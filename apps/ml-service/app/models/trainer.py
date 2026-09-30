import numpy as np
from typing import List, Dict, Any, Optional
from app.dataset.evaluation import Evaluator, EvaluationResult
from app.dataset.models import DatasetSampleSchema
from app.models.classical import ClassicalModelBase
from app.models.artifact import ModelArtifactMetadata, artifact_manager

class ModelTrainer:
    """
    Enforces dataset eligibility gates and trains models.
    """
    def __init__(self, evaluator: Evaluator):
        self.evaluator = evaluator

    def _extract_features(self, samples: List[DatasetSampleSchema]) -> np.ndarray:
        # Build physically motivated features (CIELAB)
        X = []
        KITS = [
            'Mecke Reagent (Selenious Acid/Sulfuric Acid)',
            'Marquis Reagent (Formaldehyde/Sulfuric Acid)',
            'Mandelin Reagent (Ammonium Vanadate/Sulfuric Acid)',
            'Duquenois-Levine Reagent (Vanillin/Acetaldehyde)',
            "Simon's Reagent (Sodium Nitroprusside/Acetaldehyde)",
            'Ehrlich Reagent (p-DMAB/HCl)',
            'Scott Reagent (Cobalt Thiocyanate Phase)'
        ]
        for sample in samples:
            # Stage C quality assessment checks
            qa = sample.quality_assessment
            if qa and (qa.get("quality_flag") or not qa.get("is_valid", True)):
                raise ValueError(f"Sample {sample.sample_id} failed quality assessment and should not be used for training.")
                
            calibrated = sample.calibrated_measurements or {}
            
            # Base/Legacy features
            l = calibrated.get("L", 0.0)
            a = calibrated.get("a", 0.0)
            b = calibrated.get("b", 0.0)
            
            # Time series features
            l_0 = calibrated.get("L_t0s", 0.0)
            a_0 = calibrated.get("a_t0s", 0.0)
            b_0 = calibrated.get("b_t0s", 0.0)
            l_15 = calibrated.get("L_t15s", 0.0)
            a_15 = calibrated.get("a_t15s", 0.0)
            b_15 = calibrated.get("b_t15s", 0.0)
            l_30 = calibrated.get("L_t30s", 0.0)
            a_30 = calibrated.get("a_t30s", 0.0)
            b_30 = calibrated.get("b_t30s", 0.0)
            l_60 = calibrated.get("L_t60s", 0.0)
            # We must use ONLY features that are genuinely available at single-image field inference time.
            # Time-series features like t0s, t15s, velocity, etc., are NOT available because the mobile
            # application only captures a single image at the end of the test.
            # Using them causes Availability Leakage.
            
            # Use the final calibrated measurement which corresponds to the single image captured
            l_final = calibrated.get("L_t60s", l)
            a_final = calibrated.get("a_t60s", a)
            b_final = calibrated.get("b_t60s", b)
            
            # Kit one-hot encoding
            kit_feat = [1.0 if sample.kit_code == k else 0.0 for k in KITS]
            
            # Additional physically valid endpoint features (no leakage)
            import math
            chroma = math.sqrt(a_final**2 + b_final**2)
            hue = math.degrees(math.atan2(b_final, a_final)) % 360
            
            row_features = [l_final, a_final, b_final, chroma, hue] + kit_feat
            X.append(row_features)
        return np.array(X)

    def _extract_labels(self, samples: List[DatasetSampleSchema], task: str) -> np.ndarray:
        y = []
        for sample in samples:
            if task == "classification":
                if not sample.ground_truth_label:
                    raise ValueError(f"Sample {sample.sample_id} missing classification ground truth.")
                y.append(int(sample.ground_truth_label))
            elif task == "regression":
                if sample.ground_truth_value is None:
                    raise ValueError(f"Sample {sample.sample_id} missing regression ground truth.")
                y.append(float(sample.ground_truth_value))
        return np.array(y)

    def train_and_evaluate(
        self, 
        model_id: str,
        model_type: str, 
        task: str,
        train_samples: List[DatasetSampleSchema], 
        test_samples: List[DatasetSampleSchema],
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        # 1. Enforce dataset and leakage gates
        if len(train_samples) == 0:
            return {"status": "BLOCKED", "reason": "Zero eligible training samples. Training blocked."}
            
        for sample in train_samples + test_samples:
            if sample.status not in ["VERIFIED_FOR_DEVELOPMENT", "ELIGIBLE_FOR_EVALUATION"]:
                return {"status": "BLOCKED", "reason": f"Sample {sample.sample_id} is unverified or disputed."}
            if sample.status == "EXCLUDED":
                return {"status": "BLOCKED", "reason": f"Sample {sample.sample_id} is excluded."}

        try:
            X_train = self._extract_features(train_samples)
            y_train = self._extract_labels(train_samples, task)
            X_test = self._extract_features(test_samples)
        except ValueError as e:
            return {"status": "BLOCKED", "reason": str(e)}

        # 2. Fit model
        
        # Apply Random Oversampling to balance classes in training set
        def oversample(X, y):
            if len(y) == 0:
                return X, y
            unique_classes, counts = np.unique(y, return_counts=True)
            max_count = counts.max()
            X_resampled = []
            y_resampled = []
            for cls, count in zip(unique_classes, counts):
                idx = np.where(y == cls)[0]
                if count < max_count:
                    resampled_idx = np.random.choice(idx, max_count, replace=True)
                    X_resampled.append(X[resampled_idx])
                    y_resampled.append(y[resampled_idx])
                else:
                    X_resampled.append(X[idx])
                    y_resampled.append(y[idx])
            return np.vstack(X_resampled), np.concatenate(y_resampled)
            
        if task == "classification":
            X_train, y_train = oversample(X_train, y_train)

        execution_metadata = {}
        if model_type in ["logistic_regression", "random_forest", "hist_gradient_boosting"]:
            model = ClassicalModelBase(model_type=model_type, task=task, **config.get("model_kwargs", {}))
            
            if task == "classification":
                from sklearn.calibration import CalibratedClassifierCV
                # Determine max CV possible (minimum class count)
                _, counts = np.unique(y_train, return_counts=True)
                min_class_count = min(counts)
                
                if min_class_count >= 2:
                    cv_folds = min(3, min_class_count)
                    calibrated_clf = CalibratedClassifierCV(model.model, cv=cv_folds, method='sigmoid')
                    calibrated_clf.fit(X_train, y_train)
                    model.model = calibrated_clf
                else:
                    model.fit(X_train, y_train)
            else:
                model.fit(X_train, y_train)
                
            execution_metadata = {"device": "cpu", "device_mode_requested": "CPU", "seed": config.get("random_seed", 42), "verified_samples_count": len(train_samples) + len(test_samples)}
        elif model_type == "mlp":
            from app.models.deep_learning import DeepLearningModelBase
            device_mode = config.get("device_mode", "AUTO")
            seed = config.get("random_seed", 42)
            model = DeepLearningModelBase(model_type=model_type, task=task, device_mode=device_mode, seed=seed, **config.get("model_kwargs", {}))
            model.fit(X_train, y_train)
            execution_metadata = model.get_execution_metadata()
            execution_metadata["verified_samples_count"] = len(train_samples) + len(test_samples)
        else:
            return {"status": "BLOCKED", "reason": f"Unsupported model_type: {model_type}"}

        # 3. Evaluate on isolated test set
        if task == "classification":
            raw_labels = model.predict(X_test)
            probs = model.predict_proba(X_test) if hasattr(model, "predict_proba") else None
            predictions = []
            for i, label in enumerate(raw_labels):
                if probs is not None:
                    confidence = float(np.max(probs[i]))
                else:
                    confidence = 1.0
                predictions.append({"label": int(label), "confidence": confidence})
        else:
            predictions = model.predict(X_test).tolist()
        
        if task == "classification":
            eval_result = self.evaluator.evaluate_classification(test_samples, predictions)
        else:
            eval_result = self.evaluator.evaluate_regression(test_samples, predictions)

        if eval_result.blocked:
            return {"status": "BLOCKED", "reason": eval_result.blocked_reason}

        # 4. Model Artifact and Governance
        dependency_versions = {"scikit-learn": "1.3.0"}
        if model_type == "mlp":
            import torch
            dependency_versions["torch"] = torch.__version__

        metadata = ModelArtifactMetadata(
            model_id=model_id,
            model_version="1.0",
            training_dataset_version=train_samples[0].dataset_version if train_samples else "unknown",
            feature_version="cielab-v1",
            preprocessing_version="standard-scaler-v1",
            assay_version=config.get("assay_version", "unknown"),
            protocol_version=config.get("protocol_version", "unknown"),
            training_config=config,
            dependency_versions=dependency_versions,
            random_seed=config.get("random_seed", 42),
            evaluation_metrics=eval_result.metrics,
            approval_status="RESEARCH_ONLY",
            execution_metadata=execution_metadata
        )
        
        artifact_manager.register_artifact(metadata)

        return {
            "status": "SUCCESS",
            "model_id": model_id,
            "metrics": eval_result.metrics,
            "counts": eval_result.sample_counts,
            "hash": metadata.integrity_hash,
            "execution_metadata": execution_metadata
        }
