from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum

class DatasetSampleStatus(str, Enum):
    INGESTED = "INGESTED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    VERIFIED_FOR_DEVELOPMENT = "VERIFIED_FOR_DEVELOPMENT"
    ELIGIBLE_FOR_EVALUATION = "ELIGIBLE_FOR_EVALUATION"
    EXCLUDED = "EXCLUDED"
    DISPUTED = "DISPUTED"

class DatasetSampleSchema(BaseModel):
    # Identity & Integrity
    sample_id: str = Field(..., description="Unique sample identifier")
    original_test_id: Optional[str] = Field(None, description="Original test identifier")
    image_hash: str = Field(..., description="Original image SHA-256")
    evidence_record_id: Optional[str] = None
    dataset_version: str = Field("1.0.0")
    
    # Assay & Collection
    kit_code: str = Field(..., description="Assay and test-kit identity")
    reagent_lot: Optional[str] = None
    collection_site: Optional[str] = None
    capture_session_id: Optional[str] = None
    operator_id: Optional[str] = None
    device_metadata: Optional[Dict[str, Any]] = None
    environment_data: Optional[Dict[str, Any]] = None
    
    # Reference & Measurements
    reference_card_version: Optional[str] = None
    calibration_config: Optional[str] = None
    raw_measurements: Optional[Dict[str, Any]] = None
    calibrated_measurements: Optional[Dict[str, Any]] = None
    quality_assessment: Optional[Dict[str, Any]] = None
    
    # Ground Truth
    reference_method: Optional[str] = None
    ground_truth_label: Optional[str] = None
    ground_truth_value: Optional[float] = None
    ground_truth_units: Optional[str] = None
    ground_truth_uncertainty: Optional[float] = None
    ground_truth_timestamp: Optional[datetime] = None
    labeling_protocol_version: Optional[str] = None
    reviewer_id: Optional[str] = None
    
    # Privacy
    consent_status: Optional[str] = None
    retention_policy: Optional[str] = None
    
    status: DatasetSampleStatus = DatasetSampleStatus.INGESTED
    exclusion_reason: Optional[str] = None

class ValidationResult(BaseModel):
    is_valid: bool
    status: DatasetSampleStatus
    errors: List[str]
    warnings: List[str]
