import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Guard that requires a valid JWT access token.
 * Delegates to JwtStrategy for validation.
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
