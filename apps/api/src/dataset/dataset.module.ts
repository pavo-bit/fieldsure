import { Module } from '@nestjs/common';
import { DatasetService } from './dataset.service.js';
import { PrismaModule } from '../prisma/prisma.module.js';

@Module({
  imports: [PrismaModule],
  providers: [DatasetService],
  exports: [DatasetService],
})
export class DatasetModule {}
