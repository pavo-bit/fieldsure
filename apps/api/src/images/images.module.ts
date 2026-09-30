import { Module } from '@nestjs/common';
import { ImageUploadService } from './image-upload.service.js';

@Module({
  providers: [ImageUploadService],
  exports: [ImageUploadService],
})
export class ImagesModule {}
