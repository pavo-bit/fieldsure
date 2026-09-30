"""Tests for the ML service health endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check() -> None:
    """Health endpoint returns healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "fieldsure-ml-service"
    assert "timestamp" in data


def test_readiness_check() -> None:
    """Readiness endpoint returns ready status."""
    response = client.get("/health/ready")
    assert response.status_code == 200
    data = response.json()
def test_process_endpoint() -> None:
    """Process endpoint returns failed status for missing image."""
    from app.core.auth import verify_shared_secret
    
    app.dependency_overrides[verify_shared_secret] = lambda: None
    
    response = client.post(
        "/process",
        json={
            "image_url": "s3://test-bucket/test.jpg",
            "kit_code": "TEST_KIT_001",
            "config_version": "1.0.0",
            "model_version": "DEMO-CONFIG-v1",
            "test_id": "test-uuid-123",
            "processing_run_id": "run-uuid-456",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "failed"
    assert data["test_id"] == "test-uuid-123"
    assert data["processing_run_id"] == "run-uuid-456"
    
    app.dependency_overrides.clear()
