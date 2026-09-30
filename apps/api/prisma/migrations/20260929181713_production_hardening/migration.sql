-- Production hardening migration
-- Adds: tokenFamily, familySequence, rotatedAt to AuthSession
-- Adds: mustChangePassword, failedLoginAttempts, lockedUntil to User
-- Adds: requestId to AuditLog
-- Adds new audit event types

-- AlterTable: AuthSession
ALTER TABLE "auth_sessions" ADD COLUMN "token_family" UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE "auth_sessions" ADD COLUMN "family_sequence" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "auth_sessions" ADD COLUMN "rotated_at" TIMESTAMPTZ;

-- CreateIndex: AuthSession tokenFamily
CREATE INDEX "auth_sessions_token_family_idx" ON "auth_sessions"("token_family");

-- AlterTable: User
ALTER TABLE "users" ADD COLUMN "must_change_password" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "failed_login_attempts" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "locked_until" TIMESTAMPTZ;

-- AlterTable: AuditLog
ALTER TABLE "audit_logs" ADD COLUMN "request_id" VARCHAR(36);

-- Update enum: AuditEventType (add new values)
-- Note: PostgreSQL enums cannot be altered directly in a transaction, so we recreate
ALTER TYPE "AuditEventType" RENAME TO "AuditEventType_old";
CREATE TYPE "AuditEventType" AS ENUM (
  'LOGIN',
  'LOGIN_FAILED',
  'LOGOUT',
  'TOKEN_REFRESH',
  'TOKEN_FAMILY_COMPROMISED',
  'PASSWORD_CHANGED',
  'PASSWORD_RESET_FORCED',
  'ACCOUNT_LOCKED',
  'ACCOUNT_UNLOCKED',
  'USER_CREATED',
  'USER_UPDATED',
  'USER_DEACTIVATED',
  'TEST_CREATED',
  'IMAGE_CAPTURED',
  'IMAGE_UPLOADED',
  'IMAGE_HASHED',
  'PROCESSING_STARTED',
  'PROCESSING_COMPLETED',
  'CLASSIFICATION_CREATED',
  'EVIDENCE_SIGNED',
  'RECORD_VIEWED',
  'RECORD_VERIFIED',
  'RECORD_EXPORTED',
  'SYNC_STARTED',
  'SYNC_COMPLETED',
  'ERROR'
);
ALTER TABLE "audit_logs" ALTER COLUMN "event_type" TYPE "AuditEventType" USING ("event_type"::text::"AuditEventType");
DROP TYPE "AuditEventType_old";
