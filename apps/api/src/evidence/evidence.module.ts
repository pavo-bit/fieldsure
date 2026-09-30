import { Module } from '@nestjs/common';
import { EvidenceService } from './evidence.service.js';
import { SignerService } from './signer.service.js';
import { TimestampService } from './timestamp.service.js';
import { EvidenceController, VerifyController, PublicEvidenceController } from './evidence.controller.js';
import { PrismaModule } from '../prisma/prisma.module.js';
import { AuditModule } from '../audit/audit.module.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { SigningKeysModule } from '../signing-keys/signing-keys.module.js';
import { StorageModule } from '../storage/storage.module.js';

@Module({
  imports: [PrismaModule, AuditModule, SigningKeysModule, StorageModule],
  controllers: [EvidenceController, VerifyController, PublicEvidenceController],
  providers: [EvidenceService, SignerService, TimestampService, OwnershipPolicy],
  exports: [EvidenceService],
})
export class EvidenceModule {}
