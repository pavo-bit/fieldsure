import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AuditEventType, UserRole } from '@prisma/client';

export interface CreateOrganizationDto {
  code: string;
  name: string;
}

export interface UpdateOrganizationDto {
  name?: string;
  active?: boolean;
}

export interface CreateOrgUnitDto {
  organizationId: string;
  parentUnitId?: string;
  code: string;
  name: string;
}

export interface UpdateOrgUnitDto {
  name?: string;
  active?: boolean;
}

/**
 * Organization and OrgUnit management.
 * ADMIN-only operations.
 */
@Injectable()
export class OrganizationsService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  /**
   * Tenant scoping helper: get accessible org units for a user.
   * - OPERATOR: own unit only
   * - SUPERVISOR: own unit + descendants
   * - ADMIN: all units in organization
   */
  async getAccessibleUnitIds(userId: string, role: UserRole): Promise<string[]> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { orgUnitId: true, organizationId: true },
    });

    if (!user) return [];

    if (role === UserRole.ADMIN && user.organizationId) {
      // Admin sees all units in organization
      const units = await this.prisma.orgUnit.findMany({
        where: { organizationId: user.organizationId },
        select: { id: true },
      });
      return units.map((u) => u.id);
    }

    if (role === UserRole.SUPERVISOR && user.orgUnitId) {
      // Supervisor sees own unit + descendants
      const descendants = await this.getDescendantUnits(user.orgUnitId);
      return [user.orgUnitId, ...descendants.map((u) => u.id)];
    }

    // Operator sees own unit only
    return user.orgUnitId ? [user.orgUnitId] : [];
  }

  /**
   * Get all descendant units (recursive).
   */
  private async getDescendantUnits(parentUnitId: string): Promise<Array<{ id: string }>> {
    const directChildren = await this.prisma.orgUnit.findMany({
      where: { parentUnitId },
      select: { id: true },
    });

    const descendants: Array<{ id: string }> = [...directChildren];

    for (const child of directChildren) {
      const childDescendants = await this.getDescendantUnits(child.id);
      descendants.push(...childDescendants);
    }

    return descendants;
  }

  async createOrganization(dto: CreateOrganizationDto, userId: string, requestId?: string) {
    const org = await this.prisma.organization.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.ORG_CREATED,
      userId,
      resourceType: 'Organization',
      resourceId: org.id,
      details: { code: dto.code } as any,
      requestId,
    });

    return org;
  }

  async updateOrganization(
    id: string,
    dto: UpdateOrganizationDto,
    userId: string,
    requestId?: string,
  ) {
    const org = await this.prisma.organization.findUnique({ where: { id } });
    if (!org) {
      throw new AppError(ErrorCode.ORG_NOT_FOUND, 'Organization not found', 404);
    }

    const updated = await this.prisma.organization.update({
      where: { id },
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.ORG_UPDATED,
      userId,
      resourceType: 'Organization',
      resourceId: id,
      details: dto as any,
      requestId,
    });

    return updated;
  }

  async findAllOrganizations() {
    return this.prisma.organization.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findOrganizationById(id: string) {
    const org = await this.prisma.organization.findUnique({
      where: { id },
      include: { units: true },
    });
    if (!org) {
      throw new AppError(ErrorCode.ORG_NOT_FOUND, 'Organization not found', 404);
    }
    return org;
  }

  async createOrgUnit(dto: CreateOrgUnitDto, userId: string, requestId?: string) {
    const unit = await this.prisma.orgUnit.create({
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.UNIT_CREATED,
      userId,
      resourceType: 'OrgUnit',
      resourceId: unit.id,
      details: { code: dto.code, organizationId: dto.organizationId } as any,
      requestId,
    });

    return unit;
  }

  async updateOrgUnit(id: string, dto: UpdateOrgUnitDto, userId: string, requestId?: string) {
    const unit = await this.prisma.orgUnit.findUnique({ where: { id } });
    if (!unit) {
      throw new AppError(ErrorCode.UNIT_NOT_FOUND, 'Organizational unit not found', 404);
    }

    const updated = await this.prisma.orgUnit.update({
      where: { id },
      data: dto,
    });

    await this.auditService.log({
      eventType: AuditEventType.UNIT_UPDATED,
      userId,
      resourceType: 'OrgUnit',
      resourceId: id,
      details: dto as any,
      requestId,
    });

    return updated;
  }

  async findUnitsByOrganization(organizationId: string) {
    return this.prisma.orgUnit.findMany({
      where: { organizationId },
      orderBy: { name: 'asc' },
    });
  }

  async findOrgUnitById(id: string) {
    const unit = await this.prisma.orgUnit.findUnique({
      where: { id },
      include: { organization: true, childUnits: true },
    });
    if (!unit) {
      throw new AppError(ErrorCode.UNIT_NOT_FOUND, 'Organizational unit not found', 404);
    }
    return unit;
  }
}
