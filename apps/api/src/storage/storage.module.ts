import { Module } from '@nestjs/common';
import { LocalStorageService } from './local-storage.service.js';
import { S3StorageService } from './s3-storage.service.js';
import type { IStorageService } from './storage.interface.js';

/**
 * Storage backend selection based on STORAGE_BACKEND env var.
 * Defaults to 'local' if not specified or invalid.
 */
const STORAGE_BACKEND = process.env.STORAGE_BACKEND?.toLowerCase() || 'local';

@Module({
  providers: [
    {
      provide: 'IStorageService',
      useFactory: (): IStorageService => {
        if (STORAGE_BACKEND === 's3') {
          return new S3StorageService();
        }
        return new LocalStorageService();
      },
    },
  ],
  exports: ['IStorageService'],
})
export class StorageModule {}
