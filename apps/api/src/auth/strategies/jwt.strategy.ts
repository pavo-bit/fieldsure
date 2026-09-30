import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService } from '../auth.service.js';
import type { JwtPayload } from '../interfaces/auth.interfaces.js';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private authService: AuthService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_ACCESS_SECRET', 'dev-secret-change-me'),
    });
  }

  /**
   * Called by Passport after JWT signature verification succeeds.
   * Validates the session is still active (not revoked/expired).
   */
  async validate(payload: JwtPayload): Promise<JwtPayload> {
    const isValid = await this.authService.validateSession(
      payload.sessionId,
      payload.sub,
    );

    if (!isValid) {
      throw new UnauthorizedException('Session expired or revoked');
    }

    return payload;
  }
}
