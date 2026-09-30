import { NestFactory } from '@nestjs/core';
import { ValidationPipe, HttpStatus } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module.js';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter.js';
import { AppError } from './common/errors/app-error.js';
import { ErrorCode } from './common/errors/error-codes.js';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

/**
 * Validate required environment variables at startup.
 * Fail fast if critical configuration is missing.
 */
function validateEnv() {
  const required = [
    'DATABASE_URL',
    'JWT_ACCESS_SECRET',
    'JWT_REFRESH_SECRET',
  ];

  const isProduction = process.env['NODE_ENV'] === 'production';

  if (isProduction) {
    // In production, enforce strong secrets and no defaults
    const prodRequired = [
      ...required,
      'CORS_ORIGINS',
    ];

    for (const key of prodRequired) {
      if (!process.env[key]) {
        throw new Error(`Missing required environment variable: ${key}`);
      }
    }

    // Check that secrets are strong enough in production
    const accessSecret = process.env['JWT_ACCESS_SECRET'];
    const refreshSecret = process.env['JWT_REFRESH_SECRET'];

    if (accessSecret && accessSecret.length < 32) {
      throw new Error('JWT_ACCESS_SECRET must be at least 32 characters in production');
    }
    if (refreshSecret && refreshSecret.length < 32) {
      throw new Error('JWT_REFRESH_SECRET must be at least 32 characters in production');
    }
  } else {
    // In development, just check the basics
    for (const key of required) {
      if (!process.env[key]) {
        console.warn(`⚠️  Missing environment variable: ${key} (using default)`);
      }
    }
  }
}

async function bootstrap() {
  // Validate environment before starting
  validateEnv();

  const app = await NestFactory.create(AppModule);

  const isProduction = process.env['NODE_ENV'] === 'production';

  // OpenAPI / Swagger setup
  const config = new DocumentBuilder()
    .setTitle('FieldSure API')
    .setDescription('Production-grade API for colorimetric field drug testing')
    .setVersion('1.0')
    .addBearerAuth()
    .addServer('http://localhost:3000', 'Development')
    .addServer('https://api.fieldsure.example.com', 'Production')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api-docs', app, document);

  // Export OpenAPI spec if requested
  if (process.argv.includes('--export-openapi')) {
    fs.writeFileSync('./openapi.json', JSON.stringify(document, null, 2));
    console.log('✓ OpenAPI spec exported to openapi.json');
    process.exit(0);
  }

  // Security headers with HSTS
  app.use(
    helmet({
      hsts: isProduction
        ? { maxAge: 31536000, includeSubDomains: true, preload: true }
        : false,
    }),
  );

  // HTTPS enforcement in production
  if (isProduction) {
    app.use((req: any, res: any, next: any) => {
      if (req.headers['x-forwarded-proto'] !== 'https') {
        return res.redirect(301, `https://${req.headers.host}${req.url}`);
      }
      next();
    });
  }

  // CORS
  const corsOrigins = process.env['CORS_ORIGINS']?.split(',') ?? [
    'http://localhost:3000',
  ];

  // In production, no wildcards allowed
  if (isProduction && corsOrigins.some((o) => o === '*')) {
    throw new Error('CORS wildcard (*) is not allowed in production');
  }

  app.enableCors({
    origin: corsOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'X-App-Version'],
  });

  // X-Request-Id middleware (generate if not present)
  app.use((req: any, res: any, next: any) => {
    if (!req.headers['x-request-id']) {
      req.headers['x-request-id'] = uuidv4();
    }
    next();
  });

  // App version compatibility check
  const minAppVersion = process.env['MIN_APP_VERSION'];
  if (minAppVersion) {
    app.use((req: any, res: any, next: any) => {
      const appVersion = req.headers['x-app-version'];
      if (appVersion && compareVersions(appVersion, minAppVersion) < 0) {
        return res.status(426).json({
          error: {
            code: ErrorCode.APP_VERSION_TOO_OLD,
            message: `App version ${appVersion} is no longer supported. Please update to version ${minAppVersion} or later.`,
            status: 426,
          },
          meta: {
            timestamp: new Date().toISOString(),
            requestId: req.headers['x-request-id'],
          },
        });
      }
      next();
    });
  }

  // Global validation pipe — strict by default
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true, // Strict: reject unknown fields
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors) => {
        // Custom error formatting for validation errors
        const details = errors.map((e) => ({
          field: e.property,
          constraints: e.constraints,
        }));
        throw new AppError(
          ErrorCode.VALIDATION_FAILED,
          'Validation failed',
          HttpStatus.BAD_REQUEST,
          details,
        );
      },
    }),
  );

  // Global exception filter
  app.useGlobalFilters(new GlobalExceptionFilter());

  const port = process.env['PORT'] ?? 3000;
  await app.listen(port);
  console.log(`✓ FieldSure API running on http://localhost:${port}`);
  console.log(`✓ API Documentation: http://localhost:${port}/api-docs`);
  console.log(`✓ Environment: ${isProduction ? 'production' : 'development'}`);
  console.log(`✓ CORS origins: ${corsOrigins.join(', ')}`);
}

/**
 * Simple semver comparison.
 * Returns: -1 if a < b, 0 if equal, 1 if a > b
 */
function compareVersions(a: string, b: string): number {
  const aParts = a.split('.').map((n) => parseInt(n, 10) || 0);
  const bParts = b.split('.').map((n) => parseInt(n, 10) || 0);

  for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
    const aVal = aParts[i] || 0;
    const bVal = bParts[i] || 0;
    if (aVal < bVal) return -1;
    if (aVal > bVal) return 1;
  }

  return 0;
}

await bootstrap();
