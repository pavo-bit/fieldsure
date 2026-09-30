"""Image processing endpoint."""

from fastapi import APIRouter, Depends, HTTPException, status, Body

from app.core.auth import verify_shared_secret
from app.core.validation import ValidationError
from app.schemas.requests import ProcessRequest
from app.schemas.responses import ProcessResponse, ErrorResponse

router = APIRouter()


from app.services.pipeline import MLPipeline

pipeline = MLPipeline()


@router.post(
    "",
    response_model=ProcessResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Validation error"},
        401: {"model": ErrorResponse, "description": "Authentication failed"},
        403: {"model": ErrorResponse, "description": "Forbidden"},
        413: {"model": ErrorResponse, "description": "Image too large"},
        500: {"model": ErrorResponse, "description": "Processing error"},
        503: {"model": ErrorResponse, "description": "Service unavailable"},
    },
    dependencies=[Depends(verify_shared_secret)],
)
async def process_image(payload: ProcessRequest = Body(..., embed=False)) -> ProcessResponse:
    """
    Process an image through the CV pipeline.
    
    Requires authentication via Bearer token (shared secret).
    """
    import logging
    logger = logging.getLogger("inference_telemetry")
    try:
        response = await pipeline.process(payload)
        
        # Privacy-preserving aggregate telemetry
        telemetry_event = {
            "event": "inference_request",
            "model_version": payload.model_version,
            "config_version": payload.config_version,
            "status": response.status,
            "quality_status": response.quality.assessment.overall_status if response.quality and response.quality.assessment else "UNKNOWN",
            "timestamp": response.classification.classifiedAt if response.classification else None,
            "validation_status": response.classification.validationStatus if response.classification else "UNVALIDATED"
        }
        logger.info(str(telemetry_event))
        
        return response
    except ValidationError as e:
        logger.warning({"event": "validation_error", "code": e.code})
        raise HTTPException(
            status_code=e.status_code,
            detail={"code": e.code, "message": e.message},
        )
    except Exception as e:
        # Log error details but return generic message to client
        print(f"Processing error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": "PROCESSING_ERROR",
                "message": "An error occurred during processing",
            },
        )
