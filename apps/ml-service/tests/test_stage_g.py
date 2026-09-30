import pytest
import numpy as np
from app.models.artifact import ModelArtifactMetadata, artifact_manager
from app.models.classical import ClassicalModelBase
from app.models.trainer import ModelTrainer
from app.models.inference import SafeInferenceEngine
from app.dataset.evaluation import Evaluator
from app.dataset.models import DatasetSampleSchema

def test_classical_model_base_logistic():
    model = ClassicalModelBase(model_type="logistic_regression", task="classification")
    X = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    y = np.array(["A", "B"])
    model.fit(X, y)
    preds = model.predict(X)
    assert len(preds) == 2

def test_classical_model_base_random_forest():
    model = ClassicalModelBase(model_type="random_forest", task="regression", random_state=42)
    X = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    y = np.array([10.5, 20.5])
    model.fit(X, y)
    preds = model.predict(X)
    assert len(preds) == 2

def test_artifact_registration_and_hash():
    meta = ModelArtifactMetadata(
        model_id="test-model-1",
        model_version="1.0",
        training_dataset_version="v1",
        feature_version="cielab",
        preprocessing_version="std",
        assay_version="assay-1",
        protocol_version="proto-1",
        training_config={"model": "rf"},
        dependency_versions={},
        random_seed=42,
        evaluation_metrics={"acc": 0.9},
        approval_status="RESEARCH_ONLY"
    )
    registered = artifact_manager.register_artifact(meta)
    assert registered.integrity_hash is not None
    assert artifact_manager.get_artifact("test-model-1") == registered

def test_model_promotion_prevention():
    meta = ModelArtifactMetadata(
        model_id="test-demo-1",
        model_version="1.0",
        training_dataset_version="DEMO-v1",
        feature_version="cielab",
        preprocessing_version="std",
        assay_version="assay-1",
        protocol_version="proto-1",
        training_config={},
        dependency_versions={},
        random_seed=42,
        evaluation_metrics={},
        approval_status="APPROVED"
    )
    # Should prevent promotion if trained on DEMO data
    with pytest.raises(ValueError, match="Cannot promote model trained on DEMO data"):
        artifact_manager.register_artifact(meta)

def test_trainer_blocked_zero_samples():
    evaluator = Evaluator(min_engineering_gate_samples=2)
    trainer = ModelTrainer(evaluator)
    result = trainer.train_and_evaluate("m1", "logistic_regression", "classification", [], [], {})
    assert result["status"] == "BLOCKED"
    assert "Zero eligible training samples" in result["reason"]

def test_trainer_rejects_unverified_records():
    evaluator = Evaluator(min_engineering_gate_samples=2)
    trainer = ModelTrainer(evaluator)
    
    # Create a synthetic unverified sample
    s1 = DatasetSampleSchema(
        sample_id="s1",
        dataset_version="v1",
        image_hash="abc",
        kit_code="KIT-1",
        status="PENDING_VERIFICATION"
    )
    
    result = trainer.train_and_evaluate("m2", "logistic_regression", "classification", [s1], [s1], {})
    assert result["status"] == "BLOCKED"
    assert "unverified or disputed" in result["reason"]

def test_safe_inference_quality_gate():
    engine = SafeInferenceEngine()
    result = engine.predict("test-model-1", {"L": 50, "a": 0, "b": 0}, "assay-1", quality_issues=["TOO_DARK"])
    assert result["status"] == "ABSTAIN"
    assert "quality or calibration failures" in result["reason"]

def test_safe_inference_assay_mismatch():
    engine = SafeInferenceEngine()
    # test-model-1 is registered with assay-1
    result = engine.predict("test-model-1", {"L": 50, "a": 0, "b": 0}, "assay-2", quality_issues=[])
    assert result["status"] == "ABSTAIN"
    assert "incompatible with assay-2" in result["reason"]

def test_safe_inference_research_only():
    engine = SafeInferenceEngine()
    # Mocking model load
    model = ClassicalModelBase("logistic_regression", "classification")
    model.fit(np.array([[50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [10, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0]]), np.array(["A", "B"]))
    engine.load_model("test-model-1", model)
    
    result = engine.predict("test-model-1", {"L": 50, "a": 0, "b": 0}, "assay-1", quality_issues=[])
    assert result["status"] == "SUCCESS"
    assert result["production_safe"] is False
    assert result["message"] == "RESEARCH_ONLY inference."
