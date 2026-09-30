import { Injectable, HttpStatus, Inject } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { SignerService } from './signer.service.js';
import { AuditService } from '../audit/audit.service.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AppError } from '../common/errors/app-error.js';
import { AuditEventType, TestStatus } from '@prisma/client';
import { SigningKeysService } from '../signing-keys/signing-keys.service.js';
import { TimestampService } from './timestamp.service.js';
import type { IStorageService } from '../storage/storage.interface.js';
import { createCanonicalV1, createCanonicalV2, createCanonicalV3 } from './canonicalizers.js';
import * as crypto from 'crypto';

@Injectable()
export class EvidenceService {
  constructor(
    private prisma: PrismaService,
    private signer: SignerService,
    private auditService: AuditService,
    private ownership: OwnershipPolicy,
    private signingKeys: SigningKeysService,
    private timestampService: TimestampService,
    @Inject('IStorageService') private storage: IStorageService,
  ) {}

  /**
   * Create evidence record automatically (called atomically after classification).
   * Uses V3 canonical format with colorimetric measurements, quality assessment, validation status.
   * Includes operator interpretation if it exists at time of evidence creation.
   */
  async createEvidenceAutomatic(testId: string, requestId?: string) {
    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      include: {
        classification: {
          include: {
            operatorInterpretations: {
              orderBy: { interpretedAt: 'desc' },
              take: 1, // Most recent operator interpretation
            },
          },
        },
        imageAsset: true,
        kit: true, // Include TestKit for kitCode and validationStatus
      },
    });

    if (!test || !test.classification || !test.imageAsset || !test.kit) {
      throw new AppError(
        ErrorCode.TEST_MISSING_CLASSIFICATION,
        'Test missing classification, image, or kit metadata',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    // Check for existing evidence (idempotent)
    const existing = await this.prisma.evidenceRecord.findUnique({ where: { testId } });
    if (existing) return existing;

    // Get chain state (previous record hash, next index)
    const lastRecord = await this.prisma.evidenceRecord.findFirst({
      orderBy: { chainIndex: 'desc' },
      select: { recordHash: true, chainIndex: true },
    });

    const previousRecordHash = lastRecord?.recordHash || null;
    const chainIndex = lastRecord ? lastRecord.chainIndex + 1 : 0;

    // Get operator interpretation if exists (most recent)
    const operatorInterpretation = test.classification.operatorInterpretations[0] || null;

    // Create canonical record V3 (safety-hardened with colorimetric measurements)
    const canonicalString = createCanonicalV3(
      test,
      test.classification,
      test.imageAsset,
      test.kit,
      operatorInterpretation,
      previousRecordHash,
      chainIndex,
    );

    const recordHash = crypto.createHash('sha256').update(canonicalString).digest('hex');

    // Get active signing key
    const signingKey = await this.signingKeys.getActiveKey();

    // Sign with RSA-SHA256
    const signature = crypto.sign('sha256', Buffer.from(canonicalString), {
      key: signingKey.privateKeyPem,
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
    });

    // Optional: get RFC 3161 timestamp token
    const timestampToken = await this.timestampService.getTimestampToken(recordHash);

    // Create evidence record
    const evidence = await this.prisma.evidenceRecord.create({
      data: {
        testId,
        version: 3,
        schemaVersion: '3.0',
        canonicalizationVersion: '3.0-RFC8785',
        clientImageHash: test.imageAsset.clientHash,
        serverImageHash: test.imageAsset.serverHash,
        captureMetadata: test.imageAsset.captureMetadata || undefined,
        previousRecordHash,
        chainIndex,
        recordHash,
        hashingAlgorithm: 'SHA-256',
        signature: signature.toString('base64'),
        signatureAlgorithm: 'RS256',
        signerKeyId: signingKey.kid,
        timestampToken,
        signedAt: new Date(),
        verificationStatus: 'VERIFIED',
      },
    });

    await this.auditService.log({
      eventType: AuditEventType.EVIDENCE_SIGNED,
      userId: test.operatorId,
      resourceType: 'evidence',
      resourceId: evidence.id,
      details: { 
        recordHash, 
        chainIndex,
        version: 3,
        validationStatus: test.classification.validationStatus,
        qualityStatus: test.classification.qualityStatus,
        operatorReviewed: operatorInterpretation !== null,
      } as any,
      requestId,
    });

    return evidence;
  }

  /**
   * Legacy: manual evidence creation (for backward compatibility).
   */
  async createEvidence(testId: string, operatorId: string, role: UserRole, requestId?: string) {
    await this.ownership.canReadTest(testId, operatorId, role);

    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      include: {
        classification: true,
        imageAsset: true,
      },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }
    if (test.status !== TestStatus.COMPLETED) {
      throw new AppError(
        ErrorCode.TEST_NOT_COMPLETED,
        'Test is not completed',
        HttpStatus.CONFLICT,
      );
    }
    if (!test.classification) {
      throw new AppError(
        ErrorCode.TEST_MISSING_CLASSIFICATION,
        'Test missing classification result',
        HttpStatus.CONFLICT,
      );
    }

    const existing = await this.prisma.evidenceRecord.findUnique({ where: { testId } });
    if (existing) return existing;

    // Use automatic creation path
    return this.createEvidenceAutomatic(testId, requestId);
  }

  async getEvidence(testId: string, operatorId: string, role: UserRole, requestId?: string) {
    await this.ownership.canReadTest(testId, operatorId, role);

    const evidence = await this.prisma.evidenceRecord.findUnique({
      where: { testId },
    });
    if (!evidence) {
      throw new AppError(ErrorCode.EVIDENCE_NOT_FOUND, 'Evidence not found', 404);
    }

    await this.auditService.log({
      eventType: AuditEventType.RECORD_VIEWED,
      userId: operatorId,
      resourceType: 'evidence',
      resourceId: evidence.id,
      details: {} as any,
      requestId,
    });

    return evidence;
  }

  async verifyEvidence(testId: string, operatorId: string, role: UserRole, requestId?: string) {
    await this.ownership.canReadTest(testId, operatorId, role);
    await this.ownership.canVerifyEvidence(testId, operatorId, role);

    const evidence = await this.prisma.evidenceRecord.findUnique({
      where: { testId },
      include: {
        test: {
          include: {
            classification: {
              include: {
                operatorInterpretations: {
                  orderBy: { interpretedAt: 'desc' },
                  take: 1,
                },
              },
            },
            imageAsset: true,
            kit: true,
          },
        },
      },
    });

    if (!evidence) {
      throw new AppError(ErrorCode.EVIDENCE_NOT_FOUND, 'Evidence not found', 404);
    }

    const test = evidence.test;
    const version = evidence.version || 1;

    // Image integrity check
    let imageIntegrity = 'VALID';
    if (test.imageAsset) {
      const imageBuffer = await this.storage.read(test.imageAsset.storagePath);
      const currentHash = crypto.createHash('sha256').update(imageBuffer).digest('hex');
      if (currentHash !== test.imageAsset.serverHash) {
        imageIntegrity = 'TAMPERED';
      }
      if (evidence.serverImageHash && currentHash !== evidence.serverImageHash) {
        imageIntegrity = 'TAMPERED';
      }
    } else {
      imageIntegrity = 'MISSING';
    }

    // Client vs server hash check (V2+ only)
    let clientServerHashMatch = 'N/A';
    if (version >= 2 && evidence.clientImageHash && evidence.serverImageHash) {
      clientServerHashMatch = evidence.clientImageHash === evidence.serverImageHash ? 'MATCH' : 'MISMATCH';
    }

    // Record integrity check: recompute canonical record and hash
    let canonicalString: string;
    if (version === 1) {
      // V1: legacy format (use serverImageHash as imageHash)
      canonicalString = createCanonicalV1(test, test.classification, evidence.serverImageHash);
    } else if (version === 2) {
      // V2: extended format
      if (!test.imageAsset) {
        throw new AppError(ErrorCode.EVIDENCE_INVALID_VERSION, 'V2 record missing image asset', 400);
      }
      canonicalString = createCanonicalV2(
        test,
        test.classification,
        test.imageAsset,
        evidence.previousRecordHash,
        evidence.chainIndex,
      );
    } else {
      // V3: safety-hardened format with colorimetric measurements
      if (!test.imageAsset || !test.kit) {
        throw new AppError(
          ErrorCode.EVIDENCE_INVALID_VERSION,
          'V3 record missing image asset or kit metadata',
          400,
        );
      }
      const operatorInterpretation = test.classification?.operatorInterpretations[0] || null;
      canonicalString = createCanonicalV3(
        test,
        test.classification,
        test.imageAsset,
        test.kit,
        operatorInterpretation,
        evidence.previousRecordHash,
        evidence.chainIndex,
      );
    }

    const currentRecordHash = crypto.createHash('sha256').update(canonicalString).digest('hex');
    const recordIntegrity = currentRecordHash === evidence.recordHash ? 'VALID' : 'TAMPERED';

    // Signature verification
    const publicKeyPem = await this.signingKeys.getPublicKey(evidence.signerKeyId);
    let signatureIntegrity = 'VALID';
    try {
      const signatureBuffer = Buffer.from(evidence.signature, 'base64');
      const isValid = crypto.verify(
        'sha256',
        Buffer.from(canonicalString),
        {
          key: publicKeyPem,
          padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
        },
        signatureBuffer,
      );
      signatureIntegrity = isValid ? 'VALID' : 'INVALID';
    } catch (err: any) {
      signatureIntegrity = 'INVALID';
    }

    // Chain integrity check (V2+ only)
    let chainIntegrity = 'N/A';
    if (version >= 2 && evidence.chainIndex > 0) {
      const previousRecord = await this.prisma.evidenceRecord.findFirst({
        where: { chainIndex: evidence.chainIndex - 1 },
        select: { recordHash: true },
      });
      if (previousRecord) {
        chainIntegrity = previousRecord.recordHash === evidence.previousRecordHash ? 'VALID' : 'BROKEN';
      } else {
        chainIntegrity = 'MISSING_PREVIOUS';
      }
    } else if (version >= 2 && evidence.chainIndex === 0) {
      chainIntegrity = evidence.previousRecordHash === null ? 'GENESIS' : 'INVALID_GENESIS';
    }

    const verified =
      imageIntegrity === 'VALID' &&
      recordIntegrity === 'VALID' &&
      signatureIntegrity === 'VALID' &&
      (chainIntegrity === 'VALID' || chainIntegrity === 'GENESIS' || chainIntegrity === 'N/A');

    const overallStatus = verified ? 'VERIFIED' : 'INTEGRITY_FAILED';

    if (evidence.verificationStatus !== overallStatus) {
      await this.prisma.evidenceRecord.update({
        where: { id: evidence.id },
        data: { verificationStatus: overallStatus },
      });
    }

    await this.auditService.log({
      eventType: verified ? AuditEventType.RECORD_VERIFIED : AuditEventType.ERROR,
      userId: operatorId,
      resourceType: 'evidence',
      resourceId: evidence.id,
      details: {
        action: 'VERIFICATION',
        imageIntegrity,
        recordIntegrity,
        signatureIntegrity,
        chainIntegrity,
        clientServerHashMatch,
        overallStatus,
        version,
      } as any,
      requestId,
    });

    return {
      verified,
      integrity: overallStatus,
      version: evidence.version,
      imageIntegrity,
      clientServerHashMatch,
      recordIntegrity,
      signature: signatureIntegrity,
      chainIntegrity,
      recordHash: evidence.recordHash,
      algorithm: evidence.hashingAlgorithm,
      signatureAlgorithm: evidence.signatureAlgorithm,
      signerKeyId: evidence.signerKeyId,
      chainIndex: evidence.chainIndex,
      verifiedAt: new Date().toISOString(),
    };
  }
}
