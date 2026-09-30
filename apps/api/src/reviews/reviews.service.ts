import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AuditEventType, TestStatus, UserRole } from '@prisma/client';

export interface CreateReviewDto {
  testId: string;
  decision: 'REVIEWED_CONFIRMED' | 'REVIEWED_OVERRIDDEN';
  reason: string;
  revisedLabel?: string;
}

/**
 * Human review workflow.
 * SUPERVISOR/ADMIN can review COMPLETED/INCONCLUSIVE tests.
 * Original classification is immutable; review creates append-only record.
 * Override creates new evidence version.
 */
@Injectable()
export class ReviewsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async createReview(dto: CreateReviewDto, reviewerId: string, role: UserRole, requestId?: string) {
    if (role !== UserRole.SUPERVISOR && role !== UserRole.ADMIN) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Only SUPERVISOR/ADMIN can review tests', 403);
    }

    const test = await this.prisma.test.findUnique({
      where: { id: dto.testId },
      include: { classification: true, reviews: true },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Only COMPLETED or INCONCLUSIVE tests can be reviewed
    if (test.status !== TestStatus.COMPLETED && test.status !== TestStatus.INCONCLUSIVE) {
      throw new AppError(
        ErrorCode.REVIEW_INVALID_STATE,
        'Test must be COMPLETED or INCONCLUSIVE to be reviewed',
        409,
      );
    }

    if (!test.classification) {
      throw new AppError(
        ErrorCode.TEST_MISSING_CLASSIFICATION,
        'Test has no classification to review',
        409,
      );
    }

    // Check if already reviewed (immutability check)
    if (test.reviews.length > 0) {
      throw new AppError(
        ErrorCode.REVIEW_IMMUTABLE,
        'Test has already been reviewed. Reviews are immutable.',
        409,
      );
    }

    // Override requires revised label
    if (dto.decision === 'REVIEWED_OVERRIDDEN' && !dto.revisedLabel) {
      throw new AppError(
        ErrorCode.VALIDATION_FAILED,
        'Revised label is required for overrides',
        400,
      );
    }

    // Create review record (append-only)
    const review = await this.prisma.testReview.create({
      data: {
        testId: dto.testId,
        reviewerId,
        decision: dto.decision,
        reason: dto.reason,
        revisedLabel: dto.revisedLabel,
      },
    });

    // Update test status
    const newStatus =
      dto.decision === 'REVIEWED_CONFIRMED'
        ? TestStatus.REVIEWED_CONFIRMED
        : TestStatus.REVIEWED_OVERRIDDEN;

    await this.prisma.test.update({
      where: { id: dto.testId },
      data: { status: newStatus },
    });

    await this.auditService.log({
      eventType: AuditEventType.TEST_REVIEWED,
      userId: reviewerId,
      resourceType: 'TestReview',
      resourceId: review.id,
      details: {
        testId: dto.testId,
        decision: dto.decision,
        originalLabel: test.classification.presumptiveLabel,
        revisedLabel: dto.revisedLabel,
      } as any,
      requestId,
    });

    // TODO: For overrides, create new evidence version (Phase 3 scope limitation)
    // This would call evidenceService.createEvidenceAutomatic() with updated data

    return review;
  }

  async findReviewsByTest(testId: string) {
    return this.prisma.testReview.findMany({
      where: { testId },
      include: {
        reviewer: { select: { name: true, operatorId: true, role: true } },
      },
      orderBy: { reviewedAt: 'desc' },
    });
  }
}
