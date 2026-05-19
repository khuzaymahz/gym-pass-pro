import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  String get signInStep;
  String get signInHeadline1;
  String get signInHeadline2;
  String get signInHeadlineAccent;
  String get signInBlurb;
  String get signInOtpNote;
  String get signInContinueWithGoogle;
  String get signInPasswordLabel;
  String get signInPasswordHint;
  String get signInPasswordNote;
  String get signInWithPasswordCta;
  String get signInRememberMe;
  String get signInForgotPassword;
  String get signInCheckingNumber;
  String get errorPasswordInvalid;
  String get errorRequiredFields;
  String get errorInvalidInput;
  String get errorPasswordSignInRequired;
  String get errorOtpLocked;
  String get errorOtpInvalid;
  String get errorNetwork;
  String get orDivider;
  String get phoneCountryPrefix;
  String get phoneHint;
  String get errorPhoneRequired;
  String get errorPhoneInvalid;

  String get otpSentTo;
  String get otpResend;
  String otpResendIn(int seconds);
  String get otpDevHint;
  String get errorOtpIncomplete;
  String get otpStep;
  String get otpAlmostTitle;
  String get otpAlmostAccent;
  String otpSentToPhone(String phone);
  String get otpPhoneFallback;
  String get otpResendNow;
  String get otpResendBtn;

  String get registerStep;
  String get registerTitle;
  String get registerTitleAccent;
  String get registerBlurb;
  String get labelFirstName;
  String get labelLastName;
  String get labelEmail;
  String get labelPassword;
  String get labelPasswordConfirm;
  String get labelBirthdate;
  String get hintFirstName;
  String get hintLastName;
  String get hintEmail;
  String get hintBirthdate;
  String get birthdateHelpText;
  String get hintPassword;
  String get hintPasswordConfirm;
  String get agreementText;
  String get terms;
  String get and;
  String get privacyPolicy;
  String get createMyPass;
  String get errorFirstNameRequired;
  String get errorLastNameRequired;
  String errorNameTooShort(int min);
  String get errorEmailRequired;
  String get errorEmailInvalid;
  String get errorPasswordRequired;
  String get errorPasswordTooShort;
  String get errorPasswordWeak;
  String get errorPasswordMismatch;
  String get errorAgreementRequired;
  String get errorBirthdateRequired;
  String get labelGender;
  String get genderMale;
  String get genderFemale;
  String get errorGenderRequired;

  String get continueLabel;
  String get confirm;
  String get cancel;
  String get save;
  String get close;
  String get back;
  String get retry;
  String get seeAll;

  String homeGreetingName(String name);
  String get homeGreetingFallback;
  String get homeHeadlineLine1;
  String get homeHeadlineAccent;
  String get homeActive;
  String get homeVisits;
  String homeLeftThisCycle(int n);
  String homeCycleProgress(int cycle, int total, int days);
  String homeTermEndsIn(int days);
  String get homeManage;
  String get homeNoPlanOverline;
  String get homeNoPlanTitle;
  String get homeNoPlanBlurb;
  String get homeNoPlanCta;
  String get homeNearYou;
  String get homeNoGymsYet;
  String get homeOfflineNoCache;
  String get offlineBannerMessage;
  String get homeCategories;
  String get categoryGym;
  String get categoryCross;
  String get categoryMartial;
  String get categoryYoga;
  String clubsCount(int n);

  String get tabHome;
  String get tabGyms;
  String get tabExplore;
  String get exploreOverline;
  String get exploreViewProfile;
  String get exploreSearchHint;
  String exploreSearchEmpty(String query);
  String exploreCountStrip(int shown, int total);
  String exploreDistanceKm(String km);
  String exploreGymCount(int n);
  String get exploreOneGymCount;
  String get exploreSelectedGymHeader;
  String get exploreSelectedViewProfile;
  String exploreShowAllGyms(int n);
  String get exploreNoMatches;
  String get exploreFiltersTitle;
  String get exploreFiltersReset;
  String get exploreFiltersResetDone;
  String get exploreFiltersDone;
  String get exploreFiltersCategorySection;
  String get exploreFiltersTierSection;
  String get exploreFiltersFavoritesLabel;
  String get exploreLocateServiceDisabled;
  String get exploreLocatePermissionDenied;
  String get exploreLocatePermissionDeniedForever;
  String get exploreLocateOpenSettings;
  String get exploreLocateUnavailable;
  String get gymsCategoryAll;
  String get gymsCategoryGym;
  String get gymsCategoryCrossfit;
  String get gymsCategoryMartial;
  String get gymsCategoryYoga;
  String get tabScan;
  String get tabProfile;

  String get gymsTitle;
  String get gymsHeadline;
  String get gymsHeadlineAccent;
  String get gymsSearchHint;
  String get gymsFilterAll;
  String get gymsFilterGym;
  String get gymsFilterCrossfit;
  String get gymsFilterMartial;
  String get gymsFilterYoga;
  String get gymsEmpty;
  String get gymsEmptyFavorites;
  String get gymOpen247;
  String get audienceFemaleOnly;
  String get audienceMaleOnly;
  String gymKmAway(String km);
  String get gymAbout;
  String get gymAmenityWifi;
  String get gymAmenityParking;
  String get gymAmenityShowers;
  String get gymAmenityLockers;
  String get gymAmenityChangingRooms;
  String get gymAmenityTowels;
  String get gymAmenityWaterFountain;
  String get gymAmenityAc;
  String get gymAmenityFreeWeights;
  String get gymAmenityCardioMachines;
  String get gymAmenitySauna;
  String get gymAmenityPool;
  String get gymAmenitySteamRoom;
  String get gymAmenityGroupClasses;
  String get gymAmenityPersonalTraining;
  String get gymAmenityKidsArea;
  String get gymAmenityWomenOnlyArea;
  String get gymAmenityPrayerRoom;
  String get gymAmenityJuiceBar;
  String get gymAmenityWheelchairAccess;
  String get gymCheckInHere;
  String get gymCheckedInRecently;
  String gymUpgradeTo(String tier);
  String gymDayPassCta(String price);
  String gymDayPassActive(String when);
  String get dayPassSheetTitle;
  String get dayPassSheetLineItem;
  String dayPassSheetValidity(int hours);
  String dayPassSheetPay(String price);
  String get dayPassSheetPaying;
  String get dayPassSheetTerms;
  String get dayPassPurchasedSnack;
  String get currencyJod;
  String get profileDayPassesTitle;
  String get profileDayPassesEmpty;
  String profileDayPassExpiresIn(String duration);
  String profileDayPassUsed(String when);
  String durationHours(int count);
  String durationMinutes(int count);
  String get durationLessThanAMinute;
  String get durationExpired;
  String get gymAccessIncluded;
  String gymAccessRequiresTier(String tier);
  String gymDescriptionFallback(String area);

  String get checkinSuccess;
  String get checkinDemoButton;
  String get checkinLockedBannerTitle;
  String get checkinLockedBannerBody;
  String get checkinSeePlansCta;
  String get checkinCameraPermissionTitle;
  String get checkinCameraPermissionBody;
  String get checkinCameraOpenSettings;
  String get checkinCameraRetry;
  String get checkinCameraGenericError;
  String get checkinBackHome;
  String get checkinVisitGym;
  String get checkinSuccessTitle;
  String get checkinSuccessTitleAccent;

  String visitsRemaining(int count);

  String get tierSilver;
  String get tierGold;
  String get tierPlatinum;
  String get tierDiamond;
  List<String> tierFeatures(String tierKey);

  String get plansTitle;
  String get plansTitleAccent;
  String get plansOverline;
  String plansContinueWith(String tier);
  String plansSubscribeTo(String tier);
  String get plansSkipForNow;
  String get plansVisitsPerMonth;
  String get plansUnlimited;
  String get plansPerMonth;
  String get plansDurationHeading;
  String get plansDurationSwipeHint;
  String get plansDuration1Month;
  String get plansDuration3Months;
  String get plansDuration6Months;
  String get plansDuration12Months;
  String plansDurationSave(int percent);
  String plansDurationTotal(int amount);
  String plansVisitsIncluded(int count);
  String plansFeaturePauseSingle(int days);
  String plansFeaturePauseSplit(int days, int count);
  String get plansTapToExpand;
  String plansNetworkCount(int count);
  String plansStartsFrom(int amount);
  String plansDurationCardPerMonth(int amount);
  String plansNetworkSheetTitle(String tier);
  String get plansNetworkSheetBody;
  String get plansNetworkVisitsBadge;
  String get plansNetworkClose;
  String get plansNetworkEmpty;
  String get plansCurrentPlan;
  String get plansPickUpgrade;
  String plansScheduleDowngradeTo(String tier);
  String get plansCurrentPlanCta;
  String get plansCancelScheduledChange;
  String get plansScheduledBadge;
  String plansScheduledFor(String date);
  String get plansDowngradeConfirmTitle;
  String plansDowngradeConfirmBody(String tier, String date);
  String plansScheduledSnack(String tier, String date);
  String get plansScheduledCancelledSnack;
  String plansUpgradeTo(String tier);
  String get plansUpgradeConfirmTitle;
  String plansUpgradeConfirmBody(String tier, String duration);
  String plansSwitchPeriodTo(String duration);
  String get plansPeriodChangeConfirmTitle;
  String plansPeriodChangeConfirmBody(String duration, String date);
  String plansPeriodScheduledSnack(String duration, String date);
  String plansExtendTo(String duration);
  String get plansExtendConfirmTitle;
  String plansExtendConfirmBody(String duration, String renewDate);
  String plansExtendedSnack(String renewDate);
  // Unified switch CTA — replaces the previous schedule / upgrade / extend
  // trio. The destination is always /checkout, which routes through
  // backend cancel-then-buy on the way through.
  String plansSwitchToCta(String tier, String duration);
  String get plansSwitchConfirmTitle;
  String plansSwitchConfirmBody(String tier, String duration);

  String get checkoutTitle;
  String get checkoutTitleAccent;
  String get checkoutOverline;
  String checkoutPayAmount(int amount);
  String get checkoutPayingOverlay;
  String get checkoutOneMonth;
  String checkoutDurationSummary(int months);
  String get checkoutDurationYear;
  String checkoutDiscount(int percent);
  String get checkoutSubtotal;
  String get checkoutTax;
  String get checkoutTotal;
  String get checkoutPaymentMethod;
  String get checkoutNoMethodsHint;
  String get checkoutAddPaymentMethod;
  String get checkoutAddAnother;
  String get checkoutExtensionBadge;
  String get checkoutCurrentPlanCredit;
  String get checkoutExtensionRenewsOn;
  String get errorPaymentMethod;

  String get subscriptionTitle;
  String get subscriptionOverline;
  String get subscriptionTitleAccent;
  String subscriptionRenewsOn(String date);
  String subscriptionUpgradeTo(String tier);
  String get subscriptionChangePlan;
  String get subscriptionPerks;
  String get subscriptionEmptyOverline;
  String get subscriptionEmptyTitle;
  String get subscriptionEmptyBlurb;
  String get subscriptionEmptyCta;

  // Pause + early-renewal (on /subscription and /checkin)
  String get subscriptionPausedBadge;
  String get subscriptionPausedOverline;
  String get subscriptionPauseScheduledOverline;
  String subscriptionPausedBody(String untilIso);
  String subscriptionPauseScheduledBody(String fromIso, String untilIso);
  String get subscriptionPauseCta;
  String get subscriptionResumeCta;
  String get subscriptionPauseCancelCta;
  String get subscriptionResumeConfirmTitle;
  String get subscriptionResumeConfirmBody;
  String get subscriptionPauseCancelTitle;
  String get subscriptionPauseCancelBody;
  String get subscriptionResumedSnack;
  String subscriptionPausedNowSnack(String untilIso);
  String subscriptionPauseScheduledSnack(String fromIso);
  String get subscriptionPauseSheetTitle;
  String subscriptionPauseSheetBlurb(int days);
  String get subscriptionPauseRemainingLabel;
  String subscriptionPauseRemainingValue(int days);
  String get subscriptionPauseStartDateLabel;
  String get subscriptionPauseStartNow;
  String get subscriptionPauseDaysLabel;
  String subscriptionPauseSummary(String fromIso, String untilIso);
  String get subscriptionPauseStartSubmit;
  String get subscriptionVisitsExhaustedTitle;
  String get subscriptionVisitsExhaustedBody;
  String get subscriptionRenewNowCta;
  String get subscriptionRenewConfirmTitle;
  String get subscriptionRenewConfirmBody;
  String get subscriptionRenewedSnack;

  // Check-in pause nudge + visits-exhausted banner
  String get checkinPausedDialogTitle;
  String checkinPausedDialogBody(String gym, String untilIso);
  String get checkinPausedDialogResume;
  String get checkinPausedDialogKeep;
  String get checkinVisitsExhaustedBody;

  String get profileOverline;
  String get profileMemberSince;
  String get profileVisitsThisMo;
  String get profileStreak;
  String get profileThisMonth;
  String get profileNextTier;
  String get profileNextTierMaxed;
  String get profileNextTierEmpty;
  String get profileNoPlanChip;
  String profileStreakDays(int days);
  String get profileMenuSubscription;
  String get profileMenuFavorites;
  String get profileMenuNotifications;
  String get favoritesOverline;
  String get favoritesHeadline;
  String get favoritesHeadlineAccent;
  String get favoritesEmptyTitle;
  String get favoritesEmptyBody;
  String get favoritesEmptyCta;
  String get profileMenuBilling;
  String get profileMenuHelp;
  String get profileMenuSettings;
  String get profileMenuInvite;
  String get profileLogout;

  String get inviteOverline;
  String get inviteHeadline;
  String get inviteHeadlineAccent;
  String get inviteBlurb;
  String get inviteYourCode;
  String get inviteShareLink;
  String get inviteCopyCode;
  String get inviteShare;
  String get inviteCodeCopied;
  String get inviteLinkCopied;
  String get inviteCountsPending;
  String get inviteCountsConverted;
  String get inviteCountsExpired;
  String get inviteListTitle;
  String get inviteListEmpty;
  String get inviteStatusPending;
  String get inviteStatusConverted;
  String get inviteStatusExpired;
  String get inviteInvitedBy;
  String get inviteInvitedByNone;
  String get inviteClaimTitle;
  String get inviteClaimBlurb;
  String get inviteClaimInputLabel;
  String get inviteClaimInputHint;
  String get inviteClaimCta;
  String inviteClaimSuccess(String name);
  String get inviteClaimErrorInvalid;
  String get inviteClaimErrorNotFound;
  String get inviteClaimErrorOwnCode;
  String get inviteClaimErrorAlready;

  String get settingsTitle;
  String get settingsLanguage;
  String get settingsNotifications;
  String get settingsAccount;
  String get settingsLangArabic;
  String get settingsLangEnglish;
  String get settingsAppearance;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsNotifPlanReminders;
  String get settingsNotifNewClubs;
  String get settingsNotifPromos;
  String get settingsAccountEditProfile;
  String get settingsAccountSecurity;
  String get settingsAccountTerms;
  String get settingsAccountPrivacy;
  String get settingsAccountLogout;
  String get settingsAppVersion;

  String get notificationsOverline;
  String get notificationsEmpty;
  String get notificationsHeadline;
  String get notificationsHeadlineAccent;
  String get notificationsMarkAllRead;
  String get notifFilterAll;
  String get notifFilterUnread;
  String get notifFilterCheckin;
  String get notifFilterPromo;

  String get splashTagline;
  String get splashLoading;
  String get splashFooter;

  String get gymsMapPreview;

  String get checkinStepLabel;
  String get checkinAlignTitle;
  String get checkinAlignAccent;
  String get checkinAlignHintCaps;
  String get checkinFailedGeneric;

  String get checkinConfirmHintCaps;
  String get checkinConfirmEyebrow;
  String get checkinConfirmPrompt;
  String checkinConfirmCta(String gym);
  String get checkinCancelScan;
  String get checkinPassLabel;
  String get checkinPassEyebrow;
  String get checkinEntryDetailsLabel;
  String get checkinStatVisitsLeft;
  String get checkinStatDaysToRenewal;
  String get checkinStatThisTerm;
  String checkinLowVisitsWarning(int count);
  String get checkinViewPlans;

  String get welcomeOverline;
  String get welcomeYoureTitle;
  String get welcomeYoureAccent;
  String welcomeSubTier(String tier);
  String welcomeBlurbLong(String visits);
  String get welcomeFindGym;
  String get welcomeGoHome;

  String get subscriptionVisitLabelCaps;

  String get snackErrorGeneric;

  // Demo user (mock auth)
  String get demoUserName;
  String profileVisitsCount(int n);

  // Action sheets / dialogs / snackbars
  String get searchHintHome;
  String get favAddedMessage;
  String get favRemovedMessage;
  String get shareMessage;
  String get filterDialogTitle;
  String get filterApply;
  String get filterReset;
  String get filterDone;
  String filterMatchCount(int count);
  String get filterCategory;
  String get filterTier;
  String get googleSignInMock;
  String get googleMockEmail;
  String get editProfileTitle;
  String get editProfileSave;
  String get editProfileFirstName;
  String get editProfileLastName;
  String get editProfileEmail;
  String get editProfileSaved;
  String get helpTitle;
  String get helpContactSupport;
  String get helpFaq;
  String get helpReportIssue;
  String get securityTitle;
  String get securityChangePhone;
  String get securitySessions;
  String get termsTitle;
  String get termsBody;
  String get privacyPolicyBody;

  // Full-page legal documents: shared chrome + 10 sections each for
  // Terms and Privacy. The legacy `termsBody` / `privacyPolicyBody`
  // single-blob strings above are kept for any older surface that
  // still renders them; the new pages use the structured keys below.
  String get legalLastUpdated;
  String get legalReadTermsAction;
  String get legalReadPrivacyAction;
  String get legalSignupConsent;
  String get legalSignupConsentPrefix;

  String get termsSubtitle;
  String get termsUpdatedAt;
  String get termsAcceptanceHeadline;
  String get termsAcceptanceBody;
  String get termsAccountHeadline;
  String get termsAccountBody;
  String get termsMembershipHeadline;
  String get termsMembershipBody;
  String get termsPaymentHeadline;
  String get termsPaymentBody;
  String get termsCheckinHeadline;
  String get termsCheckinBody;
  String get termsConductHeadline;
  String get termsConductBody;
  String get termsTerminationHeadline;
  String get termsTerminationBody;
  String get termsLiabilityHeadline;
  String get termsLiabilityBody;
  String get termsChangesHeadline;
  String get termsChangesBody;
  String get termsContactHeadline;
  String get termsContactBody;

  String get privacyTitle;
  String get privacySubtitle;
  String get privacyUpdatedAt;
  String get privacyDataWeCollectHeadline;
  String get privacyDataWeCollectBody;
  String get privacyPurposeHeadline;
  String get privacyPurposeBody;
  String get privacySharingHeadline;
  String get privacySharingBody;
  String get privacyMaskingHeadline;
  String get privacyMaskingBody;
  String get privacyRetentionHeadline;
  String get privacyRetentionBody;
  String get privacySecurityHeadline;
  String get privacySecurityBody;
  String get privacyRightsHeadline;
  String get privacyRightsBody;
  String get privacyChildrenHeadline;
  String get privacyChildrenBody;
  String get privacyChangesHeadline;
  String get privacyChangesBody;
  String get privacyContactHeadline;
  String get privacyContactBody;
  String get logoutConfirmTitle;
  String get logoutConfirmBody;
  String get logoutConfirmYes;

  // Contact support
  String get supportOverline;
  String get supportHeadline;
  String get supportHeadlineAccent;
  String get supportBlurb;
  String get supportChannelsLabel;
  String get supportChannelCallTitle;
  String get supportChannelCallSubtitle;
  String get supportChannelEmailTitle;
  String get supportChannelEmailSubtitle;
  String get supportChannelWhatsappTitle;
  String get supportChannelWhatsappSubtitle;
  String get supportSupportPhone;
  String get supportMessageLabel;
  String get supportSubjectLabel;
  String get supportSubjectHint;
  String get supportBodyLabel;
  String get supportBodyHint;
  String get supportSendBtn;
  String get supportSentSnackbar;
  String get supportMissingFields;

  // FAQ
  String get faqOverline;
  String get faqHeadline;
  String get faqHeadlineAccent;
  String get faqBlurb;
  String get faqSearchHint;
  String get faqEmpty;
  String get faqContactFooter;
  String get faqContactCta;
  String get faqCategoryAll;
  String get faqCategoryGeneral;
  String get faqCategoryBilling;
  String get faqCategoryCheckin;
  String get faqCategoryClasses;
  String get faqQ1;
  String get faqA1;
  String get faqQ2;
  String get faqA2;
  String get faqQ3;
  String get faqA3;
  String get faqQ5;
  String get faqA5;
  String get faqQ6;
  String get faqA6;
  String get faqQ7;
  String get faqA7;
  String get faqQ8;
  String get faqA8;

  // Report an issue
  String get reportOverline;
  String get reportHeadline;
  String get reportHeadlineAccent;
  String get reportBlurb;
  String get reportCategoryLabel;
  String get reportCategoryCheckin;
  String get reportCategoryPayment;
  String get reportCategoryApp;
  String get reportCategoryAccount;
  String get reportCategoryOther;
  String get reportGymLabel;
  String get reportGymHint;
  String get reportDescLabel;
  String get reportDescHint;
  String get reportAttachLabel;
  String get reportAttachPlaceholder;
  String get reportAttachAttached;
  String get reportSubmitBtn;
  String get reportSubmittedTitle;
  String reportSubmittedBody(String ref);
  String get reportSubmittedClose;
  String get reportMissingFields;

  // Billing
  String get billingOverline;
  String get billingHeadline;
  String get billingHeadlineAccent;
  String get billingBlurb;
  String get billingMethodsLabel;
  String get billingMethodsEmpty;
  String get billingAddMethod;
  String get billingSetDefault;
  String get billingDefaultChip;
  String get billingRemoveMethod;
  String billingRemoveConfirmBody(String label);
  String get billingRemoveConfirmTitle;
  String get billingRemoveConfirmYes;
  String get billingAddTitle;
  String get billingAddCard;
  String get billingAddCliq;
  String get billingAddApple;
  String get billingAddGoogle;
  String get billingAddSaveBtn;
  String get billingAddCardSection;
  String get billingAddCliqSection;
  String get billingAddApplePaySection;
  String get billingAddGooglePaySection;
  String get billingAddCardNumberLabel;
  String get billingAddCardNumberHint;
  String get billingAddExpiryLabel;
  String get billingAddExpiryHint;
  String get billingAddCvvLabel;
  String get billingAddCvvHint;
  String get billingAddHolderLabel;
  String get billingAddHolderHint;
  String get billingAddCliqAliasLabel;
  String get billingAddCliqAliasHint;
  String get billingAddCliqPhoneLabel;
  String get billingAddCliqPhoneHint;
  String get billingAddCliqModeAlias;
  String get billingAddCliqModePhone;
  String get billingAddApplePayBlurb;
  String get billingAddApplePayConnect;
  String get billingAddApplePayConnecting;
  String get billingAddApplePayConnected;
  String get billingAddGooglePayBlurb;
  String get billingAddGooglePayConnect;
  String get billingAddGooglePayConnecting;
  String get billingAddGooglePayConnected;
  String get billingAddErrCardNumber;
  String get billingAddErrExpiry;
  String get billingAddErrCvv;
  String get billingAddErrHolder;
  String get billingAddErrCliq;
  String get billingAddErrApplePay;
  String get billingAddErrGooglePay;
  String get billingMethodAdded;
  String get billingMethodRemoved;
  String get billingDefaultUpdated;
  String get billingNextChargeLabel;
  String billingNextChargeBody(String date, int amount);
  String get billingHistoryLabel;
  String get billingHistoryEmpty;
  String billingInvoicePaid(String iso, int amount);
  String get billingInvoiceReceipt;
  String get billingCardNetworkVisa;
  String get billingCardNetworkMastercard;
  String get billingCardNetworkCliq;
  String get billingCardNetworkApple;
  String get billingCardNetworkGoogle;

  // Security
  String get securityBlurb;
  String get securityChangePhoneDesc;
  String get securitySessionsDesc;
  String get securityChangePhoneTitle;
  String get securityChangePhoneNewLabel;
  String get securityChangePhoneOtpNote;
  String get securityChangePhoneSubmit;
  String get securityChangePhoneSuccess;
  String get securityChangePhoneInvalid;
  String get securityChangePhoneOtpTitle;
  String securityChangePhoneOtpSubtitle(String phone);
  String get securityChangePhoneVerifyBtn;
  String get securityChangePhoneOtpError;
  String get securityChangePhoneInUse;
  String get securitySessionsTitle;
  String get securitySessionsThisDevice;
  String get securitySessionsActive;
  String get securitySessionsRevoke;
  String get securitySessionsRevoked;
  String get securitySessionsRevokeAll;
  String securitySessionsLastActive(String when);

  // Help landing
  String get helpOverline;
  String get helpHeadline;
  String get helpHeadlineAccent;
  String get helpBlurb;
  String get helpContactSupportDesc;
  String get helpFaqDesc;
  String get helpReportIssueDesc;

  // Support channel actions (added for E2E wiring)
  String get supportEmail;
  String get supportEmailDefaultSubject;
  String get supportWhatsapp;
  String supportChannelCopied(String value);
  String supportSentWithRef(String ref);
  String get supportSubmittedTitle;

  // Report attachment picker (added for E2E wiring)
  String get reportAttachPickerTitle;
  String get reportAttachCameraRoll;
  String get reportAttachPhoto;
  String get reportAttachRemove;
  String get reportAttachPickFailed;
  String get reportAttachCameraDenied;
  String get reportAttachGalleryDenied;

  // Billing receipt sheet (added for E2E wiring)
  String get billingReceiptTitle;
  String get billingReceiptItemsLabel;
  String get billingReceiptLineBase;
  String billingReceiptLineTax(int amount);
  String get billingReceiptTotalLabel;
  String get billingReceiptSendEmail;
  String get billingReceiptEmailQueued;
  String get billingReceiptDownload;
  String billingReceiptDownloadSubject(String id);
  String get billingReceiptCloseBtn;

  // Security change-phone (added for E2E wiring)
  String securityChangePhoneUpdated(String phone);

  // Forgot-password wizard
  String get forgotOverline;
  String get forgotTitle;
  String get forgotTitleAccent;
  String get forgotStep1;
  String get forgotStep2;
  String get forgotStep3;
  String get forgotBlurb1;
  String get forgotMethodSmsTitle;
  String forgotMethodSmsSubtitle(String phone);
  String get forgotMethodEmailTitle;
  String forgotMethodEmailSubtitle(String email);
  String get forgotMethodEmailMissing;
  String get forgotSendCode;
  String forgotCodeBlurb(String target);
  String get forgotResendCode;
  String get forgotVerifyCode;
  String get forgotNewPasswordBlurb;
  String get forgotSetNewPassword;
  String get forgotResetSuccess;
  String get forgotErrAccountMissing;
  String get forgotErrCodeInvalid;
  String get forgotDevHint;

  // Biometric sign-in
  String get securityBiometricTitle;
  String get securityBiometricDesc;
  String get securityBiometricNoPassword;
  String get securityBiometricUnavailable;
  String get biometricEnrollTitle;
  String biometricEnrollBlurb(String biometric);
  String get biometricEnrollPasswordLabel;
  String get biometricEnrollPasswordHint;
  String get biometricEnrollSubmit;
  String get biometricUnlockReason;
  String get biometricEnrollReason;
  String get biometricSignInBtn;
  String get biometricEnabled;
  String get biometricDisabled;
  String get biometricCancelled;
  String get biometricGenericLabel;
  String get billingNoSubscriptionTitle;
  String get billingNoSubscriptionBlurb;
  String get billingNoSubscriptionCta;
  String get gymNotFoundTitle;
  String gymNotFoundBody(String slug);
  String get gymNotFoundBackToExplore;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale".');
}
