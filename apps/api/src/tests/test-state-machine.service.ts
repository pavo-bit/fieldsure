import { Injectable, HttpStatus } from '@nestjs/common';
import { TestStatus } from '@prisma/client';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AppError } from '../common/errors/app-error.js';

export enum TransitionActor {
  CLIENT = 'CLIENT',
  SYSTEM = 'SYSTEM',
}

@Injectable()
export class TestStateMachineService {
  /**
   * All valid transitions in the state machine.
   */
  private readonly transitions: Record<TestStatus, TestStatus[]> = {
    [TestStatus.DRAFT]: [TestStatus.CAPTURED],
    [TestStatus.CAPTURED]: [
      TestStatus.UPLOADING,
      TestStatus.PROCESSING,
      TestStatus.FAILED,
    ],
    [TestStatus.UPLOADING]: [
      TestStatus.PROCESSING,
      TestStatus.FAILED,
      TestStatus.PENDING_SYNC,
    ],
    [TestStatus.PROCESSING]: [
      TestStatus.COMPLETED,
      TestStatus.INCONCLUSIVE,
      TestStatus.FAILED,
    ],
    [TestStatus.PENDING_SYNC]: [TestStatus.CAPTURED, TestStatus.UPLOADING],
    [TestStatus.COMPLETED]: [TestStatus.REVIEWED_CONFIRMED, TestStatus.REVIEWED_OVERRIDDEN],
    [TestStatus.INCONCLUSIVE]: [TestStatus.REVIEWED_CONFIRMED, TestStatus.REVIEWED_OVERRIDDEN],
    [TestStatus.REVIEWED_CONFIRMED]: [],
    [TestStatus.REVIEWED_OVERRIDDEN]: [],
    [TestStatus.FAILED]: [TestStatus.DRAFT], // Controlled retry path
  };

  /**
   * Status transitions that clients are allowed to perform.
   * SYSTEM-only transitions (PROCESSING, COMPLETED, INCONCLUSIVE, FAILED) are NOT in this set.
   */
  private readonly clientAllowedTargets = new Set<TestStatus>([
    TestStatus.DRAFT,
    TestStatus.CAPTURED,
    TestStatus.UPLOADING,
    TestStatus.PENDING_SYNC,
  ]);

  /**
   * Validates if the transition from currentStatus to newStatus is allowed.
   * Throws AppError with 409 if invalid.
   * Enforces actor-based restrictions: clients cannot set server-owned statuses.
   */
  validateTransition(
    currentStatus: TestStatus,
    newStatus: TestStatus,
    actor: TransitionActor,
  ): void {
    if (currentStatus === newStatus) {
      return; // No-op transition is safely ignored
    }

    // Check if transition is valid in the state machine
    const allowed = this.transitions[currentStatus];
    if (!allowed || !allowed.includes(newStatus)) {
      throw new AppError(
        ErrorCode.TEST_INVALID_TRANSITION,
        `Invalid status transition from ${currentStatus} to ${newStatus}`,
        HttpStatus.CONFLICT,
      );
    }

    // Check if client is trying to set a server-owned status
    if (actor === TransitionActor.CLIENT && !this.clientAllowedTargets.has(newStatus)) {
      throw new AppError(
        ErrorCode.TEST_TRANSITION_NOT_ALLOWED_BY_CLIENT,
        `Status ${newStatus} can only be set by the server, not by clients`,
        HttpStatus.CONFLICT,
      );
    }
  }

  /**
   * Checks if the given status is a terminal state (cannot transition further).
   */
  isTerminal(status: TestStatus): boolean {
    return status === TestStatus.COMPLETED || status === TestStatus.INCONCLUSIVE;
  }
}

