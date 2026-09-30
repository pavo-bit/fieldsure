/**
 * Tests for RFC 8785 JSON Canonicalization Scheme implementation
 * and canonical record format versions V1/V2/V3.
 * 
 * CRITICAL: These tests ensure cross-language reproducibility and tamper detection.
 */

import { describe, it, expect } from 'vitest';
import {
  canonicalizeRFC8785,
  createCanonicalV1,
  createCanonicalV2,
  createCanonicalV3,
} from './canonicalizers.js';

describe('RFC 8785 JSON Canonicalization Scheme', () => {
  describe('Primitive values', () => {
    it('should canonicalize null', () => {
      expect(canonicalizeRFC8785(null)).toBe('null');
    });

    it('should canonicalize booleans', () => {
      expect(canonicalizeRFC8785(true)).toBe('true');
      expect(canonicalizeRFC8785(false)).toBe('false');
    });

    it('should canonicalize strings with proper escaping', () => {
      expect(canonicalizeRFC8785('hello')).toBe('"hello"');
      expect(canonicalizeRFC8785('hello "world"')).toBe('"hello \\"world\\""');
      expect(canonicalizeRFC8785('line1\nline2')).toBe('"line1\\nline2"');
    });

    it('should canonicalize numbers according to RFC 8785', () => {
      expect(canonicalizeRFC8785(0)).toBe('0');
      expect(canonicalizeRFC8785(-0)).toBe('0'); // Negative zero becomes positive zero
      expect(canonicalizeRFC8785(42)).toBe('42');
      expect(canonicalizeRFC8785(-42)).toBe('-42');
      expect(canonicalizeRFC8785(3.14)).toBe('3.14');
      expect(canonicalizeRFC8785(1e10)).toBe('10000000000');
      expect(canonicalizeRFC8785(1e-5)).toBe('0.00001');
    });

    it('should reject Infinity and NaN', () => {
      expect(() => canonicalizeRFC8785(Infinity)).toThrow();
      expect(() => canonicalizeRFC8785(-Infinity)).toThrow();
      expect(() => canonicalizeRFC8785(NaN)).toThrow();
    });
  });

  describe('Arrays', () => {
    it('should canonicalize empty array', () => {
      expect(canonicalizeRFC8785([])).toBe('[]');
    });

    it('should canonicalize arrays with primitives', () => {
      expect(canonicalizeRFC8785([1, 2, 3])).toBe('[1,2,3]');
      expect(canonicalizeRFC8785(['a', 'b', 'c'])).toBe('["a","b","c"]');
      expect(canonicalizeRFC8785([true, false, null])).toBe('[true,false,null]');
    });

    it('should canonicalize nested arrays', () => {
      expect(canonicalizeRFC8785([[1, 2], [3, 4]])).toBe('[[1,2],[3,4]]');
    });

    it('should preserve array order', () => {
      expect(canonicalizeRFC8785([3, 1, 2])).toBe('[3,1,2]');
    });
  });

  describe('Objects', () => {
    it('should canonicalize empty object', () => {
      expect(canonicalizeRFC8785({})).toBe('{}');
    });

    it('should sort object keys lexicographically', () => {
      const obj = { z: 1, a: 2, m: 3 };
      expect(canonicalizeRFC8785(obj)).toBe('{"a":2,"m":3,"z":1}');
    });

    it('should handle nested objects with sorted keys', () => {
      const obj = {
        outer2: { inner2: 'b', inner1: 'a' },
        outer1: { inner3: 'c' },
      };
      expect(canonicalizeRFC8785(obj)).toBe(
        '{"outer1":{"inner3":"c"},"outer2":{"inner1":"a","inner2":"b"}}',
      );
    });

    it('should handle objects with mixed value types', () => {
      const obj = { num: 42, str: 'hello', bool: true, nil: null, arr: [1, 2] };
      expect(canonicalizeRFC8785(obj)).toBe(
        '{"arr":[1,2],"bool":true,"nil":null,"num":42,"str":"hello"}',
      );
    });
  });

  describe('Deterministic serialization', () => {
    it('should produce identical output for equivalent objects', () => {
      const obj1 = { a: 1, b: 2, c: 3 };
      const obj2 = { c: 3, a: 1, b: 2 };
      const obj3 = { b: 2, c: 3, a: 1 };

      const canon1 = canonicalizeRFC8785(obj1);
      const canon2 = canonicalizeRFC8785(obj2);
      const canon3 = canonicalizeRFC8785(obj3);

      expect(canon1).toBe(canon2);
      expect(canon2).toBe(canon3);
    });

    it('should produce different output for different objects', () => {
      const obj1 = { a: 1, b: 2 };
      const obj2 = { a: 1, b: 3 };

      expect(canonicalizeRFC8785(obj1)).not.toBe(canonicalizeRFC8785(obj2));
    });
  });

  describe('Colorimetric data', () => {
    it('should canonicalize LAB color space values', () => {
      const color = { L: 65.5, a: 18.2, b: -35.7 };
      expect(canonicalizeRFC8785(color)).toBe('{"L":65.5,"a":18.2,"b":-35.7}');
    });

    it('should handle quality issues array', () => {
      const issues = ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS'];
      expect(canonicalizeRFC8785(issues)).toBe(
        '["COLOR_DISTANCE_HIGH","EXTREME_LIGHTNESS"]',
      );
    });
  });
});

describe('Canonical Record Formats', () => {
  const mockTest = {
    id: 'test-123',
    testNumber: 'T-2024-001',
    caseId: 'case-456',
    sampleId: 'sample-789',
    operatorId: 'user-001',
    kitId: 'kit-abc',
    configurationVersion: '1.0',
  };

  const mockClassificationLegacy = {
    result: 'POSITIVE',
    confidence: 0.85,
    algorithmVersion: 'v1.0',
    modelVersion: 'demo-v1',
  };

  const mockClassificationV3 = {
    result: null, // DEPRECATED
    confidence: null, // DEPRECATED
    observedColorLab: { L: 65.5, a: 18.2, b: -35.7 },
    colorDistance: 12.3,
    nearestReferenceLabel: 'Blue-Purple range',
    qualityStatus: 'ACCEPTABLE',
    qualityIssues: null,
    validationStatus: 'UNVALIDATED',
    algorithmVersion: 'v2.0',
    modelVersion: 'demo-v2',
    pipelineId: 'colorimetric-v1',
  };

  const mockImageAsset = {
    clientHash: 'client-hash-abc123',
    serverHash: 'server-hash-def456',
    captureMetadata: { device: 'iPhone 13', timestamp: '2024-01-01T00:00:00Z' },
  };

  const mockTestKit = {
    code: 'DEMO-KIT-001',
  };

  describe('V1 Canonical Format', () => {
    it('should create V1 canonical record with sorted keys', () => {
      const canonical = createCanonicalV1(
        mockTest,
        mockClassificationLegacy,
        'image-hash-123',
      );

      const parsed = JSON.parse(canonical);

      // Verify all required fields present
      expect(parsed.testId).toBe('test-123');
      expect(parsed.classificationResult).toBe('POSITIVE');
      expect(parsed.classificationConfidence).toBe(0.85);
      expect(parsed.imageHash).toBe('image-hash-123');
      expect(parsed.schemaVersion).toBe('1.0');

      // Verify keys are sorted
      const keys = Object.keys(parsed);
      const sortedKeys = [...keys].sort();
      expect(keys).toEqual(sortedKeys);
    });
  });

  describe('V2 Canonical Format', () => {
    it('should create V2 canonical record with chain fields', () => {
      const canonical = createCanonicalV2(
        mockTest,
        mockClassificationLegacy,
        mockImageAsset,
        'prev-hash-xyz',
        5,
      );

      const parsed = JSON.parse(canonical);

      // Verify extended fields
      expect(parsed.version).toBe(2);
      expect(parsed.clientImageHash).toBe('client-hash-abc123');
      expect(parsed.serverImageHash).toBe('server-hash-def456');
      expect(parsed.previousRecordHash).toBe('prev-hash-xyz');
      expect(parsed.chainIndex).toBe(5);
      expect(parsed.schemaVersion).toBe('2.0');

      // Verify keys are sorted
      const keys = Object.keys(parsed);
      const sortedKeys = [...keys].sort();
      expect(keys).toEqual(sortedKeys);
    });
  });

  describe('V3 Canonical Format (Safety-Hardened)', () => {
    it('should create V3 canonical record with colorimetric fields', () => {
      const canonical = createCanonicalV3(
        mockTest,
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        null, // No operator interpretation
        'prev-hash-xyz',
        10,
      );

      const parsed = JSON.parse(canonical);

      // Verify version
      expect(parsed.version).toBe(3);
      expect(parsed.schemaVersion).toBe('3.0');
      expect(parsed.canonicalizationVersion).toBe('3.0-RFC8785');

      // Verify colorimetric fields
      expect(parsed.observedColorLab).toEqual({ L: 65.5, a: 18.2, b: -35.7 });
      expect(parsed.colorDistance).toBe(12.3);
      expect(parsed.nearestReferenceLabel).toBe('Blue-Purple range');

      // Verify quality fields
      expect(parsed.qualityStatus).toBe('ACCEPTABLE');
      expect(parsed.qualityIssues).toBeNull();

      // Verify validation status
      expect(parsed.validationStatus).toBe('UNVALIDATED');

      // Verify kit metadata
      expect(parsed.kitCode).toBe('DEMO-KIT-001');

      // Verify operator interpretation is null
      expect(parsed.operatorInterpretation).toBeNull();
    });

    it('should include operator interpretation when present', () => {
      const mockOperatorInterpretation = {
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
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        mockOperatorInterpretation,
        'prev-hash-xyz',
        10,
      );

      const parsed = JSON.parse(canonical);

      // Verify operator interpretation included
      expect(parsed.operatorInterpretation).toBeDefined();
      expect(parsed.operatorInterpretation.id).toBe('interp-001');
      expect(parsed.operatorInterpretation.visualObservation).toBe(
        'Strong blue-purple color observed',
      );
      expect(parsed.operatorInterpretation.agreementWithMachine).toBe('AGREE');
      expect(parsed.operatorInterpretation.disclaimerAcknowledged).toBe(true);
      expect(parsed.operatorInterpretation.interpretedAt).toBe('2024-01-01T12:00:00.000Z');
    });

    it('should preserve deprecated fields for backward compatibility', () => {
      const classificationWithLegacy = {
        ...mockClassificationV3,
        result: 'POSITIVE', // DEPRECATED but still captured
        confidence: 0.85, // DEPRECATED but still captured
      };

      const canonical = createCanonicalV3(
        mockTest,
        classificationWithLegacy,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);

      // Verify deprecated fields captured
      expect(parsed.classificationResult).toBe('POSITIVE');
      expect(parsed.classificationConfidence).toBe(0.85);
    });

    it('should handle null values correctly', () => {
      const testWithNulls = {
        ...mockTest,
        caseId: null,
        sampleId: null,
      };

      const classificationWithNulls = {
        ...mockClassificationV3,
        nearestReferenceLabel: null,
        qualityIssues: null,
        pipelineId: null,
      };

      const canonical = createCanonicalV3(
        testWithNulls,
        classificationWithNulls,
        { ...mockImageAsset, clientHash: null },
        mockTestKit,
        null,
        null,
        0,
      );

      const parsed = JSON.parse(canonical);

      expect(parsed.caseId).toBeNull();
      expect(parsed.sampleId).toBeNull();
      expect(parsed.nearestReferenceLabel).toBeNull();
      expect(parsed.qualityIssues).toBeNull();
      expect(parsed.pipelineId).toBeNull();
      expect(parsed.clientImageHash).toBeNull();
      expect(parsed.operatorInterpretation).toBeNull();
    });
  });

  describe('Cross-version consistency', () => {
    it('should produce different hashes for V1/V2/V3 of same test', () => {
      const crypto = require('crypto');

      const v1 = createCanonicalV1(mockTest, mockClassificationLegacy, 'image-hash-123');
      const v2 = createCanonicalV2(
        mockTest,
        mockClassificationLegacy,
        mockImageAsset,
        null,
        0,
      );
      const v3 = createCanonicalV3(
        mockTest,
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const hash1 = crypto.createHash('sha256').update(v1).digest('hex');
      const hash2 = crypto.createHash('sha256').update(v2).digest('hex');
      const hash3 = crypto.createHash('sha256').update(v3).digest('hex');

      // All three versions should produce different hashes
      expect(hash1).not.toBe(hash2);
      expect(hash2).not.toBe(hash3);
      expect(hash1).not.toBe(hash3);
    });
  });

  describe('Tamper detection', () => {
    it('should detect field value tampering', () => {
      const crypto = require('crypto');

      const canonical1 = createCanonicalV3(
        mockTest,
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const tamperedClassification = {
        ...mockClassificationV3,
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

      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect operator interpretation tampering', () => {
      const crypto = require('crypto');

      const mockOperatorInterpretation1 = {
        id: 'interp-001',
        visualObservation: 'Strong blue-purple color observed',
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
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        mockOperatorInterpretation1,
        null,
        0,
      );

      const mockOperatorInterpretation2 = {
        ...mockOperatorInterpretation1,
        disclaimerAcknowledged: false, // TAMPERED!
      };

      const canonical2 = createCanonicalV3(
        mockTest,
        mockClassificationV3,
        mockImageAsset,
        mockTestKit,
        mockOperatorInterpretation2,
        null,
        0,
      );

      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });

    it('should detect validation status tampering', () => {
      const crypto = require('crypto');

      const canonical1 = createCanonicalV3(
        mockTest,
        { ...mockClassificationV3, validationStatus: 'UNVALIDATED' },
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const canonical2 = createCanonicalV3(
        mockTest,
        { ...mockClassificationV3, validationStatus: 'VALIDATED' }, // TAMPERED!
        mockImageAsset,
        mockTestKit,
        null,
        null,
        0,
      );

      const hash1 = crypto.createHash('sha256').update(canonical1).digest('hex');
      const hash2 = crypto.createHash('sha256').update(canonical2).digest('hex');

      expect(hash1).not.toBe(hash2);
    });
  });
});
