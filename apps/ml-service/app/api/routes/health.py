"""Health check endpoints."""

from datetime import UTC, datetime

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    """Basic health check."""
    return {
        "status": "healthy",
        "service": "fieldsure-ml-service",
        "timestamp": datetime.now(UTC).isoformat(),
    }


@router.get("/health/ready")
async def readiness_check() -> dict[str, str]:
    """Readiness probe — checks that dependencies are available."""
    # TODO: Check S3 connectivity, model availability
    return {
        "status": "ready",
        "timestamp": datetime.now(UTC).isoformat(),
    }
