# FieldSure — Start Development Environment
# Starts infrastructure and all services for local development.

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  FieldSure — Starting Development" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Start Docker infrastructure
Write-Host "--- Starting infrastructure (PostgreSQL, Redis, MinIO) ---" -ForegroundColor Cyan
docker compose up -d postgres redis minio minio-init

# Wait for services to be healthy
Write-Host "Waiting for infrastructure..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Start NestJS API
Write-Host ""
Write-Host "--- Starting NestJS API (port 3000) ---" -ForegroundColor Cyan
$apiJob = Start-Process -FilePath "npm" -ArgumentList "run", "start:dev" -WorkingDirectory "apps/api" -PassThru -NoNewWindow

# Start ML Service
Write-Host ""
Write-Host "--- Starting ML Service (port 8000) ---" -ForegroundColor Cyan
Push-Location apps/ml-service
& .\.venv\Scripts\Activate.ps1
$mlJob = Start-Process -FilePath "uvicorn" -ArgumentList "app.main:app", "--reload", "--port", "8000" -PassThru -NoNewWindow
Pop-Location

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  All services started!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Services:" -ForegroundColor Yellow
Write-Host "  API:        http://localhost:3000"
Write-Host "  ML Service: http://localhost:8000"
Write-Host "  MinIO:      http://localhost:9001 (console)"
Write-Host "  PostgreSQL: localhost:5432"
Write-Host "  Redis:      localhost:6379"
Write-Host ""
Write-Host "Flutter:      cd apps/mobile && flutter run" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop services." -ForegroundColor Gray
Write-Host ""

# Wait for interrupt
try {
    Wait-Process -Id $apiJob.Id
} catch {
    Write-Host "Shutting down..." -ForegroundColor Yellow
    Stop-Process -Id $apiJob.Id -ErrorAction SilentlyContinue
    Stop-Process -Id $mlJob.Id -ErrorAction SilentlyContinue
    docker compose stop
}
