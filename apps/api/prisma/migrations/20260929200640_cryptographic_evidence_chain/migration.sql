-- FieldSure Phase 2: Cryptographic Evidence Chain Migration
-- Image assets, signing keys, hash chain, extended evidence records

-- Create SigningKeyStatus enum
CREATE TYPE "SigningKeyStatus" AS ENUM ('ACTIVE', 'RETIRED');

-- Create signing_keys table
CREATE TABLE "signing_keys" (
    "id" UUID NOT NULL,
    "kid" VARCHAR(50) NOT NULL,
    "algorithm" VARCHAR(50) NOT NULL,
    "public_key_pem" TEXT NOT NULL,
    "private_key_pem" TEXT,
    "status" "SigningKeyStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "retired_at" TIMESTAMPTZ,

    CONSTRAINT "signing_keys_pkey" PRIMARY KEY ("id")
);

-- Create unique index on kid
CREATE UNIQUE INDEX "signing_keys_kid_key" ON "signing_keys"("kid");

-- Create image_assets table
CREATE TABLE "image_assets" (
    "id" UUID NOT NULL,
    "test_id" UUID NOT NULL,
    "client_hash" VARCHAR(64) NOT NULL,
    "server_hash" VARCHAR(64) NOT NULL,
    "original_filename" VARCHAR(255) NOT NULL,
    "mime_type" VARCHAR(100) NOT NULL,
    "size_bytes" INTEGER NOT NULL,
    "capture_metadata" JSONB,
    "storage_backend" VARCHAR(20) NOT NULL,
    "storage_path" VARCHAR(1024) NOT NULL,
    "uploaded_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "image_assets_pkey" PRIMARY KEY ("id")
);

-- Create unique index on testId (one image per test)
CREATE UNIQUE INDEX "image_assets_test_id_key" ON "image_assets"("test_id");

-- Create index on serverHash for lookups
CREATE INDEX "image_assets_server_hash_idx" ON "image_assets"("server_hash");

-- Add foreign key constraint
ALTER TABLE "image_assets" ADD CONSTRAINT "image_assets_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "tests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Extend evidence_records table with Phase 2 fields
-- Note: We're adding columns, not recreating the table to preserve existing data

-- Add version column (default 2 for new records)
ALTER TABLE "evidence_records" ADD COLUMN "version" INTEGER NOT NULL DEFAULT 2;

-- Rename imageHash to serverImageHash for clarity
ALTER TABLE "evidence_records" RENAME COLUMN "image_hash" TO "server_image_hash";
ALTER TABLE "evidence_records" ALTER COLUMN "server_image_hash" TYPE VARCHAR(64);

-- Add clientImageHash (nullable for legacy records)
ALTER TABLE "evidence_records" ADD COLUMN "client_image_hash" VARCHAR(64);

-- Add capture metadata
ALTER TABLE "evidence_records" ADD COLUMN "capture_metadata" JSONB;

-- Add hash chain fields
ALTER TABLE "evidence_records" ADD COLUMN "previous_record_hash" VARCHAR(64);
ALTER TABLE "evidence_records" ADD COLUMN "chain_index" INTEGER NOT NULL DEFAULT 0;

-- Add timestamp token
ALTER TABLE "evidence_records" ADD COLUMN "timestamp_token" TEXT;

-- Create indexes for chain queries
CREATE INDEX "evidence_records_chain_index_idx" ON "evidence_records"("chain_index");
CREATE INDEX "evidence_records_signer_key_id_idx" ON "evidence_records"("signer_key_id");
CREATE INDEX "evidence_records_record_hash_idx" ON "evidence_records"("record_hash");

-- Add foreign key to signing_keys
ALTER TABLE "evidence_records" ADD CONSTRAINT "evidence_records_signer_key_id_fkey" FOREIGN KEY ("signer_key_id") REFERENCES "signing_keys"("kid") ON DELETE SET NULL ON UPDATE CASCADE;
