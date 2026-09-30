from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Any
from enum import Enum

class GroundTruthState(str, Enum):
    PENDING_LAB_RESULT = "PENDING_LAB_RESULT"
    LAB_RESULT_RECEIVED = "LAB_RESULT_RECEIVED"
    PENDING_REVIEW = "PENDING_REVIEW"
    VERIFIED = "VERIFIED"
    DISPUTED = "DISPUTED"
    REJECTED = "REJECTED"

class AssayConfig(BaseModel):
    assay_id: str
    kit_identity: str
    intended_measurement: str
    approved_sample_types: List[str]
    reference_laboratory_method: str
    measurement_units: str
    reporting_limits: Dict[str, float]
    sample_collection_requirements: str
    storage_conditions: str
    transport_conditions: str
    reagent_lot_tracking_required: bool = True
    reference_card_version: str
    image_capture_procedure: str
    environmental_metadata_required: List[str]
    quality_control_requirements: str
    exclusion_criteria: List[str]
    retention_policy: str
    
    # Flag to indicate if this config has formal scientific approval
    scientifically_approved: bool = False
    scientific_approval_reference: Optional[str] = None

class PilotProtocol(BaseModel):
    protocol_version: str
    description: str
    assay_configs: Dict[str, AssayConfig]
    
    def validate_assay(self, kit_code: str) -> bool:
        return kit_code in self.assay_configs
