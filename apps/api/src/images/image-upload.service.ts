import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';

const MAX_IMAGE_SIZE = 50 * 1024 * 1024; // 50 MB

// Magic bytes for supported image formats
const MAGIC_BYTES = {
  'image/jpeg': [
    [0xff, 0xd8, 0xff],
  ],
  'image/png': [
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
  ],
};

const ALLOWED_MIME_TYPES = Object.keys(MAGIC_BYTES);

export interface ImageValidationResult {
  buffer: Buffer;
  serverHash: string;
  mimeType: string;
  sizeBytes: number;
}

/**
 * Image upload validation service:
 * - Size check
 * - Magic byte validation
 * - SHA-256 hash computation
 * - Client hash verification
 */
@Injectable()
export class ImageUploadService {
  private readonly logger = new Logger(ImageUploadService.name);

  /**
   * Validate uploaded image and compute server-side hash.
   */
  validateImage(
    buffer: Buffer,
    declaredMimeType: string,
    clientHash?: string,
  ): ImageValidationResult {
    // Size check
    if (buffer.length > MAX_IMAGE_SIZE) {
      throw new AppError(
        ErrorCode.IMAGE_TOO_LARGE,
        `Image exceeds maximum size of ${MAX_IMAGE_SIZE} bytes`,
      );
    }

    // MIME type check
    if (!ALLOWED_MIME_TYPES.includes(declaredMimeType)) {
      throw new AppError(
        ErrorCode.UNSUPPORTED_IMAGE_TYPE,
        `Unsupported image type: ${declaredMimeType}. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`,
      );
    }

    // Magic byte validation
    const validMimeType = this.detectMimeType(buffer);
    if (!validMimeType) {
      throw new AppError(
        ErrorCode.UNSUPPORTED_IMAGE_TYPE,
        `Invalid image format: magic bytes do not match any supported type`,
      );
    }

    if (validMimeType !== declaredMimeType) {
      this.logger.warn(
        `MIME type mismatch: declared=${declaredMimeType}, detected=${validMimeType}`,
      );
      throw new AppError(
        ErrorCode.UNSUPPORTED_IMAGE_TYPE,
        `MIME type mismatch: declared ${declaredMimeType}, detected ${validMimeType}`,
      );
    }

    // Compute SHA-256
    const serverHash = this.computeHash(buffer);

    // Verify client hash if provided
    if (clientHash && clientHash !== serverHash) {
      this.logger.warn(
        `Hash mismatch: client=${clientHash}, server=${serverHash}`,
      );
      throw new AppError(
        ErrorCode.IMAGE_HASH_MISMATCH,
        `Client hash does not match server-computed hash`,
      );
    }

    return {
      buffer,
      serverHash,
      mimeType: validMimeType,
      sizeBytes: buffer.length,
    };
  }

  /**
   * Compute SHA-256 hash of buffer.
   */
  computeHash(buffer: Buffer): string {
    return createHash('sha256').update(buffer).digest('hex');
  }

  /**
   * Detect MIME type from magic bytes.
   */
  private detectMimeType(buffer: Buffer): string | null {
    for (const [mimeType, patterns] of Object.entries(MAGIC_BYTES)) {
      for (const pattern of patterns) {
        if (this.matchesMagicBytes(buffer, pattern)) {
          return mimeType;
        }
      }
    }
    return null;
  }

  /**
   * Check if buffer starts with given magic bytes.
   */
  private matchesMagicBytes(buffer: Buffer, pattern: number[]): boolean {
    if (buffer.length < pattern.length) return false;
    for (let i = 0; i < pattern.length; i++) {
      if (buffer[i] !== pattern[i]) return false;
    }
    return true;
  }
}
