import { Controller, Get, HttpStatus } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { ConfigService } from '@nestjs/config';

/**
 * Health check endpoints for liveness and readiness probes.
 * Unauthenticated — no sensitive information exposed.
 */
@Controller()
export class HealthController {
  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {}

  /**
   * Liveness probe: is the application running?
   * Returns 200 if the process is alive.
   */
  @Get('health')
  async health() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Readiness probe: is the application ready to serve traffic?
   * Checks DB connectivity and ML service availability.
   */
  @Get('ready')
  async ready() {
    const checks: Record<string, string> = {};

    // Check database
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      checks.database = 'ok';
    } catch {
      checks.database = 'unavailable';
    }

    // Check ML service (non-blocking, quick health check)
    try {
      const mlServiceUrl = this.config.get<string>('ML_SERVICE_URL');
      if (mlServiceUrl) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 2000); // 2s timeout
        const response = await fetch(`${mlServiceUrl}/health`, {
          signal: controller.signal,
        });
        clearTimeout(timeoutId);
        checks.mlService = response.ok ? 'ok' : 'unavailable';
      } else {
        checks.mlService = 'not_configured';
      }
    } catch {
      checks.mlService = 'unavailable';
    }

    const allReady = Object.values(checks).every((v) => v === 'ok' || v === 'not_configured');
    const status = allReady ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;

    return {
      status: allReady ? 'ready' : 'not_ready',
      checks,
      timestamp: new Date().toISOString(),
    };
  }
}
