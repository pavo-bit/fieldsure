#!/bin/bash
# FieldSure Database Backup Script
# Performs pg_dump with compression and timestamp

set -euo pipefail

# Configuration from environment or defaults
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-fieldsure}"
DB_NAME="${POSTGRES_DB:-fieldsure}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/fieldsure_${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting database backup..."

# Perform backup with pg_dump
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_FILE"

# Check backup was created successfully
if [ -f "$BACKUP_FILE" ]; then
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "[$(date)] Backup completed: $BACKUP_FILE ($BACKUP_SIZE)"
  
  # Compute SHA-256 for integrity verification
  sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
  echo "[$(date)] Integrity hash: ${BACKUP_FILE}.sha256"
else
  echo "[$(date)] ERROR: Backup failed"
  exit 1
fi

# Clean up old backups (retention policy)
echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "fieldsure_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "fieldsure_*.sha256" -type f -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup complete"
