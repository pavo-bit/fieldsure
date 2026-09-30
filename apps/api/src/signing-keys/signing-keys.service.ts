import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { generateKeyPairSync } from 'crypto';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';

export interface SigningKeyPair {
  kid: string;
  publicKeyPem: string;
  privateKeyPem: string;
  algorithm: string;
}

/**
 * Signing key management with rotation support.
 * Loads active key on startup, supports manual rotation.
 */
@Injectable()
export class SigningKeysService implements OnModuleInit {
  private readonly logger = new Logger(SigningKeysService.name);
  private activeKey: SigningKeyPair | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    await this.loadActiveKey();
  }

  /**
   * Get the current active signing key.
   * Creates one if none exists.
   */
  async getActiveKey(): Promise<SigningKeyPair> {
    if (this.activeKey) return this.activeKey;

    await this.loadActiveKey();
    if (!this.activeKey) {
      throw new AppError(ErrorCode.SIGNING_KEY_NOT_FOUND, 'No active signing key available');
    }
    return this.activeKey;
  }

  /**
   * Get public key by kid (for verification).
   */
  async getPublicKey(kid: string): Promise<string> {
    const key = await this.prisma.signingKey.findUnique({
      where: { kid },
      select: { publicKeyPem: true },
    });

    if (!key) {
      throw new AppError(ErrorCode.SIGNING_KEY_NOT_FOUND, `Signing key not found: ${kid}`);
    }

    return key.publicKeyPem;
  }

  /**
   * Get all public keys for JWKS endpoint.
   */
  async getAllPublicKeys(): Promise<Array<{ kid: string; publicKeyPem: string; algorithm: string; status: string }>> {
    return this.prisma.signingKey.findMany({
      select: {
        kid: true,
        publicKeyPem: true,
        algorithm: true,
        status: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Rotate signing key: retire current, generate new.
   */
  async rotateKey(): Promise<SigningKeyPair> {
    // Retire current active key
    const currentActive = await this.prisma.signingKey.findFirst({
      where: { status: 'ACTIVE' },
    });

    if (currentActive) {
      await this.prisma.signingKey.update({
        where: { id: currentActive.id },
        data: {
          status: 'RETIRED',
          retiredAt: new Date(),
        },
      });
      this.logger.log(`Retired key ${currentActive.kid}`);
    }

    // Generate new key
    const newKey = await this.createKey();
    this.activeKey = newKey;
    this.logger.log(`Rotated to new key ${newKey.kid}`);

    return newKey;
  }

  /**
   * Load active key from database or create if missing.
   */
  private async loadActiveKey(): Promise<void> {
    const dbKey = await this.prisma.signingKey.findFirst({
      where: { status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });

    if (dbKey) {
      this.activeKey = {
        kid: dbKey.kid,
        publicKeyPem: dbKey.publicKeyPem,
        privateKeyPem: dbKey.privateKeyPem || '',
        algorithm: dbKey.algorithm,
      };
      this.logger.log(`Loaded active signing key: ${dbKey.kid}`);
    } else {
      this.logger.warn('No active signing key found, generating new one');
      this.activeKey = await this.createKey();
    }
  }

  /**
   * Generate RSA-2048 key pair and persist to DB.
   */
  private async createKey(): Promise<SigningKeyPair> {
    const { publicKey, privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });

    const kid = `key-${Date.now()}`;
    const algorithm = 'RS256';

    await this.prisma.signingKey.create({
      data: {
        kid,
        algorithm,
        publicKeyPem: publicKey,
        privateKeyPem: privateKey,
        status: 'ACTIVE',
      },
    });

    this.logger.log(`Created new signing key: ${kid}`);

    return {
      kid,
      publicKeyPem: publicKey,
      privateKeyPem: privateKey,
      algorithm,
    };
  }
}
