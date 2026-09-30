// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'फील्डश्योर';

  @override
  String get appTagline => 'फील्ड ड्रग टेस्टिंग के लिए डिजिटल साथी';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonRetry => 'पुनः प्रयास करें';

  @override
  String get commonContinue => 'जारी रखें';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonDelete => 'हटाएं';

  @override
  String get authLogin => 'लॉगिन';

  @override
  String get authLogout => 'लॉगआउट';

  @override
  String get authEmail => 'ईमेल';

  @override
  String get authPassword => 'पासवर्ड';

  @override
  String get captureTitle => 'परीक्षण छवि कैप्चर करें';

  @override
  String get captureInstructions => 'फ्रेम के भीतर टेस्ट किट को रखें';

  @override
  String get captureButton => 'कैप्चर करें';

  @override
  String get captureRetake => 'फिर से लें';

  @override
  String get qualityCheckBlur => 'छवि बहुत धुंधली है';

  @override
  String get qualityCheckBlurGuidance =>
      'डिवाइस को स्थिर रखें और फिर से प्रयास करें';

  @override
  String get qualityCheckUnderexposed => 'छवि में कम रोशनी है';

  @override
  String get qualityCheckUnderexposedGuidance =>
      'बेहतर रोशनी में जाएं या फ्लैश का उपयोग करें';

  @override
  String get qualityCheckOverexposed => 'छवि में अधिक रोशनी है';

  @override
  String get qualityCheckOverexposedGuidance =>
      'छाया में जाएं या रोशनी कम करें';

  @override
  String get qualityCheckGlare => 'चमक का पता चला';

  @override
  String get qualityCheckGlareGuidance =>
      'प्रतिबिंब से बचने के लिए छाया में जाएं';

  @override
  String get qualityCheckPoorContrast => 'खराब कंट्रास्ट';

  @override
  String get qualityCheckPoorContrastGuidance =>
      'बेहतर कंट्रास्ट के लिए रोशनी समायोजित करें';

  @override
  String get resultPresumptiveLabel => 'अनुमानित परिणाम';

  @override
  String get resultDisclaimer =>
      'केवल अनुमानित परिणाम। सभी कलरमेट्रिक फील्ड टेस्ट परिणाम अनुमानित हैं और कानूनी कार्यवाही में उपयोग से पहले प्रयोगशाला विश्लेषण (GCMS, FTIR, या समकक्ष) द्वारा पुष्टि की जानी चाहिए।';

  @override
  String get resultPendingAnalysis => 'सर्वर विश्लेषण लंबित';

  @override
  String get resultConfidence => 'विश्वास';

  @override
  String get resultCandidateClasses => 'उम्मीदवार वर्ग';

  @override
  String get resultQualityFlags => 'गुणवत्ता झंडे';

  @override
  String get resultKitValidation => 'किट सत्यापन स्थिति';

  @override
  String get syncStatusSyncing => 'समन्वयन हो रहा है...';

  @override
  String get syncStatusSynced => 'समन्वयित';

  @override
  String get syncStatusPending => 'समन्वयन लंबित';

  @override
  String get syncStatusConflict => 'समन्वयन संघर्ष';

  @override
  String get syncStatusError => 'समन्वयन त्रुटि';

  @override
  String get conflictResolutionTitle => 'समन्वयन संघर्ष';

  @override
  String get conflictResolutionMessage =>
      'यह परीक्षण सर्वर पर संशोधित किया गया है। समाधान कैसे करें चुनें:';

  @override
  String get conflictKeepServer => 'सर्वर संस्करण रखें';

  @override
  String get conflictRetryLocal => 'स्थानीय परिवर्तन पुनः प्रयास करें';

  @override
  String get conflictDiscardLocal => 'स्थानीय परिवर्तन त्यागें';

  @override
  String get errorNetwork => 'नेटवर्क त्रुटि। कृपया अपना कनेक्शन जांचें।';

  @override
  String get errorUnauthorized =>
      'सत्र समाप्त हो गया। कृपया फिर से लॉगिन करें।';

  @override
  String get errorForbidden => 'इस क्रिया के लिए आपके पास अनुमति नहीं है।';

  @override
  String get errorNotFound => 'संसाधन नहीं मिला।';

  @override
  String get errorConflict =>
      'एक संघर्ष हुआ। कृपया रिफ्रेश करें और पुनः प्रयास करें।';

  @override
  String get errorServer => 'सर्वर त्रुटि। कृपया बाद में पुनः प्रयास करें।';

  @override
  String get errorUnknown => 'एक अप्रत्याशित त्रुटि हुई।';

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
