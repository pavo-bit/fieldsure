import os

files = {
    "app/schemas/responses.py": """\
from pydantic import BaseModel
from typing import Dict, List, Optional, Any

class ImageQualityDiagnostics(BaseModel):
    width: int
    height: int
    brightness: float
    blur_score: float
    reference_card_detected: bool
    test_region_detected: bool

class ImageQualityResult(BaseModel):
    acceptable: bool
    issues: List[str]
    diagnostics: ImageQualityDiagnostics

class ClassificationFeatures(BaseModel):
    lab_mean_l: float
    lab_mean_a: float
    lab_mean_b: float
    color_distance: float
    
class ClassificationResult(BaseModel):
    result: str  # POSITIVE, NEGATIVE, INCONCLUSIVE
    confidence: Optional[float] = None
    algorithmVersion: str
    modelVersion: str
    configurationVersion: str
    features: ClassificationFeatures
    diagnostics: Dict[str, Any] = {}

class ProcessResponse(BaseModel):
    status: str
    processing_run_id: str
    test_id: str
    quality: Optional[ImageQualityResult] = None
    classification: Optional[ClassificationResult] = None
    message: Optional[str] = None
    diagnostics: Dict[str, Any] = {}
""",
    
    "app/services/image_quality/validator.py": """\
import cv2
import numpy as np
from app.schemas.responses import ImageQualityResult, ImageQualityDiagnostics

class ImageQualityValidator:
    def __init__(self, min_resolution: int = 400):
        self.min_resolution = min_resolution
        
    def validate(self, image: np.ndarray) -> ImageQualityResult:
        issues = []
        if image is None or image.size == 0:
            return ImageQualityResult(
                acceptable=False, 
                issues=["Invalid or empty image"],
                diagnostics=ImageQualityDiagnostics(width=0, height=0, brightness=0.0, blur_score=0.0, reference_card_detected=False, test_region_detected=False)
            )
            
        height, width = image.shape[:2]
        if min(height, width) < self.min_resolution:
            issues.append(f"Resolution too low. Minimum dimension should be {self.min_resolution}px")
            
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
        brightness = np.mean(gray) / 255.0
        
        if blur_score < 50.0:
            issues.append("Image is too blurry")
        if brightness < 0.2:
            issues.append("Image is too dark")
        if brightness > 0.9:
            issues.append("Image is overexposed")
            
        acceptable = len(issues) == 0
        
        return ImageQualityResult(
            acceptable=acceptable,
            issues=issues,
            diagnostics=ImageQualityDiagnostics(
                width=width,
                height=height,
                brightness=float(brightness),
                blur_score=float(blur_score),
                reference_card_detected=True,  # Mock for now
                test_region_detected=True      # Mock for now
            )
        )
""",
    
    "app/services/reference_card/detector.py": """\
import numpy as np

class ReferenceCardDetector:
    def detect(self, image: np.ndarray, config: dict):
        # Implementation for reference card detection
        return {"detected": True, "corners": [(0, 0), (100, 0), (100, 100), (0, 100)]}
""",

    "app/services/calibration/calibrator.py": """\
import numpy as np

class ColorCalibrator:
    def calibrate(self, image: np.ndarray, card_corners: list, config: dict) -> np.ndarray:
        return image.copy()
""",

    "app/services/roi/extractor.py": """\
import numpy as np

class RegionExtractor:
    def extract(self, image: np.ndarray, config: dict) -> np.ndarray:
        roi_cfg = config.get("testRegion", {})
        h, w = image.shape[:2]
        x = int(roi_cfg.get("x", 0.3) * w)
        y = int(roi_cfg.get("y", 0.4) * h)
        rw = int(roi_cfg.get("width", 0.4) * w)
        rh = int(roi_cfg.get("height", 0.2) * h)
        # Prevent 0-sized arrays
        if rw <= 0 or rh <= 0 or x >= w or y >= h:
            return image[0:1, 0:1]
        return image[y:min(y+rh, h), x:min(x+rw, w)]
""",

    "app/services/features/extractor.py": """\
import cv2
import numpy as np
from app.schemas.responses import ClassificationFeatures

class FeatureExtractor:
    def extract(self, roi: np.ndarray) -> ClassificationFeatures:
        if roi is None or roi.size == 0 or roi.shape[0] == 0 or roi.shape[1] == 0:
            return ClassificationFeatures(lab_mean_l=0.0, lab_mean_a=0.0, lab_mean_b=0.0, color_distance=0.0)
            
        lab = cv2.cvtColor(roi, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        
        mean_l = float(np.mean(l))
        mean_a = float(np.mean(a))
        mean_b = float(np.mean(b))
        
        # Fake color distance for demo
        dist = np.sqrt(mean_a**2 + mean_b**2)
        
        return ClassificationFeatures(
            lab_mean_l=mean_l,
            lab_mean_a=mean_a,
            lab_mean_b=mean_b,
            color_distance=float(dist)
        )
""",

    "app/services/classification/classifier.py": """\
from app.schemas.responses import ClassificationResult, ClassificationFeatures

class DemoClassifier:
    def __init__(self, config_version: str):
        self.algorithm_version = "demo-1.0.0"
        self.model_version = "DEMO-CONFIG-v1"
        self.config_version = config_version

    def classify(self, features: ClassificationFeatures) -> ClassificationResult:
        if features.color_distance > 50:
            result = "POSITIVE"
        elif features.color_distance < 20:
            result = "NEGATIVE"
        else:
            result = "INCONCLUSIVE"
            
        return ClassificationResult(
            result=result,
            confidence=None,
            algorithmVersion=self.algorithm_version,
            modelVersion=self.model_version,
            configurationVersion=self.config_version,
            features=features,
            diagnostics={"reason": "demo heuristic"}
        )
""",

    "app/configs/demo_config.py": """\
DEMO_KIT_CONFIG = {
    "referenceCard": {
        "id": "demo-card-v1",
        "expectedPatches": []
    },
    "testRegion": {
        "type": "configured_roi",
        "x": 0.30,
        "y": 0.40,
        "width": 0.40,
        "height": 0.20
    }
}
""",

    "app/services/pipeline.py": """\
import cv2
import numpy as np
import httpx
from app.schemas.requests import ProcessRequest
from app.schemas.responses import ProcessResponse, ImageQualityResult, ImageQualityDiagnostics
from app.services.image_quality.validator import ImageQualityValidator
from app.services.reference_card.detector import ReferenceCardDetector
from app.services.calibration.calibrator import ColorCalibrator
from app.services.roi.extractor import RegionExtractor
from app.services.features.extractor import FeatureExtractor
from app.services.classification.classifier import DemoClassifier
from app.configs.demo_config import DEMO_KIT_CONFIG

class MLPipeline:
    def __init__(self):
        self.quality_validator = ImageQualityValidator()
        self.card_detector = ReferenceCardDetector()
        self.calibrator = ColorCalibrator()
        self.roi_extractor = RegionExtractor()
        self.feature_extractor = FeatureExtractor()

    async def fetch_image(self, url: str):
        try:
            if url.startswith("http"):
                async with httpx.AsyncClient() as client:
                    resp = await client.get(url)
                    resp.raise_for_status()
                    image_bytes = np.frombuffer(resp.content, np.uint8)
                    return cv2.imdecode(image_bytes, cv2.IMREAD_COLOR)
            else:
                return cv2.imread(url)
        except Exception:
            return None

    async def process(self, request: ProcessRequest) -> ProcessResponse:
        image = await self.fetch_image(request.image_url)
        
        quality = self.quality_validator.validate(image)
        if not quality.acceptable:
            return ProcessResponse(
                status="failed",
                message="Image quality rejected",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality
            )
            
        config = DEMO_KIT_CONFIG
        
        card_info = self.card_detector.detect(image, config)
        calibrated = self.calibrator.calibrate(image, card_info["corners"], config)
        roi = self.roi_extractor.extract(calibrated, config)
        features = self.feature_extractor.extract(roi)
        
        classifier = DemoClassifier(config_version=request.config_version)
        classification = classifier.classify(features)
        
        return ProcessResponse(
            status="completed",
            message="Processing successful",
            processing_run_id=request.processing_run_id,
            test_id=request.test_id,
            quality=quality,
            classification=classification
        )
"""
}

for path, content in files.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)

print("Scaffold complete.")
