# scripts/evaluate-model.ps1
# Helper script to execute reproducible model evaluations when a validated dataset is ingested.

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName

Write-Host "Initiating CV/ML Model Evaluation..." -ForegroundColor Cyan

Set-Location "$ProjectRoot\apps\ml-service"

# This requires the python virtual environment
if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "Error: Python virtual environment not found in apps/ml-service/.venv" -ForegroundColor Red
    exit 1
}

Write-Host "Checking for datasets..."
# Currently blocked until actual labeled data exists
Write-Host "Status: BLOCKED. No scientifically validated labeled dataset exists." -ForegroundColor Yellow
Write-Host "See docs/dataset_audit.md for more information." -ForegroundColor Yellow

# When data exists, this will trigger the python evaluation module:
# & .\.venv\Scripts\python.exe -m app.evaluation.runner --config default

Write-Host "Evaluation halted." -ForegroundColor Gray
