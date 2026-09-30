import { Module } from '@nestjs/common';
import { TestKitsService } from './test-kits.service.js';
import { TestKitsController } from './test-kits.controller.js';
import { AuditModule } from '../audit/audit.module.js';

@Module({
  imports: [AuditModule],
  controllers: [TestKitsController],
  providers: [TestKitsService],
  exports: [TestKitsService],
})
export class TestKitsModule {}
