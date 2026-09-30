import { Injectable, ConflictException, NotFoundException, Logger, HttpStatus } from '@nestjs/common';
import { promises as fs } from 'fs';
import { join, dirname } from 'path';
import { IStorageService, StorageResult, SignedUrlOptions, PresignedUploadResult } from './storage.interface.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';

/**
 * Local filesystem storage implementation.
 * Write-once: throws CONFLICT if path already exists.
 */
@Injectable()
export class LocalStorageService implements IStorageService {
  private readonly logger = new Logger(LocalStorageService.name);
  private readonly baseDir: string;

  constructor() {
    this.baseDir = process.env.STORAGE_LOCAL_PATH || './data/evidence';
  }

  async write(path: string, content: Buffer): Promise<StorageResult> {
    const fullPath = join(this.baseDir, path);

    // Write-once check
    try {
      await fs.access(fullPath);
      throw new AppError(ErrorCode.IMAGE_CONFLICT, `File already exists: ${path}`, HttpStatus.CONFLICT);
    } catch (err: any) {
      if (err.code !== 'ENOENT') throw err;
    }

    // Ensure parent directory exists
    await fs.mkdir(dirname(fullPath), { recursive: true });

    // Write atomically
    const tempPath = `${fullPath}.tmp`;
    await fs.writeFile(tempPath, content);
    await fs.rename(tempPath, fullPath);

    this.logger.log(`Wrote ${content.length} bytes to ${path}`);

    return {
      backend: 'local',
      path,
      sizeBytes: content.length,
    };
  }

  async read(path: string): Promise<Buffer> {
    const fullPath = join(this.baseDir, path);
    try {
      return await fs.readFile(fullPath);
    } catch (err: any) {
      if (err.code === 'ENOENT') {
        throw new AppError(ErrorCode.NOT_FOUND, `File not found: ${path}`, HttpStatus.NOT_FOUND);
      }
      throw err;
    }
  }

  async exists(path: string): Promise<boolean> {
    const fullPath = join(this.baseDir, path);
    try {
      await fs.access(fullPath);
      return true;
    } catch {
      return false;
    }
  }

  async getSignedUrl(_path: string, _options: SignedUrlOptions): Promise<string | null> {
    // Local storage doesn't support signed URLs
    return null;
  }

  async getPresignedUploadUrl(
    _objectKey: string,
    _contentType: string,
    _maxSizeBytes: number,
    _expiresInSeconds: number,
  ): Promise<PresignedUploadResult | null> {
    // Local storage doesn't support presigned uploads
    // Clients must use multipart upload endpoint instead
    return null;
  }

  getBackend(): string {
    return 'local';
  }
}
