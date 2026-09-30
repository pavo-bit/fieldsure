/**
 * Legal disclaimers for presumptive field test results.
 * Must be included in all classification and evidence API responses.
 */
export const PRESUMPTIVE_RESULT_DISCLAIMER =
  'PRESUMPTIVE RESULT ONLY. All colorimetric field test results are presumptive and must be confirmed by laboratory analysis (GCMS, FTIR, or equivalent) before use in legal proceedings. False positives may occur due to cross-reactivity with common substances. This result does not constitute definitive identification.';

/**
 * Kit validation status disclaimer.
 * Shown when kit validationStatus is UNVALIDATED or PILOT.
 */
export const KIT_VALIDATION_DISCLAIMER = {
  UNVALIDATED:
    'WARNING: This test kit configuration has not been validated. Results should be treated as preliminary and used for investigative purposes only.',
  PILOT:
    'NOTICE: This test kit configuration is in pilot validation phase. Results require additional verification.',
};
