# scripts/seed-demo.ps1
# Helper script to quickly seed the FieldSure API database with demo configuration
# Requirements: Node, npm must be installed.

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName

Write-Host "Seeding Demo Data into the Database..." -ForegroundColor Cyan

Set-Location "$ProjectRoot\apps\api"

Write-Host "Running npx tsx prisma/seed.ts..."
npx tsx prisma/seed.ts

Write-Host "Demo data seeding complete!" -ForegroundColor Green
