/**
 * Tests for safe result transformation and validation status enforcement.
 * CRITICAL: These tests verify that unsafe results cannot be presented without warnings.
 */

import { describe, it, expect } from 'vitest';
import {
  generateSafetyWarnings,
  transformToSafeResult,
  type SafetyWarning,
} from './test-result-response.dto.js';
import type { Classification } from '@prisma/client';

describe('Safety Warnings Generation', () => {
  const mockBaseClassification: Partial<Classification> = {
    id: 'cls-123',
    testId: 'test-123',
    observedColorLab: { L: 65.5, a: 18.2, b: -35.7 } as any,
    colorDistance: 12.3,
    nearestReferenceLabel: 'Blue-Purple range',
    qualityStatus: 'ACCEPTABLE',
    qualityIssues: null as any,
    validationStatus: 'UNVALIDATED',
    algorithmVersion: 'v2.0',
    modelVersion: 'demo-v2',
    pipelineId: 'colorimetric-v1',
    kitCode: 'DEMO-KIT-001',
    result: null,
    confidence: null,
    configurationVersion: '1.0',
    features: {} as any,
    diagnostics: null as any,
    presumptiveLabel: null,
    createdAt: new Date(),
  };

  describe('Validation Status Warnings', () => {
    it('should generate CRITICAL warning for UNVALIDATED classifier', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'UNVALIDATED' } as Classification,
      );

      const unvalidatedWarning = warnings.find((w: any) => w.code === 'CLASSIFIER_UNVALIDATED');
      expect(unvalidatedWarning).toBeDefined();
      expect(unvalidatedWarning?.severity).toBe('CRITICAL');
      expect(unvalidatedWarning?.message).toContain('NOT been scientifically validated');
    });

    it('should generate WARNING for PILOT classifier', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'PILOT' } as Classification,
      );

      const pilotWarning = warnings.find((w: any) => w.code === 'CLASSIFIER_PILOT');
      expect(pilotWarning).toBeDefined();
      expect(pilotWarning?.severity).toBe('WARNING');
      expect(pilotWarning?.message).toContain('PRESUMPTIVE ONLY');
    });

    it('should not generate validation warning for VALIDATED classifier', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'VALIDATED' } as Classification,
      );

      const validationWarnings = warnings.filter(
        (w: any) => w.code === 'CLASSIFIER_UNVALIDATED' || w.code === 'CLASSIFIER_PILOT',
      );
      expect(validationWarnings).toHaveLength(0);
    });

    it('should generate CRITICAL warning for UNVALIDATED kit', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'VALIDATED' } as Classification,
        'UNVALIDATED',
      );

      const kitWarning = warnings.find((w: any) => w.code === 'KIT_UNVALIDATED');
      expect(kitWarning).toBeDefined();
      expect(kitWarning?.severity).toBe('CRITICAL');
      expect(kitWarning?.message).toContain('kit configuration has NOT been validated');
    });

    it('should generate WARNING for PILOT kit', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'VALIDATED' } as Classification,
        'PILOT',
      );

      const kitWarning = warnings.find((w: any) => w.code === 'KIT_PILOT');
      expect(kitWarning).toBeDefined();
      expect(kitWarning?.severity).toBe('WARNING');
    });
  });

  describe('Quality Status Warnings', () => {
    it('should generate CRITICAL warning for REJECTED quality', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, qualityStatus: 'REJECTED' } as Classification,
      );

      const rejectedWarning = warnings.find((w: any) => w.code === 'QUALITY_REJECTED');
      expect(rejectedWarning).toBeDefined();
      expect(rejectedWarning?.severity).toBe('CRITICAL');
      expect(rejectedWarning?.message).toContain('REJECTED');
      expect(rejectedWarning?.message).toContain('should not be used');
    });

    it('should generate WARNING for MARGINAL quality', () => {
      const warnings = generateSafetyWarnings(
        { ...mockBaseClassification, qualityStatus: 'MARGINAL' } as Classification,
      );

      const marginalWarning = warnings.find((w: any) => w.code === 'QUALITY_MARGINAL');
      expect(marginalWarning).toBeDefined();
      expect(marginalWarning?.severity).toBe('WARNING');
      expect(marginalWarning?.message).toContain('MARGINAL');
    });

    it('should include quality issues details', () => {
      const warnings = generateSafetyWarnings({
        ...mockBaseClassification,
        qualityIssues: ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS'] as any,
      } as Classification);

      const issuesWarning = warnings.find((w: any) => w.code === 'QUALITY_ISSUES');
      expect(issuesWarning).toBeDefined();
      expect(issuesWarning?.message).toContain('COLOR_DISTANCE_HIGH');
      expect(issuesWarning?.message).toContain('EXTREME_LIGHTNESS');
    });
  });

  describe('Presumptive Disclaimer', () => {
    it('should ALWAYS include presumptive disclaimer', () => {
      const warningsUnvalidated = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'UNVALIDATED' } as Classification,
      );
      const warningsValidated = generateSafetyWarnings(
        { ...mockBaseClassification, validationStatus: 'VALIDATED' } as Classification,
      );

      const disclaimerUnvalidated = warningsUnvalidated.find(
        (w: any) => w.code === 'PRESUMPTIVE_ONLY',
      );
      const disclaimerValidated = warningsValidated.find((w: any) => w.code === 'PRESUMPTIVE_ONLY');

      expect(disclaimerUnvalidated).toBeDefined();
      expect(disclaimerValidated).toBeDefined();
      expect(disclaimerUnvalidated?.message).toContain('PRESUMPTIVE ONLY');
      expect(disclaimerValidated?.message).toContain('Laboratory confirmation is required');
    });
  });

  describe('Multiple Warnings', () => {
    it('should generate multiple warnings when multiple issues present', () => {
      const warnings = generateSafetyWarnings(
        {
          ...mockBaseClassification,
          validationStatus: 'UNVALIDATED',
          qualityStatus: 'MARGINAL',
          qualityIssues: ['COLOR_DISTANCE_HIGH'] as any,
        } as Classification,
        'UNVALIDATED',
      );

      expect(warnings.length).toBeGreaterThanOrEqual(5); // classifier, kit, quality, issues, disclaimer
      expect(warnings.some((w: any) => w.code === 'CLASSIFIER_UNVALIDATED')).toBe(true);
      expect(warnings.some((w: any) => w.code === 'KIT_UNVALIDATED')).toBe(true);
      expect(warnings.some((w: any) => w.code === 'QUALITY_MARGINAL')).toBe(true);
      expect(warnings.some((w: any) => w.code === 'QUALITY_ISSUES')).toBe(true);
      expect(warnings.some((w: any) => w.code === 'PRESUMPTIVE_ONLY')).toBe(true);
    });
  });
});

describe('Safe Result Transformation', () => {
  const mockClassification: Classification = {
    id: 'cls-123',
    testId: 'test-123',
    observedColorLab: { L: 65.5, a: 18.2, b: -35.7 } as any,
    colorDistance: 12.3,
    nearestReferenceLabel: 'Blue-Purple range',
    qualityStatus: 'ACCEPTABLE',
    qualityIssues: null as any,
    validationStatus: 'UNVALIDATED',
    algorithmVersion: 'v2.0',
    modelVersion: 'demo-v2',
    pipelineId: 'colorimetric-v1',
    kitCode: 'DEMO-KIT-001',
    result: null,
    confidence: null,
    configurationVersion: '1.0',
    features: {} as any,
    diagnostics: null as any,
    presumptiveLabel: null,
    createdAt: new Date(),
  };

  it('should transform classification to safe result format', () => {
    const safeResult = transformToSafeResult(mockClassification, 'UNVALIDATED');

    expect(safeResult.observedColorLab).toEqual({ L: 65.5, a: 18.2, b: -35.7 });
    expect(safeResult.colorDistance).toBe(12.3);
    expect(safeResult.nearestReferenceLabel).toBe('Blue-Purple range');
    expect(safeResult.qualityStatus).toBe('ACCEPTABLE');
    expect(safeResult.validationStatus).toBe('UNVALIDATED');
    expect(safeResult.kitValidationStatus).toBe('UNVALIDATED');
  });

  it('should include warnings array', () => {
    const safeResult = transformToSafeResult(mockClassification, 'UNVALIDATED');

    expect(safeResult.warnings).toBeDefined();
    expect(Array.isArray(safeResult.warnings)).toBe(true);
    expect(safeResult.warnings.length).toBeGreaterThan(0);
  });

  it('should include deprecated fields separately', () => {
    const classificationWithLegacy: Classification = {
      ...mockClassification,
      result: 'POSITIVE',
      confidence: 0.85,
    };

    const safeResult = transformToSafeResult(classificationWithLegacy, 'VALIDATED');

    expect(safeResult.deprecated).toBeDefined();
    expect(safeResult.deprecated?.result).toBe('POSITIVE');
    expect(safeResult.deprecated?.confidence).toBe(0.85);
  });

  it('should NOT expose deprecated fields at top level', () => {
    const classificationWithLegacy: Classification = {
      ...mockClassification,
      result: 'POSITIVE',
      confidence: 0.85,
    };

    const safeResult = transformToSafeResult(classificationWithLegacy, 'VALIDATED');

    // Top level should NOT have result/confidence
    expect((safeResult as any).result).toBeUndefined();
    expect((safeResult as any).confidence).toBeUndefined();
  });

  it('should include algorithm identifiers', () => {
    const safeResult = transformToSafeResult(mockClassification, 'VALIDATED');

    expect(safeResult.algorithmVersion).toBe('v2.0');
    expect(safeResult.modelVersion).toBe('demo-v2');
    expect(safeResult.pipelineId).toBe('colorimetric-v1');
  });

  it('should handle null quality issues', () => {
    const safeResult = transformToSafeResult(mockClassification, 'VALIDATED');

    expect(safeResult.qualityIssues).toBeNull();
  });

  it('should handle quality issues array', () => {
    const classificationWithIssues: Classification = {
      ...mockClassification,
      qualityIssues: ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS'] as any,
    };

    const safeResult = transformToSafeResult(classificationWithIssues, 'VALIDATED');

    expect(safeResult.qualityIssues).toEqual(['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS']);
  });
});

describe('Safety Enforcement', () => {
  it('should require warnings to be displayed - CRITICAL for UNVALIDATED', () => {
    const mockClassification: Classification = {
      id: 'cls-123',
      testId: 'test-123',
      observedColorLab: { L: 65.5, a: 18.2, b: -35.7 } as any,
      colorDistance: 12.3,
      nearestReferenceLabel: 'Blue-Purple range',
      qualityStatus: 'ACCEPTABLE',
      qualityIssues: null as any,
      validationStatus: 'UNVALIDATED',
      algorithmVersion: 'v2.0',
      modelVersion: 'demo-v2',
      pipelineId: 'colorimetric-v1',
      kitCode: 'DEMO-KIT-001',
      result: null,
      confidence: null,
      configurationVersion: '1.0',
      features: {} as any,
      diagnostics: null as any,
      presumptiveLabel: null,
      createdAt: new Date(),
    };

    const safeResult = transformToSafeResult(mockClassification, 'UNVALIDATED');

    // CRITICAL warnings MUST be present
    const criticalWarnings = safeResult.warnings.filter((w: any) => w.severity === 'CRITICAL');
    expect(criticalWarnings.length).toBeGreaterThan(0);

    // Validation status MUST be visible
    expect(safeResult.validationStatus).toBe('UNVALIDATED');
    expect(safeResult.kitValidationStatus).toBe('UNVALIDATED');
  });

  it('should prevent confidence scores from being used in field decisions', () => {
    const classificationWithConfidence: Classification = {
      id: 'cls-123',
      testId: 'test-123',
      observedColorLab: { L: 65.5, a: 18.2, b: -35.7 } as any,
      colorDistance: 12.3,
      nearestReferenceLabel: 'Blue-Purple range',
      qualityStatus: 'ACCEPTABLE',
      qualityIssues: null as any,
      validationStatus: 'UNVALIDATED',
      algorithmVersion: 'v2.0',
      modelVersion: 'demo-v2',
      pipelineId: 'colorimetric-v1',
      kitCode: 'DEMO-KIT-001',
      result: 'POSITIVE',
      confidence: 0.95, // High confidence but UNVALIDATED!
      configurationVersion: '1.0',
      features: {} as any,
      diagnostics: null as any,
      presumptiveLabel: null,
      createdAt: new Date(),
    };

    const safeResult = transformToSafeResult(classificationWithConfidence, 'UNVALIDATED');

    // Confidence should be in deprecated section, NOT at top level
    expect((safeResult as any).confidence).toBeUndefined();
    expect(safeResult.deprecated?.confidence).toBe(0.95);

    // CRITICAL warning about validation status must override high confidence
    const criticalWarnings = safeResult.warnings.filter((w: any) => w.severity === 'CRITICAL');
    expect(criticalWarnings.length).toBeGreaterThan(0);
  });
});
