import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuditEventType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import type { CreateUserDto, UpdateUserDto } from './dto/user.dto.js';
import type { UserResponse } from '../auth/interfaces/auth.interfaces.js';

const BCRYPT_ROUNDS = 12;

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private auditService: AuditService,
  ) {}

  async create(dto: CreateUserDto, createdBy: string, requestId?: string): Promise<UserResponse> {
    // Check for duplicate email or operatorId
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [{ email: dto.email }, { operatorId: dto.operatorId }],
      },
    });

    if (existing) {
      const field = existing.email === dto.email ? 'email' : 'operatorId';
      throw new ConflictException(`User with this ${field} already exists`);
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = await this.prisma.user.create({
      data: {
        operatorId: dto.operatorId,
        name: dto.name,
        email: dto.email,
        passwordHash,
        role: dto.role ?? 'OPERATOR',
        mustChangePassword: true, // Force password change on first login for admin-created users
      },
    });

    await this.auditService.log({
      eventType: AuditEventType.USER_CREATED,
      userId: createdBy,
      resourceType: 'user',
      resourceId: user.id,
      details: { operatorId: user.operatorId, role: user.role },
      requestId,
    });

    return this.toResponse(user);
  }

  async findAll(query: any): Promise<{ items: UserResponse[]; total: number; page: number; limit: number; totalPages: number }> {
    const {
      search,
      role,
      isActive,
      sort = 'desc',
      page = '1',
      limit = '20',
    } = query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where: Prisma.UserWhereInput = {};

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { operatorId: { contains: search, mode: 'insensitive' } },
      ];
    }

    if (role) {
      where.role = role as any;
    }

    if (isActive !== undefined) {
      where.isActive = isActive === 'true';
    }

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: sort === 'asc' ? 'asc' : 'desc' },
        skip,
        take: limitNum,
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      items: users.map((u) => this.toResponse(u)),
      total,
      page: pageNum,
      limit: limitNum,
      totalPages: Math.ceil(total / limitNum),
    };
  }

  async findById(id: string): Promise<UserResponse> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.toResponse(user);
  }

  async update(
    id: string,
    dto: UpdateUserDto,
    updatedBy: string,
    requestId?: string,
  ): Promise<UserResponse> {
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('User not found');

    // Check for duplicate email/operatorId if changing
    if (dto.email && dto.email !== existing.email) {
      const dup = await this.prisma.user.findUnique({
        where: { email: dto.email },
      });
      if (dup) throw new ConflictException('Email already in use');
    }

    if (dto.operatorId && dto.operatorId !== existing.operatorId) {
      const dup = await this.prisma.user.findUnique({
        where: { operatorId: dto.operatorId },
      });
      if (dup) throw new ConflictException('Operator ID already in use');
    }

    const user = await this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.email !== undefined && { email: dto.email }),
        ...(dto.role !== undefined && { role: dto.role }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.operatorId !== undefined && { operatorId: dto.operatorId }),
      },
    });

    const eventType =
      dto.isActive === false
        ? AuditEventType.USER_DEACTIVATED
        : AuditEventType.USER_UPDATED;

    await this.auditService.log({
      eventType,
      userId: updatedBy,
      resourceType: 'user',
      resourceId: user.id,
      details: dto as unknown as Prisma.InputJsonValue,
      requestId,
    });

    return this.toResponse(user);
  }

  async deactivate(id: string, deactivatedBy: string, requestId?: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');

    await this.prisma.user.update({
      where: { id },
      data: { isActive: false },
    });

    // Revoke all sessions
    await this.prisma.authSession.updateMany({
      where: { userId: id, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    await this.auditService.log({
      eventType: AuditEventType.USER_DEACTIVATED,
      userId: deactivatedBy,
      resourceType: 'user',
      resourceId: id,
      requestId,
    });
  }

  private toResponse(user: {
    id: string;
    operatorId: string;
    name: string;
    email: string;
    role: string;
    isActive: boolean;
    lastLoginAt: Date | null;
    createdAt: Date;
  }): UserResponse {
    return {
      id: user.id,
      operatorId: user.operatorId,
      name: user.name,
      email: user.email,
      role: user.role as UserResponse['role'],
      isActive: user.isActive,
      lastLoginAt: user.lastLoginAt?.toISOString() ?? null,
      createdAt: user.createdAt.toISOString(),
    };
  }
}
