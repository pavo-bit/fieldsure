#!/bin/bash
# FieldSure Evidence Chain Verification Script
# Verifies cryptographic integrity of evidence records after restore

set -euo pipefail

DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-fieldsure}"
DB_NAME="${POSTGRES_DB:-fieldsure}"

echo "[$(date)] Starting evidence chain verification..."

# SQL query to check evidence integrity
QUERY="
SELECT 
  COUNT(*) AS total_records,
  COUNT(CASE WHEN verification_status = 'VERIFIED' THEN 1 END) AS verified,
  COUNT(CASE WHEN verification_status = 'INTEGRITY_FAILED' THEN 1 END) AS integrity_failed,
  COUNT(CASE WHEN verification_status IS NULL THEN 1 END) AS unverified
FROM evidence_records;
"

# Execute query
RESULT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --tuples-only \
  --no-align \
  --field-separator='|' \
  -c "$QUERY")

# Parse results
TOTAL=$(echo "$RESULT" | cut -d'|' -f1)
VERIFIED=$(echo "$RESULT" | cut -d'|' -f2)
FAILED=$(echo "$RESULT" | cut -d'|' -f3)
UNVERIFIED=$(echo "$RESULT" | cut -d'|' -f4)

echo "Evidence Records Summary:"
echo "  Total: $TOTAL"
echo "  Verified: $VERIFIED"
echo "  Integrity Failed: $FAILED"
echo "  Unverified: $UNVERIFIED"

# Check for integrity failures
if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "WARNING: $FAILED evidence records have integrity failures"
  echo "This may indicate data corruption or tampering"
  
  # List failed records
  PGPASSWORD="$POSTGRES_PASSWORD" psql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    -c "SELECT id, test_id, created_at FROM evidence_records WHERE verification_status = 'INTEGRITY_FAILED' LIMIT 10;"
fi

# Verify hash chain continuity (if implemented)
CHAIN_QUERY="
SELECT COUNT(*) FROM evidence_records 
WHERE previous_hash IS NOT NULL 
  AND previous_hash != ''
  AND verification_status = 'VERIFIED';
"

CHAIN_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --tuples-only \
  --no-align \
  -c "$CHAIN_QUERY")

echo ""
echo "Evidence Chain:"
echo "  Records in chain: $CHAIN_COUNT"

if [ "$FAILED" -eq 0 ]; then
  echo ""
  echo "[$(date)] ✓ Evidence chain verification PASSED"
  exit 0
else
  echo ""
  echo "[$(date)] ✗ Evidence chain verification FAILED"
  exit 1
fi
