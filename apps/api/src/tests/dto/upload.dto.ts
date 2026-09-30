/**
 * DTOs for secure image upload workflow.
 */

import { IsString, IsIn, IsInt, Min, Max, IsOptional, Matches } from 'class-validator';

export class RequestUploadDto {
  @IsString()
  @IsIn(['image/jpeg', 'image/png', 'image/webp'])
  contentType: 'image/jpeg' | 'image/png' | 'image/webp';

  @IsInt()
  @Min(1024) // At least 1KB
  @Max(50 * 1024 * 1024) // Max 50MB
  fileSizeBytes: number;

  @IsString()
  @IsOptional()
  clientHash?: string; // SHA-256 hex hash of file content (client-computed)
}

export class UploadUrlResponse {
  uploadUrl: string;
  objectKey: string;
  expiresAt: string;
  maxSizeBytes: number;
}

export class CompleteUploadDto {
  @IsString()
  objectKey: string;

  @IsString()
  @Matches(/^[a-f0-9]{64}$/, { message: 'clientHash must be a valid SHA-256 hex string' })
  clientHash: string;

  @IsInt()
  @Min(1)
  actualSizeBytes: number;
}

export class CompleteUploadResponse {
  imageAssetId: string;
  serverHash: string;
  verified: boolean;
}
