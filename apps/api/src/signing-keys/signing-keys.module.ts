import { Module } from '@nestjs/common';
import { SigningKeysService } from './signing-keys.service.js';
import { PrismaModule } from '../prisma/prisma.module.js';

@Module({
  imports: [PrismaModule],
  providers: [SigningKeysService],
  exports: [SigningKeysService],
})
export class SigningKeysModule {}
