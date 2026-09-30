import { Controller, Get, Post, Param, UseGuards, HttpCode, HttpStatus, Req } from '@nestjs/common';
import type { Request } from 'express';
import { EvidenceService } from './evidence.service.js';
import { SigningKeysService } from '../signing-keys/signing-keys.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';

@Controller('api/v1/tests/:id/evidence')
@UseGuards(JwtAuthGuard)
export class EvidenceController {
  constructor(
    private readonly evidenceService: EvidenceService,
    private readonly signingKeys: SigningKeysService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async createEvidence(@Param('id') id: string, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.evidenceService.createEvidence(id, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  async getEvidence(@Param('id') id: string, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.evidenceService.getEvidence(id, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }
}

@Controller('api/v1/tests/:id/verify')
@UseGuards(JwtAuthGuard)
export class VerifyController {
  constructor(private readonly evidenceService: EvidenceService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  async verifyEvidence(@Param('id') id: string, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.evidenceService.verifyEvidence(id, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }
}

/**
 * Public endpoints for key distribution and verification.
 */
@Controller()
export class PublicEvidenceController {
  constructor(private readonly signingKeys: SigningKeysService) {}

  /**
   * JWKS endpoint (RFC 7517) for public key distribution.
   */
  @Get('.well-known/jwks.json')
  async getJWKS() {
    const keys = await this.signingKeys.getAllPublicKeys();
    const jwks = {
      keys: keys.map((key) => ({
        kid: key.kid,
        kty: 'RSA',
        use: 'sig',
        alg: key.algorithm,
        // In production: parse PEM to extract n (modulus) and e (exponent)
        // For now, return PEM in x5c format
        x5c: [key.publicKeyPem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\n/g, '')],
        status: key.status,
      })),
    };
    return jwks;
  }

  /**
   * Alternative: simple JSON format for public keys.
   */
  @Get('api/v1/evidence/public-keys')
  async getPublicKeys() {
    return this.signingKeys.getAllPublicKeys();
  }
}
