"""
RFC 8785 JSON Canonicalization Scheme (JCS) implementation for Python.
https://www.rfc-editor.org/rfc/rfc8785.html

Used for cross-language evidence verification between TypeScript API and Python ML service.
CRITICAL: Must produce byte-for-byte identical output to TypeScript implementation.
"""

import json
import math
from typing import Any


class RFC8785Error(Exception):
    """Errors related to RFC 8785 canonicalization."""
    pass


def canonicalize_rfc8785(value: Any) -> str:
    """
    Canonicalize a Python value according to RFC 8785 JSON Canonicalization Scheme.
    
    Args:
        value: Python value to canonicalize (must be JSON-compatible)
        
    Returns:
        Canonical JSON string representation
        
    Raises:
        RFC8785Error: If value cannot be canonicalized (e.g., Infinity, NaN, unsupported types)
    """
    # Handle None (null)
    if value is None:
        return 'null'
    
    # Handle booleans
    if isinstance(value, bool):
        return 'true' if value else 'false'
    
    # Handle strings
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    
    # Handle numbers (RFC 8785 Section 3.2.2.3)
    if isinstance(value, (int, float)):
        if math.isnan(value) or math.isinf(value):
            raise RFC8785Error('RFC 8785: Infinity and NaN are not allowed')
        
        # Handle negative zero
        if value == 0 and math.copysign(1, value) == -1:
            return '0'
        
        # Python's default number serialization is compatible with RFC 8785
        # for most cases, but we need to handle scientific notation
        if isinstance(value, float):
            # Use Python's repr which matches ES6 number serialization
            result = repr(value)
            # Ensure lowercase 'e' for scientific notation
            if 'e' in result.lower():
                result = result.lower()
            return result
        
        return str(value)
    
    # Handle arrays (lists)
    if isinstance(value, list):
        elements = [canonicalize_rfc8785(item) for item in value]
        return f"[{','.join(elements)}]"
    
    # Handle objects (dicts)
    if isinstance(value, dict):
        # Sort keys lexicographically by UTF-16 code units
        # Python's default sort is by Unicode code points which matches UTF-16 for most cases
        sorted_keys = sorted(value.keys())
        
        pairs = []
        for key in sorted_keys:
            canonical_key = json.dumps(key, ensure_ascii=False)
            canonical_value = canonicalize_rfc8785(value[key])
            pairs.append(f"{canonical_key}:{canonical_value}")
        
        return f"{{{','.join(pairs)}}}"
    
    raise RFC8785Error(f'RFC 8785: Unsupported type {type(value).__name__}')


def verify_evidence_record(
    canonical_string: str,
    expected_hash: str,
    algorithm: str = 'sha256'
) -> bool:
    """
    Verify an evidence record by recomputing its hash.
    
    Args:
        canonical_string: Canonical JSON representation
        expected_hash: Expected SHA-256 hash (hex)
        algorithm: Hashing algorithm (default: sha256)
        
    Returns:
        True if hash matches, False otherwise
    """
    import hashlib
    
    if algorithm.lower() == 'sha256' or algorithm.upper() == 'SHA-256':
        computed_hash = hashlib.sha256(canonical_string.encode('utf-8')).hexdigest()
    else:
        raise RFC8785Error(f'Unsupported hashing algorithm: {algorithm}')
    
    return computed_hash == expected_hash


def create_canonical_v3(
    test: dict,
    classification: dict,
    image_asset: dict,
    test_kit: dict,
    operator_interpretation: dict | None,
    previous_record_hash: str | None,
    chain_index: int,
) -> str:
    """
    Create V3 canonical record: safety-hardened with colorimetric measurements.
    Matches TypeScript implementation for cross-language verification.
    
    Args:
        test: Test record
        classification: Classification with colorimetric fields
        image_asset: Image asset with hashes
        test_kit: Test kit metadata
        operator_interpretation: Optional operator review
        previous_record_hash: Previous record hash in chain
        chain_index: Index in evidence chain
        
    Returns:
        Canonical JSON string using RFC 8785
    """
    canonical_obj = {
        'version': 3,
        'testId': test['id'],
        'testNumber': test['testNumber'],
        'caseId': test.get('caseId'),
        'sampleId': test.get('sampleId'),
        'operatorId': test['operatorId'],
        'kitId': test['kitId'],
        'kitCode': test_kit['code'],
        'configurationVersion': test['configurationVersion'],
        
        # Colorimetric measurements
        'observedColorLab': classification['observedColorLab'],
        'colorDistance': classification['colorDistance'],
        'nearestReferenceLabel': classification.get('nearestReferenceLabel'),
        
        # Quality assessment
        'qualityStatus': classification['qualityStatus'],
        'qualityIssues': classification.get('qualityIssues'),
        
        # Validation status
        'validationStatus': classification['validationStatus'],
        
        # DEPRECATED (kept for backward compatibility)
        'classificationResult': classification.get('result'),
        'classificationConfidence': classification.get('confidence'),
        
        # Algorithm identifiers
        'algorithmVersion': classification['algorithmVersion'],
        'modelVersion': classification['modelVersion'],
        'pipelineId': classification.get('pipelineId'),
        
        # Image integrity
        'clientImageHash': image_asset.get('clientHash'),
        'serverImageHash': image_asset['serverHash'],
        'captureMetadata': image_asset.get('captureMetadata'),
        
        # Operator interpretation (if exists)
        'operatorInterpretation': None,
        
        # Chain metadata
        'previousRecordHash': previous_record_hash,
        'chainIndex': chain_index,
        
        # Canonical metadata
        'hashingAlgorithm': 'SHA-256',
        'schemaVersion': '3.0',
        'canonicalizationVersion': '3.0-RFC8785',
    }
    
    # Include operator interpretation if exists
    if operator_interpretation:
        canonical_obj['operatorInterpretation'] = {
            'id': operator_interpretation['id'],
            'visualObservation': operator_interpretation['visualObservation'],
            'selectedReferenceColor': operator_interpretation.get('selectedReferenceColor'),
            'presumptiveInterpretation': operator_interpretation.get('presumptiveInterpretation'),
            'agreementWithMachine': operator_interpretation['agreementWithMachine'],
            'disagreementReason': operator_interpretation.get('disagreementReason'),
            'withinReadingWindow': operator_interpretation['withinReadingWindow'],
            'actualReadingTime': operator_interpretation.get('actualReadingTime'),
            'readingTimeViolationReason': operator_interpretation.get('readingTimeViolationReason'),
            'disclaimerAcknowledged': operator_interpretation['disclaimerAcknowledged'],
            'interpretedAt': operator_interpretation['interpretedAt'],  # ISO 8601 string
        }
    
    return canonicalize_rfc8785(canonical_obj)
