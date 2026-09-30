"""FieldSure ML Service — Computer Vision Pipeline for Field Drug Testing."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import health, process
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    """Application lifespan manager."""
    # Startup
    print(f"Starting FieldSure ML Service v{settings.APP_VERSION}")
    
    # Validate production configuration
    if not settings.DEBUG:
        try:
            settings.validate_production_config()
            print("Production configuration validated")
        except ValueError as e:
            print(f"FATAL: Production configuration invalid: {e}")
            raise
    
    yield
    # Shutdown
    print("Shutting down FieldSure ML Service")


app = FastAPI(
    title="FieldSure ML Service",
    description="Computer Vision Pipeline for Field Drug Testing",
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs" if settings.DEBUG else None,  # Disable docs in production
    redoc_url="/redoc" if settings.DEBUG else None,
)

# CORS middleware (restricted in production)
if settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Register routes
app.include_router(health.router, tags=["Health"])
app.include_router(process.router, prefix="/process", tags=["Processing"])
