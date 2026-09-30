import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuditModule } from './audit/audit.module.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { TestKitsModule } from './test-kits/test-kits.module.js';
import { TestsModule } from './tests/tests.module.js';
import { EvidenceModule } from './evidence/evidence.module.js';
import { HealthModule } from './health/health.module.js';
import { OrganizationsModule } from './organizations/organizations.module.js';
import { CasesModule } from './cases/cases.module.js';
import { ReviewsModule } from './reviews/reviews.module.js';
import { LabConfirmationsModule } from './lab-confirmations/lab-confirmations.module.js';
import { DatasetModule } from './dataset/dataset.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { CustomThrottlerGuard } from './common/guards/custom-throttler.guard.js';

@Module({
  imports: [
    // Load .env file
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../../.env'],
    }),

    // Rate limiting with named profiles
    ThrottlerModule.forRoot({
      throttlers: [
        {
          name: 'default',
          ttl: 60000,   // 1 minute window
          limit: 60,    // 60 requests per minute (general)
        },
        {
          name: 'auth',
          ttl: 900000,  // 15 minute window
          limit: 5,     // 5 auth attempts per 15 minutes
        },
        {
          name: 'sync',
          ttl: 60000,   // 1 minute window
          limit: 100,   // Higher limit for sync-critical endpoints
        },
      ],
    }),

    // Core modules
    PrismaModule,
    AuditModule,
    AuthModule,
    UsersModule,
    TestKitsModule,
    TestsModule,
    EvidenceModule,
    HealthModule,
    OrganizationsModule,
    CasesModule,
    ReviewsModule,
    LabConfirmationsModule,
    DatasetModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    // Global rate limiting guard (per-user tracking)
    {
      provide: APP_GUARD,
      useClass: CustomThrottlerGuard,
    },
  ],
})
export class AppModule {}
