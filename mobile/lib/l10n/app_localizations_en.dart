// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signInStep => 'Welcome — Step 1 of 3';
  @override
  String get signInHeadline1 => 'ONE PASS,';
  @override
  String get signInHeadline2 => 'EVERY';
  @override
  String get signInHeadlineAccent => 'gym.';
  @override
  String get signInBlurb =>
      "Train anywhere in the network. One subscription. Unlocked by the QR at the door.";
  @override
  String get signInOtpNote => "We'll text you a 4-digit code. No spam, ever.";
  @override
  String get signInContinueWithGoogle => 'Continue with Google';
  @override
  String get signInPasswordLabel => 'PASSWORD';
  @override
  String get signInPasswordHint => 'Enter your password';
  @override
  String get signInPasswordNote => "Welcome back. Enter the password you set when you joined.";
  @override
  String get signInWithPasswordCta => 'Sign in';
  @override
  String get signInRememberMe => 'Remember me';
  @override
  String get signInForgotPassword => 'Forgot password?';
  @override
  String get signInCheckingNumber => 'Checking your number…';
  @override
  String get errorPasswordInvalid => 'Wrong password. Try again.';
  @override
  String get errorRequiredFields => 'Please fill in all the required fields.';
  @override
  String get errorInvalidInput =>
      'Some fields look wrong. Check and try again.';
  @override
  String get errorPasswordSignInRequired => 'Enter your password';
  @override
  String get errorOtpLocked =>
      'Too many attempts. Try again in 1 minute.';
  @override
  String get errorOtpInvalid => 'Wrong code. Try again.';
  @override
  String get errorNetwork =>
      'Network error. Check your connection and try again.';
  @override
  String get orDivider => 'OR';
  @override
  String get phoneCountryPrefix => '+962';
  @override
  String get phoneHint => '7X XXX XXXX';
  @override
  String get errorPhoneRequired => 'Please enter your phone number';
  @override
  String get errorPhoneInvalid => 'Invalid mobile number';

  @override
  String get otpSentTo => 'We sent a code to';
  @override
  String get otpResend => 'Resend code';
  @override
  String otpResendIn(int seconds) => 'Resend in ${seconds}s';
  @override
  String get otpDevHint => 'Dev mode: use 1234';
  @override
  String get errorOtpIncomplete => 'Please enter the full 4-digit code';
  @override
  String get otpStep => 'Step 2 of 3 — Verify';
  @override
  String get otpAlmostTitle => 'ALMOST';
  @override
  String get otpAlmostAccent => 'there.';
  @override
  String otpSentToPhone(String phone) =>
      'Enter the 4-digit code we sent to $phone.';
  @override
  String get otpPhoneFallback => '+962 7X XXX XXXX';
  @override
  String get otpResendNow => 'You can resend now';
  @override
  String get otpResendBtn => 'RESEND';

  @override
  String get registerStep => 'Step 3 of 3 — Profile';
  @override
  String get registerTitle => "YOU'RE";
  @override
  String get registerTitleAccent => 'new.';
  @override
  String get registerBlurb =>
      'Tell us your name and email so we can personalize your pass.';
  @override
  String get labelFirstName => 'FIRST NAME';
  @override
  String get labelLastName => 'LAST NAME';
  @override
  String get labelEmail => 'EMAIL';
  @override
  String get labelPassword => 'PASSWORD';
  @override
  String get labelPasswordConfirm => 'CONFIRM PASSWORD';
  @override
  String get labelBirthdate => 'BIRTHDATE';
  @override
  String get hintFirstName => 'e.g. Layla';
  @override
  String get hintLastName => 'e.g. Haddad';
  @override
  String get hintEmail => 'username@domain.com';
  @override
  String get hintBirthdate => 'DD / MM / YYYY';
  @override
  String get birthdateHelpText => 'Pick your date of birth';
  @override
  String get hintPassword => 'At least 8 characters';
  @override
  String get hintPasswordConfirm => 'Re-enter your password';
  @override
  String get agreementText => 'I agree to the';
  @override
  String get terms => 'Terms';
  @override
  String get and => 'and';
  @override
  String get privacyPolicy => 'Privacy Policy';
  @override
  String get createMyPass => 'Create my pass';
  @override
  String get errorFirstNameRequired => 'First name is required';
  @override
  String get errorLastNameRequired => 'Last name is required';
  @override
  String errorNameTooShort(int min) => 'Must be at least $min characters';
  @override
  String get errorEmailRequired => 'Email is required';
  @override
  String get errorEmailInvalid => 'Invalid email address';
  @override
  String get errorPasswordRequired => 'Password is required';
  @override
  String get errorPasswordTooShort => 'Password must be at least 8 characters';
  @override
  String get errorPasswordWeak =>
      'Password must include a letter and a number';
  @override
  String get errorPasswordMismatch => "Passwords don't match";
  @override
  String get errorAgreementRequired => 'You must agree to continue';
  @override
  String get errorBirthdateRequired => 'Please pick your birthdate';
  @override
  String get labelGender => 'GENDER';
  @override
  String get genderMale => 'Male';
  @override
  String get genderFemale => 'Female';
  @override
  String get errorGenderRequired => 'Please select your gender';

  @override
  String get continueLabel => 'Continue';
  @override
  String get confirm => 'Confirm';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get close => 'Close';
  @override
  String get back => 'Back';
  @override
  String get retry => 'Retry';
  @override
  String get seeAll => 'See all';

  @override
  String homeGreetingName(String name) => '${name.toUpperCase()},';
  @override
  String get homeGreetingFallback => 'THERE,';
  @override
  String get homeHeadlineLine1 => "LET'S";
  @override
  String get homeHeadlineAccent => 'train.';
  @override
  String get homeActive => 'ACTIVE';
  @override
  String get homeVisits => 'visits';
  @override
  String homeLeftThisCycle(int n) => '$n LEFT THIS CYCLE';
  @override
  String homeCycleProgress(int cycle, int total, int days) =>
      'MONTH $cycle OF $total · CYCLE RESETS IN ${days}D';
  @override
  String homeTermEndsIn(int days) => 'TERM RENEWS IN ${days}D';
  @override
  String get homeManage => 'MANAGE';
  @override
  String get homeNoPlanOverline => 'No active plan';
  @override
  String get homeNoPlanTitle => 'Choose your pass';
  @override
  String get homeNoPlanBlurb =>
      'Pick a tier to unlock gyms across the city. Your pass activates the moment checkout succeeds.';
  @override
  String get homeNoPlanCta => 'See plans';
  @override
  String get homeNearYou => 'Near you';
  @override
  String get homeNoGymsYet =>
      'No partner gyms in the network yet. Pull to refresh.';
  @override
  String get homeCategories => 'Categories';
  @override
  String get categoryGym => 'GYM';
  @override
  String get categoryCross => 'CROSS';
  @override
  String get categoryMartial => 'MARTIAL';
  @override
  String get categoryYoga => 'YOGA';
  @override
  String clubsCount(int n) {
    final s = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      zero: 'No clubs',
      one: '1 club',
      other: '$n clubs',
    );
    return s;
  }

  @override
  String get tabHome => 'Home';
  @override
  String get tabGyms => 'Gyms';
  @override
  String get tabExplore => 'Explore';
  @override
  String get exploreOverline => 'Explore';
  @override
  String get exploreViewProfile => 'View profile';
  @override
  String get exploreSearchHint => 'Search gyms or areas';
  @override
  String exploreSearchEmpty(String query) =>
      'No gyms match "$query".';
  @override
  String exploreCountStrip(int shown, int total) =>
      '$shown of $total gyms match';
  @override
  String exploreDistanceKm(String km) => '$km km';
  @override
  String exploreGymCount(int n) => '$n GYMS';
  @override
  String get exploreOneGymCount => '1 GYM';
  @override
  String get exploreSelectedGymHeader => 'SELECTED';
  @override
  String get exploreSelectedViewProfile => 'View profile';
  @override
  String exploreShowAllGyms(int n) => 'SHOW ALL $n';
  @override
  String get exploreNoMatches => 'No gyms match the current filters.';
  @override
  String get exploreFiltersTitle => 'Filters';
  @override
  String get exploreFiltersReset => 'Reset';
  @override
  String get exploreFiltersDone => 'Done';
  @override
  String get exploreFiltersCategorySection => 'Category';
  @override
  String get exploreFiltersTierSection => 'Tier';
  @override
  String get exploreFiltersFavoritesLabel => 'Show only favorites';
  @override
  String get gymsCategoryAll => 'All';
  @override
  String get gymsCategoryGym => 'Gym';
  @override
  String get gymsCategoryCrossfit => 'CrossFit';
  @override
  String get gymsCategoryMartial => 'Martial';
  @override
  String get gymsCategoryYoga => 'Yoga';
  @override
  String get tabScan => 'Scan';
  @override
  String get tabProfile => 'Profile';

  @override
  String get gymsTitle => 'Browse gyms';
  @override
  String get gymsHeadline => 'EVERY';
  @override
  String get gymsHeadlineAccent => 'club.';
  @override
  String get gymsSearchHint => 'Search by name or area';
  @override
  String get gymsFilterAll => 'All';
  @override
  String get gymsFilterGym => 'Gym';
  @override
  String get gymsFilterCrossfit => 'CrossFit';
  @override
  String get gymsFilterMartial => 'Martial';
  @override
  String get gymsFilterYoga => 'Yoga';
  @override
  String get gymsEmpty => 'No matching gyms';
  @override
  String get gymsEmptyFavorites =>
      'No favorites yet — tap the heart on any club to save it here.';
  @override
  String get gymOpen247 => 'OPEN 24/7';
  @override
  String gymKmAway(String km) => '$km KM';
  @override
  String get gymAbout => 'About';
  @override
  String get gymAmenityWifi => 'WI-FI';
  @override
  String get gymAmenityParking => 'PARKING';
  @override
  String get gymAmenityShowers => 'SHOWERS';
  @override
  String get gymAmenityLockers => 'LOCKERS';
  @override
  String get gymCheckInHere => 'Check in here';
  @override
  String get gymCheckedInRecently => 'Checked in · pass active';
  @override
  String gymUpgradeTo(String tier) => 'Upgrade to $tier';
  @override
  String get gymAccessIncluded => 'Included in your plan';
  @override
  String gymAccessRequiresTier(String tier) => 'Requires $tier tier';
  @override
  String gymDescriptionFallback(String area) =>
      'A serious training space in $area. Modern equipment, climate-controlled, and 24/7 access for GymPass members.';

  @override
  String get checkinSuccess => 'Check-in successful';
  @override
  String get checkinDemoButton => 'Demo check-in';
  @override
  String get checkinLockedBannerTitle => 'Preview mode';
  @override
  String get checkinLockedBannerBody =>
      "You don't have an active plan yet. Scanning a gym's QR will open its profile so you can preview access; check-ins unlock once you subscribe.";
  @override
  String get checkinSeePlansCta => 'See plans';
  @override
  String get checkinBackHome => 'Back to home';
  @override
  String get checkinVisitGym => 'View gym';
  @override
  String get checkinSuccessTitle => "YOU'RE";
  @override
  String get checkinSuccessTitleAccent => 'in.';

  @override
  String visitsRemaining(int count) {
    final s = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      zero: 'No visits left',
      one: '1 visit left',
      other: '$count visits left',
    );
    return s;
  }

  @override
  String get tierSilver => 'Silver';
  @override
  String get tierGold => 'Gold';
  @override
  String get tierPlatinum => 'Platinum';
  @override
  String get tierDiamond => 'Diamond';
  @override
  List<String> tierFeatures(String tierKey) {
    switch (tierKey) {
      case 'silver':
        return const [
          '30 visits per month',
          'Access to entry-level gyms',
          'QR check-in at any partner location',
        ];
      case 'gold':
        return const [
          '30 visits per month',
          'Access to Silver + Gold gyms',
          'Pause up to 12 days on 6-month plans',
        ];
      case 'platinum':
        return const [
          '30 visits per month',
          'Access to premium gyms',
          'Pause up to 14 days on 6-month plans',
          'Priority customer support',
        ];
      case 'diamond':
        return const [
          '30 visits per month',
          'Access to every partner gym',
          'Pause up to 16 days on 6-month plans',
          'Concierge booking',
        ];
      default:
        return const [];
    }
  }

  @override
  String get plansTitle => 'CHOOSE';
  @override
  String get plansTitleAccent => 'your tier.';
  @override
  String get plansOverline => 'Pick your pass';
  @override
  String plansContinueWith(String tier) => 'Continue with $tier';
  @override
  String plansSubscribeTo(String tier) => 'Subscribe to $tier';
  @override
  String get plansSkipForNow => 'Skip for now';
  @override
  String get plansVisitsPerMonth => 'VISITS/MO';
  @override
  String get plansUnlimited => 'UNLIMITED';
  @override
  String get plansPerMonth => 'JOD/MO';
  @override
  String get plansDurationHeading => 'COMMIT FOR';
  @override
  String get plansDurationSwipeHint => 'SWIPE FOR 1 YEAR';
  @override
  String get plansDuration1Month => '1 MONTH';
  @override
  String get plansDuration3Months => '3 MONTHS';
  @override
  String get plansDuration6Months => '6 MONTHS';
  @override
  String get plansDuration12Months => '1 YEAR';
  @override
  String plansDurationSave(int percent) => 'SAVE $percent%';
  @override
  String plansDurationTotal(int amount) => '$amount JOD total';
  @override
  String plansVisitsIncluded(int count) => '$count visits included';
  @override
  String plansFeaturePauseSingle(int days) =>
      'Freeze your plan for up to $days days, in one block';
  @override
  String plansFeaturePauseSplit(int days, int count) =>
      'Freeze your plan $count times per term, up to $days days total';
  @override
  String get plansTapToExpand => 'TAP TO EXPAND';
  @override
  String plansNetworkCount(int count) => '+$count GYMS';
  @override
  String plansStartsFrom(int amount) => 'FROM $amount JOD/MO';
  @override
  String plansDurationCardPerMonth(int amount) => '$amount/MO';
  @override
  String plansNetworkSheetTitle(String tier) => '$tier plan network';
  @override
  String get plansNetworkSheetBody =>
      'One QR scan per gym per day. Your 30 monthly visits work across the entire network.';
  @override
  String get plansNetworkVisitsBadge => '30/MO';
  @override
  String get plansNetworkClose => 'Got it';
  @override
  String get plansNetworkEmpty => 'Network partners rolling out soon.';
  @override
  String get plansCurrentPlan => 'CURRENT PLAN';
  @override
  String get plansPickUpgrade => 'Pick a higher tier';
  @override
  String plansScheduleDowngradeTo(String tier) => 'Switch to $tier at renewal';
  @override
  String get plansCurrentPlanCta => 'This is your current plan';
  @override
  String get plansCancelScheduledChange => 'Cancel scheduled switch';
  @override
  String get plansScheduledBadge => 'SCHEDULED';
  @override
  String plansScheduledFor(String date) => 'Switches $date';
  @override
  String get plansDowngradeConfirmTitle => 'Schedule downgrade?';
  @override
  String plansDowngradeConfirmBody(String tier, String date) =>
      "You'll keep your current benefits until $date. On renewal, your plan switches to $tier and billing adjusts accordingly.";
  @override
  String plansScheduledSnack(String tier, String date) =>
      'Scheduled switch to $tier on $date.';
  @override
  String get plansScheduledCancelledSnack => 'Scheduled switch cancelled.';
  @override
  String plansUpgradeTo(String tier) => 'Upgrade to $tier';
  @override
  String get plansUpgradeConfirmTitle => 'Confirm upgrade?';
  @override
  String plansUpgradeConfirmBody(String tier, String duration) =>
      "You're upgrading to $tier for $duration. The new tier unlocks at your next check-in and a fresh billing period starts today.";
  @override
  String plansSwitchPeriodTo(String duration) =>
      'Switch to $duration at renewal';
  @override
  String get plansPeriodChangeConfirmTitle => 'Schedule period change?';
  @override
  String plansPeriodChangeConfirmBody(String duration, String date) =>
      'Your current plan runs until $date. On renewal, your commitment switches to $duration and billing adjusts to match.';
  @override
  String plansPeriodScheduledSnack(String duration, String date) =>
      'Switching to $duration on $date.';
  @override
  String plansExtendTo(String duration) => 'Extend to $duration';
  @override
  String get plansExtendConfirmTitle => 'Extend your plan?';
  @override
  String plansExtendConfirmBody(String duration, String renewDate) =>
      'Lock in $duration now — you only pay the difference. Your next renewal shifts to $renewDate and visits already used this term carry over.';
  @override
  String plansExtendedSnack(String renewDate) =>
      'Plan extended — renews $renewDate.';
  @override
  String plansSwitchToCta(String tier, String duration) =>
      'Switch to $tier · $duration';
  @override
  String get plansSwitchConfirmTitle => 'Switch your plan?';
  @override
  String plansSwitchConfirmBody(String tier, String duration) =>
      'You will switch to $tier on the $duration plan now. Your current subscription is cancelled and the new one starts immediately.';

  @override
  String get checkoutTitle => 'CONFIRM';
  @override
  String get checkoutTitleAccent => '& pay.';
  @override
  String get checkoutOverline => 'Secure checkout';
  @override
  String checkoutPayAmount(int amount) => 'Pay $amount JOD';
  @override
  String get checkoutOneMonth => '1-MONTH';
  @override
  String checkoutDurationSummary(int months) => '$months-MONTH';
  @override
  String get checkoutDurationYear => '1-YEAR';
  @override
  String checkoutDiscount(int percent) => 'Discount ($percent%)';
  @override
  String get checkoutSubtotal => 'Subtotal';
  @override
  String get checkoutTax => 'Tax (16%)';
  @override
  String get checkoutTotal => 'Total';
  @override
  String get checkoutPaymentMethod => 'PAYMENT METHOD';
  @override
  String get checkoutNoMethodsHint => 'No payment method on file. Add one to continue.';
  @override
  String get checkoutAddPaymentMethod => 'Add payment method';
  @override
  String get checkoutAddAnother => 'Add another';
  @override
  String get checkoutExtensionBadge => 'EXTENSION';
  @override
  String get checkoutCurrentPlanCredit => 'Current plan credit';
  @override
  String get checkoutExtensionRenewsOn => 'NEW RENEWAL';
  @override
  String get errorPaymentMethod => 'Choose a payment method';

  @override
  String get subscriptionTitle => 'YOUR';
  @override
  String get subscriptionOverline => 'Your plan';
  @override
  String get subscriptionTitleAccent => 'plan.';
  @override
  String subscriptionRenewsOn(String date) => 'ACTIVE · RENEWS $date';
  @override
  String subscriptionUpgradeTo(String tier) => 'Upgrade to $tier';
  @override
  String get subscriptionPerks => 'WHAT YOU GET';
  @override
  String get subscriptionEmptyOverline => 'No plan yet';
  @override
  String get subscriptionEmptyTitle => 'Start your pass';
  @override
  String get subscriptionEmptyBlurb =>
      "You haven't picked a tier. Browse the plans and subscribe to unlock every partner gym in the city.";
  @override
  String get subscriptionEmptyCta => 'Browse plans';

  @override
  String get subscriptionPausedBadge => 'FROZEN';
  @override
  String get subscriptionPausedOverline => 'On freeze';
  @override
  String get subscriptionPauseScheduledOverline => 'Freeze scheduled';
  @override
  String subscriptionPausedBody(String untilIso) =>
      'Your plan is frozen through $untilIso. Unfreeze early and any unused days go back to the pool; your renewal shifts only by the days you actually use.';
  @override
  String subscriptionPauseScheduledBody(String fromIso, String untilIso) =>
      "Freeze starts $fromIso and runs through $untilIso. You can still check in until then, and you can cancel the freeze before it begins.";
  @override
  String get subscriptionPauseCta => 'Freeze plan';
  @override
  String get subscriptionResumeCta => 'Unfreeze now';
  @override
  String get subscriptionPauseCancelCta => 'Cancel freeze';
  @override
  String get subscriptionResumeConfirmTitle => 'Unfreeze now?';
  @override
  String get subscriptionResumeConfirmBody =>
      'Your freeze ends today. Unused days return to the pool and your renewal date stays shifted by the days you used.';
  @override
  String get subscriptionPauseCancelTitle => 'Cancel scheduled freeze?';
  @override
  String get subscriptionPauseCancelBody =>
      "The freeze window will be removed and your plan continues normally. You'll keep the days you hadn't used yet.";
  @override
  String get subscriptionResumedSnack => 'Plan unfrozen.';
  @override
  String subscriptionPausedNowSnack(String untilIso) =>
      'Plan frozen through $untilIso.';
  @override
  String subscriptionPauseScheduledSnack(String fromIso) =>
      'Freeze scheduled for $fromIso.';
  @override
  String get subscriptionPauseSheetTitle => 'Freeze subscription';
  @override
  String subscriptionPauseSheetBlurb(int days) =>
      "Your plan allows up to $days days of freeze this term. The freeze is one block — it can't be split. Streaks pause, QR scans prompt you to unfreeze, and renewal shifts by the days you actually use.";
  @override
  String get subscriptionPauseRemainingLabel => 'Days remaining';
  @override
  String subscriptionPauseRemainingValue(int days) => '$days days';
  @override
  String get subscriptionPauseStartDateLabel => 'Start date';
  @override
  String get subscriptionPauseStartNow => 'Start today';
  @override
  String get subscriptionPauseDaysLabel => 'Days';
  @override
  String subscriptionPauseSummary(String fromIso, String untilIso) =>
      'Frozen from $fromIso through $untilIso. Renewal shifts by the same number of days.';
  @override
  String get subscriptionPauseStartSubmit => 'Confirm freeze';
  @override
  String get subscriptionVisitsExhaustedTitle => 'Visits exhausted';
  @override
  String get subscriptionVisitsExhaustedBody =>
      "You've used every visit in this term. Renew now to start a new period — you forfeit any unused days and your visit pool resets.";
  @override
  String get subscriptionRenewNowCta => 'Renew now';
  @override
  String get subscriptionRenewConfirmTitle => 'Start a new term now?';
  @override
  String get subscriptionRenewConfirmBody =>
      'Any remaining days on the current term will be forfeited and a fresh period starts today with a full visit pool.';
  @override
  String get subscriptionRenewedSnack => 'Plan renewed.';

  @override
  String get checkinPausedDialogTitle => "Your plan is frozen";
  @override
  String checkinPausedDialogBody(String gym, String untilIso) =>
      "Your plan is frozen through $untilIso. Unfreeze now to check in at $gym? Unused freeze days go back to the pool.";
  @override
  String get checkinPausedDialogResume => 'Unfreeze now';
  @override
  String get checkinPausedDialogKeep => 'Stay frozen';
  @override
  String get checkinVisitsExhaustedBody =>
      "You've used every visit in this term. Renew now to reset your pool.";

  @override
  String get profileOverline => 'Profile';
  @override
  String get profileMemberSince => 'MEMBER SINCE MAR';
  @override
  String get profileVisitsThisMo => 'VISITS THIS MO';
  @override
  String get profileStreak => 'STREAK';
  @override
  String get profileThisMonth => 'THIS MONTH';
  @override
  String get profileNextTier => 'NEXT TIER';
  @override
  String get profileNextTierMaxed => 'MAX TIER';
  @override
  String get profileNextTierEmpty => 'NO PLAN';
  @override
  String get profileNoPlanChip => 'No active plan';
  @override
  String profileStreakDays(int days) => days == 1 ? '1 DAY' : '$days DAYS';
  @override
  String get profileMenuSubscription => 'My subscription';
  @override
  String get profileMenuFavorites => 'Favorite gyms';
  @override
  String get profileMenuNotifications => 'Notifications';
  @override
  String get favoritesOverline => 'Favorites';
  @override
  String get favoritesHeadline => 'YOUR';
  @override
  String get favoritesHeadlineAccent => 'saved gyms.';
  @override
  String get favoritesEmptyTitle => 'No favorites yet';
  @override
  String get favoritesEmptyBody =>
      'Tap the heart on any gym profile to save it here for quick access.';
  @override
  String get favoritesEmptyCta => 'Browse gyms';
  @override
  String get profileMenuBilling => 'Billing history';
  @override
  String get profileMenuHelp => 'Help & support';
  @override
  String get profileMenuSettings => 'Settings';
  @override
  String get profileMenuInvite => 'Invite a friend';
  @override
  String get profileLogout => 'Log out';

  @override
  String get inviteOverline => 'INVITE A FRIEND';
  @override
  String get inviteHeadline => 'SHARE THE';
  @override
  String get inviteHeadlineAccent => 'pass.';
  @override
  String get inviteBlurb =>
      'Your friends unlock a free week. You earn a reward when they subscribe.';
  @override
  String get inviteYourCode => 'YOUR CODE';
  @override
  String get inviteShareLink => 'SHARE LINK';
  @override
  String get inviteCopyCode => 'Copy';
  @override
  String get inviteShare => 'Share';
  @override
  String get inviteCodeCopied => 'Code copied';
  @override
  String get inviteLinkCopied => 'Link copied';
  @override
  String get inviteCountsPending => 'PENDING';
  @override
  String get inviteCountsConverted => 'CONVERTED';
  @override
  String get inviteCountsExpired => 'EXPIRED';
  @override
  String get inviteListTitle => 'INVITED';
  @override
  String get inviteListEmpty =>
      'No invites yet. Share your code to get started.';
  @override
  String get inviteStatusPending => 'PENDING';
  @override
  String get inviteStatusConverted => 'CONVERTED';
  @override
  String get inviteStatusExpired => 'EXPIRED';
  @override
  String get inviteInvitedBy => 'INVITED BY';
  @override
  String get inviteInvitedByNone => 'Not referred';
  @override
  String get inviteClaimTitle => "GOT A FRIEND'S CODE?";
  @override
  String get inviteClaimBlurb =>
      'Enter their GP-XXXXXX code to credit them for bringing you in.';
  @override
  String get inviteClaimInputLabel => "FRIEND'S CODE";
  @override
  String get inviteClaimInputHint => 'GP-XXXXXX';
  @override
  String get inviteClaimCta => 'Claim code';
  @override
  String inviteClaimSuccess(String name) =>
      'Got it — $name now gets credit for your invite.';
  @override
  String get inviteClaimErrorInvalid => "That doesn't look like a GP code.";
  @override
  String get inviteClaimErrorNotFound => 'No member uses that code.';
  @override
  String get inviteClaimErrorOwnCode => "That's your own code.";
  @override
  String get inviteClaimErrorAlready =>
      "You've already claimed a friend's code.";

  @override
  String get settingsTitle => 'SETTINGS.';
  @override
  String get settingsLanguage => 'LANGUAGE';
  @override
  String get settingsNotifications => 'NOTIFICATIONS';
  @override
  String get settingsAccount => 'ACCOUNT';
  @override
  String get settingsLangArabic => 'العربية';
  @override
  String get settingsLangEnglish => 'English';
  @override
  String get settingsAppearance => 'APPEARANCE';
  @override
  String get settingsThemeLight => 'Light';
  @override
  String get settingsThemeDark => 'Dark';
  @override
  String get settingsNotifPlanReminders => 'Plan reminders';
  @override
  String get settingsNotifNewClubs => 'New clubs near me';
  @override
  String get settingsNotifPromos => 'Promos & offers';
  @override
  String get settingsAccountEditProfile => 'Edit profile';
  @override
  String get settingsAccountSecurity => 'Security & privacy';
  @override
  String get settingsAccountTerms => 'Terms & policies';
  @override
  String get settingsAccountLogout => 'Log out';
  @override
  String get settingsAppVersion => 'GYMPASS v1.0 · MADE IN AMMAN';

  @override
  String get notificationsOverline => "What's new";
  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsHeadline => 'YOUR';
  @override
  String get notificationsHeadlineAccent => 'inbox.';
  @override
  String get notificationsMarkAllRead => 'Mark all read';
  @override
  String get notifFilterAll => 'All';
  @override
  String get notifFilterUnread => 'Unread';
  @override
  String get notifFilterCheckin => 'Check-in';
  @override
  String get notifFilterPromo => 'Promo';

  @override
  String get splashTagline => 'One pass · Every gym';
  @override
  String get splashLoading => 'LOADING';
  @override
  String get splashFooter => 'MADE IN AMMAN · EST 2025';

  @override
  String get gymsMapPreview => 'AMMAN · MAP PREVIEW';

  @override
  String get checkinStepLabel => 'Scan QR · Step 1 of 2';
  @override
  String get checkinAlignTitle => 'ALIGN';
  @override
  String get checkinAlignAccent => 'the code.';
  @override
  String get checkinAlignHintCaps => 'ALIGN QR WITHIN THE FRAME';
  @override
  String get checkinFailedGeneric => 'Check-in failed';

  @override
  String get checkinConfirmHintCaps => 'CONFIRM TO LOG YOUR VISIT';
  @override
  String get checkinConfirmEyebrow => 'QR match';
  @override
  String get checkinConfirmPrompt => "You're checking into";
  @override
  String checkinConfirmCta(String gym) => 'Check in to $gym';
  @override
  String get checkinCancelScan => 'Scan a different QR';
  @override
  String get checkinPassLabel => 'PASS';
  @override
  String get checkinPassEyebrow => 'Access granted';
  @override
  String get checkinEntryDetailsLabel => 'Entry details';
  @override
  String get checkinStatVisitsLeft => 'Visits left';
  @override
  String get checkinStatDaysToRenewal => 'Days to renewal';
  @override
  String get checkinStatThisTerm => 'This term';
  @override
  String checkinLowVisitsWarning(int count) =>
      'Only $count visits left this term — renew before your next scan.';
  @override
  String get checkinViewPlans => 'View plans';

  @override
  String get welcomeOverline => 'You are in';
  @override
  String get welcomeYoureTitle => "YOU'RE";
  @override
  String get welcomeYoureAccent => 'in.';
  @override
  String welcomeSubTier(String tier) => 'Welcome to ${tier.toUpperCase()}.';
  @override
  String welcomeBlurbLong(String visits) =>
      'Your pass is active. $visits visits await across every partnered gym in the network.';
  @override
  String get welcomeFindGym => 'Find your first gym';
  @override
  String get welcomeGoHome => 'Go to home';

  @override
  String get subscriptionVisitLabelCaps => 'VISITS';

  @override
  String get snackErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get demoUserName => 'Guest Member';
  @override
  String profileVisitsCount(int n) => '$n VISITS';

  @override
  String get searchHintHome => 'Search gyms, areas, tiers…';
  @override
  String get favAddedMessage => 'Saved to favorites';
  @override
  String get favRemovedMessage => 'Removed from favorites';
  @override
  String get shareMessage => 'Share link copied';
  @override
  String get filterDialogTitle => 'Refine results';
  @override
  String get filterApply => 'Apply';
  @override
  String get filterReset => 'Reset';
  @override
  String get filterDone => 'Done';
  @override
  String filterMatchCount(int count) => count == 1 ? '1 club matches' : '$count clubs match';
  @override
  String get filterCategory => 'By category';
  @override
  String get filterTier => 'By tier';
  @override
  String get googleSignInMock => 'Google sign-in is mocked in dev — proceeding.';
  @override
  String get googleMockEmail => 'guest@gympass.jo';
  @override
  String get editProfileTitle => 'Edit profile';
  @override
  String get editProfileSave => 'Save';
  @override
  String get editProfileFirstName => 'First name';
  @override
  String get editProfileLastName => 'Last name';
  @override
  String get editProfileEmail => 'Email';
  @override
  String get editProfileSaved => 'Profile updated';
  @override
  String get helpTitle => 'Help & support';
  @override
  String get helpContactSupport => 'Contact support';
  @override
  String get helpFaq => 'FAQ';
  @override
  String get helpReportIssue => 'Report an issue';
  @override
  String get securityTitle => 'Security';
  @override
  String get securityChangePhone => 'Change phone number';
  @override
  String get securitySessions => 'Active sessions';
  @override
  String get termsTitle => 'Terms & Privacy';
  @override
  String get termsBody =>
      'By using GymPass you agree to a single subscription that grants access to every gym in our partner network. Your tier (Silver, Gold, Platinum, Diamond) determines which gyms you can scan into and how many visits per cycle you have. Visits are counted at the moment of QR scan and reset on a 30-day rolling window from your subscription start date. We will not refund unused visits at the end of a cycle. You may cancel auto-renewal at any time and your subscription will remain active until the end of the current billing period. Misuse of the QR — including sharing your account or attempting to bypass tier gates — may result in suspension. We may update these terms with notice via the app. Continued use after a notice constitutes acceptance.';
  @override
  String get privacyPolicyBody =>
      'We collect only the data needed to operate your membership: your phone number, email, name, gender, birthdate, and a hashed password. Each successful check-in stores the gym, timestamp, and your subscription tier in our audit log so partner gyms can be paid correctly and so you can review your visit history. Your phone and email are never shared with partner gyms — they only see your tier and your name at check-in. We use a payment provider to process charges; payment card details never touch our servers. Location data is used only on-device to surface nearby gyms in Explore — we do not store your GPS history. You may request export or deletion of your data at any time from Settings → Privacy. We retain audit-log entries for 24 months for fraud-prevention and accounting; everything else is deleted on account closure within 30 days.';
  @override
  String get logoutConfirmTitle => 'Sign out?';
  @override
  String get logoutConfirmBody =>
      'You will need to verify your phone again to sign back in.';
  @override
  String get logoutConfirmYes => 'Sign out';

  @override
  String get supportOverline => 'GET HELP';
  @override
  String get supportHeadline => "WE'RE HERE";
  @override
  String get supportHeadlineAccent => 'to help.';
  @override
  String get supportBlurb =>
      "Average reply under 4 hours. We're based in Amman.";
  @override
  String get supportChannelsLabel => 'CHANNELS';
  @override
  String get supportChannelCallTitle => 'Call our team';
  @override
  String get supportChannelCallSubtitle => 'Sun–Thu · 9am–7pm';
  @override
  String get supportChannelEmailTitle => 'Email support';
  @override
  String get supportChannelEmailSubtitle => 'support@gym-pass.net';
  @override
  String get supportChannelWhatsappTitle => 'WhatsApp chat';
  @override
  String get supportChannelWhatsappSubtitle => 'Typically replies in 10 min';
  @override
  String get supportSupportPhone => '+962 6 555 0100';
  @override
  String get supportMessageLabel => 'SEND A MESSAGE';
  @override
  String get supportSubjectLabel => 'Subject';
  @override
  String get supportSubjectHint => "What's this about?";
  @override
  String get supportBodyLabel => 'How can we help?';
  @override
  String get supportBodyHint => "Tell us what's going on…";
  @override
  String get supportSendBtn => 'Send message';
  @override
  String get supportSentSnackbar =>
      "Thanks — we'll reply within 24 hours.";
  @override
  String get supportMissingFields =>
      'Please fill in both subject and message.';

  @override
  String get faqOverline => 'KNOWLEDGE BASE';
  @override
  String get faqHeadline => 'FREQUENT';
  @override
  String get faqHeadlineAccent => 'questions.';
  @override
  String get faqBlurb =>
      'Quick answers to what members ask us every day.';
  @override
  String get faqSearchHint => 'Search questions…';
  @override
  String get faqEmpty =>
      'No matching questions. Try different words or contact support.';
  @override
  String get faqContactFooter => "Can't find what you need?";
  @override
  String get faqContactCta => 'Contact support';
  @override
  String get faqCategoryAll => 'All';
  @override
  String get faqCategoryGeneral => 'General';
  @override
  String get faqCategoryBilling => 'Billing';
  @override
  String get faqCategoryCheckin => 'Check-in';
  @override
  String get faqCategoryClasses => 'Classes';
  @override
  String get faqQ1 => 'How does QR check-in work?';
  @override
  String get faqA1 =>
      'Each gym has its own QR. Open the Check-in tab, scan the code at the door, and wait for the confirmation screen. Your visit count updates instantly.';
  @override
  String get faqQ2 => 'Can I switch tiers at any time?';
  @override
  String get faqA2 =>
      'Yes. Upgrades are pro-rated and take effect immediately. Downgrades apply at the next billing cycle.';
  @override
  String get faqQ3 => 'What happens if I miss a month?';
  @override
  String get faqA3 =>
      "Unused visits don't roll over. Your visit count resets at the start of each billing cycle.";
  @override
  String get faqQ5 => 'Which payment methods are accepted?';
  @override
  String get faqA5 =>
      'Visa, Mastercard, CliQ, and Apple Pay. All billing is in JOD.';
  @override
  String get faqQ6 => 'Can I freeze or cancel my subscription?';
  @override
  String get faqA6 =>
      "There's no cancellation flow — you're not locked in. Your plan simply ends on the last day of your current term and you can choose to renew (or not) at any point. Freezing is available on 6- and 12-month plans: Silver gets 10/24 days, Gold 12/26, Platinum 14/28, Diamond 16/30 (6mo/12mo). The freeze is one block that can't be split; 12-month plans can freeze twice. Freeze shifts both your renewal and expiration by the days you actually use.";
  @override
  String get faqQ7 => 'Is my data shared with gyms?';
  @override
  String get faqA7 =>
      'Only what is needed for check-in: your name and tier. Your phone and email never leave our servers.';
  @override
  String get faqQ8 => "What's the difference between tiers?";
  @override
  String get faqA8 =>
      'Every tier gives you 30 visits each month. What changes is the gym network you unlock — Silver covers entry-level gyms, Gold adds Silver + Gold, Platinum adds premium, and Diamond opens every partner gym in the network.';

  @override
  String get reportOverline => 'REPORT A BUG';
  @override
  String get reportHeadline => 'SOMETHING';
  @override
  String get reportHeadlineAccent => 'broken?';
  @override
  String get reportBlurb =>
      'Tell us what went wrong — screenshots help us fix it faster.';
  @override
  String get reportCategoryLabel => 'CATEGORY';
  @override
  String get reportCategoryCheckin => 'Check-in';
  @override
  String get reportCategoryPayment => 'Payment';
  @override
  String get reportCategoryApp => 'App / UI';
  @override
  String get reportCategoryAccount => 'Account';
  @override
  String get reportCategoryOther => 'Other';
  @override
  String get reportGymLabel => 'Gym (optional)';
  @override
  String get reportGymHint => 'Which gym?';
  @override
  String get reportDescLabel => 'What happened?';
  @override
  String get reportDescHint => 'Step-by-step if you can…';
  @override
  String get reportAttachLabel => 'Attachment (optional)';
  @override
  String get reportAttachPlaceholder => 'Attach a screenshot';
  @override
  String get reportAttachAttached => 'Screenshot attached · tap to remove';
  @override
  String get reportSubmitBtn => 'Send report';
  @override
  String get reportSubmittedTitle => 'Report received';
  @override
  String reportSubmittedBody(String ref) =>
      'Thanks for the heads-up. Your reference number is $ref — we will follow up by email.';
  @override
  String get reportSubmittedClose => 'Close';
  @override
  String get reportMissingFields =>
      'Please pick a category and describe the issue.';

  @override
  String get billingOverline => 'Billing · payments';
  @override
  String get billingHeadline => 'YOUR';
  @override
  String get billingHeadlineAccent => 'billing.';
  @override
  String get billingBlurb =>
      'Manage payment methods, review invoices, and track what is next on your pass.';
  @override
  String get billingMethodsLabel => 'PAYMENT METHODS';
  @override
  String get billingMethodsEmpty =>
      'No payment method yet. Add one to keep your pass active.';
  @override
  String get billingAddMethod => 'Add method';
  @override
  String get billingSetDefault => 'Set default';
  @override
  String get billingDefaultChip => 'Default';
  @override
  String get billingRemoveMethod => 'Remove';
  @override
  String billingRemoveConfirmBody(String label) =>
      'Remove $label from your saved payment methods?';
  @override
  String get billingRemoveConfirmTitle => 'Remove method';
  @override
  String get billingRemoveConfirmYes => 'Remove';
  @override
  String get billingAddTitle => 'Add payment method';
  @override
  String get billingAddCard => 'Card (Visa / Mastercard)';
  @override
  String get billingAddCliq => 'CliQ';
  @override
  String get billingAddApple => 'Apple Pay';
  @override
  String get billingAddGoogle => 'Google Pay';
  @override
  String get billingAddSaveBtn => 'Save method';
  @override
  String get billingAddCardSection => 'Card details';
  @override
  String get billingAddCliqSection => 'CliQ details';
  @override
  String get billingAddApplePaySection => 'Apple Pay';
  @override
  String get billingAddGooglePaySection => 'Google Pay';
  @override
  String get billingAddCardNumberLabel => 'CARD NUMBER';
  @override
  String get billingAddCardNumberHint => '4242 4242 4242 4242';
  @override
  String get billingAddExpiryLabel => 'EXPIRY';
  @override
  String get billingAddExpiryHint => 'MM / YY';
  @override
  String get billingAddCvvLabel => 'CVV';
  @override
  String get billingAddCvvHint => '123';
  @override
  String get billingAddHolderLabel => 'CARDHOLDER NAME';
  @override
  String get billingAddHolderHint => 'Name as printed on card';
  @override
  String get billingAddCliqAliasLabel => 'CLIQ ALIAS';
  @override
  String get billingAddCliqAliasHint => 'e.g. omar.jo';
  @override
  String get billingAddCliqPhoneLabel => 'CLIQ PHONE';
  @override
  String get billingAddCliqPhoneHint => '+962 7X XXX XXXX';
  @override
  String get billingAddCliqModeAlias => 'Alias';
  @override
  String get billingAddCliqModePhone => 'Phone';
  @override
  String get billingAddApplePayBlurb =>
      'Connect Apple Pay to pay with Face ID or Touch ID. Your card stays in the Wallet — we only receive a payment token.';
  @override
  String get billingAddApplePayConnect => 'Connect Apple Pay';
  @override
  String get billingAddApplePayConnecting => 'Connecting to Wallet…';
  @override
  String get billingAddApplePayConnected => 'Apple Pay connected';
  @override
  String get billingAddGooglePayBlurb =>
      'Connect Google Pay to pay with your fingerprint or device unlock. Your card stays in Google Wallet — we only receive a payment token.';
  @override
  String get billingAddGooglePayConnect => 'Connect Google Pay';
  @override
  String get billingAddGooglePayConnecting => 'Connecting to Google Wallet…';
  @override
  String get billingAddGooglePayConnected => 'Google Pay connected';
  @override
  String get billingAddErrCardNumber =>
      'Enter a valid 13–19 digit card number.';
  @override
  String get billingAddErrExpiry => 'Expiry must be a future MM/YY date.';
  @override
  String get billingAddErrCvv => 'CVV must be 3 or 4 digits.';
  @override
  String get billingAddErrHolder => 'Enter the cardholder\'s name.';
  @override
  String get billingAddErrCliq =>
      'Enter a valid CliQ alias or Jordanian phone number.';
  @override
  String get billingAddErrApplePay =>
      'Tap "Connect Apple Pay" to finish linking your wallet.';
  @override
  String get billingAddErrGooglePay =>
      'Tap "Connect Google Pay" to finish linking your wallet.';
  @override
  String get billingMethodAdded => 'Payment method added.';
  @override
  String get billingMethodRemoved => 'Payment method removed.';
  @override
  String get billingDefaultUpdated => 'Default payment method updated.';
  @override
  String get billingNextChargeLabel => 'NEXT CHARGE';
  @override
  String billingNextChargeBody(String date, int amount) =>
      '$date · $amount JOD';
  @override
  String get billingHistoryLabel => 'INVOICE HISTORY';
  @override
  String get billingHistoryEmpty => 'No invoices yet.';
  @override
  String billingInvoicePaid(String iso, int amount) => '$iso · $amount JOD';
  @override
  String get billingInvoiceReceipt => 'Receipt';
  @override
  String get billingCardNetworkVisa => 'Visa';
  @override
  String get billingCardNetworkMastercard => 'Mastercard';
  @override
  String get billingCardNetworkCliq => 'CliQ';
  @override
  String get billingCardNetworkApple => 'Apple Pay';
  @override
  String get billingCardNetworkGoogle => 'Google Pay';

  @override
  String get securityBlurb =>
      'Change your phone, enable biometric sign-in, and review where you\'re signed in.';
  @override
  String get securityChangePhoneDesc => 'Swap the phone number on your pass.';
  @override
  String get securitySessionsDesc =>
      'See devices currently signed in and revoke any you don\'t recognize.';
  @override
  String get securityChangePhoneTitle => 'Change phone number';
  @override
  String get securityChangePhoneNewLabel => 'New phone number';
  @override
  String get securityChangePhoneOtpNote =>
      'We\'ll send a verification code to confirm the new number.';
  @override
  String get securityChangePhoneSubmit => 'Send code';
  @override
  String get securityChangePhoneSuccess =>
      'Verification sent. Check your SMS.';
  @override
  String get securityChangePhoneInvalid => 'Enter a valid phone number.';
  @override
  String get securityChangePhoneOtpTitle => 'Verify your number';
  @override
  String securityChangePhoneOtpSubtitle(String phone) =>
      'Enter the 4-digit code we sent to $phone.';
  @override
  String get securityChangePhoneVerifyBtn => 'Verify';
  @override
  String get securityChangePhoneOtpError =>
      'Code is invalid or expired.';
  @override
  String get securityChangePhoneInUse =>
      'This phone is already in use by another account.';
  @override
  String get securitySessionsTitle => 'Active sessions';
  @override
  String get securitySessionsThisDevice => 'This device';
  @override
  String get securitySessionsActive => 'Active now';
  @override
  String get securitySessionsRevoke => 'Revoke';
  @override
  String get securitySessionsRevoked => 'Session revoked.';
  @override
  String get securitySessionsRevokeAll => 'Sign out all others';
  @override
  String securitySessionsLastActive(String when) => 'Last active $when';

  @override
  String get helpOverline => 'Help · support';
  @override
  String get helpHeadline => 'HOW CAN WE';
  @override
  String get helpHeadlineAccent => 'help?';
  @override
  String get helpBlurb =>
      'Talk to a human, skim the FAQ, or send us a report — we are on it.';
  @override
  String get helpContactSupportDesc =>
      'Call, email, or WhatsApp — the team answers during the day.';
  @override
  String get helpFaqDesc => 'Quick answers to the questions members ask most.';
  @override
  String get helpReportIssueDesc =>
      'Something broken? File a report and we will follow up by email.';

  @override
  String get supportEmail => 'support@gym-pass.net';
  @override
  String get supportWhatsapp => '+962 7 9000 0100';
  @override
  String supportChannelCopied(String value) => 'Copied $value to clipboard.';
  @override
  String supportSentWithRef(String ref) =>
      'Thanks — ticket $ref. We will reply within 24 hours.';
  @override
  String get supportSubmittedTitle => 'Message received';

  @override
  String get reportAttachPickerTitle => 'Attach evidence';
  @override
  String get reportAttachScreenshot => 'Recent screenshot';
  @override
  String get reportAttachCameraRoll => 'Photo from camera roll';
  @override
  String get reportAttachPhoto => 'Take a photo';
  @override
  String get reportAttachRemove => 'Remove attachment';

  @override
  String get billingReceiptTitle => 'Receipt';
  @override
  String get billingReceiptItemsLabel => 'LINE ITEMS';
  @override
  String get billingReceiptLineBase => 'Monthly pass';
  @override
  String billingReceiptLineTax(int amount) => 'VAT · $amount JOD';
  @override
  String get billingReceiptTotalLabel => 'TOTAL';
  @override
  String get billingReceiptSendEmail => 'Send to email';
  @override
  String get billingReceiptEmailQueued =>
      'Receipt queued — emailed within a minute.';
  @override
  String get billingReceiptCloseBtn => 'Close';

  @override
  String securityChangePhoneUpdated(String phone) =>
      'Phone updated to $phone.';

  @override
  String get forgotOverline => 'Password reset';
  @override
  String get forgotTitle => 'RESET';
  @override
  String get forgotTitleAccent => 'your password.';
  @override
  String get forgotStep1 => 'Step 1 of 3 — Choose method';
  @override
  String get forgotStep2 => 'Step 2 of 3 — Enter code';
  @override
  String get forgotStep3 => 'Step 3 of 3 — New password';
  @override
  String get forgotBlurb1 =>
      "Pick how you'd like to receive the 4-digit code.";
  @override
  String get forgotMethodSmsTitle => 'Text me a code';
  @override
  String forgotMethodSmsSubtitle(String phone) => 'Sent to $phone';
  @override
  String get forgotMethodEmailTitle => 'Email me a code';
  @override
  String forgotMethodEmailSubtitle(String email) => 'Sent to $email';
  @override
  String get forgotMethodEmailMissing => 'No email on file. Use SMS instead.';
  @override
  String get forgotSendCode => 'Send code';
  @override
  String forgotCodeBlurb(String target) =>
      'We sent a 4-digit code to $target. Enter it below.';
  @override
  String get forgotResendCode => 'Send it again';
  @override
  String get forgotVerifyCode => 'Verify code';
  @override
  String get forgotNewPasswordBlurb =>
      "Pick a new password. You'll use it to sign in from now on.";
  @override
  String get forgotSetNewPassword => 'Update password';
  @override
  String get forgotResetSuccess =>
      'Password updated. You can sign in with the new one.';
  @override
  String get forgotErrAccountMissing => 'No account on file for that number.';
  @override
  String get forgotErrCodeInvalid => "That code doesn't match. Try again.";
  @override
  String get forgotDevHint =>
      'Dev mode: any 4-digit code works, but 1234 is the canonical one.';

  @override
  String get securityBiometricTitle => 'Sign in with biometrics';
  @override
  String get securityBiometricDesc =>
      'Use Face ID, fingerprint, or your device PIN instead of typing your password.';
  @override
  String get securityBiometricNoPassword =>
      'Set a password first to enable biometric sign-in.';
  @override
  String get securityBiometricUnavailable =>
      "This device doesn't have biometrics or a screen lock set up.";
  @override
  String get biometricEnrollTitle => 'Confirm your password';
  @override
  String biometricEnrollBlurb(String biometric) =>
      'Re-enter your password so we can save it behind $biometric.';
  @override
  String get biometricEnrollPasswordLabel => 'PASSWORD';
  @override
  String get biometricEnrollPasswordHint => 'Enter your password';
  @override
  String get biometricEnrollSubmit => 'Confirm';
  @override
  String get biometricUnlockReason => 'Unlock GymPass to sign in';
  @override
  String get biometricEnrollReason => 'Confirm to save your sign-in';
  @override
  String get biometricSignInBtn => 'Sign in with biometrics';
  @override
  String get biometricEnabled => 'Biometric sign-in is on.';
  @override
  String get biometricDisabled => 'Biometric sign-in is off.';
  @override
  String get biometricCancelled => 'Biometric prompt cancelled.';
  @override
  String get biometricGenericLabel => 'biometrics';

  @override
  String get billingNoSubscriptionTitle => 'No active subscription';
  @override
  String get billingNoSubscriptionBlurb =>
      "You don't have a plan right now, so there's nothing scheduled to charge. Pick a tier to start scanning into partner gyms.";
  @override
  String get billingNoSubscriptionCta => 'Browse plans';

  @override
  String get gymNotFoundTitle => 'Gym not found';
  @override
  String gymNotFoundBody(String slug) =>
      'We could not find a gym matching "$slug". It may have been removed.';
  @override
  String get gymNotFoundBackToExplore => 'Back to explore';
}
