# FieldSure — Development Setup Script
# Run this once after cloning the repository.

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  FieldSure — Development Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
$tools = @(
    @{ Name = "flutter"; Cmd = "flutter --version" },
    @{ Name = "dart"; Cmd = "dart --version" },
    @{ Name = "node"; Cmd = "node --version" },
    @{ Name = "npm"; Cmd = "npm --version" },
    @{ Name = "python"; Cmd = "python --version" },
    @{ Name = "docker"; Cmd = "docker --version" },
    @{ Name = "git"; Cmd = "git --version" }
)

$allPresent = $true
foreach ($tool in $tools) {
    try {
        $null = Invoke-Expression $tool.Cmd 2>&1
        Write-Host "  [OK] $($tool.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  [MISSING] $($tool.Name)" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host ""
    Write-Host "Please install missing tools before continuing." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Copy .env if not present
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "[OK] Created .env from .env.example" -ForegroundColor Green
} else {
    Write-Host "[SKIP] .env already exists" -ForegroundColor Yellow
}

# Flutter dependencies
Write-Host ""
Write-Host "--- Flutter (apps/mobile) ---" -ForegroundColor Cyan
Push-Location apps/mobile
flutter pub get
Pop-Location

# NestJS dependencies
Write-Host ""
Write-Host "--- NestJS API (apps/api) ---" -ForegroundColor Cyan
Push-Location apps/api
npm install
Pop-Location

# Python virtual environment
Write-Host ""
Write-Host "--- Python ML Service (apps/ml-service) ---" -ForegroundColor Cyan
Push-Location apps/ml-service
if (-not (Test-Path ".venv")) {
    python -m venv .venv
    Write-Host "[OK] Created Python virtual environment" -ForegroundColor Green
}
& .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
deactivate
Pop-Location

# Start infrastructure
Write-Host ""
Write-Host "--- Docker Infrastructure ---" -ForegroundColor Cyan
docker compose up -d postgres redis minio minio-init

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review .env and adjust if needed"
Write-Host "  2. Run: .\scripts\dev.ps1   (start all services)"
Write-Host "  3. Run: .\scripts\test-all.ps1  (run all tests)"
Write-Host ""
