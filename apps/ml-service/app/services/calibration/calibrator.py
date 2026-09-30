"""
Stage B ColorCalibrator — typed calibration result.

Implements:
  A. Perspective correction (existing behaviour, unchanged).
  B. Neutral white-point correction — if a neutral patch is extracted from the
     reference card and is within a supported luminance range, a per-channel
     gain correction is applied so that the neutral renders as (R=G=B=ref_value).
  C. Full colour-correction matrix (CCM) — NOT implemented because the demo
     reference card has no characterised multi-patch reference values.  The
     interface is defined so it can accept them when they become available.

Calibration is deliberately conservative:
  - Returns PERSPECTIVE_ONLY when no neutral patch is available.
  - Returns NEUTRAL_CORRECTION when a valid neutral patch is found.
  - Returns FAILED for missing corners or invalid images.
  - Never marks itself FULL_CCM without actual characterised reference data.

The source image is NEVER overwritten; a corrected copy is always returned.
"""

import numpy as np
import cv2
from dataclasses import dataclass, field
from typing import Any


# Target output size after perspective correction
_TARGET_W = 600
_TARGET_H = 800

# Neutral patch expected luminance limits (in linear sRGB, 0-1)
# Patches outside this range are clipped/glared and are rejected.
_NEUTRAL_MIN_LINEAR = 0.05
_NEUTRAL_MAX_LINEAR = 0.92

# Rough region of the warped card (normalised, 0-1) where the white neutral
# patch is expected.  This is a placeholder — actual coordinates depend on the
# physical card design.  When no characterised card layout is available, neutral
# extraction is SKIPPED.
_NEUTRAL_PATCH_KNOWN = False  # set True when physical card layout is characterised


@dataclass
class CalibrationResult:
    """
    Typed calibration output.

    status values
    -------------
    FAILED              — perspective correction could not be performed.
    PERSPECTIVE_ONLY    — perspective corrected; no colour correction available.
    NEUTRAL_CORRECTION  — perspective + neutral white-point gain applied.
    FULL_CCM            — perspective + full CCM (NOT IMPLEMENTED; future).
    """
    status: str
    method_version: str
    color_space: str = "sRGB"
    illuminant: str = "D65"
    corrected_image: np.ndarray | None = None
    neutral_patch_rgb: list[float] = field(default_factory=list)
    neutral_gain: list[float] = field(default_factory=lambda: [1.0, 1.0, 1.0])
    usable_patch_count: int = 0
    calibration_residuals: list[float] = field(default_factory=list)
    quality_flags: list[str] = field(default_factory=list)
    rejection_reasons: list[str] = field(default_factory=list)
    calibrated_measurement_supported: bool = False
    diagnostics: dict[str, Any] = field(default_factory=dict)


class ColorCalibrator:
    """
    Two-step calibrator:
      1. Perspective correction (always attempted when 4 card corners provided).
      2. Neutral white-point correction (only when card layout is characterised).
    """

    METHOD_VERSION = "perspective-neutral-v1"

    def calibrate(
        self,
        image: np.ndarray,
        card_corners: list[tuple],
        config: dict[str, Any],
    ) -> CalibrationResult:
        """
        Perform perspective correction and optional neutral correction.

        Returns a CalibrationResult; the corrected image is in
        result.corrected_image (a copy — source image is never mutated).
        """
        if image is None or image.size == 0:
            return CalibrationResult(
                status="FAILED",
                method_version=self.METHOD_VERSION,
                rejection_reasons=["Image is None or empty"],
            )

        if not card_corners or len(card_corners) != 4:
            return CalibrationResult(
                status="FAILED",
                method_version=self.METHOD_VERSION,
                rejection_reasons=["Exactly 4 card corners required for perspective correction"],
            )

        # --- Step 1: Perspective correction ---
        try:
            src_pts = np.array(card_corners, dtype="float32")
            dst_pts = np.array([
                [0, 0],
                [_TARGET_W - 1, 0],
                [_TARGET_W - 1, _TARGET_H - 1],
                [0, _TARGET_H - 1],
            ], dtype="float32")
            matrix = cv2.getPerspectiveTransform(src_pts, dst_pts)
            warped = cv2.warpPerspective(image, matrix, (_TARGET_W, _TARGET_H))
        except Exception as exc:
            return CalibrationResult(
                status="FAILED",
                method_version=self.METHOD_VERSION,
                rejection_reasons=[f"Perspective transform failed: {exc}"],
            )

        # --- Step 2: Neutral correction (only if card layout is characterised) ---
        if not _NEUTRAL_PATCH_KNOWN:
            return CalibrationResult(
                status="PERSPECTIVE_ONLY",
                method_version=self.METHOD_VERSION,
                corrected_image=warped,
                quality_flags=["NEUTRAL_PATCH_LAYOUT_UNKNOWN"],
                rejection_reasons=["Reference card patch coordinates not characterised"],
                calibrated_measurement_supported=False,
                diagnostics={"perspective_matrix": matrix.tolist()},
            )

        # --- Neutral patch extraction (executed only when layout is known) ---
        neutral_rgb, neutral_flags, neutral_rejections = self._extract_neutral_patch(warped, config)

        if neutral_rgb is None:
            return CalibrationResult(
                status="PERSPECTIVE_ONLY",
                method_version=self.METHOD_VERSION,
                corrected_image=warped,
                quality_flags=neutral_flags,
                rejection_reasons=neutral_rejections,
                calibrated_measurement_supported=False,
                diagnostics={"perspective_matrix": matrix.tolist()},
            )

        # Neutral correction gain: drive measured neutral to D65 white (R=G=B=1.0)
        target = np.array([1.0, 1.0, 1.0])
        measured_linear = self._srgb_to_linear(np.array(neutral_rgb) / 255.0)
        gain = target / np.maximum(measured_linear, 1e-6)
        gain = np.clip(gain, 0.5, 2.0)  # Constrain to avoid wild corrections

        corrected = self._apply_gain(warped, gain)

        return CalibrationResult(
            status="NEUTRAL_CORRECTION",
            method_version=self.METHOD_VERSION,
            corrected_image=corrected,
            neutral_patch_rgb=neutral_rgb,
            neutral_gain=gain.tolist(),
            usable_patch_count=1,
            quality_flags=neutral_flags,
            calibrated_measurement_supported=True,
            diagnostics={"perspective_matrix": matrix.tolist()},
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _extract_neutral_patch(
        self,
        warped: np.ndarray,
        config: dict[str, Any],
    ) -> tuple[list[float] | None, list[str], list[str]]:
        """
        Extract mean BGR values from the white/neutral patch region.

        Returns (rgb_list, quality_flags, rejection_reasons).
        Returns (None, flags, reasons) if the patch is not usable.

        This function is a placeholder; actual patch coordinates must come
        from a characterised card layout configuration.
        """
        layout = config.get("neutral_patch_region_normalised")
        if not layout:
            return None, ["NEUTRAL_LAYOUT_MISSING"], ["neutral_patch_region_normalised not in config"]

        h, w = warped.shape[:2]
        x0 = int(layout["x"] * w)
        y0 = int(layout["y"] * h)
        x1 = int((layout["x"] + layout["width"]) * w)
        y1 = int((layout["y"] + layout["height"]) * h)

        patch = warped[y0:y1, x0:x1]
        if patch.size == 0:
            return None, ["NEUTRAL_PATCH_EMPTY"], ["Patch region resolved to empty slice"]

        # BGR → RGB mean
        bgr_mean = np.mean(patch.reshape(-1, 3), axis=0)
        rgb_mean = bgr_mean[::-1]

        # Reject clipped / under-exposed patch
        linear = self._srgb_to_linear(rgb_mean / 255.0)
        flags: list[str] = []
        reasons: list[str] = []

        if np.any(linear > _NEUTRAL_MAX_LINEAR):
            flags.append("NEUTRAL_PATCH_CLIPPED")
            reasons.append("Neutral patch appears over-exposed or glared")
            return None, flags, reasons

        if np.any(linear < _NEUTRAL_MIN_LINEAR):
            flags.append("NEUTRAL_PATCH_TOO_DARK")
            reasons.append("Neutral patch appears under-exposed or contaminated")
            return None, flags, reasons

        return rgb_mean.tolist(), flags, reasons

    @staticmethod
    def _srgb_to_linear(srgb: np.ndarray) -> np.ndarray:
        srgb = np.clip(srgb, 0.0, 1.0)
        return np.where(
            srgb <= 0.04045,
            srgb / 12.92,
            np.power((srgb + 0.055) / 1.055, 2.4),
        )

    @staticmethod
    def _apply_gain(image: np.ndarray, gain_rgb: np.ndarray) -> np.ndarray:
        """Apply per-channel linear gain in float, clip back to uint8."""
        # image is BGR; gain_rgb is [R, G, B]
        gain_bgr = gain_rgb[::-1]
        img_f = image.astype(np.float64) * gain_bgr[np.newaxis, np.newaxis, :]
        return np.clip(img_f, 0, 255).astype(np.uint8)
