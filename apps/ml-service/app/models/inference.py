from typing import Dict, Any, Optional
from app.models.artifact import ModelArtifactMetadata, artifact_manager
from app.schemas.responses import ClassificationResult
from app.models.classical import ClassicalModelBase

class SafeInferenceEngine:
    def __init__(self):
        self.loaded_models: Dict[str, ClassicalModelBase] = {}

    def load_model(self, model_id: str, model: ClassicalModelBase):
        """In a real system, this loads the serialized model from storage."""
        self.loaded_models[model_id] = model

    def predict(
        self, 
        model_id: str, 
        features: Dict[str, float], 
        assay_version: str, 
        quality_issues: list[str]
    ) -> Dict[str, Any]:
        artifact = artifact_manager.get_artifact(model_id)
        if not artifact:
            raise ValueError(f"Model artifact {model_id} not found.")

        # 1. Bypassing Quality Checks is strictly forbidden
        if quality_issues:
            return {
                "status": "ABSTAIN",
                "reason": "Image quality or calibration failures detected.",
                "quality_issues": quality_issues
            }

        # 2. Compatibility Checks
        if artifact.assay_version != assay_version:
            return {
                "status": "ABSTAIN",
                "reason": f"Model trained for assay {artifact.assay_version}, incompatible with {assay_version}."
            }

        # 3. Artifact Integrity Verification
        current_hash = artifact.compute_hash()
        if current_hash != artifact.integrity_hash:
            return {
                "status": "ABSTAIN",
                "reason": "Model artifact integrity hash mismatch. Tampering detected."
            }

        # 4. Model Governance
        if artifact.approval_status in ["SUSPENDED", "RETIRED"]:
            return {
                "status": "ABSTAIN",
                "reason": f"Model is {artifact.approval_status}."
            }
            
        production_safe = artifact.approval_status == "APPROVED"
        
        # 5. Inference
        model = self.loaded_models.get(model_id)
        if not model:
            raise ValueError("Model object not loaded in memory.")
            
        import numpy as np
        
        KITS = [
            'Mecke Reagent (Selenious Acid/Sulfuric Acid)',
            'Marquis Reagent (Formaldehyde/Sulfuric Acid)',
            'Mandelin Reagent (Ammonium Vanadate/Sulfuric Acid)',
            'Duquenois-Levine Reagent (Vanillin/Acetaldehyde)',
            "Simon's Reagent (Sodium Nitroprusside/Acetaldehyde)",
            'Ehrlich Reagent (p-DMAB/HCl)',
            'Scott Reagent (Cobalt Thiocyanate Phase)'
        ]
        
        kit_feat = [1.0 if assay_version == k else 0.0 for k in KITS]
        l_val = features.get("L", 0.0)
        a_val = features.get("a", 0.0)
        b_val = features.get("b", 0.0)
        
        import math
        chroma = math.sqrt(a_val**2 + b_val**2)
        hue = math.degrees(math.atan2(b_val, a_val)) % 360
        
        X = np.array([[l_val, a_val, b_val, chroma, hue] + kit_feat])
        
        from datetime import datetime
        try:
            pred = model.predict(X)[0]
            if hasattr(model, "predict_proba"):
                probs = model.predict_proba(X)[0].tolist()
            else:
                probs = None
        except Exception as e:
            return {"status": "ERROR", "reason": str(e)}

        return {
            "status": "SUCCESS",
            "prediction": pred,
            "probabilities": probs,
            "production_safe": production_safe,
            "approval_status": artifact.approval_status,
            "message": "RESEARCH_ONLY inference." if not production_safe else "Validated inference.",
            "evidence": {
                "model_id": artifact.model_id,
                "model_version": artifact.model_version,
                "integrity_hash": artifact.integrity_hash,
                "assay_version": artifact.assay_version,
                "protocol_version": artifact.protocol_version,
                "preprocessing_version": artifact.preprocessing_version,
                "inference_timestamp": datetime.utcnow().isoformat()
            }
        }

inference_engine = SafeInferenceEngine()
