from app.schemas.responses import (
    QualityAssessment, 
    MeasurementUncertainty, 
    ClassificationFeatures
)
from typing import Dict, Any, Optional

class DecisionGate:
    """Central decision gate for safe abstention before interpretation."""
    
    def evaluate(
        self,
        assessment: QualityAssessment,
        uncertainty: Optional[MeasurementUncertainty],
        features: ClassificationFeatures,
        config_version: str,
        is_model_validated: bool
    ) -> Dict[str, Any]:
        
        # 1. Image Integrity and Recapture needed
        if assessment.image_integrity.status == "REJECTED":
            return {
                "gate_status": "REJECTED_RECAPTURE_REQUIRED",
                "quality_status": "REJECTED",
                "can_proceed": False
            }
            
        # 2. Overall Image Quality
        if assessment.overall_status == "REJECTED":
            return {
                "gate_status": "REJECTED_QUALITY",
                "quality_status": "REJECTED",
                "can_proceed": False
            }
            
        # 3. Reference Card / Calibration Failure
        if assessment.reference_card_quality.status == "REJECTED" or assessment.calibration_quality.status == "REJECTED":
            return {
                "gate_status": "REFERENCE_OR_CALIBRATION_FAILURE",
                "quality_status": "REJECTED",
                "can_proceed": False
            }
            
        # 4. Uncertainty limitations
        if uncertainty and uncertainty.is_available:
            if uncertainty.roi_variability and uncertainty.roi_variability > 10.0:
                return {
                    "gate_status": "HIGH_MEASUREMENT_UNCERTAINTY",
                    "quality_status": "MARGINAL",
                    "can_proceed": True,
                    "interpretation_withheld": True
                }
                
        # 5. Out of supported domain / Color range
        # Assume L should be within reasonable bounds if card was detected, 
        # but check for extremely abnormal lightness
        if features.lab_mean_l < 5 or features.lab_mean_l > 98:
            return {
                "gate_status": "OUT_OF_SUPPORTED_DOMAIN",
                "quality_status": "MARGINAL",
                "can_proceed": True,
                "interpretation_withheld": True
            }
            
        # 6. Model available and Validated
        if not is_model_validated:
            return {
                "gate_status": "MEASUREMENT_AVAILABLE_UNVALIDATED",
                "quality_status": assessment.overall_status,
                "can_proceed": True,
                "interpretation_withheld": False,
                "validation_status": "UNVALIDATED"
            }
            
        return {
            "gate_status": "VALIDATED_INTERPRETATION",
            "quality_status": assessment.overall_status,
            "can_proceed": True,
            "interpretation_withheld": False,
            "validation_status": "VALIDATED"
        }
