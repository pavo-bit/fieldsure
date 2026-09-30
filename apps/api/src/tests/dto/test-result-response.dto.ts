/**
 * Response DTOs for test results with safety warnings.
 * CRITICAL: All responses must surface validationStatus and quality warnings.
 */

import { Classification } from '@prisma/client';

/**
 * Safety warning attached to test results.
 */
export interface SafetyWarning {
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  code: string;
  message: string;
}

/**
 * Enhanced classification result with safety metadata.
 * NEVER return raw Classification without these safety checks.
 */
export interface SafeClassificationResult {
  // Colorimetric measurements (primary result format)
  observedColorLab: { L: number; a: number; b: number };
  colorDistance: number;
  nearestReferenceLabel: string | null;
  
  // Quality assessment
  qualityStatus: string;
  qualityIssues: string[] | null;
  
  // Validation status (CRITICAL)
  validationStatus: string;
  kitValidationStatus?: string; // From TestKit
  
  // Algorithm identifiers
  algorithmVersion: string;
  modelVersion: string;
  pipelineId: string | null;
  
  // Safety warnings (computed from validation/quality status)
  warnings: SafetyWarning[];
  
  // DEPRECATED fields (only for backward compatibility)
  // UI should NOT use these for decision-making
  deprecated?: {
    result: string | null;
    confidence: number | null;
  };
}

/**
 * Generate safety warnings based on validation and quality status.
 */
export function generateSafetyWarnings(
  classification: Classification,
  kitValidationStatus?: string,
): SafetyWarning[] {
  const warnings: SafetyWarning[] = [];
  
  // CRITICAL: Validation status warnings
  if (classification.validationStatus === 'UNVALIDATED') {
    warnings.push({
      severity: 'CRITICAL',
      code: 'CLASSIFIER_UNVALIDATED',
      message: 'This classification algorithm has NOT been scientifically validated. Results are for research/demonstration purposes only and MUST NOT be used for forensic or evidentiary purposes.',
    });
  }
  
  if (classification.validationStatus === 'PILOT') {
    warnings.push({
      severity: 'WARNING',
      code: 'CLASSIFIER_PILOT',
      message: 'This classification algorithm is in pilot/validation phase. Results are PRESUMPTIVE ONLY and require laboratory confirmation.',
    });
  }
  
  if (kitValidationStatus === 'UNVALIDATED') {
    warnings.push({
      severity: 'CRITICAL',
      code: 'KIT_UNVALIDATED',
      message: 'This test kit configuration has NOT been validated. Results are for demonstration purposes only.',
    });
  }
  
  if (kitValidationStatus === 'PILOT') {
    warnings.push({
      severity: 'WARNING',
      code: 'KIT_PILOT',
      message: 'This test kit is in pilot/validation phase. Results are presumptive only.',
    });
  }
  
  // Quality status warnings
  if (classification.qualityStatus === 'REJECTED') {
    warnings.push({
      severity: 'CRITICAL',
      code: 'QUALITY_REJECTED',
      message: 'Test quality is REJECTED. Result should not be used. Consider retaking the test.',
    });
  }
  
  if (classification.qualityStatus === 'MARGINAL') {
    warnings.push({
      severity: 'WARNING',
      code: 'QUALITY_MARGINAL',
      message: 'Test quality is MARGINAL. Result may be unreliable. Consider retaking the test.',
    });
  }
  
  // Quality issues details
  if (classification.qualityIssues && Array.isArray(classification.qualityIssues)) {
    const issues = classification.qualityIssues as string[];
    if (issues.length > 0) {
      warnings.push({
        severity: 'INFO',
        code: 'QUALITY_ISSUES',
        message: `Quality issues detected: ${issues.join(', ')}`,
      });
    }
  }
  
  // Presumptive nature disclaimer (always shown)
  warnings.push({
    severity: 'INFO',
    code: 'PRESUMPTIVE_ONLY',
    message: 'All field test results are PRESUMPTIVE ONLY. Laboratory confirmation is required for forensic/evidentiary use.',
  });
  
  return warnings;
}

/**
 * Transform raw Classification into safe response format.
 * Adds validation warnings and structures data safely.
 */
export function transformToSafeResult(
  classification: Classification,
  kitValidationStatus?: string,
): SafeClassificationResult {
  const warnings = generateSafetyWarnings(classification, kitValidationStatus);
  
  return {
    // Primary colorimetric measurements
    observedColorLab: classification.observedColorLab as { L: number; a: number; b: number },
    colorDistance: classification.colorDistance,
    nearestReferenceLabel: classification.nearestReferenceLabel,
    
    // Quality assessment
    qualityStatus: classification.qualityStatus,
    qualityIssues: classification.qualityIssues as string[] | null,
    
    // Validation status
    validationStatus: classification.validationStatus,
    kitValidationStatus,
    
    // Algorithm identifiers
    algorithmVersion: classification.algorithmVersion,
    modelVersion: classification.modelVersion,
    pipelineId: classification.pipelineId,
    
    // Safety warnings
    warnings,
    
    // DEPRECATED (only for backward compatibility - UI should ignore)
    deprecated: {
      result: classification.result,
      confidence: classification.confidence,
    },
  };
}
