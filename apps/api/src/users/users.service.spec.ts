import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service.js';
import { UserRole, AuditEventType } from '@prisma/client';

describe('UsersService', () => {
  let usersService: UsersService;
  let mockPrisma: any;
  let mockAuditService: any;

  const mockUser = {
    id: '22222222-2222-2222-2222-222222222222',
    operatorId: 'OP-042',
    name: 'Officer Priya',
    email: 'priya@police.gov.in',
    passwordHash: '$2b$12$hashedPasswordExampleValue12345678901234567890',
    role: UserRole.OPERATOR,
    isActive: true,
    lastLoginAt: null,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
  };

  beforeEach(() => {
    mockPrisma = {
      user: {
        findFirst: vi.fn().mockResolvedValue(null),
        findUnique: vi.fn().mockResolvedValue(null),
        findMany: vi.fn().mockResolvedValue([mockUser]),
        create: vi.fn().mockResolvedValue(mockUser),
        update: vi.fn().mockResolvedValue(mockUser),
        count: vi.fn().mockResolvedValue(1),
      },
      authSession: {
        updateMany: vi.fn().mockResolvedValue({ count: 2 }),
      },
    };

    mockAuditService = {
      log: vi.fn().mockResolvedValue(undefined),
    };

    usersService = new UsersService(mockPrisma, mockAuditService);
  });

  describe('create', () => {
    it('should create a new user with hashed password and audit entry', async () => {
      const result = await usersService.create(
        {
          operatorId: 'OP-042',
          name: 'Officer Priya',
          email: 'priya@police.gov.in',
          password: 'Password123!',
          role: UserRole.OPERATOR,
        },
        'admin-user-id',
      );

      expect(result).toEqual({
        id: mockUser.id,
        operatorId: mockUser.operatorId,
        name: mockUser.name,
        email: mockUser.email,
        role: UserRole.OPERATOR,
        isActive: true,
        lastLoginAt: null,
        createdAt: mockUser.createdAt.toISOString(),
      });
      expect(mockPrisma.user.create).toHaveBeenCalled();
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.USER_CREATED,
          userId: 'admin-user-id',
          resourceType: 'user',
          resourceId: mockUser.id,
        }),
      );
    });

    it('should throw ConflictException if user with email or operatorId exists', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(mockUser);

      await expect(
        usersService.create(
          {
            operatorId: 'OP-042',
            name: 'Officer Priya',
            email: 'priya@police.gov.in',
            password: 'Password123!',
          },
          'admin-id',
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should return list of safe user profiles', async () => {
      const result = await usersService.findAll({});
      expect(result.items).toHaveLength(1);
      expect(result.items[0].id).toBe(mockUser.id);
      expect(result.items[0]).not.toHaveProperty('passwordHash');
    });
  });

  describe('findById', () => {
    it('should return user profile if found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);
      const user = await usersService.findById(mockUser.id);
      expect(user.id).toBe(mockUser.id);
    });

    it('should throw NotFoundException if user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(usersService.findById('missing-id')).rejects.toThrow(NotFoundException);
    });
  });

  describe('update', () => {
    it('should update user fields and log audit event', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);
      mockPrisma.user.update.mockResolvedValue({
        ...mockUser,
        name: 'Officer Priya Sharma',
      });

      const updated = await usersService.update(
        mockUser.id,
        { name: 'Officer Priya Sharma' },
        'admin-id',
      );

      expect(updated.name).toBe('Officer Priya Sharma');
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.USER_UPDATED,
          userId: 'admin-id',
        }),
      );
    });
  });

  describe('deactivate', () => {
    it('should deactivate user, revoke all active sessions, and log audit event', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);

      await usersService.deactivate(mockUser.id, 'admin-id');

      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: mockUser.id },
        data: { isActive: false },
      });
      // All active sessions are revoked
      expect(mockPrisma.authSession.updateMany).toHaveBeenCalledWith({
        where: { userId: mockUser.id, revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.USER_DEACTIVATED,
          userId: 'admin-id',
          resourceId: mockUser.id,
        }),
      );
    });
  });
});
