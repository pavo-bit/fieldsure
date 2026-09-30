from pydantic import BaseModel
from typing import Dict, List, Optional, Any

class ImageQualityDiagnostics(BaseModel):
    width: int
    height: int
    brightness: float
    blur_score: float
    reference_card_detected: bool
    test_region_detected: bool

class QualityDimension(BaseModel):
    status: str  # ACCEPTABLE, MARGINAL, REJECTED
    issues: List[str] = []
    metrics: Dict[str, Any] = {}

class QualityAssessment(BaseModel):
    overall_status: str  # ACCEPTABLE, MARGINAL, REJECTED
    image_integrity: QualityDimension
    focus_and_resolution: QualityDimension
    exposure_and_illumination: QualityDimension
    reference_card_quality: QualityDimension
    calibration_quality: QualityDimension
    
    can_proceed_to_measurement: bool
    can_interpret: bool
    recapture_guidance: Optional[str] = None
    config_version: str

class MeasurementUncertainty(BaseModel):
    pixel_sampling_std_l: Optional[float] = None
    pixel_sampling_std_a: Optional[float] = None
    pixel_sampling_std_b: Optional[float] = None
    roi_variability: Optional[float] = None
    calibration_residual_delta_e: Optional[float] = None
    is_available: bool = True

class ImageQualityResult(BaseModel):
    # DEPRECATED fields for backward compatibility
    acceptable: bool
    issues: List[str]
    diagnostics: ImageQualityDiagnostics
    # New detailed assessment
    assessment: Optional[QualityAssessment] = None

class ClassificationFeatures(BaseModel):
    """
    Color measurement features.

    Field naming and semantics:
    - lab_mean_l/a/b: True CIELAB coordinates (L in [0,100], a/b unbounded,
      derived from sRGB linearisation → XYZ D65 → CIELAB D65).
    - delta_e_76: CIE76 Euclidean colour difference to nearest reference.
    - delta_e_2000: CIEDE2000 colour difference to nearest reference (preferred metric).
    - chroma: sqrt(a^2 + b^2); purely geometric magnitude, NOT a colour difference.
    - color_distance: DEPRECATED alias for delta_e_2000; retained for downstream
      compatibility but explicitly labelled deprecated.
    - color_space: colour space of the LAB values ("CIELAB").
    - illuminant: reference white used ("D65").
    - conversion_version: string identifier for the conversion pipeline version.
    """
    # True CIELAB coordinates
    lab_mean_l: float
    lab_mean_a: float
    lab_mean_b: float

    # Correct colour-difference metrics
    delta_e_76: float = 0.0    # CIE76 Euclidean ΔE
    delta_e_2000: float = 0.0  # CIEDE2000 ΔE00

    # Chroma magnitude (NOT a colour difference)
    chroma: float = 0.0

    # Legacy HSV (kept for backward compat, may be absent)
    hsv_mean_h: float = 0.0
    hsv_mean_s: float = 0.0
    hsv_mean_v: float = 0.0

    # DEPRECATED: legacy field; equals delta_e_2000 for callers that read it
    color_distance: float = 0.0

    # Colour-space metadata
    color_space: str = "CIELAB"
    illuminant: str = "D65"
    conversion_version: str = "srgb-d65-v1"

    # Calibration status propagated from calibrator
    calibration_status: str = "NOT_ATTEMPTED"
    
class ColorObservation(BaseModel):
    """Observed color in LAB color space"""
    L: float  # Lightness (0-100)
    a: float  # Green-Red axis
    b: float  # Blue-Yellow axis

class ClassificationResult(BaseModel):
    """
    Safe classification output - observed color and quality, NOT drug identification.
    
    CRITICAL: This is a colorimetric measurement, not a confirmed drug identification.
    All interpretations are presumptive and require laboratory confirmation.
    """
    # Observed color measurement
    observedColor: ColorObservation
    
    # Distance to nearest reference color (deltaE2000 metric)
    colorDistance: float  # deltaE - lower values indicate closer match
    
    # If kit has reference colors, the closest match label (descriptive, not confirmatory)
    nearestReferenceLabel: Optional[str] = None  # e.g., "Blue-Purple range" NOT "Methamphetamine"
    
    # Quality assessment
    qualityStatus: str  # ACCEPTABLE, MARGINAL, REJECTED
    qualityIssues: List[str] = []  # Specific quality problems
    
    # Technical metadata
    algorithmVersion: str
    modelVersion: str  # Always includes validation status (e.g., "DEMO-UNVALIDATED-v1")
    configurationVersion: str
    kitCode: str
    validationStatus: str = "UNVALIDATED"  # UNVALIDATED, PILOT, VALIDATED
    
    # Feature vector (for audit/debugging)
    features: ClassificationFeatures
    
    # Measurement Uncertainty
    uncertainty: Optional[MeasurementUncertainty] = None
    
    # Stage H: Evidence Integration
    evidencePayload: Optional[Dict[str, Any]] = None
    
    # Additional diagnostics
    diagnostics: Dict[str, Any] = {}
    
    # Timestamp
    classifiedAt: str

class ProcessResponse(BaseModel):
    status: str
    processing_run_id: str
    test_id: str
    quality: Optional[ImageQualityResult] = None
    classification: Optional[ClassificationResult] = None
    message: Optional[str] = None
    diagnostics: Dict[str, Any] = {}


class ErrorResponse(BaseModel):
    """Structured error response."""
    code: str
    message: str
    details: Optional[Dict[str, Any]] = None
