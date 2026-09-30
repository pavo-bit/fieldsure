import { Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service.js';
import { ErrorCode } from '../errors/error-codes.js';
import { AppError } from '../errors/app-error.js';

/**
 * Reusable ownership policy for object-level authorization.
 * Enforces RBAC + organization scoping + ownership rules:
 * - OPERATOR: only their own tests
 * - SUPERVISOR: tests within their organization only
 * - ADMIN: all tests system-wide
 */
@Injectable()
export class OwnershipPolicy {
  constructor(private prisma: PrismaService) {}

  /**
   * Get user's organization context for authorization.
   * Returns null for ADMIN (no org restriction), throws for missing org on other roles.
   */
  private async getUserOrgContext(userId: string, role: UserRole): Promise<string | null> {
    if (role === UserRole.ADMIN) {
      return null; // ADMIN has system-wide access
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { organizationId: true, orgUnitId: true },
    });

    if (!user) {
      throw new AppError(ErrorCode.USER_NOT_FOUND, 'User not found', 404);
    }

    // SUPERVISOR/OPERATOR/AUDITOR must have organizationId
    if (!user.organizationId) {
      throw new AppError(
        ErrorCode.FORBIDDEN,
        'User must be assigned to an organization',
        403,
      );
    }

    return user.organizationId;
  }

  /**
   * Check if user can read a test. Throws 404 (not 403) if forbidden to avoid leaking existence.
   * Organization-scoped: SUPERVISOR can only access tests within their organization.
   */
  async canReadTest(testId: string, userId: string, role: UserRole): Promise<void> {
    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      select: { 
        operatorId: true,
        operator: {
          select: { organizationId: true, orgUnitId: true }
        }
      },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // ADMIN can read all tests
    if (role === UserRole.ADMIN) {
      return;
    }

    // Get user's organization context
    const userOrgId = await this.getUserOrgContext(userId, role);

    // OPERATOR can only read their own tests
    if (role === UserRole.OPERATOR) {
      if (test.operatorId !== userId) {
        throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
      }
      return;
    }

    // SUPERVISOR/AUDITOR can read tests within their organization only
    if (userOrgId && test.operator.organizationId !== userOrgId) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }
  }

  /**
   * Check if user can modify a test (status, process, etc.).
   * Only the owner or ADMIN can modify. SUPERVISOR is read-only within their organization.
   */
  async canModifyTest(testId: string, userId: string, role: UserRole): Promise<void> {
    const test = await this.prisma.test.findUnique({
      where: { id: testId },
      select: { 
        operatorId: true,
        operator: {
          select: { organizationId: true }
        }
      },
    });

    if (!test) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // ADMIN can modify anything
    if (role === UserRole.ADMIN) {
      return;
    }

    // Only owner can modify their test
    if (test.operatorId !== userId) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }

    // Verify user is in same organization as test (prevents cross-org modification)
    const userOrgId = await this.getUserOrgContext(userId, role);
    if (userOrgId && test.operator.organizationId !== userOrgId) {
      throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
    }
  }

  /**
   * Check if user can access a case. Organization-scoped for SUPERVISOR.
   */
  async canReadCase(caseId: string, userId: string, role: UserRole): Promise<void> {
    const caseRecord = await this.prisma.case.findUnique({
      where: { id: caseId },
      select: {
        organizationId: true,
      },
    });

    if (!caseRecord) {
      throw new AppError(ErrorCode.CASE_NOT_FOUND, 'Case not found', 404);
    }

    // ADMIN can read all cases
    if (role === UserRole.ADMIN) {
      return;
    }

    // Get user's organization
    const userOrgId = await this.getUserOrgContext(userId, role);

    // Verify same organization
    if (userOrgId && caseRecord.organizationId !== userOrgId) {
      throw new AppError(ErrorCode.CASE_NOT_FOUND, 'Case not found', 404);
    }
  }

  /**
   * Check if user can verify evidence. SUPERVISOR and ADMIN only, within organization scope.
   */
  async canVerifyEvidence(testId: string, userId: string, role: UserRole): Promise<void> {
    if (role !== UserRole.SUPERVISOR && role !== UserRole.ADMIN) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Only supervisors and admins can verify evidence', 403);
    }

    // For SUPERVISOR, verify same organization
    if (role === UserRole.SUPERVISOR) {
      const test = await this.prisma.test.findUnique({
        where: { id: testId },
        select: {
          operator: {
            select: { organizationId: true }
          }
        },
      });

      if (!test) {
        throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
      }

      const userOrgId = await this.getUserOrgContext(userId, role);
      if (userOrgId && test.operator.organizationId !== userOrgId) {
        throw new AppError(ErrorCode.TEST_NOT_FOUND, 'Test not found', 404);
      }
    }
  }

  /**
   * Build organization-scoped WHERE clause for listing tests.
   * Returns Prisma WHERE filter based on user's role and organization.
   */
  async buildTestListFilter(userId: string, role: UserRole): Promise<any> {
    if (role === UserRole.ADMIN) {
      return {}; // ADMIN sees all
    }

    if (role === UserRole.OPERATOR) {
      return { operatorId: userId }; // OPERATOR sees only their own
    }

    // SUPERVISOR/AUDITOR: filter by organization
    const userOrgId = await this.getUserOrgContext(userId, role);
    return {
      operator: {
        organizationId: userOrgId,
      },
    };
  }

  /**
   * Build organization-scoped WHERE clause for listing cases.
   */
  async buildCaseListFilter(userId: string, role: UserRole): Promise<any> {
    if (role === UserRole.ADMIN) {
      return {}; // ADMIN sees all
    }

    const userOrgId = await this.getUserOrgContext(userId, role);
    return {
      createdBy: {
        organizationId: userOrgId,
      },
    };
  }

  /**
   * Check if a test with the given id already exists and belongs to a different user.
   * Used for idempotent POST /tests to detect TEST_ID_CONFLICT.
   */
  async checkTestIdConflict(testId: string, expectedOwnerId: string): Promise<void> {
    const existing = await this.prisma.test.findUnique({
      where: { id: testId },
      select: { operatorId: true },
    });

    if (existing && existing.operatorId !== expectedOwnerId) {
      throw new AppError(
        ErrorCode.TEST_ID_CONFLICT,
        'A test with this ID already exists and belongs to a different user',
        409,
      );
    }
  }
}
