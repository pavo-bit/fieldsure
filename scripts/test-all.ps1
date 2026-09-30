# FieldSure — Run All Tests

Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  FieldSure — Test All Services' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

$exitCode = 0

# Flutter
Write-Host ''
Write-Host '--- Flutter (apps/mobile) ---' -ForegroundColor Cyan
Push-Location apps/mobile
flutter test
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

# NestJS
Write-Host ''
Write-Host '--- NestJS API (apps/api) ---' -ForegroundColor Cyan
Push-Location apps/api
npm run test
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

# Python
Write-Host ''
Write-Host '--- Python ML Service (apps/ml-service) ---' -ForegroundColor Cyan
Push-Location apps/ml-service
if (Test-Path '.venv') {
    & .\.venv\Scripts\Activate.ps1
}
pytest
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
Pop-Location

Write-Host ''
if ($exitCode -eq 0) {
    Write-Host 'All tests passed!' -ForegroundColor Green
} else {
    Write-Host 'Some tests failed. See output above.' -ForegroundColor Red
}

exit $exitCode
