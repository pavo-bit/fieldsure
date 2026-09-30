import { Module } from '@nestjs/common';
import { CasesService } from './cases.service.js';
import { CasesController, SamplesController } from './cases.controller.js';
import { AuditModule } from '../audit/audit.module.js';

@Module({
  imports: [AuditModule],
  controllers: [CasesController, SamplesController],
  providers: [CasesService],
  exports: [CasesService],
})
export class CasesModule {}
