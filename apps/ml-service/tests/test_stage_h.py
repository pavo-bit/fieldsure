import pytest
import numpy as np
from app.models.artifact import ModelArtifactMetadata, artifact_manager
from app.models.classical import ClassicalModelBase
from app.models.inference import SafeInferenceEngine

@pytest.fixture
def test_artifact():
    meta = ModelArtifactMetadata(
        model_id="stage-h-model",
        model_version="1.0",
        training_dataset_version="v2",
        feature_version="cielab",
        preprocessing_version="std",
        assay_version="assay-1",
        protocol_version="proto-1",
        training_config={"model": "rf"},
        dependency_versions={},
        random_seed=42,
        evaluation_metrics={"accuracy": 0.95},
        approval_status="RESEARCH_ONLY"
    )
    return artifact_manager.register_artifact(meta)

@pytest.fixture
def test_engine():
    engine = SafeInferenceEngine()
    model = ClassicalModelBase("logistic_regression", "classification")
    model.fit(np.array([[50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [10, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0]]), np.array(["A", "B"]))
    engine.load_model("stage-h-model", model)
    return engine

def test_artifact_hash_mismatch(test_artifact, test_engine):
    # Manually tamper with the artifact configuration without updating the hash
    test_artifact.assay_version = "tampered-assay"
    
    result = test_engine.predict("stage-h-model", {"L": 50, "a": 0, "b": 0}, "tampered-assay", [])
    assert result["status"] == "ABSTAIN"
    assert "integrity hash mismatch" in result["reason"]
    
    # Restore
    test_artifact.assay_version = "assay-1"

def test_transition_suspension(test_artifact, test_engine):
    artifact_manager.transition_state("stage-h-model", "SUSPENDED", "admin")
    result = test_engine.predict("stage-h-model", {"L": 50, "a": 0, "b": 0}, "assay-1", [])
    assert result["status"] == "ABSTAIN"
    assert "SUSPENDED" in result["reason"]
    
    # Attempting to reactivate should fail if it goes directly to APPROVED
    with pytest.raises(ValueError, match="Cannot reactivate a suspended or retired artifact"):
        artifact_manager.transition_state("stage-h-model", "APPROVED", "admin")

def test_zero_sample_production_block(test_artifact):
    # Transitioning to APPROVED should fail because there are NO verified lab samples.
    # The artifact has a valid dataset version, but the zero-sample block is hardcoded in validation.
    with pytest.raises(ValueError, match="Zero verified laboratory-linked samples exist. Production approval blocked."):
        artifact_manager.transition_state("stage-h-model", "APPROVED", "admin")

def test_demo_promotion_block():
    meta = ModelArtifactMetadata(
        model_id="stage-h-demo-model",
        model_version="1.0",
        training_dataset_version="DEMO-v1",
        feature_version="cielab",
        preprocessing_version="std",
        assay_version="assay-1",
        protocol_version="proto-1",
        training_config={},
        dependency_versions={},
        random_seed=42,
        evaluation_metrics={"accuracy": 0.95},
        approval_status="RESEARCH_ONLY"
    )
    artifact_manager.register_artifact(meta)
    with pytest.raises(ValueError, match="Cannot promote model trained on DEMO data to APPROVED."):
        artifact_manager.transition_state("stage-h-demo-model", "APPROVED", "admin")

def test_evidence_integration_payload(test_artifact, test_engine):
    # Ensure it is back to a working state
    test_artifact.approval_status = "RESEARCH_ONLY"
    
    result = test_engine.predict("stage-h-model", {"L": 50, "a": 0, "b": 0}, "assay-1", [])
    assert result["status"] == "SUCCESS"
    assert "evidence" in result
    evidence = result["evidence"]
    assert evidence["model_id"] == "stage-h-model"
    assert evidence["integrity_hash"] == test_artifact.integrity_hash
    assert "inference_timestamp" in evidence
