import { Module } from '@nestjs/common';
import { LabConfirmationsService } from './lab-confirmations.service.js';
import { LabConfirmationsController } from './lab-confirmations.controller.js';
import { AuditModule } from '../audit/audit.module.js';

@Module({
  imports: [AuditModule],
  controllers: [LabConfirmationsController],
  providers: [LabConfirmationsService],
  exports: [LabConfirmationsService],
})
export class LabConfirmationsModule {}
