"""
Feature extractor — Stage B implementation.

Converts BGR uint8 ROI images to true CIELAB values using the correct
sRGB linearisation → XYZ D65 → CIELAB D65 pipeline.

Key guarantees:
- Does NOT interpret OpenCV uint8 LAB as standard CIELAB.
- Keeps chroma magnitude separate from Delta E metrics.
- Returns both Delta E 76 and Delta E 2000.
- Records color-space and illuminant metadata in output.
- Does not overwrite or mutate the source image.
"""

import numpy as np
from app.schemas.responses import ClassificationFeatures
from app.services.features.color_math import (
    bgr_image_to_lab,
    delta_e_76,
    delta_e_2000,
)

# Reference white used by this pipeline
_ILLUMINANT = "D65"
_CONVERSION_VERSION = "srgb-d65-v1"


class FeatureExtractor:
    """
    Extracts colour-science features from a BGR uint8 ROI image.

    Source image channel order must be BGR (OpenCV default).
    The ROI must be uint8 or float32/float64 in [0, 255] range.
    """

    ILLUMINANT: str = _ILLUMINANT
    CONVERSION_VERSION: str = _CONVERSION_VERSION

    def extract(
        self,
        roi: np.ndarray,
        nearest_reference_lab: np.ndarray | None = None,
        calibration_status: str = "NOT_ATTEMPTED",
    ) -> tuple[ClassificationFeatures, 'MeasurementUncertainty']:
        """
        Extract colour features from the ROI.

        Parameters
        ----------
        roi : np.ndarray
            BGR uint8 image array, shape (H, W, 3).
        nearest_reference_lab : np.ndarray or None
            If provided, shape (3,) with true CIELAB [L, a, b] of the
            nearest reference colour.  Used to compute Delta E.
        calibration_status : str
            Calibration status string from the calibrator, propagated into features.

        Returns
        -------
        ClassificationFeatures
        """
        # --- Guard empty/invalid inputs ---
        from app.schemas.responses import MeasurementUncertainty
        if roi is None or roi.size == 0 or roi.ndim < 2:
            return ClassificationFeatures(
                lab_mean_l=0.0,
                lab_mean_a=0.0,
                lab_mean_b=0.0,
                calibration_status=calibration_status,
            ), MeasurementUncertainty(is_available=False)

        h, w = roi.shape[:2]
        if h == 0 or w == 0:
            return ClassificationFeatures(
                lab_mean_l=0.0,
                lab_mean_a=0.0,
                lab_mean_b=0.0,
                calibration_status=calibration_status,
            ), MeasurementUncertainty(is_available=False)

        # --- Handle channel count ---
        if roi.ndim == 2:
            # Grayscale: replicate to 3 channels
            roi = np.stack([roi, roi, roi], axis=-1)
        elif roi.shape[2] == 4:
            # BGRA: drop alpha channel
            roi = roi[..., :3]

        # --- Ensure uint8 ---
        if roi.dtype != np.uint8:
            roi = np.clip(roi, 0, 255).astype(np.uint8)

        # --- Convert to true CIELAB (float64, D65) ---
        lab_image = bgr_image_to_lab(roi, illuminant=_ILLUMINANT)  # shape (H, W, 3)
        lab_pixels = lab_image.reshape(-1, 3)

        mean_lab = np.mean(lab_pixels, axis=0)  # [L_mean, a_mean, b_mean]
        L_mean, a_mean, b_mean = float(mean_lab[0]), float(mean_lab[1]), float(mean_lab[2])
        
        # --- Uncertainty (pixel variance) ---
        std_lab = np.std(lab_pixels, axis=0)
        roi_var = float(np.mean(std_lab))

        # --- Chroma (geometric magnitude; NOT a colour difference) ---
        chroma = float(np.sqrt(a_mean**2 + b_mean**2))

        # --- Delta E metrics ---
        de76 = 0.0
        de2000 = 0.0
        if nearest_reference_lab is not None:
            ref = np.asarray(nearest_reference_lab, dtype=np.float64).reshape(1, 3)
            obs = np.array([[L_mean, a_mean, b_mean]], dtype=np.float64)
            de76 = float(delta_e_76(obs, ref)[0])
            de2000 = float(delta_e_2000(obs, ref)[0])
            
        from app.schemas.responses import MeasurementUncertainty
        uncertainty = MeasurementUncertainty(
            pixel_sampling_std_l=float(std_lab[0]),
            pixel_sampling_std_a=float(std_lab[1]),
            pixel_sampling_std_b=float(std_lab[2]),
            roi_variability=roi_var,
            calibration_residual_delta_e=None, # Assigned by calibrator later if possible
            is_available=True
        )

        return ClassificationFeatures(
            lab_mean_l=L_mean,
            lab_mean_a=a_mean,
            lab_mean_b=b_mean,
            delta_e_76=de76,
            delta_e_2000=de2000,
            chroma=chroma,
            # Backward-compat alias: color_distance = de2000 (when reference available)
            # or 0.0 (when not).  The classifier computes its own ΔE.
            color_distance=de2000,
            color_space="CIELAB",
            illuminant=_ILLUMINANT,
            conversion_version=_CONVERSION_VERSION,
            calibration_status=calibration_status,
        ), uncertainty
