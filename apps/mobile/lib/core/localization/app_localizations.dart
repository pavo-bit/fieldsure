import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'FieldSure'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Digital Companion for Field Drug Testing'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get authLogout;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @captureTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture Test Image'**
  String get captureTitle;

  /// No description provided for @captureInstructions.
  ///
  /// In en, this message translates to:
  /// **'Position the test kit within the frame'**
  String get captureInstructions;

  /// No description provided for @captureButton.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get captureButton;

  /// No description provided for @captureRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get captureRetake;

  /// No description provided for @qualityCheckBlur.
  ///
  /// In en, this message translates to:
  /// **'Image is too blurry'**
  String get qualityCheckBlur;

  /// No description provided for @qualityCheckBlurGuidance.
  ///
  /// In en, this message translates to:
  /// **'Hold the device steady and try again'**
  String get qualityCheckBlurGuidance;

  /// No description provided for @qualityCheckUnderexposed.
  ///
  /// In en, this message translates to:
  /// **'Image is underexposed'**
  String get qualityCheckUnderexposed;

  /// No description provided for @qualityCheckUnderexposedGuidance.
  ///
  /// In en, this message translates to:
  /// **'Move to better lighting or use flash'**
  String get qualityCheckUnderexposedGuidance;

  /// No description provided for @qualityCheckOverexposed.
  ///
  /// In en, this message translates to:
  /// **'Image is overexposed'**
  String get qualityCheckOverexposed;

  /// No description provided for @qualityCheckOverexposedGuidance.
  ///
  /// In en, this message translates to:
  /// **'Move to shade or reduce lighting'**
  String get qualityCheckOverexposedGuidance;

  /// No description provided for @qualityCheckGlare.
  ///
  /// In en, this message translates to:
  /// **'Glare detected'**
  String get qualityCheckGlare;

  /// No description provided for @qualityCheckGlareGuidance.
  ///
  /// In en, this message translates to:
  /// **'Move to shade to avoid reflections'**
  String get qualityCheckGlareGuidance;

  /// No description provided for @qualityCheckPoorContrast.
  ///
  /// In en, this message translates to:
  /// **'Poor contrast'**
  String get qualityCheckPoorContrast;

  /// No description provided for @qualityCheckPoorContrastGuidance.
  ///
  /// In en, this message translates to:
  /// **'Adjust lighting for better contrast'**
  String get qualityCheckPoorContrastGuidance;

  /// No description provided for @resultPresumptiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Presumptive Result'**
  String get resultPresumptiveLabel;

  /// No description provided for @resultDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'PRESUMPTIVE RESULT ONLY. All colorimetric field test results are presumptive and must be confirmed by laboratory analysis (GCMS, FTIR, or equivalent) before use in legal proceedings.'**
  String get resultDisclaimer;

  /// No description provided for @resultPendingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'PENDING SERVER ANALYSIS'**
  String get resultPendingAnalysis;

  /// No description provided for @resultConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get resultConfidence;

  /// No description provided for @resultCandidateClasses.
  ///
  /// In en, this message translates to:
  /// **'Candidate Classes'**
  String get resultCandidateClasses;

  /// No description provided for @resultQualityFlags.
  ///
  /// In en, this message translates to:
  /// **'Quality Flags'**
  String get resultQualityFlags;

  /// No description provided for @resultKitValidation.
  ///
  /// In en, this message translates to:
  /// **'Kit Validation Status'**
  String get resultKitValidation;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get syncStatusPending;

  /// No description provided for @syncStatusConflict.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get syncStatusConflict;

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get syncStatusError;

  /// No description provided for @conflictResolutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get conflictResolutionTitle;

  /// No description provided for @conflictResolutionMessage.
  ///
  /// In en, this message translates to:
  /// **'This test has been modified on the server. Choose how to resolve:'**
  String get conflictResolutionMessage;

  /// No description provided for @conflictKeepServer.
  ///
  /// In en, this message translates to:
  /// **'Keep Server Version'**
  String get conflictKeepServer;

  /// No description provided for @conflictRetryLocal.
  ///
  /// In en, this message translates to:
  /// **'Retry Local Changes'**
  String get conflictRetryLocal;

  /// No description provided for @conflictDiscardLocal.
  ///
  /// In en, this message translates to:
  /// **'Discard Local Changes'**
  String get conflictDiscardLocal;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Resource not found.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'A conflict occurred. Please refresh and try again.'**
  String get errorConflict;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorUnknown;

  /// No description provided for @conflictWarning.
  ///
  /// In en, this message translates to:
  /// **'Data conflict detected'**
  String get conflictWarning;

  /// No description provided for @operationDetails.
  ///
  /// In en, this message translates to:
  /// **'Operation Details'**
  String get operationDetails;

  /// No description provided for @operationType.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operationType;

  /// No description provided for @entityType.
  ///
  /// In en, this message translates to:
  /// **'Entity Type'**
  String get entityType;

  /// No description provided for @entityId.
  ///
  /// In en, this message translates to:
  /// **'Entity ID'**
  String get entityId;

  /// No description provided for @attemptCount.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get attemptCount;

  /// No description provided for @conflictDescription.
  ///
  /// In en, this message translates to:
  /// **'Conflict Details'**
  String get conflictDescription;

  /// No description provided for @conflictExplanation.
  ///
  /// In en, this message translates to:
  /// **'The server has different data than your local changes. Choose how to resolve this conflict.'**
  String get conflictExplanation;

  /// No description provided for @chooseResolution.
  ///
  /// In en, this message translates to:
  /// **'Choose Resolution'**
  String get chooseResolution;

  /// No description provided for @keepServerData.
  ///
  /// In en, this message translates to:
  /// **'Keep Server Data'**
  String get keepServerData;

  /// No description provided for @keepServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Discard local changes and use server data'**
  String get keepServerDescription;

  /// No description provided for @retryLocalData.
  ///
  /// In en, this message translates to:
  /// **'Retry Local Changes'**
  String get retryLocalData;

  /// No description provided for @retryLocalDescription.
  ///
  /// In en, this message translates to:
  /// **'Try to send local changes again'**
  String get retryLocalDescription;

  /// No description provided for @discardLocalData.
  ///
  /// In en, this message translates to:
  /// **'Discard Local Changes'**
  String get discardLocalData;

  /// No description provided for @discardLocalDescription.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete local changes with reason'**
  String get discardLocalDescription;

  /// No description provided for @discardReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for Discarding'**
  String get discardReason;

  /// No description provided for @discardReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain why you\'re discarding these changes'**
  String get discardReasonHint;

  /// No description provided for @discardReasonHelper.
  ///
  /// In en, this message translates to:
  /// **'Required for audit trail'**
  String get discardReasonHelper;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @resolveConflict.
  ///
  /// In en, this message translates to:
  /// **'Resolve Conflict'**
  String get resolveConflict;

  /// No description provided for @conflictResolved.
  ///
  /// In en, this message translates to:
  /// **'Conflict resolved successfully'**
  String get conflictResolved;

  /// No description provided for @resolutionFailed.
  ///
  /// In en, this message translates to:
  /// **'Resolution failed'**
  String get resolutionFailed;

  /// No description provided for @testResult.
  ///
  /// In en, this message translates to:
  /// **'Test Result'**
  String get testResult;

  /// No description provided for @shareResult.
  ///
  /// In en, this message translates to:
  /// **'Share Result'**
  String get shareResult;

  /// No description provided for @presumptiveResultTitle.
  ///
  /// In en, this message translates to:
  /// **'PRESUMPTIVE RESULT ONLY'**
  String get presumptiveResultTitle;

  /// No description provided for @presumptiveResultWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a presumptive test result from on-device classification. Laboratory confirmation is required for legal proceedings.'**
  String get presumptiveResultWarning;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @onDeviceClassification.
  ///
  /// In en, this message translates to:
  /// **'On-Device Classification'**
  String get onDeviceClassification;

  /// No description provided for @candidateClasses.
  ///
  /// In en, this message translates to:
  /// **'Candidate Classifications'**
  String get candidateClasses;

  /// No description provided for @qualityMetrics.
  ///
  /// In en, this message translates to:
  /// **'Quality Metrics'**
  String get qualityMetrics;

  /// No description provided for @deltaE.
  ///
  /// In en, this message translates to:
  /// **'Color Delta E'**
  String get deltaE;

  /// No description provided for @blurScore.
  ///
  /// In en, this message translates to:
  /// **'Blur Score'**
  String get blurScore;

  /// No description provided for @exposureScore.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get exposureScore;

  /// No description provided for @qualityFlags.
  ///
  /// In en, this message translates to:
  /// **'Quality Flags'**
  String get qualityFlags;

  /// No description provided for @qualityFlagBlur.
  ///
  /// In en, this message translates to:
  /// **'Image appears blurred'**
  String get qualityFlagBlur;

  /// No description provided for @qualityFlagUnderExposure.
  ///
  /// In en, this message translates to:
  /// **'Image is underexposed'**
  String get qualityFlagUnderExposure;

  /// No description provided for @qualityFlagOverExposure.
  ///
  /// In en, this message translates to:
  /// **'Image is overexposed'**
  String get qualityFlagOverExposure;

  /// No description provided for @qualityFlagGlare.
  ///
  /// In en, this message translates to:
  /// **'Excessive glare detected'**
  String get qualityFlagGlare;

  /// No description provided for @qualityFlagRefCardMissing.
  ///
  /// In en, this message translates to:
  /// **'Reference card not detected'**
  String get qualityFlagRefCardMissing;

  /// No description provided for @qualityFlagRefCardSmall.
  ///
  /// In en, this message translates to:
  /// **'Reference card too small'**
  String get qualityFlagRefCardSmall;

  /// No description provided for @qualityFlagRefCardAngle.
  ///
  /// In en, this message translates to:
  /// **'Reference card at incorrect angle'**
  String get qualityFlagRefCardAngle;

  /// No description provided for @qualityFlagLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Low confidence classification'**
  String get qualityFlagLowConfidence;

  /// No description provided for @kitValidation.
  ///
  /// In en, this message translates to:
  /// **'Kit Validation'**
  String get kitValidation;

  /// No description provided for @kitStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get kitStatus;

  /// No description provided for @validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get validated;

  /// No description provided for @notValidated.
  ///
  /// In en, this message translates to:
  /// **'Not Validated'**
  String get notValidated;

  /// No description provided for @lotNumber.
  ///
  /// In en, this message translates to:
  /// **'Lot Number'**
  String get lotNumber;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDate;

  /// No description provided for @captureMetadata.
  ///
  /// In en, this message translates to:
  /// **'Capture Metadata'**
  String get captureMetadata;

  /// No description provided for @capturedAt.
  ///
  /// In en, this message translates to:
  /// **'Captured At'**
  String get capturedAt;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceId;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @gpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get gpsCoordinates;

  /// No description provided for @chainOfCustody.
  ///
  /// In en, this message translates to:
  /// **'Chain of Custody'**
  String get chainOfCustody;

  /// No description provided for @requestLabConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Request Lab Confirmation'**
  String get requestLabConfirmation;

  /// No description provided for @viewEvidencePackage.
  ///
  /// In en, this message translates to:
  /// **'View Evidence Package'**
  String get viewEvidencePackage;

  /// No description provided for @legalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Legal Disclaimer'**
  String get legalDisclaimer;

  /// No description provided for @presumptiveTestDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This presumptive test result is for screening purposes only and is not admissible as definitive evidence in legal proceedings without laboratory confirmation.'**
  String get presumptiveTestDisclaimer;

  /// No description provided for @labConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Laboratory confirmation using GC-MS or equivalent analytical methods is required for legal proceedings.'**
  String get labConfirmationRequired;

  /// No description provided for @shareNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Share feature coming soon'**
  String get shareNotImplemented;

  /// No description provided for @selectCase.
  ///
  /// In en, this message translates to:
  /// **'Select Case'**
  String get selectCase;

  /// No description provided for @caseLabel.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get caseLabel;

  /// No description provided for @searchCases.
  ///
  /// In en, this message translates to:
  /// **'Search cases...'**
  String get searchCases;

  /// No description provided for @newCase.
  ///
  /// In en, this message translates to:
  /// **'New Case'**
  String get newCase;

  /// No description provided for @noCasesFound.
  ///
  /// In en, this message translates to:
  /// **'No cases found'**
  String get noCasesFound;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'tests'**
  String get tests;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon'**
  String get featureComingSoon;

  /// No description provided for @reviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Review Queue'**
  String get reviewQueue;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @reviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Review Notes'**
  String get reviewNotes;

  /// No description provided for @addNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes...'**
  String get addNotes;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @noItemsToReview.
  ///
  /// In en, this message translates to:
  /// **'No items pending review'**
  String get noItemsToReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully'**
  String get reviewSubmitted;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit review'**
  String get reviewFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
