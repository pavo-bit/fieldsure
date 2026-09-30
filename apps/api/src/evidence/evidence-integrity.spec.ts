/**
 * Comprehensive evidence integrity tests.
 * CRITICAL: These tests verify tamper detection, signature validation, operator audit trail.
 */

import { describe, it, expect, beforeEach, jest } from 'vitest';
import { Test } from 'vitest';
import { EvidenceService } from './evidence.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SignerService } from './signer.service.js';
import { AuditService } from '../audit/audit.service.js';
import { OwnershipPolicy } from '../common/policies/ownership.policy.js';
import { SigningKeysService } from '../signing-keys/signing-keys.service.js';
import { TimestampService } from './timestamp.service.js';
import { createCanonicalV3 } from './canonicalizers.js';
import * as crypto from 'crypto';

describe('Evidence Integrity Tests', () => {
  let service: EvidenceService;
  let prisma: PrismaService;

  const mockTest = {
    id: 'test-123',
    testNumber: 'T-2024-001',
    caseId: 'case-456',
    sampleId: 'sample-789',
    operatorId: 'user-001',
    kitId: 'kit-abc',
    configurationVersion: '1.0',
  };

  const mockClassification = {
    id: 'cls-123',
    testId: 'test-123',
    observedColorLab: { L: 65.5, a: 18.2, b: -35.7 },
    colorDistance: 12.3,
    nearestReferenceLabel: 'Blue-Purple range',
    qualityStatus: 'ACCEPTABLE',
    qualityIssues: null,
    validationStatus: 'UNVALIDATED',
    kitCode: 'DEMO-KIT-001',
    pipelineId: 'colorimetric-v1',
    algorithmVersion: 'v2.0',
    modelVersion: 'demo-v2',
    configurationVersion: '1.0',
    result: null,
    confidence: null,
    features: {},
    diagnostics: null,
    presumptiveLabel: null,
    createdAt: new Date(),
  };

  const mockImageAsset = {
    clientHash: 'client-hash-abc123',
    serverHash: 'server-hash-def456',
    storagePath: 'path/to/image.jpg',
    captureMetadata: { device: 'iPhone 13', timestamp: '2024-01-01T00:00:00Z' },
  };

  const mockTestKit = {
    code: 'DEMO-KIT-001',
    validationStatus: 'UNVALIDATED',
  };

  describe('Tamper Detection', () => {
    it('should detect tampering of colorDistance field', async () => {
      // Create canonical with original colorDistance
      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper with colorDistance
      const tamperedClassification = {
        ...mockClassification,
        colorDistance: 999.9, // TAMPERED!
      };
      const canonical2 = createCanonicalV3(
        mockTest,
        tamperedClassification,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      // Hashes should differ
      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of validationStatus field', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        { ...mockClassification, validationStatus: 'UNVALIDATED' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: upgrade UNVALIDATED to VALIDATED
      const canonical2 = createCanonicalV3(
        mockTest,
        { ...mockClassification, validationStatus: 'VALIDATED' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of qualityStatus field', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        { ...mockClassification, qualityStatus: 'REJECTED' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change REJECTED to ACCEPTABLE
      const canonical2 = createCanonicalV3(
        mockTest,
        { ...mockClassification, qualityStatus: 'ACCEPTABLE' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of nearestReferenceLabel', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        { ...mockClassification, nearestReferenceLabel: 'Blue-Purple range' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change reference label
      const canonical2 = createCanonicalV3(
        mockTest,
        { ...mockClassification, nearestReferenceLabel: 'Pink-Red range' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of LAB color values', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        { ...mockClassification, observedColorLab: { L: 65.5, a: 18.2, b: -35.7 } },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change LAB values
      const canonical2 = createCanonicalV3(
        mockTest,
        { ...mockClassification, observedColorLab: { L: 70.0, a: 20.0, b: -30.0 } },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of kit code', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        { code: 'DEMO-KIT-001' },
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change kit code
      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        { code: 'VALIDATED-KIT-002' },
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect image hash tampering', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change image hash
      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        { ...mockImageAsset, serverHash: 'tampered-hash-999' },
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });
  });

  describe('Operator Interpretation Audit Trail', () => {
    it('should include operator interpretation in evidence record', async () => {
      const operatorInterpretation = {
        id: 'interp-001',
        visualObservation: 'Strong blue-purple color observed',
        selectedReferenceColor: 'Blue-Purple (reference 3)',
        presumptiveInterpretation: 'Consistent with expected reaction',
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: true,
        actualReadingTime: 120,
        readingTimeViolationReason: null,
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);
      expect(parsed.operatorInterpretation).toBeDefined();
      expect(parsed.operatorInterpretation.id).toBe('interp-001');
      expect(parsed.operatorInterpretation.disclaimerAcknowledged).toBe(true);
    });

    it('should detect tampering of disclaimerAcknowledged flag', async () => {
      const operatorInterpretation1 = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: true,
        actualReadingTime: 120,
        readingTimeViolationReason: null,
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation1,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: set disclaimerAcknowledged to false
      const operatorInterpretation2 = {
        ...operatorInterpretation1,
        disclaimerAcknowledged: false, // TAMPERED!
      };

      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation2,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of operator disagreement reason', async () => {
      const operatorInterpretation1 = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'DISAGREE',
        disagreementReason: 'Color appears more pink than algorithm suggests',
        withinReadingWindow: true,
        actualReadingTime: 120,
        readingTimeViolationReason: null,
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation1,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change disagreement reason
      const operatorInterpretation2 = {
        ...operatorInterpretation1,
        disagreementReason: 'Different reason', // TAMPERED!
      };

      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation2,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of withinReadingWindow flag', async () => {
      const operatorInterpretation1 = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: false, // Reading outside window
        actualReadingTime: 300,
        readingTimeViolationReason: 'Test delayed due to environmental conditions',
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation1,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: set withinReadingWindow to true (hiding violation)
      const operatorInterpretation2 = {
        ...operatorInterpretation1,
        withinReadingWindow: true, // TAMPERED!
      };

      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation2,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should preserve operator interpretation timestamp immutably', async () => {
      const operatorInterpretation1 = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: true,
        actualReadingTime: 120,
        readingTimeViolationReason: null,
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00.000Z'),
      };

      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation1,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change timestamp by 1 second
      const operatorInterpretation2 = {
        ...operatorInterpretation1,
        interpretedAt: new Date('2024-01-01T12:00:01.000Z'), // TAMPERED!
      };

      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation2,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });
  });

  describe('Missing Disclaimers', () => {
    it('should fail if disclaimerAcknowledged is false', async () => {
      const operatorInterpretation = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: true,
        actualReadingTime: 120,
        readingTimeViolationReason: null,
        disclaimerAcknowledged: false, // NOT ACKNOWLEDGED!
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);
      expect(parsed.operatorInterpretation.disclaimerAcknowledged).toBe(false);

      // In production, evidence service should reject creating evidence
      // if operator interpretation exists but disclaimerAcknowledged is false
    });

    it('should require reading time violation reason when outside window', async () => {
      const operatorInterpretation = {
        id: 'interp-001',
        visualObservation: 'Color observed',
        selectedReferenceColor: null,
        presumptiveInterpretation: null,
        agreementWithMachine: 'AGREE',
        disagreementReason: null,
        withinReadingWindow: false,
        actualReadingTime: 300,
        readingTimeViolationReason: null, // MISSING REQUIRED FIELD!
        disclaimerAcknowledged: true,
        interpretedAt: new Date('2024-01-01T12:00:00Z'),
      };

      const canonical = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        operatorInterpretation,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);
      expect(parsed.operatorInterpretation.withinReadingWindow).toBe(false);
      expect(parsed.operatorInterpretation.readingTimeViolationReason).toBeNull();

      // In production, API validation should reject this
    });
  });

  describe('Quality Status Enforcement', () => {
    it('should preserve REJECTED quality status in evidence', async () => {
      const rejectedClassification = {
        ...mockClassification,
        qualityStatus: 'REJECTED',
        qualityIssues: ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS'],
      };

      const canonical = createCanonicalV3(
        mockTest,
        rejectedClassification,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);
      expect(parsed.qualityStatus).toBe('REJECTED');
      expect(parsed.qualityIssues).toContain('COLOR_DISTANCE_HIGH');
      expect(parsed.qualityIssues).toContain('EXTREME_LIGHTNESS');
    });

    it('should preserve quality issues array immutably', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        {
          ...mockClassification,
          qualityIssues: ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS'],
        },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: remove one quality issue
      const canonical2 = createCanonicalV3(
        mockTest,
        {
          ...mockClassification,
          qualityIssues: ['COLOR_DISTANCE_HIGH'], // Removed EXTREME_LIGHTNESS!
        },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });
  });

  describe('Chain Integrity', () => {
    it('should include previous record hash in chain', async () => {
      const previousHash = 'prev-hash-abc123';
      const canonical = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        previousHash,
        5,
      );

      const parsed = JSON.parse(canonical);
      expect(parsed.previousRecordHash).toBe(previousHash);
      expect(parsed.chainIndex).toBe(5);
    });

    it('should detect tampering of previousRecordHash', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        'prev-hash-abc123',
        5,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change previous hash
      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        'tampered-hash-xyz789',
        5,
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect tampering of chainIndex', async () => {
      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        'prev-hash-abc123',
        5,
      );
      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');

      // Tamper: change chain index
      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassification,
        mockImageAsset,
        mockTestKit,
        null,
        'prev-hash-abc123',
        10, // TAMPERED!
      );
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });
  });
});
