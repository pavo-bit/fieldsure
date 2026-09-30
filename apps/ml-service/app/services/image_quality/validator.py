import cv2
import numpy as np
from app.schemas.responses import (
    ImageQualityResult, 
    ImageQualityDiagnostics,
    QualityAssessment,
    QualityDimension
)
from typing import Tuple

class ImageQualityValidator:
    def __init__(self, min_resolution: int = 400, config_version: str = "v1-provisional"):
        self.min_resolution = min_resolution
        self.config_version = config_version
        
    def check_integrity(self, image: np.ndarray) -> QualityDimension:
        issues = []
        if image is None or image.size == 0:
            issues.append("IMAGE_DECODE_FAILED")
            return QualityDimension(status="REJECTED", issues=issues)
            
        height, width = image.shape[:2]
        if min(height, width) < self.min_resolution:
            issues.append("IMAGE_TOO_SMALL")
            
        status = "REJECTED" if "IMAGE_DECODE_FAILED" in issues or "IMAGE_TOO_SMALL" in issues else "ACCEPTABLE"
        return QualityDimension(
            status=status,
            issues=issues,
            metrics={"width": int(width), "height": int(height)}
        )

    def check_focus(self, gray_image: np.ndarray) -> QualityDimension:
        blur_score = cv2.Laplacian(gray_image, cv2.CV_64F).var()
        issues = []
        if blur_score < 50.0:
            issues.append("BLUR_DETECTED")
            
        return QualityDimension(
            status="REJECTED" if issues else "ACCEPTABLE",
            issues=issues,
            metrics={"blur_score": float(blur_score)}
        )
        
    def check_exposure(self, gray_image: np.ndarray) -> QualityDimension:
        brightness = np.mean(gray_image) / 255.0
        
        # Check for clipped channels / glare
        # High value pixels > 250
        glare_ratio = np.sum(gray_image > 250) / gray_image.size
        
        issues = []
        if brightness < 0.2 or brightness > 0.9:
            issues.append("EXPOSURE_OUT_OF_RANGE")
        if glare_ratio > 0.05:
            issues.append("GLARE_DETECTED")
            
        return QualityDimension(
            status="REJECTED" if issues else "ACCEPTABLE",
            issues=issues,
            metrics={"brightness": float(brightness), "glare_ratio": float(glare_ratio)}
        )

    def validate(self, image: np.ndarray) -> ImageQualityResult:
        integrity = self.check_integrity(image)
        if integrity.status == "REJECTED":
            # Fast fail
            assessment = QualityAssessment(
                overall_status="REJECTED",
                image_integrity=integrity,
                focus_and_resolution=QualityDimension(status="UNAVAILABLE"),
                exposure_and_illumination=QualityDimension(status="UNAVAILABLE"),
                reference_card_quality=QualityDimension(status="UNAVAILABLE"),
                calibration_quality=QualityDimension(status="UNAVAILABLE"),
                can_proceed_to_measurement=False,
                can_interpret=False,
                recapture_guidance="Please retake the photo with a clear view.",
                config_version=self.config_version
            )
            return ImageQualityResult(
                acceptable=False,
                issues=integrity.issues,
                diagnostics=ImageQualityDiagnostics(width=0, height=0, brightness=0.0, blur_score=0.0, reference_card_detected=False, test_region_detected=False),
                assessment=assessment
            )

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        focus = self.check_focus(gray)
        exposure = self.check_exposure(gray)
        
        all_issues = integrity.issues + focus.issues + exposure.issues
        acceptable = len(all_issues) == 0
        
        assessment = QualityAssessment(
            overall_status="ACCEPTABLE" if acceptable else "REJECTED",
            image_integrity=integrity,
            focus_and_resolution=focus,
            exposure_and_illumination=exposure,
            reference_card_quality=QualityDimension(status="PENDING"),
            calibration_quality=QualityDimension(status="PENDING"),
            can_proceed_to_measurement=acceptable, # May be updated by later stages
            can_interpret=acceptable,
            recapture_guidance="Please ensure good lighting and focus." if not acceptable else None,
            config_version=self.config_version
        )
        
        return ImageQualityResult(
            acceptable=acceptable,
            issues=all_issues,
            diagnostics=ImageQualityDiagnostics(
                width=integrity.metrics["width"],
                height=integrity.metrics["height"],
                brightness=exposure.metrics["brightness"],
                blur_score=focus.metrics["blur_score"],
                reference_card_detected=False, # updated later
                test_region_detected=False
            ),
            assessment=assessment
        )
