import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AuditEventType, LabMethod, ConfirmationOutcome, UserRole } from '@prisma/client';

export interface CreateLabConfirmationDto {
  testId: string;
  method: LabMethod;
  confirmedSubstance: string;
  labReferenceNumber: string;
  reportDate: Date;
  reportFilePath?: string;
  notes?: string;
}

/**
 * Lab confirmation service (ground truth).
 * SUPERVISOR/ADMIN/LAB_ANALYST can record confirmations.
 * Computes agreement outcome: TP/FP/TN/FN/NOT_APPLICABLE.
 */
@Injectable()
export class LabConfirmationsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  /**
   * Compute agreement outcome between presumptive and confirmed results.
   */
  private computeOutcome(
    presumptiveLabel: string | null,
    confirmedSubstance: string,
  ): ConfirmationOutcome {
    const presumptive = (presumptiveLabel || '').toLowerCase().trim();
    const confirmed = confirmedSubstance.toLowerCase().trim();

    // Negative cases
    if (presumptive === '' || presumptive === 'negative') {
      if (confirmed === 'none' || confirmed === 'negative' || confirmed === 'no substance detected') {
        return ConfirmationOutcome.TRUE_NEGATIVE;
      }
      return ConfirmationOutcome.FALSE_NEGATIVE; // Missed detection
    }

    // Positive cases
    if (confirmed === 'none' || confirmed === 'negative' || confirmed === 'no substance detected') {
      return ConfirmationOutcome.FALSE_POSITIVE; // False alarm
    }

    // Both positive: check if classes match (simple substring match, production needs domain mapping)
    if (presumptive.includes(confirmed) || confirmed.includes(presumptive)) {
      return ConfirmationOutcome.TRUE_POSITIVE;
    }

    // Both positive but different substances
    return ConfirmationOutcome.FALSE_POSITIVE;
  }

  async createLabConfirmation(
    dto: CreateLabConfirmationDto,
    confirmedById: string,
    role: UserRole,
    requestId?: string,
  ) {
    if (
      role !== UserRole.SUPERVISOR &&
      role !== UserRole.ADMIN &&
      role !== UserRole.LAB_ANALYST
    ) {
      throw new AppError(
        ErrorCode.FORBIDDEN,
        'Only SUPERVISOR/ADMIN/LAB_ANALYST can record lab confirmations',
        403,
      );
    }

    const test = await this.prisma.test.findUnique({
      where: { id: dto.testId },
      include: { classification: true, labConfirmation: true },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    if (test.labConfirmation) {
      throw new AppError(
        ErrorCode.LAB_CONFIRMATION_EXISTS,
        'Lab confirmation already exists for this test',
        409,
      );
    }

    // Compute agreement outcome
    const outcome = this.computeOutcome(
      test.classification?.presumptiveLabel || null,
      dto.confirmedSubstance,
    );

    const labConfirmation = await this.prisma.labConfirmation.create({
      data: {
        ...dto,
        confirmedById,
        outcome,
      },
    });

    await this.auditService.log({
      eventType: AuditEventType.LAB_CONFIRMATION_RECORDED,
      userId: confirmedById,
      resourceType: 'LabConfirmation',
      resourceId: labConfirmation.id,
      details: {
        testId: dto.testId,
        outcome,
        method: dto.method,
        confirmedSubstance: dto.confirmedSubstance,
      } as any,
      requestId,
    });

    return labConfirmation;
  }

  async findLabConfirmationByTest(testId: string) {
    const confirmation = await this.prisma.labConfirmation.findUnique({
      where: { testId },
      include: {
        test: { include: { classification: true } },
        confirmedBy: { select: { name: true, operatorId: true, role: true } },
      },
    });

    if (!confirmation) {
      throw new AppError(ErrorCode.EVIDENCE_NOT_FOUND, 'Lab confirmation not found', 404);
    }

    return confirmation;
  }

  /**
   * Export labelled dataset for model training (CSV/JSONL).
   * No PII included: only imageHash, kitVersion, confirmedSubstance, outcome.
   */
  async exportLabelledDataset(format: 'csv' | 'jsonl' = 'csv'): Promise<string> {
    const confirmations = await this.prisma.labConfirmation.findMany({
      include: {
        test: {
          include: {
            imageAsset: { select: { serverHash: true } },
            kitVersion: { select: { version: true }, include: { kit: { select: { code: true } } } },
            classification: { select: { presumptiveLabel: true, confidence: true } },
          },
        },
      },
    });

    if (format === 'csv') {
      const header = 'imageHash,kitCode,kitVersion,presumptiveLabel,confidence,confirmedSubstance,outcome\n';
      const rows = confirmations.map((c) => {
        const imageHash = c.test.imageAsset?.serverHash || 'MISSING';
        const kitCode = c.test.kitVersion?.kit.code || 'UNKNOWN';
        const kitVersion = c.test.kitVersion?.version || 'UNKNOWN';
        const presumptiveLabel = c.test.classification?.presumptiveLabel || 'NONE';
        const confidence = c.test.classification?.confidence || 0;
        return `${imageHash},${kitCode},${kitVersion},"${presumptiveLabel}",${confidence},"${c.confirmedSubstance}",${c.outcome}`;
      });
      return header + rows.join('\n');
    } else {
      // JSONL
      const lines = confirmations.map((c) =>
        JSON.stringify({
          imageHash: c.test.imageAsset?.serverHash || 'MISSING',
          kitCode: c.test.kitVersion?.kit.code || 'UNKNOWN',
          kitVersion: c.test.kitVersion?.version || 'UNKNOWN',
          presumptiveLabel: c.test.classification?.presumptiveLabel || 'NONE',
          confidence: c.test.classification?.confidence || 0,
          confirmedSubstance: c.confirmedSubstance,
          outcome: c.outcome,
        }),
      );
      return lines.join('\n');
    }
  }
}
