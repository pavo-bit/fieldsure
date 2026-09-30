import { describe, it, expect, beforeEach, vi } from 'vitest';
import { UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { UserRole, AuditEventType } from '@prisma/client';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let authService: AuthService;
  let mockPrisma: any;
  let mockJwtService: any;
  let mockConfigService: any;
  let mockAuditService: any;

  const validPassword = 'ValidPassword123!';
  const realPasswordHash = bcrypt.hashSync(validPassword, 10);

  const mockUser = {
    id: '11111111-1111-1111-1111-111111111111',
    operatorId: 'OP-001',
    name: 'Inspector Vikram',
    email: 'vikram@police.gov.in',
    passwordHash: realPasswordHash,
    role: UserRole.OPERATOR,
    isActive: true,
    lastLoginAt: new Date('2026-01-01T00:00:00Z'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
  };

  beforeEach(() => {
    mockPrisma = {
      user: {
        findUnique: vi.fn(),
        update: vi.fn().mockResolvedValue(mockUser),
      },
      authSession: {
        create: vi.fn().mockResolvedValue({ id: 'sess-1' }),
        findMany: vi.fn().mockResolvedValue([]),
        findUnique: vi.fn(),
        update: vi.fn().mockResolvedValue({}),
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
    };

    mockJwtService = {
      sign: vi.fn().mockReturnValue('mock.jwt.token'),
    };

    mockConfigService = {
      get: vi.fn((key: string, defaultValue?: string) => {
        if (key === 'JWT_ACCESS_SECRET') return 'test-access-secret-key-123456';
        if (key === 'JWT_ACCESS_EXPIRES_IN') return '15m';
        if (key === 'JWT_REFRESH_EXPIRES_IN') return '7d';
        return defaultValue;
      }),
    };

    mockAuditService = {
      log: vi.fn().mockResolvedValue(undefined),
    };

    authService = new AuthService(
      mockPrisma,
      mockJwtService,
      mockConfigService,
      mockAuditService,
    );
  });

  describe('login', () => {
    it('should successfully authenticate user with valid credentials', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);

      const result = await authService.login(
        { email: 'vikram@police.gov.in', password: validPassword },
        '127.0.0.1',
        'MobileClient/1.0',
      );

      expect(result).toHaveProperty('accessToken', 'mock.jwt.token');
      expect(result).toHaveProperty('refreshToken');
      expect(result.user).toEqual({
        id: mockUser.id,
        operatorId: mockUser.operatorId,
        name: mockUser.name,
        email: mockUser.email,
        role: UserRole.OPERATOR,
        isActive: true,
        lastLoginAt: mockUser.lastLoginAt.toISOString(),
        createdAt: mockUser.createdAt.toISOString(),
      });
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.LOGIN,
          userId: mockUser.id,
        }),
      );
    });

    it('should throw UnauthorizedException when user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(
        authService.login({ email: 'unknown@police.gov.in', password: 'Pass' }, '127.0.0.1', 'MobileClient/1.0'),
      ).rejects.toThrow('Invalid credentials');

      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.LOGIN_FAILED,
        }),
      );
    });

    it('should throw ForbiddenException when user account is deactivated', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        ...mockUser,
        isActive: false,
      });

      await expect(
        authService.login({ email: 'vikram@police.gov.in', password: validPassword }, '127.0.0.1', 'MobileClient/1.0'),
      ).rejects.toThrow('Account is deactivated');

      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.LOGIN_FAILED,
          userId: mockUser.id,
        }),
      );
    });

    it('should throw UnauthorizedException when password does not match', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);

      await expect(
        authService.login({ email: 'vikram@police.gov.in', password: 'WrongPassword' }, '127.0.0.1', 'MobileClient/1.0'),
      ).rejects.toThrow('Invalid credentials');

      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.LOGIN_FAILED,
          userId: mockUser.id,
        }),
      );
    });
  });

  describe('refresh', () => {
    it('should rotate tokens for a valid refresh token', async () => {
      const rawRefreshToken = 'valid-refresh-token-uuid-12345';
      const mockSession = {
        id: 'session-uuid-1',
        userId: mockUser.id,
        refreshTokenHash: bcrypt.hashSync(rawRefreshToken, 10),
        expiresAt: new Date(Date.now() + 100000),
        revokedAt: null,
        user: mockUser,
      };

      mockPrisma.authSession.findMany.mockResolvedValue([mockSession]);
      

      const result = await authService.refresh(rawRefreshToken);

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      // Verifies session rotation: session updated with new rotatedAt
      expect(mockPrisma.authSession.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: mockSession.id },
          data: expect.objectContaining({
            rotatedAt: expect.any(Date),
            lastUsedAt: expect.any(Date),
          }),
        }),
      );
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.TOKEN_REFRESH,
          userId: mockUser.id,
        }),
      );
    });

    it('should reject invalid or unmatched refresh token', async () => {
      mockPrisma.authSession.findMany.mockResolvedValue([]);

      await expect(
        authService.refresh('unknown-refresh-token'),
      ).rejects.toThrow('Invalid or expired refresh token');
    });

    it('should reject refresh token for deactivated user', async () => {
      const rawRefreshToken = 'deactivated-user-refresh-token';
      const mockSession = {
        id: 'session-uuid-1',
        userId: mockUser.id,
        refreshTokenHash: bcrypt.hashSync(rawRefreshToken, 10),
        expiresAt: new Date(Date.now() + 100000),
        revokedAt: null,
        user: { ...mockUser, isActive: false },
      };

      mockPrisma.authSession.findMany.mockResolvedValue([mockSession]);
      

      await expect(
        authService.refresh(rawRefreshToken),
      ).rejects.toThrow('Account is deactivated');
    });
  });

  describe('logout', () => {
    it('should revoke all active sessions for the user', async () => {
      await authService.logout(mockUser.id, '127.0.0.1', 'MobileClient');

      expect(mockPrisma.authSession.updateMany).toHaveBeenCalledWith({
        where: { userId: mockUser.id, revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
      expect(mockAuditService.log).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: AuditEventType.LOGOUT,
          userId: mockUser.id,
        }),
      );
    });
  });

  describe('validateSession', () => {
    it('should return true for an active non-revoked session', async () => {
      mockPrisma.authSession.findUnique.mockResolvedValue({
        id: 'session-123',
        userId: mockUser.id,
        revokedAt: null,
        expiresAt: new Date(Date.now() + 60000),
        user: { isActive: true },
      });

      const valid = await authService.validateSession('session-123', mockUser.id);
      expect(valid).toBe(true);
    });

    it('should return false if session is revoked', async () => {
      mockPrisma.authSession.findUnique.mockResolvedValue({
        id: 'session-123',
        userId: mockUser.id,
        revokedAt: new Date(),
        expiresAt: new Date(Date.now() + 60000),
        user: { isActive: true },
      });

      const valid = await authService.validateSession('session-123', mockUser.id);
      expect(valid).toBe(false);
    });

    it('should return false if session does not exist', async () => {
      mockPrisma.authSession.findUnique.mockResolvedValue(null);

      const valid = await authService.validateSession('non-existent', mockUser.id);
      expect(valid).toBe(false);
    });
  });

  describe('getProfile', () => {
    it('should return safe user profile without password or secrets', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(mockUser);

      const profile = await authService.getProfile(mockUser.id);

      expect(profile).not.toHaveProperty('passwordHash');
      expect(profile).toHaveProperty('id', mockUser.id);
      expect(profile).toHaveProperty('operatorId', 'OP-001');
      expect(profile).toHaveProperty('role', UserRole.OPERATOR);
    });
  });
});
