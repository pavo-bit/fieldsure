"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """ML Service configuration."""

    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False

    # Service-to-service authentication
    # Either shared secret or mTLS cert paths must be provided in production
    SHARED_SECRET: str | None = None
    MTLS_ENABLED: bool = False
    MTLS_CA_CERT_PATH: str | None = None
    MTLS_CERT_PATH: str | None = None
    MTLS_KEY_PATH: str | None = None

    # Network binding (internal only in production)
    BIND_HOST: str = "0.0.0.0"  # Use "127.0.0.1" or internal network IP in prod
    BIND_PORT: int = 8000

    # S3 / MinIO
    S3_ENDPOINT: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minioadmin"
    S3_SECRET_KEY: str = "minioadmin"
    S3_BUCKET: str = "fieldsure-images"
    S3_REGION: str = "us-east-1"

    # Signed URL validation
    SIGNED_URL_SECRET: str | None = None
    SIGNED_URL_MAX_AGE_SECONDS: int = 3600

    # URL host allowlist for image fetching
    ALLOWED_IMAGE_HOSTS: list[str] = ["localhost", "127.0.0.1", "minio"]

    # API Service
    API_SERVICE_URL: str = "http://localhost:3000"

    # CORS (empty list in production - internal service only)
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]

    # Processing limits
    MAX_IMAGE_SIZE_MB: int = 20
    MAX_IMAGE_SIZE_BYTES: int = 20 * 1024 * 1024
    MIN_IMAGE_RESOLUTION: int = 1920
    MAX_IMAGE_RESOLUTION: int = 8192
    REQUEST_TIMEOUT_SECONDS: int = 30

    # Decode bomb protection
    MAX_IMAGE_PIXELS: int = 178956970  # Default PIL limit, ~8192x8192

    model_config = {
        "env_file": ".env",
        "env_prefix": "ML_",
        "case_sensitive": True,
        "extra": "ignore",
    }

    def validate_production_config(self) -> None:
        """Validate that production requirements are met."""
        if not self.DEBUG:
            if not self.SHARED_SECRET and not self.MTLS_ENABLED:
                raise ValueError(
                    "Production mode requires either SHARED_SECRET or MTLS_ENABLED"
                )
            if self.BIND_HOST == "0.0.0.0":
                raise ValueError(
                    "Production mode should not bind to 0.0.0.0 - use internal network IP"
                )
            if self.CORS_ORIGINS:
                raise ValueError(
                    "Production mode should have empty CORS_ORIGINS (internal service)"
                )


settings = Settings()
