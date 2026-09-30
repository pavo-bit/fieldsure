/**
 * Versioned canonical record formats for evidence chain.
 * V1: Legacy format (backward compatibility)
 * V2: Extended format with metadata, chain fields
 * V3: Safety-hardened format with colorimetric measurements, quality assessment, validation status
 */

export interface CanonicalRecordV1 {
  testId: string;
  testNumber: string;
  caseId: string | null;
  sampleId: string | null;
  operatorId: string;
  kitId: string;
  configurationVersion: string | null;
  classificationResult: string;
  classificationConfidence: number | null;
  algorithmVersion: string;
  modelVersion: string;
  imageHash: string;
  hashingAlgorithm: string;
  schemaVersion: string;
  canonicalizationVersion: string;
}

export interface CanonicalRecordV2 extends Omit<CanonicalRecordV1, 'imageHash'> {
  clientImageHash: string | null;
  serverImageHash: string;
  captureMetadata: any;
  previousRecordHash: string | null;
  chainIndex: number;
  version: number;
}

/**
 * V3 canonical record: safety-hardened with colorimetric measurements
 * CRITICAL: All security-relevant fields included for tamper detection
 */
export interface CanonicalRecordV3 {
  version: number;
  testId: string;
  testNumber: string;
  caseId: string | null;
  sampleId: string | null;
  operatorId: string;
  kitId: string;
  kitCode: string;
  configurationVersion: string;
  
  // Colorimetric measurements (replaces POSITIVE/NEGATIVE)
  observedColorLab: { L: number; a: number; b: number };
  colorDistance: number;
  nearestReferenceLabel: string | null;
  
  // Quality assessment
  qualityStatus: string;
  qualityIssues: string[] | null;
  
  // Validation status (UNVALIDATED/PILOT/VALIDATED)
  validationStatus: string;
  
  // DEPRECATED fields (kept for backward compatibility verification)
  classificationResult: string | null;
  classificationConfidence: number | null;
  
  // Algorithm identifiers
  algorithmVersion: string;
  modelVersion: string;
  pipelineId: string | null;
  
  // Image integrity
  clientImageHash: string | null;
  serverImageHash: string;
  captureMetadata: any;
  
  // Operator interpretation (if exists)
  operatorInterpretation: {
    id: string;
    visualObservation: string;
    selectedReferenceColor: string | null;
    presumptiveInterpretation: string | null;
    agreementWithMachine: string;
    disagreementReason: string | null;
    withinReadingWindow: boolean;
    actualReadingTime: number | null;
    readingTimeViolationReason: string | null;
    disclaimerAcknowledged: boolean;
    interpretedAt: string;
  } | null;
  
  // Chain metadata
  previousRecordHash: string | null;
  chainIndex: number;
  
  // Canonical metadata
  hashingAlgorithm: string;
  schemaVersion: string;
  canonicalizationVersion: string;
}

/**
 * Create V1 canonical record (legacy, for backward compatibility verification).
 */
export function createCanonicalV1(
  test: any,
  classification: any,
  imageHash: string,
): string {
  const canonicalObj: CanonicalRecordV1 = {
    testId: test.id,
    testNumber: test.testNumber,
    caseId: test.caseId || null,
    sampleId: test.sampleId || null,
    operatorId: test.operatorId,
    kitId: test.kitId,
    configurationVersion: test.configurationVersion,
    classificationResult: classification.result,
    classificationConfidence: classification.confidence || null,
    algorithmVersion: classification.algorithmVersion,
    modelVersion: classification.modelVersion,
    imageHash,
    hashingAlgorithm: 'SHA-256',
    schemaVersion: '1.0',
    canonicalizationVersion: '1.0',
  };

  // Sort keys for deterministic serialization
  const sortedKeys = Object.keys(canonicalObj).sort();
  const sortedObj: any = {};
  for (const key of sortedKeys) {
    sortedObj[key] = canonicalObj[key as keyof typeof canonicalObj];
  }

  return JSON.stringify(sortedObj);
}

/**
 * Create V2 canonical record (extended with chain fields).
 */
export function createCanonicalV2(
  test: any,
  classification: any,
  imageAsset: any,
  previousRecordHash: string | null,
  chainIndex: number,
): string {
  const canonicalObj: CanonicalRecordV2 = {
    version: 2,
    testId: test.id,
    testNumber: test.testNumber,
    caseId: test.caseId || null,
    sampleId: test.sampleId || null,
    operatorId: test.operatorId,
    kitId: test.kitId,
    configurationVersion: test.configurationVersion,
    classificationResult: classification.result,
    classificationConfidence: classification.confidence || null,
    algorithmVersion: classification.algorithmVersion,
    modelVersion: classification.modelVersion,
    clientImageHash: imageAsset.clientHash || null,
    serverImageHash: imageAsset.serverHash,
    captureMetadata: imageAsset.captureMetadata || null,
    previousRecordHash,
    chainIndex,
    hashingAlgorithm: 'SHA-256',
    schemaVersion: '2.0',
    canonicalizationVersion: '2.0',
  };

  // Sort keys for deterministic serialization
  const sortedKeys = Object.keys(canonicalObj).sort();
  const sortedObj: any = {};
  for (const key of sortedKeys) {
    sortedObj[key] = canonicalObj[key as keyof typeof canonicalObj];
  }

  return JSON.stringify(sortedObj);
}

/**
 * RFC 8785 JSON Canonicalization Scheme (JCS)
 * https://www.rfc-editor.org/rfc/rfc8785.html
 * 
 * Produces deterministic JSON serialization for cross-language compatibility.
 * CRITICAL: Use this for evidence records that must be verifiable across TypeScript/Python.
 */
export function canonicalizeRFC8785(value: any): string {
  // Handle primitives
  if (value === null) return 'null';
  if (typeof value === 'boolean') return value.toString();
  if (typeof value === 'string') return JSON.stringify(value);
  
  // Handle numbers (RFC 8785 Section 3.2.2.3)
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error('RFC 8785: Infinity and NaN are not allowed');
    }
    if (Object.is(value, -0)) return '0'; // Negative zero becomes positive zero
    
    // Use ES6 number serialization (compatible with RFC 8785)
    const str = value.toString();
    if (str.includes('e') || str.includes('E')) {
      // Scientific notation - ensure lowercase 'e'
      return str.toLowerCase();
    }
    return str;
  }
  
  // Handle arrays (RFC 8785 Section 3.2.2.2)
  if (Array.isArray(value)) {
    const elements = value.map(item => canonicalizeRFC8785(item));
    return `[${elements.join(',')}]`;
  }
  
  // Handle objects (RFC 8785 Section 3.2.2.1)
  if (typeof value === 'object') {
    // Sort keys lexicographically by UTF-16 code unit
    const sortedKeys = Object.keys(value).sort();
    const pairs = sortedKeys.map(key => {
      const canonicalKey = JSON.stringify(key);
      const canonicalValue = canonicalizeRFC8785(value[key]);
      return `${canonicalKey}:${canonicalValue}`;
    });
    return `{${pairs.join(',')}}`;
  }
  
  throw new Error(`RFC 8785: Unsupported type ${typeof value}`);
}

/**
 * Create V3 canonical record: safety-hardened with colorimetric measurements.
 * Uses RFC 8785 for deterministic cross-language serialization.
 * 
 * CRITICAL: This format includes ALL security-relevant fields:
 * - Colorimetric measurements (observedColorLab, colorDistance, nearestReferenceLabel)
 * - Quality assessment (qualityStatus, qualityIssues)
 * - Validation status (validationStatus from both TestKit and Classification)
 * - Operator interpretation (if exists - preserves human review in evidence chain)
 * - Kit metadata (kitCode for traceability)
 */
export function createCanonicalV3(
  test: any,
  classification: any,
  imageAsset: any,
  testKit: any,
  operatorInterpretation: any | null,
  previousRecordHash: string | null,
  chainIndex: number,
): string {
  const canonicalObj: CanonicalRecordV3 = {
    version: 3,
    testId: test.id,
    testNumber: test.testNumber,
    caseId: test.caseId || null,
    sampleId: test.sampleId || null,
    operatorId: test.operatorId,
    kitId: test.kitId,
    kitCode: testKit.code,
    configurationVersion: test.configurationVersion,
    
    // Colorimetric measurements
    observedColorLab: classification.observedColorLab,
    colorDistance: classification.colorDistance,
    nearestReferenceLabel: classification.nearestReferenceLabel || null,
    
    // Quality assessment
    qualityStatus: classification.qualityStatus,
    qualityIssues: classification.qualityIssues || null,
    
    // Validation status
    validationStatus: classification.validationStatus,
    
    // DEPRECATED (kept for backward compatibility verification)
    classificationResult: classification.result || null,
    classificationConfidence: classification.confidence || null,
    
    // Algorithm identifiers
    algorithmVersion: classification.algorithmVersion,
    modelVersion: classification.modelVersion,
    pipelineId: classification.pipelineId || null,
    
    // Image integrity
    clientImageHash: imageAsset.clientHash || null,
    serverImageHash: imageAsset.serverHash,
    captureMetadata: imageAsset.captureMetadata || null,
    
    // Operator interpretation (if exists)
    operatorInterpretation: operatorInterpretation ? {
      id: operatorInterpretation.id,
      visualObservation: operatorInterpretation.visualObservation,
      selectedReferenceColor: operatorInterpretation.selectedReferenceColor || null,
      presumptiveInterpretation: operatorInterpretation.presumptiveInterpretation || null,
      agreementWithMachine: operatorInterpretation.agreementWithMachine,
      disagreementReason: operatorInterpretation.disagreementReason || null,
      withinReadingWindow: operatorInterpretation.withinReadingWindow,
      actualReadingTime: operatorInterpretation.actualReadingTime || null,
      readingTimeViolationReason: operatorInterpretation.readingTimeViolationReason || null,
      disclaimerAcknowledged: operatorInterpretation.disclaimerAcknowledged,
      interpretedAt: operatorInterpretation.interpretedAt.toISOString(),
    } : null,
    
    // Chain metadata
    previousRecordHash,
    chainIndex,
    
    // Canonical metadata
    hashingAlgorithm: 'SHA-256',
    schemaVersion: '3.0',
    canonicalizationVersion: '3.0-RFC8785',
  };
  
  // Use RFC 8785 JSON Canonicalization Scheme for deterministic serialization
  return canonicalizeRFC8785(canonicalObj);
}
