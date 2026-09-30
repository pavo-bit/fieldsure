import { Module } from '@nestjs/common';
import { TestsController } from './tests.controller.js';
import { TestsService } from './tests.service.js';
import { TestStateMachineService } from './test-state-machine.service.js';
import { AuditModule } from '../audit/audit.module.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { StorageModule } from '../storage/storage.module.js';
import { ImagesModule } from '../images/images.module.js';
import { MLModule } from '../ml/ml.module.js';

@Module({
  imports: [AuditModule, StorageModule, ImagesModule, MLModule],
  controllers: [TestsController],
  providers: [TestsService, TestStateMachineService, OwnershipPolicy],
  exports: [TestsService],
})
export class TestsModule {}
