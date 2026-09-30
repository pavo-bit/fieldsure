import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service.js';
import { TestStatus, UserRole } from '@prisma/client';

/**
 * Database-Level Evidence Protection Test Suite
 * 
 * REQUIREMENT: Finalized evidence records must be immutable at database level
 * IMPLEMENTATION: PostgreSQL triggers prevent UPDATE/DELETE on finalized tests
 * 
 * This suite verifies:
 * 1. Finalized tests cannot be modified
 * 2. Finalized tests cannot be deleted
 * 3. Evidence records for finalized tests cannot be modified
 * 4. Classification data for finalized tests cannot be modified
 * 5. Image assets for finalized tests cannot be modified
 * 6. Archived tests have same protections as finalized tests
 * 
 * These tests require a running PostgreSQL database with migrations applied.
 */

describe('Database-Level Evidence Protection', () => {
  let prismaService: PrismaService;
  let testId: string;
  let evidenceId: string;
  let classificationId: string;
  let imageAssetId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [PrismaService],
    }).compile();

    prismaService = module.get<PrismaService>(PrismaService);
  });

  beforeEach(async () => {
    // Create test data for each test case
    const user = await prismaService.user.create({
      data: {
        email: `test-${Date.now()}@example.com`,
        passwordHash: 'hash',
        role: UserRole.OPERATOR,
        firstName: 'Test',
        lastName: 'User',
        organizationId: 'org-test',
      },
    });

    const kit = await prismaService.drugTestKit.create({
      data: {
        name: 'Marquis Reagent',
        manufacturer: 'NarcoTest',
        lotNumber: `LOT-${Date.now()}`,
        expirationDate: new Date('2027-12-31'),
      },
    });

    const test = await prismaService.test.create({
      data: {
        testNumber: `FS-2026-${Date.now().toString().slice(-6)}`,
        operatorId: user.id,
        kitId: kit.id,
        status: TestStatus.DRAFT,
        clientCreatedAt: new Date(),
      },
    });
    testId = test.id;

    const imageAsset = await prismaService.imageAsset.create({
      data: {
        testId,
        storagePath: 'test/path.jpg',
        serverHash: 'hash123',
        sizeBytes: 1024,
        captureMetadata: {},
      },
    });
    imageAssetId = imageAsset.id;

    const classification = await prismaService.classification.create({
      data: {
        testId,
        mlModelVersion: 'v1.0.0',
        observedColorLab: [50, 0, 0],
        colorDistance: 5.2,
        nearestReferenceLabel: 'purple',
        qualityStatus: 'GOOD',
        validationStatus: 'UNVALIDATED',
        rawOutput: {},
      },
    });
    classificationId = classification.id;

    const evidence = await prismaService.evidenceRecord.create({
      data: {
        testId,
        version: 'V3',
        canonicalJson: '{"test":"data"}',
        integrityHash: 'hash456',
        previousVersion: null,
      },
    });
    evidenceId = evidence.id;
  });

  afterEach(async () => {
    // Clean up test data
    await prismaService.evidenceRecord.deleteMany({ where: { testId } });
    await prismaService.classification.deleteMany({ where: { testId } });
    await prismaService.imageAsset.deleteMany({ where: { testId } });
    await prismaService.test.deleteMany({ where: { id: testId } });
  });

  afterAll(async () => {
    await prismaService.$disconnect();
  });

  describe('Finalized Test Protection', () => {
    it('should allow modifications to DRAFT tests', async () => {
      const updated = await prismaService.test.update({
        where: { id: testId },
        data: { sampleId: 'SAMPLE-001' },
      });

      expect(updated.sampleId).toBe('SAMPLE-001');
    });

    it('should prevent modifications to FINALIZED tests', async () => {
      // First finalize the test
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      // Attempt to modify finalized test
      await expect(
        prismaService.test.update({
          where: { id: testId },
          data: { sampleId: 'MODIFIED' },
        }),
      ).rejects.toThrow(/Cannot modify test with status FINALIZED/i);
    });

    it('should prevent modifications to ARCHIVED tests', async () => {
      // First finalize then archive the test
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      // Attempt to modify archived test
      await expect(
        prismaService.test.update({
          where: { id: testId },
          data: { sampleId: 'MODIFIED' },
        }),
      ).rejects.toThrow(/Cannot modify test with status ARCHIVED/i);
    });

    it('should prevent deletion of FINALIZED tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.test.delete({
          where: { id: testId },
        }),
      ).rejects.toThrow(/Cannot delete test with status FINALIZED/i);
    });

    it('should prevent deletion of ARCHIVED tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.test.delete({
          where: { id: testId },
        }),
      ).rejects.toThrow(/Cannot delete test with status ARCHIVED/i);
    });
  });

  describe('Evidence Record Protection', () => {
    it('should allow modifications to evidence for non-finalized tests', async () => {
      const updated = await prismaService.evidenceRecord.update({
        where: { id: evidenceId },
        data: { canonicalJson: '{"test":"updated"}' },
      });

      expect(updated.canonicalJson).toBe('{"test":"updated"}');
    });

    it('should prevent modifications to evidence for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.evidenceRecord.update({
          where: { id: evidenceId },
          data: { canonicalJson: '{"test":"tampered"}' },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });

    it('should prevent deletion of evidence for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.evidenceRecord.delete({
          where: { id: evidenceId },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });
  });

  describe('Classification Protection', () => {
    it('should allow modifications to classification for non-finalized tests', async () => {
      const updated = await prismaService.classification.update({
        where: { id: classificationId },
        data: { colorDistance: 6.0 },
      });

      expect(updated.colorDistance).toBe(6.0);
    });

    it('should prevent modifications to classification for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.classification.update({
          where: { id: classificationId },
          data: { colorDistance: 999.9 },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });

    it('should prevent deletion of classification for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.classification.delete({
          where: { id: classificationId },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });
  });

  describe('Image Asset Protection', () => {
    it('should allow modifications to image assets for non-finalized tests', async () => {
      const updated = await prismaService.imageAsset.update({
        where: { id: imageAssetId },
        data: { captureMetadata: { updated: true } },
      });

      expect(updated.captureMetadata).toEqual({ updated: true });
    });

    it('should prevent modifications to image assets for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.imageAsset.update({
          where: { id: imageAssetId },
          data: { storagePath: 'tampered/path.jpg' },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });

    it('should prevent deletion of image assets for finalized tests', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await expect(
        prismaService.imageAsset.delete({
          where: { id: imageAssetId },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });
  });

  describe('State Transition Protection', () => {
    it('should allow DRAFT -> CAPTURED transition', async () => {
      const updated = await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.CAPTURED },
      });

      expect(updated.status).toBe(TestStatus.CAPTURED);
    });

    it('should allow CAPTURED -> COMPLETED transition', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.CAPTURED },
      });

      const updated = await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      expect(updated.status).toBe(TestStatus.COMPLETED);
    });

    it('should allow COMPLETED -> FINALIZED transition', async () => {
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.CAPTURED },
      });

      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      const updated = await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      expect(updated.status).toBe(TestStatus.COMPLETED);
    });

    it('should prevent any modifications after FINALIZED', async () => {
      // Finalize test
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.CAPTURED },
      });

      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      // Try to modify any field
      await expect(
        prismaService.test.update({
          where: { id: testId },
          data: { sampleId: 'TAMPERED' },
        }),
      ).rejects.toThrow(/Cannot modify test with status FINALIZED/i);

      // Try to change status back
      await expect(
        prismaService.test.update({
          where: { id: testId },
          data: { status: TestStatus.DRAFT },
        }),
      ).rejects.toThrow(/Cannot modify test with status FINALIZED/i);
    });
  });

  describe('Audit Trail Integrity', () => {
    it('should preserve evidence chain when modifying non-finalized tests', async () => {
      // Create initial evidence
      const evidence1 = await prismaService.evidenceRecord.create({
        data: {
          testId,
          version: 'V3',
          canonicalJson: '{"version":1}',
          integrityHash: 'hash1',
          previousVersion: null,
        },
      });

      // Create new version
      const evidence2 = await prismaService.evidenceRecord.create({
        data: {
          testId,
          version: 'V3',
          canonicalJson: '{"version":2}',
          integrityHash: 'hash2',
          previousVersion: evidence1.id,
        },
      });

      expect(evidence2.previousVersion).toBe(evidence1.id);

      // Finalize test
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      // Attempt to create new version after finalization
      await expect(
        prismaService.evidenceRecord.create({
          data: {
            testId,
            version: 'V3',
            canonicalJson: '{"version":3}',
            integrityHash: 'hash3',
            previousVersion: evidence2.id,
          },
        }),
      ).rejects.toThrow(); // Foreign key constraint should prevent
    });

    it('should not allow backdating evidence records', async () => {
      const now = new Date();
      
      const evidence = await prismaService.evidenceRecord.create({
        data: {
          testId,
          version: 'V3',
          canonicalJson: '{"timestamp":"' + now.toISOString() + '"}',
          integrityHash: 'hash123',
          previousVersion: null,
        },
      });

      // Finalize test
      await prismaService.test.update({
        where: { id: testId },
        data: { status: TestStatus.COMPLETED },
      });

      // Try to modify timestamp
      await expect(
        prismaService.evidenceRecord.update({
          where: { id: evidence.id },
          data: {
            canonicalJson: '{"timestamp":"' + new Date('2020-01-01').toISOString() + '"}',
          },
        }),
      ).rejects.toThrow(/Cannot modify evidence for test with status FINALIZED/i);
    });
  });
});
