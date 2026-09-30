import { UserRole } from '@prisma/client';

/**
 * JWT access token payload.
 * Contains only what's needed for authorization decisions.
 */
export interface JwtPayload {
  /** User UUID */
  sub: string;
  /** User email */
  email: string;
  /** RBAC role */
  role: UserRole;
  /** Auth session UUID — for revocation checks */
  sessionId: string;
  /** Issued at (Unix timestamp) */
  iat?: number;
  /** Expiration (Unix timestamp) */
  exp?: number;
}

/**
 * Safe user response — never includes password hash or secrets.
 */
export interface UserResponse {
  id: string;
  operatorId: string;
  name: string;
  email: string;
  role: UserRole;
  isActive: boolean;
  lastLoginAt: string | null;
  createdAt: string;
}

/**
 * Login response returned to client.
 */
export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: UserResponse;
}
