"""Request models for the ML service API."""

from pydantic import BaseModel


class ProcessRequest(BaseModel):
    """Request to process an image through the CV pipeline."""

    image_url: str
    """S3 URL of the image to process."""

    kit_code: str
    """Test kit identifier for kit-specific classification."""

    config_version: str
    """Classification configuration version to use."""

    model_version: str = "DEMO-CONFIG-v1"
    """Algorithm/model version."""

    test_id: str
    """Test UUID from the API service."""

    processing_run_id: str
    """Processing run UUID from the API service."""
