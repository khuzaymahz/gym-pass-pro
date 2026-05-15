import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @signInStep.
  ///
  /// In en, this message translates to:
  /// **'Welcome — Step 1 of 3'**
  String get signInStep;

  /// No description provided for @signInHeadline1.
  ///
  /// In en, this message translates to:
  /// **'ONE PASS,'**
  String get signInHeadline1;

  /// No description provided for @signInHeadline2.
  ///
  /// In en, this message translates to:
  /// **'EVERY'**
  String get signInHeadline2;

  /// No description provided for @signInHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'gym.'**
  String get signInHeadlineAccent;

  /// No description provided for @signInBlurb.
  ///
  /// In en, this message translates to:
  /// **'Train anywhere in the network. One subscription. Unlocked by the QR at the door.'**
  String get signInBlurb;

  /// No description provided for @signInOtpNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text you a 4-digit code. No spam, ever.'**
  String get signInOtpNote;

  /// No description provided for @signInContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInContinueWithGoogle;

  /// No description provided for @signInPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get signInPasswordLabel;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get signInPasswordHint;

  /// No description provided for @signInPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Enter the password you set when you joined.'**
  String get signInPasswordNote;

  /// No description provided for @signInWithPasswordCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInWithPasswordCta;

  /// No description provided for @signInRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get signInRememberMe;

  /// No description provided for @signInForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// No description provided for @signInCheckingNumber.
  ///
  /// In en, this message translates to:
  /// **'Checking your number…'**
  String get signInCheckingNumber;

  /// No description provided for @errorPasswordInvalid.
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Try again.'**
  String get errorPasswordInvalid;

  /// No description provided for @errorRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all the required fields.'**
  String get errorRequiredFields;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Some fields look wrong. Check and try again.'**
  String get errorInvalidInput;

  /// No description provided for @errorPasswordSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get errorPasswordSignInRequired;

  /// No description provided for @errorOtpLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in 1 minute.'**
  String get errorOtpLocked;

  /// No description provided for @errorOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Try again.'**
  String get errorOtpInvalid;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @phoneCountryPrefix.
  ///
  /// In en, this message translates to:
  /// **'+962'**
  String get phoneCountryPrefix;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'7X XXX XXXX'**
  String get phoneHint;

  /// No description provided for @errorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get errorPhoneRequired;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid mobile number'**
  String get errorPhoneInvalid;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to'**
  String get otpSentTo;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpDevHint.
  ///
  /// In en, this message translates to:
  /// **'Dev mode: use 1234'**
  String get otpDevHint;

  /// No description provided for @errorOtpIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Please enter the full 4-digit code'**
  String get errorOtpIncomplete;

  /// No description provided for @registerStep.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3 — Profile'**
  String get registerStep;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'YOU\'RE'**
  String get registerTitle;

  /// No description provided for @registerTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'new.'**
  String get registerTitleAccent;

  /// No description provided for @registerBlurb.
  ///
  /// In en, this message translates to:
  /// **'Tell us your name and email so we can personalize your pass.'**
  String get registerBlurb;

  /// No description provided for @labelFirstName.
  ///
  /// In en, this message translates to:
  /// **'FIRST NAME'**
  String get labelFirstName;

  /// No description provided for @labelLastName.
  ///
  /// In en, this message translates to:
  /// **'LAST NAME'**
  String get labelLastName;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get labelEmail;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get labelPassword;

  /// No description provided for @labelPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get labelPasswordConfirm;

  /// No description provided for @labelBirthdate.
  ///
  /// In en, this message translates to:
  /// **'BIRTHDATE'**
  String get labelBirthdate;

  /// No description provided for @hintFirstName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Layla'**
  String get hintFirstName;

  /// No description provided for @hintLastName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Haddad'**
  String get hintLastName;

  /// No description provided for @hintEmail.
  ///
  /// In en, this message translates to:
  /// **'username@domain.com'**
  String get hintEmail;

  /// No description provided for @hintBirthdate.
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get hintBirthdate;

  /// No description provided for @birthdateHelpText.
  ///
  /// In en, this message translates to:
  /// **'Pick your date of birth'**
  String get birthdateHelpText;

  /// No description provided for @hintPassword.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get hintPassword;

  /// No description provided for @hintPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get hintPasswordConfirm;

  /// No description provided for @agreementText.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get agreementText;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'By using GymPass you agree to a single subscription that grants access to every gym in our partner network. Your tier (Silver, Gold, Platinum, Diamond) determines which gyms you can scan into and how many visits per cycle you have. Visits are counted at the moment of QR scan and reset on a 30-day rolling window from your subscription start date. We will not refund unused visits at the end of a cycle. You may cancel auto-renewal at any time and your subscription will remain active until the end of the current billing period. Misuse of the QR — including sharing your account or attempting to bypass tier gates — may result in suspension. We may update these terms with notice via the app. Continued use after a notice constitutes acceptance.'**
  String get termsBody;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'We collect only the data needed to operate your membership: your phone number, email, name, gender, birthdate, and a hashed password. Each successful check-in stores the gym, timestamp, and your subscription tier in our audit log so partner gyms can be paid correctly and so you can review your visit history. Your phone and email are never shared with partner gyms — they only see your tier and your name at check-in. We use a payment provider to process charges; payment card details never touch our servers. Location data is used only on-device to surface nearby gyms in Explore — we do not store your GPS history. You may request export or deletion of your data at any time from Settings → Privacy. We retain audit-log entries for 24 months for fraud-prevention and accounting; everything else is deleted on account closure within 30 days.'**
  String get privacyPolicyBody;

  /// No description provided for @createMyPass.
  ///
  /// In en, this message translates to:
  /// **'Create my pass'**
  String get createMyPass;

  /// No description provided for @errorFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get errorFirstNameRequired;

  /// No description provided for @errorLastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get errorLastNameRequired;

  /// No description provided for @errorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get errorEmailRequired;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get errorPasswordRequired;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get errorPasswordTooShort;

  /// No description provided for @errorPasswordWeak.
  ///
  /// In en, this message translates to:
  /// **'Password must include a letter and a number'**
  String get errorPasswordWeak;

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get errorPasswordMismatch;

  /// No description provided for @errorAgreementRequired.
  ///
  /// In en, this message translates to:
  /// **'You must agree to continue'**
  String get errorAgreementRequired;

  /// No description provided for @errorBirthdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please pick your birthdate'**
  String get errorBirthdateRequired;

  /// No description provided for @labelGender.
  ///
  /// In en, this message translates to:
  /// **'GENDER'**
  String get labelGender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @errorGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get errorGenderRequired;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @homeGreetingName.
  ///
  /// In en, this message translates to:
  /// **'{name},'**
  String homeGreetingName(String name);

  /// No description provided for @homeGreetingFallback.
  ///
  /// In en, this message translates to:
  /// **'THERE,'**
  String get homeGreetingFallback;

  /// No description provided for @homeHeadlineLine1.
  ///
  /// In en, this message translates to:
  /// **'LET\'S'**
  String get homeHeadlineLine1;

  /// No description provided for @homeHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'train.'**
  String get homeHeadlineAccent;

  /// No description provided for @homeActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get homeActive;

  /// No description provided for @homeVisits.
  ///
  /// In en, this message translates to:
  /// **'visits'**
  String get homeVisits;

  /// No description provided for @homeLeftThisCycle.
  ///
  /// In en, this message translates to:
  /// **'{n} LEFT THIS CYCLE'**
  String homeLeftThisCycle(int n);

  /// No description provided for @homeCycleProgress.
  ///
  /// In en, this message translates to:
  /// **'MONTH {cycle} OF {total} · CYCLE RESETS IN {days}D'**
  String homeCycleProgress(int cycle, int total, int days);

  /// No description provided for @homeTermEndsIn.
  ///
  /// In en, this message translates to:
  /// **'TERM RENEWS IN {days}D'**
  String homeTermEndsIn(int days);

  /// No description provided for @homeManage.
  ///
  /// In en, this message translates to:
  /// **'MANAGE'**
  String get homeManage;

  /// No description provided for @homeNoPlanOverline.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get homeNoPlanOverline;

  /// No description provided for @homeNoPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your pass'**
  String get homeNoPlanTitle;

  /// No description provided for @homeNoPlanBlurb.
  ///
  /// In en, this message translates to:
  /// **'Pick a tier to unlock gyms across the city. Your pass activates the moment checkout succeeds.'**
  String get homeNoPlanBlurb;

  /// No description provided for @homeNoPlanCta.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get homeNoPlanCta;

  /// No description provided for @homeNearYou.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get homeNearYou;

  /// No description provided for @homeNoGymsYet.
  ///
  /// In en, this message translates to:
  /// **'No partner gyms in the network yet. Pull to refresh.'**
  String get homeNoGymsYet;

  /// No description provided for @homeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategories;

  /// No description provided for @categoryGym.
  ///
  /// In en, this message translates to:
  /// **'GYM'**
  String get categoryGym;

  /// No description provided for @categoryCross.
  ///
  /// In en, this message translates to:
  /// **'CROSS'**
  String get categoryCross;

  /// No description provided for @categoryMartial.
  ///
  /// In en, this message translates to:
  /// **'MARTIAL'**
  String get categoryMartial;

  /// No description provided for @categoryYoga.
  ///
  /// In en, this message translates to:
  /// **'YOGA'**
  String get categoryYoga;

  /// No description provided for @clubsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No clubs} =1{1 club} other{{n} clubs}}'**
  String clubsCount(int n);

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabGyms.
  ///
  /// In en, this message translates to:
  /// **'Gyms'**
  String get tabGyms;

  /// No description provided for @tabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// No description provided for @exploreOverline.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreOverline;

  /// No description provided for @exploreViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get exploreViewProfile;

  /// No description provided for @exploreSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search gyms or areas'**
  String get exploreSearchHint;

  /// No description provided for @exploreSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gyms match \"{query}\".'**
  String exploreSearchEmpty(String query);

  /// No description provided for @exploreCountStrip.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} gyms match'**
  String exploreCountStrip(int shown, int total);

  /// No description provided for @exploreDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String exploreDistanceKm(String km);

  /// No description provided for @exploreGymCount.
  ///
  /// In en, this message translates to:
  /// **'{n} GYMS'**
  String exploreGymCount(int n);

  /// No description provided for @exploreOneGymCount.
  ///
  /// In en, this message translates to:
  /// **'1 GYM'**
  String get exploreOneGymCount;

  /// No description provided for @exploreSelectedGymHeader.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get exploreSelectedGymHeader;

  /// No description provided for @exploreSelectedViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get exploreSelectedViewProfile;

  /// No description provided for @exploreShowAllGyms.
  ///
  /// In en, this message translates to:
  /// **'SHOW ALL {n}'**
  String exploreShowAllGyms(int n);

  /// No description provided for @exploreNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No gyms match the current filters.'**
  String get exploreNoMatches;

  /// No description provided for @exploreFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exploreFiltersTitle;

  /// No description provided for @exploreFiltersReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get exploreFiltersReset;

  /// No description provided for @exploreFiltersDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get exploreFiltersDone;

  /// No description provided for @exploreFiltersCategorySection.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exploreFiltersCategorySection;

  /// No description provided for @exploreFiltersTierSection.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get exploreFiltersTierSection;

  /// No description provided for @exploreFiltersFavoritesLabel.
  ///
  /// In en, this message translates to:
  /// **'Show only favorites'**
  String get exploreFiltersFavoritesLabel;

  /// No description provided for @exploreLocateServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on Location Services in your device settings to locate yourself.'**
  String get exploreLocateServiceDisabled;

  /// No description provided for @exploreLocatePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to centre the map on you.'**
  String get exploreLocatePermissionDenied;

  /// No description provided for @exploreLocatePermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. Tap Settings to enable it.'**
  String get exploreLocatePermissionDeniedForever;

  /// No description provided for @exploreLocateOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get exploreLocateOpenSettings;

  /// No description provided for @exploreLocateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. Try again in a moment.'**
  String get exploreLocateUnavailable;

  /// No description provided for @gymsCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gymsCategoryAll;

  /// No description provided for @gymsCategoryGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gymsCategoryGym;

  /// No description provided for @gymsCategoryCrossfit.
  ///
  /// In en, this message translates to:
  /// **'CrossFit'**
  String get gymsCategoryCrossfit;

  /// No description provided for @gymsCategoryMartial.
  ///
  /// In en, this message translates to:
  /// **'Martial'**
  String get gymsCategoryMartial;

  /// No description provided for @gymsCategoryYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get gymsCategoryYoga;

  /// No description provided for @tabScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get tabScan;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @gymsTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse gyms'**
  String get gymsTitle;

  /// No description provided for @gymsHeadline.
  ///
  /// In en, this message translates to:
  /// **'EVERY'**
  String get gymsHeadline;

  /// No description provided for @gymsHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'club.'**
  String get gymsHeadlineAccent;

  /// No description provided for @gymsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or area'**
  String get gymsSearchHint;

  /// No description provided for @gymsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gymsFilterAll;

  /// No description provided for @gymsFilterGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gymsFilterGym;

  /// No description provided for @gymsFilterCrossfit.
  ///
  /// In en, this message translates to:
  /// **'CrossFit'**
  String get gymsFilterCrossfit;

  /// No description provided for @gymsFilterMartial.
  ///
  /// In en, this message translates to:
  /// **'Martial'**
  String get gymsFilterMartial;

  /// No description provided for @gymsFilterYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get gymsFilterYoga;

  /// No description provided for @gymsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching gyms'**
  String get gymsEmpty;

  /// No description provided for @gymsEmptyFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet — tap the heart on any club to save it here.'**
  String get gymsEmptyFavorites;

  /// No description provided for @gymOpen247.
  ///
  /// In en, this message translates to:
  /// **'OPEN 24/7'**
  String get gymOpen247;

  /// No description provided for @gymKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} KM'**
  String gymKmAway(String km);

  /// No description provided for @gymAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get gymAbout;

  /// No description provided for @gymAmenityWifi.
  ///
  /// In en, this message translates to:
  /// **'WI-FI'**
  String get gymAmenityWifi;

  /// No description provided for @gymAmenityParking.
  ///
  /// In en, this message translates to:
  /// **'PARKING'**
  String get gymAmenityParking;

  /// No description provided for @gymAmenityShowers.
  ///
  /// In en, this message translates to:
  /// **'SHOWERS'**
  String get gymAmenityShowers;

  /// No description provided for @gymAmenityLockers.
  ///
  /// In en, this message translates to:
  /// **'LOCKERS'**
  String get gymAmenityLockers;

  /// No description provided for @gymAmenityChangingRooms.
  ///
  /// In en, this message translates to:
  /// **'CHANGING'**
  String get gymAmenityChangingRooms;

  /// No description provided for @gymAmenityTowels.
  ///
  /// In en, this message translates to:
  /// **'TOWELS'**
  String get gymAmenityTowels;

  /// No description provided for @gymAmenityWaterFountain.
  ///
  /// In en, this message translates to:
  /// **'WATER'**
  String get gymAmenityWaterFountain;

  /// No description provided for @gymAmenityAc.
  ///
  /// In en, this message translates to:
  /// **'AIR CON'**
  String get gymAmenityAc;

  /// No description provided for @gymAmenityFreeWeights.
  ///
  /// In en, this message translates to:
  /// **'WEIGHTS'**
  String get gymAmenityFreeWeights;

  /// No description provided for @gymAmenityCardioMachines.
  ///
  /// In en, this message translates to:
  /// **'CARDIO'**
  String get gymAmenityCardioMachines;

  /// No description provided for @gymAmenitySauna.
  ///
  /// In en, this message translates to:
  /// **'SAUNA'**
  String get gymAmenitySauna;

  /// No description provided for @gymAmenityPool.
  ///
  /// In en, this message translates to:
  /// **'POOL'**
  String get gymAmenityPool;

  /// No description provided for @gymAmenitySteamRoom.
  ///
  /// In en, this message translates to:
  /// **'STEAM'**
  String get gymAmenitySteamRoom;

  /// No description provided for @gymAmenityGroupClasses.
  ///
  /// In en, this message translates to:
  /// **'CLASSES'**
  String get gymAmenityGroupClasses;

  /// No description provided for @gymAmenityPersonalTraining.
  ///
  /// In en, this message translates to:
  /// **'PT'**
  String get gymAmenityPersonalTraining;

  /// No description provided for @gymAmenityKidsArea.
  ///
  /// In en, this message translates to:
  /// **'KIDS'**
  String get gymAmenityKidsArea;

  /// No description provided for @gymAmenityWomenOnlyArea.
  ///
  /// In en, this message translates to:
  /// **'WOMEN'**
  String get gymAmenityWomenOnlyArea;

  /// No description provided for @gymAmenityPrayerRoom.
  ///
  /// In en, this message translates to:
  /// **'PRAYER'**
  String get gymAmenityPrayerRoom;

  /// No description provided for @gymAmenityJuiceBar.
  ///
  /// In en, this message translates to:
  /// **'JUICE BAR'**
  String get gymAmenityJuiceBar;

  /// No description provided for @gymAmenityWheelchairAccess.
  ///
  /// In en, this message translates to:
  /// **'ACCESS'**
  String get gymAmenityWheelchairAccess;

  /// No description provided for @gymCheckInHere.
  ///
  /// In en, this message translates to:
  /// **'Check in here'**
  String get gymCheckInHere;

  /// No description provided for @gymCheckedInRecently.
  ///
  /// In en, this message translates to:
  /// **'Checked in · pass active'**
  String get gymCheckedInRecently;

  /// No description provided for @gymUpgradeTo.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {tier}'**
  String gymUpgradeTo(String tier);

  /// No description provided for @gymAccessIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included in your plan'**
  String get gymAccessIncluded;

  /// No description provided for @gymAccessRequiresTier.
  ///
  /// In en, this message translates to:
  /// **'Requires {tier} tier'**
  String gymAccessRequiresTier(String tier);

  /// No description provided for @gymDescriptionFallback.
  ///
  /// In en, this message translates to:
  /// **'A serious training space in {area}. Modern equipment, climate-controlled, and 24/7 access for GymPass members.'**
  String gymDescriptionFallback(String area);

  /// No description provided for @checkinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in successful'**
  String get checkinSuccess;

  /// No description provided for @checkinDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Demo check-in'**
  String get checkinDemoButton;

  /// No description provided for @checkinLockedBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview mode'**
  String get checkinLockedBannerTitle;

  /// No description provided for @checkinLockedBannerBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have an active plan yet. Scanning a gym\'s QR will open its profile so you can preview access; check-ins unlock once you subscribe.'**
  String get checkinLockedBannerBody;

  /// No description provided for @checkinSeePlansCta.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get checkinSeePlansCta;

  /// No description provided for @checkinConfirmHintCaps.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM TO LOG YOUR VISIT'**
  String get checkinConfirmHintCaps;

  /// No description provided for @checkinConfirmEyebrow.
  ///
  /// In en, this message translates to:
  /// **'QR match'**
  String get checkinConfirmEyebrow;

  /// No description provided for @checkinConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'You\'re checking into'**
  String get checkinConfirmPrompt;

  /// No description provided for @checkinConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Check in to {gym}'**
  String checkinConfirmCta(String gym);

  /// No description provided for @checkinCancelScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a different QR'**
  String get checkinCancelScan;

  /// No description provided for @checkinPassLabel.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get checkinPassLabel;

  /// No description provided for @checkinPassEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get checkinPassEyebrow;

  /// No description provided for @checkinEntryDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry details'**
  String get checkinEntryDetailsLabel;

  /// No description provided for @checkinStatVisitsLeft.
  ///
  /// In en, this message translates to:
  /// **'Visits left'**
  String get checkinStatVisitsLeft;

  /// No description provided for @checkinStatDaysToRenewal.
  ///
  /// In en, this message translates to:
  /// **'Days to renewal'**
  String get checkinStatDaysToRenewal;

  /// No description provided for @checkinStatThisTerm.
  ///
  /// In en, this message translates to:
  /// **'This term'**
  String get checkinStatThisTerm;

  /// No description provided for @checkinLowVisitsWarning.
  ///
  /// In en, this message translates to:
  /// **'Only {count} visits left this term — renew before your next scan.'**
  String checkinLowVisitsWarning(int count);

  /// No description provided for @checkinViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get checkinViewPlans;

  /// No description provided for @checkinBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get checkinBackHome;

  /// No description provided for @checkinVisitGym.
  ///
  /// In en, this message translates to:
  /// **'View gym'**
  String get checkinVisitGym;

  /// No description provided for @checkinSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'YOU\'RE'**
  String get checkinSuccessTitle;

  /// No description provided for @checkinSuccessTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'in.'**
  String get checkinSuccessTitleAccent;

  /// No description provided for @visitsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No visits left} =1{1 visit left} other{{count} visits left}}'**
  String visitsRemaining(int count);

  /// No description provided for @tierSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get tierSilver;

  /// No description provided for @tierGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get tierGold;

  /// No description provided for @tierPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get tierPlatinum;

  /// No description provided for @tierDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get tierDiamond;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE'**
  String get plansTitle;

  /// No description provided for @plansTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'your tier.'**
  String get plansTitleAccent;

  /// No description provided for @plansOverline.
  ///
  /// In en, this message translates to:
  /// **'Pick your pass'**
  String get plansOverline;

  /// No description provided for @plansContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with {tier}'**
  String plansContinueWith(String tier);

  /// No description provided for @plansSubscribeTo.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {tier}'**
  String plansSubscribeTo(String tier);

  /// No description provided for @plansSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get plansSkipForNow;

  /// No description provided for @plansVisitsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'VISITS/MO'**
  String get plansVisitsPerMonth;

  /// No description provided for @plansUnlimited.
  ///
  /// In en, this message translates to:
  /// **'UNLIMITED'**
  String get plansUnlimited;

  /// No description provided for @plansPerMonth.
  ///
  /// In en, this message translates to:
  /// **'JOD/MO'**
  String get plansPerMonth;

  /// No description provided for @plansDurationHeading.
  ///
  /// In en, this message translates to:
  /// **'COMMIT FOR'**
  String get plansDurationHeading;

  /// No description provided for @plansDurationSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'SWIPE FOR 1 YEAR'**
  String get plansDurationSwipeHint;

  /// No description provided for @plansDuration1Month.
  ///
  /// In en, this message translates to:
  /// **'1 MONTH'**
  String get plansDuration1Month;

  /// No description provided for @plansDuration3Months.
  ///
  /// In en, this message translates to:
  /// **'3 MONTHS'**
  String get plansDuration3Months;

  /// No description provided for @plansDuration6Months.
  ///
  /// In en, this message translates to:
  /// **'6 MONTHS'**
  String get plansDuration6Months;

  /// No description provided for @plansDuration12Months.
  ///
  /// In en, this message translates to:
  /// **'1 YEAR'**
  String get plansDuration12Months;

  /// No description provided for @plansDurationSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE {percent}%'**
  String plansDurationSave(int percent);

  /// No description provided for @plansDurationTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} JOD total'**
  String plansDurationTotal(int amount);

  /// No description provided for @plansVisitsIncluded.
  ///
  /// In en, this message translates to:
  /// **'{count} visits included'**
  String plansVisitsIncluded(int count);

  /// No description provided for @plansFeaturePauseSingle.
  ///
  /// In en, this message translates to:
  /// **'Freeze your plan for up to {days} days, in one block'**
  String plansFeaturePauseSingle(int days);

  /// No description provided for @plansFeaturePauseSplit.
  ///
  /// In en, this message translates to:
  /// **'Freeze your plan {count} times per term, up to {days} days total'**
  String plansFeaturePauseSplit(int days, int count);

  /// No description provided for @plansTapToExpand.
  ///
  /// In en, this message translates to:
  /// **'TAP TO EXPAND'**
  String get plansTapToExpand;

  /// No description provided for @plansNetworkCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} GYMS'**
  String plansNetworkCount(int count);

  /// No description provided for @plansStartsFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM {amount} JOD/MO'**
  String plansStartsFrom(int amount);

  /// No description provided for @plansDurationCardPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount}/MO'**
  String plansDurationCardPerMonth(int amount);

  /// No description provided for @plansNetworkSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{tier} plan network'**
  String plansNetworkSheetTitle(String tier);

  /// No description provided for @plansNetworkSheetBody.
  ///
  /// In en, this message translates to:
  /// **'One QR scan per gym per day. Your 30 monthly visits work across the entire network.'**
  String get plansNetworkSheetBody;

  /// No description provided for @plansNetworkVisitsBadge.
  ///
  /// In en, this message translates to:
  /// **'30/MO'**
  String get plansNetworkVisitsBadge;

  /// No description provided for @plansNetworkClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get plansNetworkClose;

  /// No description provided for @plansNetworkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Network partners rolling out soon.'**
  String get plansNetworkEmpty;

  /// No description provided for @plansCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAN'**
  String get plansCurrentPlan;

  /// No description provided for @plansPickUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Pick a higher tier'**
  String get plansPickUpgrade;

  /// No description provided for @plansScheduleDowngradeTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {tier} at renewal'**
  String plansScheduleDowngradeTo(Object tier);

  /// No description provided for @plansCurrentPlanCta.
  ///
  /// In en, this message translates to:
  /// **'This is your current plan'**
  String get plansCurrentPlanCta;

  /// No description provided for @plansCancelScheduledChange.
  ///
  /// In en, this message translates to:
  /// **'Cancel scheduled switch'**
  String get plansCancelScheduledChange;

  /// No description provided for @plansScheduledBadge.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULED'**
  String get plansScheduledBadge;

  /// No description provided for @plansScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Switches {date}'**
  String plansScheduledFor(Object date);

  /// No description provided for @plansDowngradeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule downgrade?'**
  String get plansDowngradeConfirmTitle;

  /// No description provided for @plansDowngradeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll keep your current benefits until {date}. On renewal, your plan switches to {tier} and billing adjusts accordingly.'**
  String plansDowngradeConfirmBody(Object date, Object tier);

  /// No description provided for @plansScheduledSnack.
  ///
  /// In en, this message translates to:
  /// **'Scheduled switch to {tier} on {date}.'**
  String plansScheduledSnack(Object date, Object tier);

  /// No description provided for @plansScheduledCancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'Scheduled switch cancelled.'**
  String get plansScheduledCancelledSnack;

  /// No description provided for @plansUpgradeTo.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {tier}'**
  String plansUpgradeTo(String tier);

  /// No description provided for @plansUpgradeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm upgrade?'**
  String get plansUpgradeConfirmTitle;

  /// No description provided for @plansUpgradeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re upgrading to {tier} for {duration}. The new tier unlocks at your next check-in and a fresh billing period starts today.'**
  String plansUpgradeConfirmBody(String tier, String duration);

  /// No description provided for @plansSwitchPeriodTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {duration} at renewal'**
  String plansSwitchPeriodTo(String duration);

  /// No description provided for @plansPeriodChangeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule period change?'**
  String get plansPeriodChangeConfirmTitle;

  /// No description provided for @plansPeriodChangeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your current plan runs until {date}. On renewal, your commitment switches to {duration} and billing adjusts to match.'**
  String plansPeriodChangeConfirmBody(String duration, String date);

  /// No description provided for @plansPeriodScheduledSnack.
  ///
  /// In en, this message translates to:
  /// **'Switching to {duration} on {date}.'**
  String plansPeriodScheduledSnack(String duration, String date);

  /// No description provided for @plansExtendTo.
  ///
  /// In en, this message translates to:
  /// **'Extend to {duration}'**
  String plansExtendTo(String duration);

  /// No description provided for @plansExtendConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Extend your plan?'**
  String get plansExtendConfirmTitle;

  /// No description provided for @plansExtendConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Lock in {duration} now — you only pay the difference. Your next renewal shifts to {renewDate} and visits already used this term carry over.'**
  String plansExtendConfirmBody(String duration, String renewDate);

  /// No description provided for @plansExtendedSnack.
  ///
  /// In en, this message translates to:
  /// **'Plan extended — renews {renewDate}.'**
  String plansExtendedSnack(String renewDate);

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get checkoutTitle;

  /// No description provided for @checkoutTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'& pay.'**
  String get checkoutTitleAccent;

  /// No description provided for @checkoutOverline.
  ///
  /// In en, this message translates to:
  /// **'Secure checkout'**
  String get checkoutOverline;

  /// No description provided for @checkoutPayAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} JOD'**
  String checkoutPayAmount(int amount);

  /// No description provided for @checkoutPayingOverlay.
  ///
  /// In en, this message translates to:
  /// **'PROCESSING PAYMENT'**
  String get checkoutPayingOverlay;

  /// No description provided for @checkoutOneMonth.
  ///
  /// In en, this message translates to:
  /// **'1-MONTH'**
  String get checkoutOneMonth;

  /// No description provided for @checkoutDurationSummary.
  ///
  /// In en, this message translates to:
  /// **'{months}-MONTH'**
  String checkoutDurationSummary(int months);

  /// No description provided for @checkoutDurationYear.
  ///
  /// In en, this message translates to:
  /// **'1-YEAR'**
  String get checkoutDurationYear;

  /// No description provided for @checkoutDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount ({percent}%)'**
  String checkoutDiscount(int percent);

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutTax.
  ///
  /// In en, this message translates to:
  /// **'Tax (16%)'**
  String get checkoutTax;

  /// No description provided for @checkoutTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get checkoutTotal;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHOD'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutNoMethodsHint.
  ///
  /// In en, this message translates to:
  /// **'No payment method on file. Add one to continue.'**
  String get checkoutNoMethodsHint;

  /// No description provided for @checkoutAddPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get checkoutAddPaymentMethod;

  /// No description provided for @checkoutAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get checkoutAddAnother;

  /// No description provided for @checkoutExtensionBadge.
  ///
  /// In en, this message translates to:
  /// **'EXTENSION'**
  String get checkoutExtensionBadge;

  /// No description provided for @checkoutCurrentPlanCredit.
  ///
  /// In en, this message translates to:
  /// **'Current plan credit'**
  String get checkoutCurrentPlanCredit;

  /// No description provided for @checkoutExtensionRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'NEW RENEWAL'**
  String get checkoutExtensionRenewsOn;

  /// No description provided for @errorPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment method'**
  String get errorPaymentMethod;

  /// No description provided for @welcomeBlurbLong.
  ///
  /// In en, this message translates to:
  /// **'Your pass is active. {visits} visits await across every partnered gym in the network.'**
  String welcomeBlurbLong(String visits);

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionOverline.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get subscriptionOverline;

  /// No description provided for @subscriptionTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'plan.'**
  String get subscriptionTitleAccent;

  /// No description provided for @subscriptionRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE · RENEWS {date}'**
  String subscriptionRenewsOn(String date);

  /// No description provided for @subscriptionUpgradeTo.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {tier}'**
  String subscriptionUpgradeTo(String tier);

  /// No description provided for @subscriptionChangePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get subscriptionChangePlan;

  /// No description provided for @subscriptionPerks.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU GET'**
  String get subscriptionPerks;

  /// No description provided for @subscriptionEmptyOverline.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get subscriptionEmptyOverline;

  /// No description provided for @subscriptionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your pass'**
  String get subscriptionEmptyTitle;

  /// No description provided for @subscriptionEmptyBlurb.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t picked a tier. Browse the plans and subscribe to unlock every partner gym in the city.'**
  String get subscriptionEmptyBlurb;

  /// No description provided for @subscriptionEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Browse plans'**
  String get subscriptionEmptyCta;

  /// No description provided for @profileOverline.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileOverline;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'MEMBER SINCE MAR'**
  String get profileMemberSince;

  /// No description provided for @profileVisitsThisMo.
  ///
  /// In en, this message translates to:
  /// **'VISITS THIS MO'**
  String get profileVisitsThisMo;

  /// No description provided for @profileStreak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get profileStreak;

  /// No description provided for @profileThisMonth.
  ///
  /// In en, this message translates to:
  /// **'THIS MONTH'**
  String get profileThisMonth;

  /// No description provided for @profileNextTier.
  ///
  /// In en, this message translates to:
  /// **'NEXT TIER'**
  String get profileNextTier;

  /// No description provided for @profileNextTierEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO PLAN'**
  String get profileNextTierEmpty;

  /// No description provided for @profileNoPlanChip.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get profileNoPlanChip;

  /// No description provided for @profileMenuSubscription.
  ///
  /// In en, this message translates to:
  /// **'My subscription'**
  String get profileMenuSubscription;

  /// No description provided for @profileMenuFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorite gyms'**
  String get profileMenuFavorites;

  /// No description provided for @profileMenuNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileMenuNotifications;

  /// No description provided for @favoritesOverline.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesOverline;

  /// No description provided for @favoritesHeadline.
  ///
  /// In en, this message translates to:
  /// **'YOUR'**
  String get favoritesHeadline;

  /// No description provided for @favoritesHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'saved gyms.'**
  String get favoritesHeadlineAccent;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any gym profile to save it here for quick access.'**
  String get favoritesEmptyBody;

  /// No description provided for @favoritesEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Browse gyms'**
  String get favoritesEmptyCta;

  /// No description provided for @profileMenuBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing history'**
  String get profileMenuBilling;

  /// No description provided for @profileMenuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get profileMenuHelp;

  /// No description provided for @profileMenuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileMenuSettings;

  /// No description provided for @profileMenuInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get profileMenuInvite;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @inviteOverline.
  ///
  /// In en, this message translates to:
  /// **'INVITE A FRIEND'**
  String get inviteOverline;

  /// No description provided for @inviteHeadline.
  ///
  /// In en, this message translates to:
  /// **'SHARE THE'**
  String get inviteHeadline;

  /// No description provided for @inviteHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'pass.'**
  String get inviteHeadlineAccent;

  /// No description provided for @inviteBlurb.
  ///
  /// In en, this message translates to:
  /// **'Your friends unlock a free week. You earn a reward when they subscribe.'**
  String get inviteBlurb;

  /// No description provided for @inviteYourCode.
  ///
  /// In en, this message translates to:
  /// **'YOUR CODE'**
  String get inviteYourCode;

  /// No description provided for @inviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'SHARE LINK'**
  String get inviteShareLink;

  /// No description provided for @inviteCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get inviteCopyCode;

  /// No description provided for @inviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShare;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get inviteCodeCopied;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get inviteLinkCopied;

  /// No description provided for @inviteCountsPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get inviteCountsPending;

  /// No description provided for @inviteCountsConverted.
  ///
  /// In en, this message translates to:
  /// **'CONVERTED'**
  String get inviteCountsConverted;

  /// No description provided for @inviteCountsExpired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get inviteCountsExpired;

  /// No description provided for @inviteListTitle.
  ///
  /// In en, this message translates to:
  /// **'INVITED'**
  String get inviteListTitle;

  /// No description provided for @inviteListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invites yet. Share your code to get started.'**
  String get inviteListEmpty;

  /// No description provided for @inviteStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get inviteStatusPending;

  /// No description provided for @inviteStatusConverted.
  ///
  /// In en, this message translates to:
  /// **'CONVERTED'**
  String get inviteStatusConverted;

  /// No description provided for @inviteStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get inviteStatusExpired;

  /// No description provided for @inviteInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'INVITED BY'**
  String get inviteInvitedBy;

  /// No description provided for @inviteInvitedByNone.
  ///
  /// In en, this message translates to:
  /// **'Not referred'**
  String get inviteInvitedByNone;

  /// No description provided for @inviteClaimTitle.
  ///
  /// In en, this message translates to:
  /// **'GOT A FRIEND\'S CODE?'**
  String get inviteClaimTitle;

  /// No description provided for @inviteClaimBlurb.
  ///
  /// In en, this message translates to:
  /// **'Enter their GP-XXXXXX code to credit them for bringing you in.'**
  String get inviteClaimBlurb;

  /// No description provided for @inviteClaimInputLabel.
  ///
  /// In en, this message translates to:
  /// **'FRIEND\'S CODE'**
  String get inviteClaimInputLabel;

  /// No description provided for @inviteClaimInputHint.
  ///
  /// In en, this message translates to:
  /// **'GP-XXXXXX'**
  String get inviteClaimInputHint;

  /// No description provided for @inviteClaimCta.
  ///
  /// In en, this message translates to:
  /// **'Claim code'**
  String get inviteClaimCta;

  /// No description provided for @inviteClaimSuccess.
  ///
  /// In en, this message translates to:
  /// **'Got it — {name} now gets credit for your invite.'**
  String inviteClaimSuccess(Object name);

  /// No description provided for @inviteClaimErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a GP code.'**
  String get inviteClaimErrorInvalid;

  /// No description provided for @inviteClaimErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'No member uses that code.'**
  String get inviteClaimErrorNotFound;

  /// No description provided for @inviteClaimErrorOwnCode.
  ///
  /// In en, this message translates to:
  /// **'That\'s your own code.'**
  String get inviteClaimErrorOwnCode;

  /// No description provided for @inviteClaimErrorAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already claimed a friend\'s code.'**
  String get inviteClaimErrorAlready;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS.'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsNotifications;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsAccount;

  /// No description provided for @settingsLangArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsLangArabic;

  /// No description provided for @settingsLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLangEnglish;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsNotifPlanReminders.
  ///
  /// In en, this message translates to:
  /// **'Plan reminders'**
  String get settingsNotifPlanReminders;

  /// No description provided for @settingsNotifNewClubs.
  ///
  /// In en, this message translates to:
  /// **'New clubs near me'**
  String get settingsNotifNewClubs;

  /// No description provided for @settingsNotifPromos.
  ///
  /// In en, this message translates to:
  /// **'Promos & offers'**
  String get settingsNotifPromos;

  /// No description provided for @settingsAccountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsAccountEditProfile;

  /// No description provided for @settingsAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get settingsAccountSecurity;

  /// No description provided for @settingsAccountTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsAccountTerms;

  /// No description provided for @settingsAccountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsAccountPrivacy;

  /// No description provided for @settingsAccountLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsAccountLogout;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'GYMPASS v1.0 · MADE IN AMMAN'**
  String get settingsAppVersion;

  /// No description provided for @notificationsOverline.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get notificationsOverline;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @snackErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get snackErrorGeneric;

  /// No description provided for @supportOverline.
  ///
  /// In en, this message translates to:
  /// **'GET HELP'**
  String get supportOverline;

  /// No description provided for @supportHeadline.
  ///
  /// In en, this message translates to:
  /// **'WE\'RE HERE'**
  String get supportHeadline;

  /// No description provided for @supportHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'to help.'**
  String get supportHeadlineAccent;

  /// No description provided for @supportBlurb.
  ///
  /// In en, this message translates to:
  /// **'Average reply under 4 hours. We\'re based in Amman.'**
  String get supportBlurb;

  /// No description provided for @supportChannelsLabel.
  ///
  /// In en, this message translates to:
  /// **'CHANNELS'**
  String get supportChannelsLabel;

  /// No description provided for @supportChannelCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Call our team'**
  String get supportChannelCallTitle;

  /// No description provided for @supportChannelCallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sun–Thu · 9am–7pm'**
  String get supportChannelCallSubtitle;

  /// No description provided for @supportChannelEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get supportChannelEmailTitle;

  /// No description provided for @supportChannelEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'support@gym-pass.net'**
  String get supportChannelEmailSubtitle;

  /// No description provided for @supportChannelWhatsappTitle.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp chat'**
  String get supportChannelWhatsappTitle;

  /// No description provided for @supportChannelWhatsappSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Typically replies in 10 min'**
  String get supportChannelWhatsappSubtitle;

  /// No description provided for @supportSupportPhone.
  ///
  /// In en, this message translates to:
  /// **'+962 6 555 0100'**
  String get supportSupportPhone;

  /// No description provided for @supportMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'SEND A MESSAGE'**
  String get supportMessageLabel;

  /// No description provided for @supportSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportSubjectLabel;

  /// No description provided for @supportSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s this about?'**
  String get supportSubjectHint;

  /// No description provided for @supportBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get supportBodyLabel;

  /// No description provided for @supportBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s going on…'**
  String get supportBodyHint;

  /// No description provided for @supportSendBtn.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get supportSendBtn;

  /// No description provided for @supportSentSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll reply within 24 hours.'**
  String get supportSentSnackbar;

  /// No description provided for @supportMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in both subject and message.'**
  String get supportMissingFields;

  /// No description provided for @faqOverline.
  ///
  /// In en, this message translates to:
  /// **'KNOWLEDGE BASE'**
  String get faqOverline;

  /// No description provided for @faqHeadline.
  ///
  /// In en, this message translates to:
  /// **'FREQUENT'**
  String get faqHeadline;

  /// No description provided for @faqHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'questions.'**
  String get faqHeadlineAccent;

  /// No description provided for @faqBlurb.
  ///
  /// In en, this message translates to:
  /// **'Quick answers to what members ask us every day.'**
  String get faqBlurb;

  /// No description provided for @faqSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search questions…'**
  String get faqSearchHint;

  /// No description provided for @faqEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching questions. Try different words or contact support.'**
  String get faqEmpty;

  /// No description provided for @faqContactFooter.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find what you need?'**
  String get faqContactFooter;

  /// No description provided for @faqContactCta.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get faqContactCta;

  /// No description provided for @faqCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get faqCategoryAll;

  /// No description provided for @faqCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get faqCategoryGeneral;

  /// No description provided for @faqCategoryBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get faqCategoryBilling;

  /// No description provided for @faqCategoryCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get faqCategoryCheckin;

  /// No description provided for @faqCategoryClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get faqCategoryClasses;

  /// No description provided for @faqQ1.
  ///
  /// In en, this message translates to:
  /// **'How does QR check-in work?'**
  String get faqQ1;

  /// No description provided for @faqA1.
  ///
  /// In en, this message translates to:
  /// **'Each gym has its own QR. Open the Check-in tab, scan the code at the door, and wait for the confirmation screen. Your visit count updates instantly.'**
  String get faqA1;

  /// No description provided for @faqQ2.
  ///
  /// In en, this message translates to:
  /// **'Can I switch tiers at any time?'**
  String get faqQ2;

  /// No description provided for @faqA2.
  ///
  /// In en, this message translates to:
  /// **'Yes. Upgrades are pro-rated and take effect immediately. Downgrades apply at the next billing cycle.'**
  String get faqA2;

  /// No description provided for @faqQ3.
  ///
  /// In en, this message translates to:
  /// **'What happens if I miss a month?'**
  String get faqQ3;

  /// No description provided for @faqA3.
  ///
  /// In en, this message translates to:
  /// **'Unused visits don\'t roll over. Your visit count resets at the start of each billing cycle.'**
  String get faqA3;

  /// No description provided for @faqQ5.
  ///
  /// In en, this message translates to:
  /// **'Which payment methods are accepted?'**
  String get faqQ5;

  /// No description provided for @faqA5.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, CliQ, and Apple Pay. All billing is in JOD.'**
  String get faqA5;

  /// No description provided for @faqQ6.
  ///
  /// In en, this message translates to:
  /// **'Can I freeze or cancel my subscription?'**
  String get faqQ6;

  /// No description provided for @faqA6.
  ///
  /// In en, this message translates to:
  /// **'There\'s no cancellation flow — you\'re not locked in. Your plan simply ends on the last day of your current term and you can choose to renew (or not) at any point. Freezing is available on 6- and 12-month plans: Silver gets 10/24 days, Gold 12/26, Platinum 14/28, Diamond 16/30 (6mo/12mo). The freeze is one block that can\'t be split; 12-month plans can freeze twice. Freeze shifts both your renewal and expiration by the days you actually use.'**
  String get faqA6;

  /// No description provided for @faqQ7.
  ///
  /// In en, this message translates to:
  /// **'Is my data shared with gyms?'**
  String get faqQ7;

  /// No description provided for @faqA7.
  ///
  /// In en, this message translates to:
  /// **'Only what is needed for check-in: your name and tier. Your phone and email never leave our servers.'**
  String get faqA7;

  /// No description provided for @faqQ8.
  ///
  /// In en, this message translates to:
  /// **'What\'s the difference between tiers?'**
  String get faqQ8;

  /// No description provided for @faqA8.
  ///
  /// In en, this message translates to:
  /// **'Every tier gives you 30 visits each month. What changes is the gym network you unlock — Silver covers entry-level gyms, Gold adds Silver + Gold, Platinum adds premium, and Diamond opens every partner gym in the network.'**
  String get faqA8;

  /// No description provided for @reportOverline.
  ///
  /// In en, this message translates to:
  /// **'REPORT A BUG'**
  String get reportOverline;

  /// No description provided for @reportHeadline.
  ///
  /// In en, this message translates to:
  /// **'SOMETHING'**
  String get reportHeadline;

  /// No description provided for @reportHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'broken?'**
  String get reportHeadlineAccent;

  /// No description provided for @reportBlurb.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong — screenshots help us fix it faster.'**
  String get reportBlurb;

  /// No description provided for @reportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get reportCategoryLabel;

  /// No description provided for @reportCategoryCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get reportCategoryCheckin;

  /// No description provided for @reportCategoryPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get reportCategoryPayment;

  /// No description provided for @reportCategoryApp.
  ///
  /// In en, this message translates to:
  /// **'App / UI'**
  String get reportCategoryApp;

  /// No description provided for @reportCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get reportCategoryAccount;

  /// No description provided for @reportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportCategoryOther;

  /// No description provided for @reportGymLabel.
  ///
  /// In en, this message translates to:
  /// **'Gym (optional)'**
  String get reportGymLabel;

  /// No description provided for @reportGymHint.
  ///
  /// In en, this message translates to:
  /// **'Which gym?'**
  String get reportGymHint;

  /// No description provided for @reportDescLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get reportDescLabel;

  /// No description provided for @reportDescHint.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step if you can…'**
  String get reportDescHint;

  /// No description provided for @reportAttachLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment (optional)'**
  String get reportAttachLabel;

  /// No description provided for @reportAttachPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Attach a screenshot'**
  String get reportAttachPlaceholder;

  /// No description provided for @reportAttachAttached.
  ///
  /// In en, this message translates to:
  /// **'Screenshot attached · tap to remove'**
  String get reportAttachAttached;

  /// No description provided for @reportSubmitBtn.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSubmitBtn;

  /// No description provided for @reportSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report received'**
  String get reportSubmittedTitle;

  /// No description provided for @reportSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the heads-up. Your reference number is {ref} — we will follow up by email.'**
  String reportSubmittedBody(String ref);

  /// No description provided for @reportSubmittedClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reportSubmittedClose;

  /// No description provided for @reportMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please pick a category and describe the issue.'**
  String get reportMissingFields;

  /// No description provided for @billingOverline.
  ///
  /// In en, this message translates to:
  /// **'Billing · payments'**
  String get billingOverline;

  /// No description provided for @billingHeadline.
  ///
  /// In en, this message translates to:
  /// **'YOUR'**
  String get billingHeadline;

  /// No description provided for @billingHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'billing.'**
  String get billingHeadlineAccent;

  /// No description provided for @billingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Manage payment methods, review invoices, and track what is next on your pass.'**
  String get billingBlurb;

  /// No description provided for @billingMethodsLabel.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHODS'**
  String get billingMethodsLabel;

  /// No description provided for @billingMethodsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payment method yet. Add one to keep your pass active.'**
  String get billingMethodsEmpty;

  /// No description provided for @billingAddMethod.
  ///
  /// In en, this message translates to:
  /// **'Add method'**
  String get billingAddMethod;

  /// No description provided for @billingSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set default'**
  String get billingSetDefault;

  /// No description provided for @billingDefaultChip.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get billingDefaultChip;

  /// No description provided for @billingRemoveMethod.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get billingRemoveMethod;

  /// No description provided for @billingRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {label} from your saved payment methods?'**
  String billingRemoveConfirmBody(String label);

  /// No description provided for @billingRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove method'**
  String get billingRemoveConfirmTitle;

  /// No description provided for @billingRemoveConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get billingRemoveConfirmYes;

  /// No description provided for @billingAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get billingAddTitle;

  /// No description provided for @billingAddCard.
  ///
  /// In en, this message translates to:
  /// **'Card (Visa / Mastercard)'**
  String get billingAddCard;

  /// No description provided for @billingAddCliq.
  ///
  /// In en, this message translates to:
  /// **'CliQ'**
  String get billingAddCliq;

  /// No description provided for @billingAddApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get billingAddApple;

  /// No description provided for @billingAddGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get billingAddGoogle;

  /// No description provided for @billingAddSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save method'**
  String get billingAddSaveBtn;

  /// No description provided for @billingAddCardSection.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get billingAddCardSection;

  /// No description provided for @billingAddCliqSection.
  ///
  /// In en, this message translates to:
  /// **'CliQ details'**
  String get billingAddCliqSection;

  /// No description provided for @billingAddApplePaySection.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get billingAddApplePaySection;

  /// No description provided for @billingAddGooglePaySection.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get billingAddGooglePaySection;

  /// No description provided for @billingAddCardNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'CARD NUMBER'**
  String get billingAddCardNumberLabel;

  /// No description provided for @billingAddCardNumberHint.
  ///
  /// In en, this message translates to:
  /// **'4242 4242 4242 4242'**
  String get billingAddCardNumberHint;

  /// No description provided for @billingAddExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'EXPIRY'**
  String get billingAddExpiryLabel;

  /// No description provided for @billingAddExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'MM / YY'**
  String get billingAddExpiryHint;

  /// No description provided for @billingAddCvvLabel.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get billingAddCvvLabel;

  /// No description provided for @billingAddCvvHint.
  ///
  /// In en, this message translates to:
  /// **'123'**
  String get billingAddCvvHint;

  /// No description provided for @billingAddHolderLabel.
  ///
  /// In en, this message translates to:
  /// **'CARDHOLDER NAME'**
  String get billingAddHolderLabel;

  /// No description provided for @billingAddHolderHint.
  ///
  /// In en, this message translates to:
  /// **'Name as printed on card'**
  String get billingAddHolderHint;

  /// No description provided for @billingAddCliqAliasLabel.
  ///
  /// In en, this message translates to:
  /// **'CLIQ ALIAS'**
  String get billingAddCliqAliasLabel;

  /// No description provided for @billingAddCliqAliasHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. omar.jo'**
  String get billingAddCliqAliasHint;

  /// No description provided for @billingAddCliqPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'CLIQ PHONE'**
  String get billingAddCliqPhoneLabel;

  /// No description provided for @billingAddCliqPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+962 7X XXX XXXX'**
  String get billingAddCliqPhoneHint;

  /// No description provided for @billingAddCliqModeAlias.
  ///
  /// In en, this message translates to:
  /// **'Alias'**
  String get billingAddCliqModeAlias;

  /// No description provided for @billingAddCliqModePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get billingAddCliqModePhone;

  /// No description provided for @billingAddApplePayBlurb.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Pay to pay with Face ID or Touch ID. Your card stays in the Wallet — we only receive a payment token.'**
  String get billingAddApplePayBlurb;

  /// No description provided for @billingAddApplePayConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple Pay'**
  String get billingAddApplePayConnect;

  /// No description provided for @billingAddApplePayConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Wallet…'**
  String get billingAddApplePayConnecting;

  /// No description provided for @billingAddApplePayConnected.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay connected'**
  String get billingAddApplePayConnected;

  /// No description provided for @billingAddGooglePayBlurb.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Pay to pay with your fingerprint or device unlock. Your card stays in Google Wallet — we only receive a payment token.'**
  String get billingAddGooglePayBlurb;

  /// No description provided for @billingAddGooglePayConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Pay'**
  String get billingAddGooglePayConnect;

  /// No description provided for @billingAddGooglePayConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google Wallet…'**
  String get billingAddGooglePayConnecting;

  /// No description provided for @billingAddGooglePayConnected.
  ///
  /// In en, this message translates to:
  /// **'Google Pay connected'**
  String get billingAddGooglePayConnected;

  /// No description provided for @billingAddErrCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 13–19 digit card number.'**
  String get billingAddErrCardNumber;

  /// No description provided for @billingAddErrExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry must be a future MM/YY date.'**
  String get billingAddErrExpiry;

  /// No description provided for @billingAddErrCvv.
  ///
  /// In en, this message translates to:
  /// **'CVV must be 3 or 4 digits.'**
  String get billingAddErrCvv;

  /// No description provided for @billingAddErrHolder.
  ///
  /// In en, this message translates to:
  /// **'Enter the cardholder\'s name.'**
  String get billingAddErrHolder;

  /// No description provided for @billingAddErrCliq.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid CliQ alias or Jordanian phone number.'**
  String get billingAddErrCliq;

  /// No description provided for @billingAddErrApplePay.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Connect Apple Pay\" to finish linking your wallet.'**
  String get billingAddErrApplePay;

  /// No description provided for @billingAddErrGooglePay.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Connect Google Pay\" to finish linking your wallet.'**
  String get billingAddErrGooglePay;

  /// No description provided for @billingMethodAdded.
  ///
  /// In en, this message translates to:
  /// **'Payment method added.'**
  String get billingMethodAdded;

  /// No description provided for @billingMethodRemoved.
  ///
  /// In en, this message translates to:
  /// **'Payment method removed.'**
  String get billingMethodRemoved;

  /// No description provided for @billingDefaultUpdated.
  ///
  /// In en, this message translates to:
  /// **'Default payment method updated.'**
  String get billingDefaultUpdated;

  /// No description provided for @billingNextChargeLabel.
  ///
  /// In en, this message translates to:
  /// **'NEXT CHARGE'**
  String get billingNextChargeLabel;

  /// No description provided for @billingNextChargeBody.
  ///
  /// In en, this message translates to:
  /// **'{date} · {amount} JOD'**
  String billingNextChargeBody(String date, int amount);

  /// No description provided for @billingHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'INVOICE HISTORY'**
  String get billingHistoryLabel;

  /// No description provided for @billingHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get billingHistoryEmpty;

  /// No description provided for @billingInvoicePaid.
  ///
  /// In en, this message translates to:
  /// **'{iso} · {amount} JOD'**
  String billingInvoicePaid(String iso, int amount);

  /// No description provided for @billingInvoiceReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get billingInvoiceReceipt;

  /// No description provided for @billingCardNetworkVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get billingCardNetworkVisa;

  /// No description provided for @billingCardNetworkMastercard.
  ///
  /// In en, this message translates to:
  /// **'Mastercard'**
  String get billingCardNetworkMastercard;

  /// No description provided for @billingCardNetworkCliq.
  ///
  /// In en, this message translates to:
  /// **'CliQ'**
  String get billingCardNetworkCliq;

  /// No description provided for @billingCardNetworkApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get billingCardNetworkApple;

  /// No description provided for @billingCardNetworkGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get billingCardNetworkGoogle;

  /// No description provided for @securityBlurb.
  ///
  /// In en, this message translates to:
  /// **'Change your phone, enable biometric sign-in, and review where you\'re signed in.'**
  String get securityBlurb;

  /// No description provided for @securityChangePhoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Swap the phone number on your pass.'**
  String get securityChangePhoneDesc;

  /// No description provided for @securitySessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'See devices currently signed in and revoke any you don\'t recognize.'**
  String get securitySessionsDesc;

  /// No description provided for @securityChangePhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get securityChangePhoneTitle;

  /// No description provided for @securityChangePhoneNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New phone number'**
  String get securityChangePhoneNewLabel;

  /// No description provided for @securityChangePhoneOtpNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to confirm the new number.'**
  String get securityChangePhoneOtpNote;

  /// No description provided for @securityChangePhoneSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get securityChangePhoneSubmit;

  /// No description provided for @securityChangePhoneSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification sent. Check your SMS.'**
  String get securityChangePhoneSuccess;

  /// No description provided for @securityChangePhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get securityChangePhoneInvalid;

  /// No description provided for @securityChangePhoneOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get securityChangePhoneOtpTitle;

  /// No description provided for @securityChangePhoneOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code we sent to {phone}.'**
  String securityChangePhoneOtpSubtitle(String phone);

  /// No description provided for @securityChangePhoneVerifyBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get securityChangePhoneVerifyBtn;

  /// No description provided for @securityChangePhoneOtpError.
  ///
  /// In en, this message translates to:
  /// **'Code is invalid or expired.'**
  String get securityChangePhoneOtpError;

  /// No description provided for @securityChangePhoneInUse.
  ///
  /// In en, this message translates to:
  /// **'This phone is already in use by another account.'**
  String get securityChangePhoneInUse;

  /// No description provided for @securitySessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get securitySessionsTitle;

  /// No description provided for @securitySessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get securitySessionsThisDevice;

  /// No description provided for @securitySessionsActive.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get securitySessionsActive;

  /// No description provided for @securitySessionsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get securitySessionsRevoke;

  /// No description provided for @securitySessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'Session revoked.'**
  String get securitySessionsRevoked;

  /// No description provided for @securitySessionsRevokeAll.
  ///
  /// In en, this message translates to:
  /// **'Sign out all others'**
  String get securitySessionsRevokeAll;

  /// No description provided for @securitySessionsLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {when}'**
  String securitySessionsLastActive(String when);

  /// No description provided for @helpOverline.
  ///
  /// In en, this message translates to:
  /// **'Help · support'**
  String get helpOverline;

  /// No description provided for @helpHeadline.
  ///
  /// In en, this message translates to:
  /// **'HOW CAN WE'**
  String get helpHeadline;

  /// No description provided for @helpHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'help?'**
  String get helpHeadlineAccent;

  /// No description provided for @helpBlurb.
  ///
  /// In en, this message translates to:
  /// **'Talk to a human, skim the FAQ, or send us a report — we are on it.'**
  String get helpBlurb;

  /// No description provided for @helpContactSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Call, email, or WhatsApp — the team answers during the day.'**
  String get helpContactSupportDesc;

  /// No description provided for @helpFaqDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick answers to the questions members ask most.'**
  String get helpFaqDesc;

  /// No description provided for @helpReportIssueDesc.
  ///
  /// In en, this message translates to:
  /// **'Something broken? File a report and we will follow up by email.'**
  String get helpReportIssueDesc;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'support@gym-pass.net'**
  String get supportEmail;

  /// No description provided for @supportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'+962 7 9000 0100'**
  String get supportWhatsapp;

  /// No description provided for @supportChannelCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {value} to clipboard.'**
  String supportChannelCopied(String value);

  /// No description provided for @supportSentWithRef.
  ///
  /// In en, this message translates to:
  /// **'Thanks — ticket {ref}. We will reply within 24 hours.'**
  String supportSentWithRef(String ref);

  /// No description provided for @supportSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Message received'**
  String get supportSubmittedTitle;

  /// No description provided for @reportAttachPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach evidence'**
  String get reportAttachPickerTitle;

  /// No description provided for @reportAttachScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Recent screenshot'**
  String get reportAttachScreenshot;

  /// No description provided for @reportAttachCameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Photo from camera roll'**
  String get reportAttachCameraRoll;

  /// No description provided for @reportAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get reportAttachPhoto;

  /// No description provided for @reportAttachRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get reportAttachRemove;

  /// No description provided for @billingReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get billingReceiptTitle;

  /// No description provided for @billingReceiptItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'LINE ITEMS'**
  String get billingReceiptItemsLabel;

  /// No description provided for @billingReceiptLineBase.
  ///
  /// In en, this message translates to:
  /// **'Monthly pass'**
  String get billingReceiptLineBase;

  /// No description provided for @billingReceiptLineTax.
  ///
  /// In en, this message translates to:
  /// **'VAT · {amount} JOD'**
  String billingReceiptLineTax(int amount);

  /// No description provided for @billingReceiptTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get billingReceiptTotalLabel;

  /// No description provided for @billingReceiptSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send to email'**
  String get billingReceiptSendEmail;

  /// No description provided for @billingReceiptEmailQueued.
  ///
  /// In en, this message translates to:
  /// **'Receipt queued — emailed within a minute.'**
  String get billingReceiptEmailQueued;

  /// No description provided for @billingReceiptCloseBtn.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get billingReceiptCloseBtn;

  /// No description provided for @securityChangePhoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'Phone updated to {phone}.'**
  String securityChangePhoneUpdated(String phone);

  /// No description provided for @forgotOverline.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get forgotOverline;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get forgotTitle;

  /// No description provided for @forgotTitleAccent.
  ///
  /// In en, this message translates to:
  /// **'your password.'**
  String get forgotTitleAccent;

  /// No description provided for @forgotStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3 — Choose method'**
  String get forgotStep1;

  /// No description provided for @forgotStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3 — Enter code'**
  String get forgotStep2;

  /// No description provided for @forgotStep3.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3 — New password'**
  String get forgotStep3;

  /// No description provided for @forgotBlurb1.
  ///
  /// In en, this message translates to:
  /// **'Pick how you\'d like to receive the 4-digit code.'**
  String get forgotBlurb1;

  /// No description provided for @forgotMethodSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Text me a code'**
  String get forgotMethodSmsTitle;

  /// No description provided for @forgotMethodSmsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent to {phone}'**
  String forgotMethodSmsSubtitle(String phone);

  /// No description provided for @forgotMethodEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email me a code'**
  String get forgotMethodEmailTitle;

  /// No description provided for @forgotMethodEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent to {email}'**
  String forgotMethodEmailSubtitle(String email);

  /// No description provided for @forgotMethodEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'No email on file. Use SMS instead.'**
  String get forgotMethodEmailMissing;

  /// No description provided for @forgotSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotSendCode;

  /// No description provided for @forgotCodeBlurb.
  ///
  /// In en, this message translates to:
  /// **'We sent a 4-digit code to {target}. Enter it below.'**
  String forgotCodeBlurb(String target);

  /// No description provided for @forgotResendCode.
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get forgotResendCode;

  /// No description provided for @forgotVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get forgotVerifyCode;

  /// No description provided for @forgotNewPasswordBlurb.
  ///
  /// In en, this message translates to:
  /// **'Pick a new password. You\'ll use it to sign in from now on.'**
  String get forgotNewPasswordBlurb;

  /// No description provided for @forgotSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get forgotSetNewPassword;

  /// No description provided for @forgotResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated. You can sign in with the new one.'**
  String get forgotResetSuccess;

  /// No description provided for @forgotErrAccountMissing.
  ///
  /// In en, this message translates to:
  /// **'No account on file for that number.'**
  String get forgotErrAccountMissing;

  /// No description provided for @forgotErrCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Try again.'**
  String get forgotErrCodeInvalid;

  /// No description provided for @forgotDevHint.
  ///
  /// In en, this message translates to:
  /// **'Dev mode: any 4-digit code works, but 1234 is the canonical one.'**
  String get forgotDevHint;

  /// No description provided for @securityBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with biometrics'**
  String get securityBiometricTitle;

  /// No description provided for @securityBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID, fingerprint, or your device PIN instead of typing your password.'**
  String get securityBiometricDesc;

  /// No description provided for @securityBiometricNoPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a password first to enable biometric sign-in.'**
  String get securityBiometricNoPassword;

  /// No description provided for @securityBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t have biometrics or a screen lock set up.'**
  String get securityBiometricUnavailable;

  /// No description provided for @biometricEnrollTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get biometricEnrollTitle;

  /// No description provided for @biometricEnrollBlurb.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password so we can save it behind {biometric}.'**
  String biometricEnrollBlurb(String biometric);

  /// No description provided for @biometricEnrollPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get biometricEnrollPasswordLabel;

  /// No description provided for @biometricEnrollPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get biometricEnrollPasswordHint;

  /// No description provided for @biometricEnrollSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get biometricEnrollSubmit;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock GymPass to sign in'**
  String get biometricUnlockReason;

  /// No description provided for @biometricEnrollReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to save your sign-in'**
  String get biometricEnrollReason;

  /// No description provided for @biometricSignInBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with biometrics'**
  String get biometricSignInBtn;

  /// No description provided for @biometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric sign-in is on.'**
  String get biometricEnabled;

  /// No description provided for @biometricDisabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric sign-in is off.'**
  String get biometricDisabled;

  /// No description provided for @biometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric prompt cancelled.'**
  String get biometricCancelled;

  /// No description provided for @biometricGenericLabel.
  ///
  /// In en, this message translates to:
  /// **'biometrics'**
  String get biometricGenericLabel;

  /// No description provided for @billingNoSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'No active subscription'**
  String get billingNoSubscriptionTitle;

  /// No description provided for @billingNoSubscriptionBlurb.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a plan right now, so there\'s nothing scheduled to charge. Pick a tier to start scanning into partner gyms.'**
  String get billingNoSubscriptionBlurb;

  /// No description provided for @billingNoSubscriptionCta.
  ///
  /// In en, this message translates to:
  /// **'Browse plans'**
  String get billingNoSubscriptionCta;

  /// No description provided for @gymNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Gym not found'**
  String get gymNotFoundTitle;

  /// No description provided for @gymNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'We could not find a gym matching \"{slug}\". It may have been removed.'**
  String gymNotFoundBody(String slug);

  /// No description provided for @gymNotFoundBackToExplore.
  ///
  /// In en, this message translates to:
  /// **'Back to explore'**
  String get gymNotFoundBackToExplore;

  /// No description provided for @legalLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get legalLastUpdated;

  /// No description provided for @legalReadTermsAction.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalReadTermsAction;

  /// No description provided for @legalReadPrivacyAction.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalReadPrivacyAction;

  /// No description provided for @legalSignupConsent.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our Terms of Service and Privacy Policy.'**
  String get legalSignupConsent;

  /// No description provided for @legalSignupConsentPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our'**
  String get legalSignupConsentPrefix;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsTitle;

  /// No description provided for @termsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GymPass · Member Agreement'**
  String get termsSubtitle;

  /// No description provided for @termsUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'May 2026'**
  String get termsUpdatedAt;

  /// No description provided for @termsAcceptanceHeadline.
  ///
  /// In en, this message translates to:
  /// **'Acceptance of these Terms'**
  String get termsAcceptanceHeadline;

  /// No description provided for @termsAcceptanceBody.
  ///
  /// In en, this message translates to:
  /// **'By creating a GymPass account, subscribing to a plan, or scanning into a partner gym, you confirm that you have read these Terms and agree to be bound by them. If you do not accept any clause below, please do not use the service.'**
  String get termsAcceptanceBody;

  /// No description provided for @termsAccountHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get termsAccountHeadline;

  /// No description provided for @termsAccountBody.
  ///
  /// In en, this message translates to:
  /// **'You sign in with a Jordanian mobile number and a one-time code. Keep your number current — we use it for account recovery, payment receipts, and time-sensitive notifications. You are responsible for activity on your account and for keeping your device secure. Notify support immediately if you suspect unauthorised use.'**
  String get termsAccountBody;

  /// No description provided for @termsMembershipHeadline.
  ///
  /// In en, this message translates to:
  /// **'Subscription tiers'**
  String get termsMembershipHeadline;

  /// No description provided for @termsMembershipBody.
  ///
  /// In en, this message translates to:
  /// **'Your tier (Silver, Gold, Platinum, or Diamond) determines which partner gyms you can enter and how many visits you get each calendar month. Visit budgets reset on the first day of each month and do not roll over. Upgrading or downgrading takes effect at your next renewal unless we explicitly note otherwise in the upgrade flow.'**
  String get termsMembershipBody;

  /// No description provided for @termsPaymentHeadline.
  ///
  /// In en, this message translates to:
  /// **'Payments and renewals'**
  String get termsPaymentHeadline;

  /// No description provided for @termsPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically at the start of each billing period unless cancelled in advance. We charge the payment method you registered. If a charge fails we may retry, suspend access, or terminate the subscription. All prices are shown in Jordanian Dinars (JOD). Taxes, where applicable, are included in the displayed price.'**
  String get termsPaymentBody;

  /// No description provided for @termsCheckinHeadline.
  ///
  /// In en, this message translates to:
  /// **'Gym access and check-ins'**
  String get termsCheckinHeadline;

  /// No description provided for @termsCheckinBody.
  ///
  /// In en, this message translates to:
  /// **'Each partner gym has a static QR code at its entrance. Scanning the code with the app records a check-in and deducts one visit from your monthly budget. Access is contingent on your tier allowing the gym, your remaining visits, and your account being in good standing. We may rate-limit repeated scans at the same gym to prevent accidental double-charges.'**
  String get termsCheckinBody;

  /// No description provided for @termsConductHeadline.
  ///
  /// In en, this message translates to:
  /// **'Member conduct'**
  String get termsConductHeadline;

  /// No description provided for @termsConductBody.
  ///
  /// In en, this message translates to:
  /// **'You agree to follow each partner gym\'s house rules, behave respectfully with staff and other members, and use the service only for personal, non-commercial gym access. Sharing your account, reselling visits, or attempting to scan with another member\'s QR is prohibited and may result in immediate termination.'**
  String get termsConductBody;

  /// No description provided for @termsTerminationHeadline.
  ///
  /// In en, this message translates to:
  /// **'Termination'**
  String get termsTerminationHeadline;

  /// No description provided for @termsTerminationBody.
  ///
  /// In en, this message translates to:
  /// **'You may cancel at any time from your profile. Cancellation takes effect at the end of your current billing period; we do not pro-rate refunds. We may suspend or terminate accounts for non-payment, fraud, abuse of a partner gym, or violation of these Terms. Outstanding payouts and audit records survive termination per the Privacy Policy.'**
  String get termsTerminationBody;

  /// No description provided for @termsLiabilityHeadline.
  ///
  /// In en, this message translates to:
  /// **'Liability'**
  String get termsLiabilityHeadline;

  /// No description provided for @termsLiabilityBody.
  ///
  /// In en, this message translates to:
  /// **'GymPass is a booking and access platform. We are not the operator of the partner gyms and are not responsible for injuries, lost property, or disputes that occur at a partner venue — those remain matters between you and the gym. Where Jordanian law permits, our liability is limited to the amount you paid us in the three months preceding the claim.'**
  String get termsLiabilityBody;

  /// No description provided for @termsChangesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Changes to these Terms'**
  String get termsChangesHeadline;

  /// No description provided for @termsChangesBody.
  ///
  /// In en, this message translates to:
  /// **'We may update these Terms from time to time. If a change is material, we will notify you in-app at least seven days before it takes effect. Continued use of the service after the effective date constitutes acceptance.'**
  String get termsChangesBody;

  /// No description provided for @termsContactHeadline.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get termsContactHeadline;

  /// No description provided for @termsContactBody.
  ///
  /// In en, this message translates to:
  /// **'Questions about these Terms? Reach us via the in-app Support page or email support@gym-pass.net. We respond in Arabic or English, whichever you write in.'**
  String get termsContactBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'GymPass · How we handle your data'**
  String get privacySubtitle;

  /// No description provided for @privacyUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'May 2026'**
  String get privacyUpdatedAt;

  /// No description provided for @privacyDataWeCollectHeadline.
  ///
  /// In en, this message translates to:
  /// **'Data we collect'**
  String get privacyDataWeCollectHeadline;

  /// No description provided for @privacyDataWeCollectBody.
  ///
  /// In en, this message translates to:
  /// **'We collect: the phone number you sign up with; any name, email, and birth date you add to your profile; payment method details (handled by our payment processor — we never store your full card number, only the last four digits and the card brand); your check-in history (which gym, when, success or failure reason); device GPS while you have the Explore tab open; and the type/model of device you use so we can debug crashes.'**
  String get privacyDataWeCollectBody;

  /// No description provided for @privacyPurposeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Why we collect it'**
  String get privacyPurposeHeadline;

  /// No description provided for @privacyPurposeBody.
  ///
  /// In en, this message translates to:
  /// **'Phone number — account identity and OTP sign-in. Profile fields — display name on your account, sending you receipts. Payment data — processing subscriptions. Check-in history — tracking your visit budget, paying partner gyms for visits, surfacing fraud. GPS — finding gyms near you on the Explore map. Device info — debugging crashes and security investigations.'**
  String get privacyPurposeBody;

  /// No description provided for @privacySharingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Who we share with'**
  String get privacySharingHeadline;

  /// No description provided for @privacySharingBody.
  ///
  /// In en, this message translates to:
  /// **'Partner gyms see a masked version of your details when you check in (see the next section). Our payment processor receives the card data needed to charge you. Our hosting and analytics providers process the technical data needed to run the service. We do not sell your data to advertisers, marketers, or data brokers. We may disclose data when required by a valid Jordanian legal order.'**
  String get privacySharingBody;

  /// No description provided for @privacyMaskingHeadline.
  ///
  /// In en, this message translates to:
  /// **'What partner gyms see about you'**
  String get privacyMaskingHeadline;

  /// No description provided for @privacyMaskingBody.
  ///
  /// In en, this message translates to:
  /// **'Partners see: your first name and last-initial (e.g. \'Ahmad K.\'), the last four digits of your phone (e.g. \'•• ••• 4567\'), the time you checked in, and an internal user ID for support reference. Partners NEVER see your full phone, your email, your address, or your payment information. This masking is enforced at our API; partners cannot opt out of it.'**
  String get privacyMaskingBody;

  /// No description provided for @privacyRetentionHeadline.
  ///
  /// In en, this message translates to:
  /// **'How long we keep your data'**
  String get privacyRetentionHeadline;

  /// No description provided for @privacyRetentionBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile and active subscription data are kept while your account is active. After you delete your account, we retain financial and audit records for seven years to meet Jordanian tax and consumer-protection requirements; everything else is erased within 30 days. Check-in records linked to a paid payout cannot be deleted until that payout is settled.'**
  String get privacyRetentionBody;

  /// No description provided for @privacySecurityHeadline.
  ///
  /// In en, this message translates to:
  /// **'How we protect your data'**
  String get privacySecurityHeadline;

  /// No description provided for @privacySecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Connections to our servers use TLS. Passwords are hashed; we never store them in readable form. Payment data is tokenised by our payment processor; we don\'t see your full card number. Internal access to your data is role-gated (admin operators only, with audit logging on every read of personal records).'**
  String get privacySecurityBody;

  /// No description provided for @privacyRightsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get privacyRightsHeadline;

  /// No description provided for @privacyRightsBody.
  ///
  /// In en, this message translates to:
  /// **'You can: review and edit your profile in the Settings tab; download your data via Support; request deletion of your account at any time (we will confirm that the seven-year retention exceptions apply only to financial and audit records); withdraw consent for marketing notifications (the toggles are in Settings → Notifications); raise a complaint with the Jordanian Personal Data Protection Authority.'**
  String get privacyRightsBody;

  /// No description provided for @privacyChildrenHeadline.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get privacyChildrenHeadline;

  /// No description provided for @privacyChildrenBody.
  ///
  /// In en, this message translates to:
  /// **'GymPass is not directed at children under 16. If you believe a minor has signed up, contact support and we will remove the account.'**
  String get privacyChildrenBody;

  /// No description provided for @privacyChangesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Changes to this Policy'**
  String get privacyChangesHeadline;

  /// No description provided for @privacyChangesBody.
  ///
  /// In en, this message translates to:
  /// **'We may update this policy. If a change materially affects how we handle your data, we will notify you in-app at least seven days before it takes effect. Continued use after the effective date constitutes acceptance.'**
  String get privacyChangesBody;

  /// No description provided for @privacyContactHeadline.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get privacyContactHeadline;

  /// No description provided for @privacyContactBody.
  ///
  /// In en, this message translates to:
  /// **'Email privacy@gym-pass.net or use the in-app Support page. We respond in Arabic or English. Our Data Protection contact is reachable at the same address.'**
  String get privacyContactBody;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
