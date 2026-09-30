import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AuditEventType, CaseStatus, CustodyAction, UserRole } from '@prisma/client';

export interface CreateCaseDto {
  organizationId: string;
  caseNumber: string;
  title: string;
}

export interface UpdateCaseDto {
  title?: string;
  status?: CaseStatus;
}

export interface CreateSampleDto {
  caseId: string;
  sampleNumber: string;
  description?: string;
  sealNumber?: string;
  collectedAt: Date;
}

export interface UpdateSampleDto {
  description?: string;
  sealNumber?: string;
}

export interface CreateCustodyEventDto {
  sampleId: string;
  fromUserId?: string;
  toUserId?: string;
  action: CustodyAction;
  note?: string;
  location?: string;
}

@Injectable()
export class CasesService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async createCase(dto: CreateCaseDto, userId: string, requestId?: string) {
    const caseRecord = await this.prisma.case.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.CASE_CREATED,
      userId,
      resourceType: 'Case',
      resourceId: caseRecord.id,
      details: { caseNumber: dto.caseNumber } as any,
      requestId,
    });

    return caseRecord;
  }

  async updateCase(id: string, dto: UpdateCaseDto, userId: string, requestId?: string) {
    const caseRecord = await this.prisma.case.findUnique({ where: { id } });
    if (!caseRecord) {
      throw new AppError(ErrorCode.CASE_NOT_FOUND, 'Case not found', 404);
    }

    const updated = await this.prisma.case.update({
      where: { id },
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.CASE_UPDATED,
      userId,
      resourceType: 'Case',
      resourceId: id,
      details: dto as any,
      requestId,
    });

    return updated;
  }

  async findCaseById(id: string) {
    const caseRecord = await this.prisma.case.findUnique({
      where: { id },
      include: { samples: true },
    });
    if (!caseRecord) {
      throw new AppError(ErrorCode.CASE_NOT_FOUND, 'Case not found', 404);
    }
    return caseRecord;
  }

  async findCasesByOrganization(organizationId: string) {
    return this.prisma.case.findMany({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createSample(dto: CreateSampleDto, userId: string, requestId?: string) {
    const sample = await this.prisma.sample.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.SAMPLE_CREATED,
      userId,
      resourceType: 'Sample',
      resourceId: sample.id,
      details: { sampleNumber: dto.sampleNumber, caseId: dto.caseId } as any,
      requestId,
    });

    return sample;
  }

  async updateSample(id: string, dto: UpdateSampleDto, userId: string, requestId?: string) {
    const sample = await this.prisma.sample.findUnique({ where: { id } });
    if (!sample) {
      throw new AppError(ErrorCode.SAMPLE_NOT_FOUND, 'Sample not found', 404);
    }

    const updated = await this.prisma.sample.update({
      where: { id },
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.SAMPLE_UPDATED,
      userId,
      resourceType: 'Sample',
      resourceId: id,
      details: dto as any,
      requestId,
    });

    return updated;
  }

  async findSampleById(id: string) {
    const sample = await this.prisma.sample.findUnique({
      where: { id },
      include: { case: true, custodyEvents: { orderBy: { timestamp: 'desc' } } },
    });
    if (!sample) {
      throw new AppError(ErrorCode.SAMPLE_NOT_FOUND, 'Sample not found', 404);
    }
    return sample;
  }

  async findSamplesByCase(caseId: string) {
    return this.prisma.sample.findMany({
      where: { caseId },
      orderBy: { sampleNumber: 'asc' },
    });
  }

  /**
   * Record custody event (append-only).
   */
  async recordCustodyEvent(dto: CreateCustodyEventDto, userId: string, requestId?: string) {
    const sample = await this.prisma.sample.findUnique({ where: { id: dto.sampleId } });
    if (!sample) {
      throw new AppError(ErrorCode.SAMPLE_NOT_FOUND, 'Sample not found', 404);
    }

    const custodyEvent = await this.prisma.custodyEvent.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.CUSTODY_EVENT_RECORDED,
      userId,
      resourceType: 'CustodyEvent',
      resourceId: custodyEvent.id,
      details: {
        sampleId: dto.sampleId,
        action: dto.action,
        fromUserId: dto.fromUserId,
        toUserId: dto.toUserId,
      } as any,
      requestId,
    });

    return custodyEvent;
  }

  async findCustodyEventsBySample(sampleId: string) {
    return this.prisma.custodyEvent.findMany({
      where: { sampleId },
      orderBy: { timestamp: 'desc' },
      include: {
        fromUser: { select: { name: true, operatorId: true } },
        toUser: { select: { name: true, operatorId: true } },
      },
    });
  }
}
