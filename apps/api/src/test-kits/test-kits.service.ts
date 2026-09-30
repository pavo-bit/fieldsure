import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AuditEventType, KitValidationStatus } from '@prisma/client';

export interface CreateTestKitDto {
  code: string;
  name: string;
  manufacturer: string;
  description?: string;
  configurationVersion: string;
  crossReactivityNotes?: any;
}

export interface UpdateTestKitDto {
  name?: string;
  description?: string;
  crossReactivityNotes?: any;
  validationStatus?: KitValidationStatus;
  active?: boolean;
}

export interface CreateKitVersionDto {
  kitId: string;
  version: string;
  referenceColors: any; // {substanceClass: {L, a, b}, ...}
  readingWindow: any; // {minSeconds, maxSeconds}
  controlRequired: boolean;
  notes?: string;
}

/**
 * TestKit CRUD with versioning.
 * ADMIN-only operations.
 * Seed kits default to UNVALIDATED status.
 */
@Injectable()
export class TestKitsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async createKit(dto: CreateTestKitDto, userId: string, requestId?: string) {
    const kit = await this.prisma.testKit.create({
      data: {
        ...dto,
        validationStatus: KitValidationStatus.UNVALIDATED,
      },
    });

    await this.auditService.log({
      eventType: AuditEventType.KIT_CREATED,
      userId,
      resourceType: 'TestKit',
      resourceId: kit.id,
      details: { code: dto.code, validationStatus: 'UNVALIDATED' } as any,
      requestId,
    });

    return kit;
  }

  async updateKit(id: string, dto: UpdateTestKitDto, userId: string, requestId?: string) {
    const kit = await this.prisma.testKit.findUnique({ where: { id } });
    if (!kit) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test kit not found', 404);
    }

    const updated = await this.prisma.testKit.update({
      where: { id },
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.KIT_UPDATED,
      userId,
      resourceType: 'TestKit',
      resourceId: id,
      details: dto as any,
      requestId,
    });

    return updated;
  }

  async deactivateKit(id: string, userId: string, requestId?: string) {
    const kit = await this.prisma.testKit.findUnique({ where: { id } });
    if (!kit) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test kit not found', 404);
    }

    const updated = await this.prisma.testKit.update({
      where: { id },
      data: { active: false },
    });

    await this.auditService.log({
      eventType: AuditEventType.KIT_DEACTIVATED,
      userId,
      resourceType: 'TestKit',
      resourceId: id,
      details: {} as any,
      requestId,
    });

    return updated;
  }

  async findAllKits() {
    return this.prisma.testKit.findMany({
      include: { versions: true },
      orderBy: { name: 'asc' },
    });
  }

  async findKitById(id: string) {
    const kit = await this.prisma.testKit.findUnique({
      where: { id },
      include: { versions: true },
    });
    if (!kit) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test kit not found', 404);
    }
    return kit;
  }

  async createKitVersion(dto: CreateKitVersionDto, userId: string, requestId?: string) {
    const version = await this.prisma.kitVersion.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.KIT_VERSION_CREATED,
      userId,
      resourceType: 'KitVersion',
      resourceId: version.id,
      details: { kitId: dto.kitId, version: dto.version } as any,
      requestId,
    });

    return version;
  }

  async findVersionsByKit(kitId: string) {
    return this.prisma.kitVersion.findMany({
      where: { kitId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findVersionById(id: string) {
    const version = await this.prisma.kitVersion.findUnique({
      where: { id },
      include: { kit: true },
    });
    if (!version) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Kit version not found', 404);
    }
    return version;
  }
}
