import {
  Injectable,
  HttpStatus,
  Inject,
} from '@nestjs/common';
import { createHash } from 'crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { TestStateMachineService, TransitionActor } from './test-state-machine.service.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AppError } from '../common/errors/app-error.js';
import { CreateTestDto, UpdateTestStatusDto } from './dto/test.dto.js';
import { AuditEventType, TestStatus, Prisma, UserRole } from '@prisma/client';
import type { IStorageService } from '../storage/storage.interface.js';
import { ImageUploadService } from '../images/image-upload.service.js';
import { MLClientService } from '../ml/ml-client.service.js';

import { transformToSafeResult } from './dto/test-result-response.dto.js';

@Injectable()
export class TestsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
    private stateMachine: TestStateMachineService,
    private ownership: OwnershipPolicy,
    @Inject('IStorageService') private storage: IStorageService,
    private imageUpload: ImageUploadService,
    private mlClient: MLClientService,
  ) {}

  /**
   * Generates a collision-resistant human-readable test number.
   * Format: FS-YYYY-XXXXXX
   */
  private async generateTestNumber(): Promise<string> {
    const year = new Date().getFullYear();
    const prefix = `FS-${year}-`;

    const latestTest = await this.prisma.test.findFirst({
      where: { testNumber: { startsWith: prefix } },
      orderBy: { testNumber: 'desc' },
    });

    let nextNum = 1;
    if (latestTest) {
      const match = latestTest.testNumber.match(new RegExp(`^${prefix}(\\d+)$`));
      if (match) {
        nextNum = parseInt(match[1], 10) + 1;
      }
    }

    return `${prefix}${nextNum.toString().padStart(6, '0')}`;
  }

  async create(dto: CreateTestDto, operatorId: string, requestId?: string) {
    // If client supplies an id, check for conflicts with existing tests owned by other users
    if (dto.id) {
      await this.ownership.checkTestIdConflict(dto.id, operatorId);
      
      const existing = await this.prisma.test.findUnique({
        where: { id: dto.id },
      });
      if (existing) {
        // Idempotent response by id (same user retrying)
        return existing;
      }
    }

    let retries = 3;
    let test = null;

    while (retries > 0) {
      try {
        const testNumber = await this.generateTestNumber();
        test = await this.prisma.test.create({
          data: {
            id: dto.id,
            testNumber,
            operatorId,
            kitId: dto.kitId,
            caseId: dto.caseId,
            sampleId: dto.sampleId,
            deviceId: dto.deviceId,
            clientCreatedAt: new Date(dto.clientCreatedAt),
            status: TestStatus.DRAFT,
          },
        });
        break; // Break if successful without unique constraint violation
      } catch (e: any) {
        if (e.code === 'P2002') {
          retries--;
          if (retries === 0) {
            throw new AppError(
              ErrorCode.TEST_NUMBER_COLLISION,
              'Failed to generate unique test number after multiple attempts.',
              HttpStatus.CONFLICT,
            );
          }
        } else {
          throw e;
        }
      }
    }

    if (!test) {
      throw new AppError(ErrorCode.CONFLICT, 'Failed to create test.', HttpStatus.CONFLICT);
    }

    await this.auditService.log({
      eventType: AuditEventType.TEST_CREATED,
      userId: operatorId,
      resourceType: 'test',
      resourceId: test.id,
      details: { testNumber: test.testNumber } as unknown as Prisma.InputJsonValue,
      requestId,
    });

    return test;
  }

  async findAll(query: any, userId: string, role: UserRole) {
    const {
      search,
      status,
      kitId,
      operatorId,
      result,
      syncStatus,
      verificationStatus,
      dateFrom,
      dateTo,
      sort = 'desc',
      page = '1',
      limit = '20',
    } = query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    // Base query conditions with organization-scoped authorization
    const where: Prisma.TestWhereInput = await this.ownership.buildTestListFilter(userId, role);

    // Privileged roles can filter by operatorId (within their org scope)
    if (operatorId && (role === UserRole.ADMIN || role === UserRole.SUPERVISOR)) {
      where.operatorId = operatorId;
    }

    if (search) {
      where.OR = [
        { testNumber: { contains: search, mode: 'insensitive' } },
        { clientReference: { contains: search, mode: 'insensitive' } },
        { operator: { operatorId: { contains: search, mode: 'insensitive' } } },
      ];
    }

    if (status) {
      where.status = status as TestStatus;
    }

    if (kitId) {
      where.kitId = kitId;
    }

    if (dateFrom || dateTo) {
      where.serverCreatedAt = {};
      if (dateFrom) {
        where.serverCreatedAt.gte = new Date(dateFrom);
      }
      if (dateTo) {
        where.serverCreatedAt.lte = new Date(dateTo);
      }
    }

    if (result && result !== 'All') {
      if (result === 'PENDING') {
        where.status = {
          in: [
            TestStatus.DRAFT,
            TestStatus.CAPTURED,
            TestStatus.UPLOADING,
            TestStatus.PROCESSING,
          ],
        };
      } else if (result === 'FAILED') {
        where.status = TestStatus.FAILED;
      } else {
        where.result = result;
      }
    }

    if (verificationStatus && verificationStatus !== 'All') {
      if (verificationStatus === 'Not yet verified') {
        where.evidenceRecord = { is: null };
      } else {
        where.evidenceRecord = {
          verificationStatus:
            verificationStatus === 'Verified' ? 'VERIFIED' : 'INTEGRITY_FAILED',
        };
      }
    }

    const [items, total] = await Promise.all([
      this.prisma.test.findMany({
        where,
        orderBy: { serverCreatedAt: sort === 'asc' ? 'asc' : 'desc' },
        skip,
        take: limitNum,
        include: {
          kit: true,
          operator: { select: { operatorId: true, name: true, organizationId: true } },
          evidenceRecord: { select: { verificationStatus: true } },
          classification: {
            select: {
              validationStatus: true,
              qualityStatus: true,
              // Include deprecated fields for backward compatibility only
              result: true,
              confidence: true,
            },
          },
        },
      }),
      this.prisma.test.count({ where }),
    ]);

    return {
      items,
      total,
      page: pageNum,
      limit: limitNum,
      totalPages: Math.ceil(total / limitNum),
    };
  }

  async findById(id: string, userId: string, role: UserRole) {
    await this.ownership.canReadTest(id, userId, role);

    const test = await this.prisma.test.findUnique({
      where: { id },
      include: {
        kit: true,
        classification: true,
        evidenceRecord: true,
      },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Transform classification to safe format if present
    if (test.classification) {
      return {
        ...test,
        classification: transformToSafeResult(
          test.classification,
          test.kit?.validationStatus,
        ),
      };
    }

    return test;
  }

  async updateStatus(
    id: string,
    dto: UpdateTestStatusDto,
    userId: string,
    role: UserRole,
    requestId?: string,
  ) {
    await this.ownership.canModifyTest(id, userId, role);

    const test = await this.prisma.test.findUnique({ where: { id } });
    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Validate transition with CLIENT actor (only client-side transitions allowed)
    this.stateMachine.validateTransition(test.status, dto.status, TransitionActor.CLIENT);

    const updateData: Prisma.TestUpdateInput = { status: dto.status };

    // Record timestamps based on status milestones
    if (dto.status === TestStatus.CAPTURED && !test.startedAt) {
      updateData.startedAt = new Date();
    }

    const updated = await this.prisma.test.update({
      where: { id },
      data: updateData,
    });

    await this.auditService.log({
      eventType: AuditEventType.USER_UPDATED,
      userId,
      resourceType: 'test',
      resourceId: id,
      details: {
        oldStatus: test.status,
        newStatus: dto.status,
      } as unknown as Prisma.InputJsonValue,
      requestId,
    });

    return updated;
  }

  async processImage(id: string, imageUrl: string, operatorId: string, role: UserRole, requestId?: string) {
    await this.ownership.canModifyTest(id, operatorId, role);

    const test = await this.prisma.test.findUnique({
      where: { id },
      include: {
        kit: true,
        classification: true,
        processingRuns: { orderBy: { startedAt: 'desc' }, take: 1 },
      },
    });
    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Idempotency check to prevent P2002 unique constraint violations on retry
    if (test.status === TestStatus.COMPLETED && test.classification) {
      return {
        status: 'completed',
        processing_run_id: test.processingRuns[0]?.id || '',
        test_id: id,
        classification: test.classification,
      };
    }

    // 1. Persist ProcessingRun (Started) outside transaction
    const processingRun = await this.prisma.processingRun.create({
      data: {
        testId: id,
        imageId: imageUrl,
        status: 'PROCESSING',
      },
    });

    try {
      // 2. Call ML Service with retry and circuit breaker
      const result = await this.mlClient.processImage({
        test_id: test.id,
        processing_run_id: processingRun.id,
        image_url: imageUrl,
        config_version: test.kit.configurationVersion,
      });

      // 3 & 4. Use atomic transaction for all database writes
      await this.prisma.$transaction(async (tx) => {
        // Update ProcessingRun
        await tx.processingRun.update({
          where: { id: processingRun.id },
          data: {
            status: result.status,
            algorithmVersion: result.classification?.algorithmVersion,
            modelVersion: result.classification?.modelVersion,
            configurationVersion: result.classification?.configurationVersion,
            diagnostics: result.diagnostics ?? undefined,
            completedAt: new Date(),
          },
        });

        // Persist Classification if successful
        if (result.classification && result.status === 'completed') {
          const cls = result.classification;
          await tx.classification.create({
            data: {
              testId: id,
              // New colorimetric fields (primary)
              observedColorLab: cls.observedColor as any, // {L, a, b}
              colorDistance: cls.colorDistance,
              nearestReferenceLabel: cls.nearestReferenceLabel || null,
              qualityStatus: cls.qualityStatus,
              qualityIssues: cls.qualityIssues as any,
              validationStatus: cls.validationStatus,
              kitCode: test.kit.code,
              pipelineId: cls.pipelineId || null,
              // Algorithm identifiers
              algorithmVersion: cls.algorithmVersion,
              modelVersion: cls.modelVersion,
              configurationVersion: cls.configurationVersion,
              features: cls.features ?? undefined,
              diagnostics: cls.diagnostics ?? undefined,
              // DEPRECATED fields (for backward compatibility only)
              result: cls.result || null,
              confidence: cls.confidence || null,
            },
          });

          // Update Test status using SYSTEM actor
          this.stateMachine.validateTransition(
            test.status,
            TestStatus.COMPLETED,
            TransitionActor.SYSTEM,
          );

          await tx.test.update({
            where: { id },
            data: {
              status: TestStatus.COMPLETED,
              // Store quality/validation status at test level for filtering
              result: cls.qualityStatus, // Use qualityStatus instead of POSITIVE/NEGATIVE
              confidence: null, // Don't store confidence at test level
              algorithmVersion: cls.algorithmVersion,
              configurationVersion: cls.configurationVersion,
              completedAt: new Date(),
            },
          });

          await this.auditService.log({
            eventType: AuditEventType.PROCESSING_COMPLETED,
            userId: operatorId,
            resourceType: 'test',
            resourceId: id,
            details: { 
              qualityStatus: cls.qualityStatus,
              validationStatus: cls.validationStatus,
              colorDistance: cls.colorDistance,
            } as any,
            requestId,
          });
        } else {
          // Validation failed or inconclusive without classification
          this.stateMachine.validateTransition(
            test.status,
            TestStatus.FAILED,
            TransitionActor.SYSTEM,
          );
          await tx.test.update({
            where: { id },
            data: { status: TestStatus.FAILED },
          });
        }
      });

      return result;
    } catch (e: any) {
      // Handle failure in atomic transaction
      await this.prisma.$transaction(async (tx) => {
        await tx.processingRun.update({
          where: { id: processingRun.id },
          data: {
            status: 'ERROR',
            error: e.message,
            completedAt: new Date(),
          },
        });

        this.stateMachine.validateTransition(
          test.status,
          TestStatus.FAILED,
          TransitionActor.SYSTEM,
        );
        await tx.test.update({
          where: { id },
          data: { status: TestStatus.FAILED },
        });
      });
      
      throw e;
    }
  }

  async getResult(id: string, userId: string, role: UserRole) {
    await this.ownership.canReadTest(id, userId, role);

    const test = await this.prisma.test.findUnique({
      where: { id },
      include: {
        classification: true,
        kit: { select: { validationStatus: true } },
      },
    });
    
    if (!test || !test.classification) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Result not found', 404);
    }
    
    // Transform to safe format with validation warnings
    return transformToSafeResult(
      test.classification,
      test.kit?.validationStatus,
    );
  }

  /**
   * Upload image for a test with hash verification (idempotent).
   * POST /tests/:id/image
   */
  async uploadImage(
    testId: string,
    buffer: Buffer,
    mimeType: string,
    originalFilename: string,
    clientHash: string | undefined,
    captureMetadata: any,
    userId: string,
    role: UserRole,
    requestId?: string,
  ) {
    // Ownership check
    await this.ownership.canModifyTest(testId, userId, role);

    // Check if image already exists (idempotency)
    const existing = await this.prisma.imageAsset.findUnique({
      where: { testId },
    });

    if (existing) {
      // Idempotent: return existing if hashes match
      if (clientHash && clientHash === existing.clientHash) {
        return existing;
      }
      throw new AppError(
        ErrorCode.IMAGE_ALREADY_EXISTS,
        'Image already uploaded for this test',
      );
    }

    // Validate image
    const validated = this.imageUpload.validateImage(buffer, mimeType, clientHash);

    // Generate storage path: {testId}/{serverHash}.{ext}
    const ext = mimeType === 'image/jpeg' ? 'jpg' : 'png';
    const storagePath = `${testId}/${validated.serverHash}.${ext}`;

    // Write to storage (write-once)
    const storageResult = await this.storage.write(storagePath, validated.buffer);

    // Create ImageAsset record
    const imageAsset = await this.prisma.imageAsset.create({
      data: {
        testId,
        clientHash: clientHash || validated.serverHash,
        serverHash: validated.serverHash,
        originalFilename,
        mimeType: validated.mimeType,
        sizeBytes: validated.sizeBytes,
        captureMetadata: captureMetadata || Prisma.JsonNull,
        storageBackend: storageResult.backend,
        storagePath: storageResult.path,
      },
    });

    // Audit log
    await this.auditService.log({
      eventType: AuditEventType.IMAGE_UPLOADED,
      userId,
      resourceType: 'Test',
      resourceId: testId,
      details: {
        serverHash: validated.serverHash,
        sizeBytes: validated.sizeBytes,
      },
      requestId,
    });

    return imageAsset;
  }
  /**
   * Request presigned upload URL for secure direct-to-storage upload.
   * Server generates object key and returns time-limited URL.
   * Eliminates SSRF risk from arbitrary imageUrl parameter.
   */
  async requestUploadUrl(
    testId: string,
    dto: { contentType: string; fileSizeBytes: number; clientHash?: string },
    userId: string,
    role: UserRole,
    requestId?: string,
  ) {
    await this.ownership.canModifyTest(testId, userId, role);

    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      select: { id: true, testNumber: true, status: true },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Validate test state
    if (!([TestStatus.DRAFT, TestStatus.CAPTURED] as TestStatus[]).includes(test.status)) {
      throw new AppError(
        ErrorCode.TEST_INVALID_TRANSITION,
        'Upload only allowed for DRAFT or CAPTURED tests',
        HttpStatus.CONFLICT,
      );
    }

    // Validate file size
    const maxSizeBytes = 50 * 1024 * 1024; // 50MB
    if (dto.fileSizeBytes > maxSizeBytes) {
      throw new AppError(
        ErrorCode.IMAGE_TOO_LARGE,
        `File size ${dto.fileSizeBytes} exceeds maximum ${maxSizeBytes} bytes`,
        HttpStatus.PAYLOAD_TOO_LARGE,
      );
    }

    // Generate server-controlled object key
    const timestamp = Date.now();
    const randomSuffix = Math.random().toString(36).substring(7);
    const extension = dto.contentType === 'image/png' ? 'png' : dto.contentType === 'image/webp' ? 'webp' : 'jpg';
    const objectKey = `tests/${testId}/${timestamp}-${randomSuffix}.${extension}`;

    // Get presigned upload URL from storage service
    const uploadResult = await this.storage.getPresignedUploadUrl(
      objectKey,
      dto.contentType,
      dto.fileSizeBytes,
      900, // 15 minutes expiry
    );

    if (!uploadResult) {
      throw new AppError(
        ErrorCode.ML_UNAVAILABLE,
        'Presigned uploads not supported by current storage backend. Use multipart upload instead.',
        HttpStatus.NOT_IMPLEMENTED,
      );
    }

    await this.auditService.log({
      eventType: AuditEventType.USER_UPDATED,
      userId,
      resourceType: 'test',
      resourceId: testId,
      details: {
        action: 'REQUEST_UPLOAD_URL',
        objectKey: uploadResult.objectKey,
        expiresAt: uploadResult.expiresAt,
      } as any,
      requestId,
    });

    return {
      uploadUrl: uploadResult.uploadUrl,
      objectKey: uploadResult.objectKey,
      expiresAt: uploadResult.expiresAt.toISOString(),
      maxSizeBytes: uploadResult.maxSizeBytes,
    };
  }

  /**
   * Complete upload after client uploads to presigned URL.
   * Verifies hash, creates ImageAsset, and triggers ML processing.
   */
  async completeUpload(
    testId: string,
    dto: { objectKey: string; clientHash: string; actualSizeBytes: number; originalFilename?: string; mimeType?: string },
    userId: string,
    role: UserRole,
    requestId?: string,
  ) {
    await this.ownership.canModifyTest(testId, userId, role);

    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      select: { id: true, testNumber: true, status: true, kit: true },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Validate object key belongs to this test
    if (!dto.objectKey.startsWith(`tests/${testId}/`)) {
      throw new AppError(
        ErrorCode.INVALID_UPLOAD_PATH,
        'Object key does not match test ID',
        HttpStatus.FORBIDDEN,
      );
    }

    // Verify object exists in storage
    const exists = await this.storage.exists(dto.objectKey);
    if (!exists) {
      throw new AppError(
        ErrorCode.NOT_FOUND,
        'Uploaded object not found in storage',
        HttpStatus.NOT_FOUND,
      );
    }

    // Compute server hash and verify
    const imageBuffer = await this.storage.read(dto.objectKey);
    const serverHash = createHash('sha256').update(imageBuffer).digest('hex');

    if (serverHash !== dto.clientHash) {
      throw new AppError(
        ErrorCode.IMAGE_HASH_MISMATCH,
        'Client hash does not match server hash',
        HttpStatus.CONFLICT,
      );
    }

    // Create ImageAsset record
    const imageAsset = await this.prisma.imageAsset.create({
      data: {
        testId,
        storagePath: dto.objectKey,
        clientHash: dto.clientHash,
        serverHash,
        sizeBytes: dto.actualSizeBytes,
        originalFilename: dto.originalFilename || 'upload.jpg',
        mimeType: dto.mimeType || 'image/jpeg',
        storageBackend: 's3',
        captureMetadata: {}, // Can be updated separately
      },
    });

    await this.auditService.log({
      eventType: AuditEventType.USER_UPDATED,
      userId,
      resourceType: 'test',
      resourceId: testId,
      details: {
        action: 'COMPLETE_UPLOAD',
        imageAssetId: imageAsset.id,
        serverHash,
        verified: true,
      } as any,
      requestId,
    });

    // Trigger ML processing with verified object key
    // Use internal processImage method that accepts storage path
    const result = await this.processImageInternal(testId, dto.objectKey, userId, role, requestId);

    return {
      imageAssetId: imageAsset.id,
      serverHash,
      verified: true,
      processingResult: result,
    };
  }

  /**
   * Internal method for processing image from verified storage path.
   * Called by completeUpload after hash verification.
   */
  private async processImageInternal(
    testId: string,
    storagePath: string,
    userId: string,
    role: UserRole,
    requestId?: string,
  ) {
    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      include: {
        kit: true,
        classification: true,
        processingRuns: { orderBy: { startedAt: 'desc' }, take: 1 },
      },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Idempotency check
    if (test.status === TestStatus.COMPLETED && test.classification) {
      return {
        status: 'completed',
        processing_run_id: test.processingRuns[0]?.id || '',
        test_id: testId,
        classification: test.classification,
      };
    }

    // Generate signed URL for ML service to fetch image
    const imageUrl = await this.storage.getSignedUrl(storagePath, { expiresIn: 3600 });
    if (!imageUrl) {
      throw new AppError(
        ErrorCode.ML_UNAVAILABLE,
        'Cannot generate signed URL for ML processing',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    // Continue with existing processImage logic
    return this.processImage(testId, imageUrl, userId, role, requestId);
  }
}
