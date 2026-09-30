// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FieldSure';

  @override
  String get appTagline => 'Digital Companion for Field Drug Testing';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get authLogin => 'Login';

  @override
  String get authLogout => 'Logout';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get captureTitle => 'Capture Test Image';

  @override
  String get captureInstructions => 'Position the test kit within the frame';

  @override
  String get captureButton => 'Capture';

  @override
  String get captureRetake => 'Retake';

  @override
  String get qualityCheckBlur => 'Image is too blurry';

  @override
  String get qualityCheckBlurGuidance => 'Hold the device steady and try again';

  @override
  String get qualityCheckUnderexposed => 'Image is underexposed';

  @override
  String get qualityCheckUnderexposedGuidance =>
      'Move to better lighting or use flash';

  @override
  String get qualityCheckOverexposed => 'Image is overexposed';

  @override
  String get qualityCheckOverexposedGuidance =>
      'Move to shade or reduce lighting';

  @override
  String get qualityCheckGlare => 'Glare detected';

  @override
  String get qualityCheckGlareGuidance => 'Move to shade to avoid reflections';

  @override
  String get qualityCheckPoorContrast => 'Poor contrast';

  @override
  String get qualityCheckPoorContrastGuidance =>
      'Adjust lighting for better contrast';

  @override
  String get resultPresumptiveLabel => 'Presumptive Result';

  @override
  String get resultDisclaimer =>
      'PRESUMPTIVE RESULT ONLY. All colorimetric field test results are presumptive and must be confirmed by laboratory analysis (GCMS, FTIR, or equivalent) before use in legal proceedings.';

  @override
  String get resultPendingAnalysis => 'PENDING SERVER ANALYSIS';

  @override
  String get resultConfidence => 'Confidence';

  @override
  String get resultCandidateClasses => 'Candidate Classes';

  @override
  String get resultQualityFlags => 'Quality Flags';

  @override
  String get resultKitValidation => 'Kit Validation Status';

  @override
  String get syncStatusSyncing => 'Syncing...';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusPending => 'Pending Sync';

  @override
  String get syncStatusConflict => 'Sync Conflict';

  @override
  String get syncStatusError => 'Sync Error';

  @override
  String get conflictResolutionTitle => 'Sync Conflict';

  @override
  String get conflictResolutionMessage =>
      'This test has been modified on the server. Choose how to resolve:';

  @override
  String get conflictKeepServer => 'Keep Server Version';

  @override
  String get conflictRetryLocal => 'Retry Local Changes';

  @override
  String get conflictDiscardLocal => 'Discard Local Changes';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorUnauthorized => 'Session expired. Please login again.';

  @override
  String get errorForbidden => 'You don\'t have permission for this action.';

  @override
  String get errorNotFound => 'Resource not found.';

  @override
  String get errorConflict =>
      'A conflict occurred. Please refresh and try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorUnknown => 'An unexpected error occurred.';

  @override
  String get conflictWarning => 'Data conflict detected';

  @override
  String get operationDetails => 'Operation Details';

  @override
  String get operationType => 'Operation';

  @override
  String get entityType => 'Entity Type';

  @override
  String get entityId => 'Entity ID';

  @override
  String get attemptCount => 'Attempts';

  @override
  String get conflictDescription => 'Conflict Details';

  @override
  String get conflictExplanation =>
      'The server has different data than your local changes. Choose how to resolve this conflict.';

  @override
  String get chooseResolution => 'Choose Resolution';

  @override
  String get keepServerData => 'Keep Server Data';

  @override
  String get keepServerDescription =>
      'Discard local changes and use server data';

  @override
  String get retryLocalData => 'Retry Local Changes';

  @override
  String get retryLocalDescription => 'Try to send local changes again';

  @override
  String get discardLocalData => 'Discard Local Changes';

  @override
  String get discardLocalDescription =>
      'Permanently delete local changes with reason';

  @override
  String get discardReason => 'Reason for Discarding';

  @override
  String get discardReasonHint =>
      'Explain why you\'re discarding these changes';

  @override
  String get discardReasonHelper => 'Required for audit trail';

  @override
  String get cancel => 'Cancel';

  @override
  String get resolveConflict => 'Resolve Conflict';

  @override
  String get conflictResolved => 'Conflict resolved successfully';

  @override
  String get resolutionFailed => 'Resolution failed';

  @override
  String get testResult => 'Test Result';

  @override
  String get shareResult => 'Share Result';

  @override
  String get presumptiveResultTitle => 'PRESUMPTIVE RESULT ONLY';

  @override
  String get presumptiveResultWarning =>
      'This is a presumptive test result from on-device classification. Laboratory confirmation is required for legal proceedings.';

  @override
  String get confidence => 'Confidence';

  @override
  String get onDeviceClassification => 'On-Device Classification';

  @override
  String get candidateClasses => 'Candidate Classifications';

  @override
  String get qualityMetrics => 'Quality Metrics';

  @override
  String get deltaE => 'Color Delta E';

  @override
  String get blurScore => 'Blur Score';

  @override
  String get exposureScore => 'Exposure';

  @override
  String get qualityFlags => 'Quality Flags';

  @override
  String get qualityFlagBlur => 'Image appears blurred';

  @override
  String get qualityFlagUnderExposure => 'Image is underexposed';

  @override
  String get qualityFlagOverExposure => 'Image is overexposed';

  @override
  String get qualityFlagGlare => 'Excessive glare detected';

  @override
  String get qualityFlagRefCardMissing => 'Reference card not detected';

  @override
  String get qualityFlagRefCardSmall => 'Reference card too small';

  @override
  String get qualityFlagRefCardAngle => 'Reference card at incorrect angle';

  @override
  String get qualityFlagLowConfidence => 'Low confidence classification';

  @override
  String get kitValidation => 'Kit Validation';

  @override
  String get kitStatus => 'Status';

  @override
  String get validated => 'Validated';

  @override
  String get notValidated => 'Not Validated';

  @override
  String get lotNumber => 'Lot Number';

  @override
  String get expiryDate => 'Expiry Date';

  @override
  String get captureMetadata => 'Capture Metadata';

  @override
  String get capturedAt => 'Captured At';

  @override
  String get deviceId => 'Device ID';

  @override
  String get appVersion => 'App Version';

  @override
  String get gpsCoordinates => 'GPS Coordinates';

  @override
  String get chainOfCustody => 'Chain of Custody';

  @override
  String get requestLabConfirmation => 'Request Lab Confirmation';

  @override
  String get viewEvidencePackage => 'View Evidence Package';

  @override
  String get legalDisclaimer => 'Legal Disclaimer';

  @override
  String get presumptiveTestDisclaimer =>
      'This presumptive test result is for screening purposes only and is not admissible as definitive evidence in legal proceedings without laboratory confirmation.';

  @override
  String get labConfirmationRequired =>
      'Laboratory confirmation using GC-MS or equivalent analytical methods is required for legal proceedings.';

  @override
  String get shareNotImplemented => 'Share feature coming soon';

  @override
  String get selectCase => 'Select Case';

  @override
  String get caseLabel => 'Case';

  @override
  String get searchCases => 'Search cases...';

  @override
  String get newCase => 'New Case';

  @override
  String get noCasesFound => 'No cases found';

  @override
  String get tests => 'tests';

  @override
  String get featureComingSoon => 'This feature is coming soon';

  @override
  String get reviewQueue => 'Review Queue';

  @override
  String get pendingReview => 'Pending Review';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get reviewNotes => 'Review Notes';

  @override
  String get addNotes => 'Add notes...';

  @override
  String get submitReview => 'Submit Review';

  @override
  String get noItemsToReview => 'No items pending review';

  @override
  String get reviewSubmitted => 'Review submitted successfully';

  @override
  String get reviewFailed => 'Failed to submit review';
}
