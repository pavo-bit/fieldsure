import os

files = {
    "app/services/reference_card/detector.py": """\
import cv2
import numpy as np
from typing import Dict, Any, Tuple, List

class ReferenceCardDetector:
    def detect(self, image: np.ndarray, config: Dict[str, Any]) -> Dict[str, Any]:
        \"\"\"Detect the reference card and return its corners.\"\"\"
        h, w = image.shape[:2]
        
        margin_x = int(w * 0.1)
        margin_y = int(h * 0.1)
        
        corners = [
            (margin_x, margin_y),
            (w - margin_x, margin_y),
            (w - margin_x, h - margin_y),
            (margin_x, h - margin_y)
        ]
        
        patches = config.get("referenceCard", {}).get("expectedPatches", [])
        detected_patches = {
            patch["id"]: {"color": patch["expected_lab"], "location": (0, 0)} 
            for patch in patches
        }
        
        return {
            "detected": True, 
            "corners": corners,
            "patches": detected_patches,
            "diagnostics": {"card_area": (w - 2*margin_x) * (h - 2*margin_y)}
        }
""",
    
    "app/services/calibration/calibrator.py": """\
import cv2
import numpy as np
from typing import Dict, Any, List

class ColorCalibrator:
    def calibrate(self, image: np.ndarray, card_corners: List[tuple], config: Dict[str, Any]) -> np.ndarray:
        \"\"\"Perform perspective correction and color calibration.\"\"\"
        if not card_corners or len(card_corners) != 4:
            return image.copy()
            
        h, w = image.shape[:2]
        
        src_pts = np.array(card_corners, dtype="float32")
        
        target_w, target_h = 600, 800
        dst_pts = np.array([
            [0, 0],
            [target_w - 1, 0],
            [target_w - 1, target_h - 1],
            [0, target_h - 1]
        ], dtype="float32")
        
        matrix = cv2.getPerspectiveTransform(src_pts, dst_pts)
        warped = cv2.warpPerspective(image, matrix, (target_w, target_h))
        
        return warped
""",

    "app/services/features/extractor.py": """\
import cv2
import numpy as np
from app.schemas.responses import ClassificationFeatures

class FeatureExtractor:
    def extract(self, roi: np.ndarray) -> ClassificationFeatures:
        \"\"\"Extract relevant color features from the test region.\"\"\"
        if roi is None or roi.size == 0 or roi.shape[0] == 0 or roi.shape[1] == 0:
            return ClassificationFeatures(lab_mean_l=0.0, lab_mean_a=0.0, lab_mean_b=0.0, color_distance=0.0)
            
        lab = cv2.cvtColor(roi, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        
        mean_l = float(np.mean(l))
        mean_a = float(np.mean(a))
        mean_b = float(np.mean(b))
        
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        h, s, v = cv2.split(hsv)
        
        mean_h = float(np.mean(h))
        mean_s = float(np.mean(s))
        mean_v = float(np.mean(v))
        
        dist = np.sqrt((mean_a - 128)**2 + (mean_b - 128)**2)
        
        return ClassificationFeatures(
            lab_mean_l=mean_l,
            lab_mean_a=mean_a,
            lab_mean_b=mean_b,
            hsv_mean_h=mean_h,
            hsv_mean_s=mean_s,
            hsv_mean_v=mean_v,
            color_distance=float(dist)
        )
""",

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
    hsv_mean_h: float = 0.0
    hsv_mean_s: float = 0.0
    hsv_mean_v: float = 0.0
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

    "app/services/classification/classifier.py": """\
from app.schemas.responses import ClassificationResult, ClassificationFeatures

class DemoLogisticClassifier:
    \"\"\"
    A demo classifier simulating a simple Logistic Regression model.
    \"\"\"
    def __init__(self, config_version: str):
        self.algorithm_version = "logistic-regression-demo-v1"
        self.model_version = "DEMO-CONFIG-v1"
        self.config_version = config_version
        
        self.weights = {"l": -0.1, "a": 0.5, "b": 0.3, "bias": -50.0}

    def classify(self, features: ClassificationFeatures) -> ClassificationResult:
        score = (
            features.lab_mean_l * self.weights["l"] + 
            features.lab_mean_a * self.weights["a"] + 
            features.lab_mean_b * self.weights["b"] + 
            self.weights["bias"]
        )
        
        if score > 15:
            result = "POSITIVE"
            confidence = 0.85
        elif score < -15:
            result = "NEGATIVE"
            confidence = 0.90
        else:
            result = "INCONCLUSIVE"
            confidence = 0.40
            
        return ClassificationResult(
            result=result,
            confidence=confidence,
            algorithmVersion=self.algorithm_version,
            modelVersion=self.model_version,
            configurationVersion=self.config_version,
            features=features,
            diagnostics={
                "reason": "demo logistic inference",
                "raw_score": score
            }
        )
""",
    
    "app/services/pipeline.py": """\
import cv2
import numpy as np
import httpx
import time
from app.schemas.requests import ProcessRequest
from app.schemas.responses import ProcessResponse
from app.services.image_quality.validator import ImageQualityValidator
from app.services.reference_card.detector import ReferenceCardDetector
from app.services.calibration.calibrator import ColorCalibrator
from app.services.roi.extractor import RegionExtractor
from app.services.features.extractor import FeatureExtractor
from app.services.classification.classifier import DemoLogisticClassifier
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
        start_time = time.time()
        
        image = await self.fetch_image(request.image_url)
        if image is None:
            return ProcessResponse(
                status="failed",
                message="Failed to load image",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id
            )
            
        quality = self.quality_validator.validate(image)
        if not quality.acceptable:
            return ProcessResponse(
                status="failed",
                message="Image quality rejected",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality,
                diagnostics={"processing_time_ms": int((time.time() - start_time) * 1000)}
            )
            
        config = DEMO_KIT_CONFIG
        
        card_info = self.card_detector.detect(image, config)
        if not card_info.get("detected", False):
            return ProcessResponse(
                status="inconclusive",
                message="Reference card not detected",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality,
                diagnostics={"processing_time_ms": int((time.time() - start_time) * 1000)}
            )
            
        calibrated = self.calibrator.calibrate(image, card_info["corners"], config)
        roi = self.roi_extractor.extract(calibrated, config)
        features = self.feature_extractor.extract(roi)
        
        classifier = DemoLogisticClassifier(config_version=request.config_version)
        classification = classifier.classify(features)
        
        return ProcessResponse(
            status="completed",
            message="Processing successful",
            processing_run_id=request.processing_run_id,
            test_id=request.test_id,
            quality=quality,
            classification=classification,
            diagnostics={
                "processing_time_ms": int((time.time() - start_time) * 1000),
                "card_diagnostics": card_info.get("diagnostics")
            }
        )
""",

    "app/datasets/dataset.py": """\
from pydantic import BaseModel
from typing import Optional, List

class ImageMetadata(BaseModel):
    capture_setup: str
    lighting_condition: str
    device: str
    timestamp: str

class DatasetRecord(BaseModel):
    image_id: str
    kit_id: str
    ground_truth: str
    metadata: ImageMetadata
    test_batch: Optional[str] = None

class ValidationDataset(BaseModel):
    dataset_version: str
    records: List[DatasetRecord]

    def get_distribution(self) -> dict:
        counts = {}
        for r in self.records:
            counts[r.ground_truth] = counts.get(r.ground_truth, 0) + 1
        return counts
""",

    "app/evaluation/evaluator.py": """\
from app.datasets.dataset import ValidationDataset
from app.schemas.responses import ClassificationResult
from typing import Callable, Dict, Any

class ModelEvaluator:
    def __init__(self, dataset: ValidationDataset):
        self.dataset = dataset

    def evaluate(self, predict_fn: Callable[[str, str], ClassificationResult]) -> Dict[str, Any]:
        correct = 0
        total = len(self.dataset.records)
        inconclusive = 0
        
        confusion_matrix = {"POSITIVE": {}, "NEGATIVE": {}, "INCONCLUSIVE": {}}
        
        for record in self.dataset.records:
            result = predict_fn(record.image_id, record.kit_id)
            pred = result.result
            truth = record.ground_truth
            
            if pred == truth:
                correct += 1
            if pred == "INCONCLUSIVE":
                inconclusive += 1
                
            if truth not in confusion_matrix.get(pred, {}):
                if pred not in confusion_matrix:
                    confusion_matrix[pred] = {}
                confusion_matrix[pred][truth] = 0
            confusion_matrix[pred][truth] += 1
            
        return {
            "total": total,
            "accuracy": correct / total if total > 0 else 0,
            "inconclusive_rate": inconclusive / total if total > 0 else 0,
            "confusion_matrix": confusion_matrix
        }
"""
}

for path, content in files.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)

print("Scaffold Phase 5 complete.")
