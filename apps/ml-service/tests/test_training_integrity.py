import pytest
import numpy as np
from app.models.trainer import ModelTrainer
from app.dataset.evaluation import Evaluator
from app.dataset.models import DatasetSampleSchema
from app.models.artifact import artifact_manager
import datetime

@pytest.fixture
def mock_evaluator():
    class MockEvaluator(Evaluator):
        def evaluate_classification(self, samples, preds):
            from app.dataset.evaluation import EvaluationResult
            return EvaluationResult(blocked=False, metrics={"accuracy": 0.99}, sample_counts={"total": len(samples)})
        def evaluate_regression(self, samples, preds):
            from app.dataset.evaluation import EvaluationResult
            return EvaluationResult(blocked=False, metrics={"mse": 0.01}, sample_counts={"total": len(samples)})
    return MockEvaluator()

@pytest.fixture
def trainer(mock_evaluator):
    return ModelTrainer(mock_evaluator)

def create_sample(id="1", status="VERIFIED_FOR_DEVELOPMENT", label="1", value=1.0, qa=None):
    if qa is None:
        qa = {"is_valid": True, "quality_flag": False}
    return DatasetSampleSchema(
        sample_id=id,
        group_id="G1",
        dataset_version="v1",
        status=status,
        ground_truth_label=str(label) if label is not None else None,
        ground_truth_value=value,
        calibrated_measurements={"L": 50.0, "a": 10.0, "b": 10.0},
        quality_assessment=qa,
        image_hash="hash123",
        kit_code="kit123",
        camera_metadata={},
        environmental_metadata={},
        collected_at=datetime.datetime.now().isoformat()
    )

def test_train_eligible_samples(trainer):
    train = [create_sample("1", "VERIFIED_FOR_DEVELOPMENT", 1), create_sample("2", "VERIFIED_FOR_DEVELOPMENT", 0)]
    test = [create_sample("3", "ELIGIBLE_FOR_EVALUATION", 1)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, test, {})
    assert res["status"] == "SUCCESS"

def test_train_empty_dataset(trainer):
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", [], [], {})
    assert res["status"] == "BLOCKED"
    assert "Zero eligible training samples" in res["reason"]

def test_train_unverified_sample(trainer):
    train = [create_sample("1", "PENDING_VERIFICATION", 1)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, [], {})
    assert res["status"] == "BLOCKED"
    assert "unverified or disputed" in res["reason"]

def test_train_excluded_sample(trainer):
    train = [create_sample("1", "EXCLUDED", 1)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, [], {})
    assert res["status"] == "BLOCKED"
    assert "unverified or disputed" in res["reason"].lower()

def test_test_unverified_sample(trainer):
    train = [create_sample("1", "VERIFIED_FOR_DEVELOPMENT", 1)]
    test = [create_sample("2", "PENDING_VERIFICATION", 1)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, test, {})
    assert res["status"] == "BLOCKED"
    assert "unverified or disputed" in res["reason"]

def test_quality_flag_blocked(trainer):
    qa = {"is_valid": True, "quality_flag": True}
    train = [create_sample("1", qa=qa)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, [], {})
    assert res["status"] == "BLOCKED"
    assert "failed quality assessment" in res["reason"]

def test_invalid_quality_blocked(trainer):
    qa = {"is_valid": False, "quality_flag": False}
    train = [create_sample("1", qa=qa)]
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", train, [], {})
    assert res["status"] == "BLOCKED"
    assert "failed quality assessment" in res["reason"]

def test_missing_classification_gt(trainer):
    sample = create_sample("1")
    sample.ground_truth_label = None
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "classification", [sample], [], {})
    assert res["status"] == "BLOCKED"
    assert "missing classification ground truth" in res["reason"]

def test_missing_regression_gt(trainer):
    sample = create_sample("1")
    sample.ground_truth_value = None
    res = trainer.train_and_evaluate("test_model", "logistic_regression", "regression", [sample], [], {})
    assert res["status"] == "BLOCKED"
    assert "missing regression ground truth" in res["reason"]

def test_feature_extraction():
    from app.models.trainer import ModelTrainer
    trainer = ModelTrainer(None)
    s = create_sample()
    X = trainer._extract_features([s])
    assert X.shape == (1, 12)
    expected = [50.0, 10.0, 10.0, 14.142135623730951, 45.0] + [0.0]*7
    np.testing.assert_allclose(X[0], expected)

def test_feature_extraction_missing_cal():
    from app.models.trainer import ModelTrainer
    trainer = ModelTrainer(None)
    s = create_sample()
    s.calibrated_measurements = None
    X = trainer._extract_features([s])
    expected = [0.0, 0.0, 0.0, 0.0, 0.0] + [0.0]*7
    np.testing.assert_allclose(X[0], expected)

def test_label_extraction_class():
    from app.models.trainer import ModelTrainer
    trainer = ModelTrainer(None)
    y = trainer._extract_labels([create_sample(label=42)], "classification")
    assert y[0] == 42

def test_label_extraction_reg():
    from app.models.trainer import ModelTrainer
    trainer = ModelTrainer(None)
    y = trainer._extract_labels([create_sample(value=42.5)], "regression")
    assert y[0] == 42.5

def test_unsupported_model_type(trainer):
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    res = trainer.train_and_evaluate("test_model", "unsupported_magic", "classification", train, [], {})
    assert res["status"] == "BLOCKED"
    assert "Unsupported model_type" in res["reason"]

def test_deep_learning_integration(trainer):
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    test = [create_sample("3", label=1)]
    res = trainer.train_and_evaluate("dl_model", "mlp", "classification", train, test, {"device_mode": "CPU", "model_kwargs": {"epochs": 1}})
    assert res["status"] == "SUCCESS"
    assert res["execution_metadata"]["device"] == "cpu"
    assert "torch" in artifact_manager.artifacts["dl_model"].dependency_versions

def test_deep_learning_regression_integration(trainer):
    train = [create_sample("1", label=1, value=1.0), create_sample("2", label=0, value=0.0)]
    test = [create_sample("3", label=1, value=1.0)]
    res = trainer.train_and_evaluate("dl_model_reg", "mlp", "regression", train, test, {"device_mode": "CPU", "model_kwargs": {"epochs": 1}})
    assert res["status"] == "SUCCESS"
    assert res["execution_metadata"]["device"] == "cpu"

def test_evaluator_blocked(trainer, monkeypatch):
    class BlockedEvaluator(Evaluator):
        def evaluate_classification(self, s, p):
            from app.dataset.evaluation import EvaluationResult
            return EvaluationResult(blocked=True, blocked_reason="Eval Failed", metrics={}, sample_counts={})
    trainer.evaluator = BlockedEvaluator()
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    test = [create_sample("3", label=1)]
    res = trainer.train_and_evaluate("fail_model", "logistic_regression", "classification", train, test, {})
    assert res["status"] == "BLOCKED"
    assert res["reason"] == "Eval Failed"

def test_training_metrics_propagated(trainer):
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    res = trainer.train_and_evaluate("metrics_model", "logistic_regression", "classification", train, [create_sample("3", label=1), create_sample("4", label=0)], {})
    assert res["metrics"]["accuracy"] == 0.99

def test_counts_propagated(trainer):
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    test = [create_sample("3", label=1)]
    res = trainer.train_and_evaluate("counts_model", "logistic_regression", "classification", train, test, {})
    assert res["counts"]["total"] == 1 # length of test set

def test_artifact_registration_on_success(trainer):
    train = [create_sample("1", label=1), create_sample("2", label=0)]
    res = trainer.train_and_evaluate("reg_model", "logistic_regression", "classification", train, [create_sample("3", label=1), create_sample("4", label=0)], {})
    assert res["status"] == "SUCCESS"
    assert "reg_model" in artifact_manager.artifacts
    assert artifact_manager.artifacts["reg_model"].approval_status == "RESEARCH_ONLY"
