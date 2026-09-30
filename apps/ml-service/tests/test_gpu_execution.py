import pytest
import torch
import numpy as np
from app.models.deep_learning import DeepLearningModelBase
import copy

def test_gpu_auto_selection(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: True)
    model = DeepLearningModelBase(device_mode="AUTO")
    assert model.device.type == "cuda"

def test_cpu_auto_selection(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    model = DeepLearningModelBase(device_mode="AUTO")
    assert model.device.type == "cpu"

def test_explicit_gpu_success(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: True)
    model = DeepLearningModelBase(device_mode="GPU")
    assert model.device.type == "cuda"

def test_explicit_gpu_failure(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    with pytest.raises(RuntimeError, match="CUDA is unavailable"):
        DeepLearningModelBase(device_mode="GPU")

def test_explicit_cpu_selection():
    model = DeepLearningModelBase(device_mode="CPU")
    assert model.device.type == "cpu"

def test_invalid_device_mode():
    with pytest.raises(ValueError, match="Invalid device_mode"):
        DeepLearningModelBase(device_mode="INVALID")

def test_execution_metadata_cpu():
    model = DeepLearningModelBase(device_mode="CPU", seed=123)
    meta = model.get_execution_metadata()
    assert meta["device"] == "cpu"
    assert meta["device_mode_requested"] == "CPU"
    assert meta["seed"] == 123
    assert "cuda_available" in meta
    assert "cuda_version" in meta

def test_execution_metadata_gpu(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: True)
    monkeypatch.setattr(torch.version, "cuda", "12.1")
    model = DeepLearningModelBase(device_mode="GPU", seed=456)
    meta = model.get_execution_metadata()
    assert meta["device"] == "cuda"
    assert meta["device_mode_requested"] == "GPU"
    assert meta["seed"] == 456
    assert meta["cuda_available"] is True
    assert meta["cuda_version"] == "12.1"

def test_deterministic_seed_cpu():
    model1 = DeepLearningModelBase(device_mode="CPU", seed=42)
    model2 = DeepLearningModelBase(device_mode="CPU", seed=42)
    
    X = np.random.rand(10, 5)
    y = np.random.randint(0, 2, 10)
    
    model1.fit(X, y)
    model2.fit(X, y)
    
    w1 = model1.model.net[0].weight.data.numpy()
    w2 = model2.model.net[0].weight.data.numpy()
    np.testing.assert_array_equal(w1, w2)

def test_deterministic_seed_diff():
    model1 = DeepLearningModelBase(device_mode="CPU", seed=42)
    model2 = DeepLearningModelBase(device_mode="CPU", seed=43)
    
    X = np.random.rand(10, 5)
    y = np.random.randint(0, 2, 10)
    
    model1.fit(X, y)
    model2.fit(X, y)
    
    w1 = model1.model.net[0].weight.data.numpy()
    w2 = model2.model.net[0].weight.data.numpy()
    assert not np.array_equal(w1, w2)

def test_prepare_data_classification():
    model = DeepLearningModelBase(device_mode="CPU", task="classification")
    X = np.array([[1, 2], [3, 4]])
    y = np.array([0, 1])
    Xt, yt = model._prepare_data(X, y)
    assert Xt.dtype == torch.float32
    assert yt.dtype == torch.int64

def test_prepare_data_regression():
    model = DeepLearningModelBase(device_mode="CPU", task="regression")
    X = np.array([[1, 2], [3, 4]])
    y = np.array([0.5, 1.5])
    Xt, yt = model._prepare_data(X, y)
    assert Xt.dtype == torch.float32
    assert yt.dtype == torch.float32

def test_fit_empty_data():
    model = DeepLearningModelBase(device_mode="CPU")
    with pytest.raises(ValueError, match="Cannot train on empty dataset"):
        model.fit(np.array([]), np.array([]))

def test_classification_single_class():
    model = DeepLearningModelBase(device_mode="CPU", task="classification")
    X = np.random.rand(5, 3)
    y = np.zeros(5)
    with pytest.raises(ValueError, match="Classification requires at least 2 distinct classes"):
        model.fit(X, y)

def test_regression_fit_predict():
    model = DeepLearningModelBase(device_mode="CPU", task="regression", epochs=2)
    X = np.random.rand(10, 3)
    y = np.random.rand(10)
    model.fit(X, y)
    preds = model.predict(X)
    assert preds.shape == (10,)

def test_classification_fit_predict():
    model = DeepLearningModelBase(device_mode="CPU", task="classification", epochs=2)
    X = np.random.rand(10, 3)
    y = np.random.randint(0, 2, 10)
    model.fit(X, y)
    preds = model.predict(X)
    assert preds.shape == (10,)
    assert set(preds).issubset({0, 1})

def test_predict_unfitted():
    model = DeepLearningModelBase(device_mode="CPU")
    X = np.random.rand(5, 3)
    with pytest.raises(RuntimeError, match="Model is not fitted yet"):
        model.predict(X)

def test_predict_empty():
    model = DeepLearningModelBase(device_mode="CPU", task="regression", epochs=1)
    X = np.random.rand(10, 3)
    y = np.random.rand(10)
    model.fit(X, y)
    preds = model.predict(np.array([]))
    assert len(preds) == 0

def test_save_load_model(tmp_path):
    model = DeepLearningModelBase(device_mode="CPU", task="classification", epochs=1)
    X = np.random.rand(10, 3)
    y = np.random.randint(0, 2, 10)
    model.fit(X, y)
    
    path = tmp_path / "model.pt"
    model.save(str(path))
    
    model2 = DeepLearningModelBase(device_mode="CPU", task="classification")
    model2.load(str(path), input_dim=3, output_dim=2)
    
    preds1 = model.predict(X)
    preds2 = model2.predict(X)
    np.testing.assert_array_equal(preds1, preds2)

def test_device_caching():
    model = DeepLearningModelBase(device_mode="CPU")
    assert model.device.type == "cpu"
    # changing mode doesn't change device automatically unless re-selected
    model.device_mode = "GPU" 
    assert model.device.type == "cpu"
