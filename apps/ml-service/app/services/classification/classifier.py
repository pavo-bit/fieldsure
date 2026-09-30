"""
Stage B DemoLogisticClassifier — colorimetric measurement classifier.

Changes from Stage A:
- Uses true CIELAB reference values (L, a, b), not uint8-scaled OpenCV LAB.
- Computes Delta E 76 and Delta E 2000 (preferred) for each reference label.
- chroma magnitude is stored separately; it is NOT used as a Delta E.
- Nearest reference is chosen by minimum Delta E 2000.
- Quality threshold is expressed as Delta E 2000 units (not chroma magnitude).

IMPORTANT: This is a DEMO configuration.
  - Reference LAB values below are illustrative colour ranges from a generic
    colorimetric chart.  They are NOT derived from validated assay data.
  - No accuracy, sensitivity, specificity, or drug-detection performance is
    claimed or implied.
  - All outputs carry validationStatus = "UNVALIDATED".
"""

import numpy as np
from datetime import datetime, timezone

from app.schemas.responses import ClassificationResult, ClassificationFeatures, ColorObservation
from app.services.features.color_math import delta_e_76, delta_e_2000 as compute_de2000

_ILLUMINANT = "D65"
_ALGORITHM_VERSION = "colorimetric-demo-v1"
_MODEL_VERSION = "DEMO-UNVALIDATED-v1"

# Threshold for quality: if nearest reference ΔE2000 > this, flag quality issue.
# Value is illustrative; has no validated analytical meaning.
_DE2000_QUALITY_THRESHOLD = 30.0

# Threshold for "extreme lightness" in CIELAB L (0-100 scale)
_L_TOO_DARK = 5.0
_L_TOO_BRIGHT = 97.0


class DemoLogisticClassifier:
    """
    DEMO ONLY — Safe colorimetric measurement classifier.

    Returns:
    - Observed CIELAB colour.
    - Delta E 2000 (preferred) and Delta E 76 to each reference label.
    - Nearest reference label (descriptive, not a substance name).
    - Quality status based on Delta E threshold and lightness limits.

    Does NOT return drug identification or analytical result.
    """

    # Demo reference colours: true approximate CIELAB D65 values for
    # common colorimetric chart patches.  Not derived from kit-specific
    # validated data.
    DEMO_REFERENCES: dict[str, np.ndarray] = {
        "Blue-Purple range":  np.array([30.0,  15.0, -30.0]),
        "Pink-Red range":     np.array([45.0,  40.0,  10.0]),
        "Brown-Orange range": np.array([40.0,  20.0,  25.0]),
        "No color change":    np.array([80.0,   0.0,   0.0]),
    }

    def __init__(self, config_version: str, kit_code: str = "DEMO-KIT"):
        self.algorithm_version = _ALGORITHM_VERSION
        self.model_version = _MODEL_VERSION
        self.config_version = config_version
        self.kit_code = kit_code

    def classify(self, features: ClassificationFeatures) -> ClassificationResult:
        """
        Classify based on measured CIELAB colour.

        Nearest reference is found by minimum Delta E 2000.
        Quality is assessed by Delta E 2000 threshold and lightness bounds.
        """
        observed_lab = np.array([[features.lab_mean_l, features.lab_mean_a, features.lab_mean_b]])
        observed_obs = ColorObservation(
            L=features.lab_mean_l,
            a=features.lab_mean_a,
            b=features.lab_mean_b,
        )

        # Compute ΔE 76 and ΔE 2000 to each reference
        distances_de76: dict[str, float] = {}
        distances_de2000: dict[str, float] = {}
        for label, ref_lab in self.DEMO_REFERENCES.items():
            ref = ref_lab.reshape(1, 3)
            distances_de76[label] = float(delta_e_76(observed_lab, ref)[0])
            distances_de2000[label] = float(compute_de2000(observed_lab, ref)[0])

        # Nearest reference by ΔE 2000
        nearest_label = min(distances_de2000, key=lambda k: distances_de2000[k])
        min_de2000 = distances_de2000[nearest_label]
        min_de76 = distances_de76[nearest_label]

        # Quality assessment — using ΔE 2000 threshold (not chroma magnitude)
        quality_issues: list[str] = []
        if min_de2000 > _DE2000_QUALITY_THRESHOLD:
            quality_issues.append("DE2000_DISTANCE_HIGH")
        if features.lab_mean_l < _L_TOO_DARK:
            quality_issues.append("EXTREME_LIGHTNESS_DARK")
        if features.lab_mean_l > _L_TOO_BRIGHT:
            quality_issues.append("EXTREME_LIGHTNESS_BRIGHT")

        if len(quality_issues) >= 2:
            quality_status = "REJECTED"
        elif len(quality_issues) == 1:
            quality_status = "MARGINAL"
        else:
            quality_status = "ACCEPTABLE"

        return ClassificationResult(
            observedColor=observed_obs,
            colorDistance=round(min_de2000, 4),
            nearestReferenceLabel=nearest_label,
            qualityStatus=quality_status,
            qualityIssues=quality_issues,
            algorithmVersion=self.algorithm_version,
            modelVersion=self.model_version,
            configurationVersion=self.config_version,
            kitCode=self.kit_code,
            validationStatus="UNVALIDATED",
            features=features,
            diagnostics={
                "classifier_type": "demo_colorimetric",
                "illuminant": _ILLUMINANT,
                "reference_count": len(self.DEMO_REFERENCES),
                "nearest_reference_label": nearest_label,
                "nearest_de2000": round(min_de2000, 4),
                "nearest_de76": round(min_de76, 4),
                "all_de2000": {k: round(v, 4) for k, v in distances_de2000.items()},
                "all_de76": {k: round(v, 4) for k, v in distances_de76.items()},
                "note": (
                    "UNVALIDATED DEMO: values are illustrative colorimetric "
                    "measurements only.  Not drug identification."
                ),
            },
            classifiedAt=datetime.now(timezone.utc).isoformat(),
        )
