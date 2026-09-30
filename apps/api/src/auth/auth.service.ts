import {
  Injectable,
  UnauthorizedException,
  ForbiddenException,
  HttpStatus,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { AuditEventType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { AppError } from '../common/errors/app-error.js';
import type {
  JwtPayload,
  AuthResponse,
  UserResponse,
} from './interfaces/auth.interfaces.js';
import type { LoginDto, ChangePasswordDto } from './dto/auth.dto.js';

const BCRYPT_ROUNDS = 12;
const GRACE_WINDOW_MS = 30 * 1000; // 30 seconds
const SESSION_CACHE_TTL_MS = 30 * 1000; // 30 seconds
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes

interface SessionCacheEntry {
  isValid: boolean;
  isActive: boolean;
  timestamp: number;
}

@Injectable()
export class AuthService {
  private sessionCache = new Map<string, SessionCacheEntry>();

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private auditService: AuditService,
  ) {}

  /**
   * Password policy validation.
   */
  private validatePasswordPolicy(password: string): void {
    if (password.length < 8) {
      throw new AppError(
        ErrorCode.AUTH_PASSWORD_POLICY,
        'Password must be at least 8 characters',
        HttpStatus.BAD_REQUEST,
      );
    }
    // Add more policy checks as needed (uppercase, numbers, special chars, etc.)
  }

  /**
   * Authenticate user with email/password.
   * Returns access token, refresh token, and safe user data.
   * Enforces account lockout after MAX_FAILED_ATTEMPTS.
   */
  async login(
    dto: LoginDto,
    ipAddress?: string,
    userAgent?: string,
    requestId?: string,
  ): Promise<AuthResponse> {
    // Find user by email
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user) {
      await this.auditService.log({
        eventType: AuditEventType.LOGIN_FAILED,
        details: { email: dto.email, reason: 'User not found' } as unknown as Prisma.InputJsonValue,
        ipAddress,
        userAgent,
        requestId,
      });
      throw new AppError(
        ErrorCode.AUTH_INVALID_CREDENTIALS,
        'Invalid credentials',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Check if account is locked
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const remainingMs = user.lockedUntil.getTime() - Date.now();
      const remainingMin = Math.ceil(remainingMs / 60000);
      await this.auditService.log({
        eventType: AuditEventType.LOGIN_FAILED,
        userId: user.id,
        details: {
          reason: 'Account locked',
          lockedUntil: user.lockedUntil.toISOString(),
        } as unknown as Prisma.InputJsonValue,
        ipAddress,
        userAgent,
        requestId,
      });
      throw new AppError(
        ErrorCode.AUTH_ACCOUNT_LOCKED,
        `Account is locked. Try again in ${remainingMin} minutes.`,
        HttpStatus.FORBIDDEN,
      );
    }

    // Check if user is active
    if (!user.isActive) {
      await this.auditService.log({
        eventType: AuditEventType.LOGIN_FAILED,
        userId: user.id,
        details: { reason: 'Account deactivated' } as unknown as Prisma.InputJsonValue,
        ipAddress,
        userAgent,
        requestId,
      });
      throw new AppError(
        ErrorCode.AUTH_ACCOUNT_DEACTIVATED,
        'Account is deactivated',
        HttpStatus.FORBIDDEN,
      );
    }

    // Verify password
    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordValid) {
      // Increment failed login attempts
      const newFailedAttempts = user.failedLoginAttempts + 1;
      const updateData: Prisma.UserUpdateInput = {
        failedLoginAttempts: newFailedAttempts,
      };

      // Lock account if threshold reached
      if (newFailedAttempts >= MAX_FAILED_ATTEMPTS) {
        updateData.lockedUntil = new Date(Date.now() + LOCKOUT_DURATION_MS);
        await this.auditService.log({
          eventType: AuditEventType.ACCOUNT_LOCKED,
          userId: user.id,
          details: {
            failedAttempts: newFailedAttempts,
            lockedUntil: updateData.lockedUntil,
          } as unknown as Prisma.InputJsonValue,
          ipAddress,
          userAgent,
          requestId,
        });
      }

      await this.prisma.user.update({
        where: { id: user.id },
        data: updateData,
      });

      await this.auditService.log({
        eventType: AuditEventType.LOGIN_FAILED,
        userId: user.id,
        details: {
          reason: 'Invalid password',
          failedAttempts: newFailedAttempts,
        } as unknown as Prisma.InputJsonValue,
        ipAddress,
        userAgent,
        requestId,
      });

      throw new AppError(
        ErrorCode.AUTH_INVALID_CREDENTIALS,
        'Invalid credentials',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Check mustChangePassword flag
    if (user.mustChangePassword) {
      throw new AppError(
        ErrorCode.AUTH_MUST_CHANGE_PASSWORD,
        'You must change your password before continuing',
        HttpStatus.FORBIDDEN,
      );
    }

    // Reset failed attempts and unlock on successful login
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginAttempts: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
      },
    });

    // Generate tokens with a new family
    const tokenFamily = uuidv4();
    const { accessToken, refreshToken, sessionId } = await this.generateTokens(
      user.id,
      user.email,
      user.role,
      tokenFamily,
    );

    // Store hashed refresh token
    const refreshTokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);
    const refreshExpiresIn = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');

    await this.prisma.authSession.create({
      data: {
        id: sessionId,
        userId: user.id,
        tokenFamily,
        refreshTokenHash,
        familySequence: 1,
        ipAddress,
        userAgent,
        expiresAt: this.computeExpiry(refreshExpiresIn),
      },
    });

    // Audit
    await this.auditService.log({
      eventType: AuditEventType.LOGIN,
      userId: user.id,
      ipAddress,
      userAgent,
      requestId,
    });

    return {
      accessToken,
      refreshToken,
      user: this.toUserResponse(user),
    };
  }

  /**
   * Refresh access token using a valid refresh token.
   * Implements token rotation with family tracking and reuse detection.
   * Grace window prevents race conditions from locking users out.
   */
  async refresh(
    refreshToken: string,
    ipAddress?: string,
    userAgent?: string,
    requestId?: string,
  ): Promise<AuthResponse> {
    // Find all sessions in the database
    const sessions = await this.prisma.authSession.findMany({
      where: {
        expiresAt: { gt: new Date() },
      },
      include: { user: true },
    });

    // Check each session's hashed token
    let matchedSession: (typeof sessions)[number] | null = null;
    for (const session of sessions) {
      const isMatch = await bcrypt.compare(refreshToken, session.refreshTokenHash);
      if (isMatch) {
        matchedSession = session;
        break;
      }
    }

    if (!matchedSession) {
      throw new AppError(
        ErrorCode.AUTH_SESSION_EXPIRED,
        'Invalid or expired refresh token',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Check if session is revoked
    if (matchedSession.revokedAt) {
      throw new AppError(
        ErrorCode.AUTH_SESSION_REVOKED,
        'Session has been revoked',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Check if user is active
    if (!matchedSession.user.isActive) {
      throw new AppError(
        ErrorCode.AUTH_ACCOUNT_DEACTIVATED,
        'Account is deactivated',
        HttpStatus.FORBIDDEN,
      );
    }

    // Reuse detection: check if this session was already rotated
    if (matchedSession.rotatedAt) {
      const timeSinceRotation = Date.now() - matchedSession.rotatedAt.getTime();

      if (timeSinceRotation > GRACE_WINDOW_MS) {
        // Rotated token replayed outside grace window — revoke entire family
        await this.prisma.authSession.updateMany({
          where: {
            tokenFamily: matchedSession.tokenFamily,
            revokedAt: null,
          },
          data: { revokedAt: new Date() },
        });

        await this.auditService.log({
          eventType: AuditEventType.TOKEN_FAMILY_COMPROMISED,
          userId: matchedSession.user.id,
          details: {
            tokenFamily: matchedSession.tokenFamily,
            reason: 'Rotated token reused outside grace window',
          } as unknown as Prisma.InputJsonValue,
          ipAddress,
          userAgent,
          requestId,
        });

        throw new AppError(
          ErrorCode.AUTH_TOKEN_FAMILY_COMPROMISED,
          'Token reuse detected. All sessions have been revoked for security.',
          HttpStatus.UNAUTHORIZED,
        );
      }

      // Within grace window — allow replay, return the next session in the family
      const nextSession = await this.prisma.authSession.findFirst({
        where: {
          tokenFamily: matchedSession.tokenFamily,
          familySequence: matchedSession.familySequence + 1,
          revokedAt: null,
        },
        include: { user: true },
      });

      if (nextSession) {
        // Return existing rotated session (graceful handling of lost response)
        const accessToken = this.jwtService.sign(
          {
            sub: nextSession.user.id,
            email: nextSession.user.email,
            role: nextSession.user.role,
            sessionId: nextSession.id,
          } as JwtPayload,
          {
            secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
            expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '15m') as any,
          },
        );

        // Decode the stored hash to get the refresh token (we can't, so regenerate)
        // Actually, we need to store the token temporarily or return the same one
        // For simplicity in grace window, generate new token family continuation
        const newRefreshToken = uuidv4();
        const newRefreshTokenHash = await bcrypt.hash(newRefreshToken, BCRYPT_ROUNDS);

        await this.prisma.authSession.update({
          where: { id: nextSession.id },
          data: { refreshTokenHash: newRefreshTokenHash },
        });

        return {
          accessToken,
          refreshToken: newRefreshToken,
          user: this.toUserResponse(nextSession.user),
        };
      }
    }

    // Mark current session as rotated (not revoked)
    await this.prisma.authSession.update({
      where: { id: matchedSession.id },
      data: {
        rotatedAt: new Date(),
        lastUsedAt: new Date(),
      },
    });

    // Generate new tokens (same family, next sequence)
    const { accessToken, refreshToken: newRefreshToken, sessionId } = await this.generateTokens(
      matchedSession.user.id,
      matchedSession.user.email,
      matchedSession.user.role,
      matchedSession.tokenFamily,
    );

    // Store new hashed refresh token
    const refreshTokenHash = await bcrypt.hash(newRefreshToken, BCRYPT_ROUNDS);
    const refreshExpiresIn = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');

    await this.prisma.authSession.create({
      data: {
        id: sessionId,
        userId: matchedSession.user.id,
        tokenFamily: matchedSession.tokenFamily,
        familySequence: matchedSession.familySequence + 1,
        refreshTokenHash,
        ipAddress,
        userAgent,
        expiresAt: this.computeExpiry(refreshExpiresIn),
      },
    });

    // Clear cache for this family
    this.sessionCache.delete(matchedSession.id);

    // Audit
    await this.auditService.log({
      eventType: AuditEventType.TOKEN_REFRESH,
      userId: matchedSession.user.id,
      ipAddress,
      userAgent,
      requestId,
    });

    return {
      accessToken,
      refreshToken: newRefreshToken,
      user: this.toUserResponse(matchedSession.user),
    };
  }

  /**
   * Logout — revoke current session or all sessions for the user.
   * Idempotent — succeeds even if session already revoked.
   */
  async logout(
    userId: string,
    sessionId: string,
    allDevices: boolean = false,
    ipAddress?: string,
    userAgent?: string,
    requestId?: string,
  ): Promise<void> {
    if (allDevices) {
      // Revoke all sessions for the user
      await this.prisma.authSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      // Revoke only the current session
      await this.prisma.authSession.updateMany({
        where: { id: sessionId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    // Clear cache
    this.sessionCache.delete(sessionId);

    await this.auditService.log({
      eventType: AuditEventType.LOGOUT,
      userId,
      details: { allDevices } as unknown as Prisma.InputJsonValue,
      ipAddress,
      userAgent,
      requestId,
    });
  }

  /**
   * Get current user profile (safe data only).
   */
  async getProfile(userId: string): Promise<UserResponse> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user || !user.isActive) {
      throw new AppError(
        ErrorCode.AUTH_ACCOUNT_DEACTIVATED,
        'User not found or deactivated',
        HttpStatus.UNAUTHORIZED,
      );
    }

    return this.toUserResponse(user);
  }

  /**
   * Change password for authenticated user.
   */
  async changePassword(
    userId: string,
    dto: ChangePasswordDto,
    ipAddress?: string,
    userAgent?: string,
    requestId?: string,
  ): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new AppError(ErrorCode.USER_NOT_FOUND, 'User not found', 404);
    }

    // Verify current password
    const passwordValid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!passwordValid) {
      throw new AppError(
        ErrorCode.AUTH_INVALID_CURRENT_PASSWORD,
        'Current password is incorrect',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Validate new password policy
    this.validatePasswordPolicy(dto.newPassword);

    // Hash new password
    const newPasswordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);

    // Update password and clear mustChangePassword flag
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newPasswordHash,
        mustChangePassword: false,
      },
    });

    // Revoke all existing sessions (force re-login everywhere)
    await this.prisma.authSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    await this.auditService.log({
      eventType: AuditEventType.PASSWORD_CHANGED,
      userId,
      ipAddress,
      userAgent,
      requestId,
    });
  }

  /**
   * Validate that a JWT session is still active (not revoked).
   * Called by JwtStrategy on every authenticated request.
   * Uses a brief cache (30s TTL) to reduce DB load.
   */
  async validateSession(sessionId: string, userId: string): Promise<boolean> {
    // Check cache first
    const cached = this.sessionCache.get(sessionId);
    if (cached && Date.now() - cached.timestamp < SESSION_CACHE_TTL_MS) {
      return cached.isValid && cached.isActive;
    }

    const session = await this.prisma.authSession.findUnique({
      where: { id: sessionId },
      include: { user: { select: { isActive: true } } },
    });

    if (!session) {
      this.sessionCache.set(sessionId, { isValid: false, isActive: false, timestamp: Date.now() });
      return false;
    }
    if (session.userId !== userId) {
      this.sessionCache.set(sessionId, { isValid: false, isActive: false, timestamp: Date.now() });
      return false;
    }
    if (session.revokedAt || session.expiresAt < new Date()) {
      this.sessionCache.set(sessionId, { isValid: false, isActive: false, timestamp: Date.now() });
      return false;
    }
    if (!session.user.isActive) {
      this.sessionCache.set(sessionId, { isValid: false, isActive: false, timestamp: Date.now() });
      return false;
    }

    this.sessionCache.set(sessionId, { isValid: true, isActive: true, timestamp: Date.now() });
    return true;
  }

  // ---- Private helpers ----

  private async generateTokens(
    userId: string,
    email: string,
    role: string,
    tokenFamily: string,
  ) {
    const sessionId = uuidv4();
    const payload: JwtPayload = {
      sub: userId,
      email,
      role: role as JwtPayload['role'],
      sessionId,
    };

    const accessExpiresIn = this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '15m');

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: accessExpiresIn as any,
    });

    // Refresh token is a random UUID — the actual security is the bcrypt hash in DB
    const refreshToken = uuidv4();

    return { accessToken, refreshToken, sessionId };
  }

  private toUserResponse(user: {
    id: string;
    operatorId: string;
    name: string;
    email: string;
    role: string;
    isActive: boolean;
    mustChangePassword: boolean;
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

  private computeExpiry(duration: string): Date {
    const match = duration.match(/^(\d+)([smhd])$/);
    if (!match) return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // default 7d

    const value = parseInt(match[1], 10);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };

    return new Date(Date.now() + value * (multipliers[unit] ?? 0));
  }
}
