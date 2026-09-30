# FieldSure — Run All Linters

Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  FieldSure — Lint All Services' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

$exitCode = 0

# Flutter
Write-Host ''
Write-Host '--- Flutter (apps/mobile) ---' -ForegroundColor Cyan
Push-Location apps/mobile
flutter analyze
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

# NestJS
Write-Host ''
Write-Host '--- NestJS API (apps/api) ---' -ForegroundColor Cyan
Push-Location apps/api
npm run lint
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

# Python
Write-Host ''
Write-Host '--- Python ML Service (apps/ml-service) ---' -ForegroundColor Cyan
Push-Location apps/ml-service
if (Test-Path '.venv') {
    & .\.venv\Scripts\Activate.ps1
}
ruff check .
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

Write-Host ''
if ($exitCode -eq 0) {
    Write-Host 'All linters passed!' -ForegroundColor Green
} else {
    Write-Host 'Some linters failed. See output above.' -ForegroundColor Red
}

exit $exitCode
