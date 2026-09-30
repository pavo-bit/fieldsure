from typing import List, Dict, Any, Optional
from .models import DatasetSampleSchema, DatasetSampleStatus, ValidationResult

class DatasetValidator:
    def __init__(self):
        pass

    def validate_ingestion(self, sample: DatasetSampleSchema) -> ValidationResult:
        errors = []
        warnings = []
        
        # 1. Validate Image Hashes
        if not sample.image_hash or len(sample.image_hash) != 64:
            errors.append("Invalid or missing image hash (must be SHA-256).")
            
        # 2. Check for missing metadata
        if not sample.kit_code:
            errors.append("Missing assay kit_code.")
            
        if not sample.reference_card_version:
            warnings.append("Missing reference card version.")
            
        # 3. Ground Truth Verification
        if sample.ground_truth_label or sample.ground_truth_value is not None:
            if not sample.reference_method:
                errors.append("Ground truth provided without reference laboratory method.")
            if not sample.reviewer_id:
                errors.append("Ground truth requires an authorized reviewer.")
        
        # Determine status based on validation
        if len(errors) > 0:
            status = DatasetSampleStatus.EXCLUDED
            is_valid = False
        else:
            is_valid = True
            if sample.ground_truth_label or sample.ground_truth_value is not None:
                status = DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION
            else:
                status = DatasetSampleStatus.PENDING_VERIFICATION
                
        return ValidationResult(
            is_valid=is_valid,
            status=status,
            errors=errors,
            warnings=warnings
        )
