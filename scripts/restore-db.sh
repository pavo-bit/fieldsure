#!/bin/bash
# FieldSure Database Restore Script
# Restores from pg_dump backup with integrity verification

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup_file.sql.gz>"
  echo "Example: $0 ./backups/fieldsure_20260929_120000.sql.gz"
  exit 1
fi

BACKUP_FILE="$1"

# Configuration from environment or defaults
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-fieldsure}"
DB_NAME="${POSTGRES_DB:-fieldsure}"

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Verify integrity if SHA-256 hash exists
HASH_FILE="${BACKUP_FILE}.sha256"
if [ -f "$HASH_FILE" ]; then
  echo "[$(date)] Verifying backup integrity..."
  sha256sum --check "$HASH_FILE"
  if [ $? -ne 0 ]; then
    echo "ERROR: Backup integrity verification failed"
    exit 1
  fi
  echo "[$(date)] Integrity verification passed"
else
  echo "[$(date)] WARNING: No integrity hash found, skipping verification"
fi

# Confirmation prompt
echo "WARNING: This will restore database '$DB_NAME' from $BACKUP_FILE"
echo "All existing data will be REPLACED"
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

echo "[$(date)] Starting database restore..."

# Drop and recreate database
PGPASSWORD="$POSTGRES_PASSWORD" psql \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname=postgres \
  -c "DROP DATABASE IF EXISTS $DB_NAME;"

PGPASSWORD="$POSTGRES_PASSWORD" psql \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname=postgres \
  -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

# Restore from backup
PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --no-owner \
  --no-acl \
  "$BACKUP_FILE"

echo "[$(date)] Database restore completed"
echo "[$(date)] Running evidence chain verification..."

# Run evidence chain verification (if script exists)
VERIFY_SCRIPT="$(dirname "$0")/verify-evidence-chain.sh"
if [ -f "$VERIFY_SCRIPT" ]; then
  bash "$VERIFY_SCRIPT"
else
  echo "WARNING: Evidence chain verification script not found"
fi

echo "[$(date)] Restore complete"
