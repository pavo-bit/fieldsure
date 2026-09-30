"""
Request validation and security checks.

Implements:
- URL host allowlist
- Image size limits
- Decode bomb protection
- Content type validation
"""

import hashlib
from urllib.parse import urlparse

from PIL import Image as PILImage
from fastapi import HTTPException, status

from app.core.config import settings


class ValidationError(Exception):
    """Custom validation error with error code."""
    
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def validate_image_url(url: str) -> None:
    """
    Validate image URL against allowlist.
    
    Raises ValidationError if URL is not allowed.
    """
    if not url:
        raise ValidationError(
            code="INVALID_URL",
            message="Image URL is required",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    
    parsed = urlparse(url)
    
    # Check scheme
    if parsed.scheme not in ("http", "https", "s3"):
        raise ValidationError(
            code="INVALID_URL_SCHEME",
            message=f"URL scheme '{parsed.scheme}' not allowed",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    
    # Check host against allowlist (skip for S3 URLs)
    if parsed.scheme in ("http", "https"):
        hostname = parsed.hostname or ""
        
        # In production, enforce strict allowlist
        if not settings.DEBUG:
            if not any(
                hostname == allowed or hostname.endswith(f".{allowed}")
                for allowed in settings.ALLOWED_IMAGE_HOSTS
            ):
                raise ValidationError(
                    code="URL_HOST_NOT_ALLOWED",
                    message=f"Host '{hostname}' not in allowlist",
                    status_code=status.HTTP_403_FORBIDDEN,
                )


def validate_image_size(content_length: int | None) -> None:
    """
    Validate image size from Content-Length header.
    
    Raises ValidationError if size exceeds limit.
    """
    if content_length is None:
        # Cannot validate without Content-Length, will check after download
        return
    
    if content_length > settings.MAX_IMAGE_SIZE_BYTES:
        size_mb = content_length / (1024 * 1024)
        raise ValidationError(
            code="IMAGE_TOO_LARGE",
            message=f"Image size {size_mb:.1f}MB exceeds limit of {settings.MAX_IMAGE_SIZE_MB}MB",
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        )


def validate_image_content(image_bytes: bytes) -> dict[str, any]:
    """
    Validate image content and protect against decode bombs.
    
    Returns dict with validation results:
    - size_bytes: actual size in bytes
    - width: image width in pixels
    - height: image height in pixels
    - format: image format (JPEG, PNG, etc)
    - sha256: SHA-256 hash of image bytes
    
    Raises ValidationError if image is invalid or exceeds limits.
    """
    # Check byte size
    size_bytes = len(image_bytes)
    if size_bytes > settings.MAX_IMAGE_SIZE_BYTES:
        size_mb = size_bytes / (1024 * 1024)
        raise ValidationError(
            code="IMAGE_TOO_LARGE",
            message=f"Image size {size_mb:.1f}MB exceeds limit of {settings.MAX_IMAGE_SIZE_MB}MB",
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        )
    
    # Set PIL decode bomb protection
    PILImage.MAX_IMAGE_PIXELS = settings.MAX_IMAGE_PIXELS
    
    try:
        # Open image to get dimensions without full decode
        with PILImage.open(io.BytesIO(image_bytes)) as img:
            width, height = img.size
            image_format = img.format or "UNKNOWN"
            
            # Check resolution limits
            if width < settings.MIN_IMAGE_RESOLUTION or height < settings.MIN_IMAGE_RESOLUTION:
                raise ValidationError(
                    code="IMAGE_RESOLUTION_TOO_LOW",
                    message=f"Image resolution {width}x{height} below minimum {settings.MIN_IMAGE_RESOLUTION}px",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
            
            if width > settings.MAX_IMAGE_RESOLUTION or height > settings.MAX_IMAGE_RESOLUTION:
                raise ValidationError(
                    code="IMAGE_RESOLUTION_TOO_HIGH",
                    message=f"Image resolution {width}x{height} exceeds maximum {settings.MAX_IMAGE_RESOLUTION}px",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
            
            # Check total pixels (decode bomb protection)
            total_pixels = width * height
            if total_pixels > settings.MAX_IMAGE_PIXELS:
                raise ValidationError(
                    code="IMAGE_DECOMPRESSION_BOMB",
                    message=f"Image has {total_pixels} pixels, exceeds safety limit",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
    
    except PILImage.DecompressionBombError:
        raise ValidationError(
            code="IMAGE_DECOMPRESSION_BOMB",
            message="Image would consume too much memory when decompressed",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    except Exception as e:
        raise ValidationError(
            code="IMAGE_INVALID",
            message=f"Failed to validate image: {str(e)}",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    
    # Calculate SHA-256 hash for integrity
    sha256_hash = hashlib.sha256(image_bytes).hexdigest()
    
    return {
        "size_bytes": size_bytes,
        "width": width,
        "height": height,
        "format": image_format,
        "sha256": sha256_hash,
    }


import io
