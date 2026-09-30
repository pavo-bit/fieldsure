# scripts/corrupt-demo-evidence.ps1
# Helper script to deliberately corrupt an evidence record in the database
# to demonstrate cryptographic verification failure (Scenario B).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName

Write-Host "Corrupting Demo Evidence Record..." -ForegroundColor Yellow

Set-Location "$ProjectRoot\apps\api"

# Use npx prisma db execute to corrupt a specific record
# Here we corrupt FS-2026-000001
$Query = "UPDATE evidence_records SET image_hash = 'corrupted-hash-00000000000000000000' FROM tests WHERE evidence_records.test_id = tests.id AND tests.test_number = 'FS-2026-000001';"

# Run prisma execute
npx prisma studio --help | Out-Null # Ensure prisma exists
Write-Host "Executing SQL..."
# Since Prisma db execute is in preview, we can just run a JS script.
$JsScript = @"
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const test = await prisma.test.findUnique({ where: { testNumber: 'FS-2026-000001' } });
  if (test) {
    await prisma.evidenceRecord.update({
      where: { testId: test.id },
      data: { recordHash: 'tampered-record-hash-demo-break' }
    });
    console.log('Evidence Record for FS-2026-000001 has been successfully corrupted.');
  } else {
    console.log('Test FS-2026-000001 not found.');
  }
}
main().finally(() => prisma.`$disconnect());
"@

$JsFile = "$ProjectRoot\apps\api\corrupt.js"
$JsScript | Out-File $JsFile -Encoding utf8

node $JsFile
Remove-Item $JsFile

Write-Host "Evidence corrupted! Now click 'Verify Evidence' on FS-2026-000001 in the app to see INTEGRITY_FAILED." -ForegroundColor Red
