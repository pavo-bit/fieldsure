import cv2
import numpy as np
import httpx
import time
from app.core.validation import validate_image_url, validate_image_size, validate_image_content
from app.schemas.requests import ProcessRequest
from app.schemas.responses import ProcessResponse
from app.services.image_quality.validator import ImageQualityValidator
from app.services.reference_card.detector import ReferenceCardDetector
from app.services.calibration.calibrator import ColorCalibrator
from app.services.roi.extractor import RegionExtractor
from app.services.features.extractor import FeatureExtractor
from app.services.classification.classifier import DemoLogisticClassifier
from app.configs.demo_config import DEMO_KIT_CONFIG
from app.core.config import settings

from app.services.classification.decision_gate import DecisionGate
from app.schemas.responses import QualityDimension

class MLPipeline:
    def __init__(self):
        self.quality_validator = ImageQualityValidator()
        self.card_detector = ReferenceCardDetector()
        self.calibrator = ColorCalibrator()
        self.roi_extractor = RegionExtractor()
        self.feature_extractor = FeatureExtractor()
        self.decision_gate = DecisionGate()

    async def fetch_image(self, url: str):
        """
        Fetch image with validation and size limits.
        
        Raises ValidationError if URL/size validation fails.
        """
        # Validate URL against allowlist
        validate_image_url(url)
        
        try:
            if url.startswith("http"):
                async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT_SECONDS) as client:
                    resp = await client.get(url)
                    resp.raise_for_status()
                    
                    # Validate Content-Length if available
                    content_length = resp.headers.get("content-length")
                    if content_length:
                        validate_image_size(int(content_length))
                    
                    image_bytes = resp.content
                    
                    # Validate actual content
                    validation_result = validate_image_content(image_bytes)
                    
                    # Decode image
                    image_array = np.frombuffer(image_bytes, np.uint8)
                    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
                    
                    if image is None:
                        raise ValueError("Failed to decode image")
                    
                    return image, validation_result
            else:
                # Local file path (for testing)
                image = cv2.imread(url)
                if image is None:
                    raise ValueError(f"Failed to load image from {url}")
                return image, {"format": "local", "sha256": "local_file"}
        except httpx.TimeoutException:
            raise ValueError("Image fetch timeout")
        except httpx.HTTPError as e:
            raise ValueError(f"HTTP error fetching image: {e}")
        except Exception as e:
            raise ValueError(f"Failed to fetch image: {e}")

    async def process(self, request: ProcessRequest) -> ProcessResponse:
        start_time = time.time()
        
        try:
            result = await self.fetch_image(request.image_url)
            if result is None:
                return ProcessResponse(
                    status="failed",
                    message="Failed to load image",
                    processing_run_id=request.processing_run_id,
                    test_id=request.test_id
                )
            
            image, image_validation = result
        except Exception as e:
            return ProcessResponse(
                status="failed",
                message=f"Image fetch failed: {str(e)}",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                diagnostics={"processing_time_ms": int((time.time() - start_time) * 1000)}
            )
            
        quality = self.quality_validator.validate(image)
        if not quality.acceptable and not quality.assessment:
            # Fallback if old code
            return ProcessResponse(status="failed", message="Image quality rejected", processing_run_id=request.processing_run_id, test_id=request.test_id, quality=quality)
            
        assessment = quality.assessment
        if assessment.overall_status == "REJECTED":
            return ProcessResponse(
                status="rejected",
                message="Image quality rejected",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality,
                diagnostics={"processing_time_ms": int((time.time() - start_time) * 1000)}
            )
            
        config = DEMO_KIT_CONFIG
        
        card_info = self.card_detector.detect(image, config)
        if not card_info.get("detected", False):
            assessment.reference_card_quality = QualityDimension(status="REJECTED", issues=["REFERENCE_CARD_NOT_FOUND"])
            assessment.overall_status = "REJECTED"
            return ProcessResponse(
                status="inconclusive",
                message="Reference card not detected",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality,
                diagnostics={"processing_time_ms": int((time.time() - start_time) * 1000)}
            )
        else:
            assessment.reference_card_quality = QualityDimension(status="ACCEPTABLE", issues=[])
            
        cal_result = self.calibrator.calibrate(image, card_info.get("corners", []), config)
        if cal_result.status == "FAILED":
            assessment.calibration_quality = QualityDimension(status="REJECTED", issues=["CALIBRATION_FAILED"])
        else:
            assessment.calibration_quality = QualityDimension(status="ACCEPTABLE", issues=[])
        
        # Use corrected image when available; fall back to original (never mutate source)
        working_image = cal_result.corrected_image if cal_result.corrected_image is not None else image
        
        roi = self.roi_extractor.extract(working_image, config)
        features, uncertainty = self.feature_extractor.extract(
            roi,
            calibration_status=cal_result.status,
        )
        
        # Extract kit code from config or request
        kit_code = config.get("kitCode", "DEMO-KIT")
        
        classifier = DemoLogisticClassifier(
            config_version=request.config_version,
            kit_code=kit_code
        )
        
        # Decision Gate Evaluation
        # Assume DemoLogisticClassifier is UNVALIDATED for DEMO-CONFIG-v1
        gate_result = self.decision_gate.evaluate(
            assessment=assessment,
            uncertainty=uncertainty,
            features=features,
            config_version=request.config_version,
            is_model_validated=False
        )
        
        if not gate_result["can_proceed"] or gate_result["interpretation_withheld"]:
            # Measurement might be available, but interpretation withheld
            return ProcessResponse(
                status="inconclusive",
                message=f"Measurement withheld: {gate_result['gate_status']}",
                processing_run_id=request.processing_run_id,
                test_id=request.test_id,
                quality=quality,
                diagnostics={
                    "processing_time_ms": int((time.time() - start_time) * 1000),
                    "gate_status": gate_result["gate_status"]
                }
            )
            
        from app.models.inference import inference_engine
        
        if request.model_version == "DEMO-CONFIG-v1":
            classifier = DemoLogisticClassifier(
                config_version=request.config_version,
                kit_code=kit_code
            )
            classification = classifier.classify(features)
            classification.qualityStatus = gate_result["quality_status"]
            classification.validationStatus = gate_result["validation_status"]
            classification.uncertainty = uncertainty
        else:
            # Use Stage H production inference engine
            # Extract features dictionary from Pydantic model
            feat_dict = {
                "L": features.lab_mean_l,
                "a": features.lab_mean_a,
                "b": features.lab_mean_b
            }
            
            # Map quality assessment issues to a list of strings
            quality_issues = []
            if assessment.overall_status == "REJECTED" or assessment.overall_status == "MARGINAL":
                quality_issues.append(assessment.overall_status)
                
            inf_result = inference_engine.predict(
                model_id=request.model_version,
                features=feat_dict,
                assay_version=kit_code,
                quality_issues=quality_issues
            )
            
            if inf_result["status"] == "ABSTAIN":
                return ProcessResponse(
                    status="inconclusive",
                    message=f"Inference withheld: {inf_result['reason']}",
                    processing_run_id=request.processing_run_id,
                    test_id=request.test_id,
                    quality=quality,
                    diagnostics={
                        "processing_time_ms": int((time.time() - start_time) * 1000),
                        "gate_status": gate_result["gate_status"]
                    }
                )
            elif inf_result["status"] == "ERROR":
                raise ValueError(f"Inference error: {inf_result['reason']}")
                
            # Synthesize ClassificationResult
            from app.schemas.responses import ClassificationResult, ColorObservation
            from datetime import datetime
            classification = ClassificationResult(
                observedColor=ColorObservation(L=features.lab_mean_l, a=features.lab_mean_a, b=features.lab_mean_b),
                colorDistance=features.delta_e_2000,
                nearestReferenceLabel=str(inf_result["prediction"]),
                qualityStatus=gate_result["quality_status"],
                algorithmVersion="inference-engine-v1",
                modelVersion=request.model_version,
                configurationVersion=request.config_version,
                kitCode=kit_code,
                validationStatus=inf_result["approval_status"],
                features=features,
                uncertainty=uncertainty,
                evidencePayload=inf_result.get("evidence"),
                classifiedAt=datetime.utcnow().isoformat()
            )

        return ProcessResponse(
            status="completed",
            message="Processing successful",
            processing_run_id=request.processing_run_id,
            test_id=request.test_id,
            quality=quality,
            classification=classification,
            diagnostics={
                "processing_time_ms": int((time.time() - start_time) * 1000),
                "card_diagnostics": card_info.get("diagnostics"),
                "image_sha256": image_validation.get("sha256"),
                "calibration_status": cal_result.status,
                "calibration_method": cal_result.method_version,
                "calibration_flags": cal_result.quality_flags,
                "gate_status": gate_result["gate_status"]
            }
        )

