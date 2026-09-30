-- CreateFunction
CREATE OR REPLACE FUNCTION prevent_finalized_test_modification()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow status transitions only through application state machine
  IF OLD.status IN ('FINALIZED', 'ARCHIVED') THEN
    -- Block ALL modifications to finalized/archived tests
    RAISE EXCEPTION 'Cannot modify test with status %. Use application state machine.', OLD.status
      USING ERRCODE = '23503'; -- foreign_key_violation for consistent error handling
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CreateTrigger
CREATE TRIGGER prevent_finalized_test_update
  BEFORE UPDATE ON "Test"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_finalized_test_modification();

-- CreateFunction
CREATE OR REPLACE FUNCTION prevent_finalized_test_deletion()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IN ('FINALIZED', 'ARCHIVED') THEN
    RAISE EXCEPTION 'Cannot delete test with status %. Tests must remain for audit trail.', OLD.status
      USING ERRCODE = '23503';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- CreateTrigger
CREATE TRIGGER prevent_finalized_test_delete
  BEFORE DELETE ON "Test"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_finalized_test_deletion();

-- CreateFunction
CREATE OR REPLACE FUNCTION prevent_evidence_modification()
RETURNS TRIGGER AS $$
DECLARE
  test_status TEXT;
BEGIN
  -- Check parent test status
  SELECT status INTO test_status FROM "Test" WHERE id = OLD."testId";
  
  IF test_status IN ('FINALIZED', 'ARCHIVED') THEN
    RAISE EXCEPTION 'Cannot modify evidence for test with status %', test_status
      USING ERRCODE = '23503';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CreateTrigger for EvidenceRecord
CREATE TRIGGER prevent_evidence_update
  BEFORE UPDATE ON "EvidenceRecord"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

CREATE TRIGGER prevent_evidence_delete
  BEFORE DELETE ON "EvidenceRecord"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

-- CreateTrigger for Classification (cannot modify if test finalized)
CREATE TRIGGER prevent_classification_update
  BEFORE UPDATE ON "Classification"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

CREATE TRIGGER prevent_classification_delete
  BEFORE DELETE ON "Classification"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

-- CreateTrigger for ImageAsset (cannot modify if test finalized)
CREATE TRIGGER prevent_image_asset_update
  BEFORE UPDATE ON "ImageAsset"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

CREATE TRIGGER prevent_image_asset_delete
  BEFORE DELETE ON "ImageAsset"
  FOR EACH ROW
  EXECUTE FUNCTION prevent_evidence_modification();

-- CreateFunction
CREATE OR REPLACE FUNCTION audit_evidence_access()
RETURNS TRIGGER AS $$
BEGIN
  -- Log all access to finalized evidence in audit log
  -- This is defensive - application should already be logging via AuditService
  INSERT INTO "AuditLog" (
    "eventType",
    "userId",
    "resourceType",
    "resourceId",
    "details",
    "timestamp"
  ) VALUES (
    'EVIDENCE_ACCESSED',
    current_user,
    TG_TABLE_NAME,
    NEW.id,
    jsonb_build_object('trigger', TG_OP, 'table', TG_TABLE_NAME),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CreateTrigger for evidence access logging
CREATE TRIGGER audit_evidence_record_access
  AFTER SELECT ON "EvidenceRecord"
  FOR EACH ROW
  EXECUTE FUNCTION audit_evidence_access();
