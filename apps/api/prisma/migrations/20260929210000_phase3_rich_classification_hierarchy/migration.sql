-- FieldSure Phase 3: Rich Classification, Kit Versioning, Case/Sample, Review, Lab Confirmation, Org Hierarchy
-- Data preservation: existing caseId/sampleId strings converted to Case/Sample entities

-- ============================================================
-- New Enums
-- ============================================================

CREATE TYPE "KitValidationStatus" AS ENUM ('UNVALIDATED', 'PILOT', 'VALIDATED');
CREATE TYPE "CaseStatus" AS ENUM ('OPEN', 'CLOSED', 'ARCHIVED');
CREATE TYPE "CustodyAction" AS ENUM ('COLLECTED', 'TRANSFERRED', 'TESTED', 'SEALED', 'SUBMITTED_TO_LAB', 'RETURNED');
CREATE TYPE "LabMethod" AS ENUM ('GCMS', 'FTIR', 'LCMS', 'NMR', 'OTHER');
CREATE TYPE "ConfirmationOutcome" AS ENUM ('TRUE_POSITIVE', 'FALSE_POSITIVE', 'TRUE_NEGATIVE', 'FALSE_NEGATIVE', 'NOT_APPLICABLE');

-- Extend existing enums
ALTER TYPE "TestStatus" ADD VALUE 'REVIEWED_CONFIRMED';
ALTER TYPE "TestStatus" ADD VALUE 'REVIEWED_OVERRIDDEN';
ALTER TYPE "UserRole" ADD VALUE 'LAB_ANALYST';

-- Extend AuditEventType
ALTER TYPE "AuditEventType" ADD VALUE 'KIT_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'KIT_UPDATED';
ALTER TYPE "AuditEventType" ADD VALUE 'KIT_DEACTIVATED';
ALTER TYPE "AuditEventType" ADD VALUE 'KIT_VERSION_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'CASE_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'CASE_UPDATED';
ALTER TYPE "AuditEventType" ADD VALUE 'SAMPLE_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'SAMPLE_UPDATED';
ALTER TYPE "AuditEventType" ADD VALUE 'CUSTODY_EVENT_RECORDED';
ALTER TYPE "AuditEventType" ADD VALUE 'TEST_REVIEWED';
ALTER TYPE "AuditEventType" ADD VALUE 'LAB_CONFIRMATION_RECORDED';
ALTER TYPE "AuditEventType" ADD VALUE 'REAGENT_EXPIRED_OVERRIDE';
ALTER TYPE "AuditEventType" ADD VALUE 'READING_WINDOW_VIOLATION';
ALTER TYPE "AuditEventType" ADD VALUE 'ORG_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'ORG_UPDATED';
ALTER TYPE "AuditEventType" ADD VALUE 'UNIT_CREATED';
ALTER TYPE "AuditEventType" ADD VALUE 'UNIT_UPDATED';

-- ============================================================
-- Organization & OrgUnit
-- ============================================================

CREATE TABLE "organizations" (
    "id" UUID NOT NULL,
    "code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "organizations_code_key" ON "organizations"("code");

CREATE TABLE "org_units" (
    "id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "parent_unit_id" UUID,
    "code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "org_units_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "org_units_organization_id_code_key" ON "org_units"("organization_id", "code");
CREATE INDEX "org_units_organization_id_idx" ON "org_units"("organization_id");
CREATE INDEX "org_units_parent_unit_id_idx" ON "org_units"("parent_unit_id");

ALTER TABLE "org_units" ADD CONSTRAINT "org_units_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "org_units" ADD CONSTRAINT "org_units_parent_unit_id_fkey" FOREIGN KEY ("parent_unit_id") REFERENCES "org_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- Extend Users with Org/Unit membership
-- ============================================================

ALTER TABLE "users" ADD COLUMN "organization_id" UUID;
ALTER TABLE "users" ADD COLUMN "org_unit_id" UUID;

CREATE INDEX "users_organization_id_idx" ON "users"("organization_id");
CREATE INDEX "users_org_unit_id_idx" ON "users"("org_unit_id");

ALTER TABLE "users" ADD CONSTRAINT "users_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "users_org_unit_id_fkey" FOREIGN KEY ("org_unit_id") REFERENCES "org_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- Case & Sample (with data migration from existing tests)
-- ============================================================

CREATE TABLE "cases" (
    "id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "case_number" VARCHAR(100) NOT NULL,
    "title" VARCHAR(500) NOT NULL,
    "status" "CaseStatus" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "cases_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "cases_organization_id_case_number_key" ON "cases"("organization_id", "case_number");
CREATE INDEX "cases_organization_id_idx" ON "cases"("organization_id");

ALTER TABLE "cases" ADD CONSTRAINT "cases_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "samples" (
    "id" UUID NOT NULL,
    "case_id" UUID NOT NULL,
    "sample_number" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "seal_number" VARCHAR(100),
    "collected_at" TIMESTAMPTZ NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "samples_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "samples_case_id_sample_number_key" ON "samples"("case_id", "sample_number");
CREATE INDEX "samples_case_id_idx" ON "samples"("case_id");

ALTER TABLE "samples" ADD CONSTRAINT "samples_case_id_fkey" FOREIGN KEY ("case_id") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "custody_events" (
    "id" UUID NOT NULL,
    "sample_id" UUID NOT NULL,
    "from_user_id" UUID,
    "to_user_id" UUID,
    "action" "CustodyAction" NOT NULL,
    "note" TEXT,
    "location" VARCHAR(255),
    "timestamp" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "custody_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "custody_events_sample_id_idx" ON "custody_events"("sample_id");
CREATE INDEX "custody_events_timestamp_idx" ON "custody_events"("timestamp" DESC);

ALTER TABLE "custody_events" ADD CONSTRAINT "custody_events_sample_id_fkey" FOREIGN KEY ("sample_id") REFERENCES "samples"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "custody_events" ADD CONSTRAINT "custody_events_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "custody_events" ADD CONSTRAINT "custody_events_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- Extend TestKit with versioning
-- ============================================================

ALTER TABLE "test_kits" ADD COLUMN "cross_reactivity_notes" JSONB;
ALTER TABLE "test_kits" ADD COLUMN "validation_status" "KitValidationStatus" NOT NULL DEFAULT 'UNVALIDATED';

CREATE TABLE "kit_versions" (
    "id" UUID NOT NULL,
    "kit_id" UUID NOT NULL,
    "version" VARCHAR(50) NOT NULL,
    "reference_colors" JSONB NOT NULL,
    "reading_window" JSONB NOT NULL,
    "control_required" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kit_versions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "kit_versions_kit_id_version_key" ON "kit_versions"("kit_id", "version");
CREATE INDEX "kit_versions_kit_id_idx" ON "kit_versions"("kit_id");

ALTER TABLE "kit_versions" ADD CONSTRAINT "kit_versions_kit_id_fkey" FOREIGN KEY ("kit_id") REFERENCES "test_kits"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ============================================================
-- Extend Test with Phase 3 fields
-- ============================================================

-- Add new UUID columns for case/sample (will replace string columns)
ALTER TABLE "tests" ADD COLUMN "case_id_new" UUID;
ALTER TABLE "tests" ADD COLUMN "sample_id_new" UUID;
ALTER TABLE "tests" ADD COLUMN "client_reference" VARCHAR(100);
ALTER TABLE "tests" ADD COLUMN "org_unit_id" UUID;
ALTER TABLE "tests" ADD COLUMN "kit_version_id" UUID;
ALTER TABLE "tests" ADD COLUMN "control_test_id" UUID;
ALTER TABLE "tests" ADD COLUMN "reagent_lot" VARCHAR(100);
ALTER TABLE "tests" ADD COLUMN "reagent_expiry" TIMESTAMPTZ;
ALTER TABLE "tests" ADD COLUMN "reagent_added_at" TIMESTAMPTZ;
ALTER TABLE "tests" ADD COLUMN "ambient_temperature" DOUBLE PRECISION;
ALTER TABLE "tests" ADD COLUMN "expired_reagent_override" TEXT;

-- Indexes for new columns
CREATE INDEX "tests_org_unit_id_idx" ON "tests"("org_unit_id");
CREATE INDEX "tests_case_id_new_idx" ON "tests"("case_id_new");
CREATE INDEX "tests_sample_id_new_idx" ON "tests"("sample_id_new");
CREATE INDEX "tests_kit_version_id_idx" ON "tests"("kit_version_id");

-- Foreign keys (will be populated after data migration)
ALTER TABLE "tests" ADD CONSTRAINT "tests_org_unit_id_fkey" FOREIGN KEY ("org_unit_id") REFERENCES "org_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tests" ADD CONSTRAINT "tests_case_id_new_fkey" FOREIGN KEY ("case_id_new") REFERENCES "cases"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tests" ADD CONSTRAINT "tests_sample_id_new_fkey" FOREIGN KEY ("sample_id_new") REFERENCES "samples"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tests" ADD CONSTRAINT "tests_kit_version_id_fkey" FOREIGN KEY ("kit_version_id") REFERENCES "kit_versions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tests" ADD CONSTRAINT "tests_control_test_id_fkey" FOREIGN KEY ("control_test_id") REFERENCES "tests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- Data Migration: Convert existing caseId/sampleId strings to entities
-- Note: Requires a default organization (created if not exists)
-- ============================================================

-- Create default organization if none exists
INSERT INTO "organizations" ("id", "code", "name", "created_at", "updated_at")
SELECT gen_random_uuid(), 'DEFAULT', 'Default Organization', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM "organizations" LIMIT 1);

-- Migrate unique caseId strings to Case entities
INSERT INTO "cases" ("id", "organization_id", "case_number", "title", "status", "created_at", "updated_at")
SELECT 
    gen_random_uuid(),
    (SELECT "id" FROM "organizations" ORDER BY "created_at" LIMIT 1),
    COALESCE("case_id", 'UNKNOWN-' || gen_random_uuid()),
    'Migrated Case: ' || COALESCE("case_id", 'Unknown'),
    'OPEN',
    NOW(),
    NOW()
FROM "tests"
WHERE "case_id" IS NOT NULL
GROUP BY "case_id"
ON CONFLICT DO NOTHING;

-- Link tests to migrated cases
UPDATE "tests" t
SET "case_id_new" = c."id"
FROM "cases" c
WHERE t."case_id" = c."case_number"
AND c."organization_id" = (SELECT "id" FROM "organizations" ORDER BY "created_at" LIMIT 1);

-- Migrate unique sampleId strings to Sample entities (linked to their cases)
INSERT INTO "samples" ("id", "case_id", "sample_number", "description", "collected_at", "created_at", "updated_at")
SELECT DISTINCT ON (t."sample_id", c."id")
    gen_random_uuid(),
    c."id",
    COALESCE(t."sample_id", 'UNKNOWN-' || gen_random_uuid()),
    'Migrated sample',
    COALESCE(MIN(t."client_created_at"), NOW()),
    NOW(),
    NOW()
FROM "tests" t
LEFT JOIN "cases" c ON t."case_id_new" = c."id"
WHERE t."sample_id" IS NOT NULL
GROUP BY t."sample_id", c."id"
ON CONFLICT DO NOTHING;

-- Link tests to migrated samples
UPDATE "tests" t
SET "sample_id_new" = s."id"
FROM "samples" s
INNER JOIN "cases" c ON s."case_id" = c."id"
WHERE t."sample_id" = s."sample_number"
AND t."case_id_new" = c."id";

-- Drop old string columns and rename new UUID columns
ALTER TABLE "tests" DROP COLUMN "case_id";
ALTER TABLE "tests" DROP COLUMN "sample_id";
ALTER TABLE "tests" RENAME COLUMN "case_id_new" TO "case_id";
ALTER TABLE "tests" RENAME COLUMN "sample_id_new" TO "sample_id";

-- Drop old index and create new one
DROP INDEX IF EXISTS "tests_case_id_idx";
DROP INDEX IF EXISTS "tests_case_id_new_idx";
DROP INDEX IF EXISTS "tests_sample_id_new_idx";
CREATE INDEX "tests_case_id_idx" ON "tests"("case_id");
CREATE INDEX "tests_sample_id_idx" ON "tests"("sample_id");

-- ============================================================
-- Extend Classification with Phase 3 fields
-- ============================================================

ALTER TABLE "classifications" ADD COLUMN "presumptive_label" VARCHAR(100);
ALTER TABLE "classifications" ADD COLUMN "color_lab" JSONB;
ALTER TABLE "classifications" ADD COLUMN "delta_e" DOUBLE PRECISION;
ALTER TABLE "classifications" ADD COLUMN "candidate_classes" JSONB;
ALTER TABLE "classifications" ADD COLUMN "quality_flags" JSONB;
ALTER TABLE "classifications" ADD COLUMN "pipeline_id" VARCHAR(100);

-- ============================================================
-- Test Review
-- ============================================================

CREATE TABLE "test_reviews" (
    "id" UUID NOT NULL,
    "test_id" UUID NOT NULL,
    "reviewer_id" UUID NOT NULL,
    "decision" VARCHAR(50) NOT NULL,
    "reason" TEXT NOT NULL,
    "revised_label" VARCHAR(100),
    "reviewed_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "test_reviews_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "test_reviews_test_id_idx" ON "test_reviews"("test_id");
CREATE INDEX "test_reviews_reviewer_id_idx" ON "test_reviews"("reviewer_id");

ALTER TABLE "test_reviews" ADD CONSTRAINT "test_reviews_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "tests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "test_reviews" ADD CONSTRAINT "test_reviews_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ============================================================
-- Lab Confirmation
-- ============================================================

CREATE TABLE "lab_confirmations" (
    "id" UUID NOT NULL,
    "test_id" UUID NOT NULL,
    "confirmed_by_id" UUID NOT NULL,
    "method" "LabMethod" NOT NULL,
    "confirmed_substance" VARCHAR(255) NOT NULL,
    "lab_reference_number" VARCHAR(100) NOT NULL,
    "report_date" TIMESTAMPTZ NOT NULL,
    "report_file_path" VARCHAR(1024),
    "outcome" "ConfirmationOutcome" NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lab_confirmations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "lab_confirmations_test_id_key" ON "lab_confirmations"("test_id");
CREATE INDEX "lab_confirmations_outcome_idx" ON "lab_confirmations"("outcome");
CREATE INDEX "lab_confirmations_report_date_idx" ON "lab_confirmations"("report_date");

ALTER TABLE "lab_confirmations" ADD CONSTRAINT "lab_confirmations_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "tests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "lab_confirmations" ADD CONSTRAINT "lab_confirmations_confirmed_by_id_fkey" FOREIGN KEY ("confirmed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
