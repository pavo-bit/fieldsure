/**
 * Storage service abstraction for evidence images.
 * Implementations: local filesystem, S3.
 */

export interface StorageResult {
  backend: string;
  path: string;
  sizeBytes: number;
}

export interface SignedUrlOptions {
  expiresIn: number; // seconds
}

export interface PresignedUploadResult {
  uploadUrl: string;
  objectKey: string;
  expiresAt: Date;
  maxSizeBytes: number;
}

export interface IStorageService {
  /**
   * Write binary content to storage (write-once).
   * @throws ConflictException if path already exists
   */
  write(path: string, content: Buffer): Promise<StorageResult>;

  /**
   * Read binary content from storage.
   * @throws NotFoundException if path doesn't exist
   */
  read(path: string): Promise<Buffer>;

  /**
   * Check if path exists.
   */
  exists(path: string): Promise<boolean>;

  /**
   * Generate signed URL for temporary read access (S3 only, local returns null).
   */
  getSignedUrl(path: string, options: SignedUrlOptions): Promise<string | null>;

  /**
   * Generate presigned upload URL for client to upload directly to storage.
   * Returns null for local storage (must use multipart endpoint instead).
   */
  getPresignedUploadUrl(
    objectKey: string,
    contentType: string,
    maxSizeBytes: number,
    expiresInSeconds: number,
  ): Promise<PresignedUploadResult | null>;

  /**
   * Backend identifier (local, s3).
   */
  getBackend(): string;
}
