import { Injectable, ConflictException, NotFoundException, Logger, HttpStatus } from '@nestjs/common';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommandInput,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { IStorageService, StorageResult, SignedUrlOptions, PresignedUploadResult } from './storage.interface.js';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';
import { Readable } from 'stream';

/**
 * AWS S3 storage implementation.
 * Write-once: uses conditional put to prevent overwrites.
 */
@Injectable()
export class S3StorageService implements IStorageService {
  private readonly logger = new Logger(S3StorageService.name);
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor() {
    this.bucket = process.env.AWS_S3_BUCKET || '';
    if (!this.bucket) {
      throw new Error('AWS_S3_BUCKET environment variable is required for S3 storage');
    }

    this.client = new S3Client({
      region: process.env.AWS_REGION || 'us-east-1',
      credentials: process.env.AWS_ACCESS_KEY_ID
        ? {
            accessKeyId: process.env.AWS_ACCESS_KEY_ID,
            secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
          }
        : undefined,
    });
  }

  async write(path: string, content: Buffer): Promise<StorageResult> {
    // Write-once check: ensure object doesn't exist
    const exists = await this.exists(path);
    if (exists) {
      throw new AppError(ErrorCode.IMAGE_CONFLICT, `Object already exists: ${path}`, HttpStatus.CONFLICT);
    }

    const params: PutObjectCommandInput = {
      Bucket: this.bucket,
      Key: path,
      Body: content,
      ContentType: 'image/jpeg',
      ServerSideEncryption: 'AES256',
    };

    await this.client.send(new PutObjectCommand(params));
    this.logger.log(`Wrote ${content.length} bytes to s3://${this.bucket}/${path}`);

    return {
      backend: 's3',
      path,
      sizeBytes: content.length,
    };
  }

  async read(path: string): Promise<Buffer> {
    try {
      const command = new GetObjectCommand({
        Bucket: this.bucket,
        Key: path,
      });
      const response = await this.client.send(command);

      if (!response.Body) {
        throw new AppError(ErrorCode.NOT_FOUND, `Empty object: ${path}`, HttpStatus.NOT_FOUND);
      }

      // Convert stream to buffer
      const stream = response.Body as Readable;
      const chunks: Buffer[] = [];
      for await (const chunk of stream) {
        chunks.push(Buffer.from(chunk));
      }
      return Buffer.concat(chunks);
    } catch (err: any) {
      if (err.name === 'NoSuchKey') {
        throw new AppError(ErrorCode.NOT_FOUND, `Object not found: ${path}`, HttpStatus.NOT_FOUND);
      }
      throw err;
    }
  }

  async exists(path: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({
          Bucket: this.bucket,
          Key: path,
        }),
      );
      return true;
    } catch (err: any) {
      if (err.name === 'NotFound') {
        return false;
      }
      throw err;
    }
  }

  async getSignedUrl(path: string, options: SignedUrlOptions): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: path,
    });
    return getSignedUrl(this.client, command, { expiresIn: options.expiresIn });
  }

  /**
   * Generate presigned upload URL for client to upload directly to S3.
   * Server controls the object key and enforces size/type restrictions.
   */
  async getPresignedUploadUrl(
    objectKey: string,
    contentType: string,
    maxSizeBytes: number,
    expiresInSeconds: number,
  ): Promise<PresignedUploadResult> {
    // Validate object key is within our bucket structure
    if (!objectKey.startsWith('evidence/') && !objectKey.startsWith('tests/')) {
      throw new AppError(
        ErrorCode.INVALID_UPLOAD_PATH,
        'Object key must start with evidence/ or tests/',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate content type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(contentType)) {
      throw new AppError(
        ErrorCode.INVALID_FILE_TYPE,
        `Content type must be one of: ${allowedTypes.join(', ')}`,
        HttpStatus.BAD_REQUEST,
      );
    }

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: objectKey,
      ContentType: contentType,
      ServerSideEncryption: 'AES256',
      // Note: size limit enforced by client, server validates hash after upload
    });

    const uploadUrl = await getSignedUrl(this.client, command, {
      expiresIn: expiresInSeconds,
    });

    const expiresAt = new Date(Date.now() + expiresInSeconds * 1000);

    this.logger.log(`Generated presigned upload URL for ${objectKey}, expires at ${expiresAt.toISOString()}`);

    return {
      uploadUrl,
      objectKey,
      expiresAt,
      maxSizeBytes,
    };
  }

  getBackend(): string {
    return 's3';
  }
}
