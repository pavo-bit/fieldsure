# Run Flutter app on physical device pointing to local host network API
$hostIp = "192.168.1.23"
Write-Host "Running Flutter app targeting physical device API endpoint at $hostIp..." -ForegroundColor Cyan

Push-Location apps/mobile
flutter run -d 10BE3M1ZNX0004U --dart-define=API_BASE_URL=http://${hostIp}:3000/api/v1
Pop-Location
