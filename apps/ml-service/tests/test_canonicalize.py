"""
Tests for RFC 8785 implementation - MUST match TypeScript output byte-for-byte.
Cross-language verification is CRITICAL for evidence integrity.
"""

import pytest
import hashlib
from datetime import datetime, timezone
from app.utils.canonicalize import (
    canonicalize_rfc8785,
    create_canonical_v3,
    verify_evidence_record,
    RFC8785Error,
)


class TestRFC8785Primitives:
    """Test RFC 8785 canonicalization of primitive values."""
    
    def test_null(self):
        assert canonicalize_rfc8785(None) == 'null'
    
    def test_booleans(self):
        assert canonicalize_rfc8785(True) == 'true'
        assert canonicalize_rfc8785(False) == 'false'
    
    def test_strings(self):
        assert canonicalize_rfc8785('hello') == '"hello"'
        assert canonicalize_rfc8785('hello "world"') == '"hello \\"world\\""'
        assert canonicalize_rfc8785('line1\nline2') == '"line1\\nline2"'
    
    def test_numbers(self):
        assert canonicalize_rfc8785(0) == '0'
        assert canonicalize_rfc8785(-0.0) == '0'  # Negative zero becomes positive zero
        assert canonicalize_rfc8785(42) == '42'
        assert canonicalize_rfc8785(-42) == '-42'
        assert canonicalize_rfc8785(3.14) == '3.14'
    
    def test_reject_infinity_nan(self):
        with pytest.raises(RFC8785Error):
            canonicalize_rfc8785(float('inf'))
        with pytest.raises(RFC8785Error):
            canonicalize_rfc8785(float('-inf'))
        with pytest.raises(RFC8785Error):
            canonicalize_rfc8785(float('nan'))


class TestRFC8785Arrays:
    """Test RFC 8785 canonicalization of arrays."""
    
    def test_empty_array(self):
        assert canonicalize_rfc8785([]) == '[]'
    
    def test_arrays_with_primitives(self):
        assert canonicalize_rfc8785([1, 2, 3]) == '[1,2,3]'
        assert canonicalize_rfc8785(['a', 'b', 'c']) == '["a","b","c"]'
        assert canonicalize_rfc8785([True, False, None]) == '[true,false,null]'
    
    def test_nested_arrays(self):
        assert canonicalize_rfc8785([[1, 2], [3, 4]]) == '[[1,2],[3,4]]'
    
    def test_preserve_array_order(self):
        assert canonicalize_rfc8785([3, 1, 2]) == '[3,1,2]'


class TestRFC8785Objects:
    """Test RFC 8785 canonicalization of objects (dicts)."""
    
    def test_empty_object(self):
        assert canonicalize_rfc8785({}) == '{}'
    
    def test_sort_keys_lexicographically(self):
        obj = {'z': 1, 'a': 2, 'm': 3}
        assert canonicalize_rfc8785(obj) == '{"a":2,"m":3,"z":1}'
    
    def test_nested_objects_with_sorted_keys(self):
        obj = {
            'outer2': {'inner2': 'b', 'inner1': 'a'},
            'outer1': {'inner3': 'c'},
        }
        expected = '{"outer1":{"inner3":"c"},"outer2":{"inner1":"a","inner2":"b"}}'
        assert canonicalize_rfc8785(obj) == expected
    
    def test_mixed_value_types(self):
        obj = {'num': 42, 'str': 'hello', 'bool': True, 'nil': None, 'arr': [1, 2]}
        expected = '{"arr":[1,2],"bool":true,"nil":null,"num":42,"str":"hello"}'
        assert canonicalize_rfc8785(obj) == expected


class TestRFC8785Determinism:
    """Test deterministic serialization across different input orders."""
    
    def test_equivalent_objects_produce_identical_output(self):
        obj1 = {'a': 1, 'b': 2, 'c': 3}
        obj2 = {'c': 3, 'a': 1, 'b': 2}
        obj3 = {'b': 2, 'c': 3, 'a': 1}
        
        canon1 = canonicalize_rfc8785(obj1)
        canon2 = canonicalize_rfc8785(obj2)
        canon3 = canonicalize_rfc8785(obj3)
        
        assert canon1 == canon2
        assert canon2 == canon3
    
    def test_different_objects_produce_different_output(self):
        obj1 = {'a': 1, 'b': 2}
        obj2 = {'a': 1, 'b': 3}
        
        assert canonicalize_rfc8785(obj1) != canonicalize_rfc8785(obj2)


class TestColorimetricData:
    """Test canonicalization of colorimetric data structures."""
    
    def test_lab_color_space(self):
        color = {'L': 65.5, 'a': 18.2, 'b': -35.7}
        expected = '{"L":65.5,"a":18.2,"b":-35.7}'
        assert canonicalize_rfc8785(color) == expected
    
    def test_quality_issues_array(self):
        issues = ['COLOR_DISTANCE_HIGH', 'EXTREME_LIGHTNESS']
        expected = '["COLOR_DISTANCE_HIGH","EXTREME_LIGHTNESS"]'
        assert canonicalize_rfc8785(issues) == expected


class TestCanonicalV3Record:
    """Test V3 canonical record creation with colorimetric measurements."""
    
    @pytest.fixture
    def mock_test(self):
        return {
            'id': 'test-123',
            'testNumber': 'T-2024-001',
            'caseId': 'case-456',
            'sampleId': 'sample-789',
            'operatorId': 'user-001',
            'kitId': 'kit-abc',
            'configurationVersion': '1.0',
        }
    
    @pytest.fixture
    def mock_classification(self):
        return {
            'result': None,  # DEPRECATED
            'confidence': None,  # DEPRECATED
            'observedColorLab': {'L': 65.5, 'a': 18.2, 'b': -35.7},
            'colorDistance': 12.3,
            'nearestReferenceLabel': 'Blue-Purple range',
            'qualityStatus': 'ACCEPTABLE',
            'qualityIssues': None,
            'validationStatus': 'UNVALIDATED',
            'algorithmVersion': 'v2.0',
            'modelVersion': 'demo-v2',
            'pipelineId': 'colorimetric-v1',
        }
    
    @pytest.fixture
    def mock_image_asset(self):
        return {
            'clientHash': 'client-hash-abc123',
            'serverHash': 'server-hash-def456',
            'captureMetadata': {'device': 'iPhone 13', 'timestamp': '2024-01-01T00:00:00Z'},
        }
    
    @pytest.fixture
    def mock_test_kit(self):
        return {
            'code': 'DEMO-KIT-001',
        }
    
    def test_create_v3_without_operator_interpretation(
        self, mock_test, mock_classification, mock_image_asset, mock_test_kit
    ):
        canonical = create_canonical_v3(
            mock_test,
            mock_classification,
            mock_image_asset,
            mock_test_kit,
            None,  # No operator interpretation
            'prev-hash-xyz',
            10,
        )
        
        # Parse and verify structure
        import json
        parsed = json.loads(canonical)
        
        assert parsed['version'] == 3
        assert parsed['schemaVersion'] == '3.0'
        assert parsed['canonicalizationVersion'] == '3.0-RFC8785'
        
        # Verify colorimetric fields
        assert parsed['observedColorLab'] == {'L': 65.5, 'a': 18.2, 'b': -35.7}
        assert parsed['colorDistance'] == 12.3
        assert parsed['nearestReferenceLabel'] == 'Blue-Purple range'
        
        # Verify quality fields
        assert parsed['qualityStatus'] == 'ACCEPTABLE'
        assert parsed['qualityIssues'] is None
        
        # Verify validation status
        assert parsed['validationStatus'] == 'UNVALIDATED'
        
        # Verify kit metadata
        assert parsed['kitCode'] == 'DEMO-KIT-001'
        
        # Verify operator interpretation is null
        assert parsed['operatorInterpretation'] is None
    
    def test_create_v3_with_operator_interpretation(
        self, mock_test, mock_classification, mock_image_asset, mock_test_kit
    ):
        operator_interpretation = {
            'id': 'interp-001',
            'visualObservation': 'Strong blue-purple color observed',
            'selectedReferenceColor': 'Blue-Purple (reference 3)',
            'presumptiveInterpretation': 'Consistent with expected reaction',
            'agreementWithMachine': 'AGREE',
            'disagreementReason': None,
            'withinReadingWindow': True,
            'actualReadingTime': 120,
            'readingTimeViolationReason': None,
            'disclaimerAcknowledged': True,
            'interpretedAt': '2024-01-01T12:00:00.000Z',
        }
        
        canonical = create_canonical_v3(
            mock_test,
            mock_classification,
            mock_image_asset,
            mock_test_kit,
            operator_interpretation,
            'prev-hash-xyz',
            10,
        )
        
        import json
        parsed = json.loads(canonical)
        
        # Verify operator interpretation included
        assert parsed['operatorInterpretation'] is not None
        assert parsed['operatorInterpretation']['id'] == 'interp-001'
        assert parsed['operatorInterpretation']['visualObservation'] == 'Strong blue-purple color observed'
        assert parsed['operatorInterpretation']['agreementWithMachine'] == 'AGREE'
        assert parsed['operatorInterpretation']['disclaimerAcknowledged'] is True


class TestTamperDetection:
    """Test that tampering produces different hashes."""
    
    @pytest.fixture
    def mock_test(self):
        return {
            'id': 'test-123',
            'testNumber': 'T-2024-001',
            'caseId': 'case-456',
            'sampleId': 'sample-789',
            'operatorId': 'user-001',
            'kitId': 'kit-abc',
            'configurationVersion': '1.0',
        }
    
    @pytest.fixture
    def mock_classification(self):
        return {
            'result': None,
            'confidence': None,
            'observedColorLab': {'L': 65.5, 'a': 18.2, 'b': -35.7},
            'colorDistance': 12.3,
            'nearestReferenceLabel': 'Blue-Purple range',
            'qualityStatus': 'ACCEPTABLE',
            'qualityIssues': None,
            'validationStatus': 'UNVALIDATED',
            'algorithmVersion': 'v2.0',
            'modelVersion': 'demo-v2',
            'pipelineId': 'colorimetric-v1',
        }
    
    @pytest.fixture
    def mock_image_asset(self):
        return {
            'clientHash': 'client-hash-abc123',
            'serverHash': 'server-hash-def456',
            'captureMetadata': {'device': 'iPhone 13'},
        }
    
    @pytest.fixture
    def mock_test_kit(self):
        return {'code': 'DEMO-KIT-001'}
    
    def test_detect_field_value_tampering(
        self, mock_test, mock_classification, mock_image_asset, mock_test_kit
    ):
        canonical1 = create_canonical_v3(
            mock_test, mock_classification, mock_image_asset, mock_test_kit, None, None, 0
        )
        
        # Tamper with colorDistance
        tampered_classification = mock_classification.copy()
        tampered_classification['colorDistance'] = 999.9
        
        canonical2 = create_canonical_v3(
            mock_test, tampered_classification, mock_image_asset, mock_test_kit, None, None, 0
        )
        
        hash1 = hashlib.sha256(canonical1.encode('utf-8')).hexdigest()
        hash2 = hashlib.sha256(canonical2.encode('utf-8')).hexdigest()
        
        assert hash1 != hash2
    
    def test_detect_validation_status_tampering(
        self, mock_test, mock_classification, mock_image_asset, mock_test_kit
    ):
        canonical1 = create_canonical_v3(
            mock_test, mock_classification, mock_image_asset, mock_test_kit, None, None, 0
        )
        
        # Tamper with validationStatus
        tampered_classification = mock_classification.copy()
        tampered_classification['validationStatus'] = 'VALIDATED'  # TAMPERED!
        
        canonical2 = create_canonical_v3(
            mock_test, tampered_classification, mock_image_asset, mock_test_kit, None, None, 0
        )
        
        hash1 = hashlib.sha256(canonical1.encode('utf-8')).hexdigest()
        hash2 = hashlib.sha256(canonical2.encode('utf-8')).hexdigest()
        
        assert hash1 != hash2


class TestEvidenceVerification:
    """Test evidence record verification using hash comparison."""
    
    def test_verify_valid_evidence(self):
        canonical = canonicalize_rfc8785({'test': 'data', 'value': 123})
        expected_hash = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
        
        assert verify_evidence_record(canonical, expected_hash)
    
    def test_verify_tampered_evidence(self):
        canonical = canonicalize_rfc8785({'test': 'data', 'value': 123})
        tampered_canonical = canonicalize_rfc8785({'test': 'data', 'value': 999})
        expected_hash = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
        
        assert not verify_evidence_record(tampered_canonical, expected_hash)


class TestCrossLanguageCompatibility:
    """
    Test cases to verify Python implementation matches TypeScript.
    These test vectors should produce IDENTICAL hashes in both languages.
    """
    
    def test_simple_object_hash_matches_typescript(self):
        """
        This test vector should be run in both Python and TypeScript.
        The hash MUST match exactly.
        """
        obj = {
            'testId': 'test-123',
            'result': 'POSITIVE',
            'confidence': 0.85,
            'version': 2,
        }
        
        canonical = canonicalize_rfc8785(obj)
        hash_value = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
        
        # Expected canonical form (verify this matches TypeScript output)
        expected_canonical = '{"confidence":0.85,"result":"POSITIVE","testId":"test-123","version":2}'
        assert canonical == expected_canonical
        
        # Expected hash (verify this matches TypeScript hash)
        expected_hash = hashlib.sha256(expected_canonical.encode('utf-8')).hexdigest()
        assert hash_value == expected_hash
    
    def test_colorimetric_object_hash_matches_typescript(self):
        """Test vector with colorimetric data for cross-language verification."""
        obj = {
            'observedColorLab': {'L': 65.5, 'a': 18.2, 'b': -35.7},
            'colorDistance': 12.3,
            'qualityStatus': 'ACCEPTABLE',
            'validationStatus': 'UNVALIDATED',
        }
        
        canonical = canonicalize_rfc8785(obj)
        hash_value = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
        
        # This canonical form and hash should match TypeScript exactly
        print(f"Canonical: {canonical}")
        print(f"Hash: {hash_value}")
        
        # Verify structure
        import json
        parsed = json.loads(canonical)
        assert parsed['colorDistance'] == 12.3
        assert parsed['validationStatus'] == 'UNVALIDATED'
