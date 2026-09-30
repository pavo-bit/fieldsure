# FieldSure ML Service - Production Dockerfile
# Multi-stage build with non-root user, pinned versions, security hardening

# ==============================================================================
# Stage 1: Builder
# ==============================================================================
FROM python:3.12.8-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY apps/ml-service/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ==============================================================================
# Stage 2: Runtime
# ==============================================================================
FROM python:3.12.8-slim

# Security: Create non-root user
RUN useradd -m -u 1000 -s /bin/bash mlservice && \
    mkdir -p /app && \
    chown -R mlservice:mlservice /app

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libopencv-core4.6 \
    libopencv-imgproc4.6 \
    libopencv-imgcodecs4.6 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder --chown=mlservice:mlservice /root/.local /home/mlservice/.local

# Copy application code
COPY --chown=mlservice:mlservice apps/ml-service/app ./app

# Switch to non-root user
USER mlservice

# Add Python packages to PATH
ENV PATH=/home/mlservice/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Expose port (bind to internal network only via env var)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()"

# Run with uvicorn
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
