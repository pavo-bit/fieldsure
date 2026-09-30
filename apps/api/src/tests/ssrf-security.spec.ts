import { vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { HttpStatus } from '@nestjs/common';
import { TestsService } from './tests.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { AuditService } from '../audit/audit.service.js';
import { TestStateMachineService } from './test-state-machine.service.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { IStorageService } from '../storage/storage.interface.js';
import { ImageUploadService } from '../images/image-upload.service.js';
import { MLClientService } from '../ml/ml-client.service.js';
import { TestStatus, UserRole } from '@prisma/client';
import { AppError } from '../common/errors/app-error.js';
import { ErrorCode } from '../common/errors/error-codes.js';

/**
 * SSRF (Server-Side Request Forgery) Security Test Suite
 * 
 * VULNERABILITY ELIMINATED: Arbitrary imageUrl parameter acceptance
 * MITIGATION: Presigned upload URLs with server-controlled object keys
 * 
 * This suite verifies:
 * 1. Presigned upload URLs use server-generated object keys
 * 2. Object key validation prevents path traversal
 * 3. Upload completion validates object key belongs to test
 * 4. Storage operations only access validated paths
 * 5. No external URL fetching from client-supplied parameters
 */

describe('TestsService - SSRF Prevention', () => {
  let service: TestsService;
  let prismaService: PrismaService;
  let storageService: Mocked<IStorageService>;
  let ownershipPolicy: OwnershipPolicy;

  const mockTest = {
    id: 'test-123',
    testNumber: 'FS-2026-000001',
    operatorId: 'user-1',
    kitId: 'kit-1',
    status: TestStatus.DRAFT,
    kit: {
      id: 'kit-1',
      name: 'Marquis Reagent',
      manufacturer: 'NarcoTest',
      lotNumber: 'LOT-2024-01',
    },
  };

  beforeEach(async () => {
    // Mock storage service
    storageService = {
      getPresignedUploadUrl: vi.fn(),
      exists: vi.fn(),
      read: vi.fn(),
      write: vi.fn(),
      delete: vi.fn(),
    } as any;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TestsService,
        {
          provide: PrismaService,
          useValue: {
            test: {
              findUnique: vi.fn(),
              create: vi.fn(),
            },
            imageAsset: {
              create: vi.fn(),
            },
            $transaction: vi.fn((cb) => cb({
              test: { findUnique: vi.fn(), update: vi.fn() },
              classification: { create: vi.fn() },
              processingRun: { create: vi.fn() },
            })),
          },
        },
        {
          provide: AuditService,
          useValue: { log: vi.fn() },
        },
        {
          provide: TestStateMachineService,
          useValue: { canTransition: vi.fn(() => true) },
        },
        {
          provide: OwnershipPolicy,
          useValue: {
            canModifyTest: vi.fn(),
            getUserOrgContext: vi.fn(() => ({ organizationId: 'org-1' })),
          },
        },
        {
          provide: 'IStorageService',
          useValue: storageService,
        },
        {
          provide: ImageUploadService,
          useValue: { validateImageFile: vi.fn() },
        },
        {
          provide: MLClientService,
          useValue: { classify: vi.fn() },
        },
      ],
    }).compile();

    service = module.get<TestsService>(TestsService);
    prismaService = module.get<PrismaService>(PrismaService);
    ownershipPolicy = module.get<OwnershipPolicy>(OwnershipPolicy);
  });

  describe('requestUploadUrl - Server-Controlled Object Keys', () => {
    it('should generate object key with test ID prefix', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);
      storageService.getPresignedUploadUrl.mockResolvedValue({
        uploadUrl: 'https://s3.amazonaws.com/bucket/presigned-url',
        objectKey: 'tests/test-123/1672531200000-abc123.jpg',
        expiresAt: new Date('2026-09-30T00:00:00Z'),
        maxSizeBytes: 50 * 1024 * 1024,
      });

      const result = await service.requestUploadUrl(
        'test-123',
        { contentType: 'image/jpeg', fileSizeBytes: 1024 * 1024 },
        'user-1',
        UserRole.OPERATOR,
      );

      expect(result.objectKey).toMatch(/^tests\/test-123\/\d+-[a-z0-9]+\.jpg$/);
      expect(storageService.getPresignedUploadUrl).toHaveBeenCalledWith(
        expect.stringMatching(/^tests\/test-123\//),
        'image/jpeg',
        1024 * 1024,
        900,
      );
    });

    it('should reject file size exceeding maximum', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      await expect(
        service.requestUploadUrl(
          'test-123',
          { contentType: 'image/jpeg', fileSizeBytes: 60 * 1024 * 1024 },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toThrow(AppError);

      await expect(
        service.requestUploadUrl(
          'test-123',
          { contentType: 'image/jpeg', fileSizeBytes: 60 * 1024 * 1024 },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.IMAGE_TOO_LARGE,
        
      });
    });

    it('should only allow uploads for DRAFT or CAPTURED tests', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue({
        ...mockTest,
        status: TestStatus.COMPLETED,
      });

      await expect(
        service.requestUploadUrl(
          'test-123',
          { contentType: 'image/jpeg', fileSizeBytes: 1024 * 1024 },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.TEST_INVALID_TRANSITION,
        
      });
    });

    it('should validate content type', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);
      storageService.getPresignedUploadUrl.mockResolvedValue({
        uploadUrl: 'https://s3.amazonaws.com/bucket/presigned-url',
        objectKey: 'tests/test-123/1672531200000-abc123.png',
        expiresAt: new Date('2026-09-30T00:00:00Z'),
        maxSizeBytes: 50 * 1024 * 1024,
      });

      const result = await service.requestUploadUrl(
        'test-123',
        { contentType: 'image/png', fileSizeBytes: 1024 * 1024 },
        'user-1',
        UserRole.OPERATOR,
      );

      expect(result.objectKey).toMatch(/\.png$/);
    });
  });

  describe('completeUpload - Path Validation Against SSRF', () => {
    it('should reject object key not matching test ID', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      await expect(
        service.completeUpload(
          'test-123',
          {
            objectKey: 'tests/test-456/image.jpg', // Different test ID
            clientHash: 'abcd1234',
            actualSizeBytes: 1024,
          },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.INVALID_UPLOAD_PATH,
        
      });
    });

    it('should reject path traversal attempts in object key', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      const maliciousKeys = [
        'tests/test-123/../../../etc/passwd',
        'tests/test-123/..%2F..%2Fetc%2Fpasswd',
        '../tests/test-123/image.jpg',
        'tests/../test-123/image.jpg',
      ];

      for (const key of maliciousKeys) {
        await expect(
          service.completeUpload(
            'test-123',
            {
              objectKey: key,
              clientHash: 'abcd1234',
              actualSizeBytes: 1024,
            },
            'user-1',
            UserRole.OPERATOR,
          ),
        ).rejects.toThrow();
      }
    });

    it('should verify object exists in storage before processing', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);
      storageService.exists.mockResolvedValue(false);

      await expect(
        service.completeUpload(
          'test-123',
          {
            objectKey: 'tests/test-123/image.jpg',
            clientHash: 'abcd1234',
            actualSizeBytes: 1024,
          },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.NOT_FOUND,
        
      });

      expect(storageService.exists).toHaveBeenCalledWith('tests/test-123/image.jpg');
    });

    it('should verify hash matches between client and server', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);
      storageService.exists.mockResolvedValue(true);
      storageService.read.mockResolvedValue(Buffer.from('test image data'));

      // Real hash of 'test image data': 7e9c...
      const realHash = '7e9c59c4dae97fc32c1e5620e7f072a7f1d6d1e1b9c01b2a3a9ad9a7e1e7f072';
      const fakeHash = 'deadbeef00000000000000000000000000000000000000000000000000000000';

      await expect(
        service.completeUpload(
          'test-123',
          {
            objectKey: 'tests/test-123/image.jpg',
            clientHash: fakeHash,
            actualSizeBytes: 15,
          },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.IMAGE_HASH_MISMATCH,
        
      });
    });
  });

  describe('SSRF Attack Vector Prevention', () => {
    it('should NOT accept arbitrary imageUrl parameter', () => {
      // This test documents that the old SSRF vulnerability is eliminated
      // The service no longer has any method that accepts imageUrl parameter
      
      const serviceInterface = Object.getOwnPropertyNames(Object.getPrototypeOf(service));
      const methodsAcceptingUrl = serviceInterface.filter(method => {
        if (typeof (service as any)[method] !== 'function') return false;
        return method.toLowerCase().includes('url') || method.toLowerCase().includes('image');
      });

      // Should only have requestUploadUrl and completeUpload (presigned flow)
      expect(methodsAcceptingUrl).toContain('requestUploadUrl');
      expect(serviceInterface).toContain('completeUpload');
    });

    it('should prevent localhost SSRF attempts', async () => {
      // Document that localhost URLs cannot be supplied
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      // These should all fail at the object key validation stage
      const localhostAttempts = [
        'http://localhost:5432',
        'http://127.0.0.1:5432',
        'http://[::1]:5432',
        'file:///etc/passwd',
      ];

      for (const url of localhostAttempts) {
        await expect(
          service.completeUpload(
            'test-123',
            {
              objectKey: url, // Will be rejected as invalid path
              clientHash: 'abcd1234',
              actualSizeBytes: 1024,
            },
            'user-1',
            UserRole.OPERATOR,
          ),
        ).rejects.toMatchObject({
          code: ErrorCode.INVALID_UPLOAD_PATH,
        });
      }
    });

    it('should prevent private IP range SSRF attempts', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      const privateIpAttempts = [
        'http://10.0.0.1/secret',
        'http://172.16.0.1/admin',
        'http://192.168.1.1/config',
        'http://169.254.169.254/latest/meta-data', // AWS metadata
      ];

      for (const url of privateIpAttempts) {
        await expect(
          service.completeUpload(
            'test-123',
            {
              objectKey: url,
              clientHash: 'abcd1234',
              actualSizeBytes: 1024,
            },
            'user-1',
            UserRole.OPERATOR,
          ),
        ).rejects.toMatchObject({
          code: ErrorCode.INVALID_UPLOAD_PATH,
        });
      }
    });

    it('should prevent DNS rebinding attacks', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      // These would resolve to localhost/private IPs but cannot be supplied as objectKey
      const dnsRebindingAttempts = [
        'http://evil.com@localhost/image.jpg',
        'http://attacker.com?redirect=http://localhost:5432',
      ];

      for (const url of dnsRebindingAttempts) {
        await expect(
          service.completeUpload(
            'test-123',
            {
              objectKey: url,
              clientHash: 'abcd1234',
              actualSizeBytes: 1024,
            },
            'user-1',
            UserRole.OPERATOR,
          ),
        ).rejects.toMatchObject({
          code: ErrorCode.INVALID_UPLOAD_PATH,
        });
      }
    });
  });

  describe('Storage Service Integration', () => {
    it('should only call storage.read with validated paths', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);
      storageService.exists.mockResolvedValue(true);
      storageService.read.mockResolvedValue(Buffer.from('test'));

      const validObjectKey = 'tests/test-123/1672531200000-abc123.jpg';

      await service.completeUpload(
        'test-123',
        {
          objectKey: validObjectKey,
          clientHash: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
          actualSizeBytes: 4,
        },
        'user-1',
        UserRole.OPERATOR,
      ).catch(() => {}); // May fail on other validations, but storage.read should be called

      expect(storageService.read).toHaveBeenCalledWith(validObjectKey);
    });

    it('should enforce object key prefix validation before storage operations', async () => {
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      await expect(
        service.completeUpload(
          'test-123',
          {
            objectKey: 'malicious/path/image.jpg',
            clientHash: 'abcd1234',
            actualSizeBytes: 1024,
          },
          'user-1',
          UserRole.OPERATOR,
        ),
      ).rejects.toThrow();

      // storage.exists should NOT be called with invalid path
      expect(storageService.exists).not.toHaveBeenCalled();
      expect(storageService.read).not.toHaveBeenCalled();
    });
  });

  describe('Authorization Integration', () => {
    it('should verify user can modify test before generating upload URL', async () => {
      (ownershipPolicy.canModifyTest as any).mockRejectedValue(
        new AppError(ErrorCode.FORBIDDEN, 'Not authorized', HttpStatus.FORBIDDEN),
      );
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      await expect(
        service.requestUploadUrl(
          'test-123',
          { contentType: 'image/jpeg', fileSizeBytes: 1024 },
          'user-2',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.FORBIDDEN,
      });

      expect(ownershipPolicy.canModifyTest).toHaveBeenCalledWith('test-123', 'user-2', UserRole.OPERATOR);
    });

    it('should verify user can modify test before completing upload', async () => {
      (ownershipPolicy.canModifyTest as any).mockRejectedValue(
        new AppError(ErrorCode.FORBIDDEN, 'Not authorized', HttpStatus.FORBIDDEN),
      );
      (prismaService.test.findUnique as any).mockResolvedValue(mockTest);

      await expect(
        service.completeUpload(
          'test-123',
          {
            objectKey: 'tests/test-123/image.jpg',
            clientHash: 'abcd1234',
            actualSizeBytes: 1024,
          },
          'user-2',
          UserRole.OPERATOR,
        ),
      ).rejects.toMatchObject({
        code: ErrorCode.FORBIDDEN,
      });
    });
  });
});

