// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'ফিল্ডশিওর';

  @override
  String get appTagline => 'ফিল্ড ড্রাগ টেস্টিংয়ের জন্য ডিজিটাল সহায়ক';

  @override
  String get commonCancel => 'বাতিল';

  @override
  String get commonConfirm => 'নিশ্চিত করুন';

  @override
  String get commonRetry => 'পুনরায় চেষ্টা করুন';

  @override
  String get commonContinue => 'চালিয়ে যান';

  @override
  String get commonSave => 'সংরক্ষণ করুন';

  @override
  String get commonDelete => 'মুছুন';

  @override
  String get authLogin => 'লগইন';

  @override
  String get authLogout => 'লগআউট';

  @override
  String get authEmail => 'ইমেইল';

  @override
  String get authPassword => 'পাসওয়ার্ড';

  @override
  String get captureTitle => 'পরীক্ষা ছবি ক্যাপচার করুন';

  @override
  String get captureInstructions => 'ফ্রেমের মধ্যে টেস্ট কিট রাখুন';

  @override
  String get captureButton => 'ক্যাপচার করুন';

  @override
  String get captureRetake => 'আবার নিন';

  @override
  String get qualityCheckBlur => 'ছবি খুব ঝাপসা';

  @override
  String get qualityCheckBlurGuidance =>
      'ডিভাইস স্থির রাখুন এবং আবার চেষ্টা করুন';

  @override
  String get qualityCheckUnderexposed => 'ছবিতে কম আলো';

  @override
  String get qualityCheckUnderexposedGuidance =>
      'ভাল আলোতে যান অথবা ফ্ল্যাশ ব্যবহার করুন';

  @override
  String get qualityCheckOverexposed => 'ছবিতে অতিরিক্ত আলো';

  @override
  String get qualityCheckOverexposedGuidance => 'ছায়ায় যান বা আলো কমান';

  @override
  String get qualityCheckGlare => 'চকচকে শনাক্ত হয়েছে';

  @override
  String get qualityCheckGlareGuidance => 'প্রতিফলন এড়াতে ছায়ায় যান';

  @override
  String get qualityCheckPoorContrast => 'দুর্বল বৈসাদৃশ্য';

  @override
  String get qualityCheckPoorContrastGuidance =>
      'ভাল বৈসাদৃশ্যের জন্য আলো সামঞ্জস্য করুন';

  @override
  String get resultPresumptiveLabel => 'অনুমানমূলক ফলাফল';

  @override
  String get resultDisclaimer =>
      'শুধুমাত্র অনুমানমূলক ফলাফল। সমস্ত কলরমেট্রিক ফিল্ড টেস্ট ফলাফল অনুমানমূলক এবং আইনি কার্যধারায় ব্যবহারের আগে অবশ্যই ল্যাবরেটরি বিশ্লেষণ (GCMS, FTIR, বা সমতুল্য) দ্বারা নিশ্চিত করা উচিত।';

  @override
  String get resultPendingAnalysis => 'সার্ভার বিশ্লেষণ মুলতুবি';

  @override
  String get resultConfidence => 'আত্মবিশ্বাস';

  @override
  String get resultCandidateClasses => 'প্রার্থী শ্রেণী';

  @override
  String get resultQualityFlags => 'গুণমান পতাকা';

  @override
  String get resultKitValidation => 'কিট বৈধতা অবস্থা';

  @override
  String get syncStatusSyncing => 'সিঙ্ক হচ্ছে...';

  @override
  String get syncStatusSynced => 'সিঙ্ক হয়েছে';

  @override
  String get syncStatusPending => 'সিঙ্ক মুলতুবি';

  @override
  String get syncStatusConflict => 'সিঙ্ক দ্বন্দ্ব';

  @override
  String get syncStatusError => 'সিঙ্ক ত্রুটি';

  @override
  String get conflictResolutionTitle => 'সিঙ্ক দ্বন্দ্ব';

  @override
  String get conflictResolutionMessage =>
      'এই পরীক্ষা সার্ভারে সংশোধন করা হয়েছে। সমাধান কিভাবে করবেন চয়ন করুন:';

  @override
  String get conflictKeepServer => 'সার্ভার সংস্করণ রাখুন';

  @override
  String get conflictRetryLocal => 'স্থানীয় পরিবর্তন পুনরায় চেষ্টা করুন';

  @override
  String get conflictDiscardLocal => 'স্থানীয় পরিবর্তন বাতিল করুন';

  @override
  String get errorNetwork =>
      'নেটওয়ার্ক ত্রুটি। অনুগ্রহ করে আপনার সংযোগ পরীক্ষা করুন।';

  @override
  String get errorUnauthorized =>
      'সেশন মেয়াদ শেষ। অনুগ্রহ করে আবার লগইন করুন।';

  @override
  String get errorForbidden => 'এই ক্রিয়ার জন্য আপনার অনুমতি নেই।';

  @override
  String get errorNotFound => 'সম্পদ পাওয়া যায়নি।';

  @override
  String get errorConflict =>
      'একটি দ্বন্দ্ব ঘটেছে। অনুগ্রহ করে রিফ্রেশ করুন এবং আবার চেষ্টা করুন।';

  @override
  String get errorServer => 'সার্ভার ত্রুটি। অনুগ্রহ করে পরে আবার চেষ্টা করুন।';

  @override
  String get errorUnknown => 'একটি অপ্রত্যাশিত ত্রুটি ঘটেছে।';

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
