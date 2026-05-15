// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get signInStep => 'أهلاً بك — الخطوة 1 من 3';

  @override
  String get signInHeadline1 => 'اشتراك واحد،';

  @override
  String get signInHeadline2 => 'كل';

  @override
  String get signInHeadlineAccent => 'النوادي.';

  @override
  String get signInBlurb => 'تدرّب في أيّ نادٍ ضمن الشبكة. اشتراك واحد. تُفتح الأبواب بمسح رمز QR.';

  @override
  String get signInOtpNote => 'سنرسل لك رمزاً مكوّناً من 4 أرقام. بدون رسائل مزعجة.';

  @override
  String get signInContinueWithGoogle => 'المتابعة بواسطة Google';

  @override
  String get signInPasswordLabel => 'كلمة المرور';

  @override
  String get signInPasswordHint => 'أدخل كلمة المرور';

  @override
  String get signInPasswordNote => 'مرحباً بعودتك. أدخل كلمة المرور التي اخترتها عند التسجيل.';

  @override
  String get signInWithPasswordCta => 'تسجيل الدخول';

  @override
  String get signInRememberMe => 'تذكّرني';

  @override
  String get signInForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get signInCheckingNumber => 'جارٍ التحقق من رقمك…';

  @override
  String get errorPasswordInvalid => 'كلمة مرور خاطئة. حاول مجدداً.';

  @override
  String get errorRequiredFields => 'يرجى تعبئة جميع الحقول المطلوبة.';

  @override
  String get errorInvalidInput => 'بعض الحقول غير صحيحة. تحقق وحاول مجدداً.';

  @override
  String get errorPasswordSignInRequired => 'أدخل كلمة المرور';

  @override
  String get errorOtpLocked => 'محاولات كثيرة. حاول بعد دقيقة.';

  @override
  String get errorOtpInvalid => 'الرمز غير صحيح. حاول مجدداً.';

  @override
  String get errorNetwork => 'خطأ في الشبكة. تحقق من اتصالك وحاول مجدداً.';

  @override
  String get orDivider => 'أو';

  @override
  String get phoneCountryPrefix => '+962';

  @override
  String get phoneHint => '7X XXX XXXX';

  @override
  String get errorPhoneRequired => 'يرجى إدخال رقم الهاتف';

  @override
  String get errorPhoneInvalid => 'رقم غير صالح';

  @override
  String get otpSentTo => 'أرسلنا رمزاً إلى';

  @override
  String get otpResend => 'إعادة إرسال الرمز';

  @override
  String otpResendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String get otpDevHint => 'في وضع التطوير استخدم 1234';

  @override
  String get errorOtpIncomplete => 'الرجاء إدخال الرمز المكوّن من 4 أرقام';

  @override
  String get registerStep => 'الخطوة 3 من 3 — الملف الشخصي';

  @override
  String get registerTitle => 'مستخدم';

  @override
  String get registerTitleAccent => 'جديد.';

  @override
  String get registerBlurb => 'أخبرنا باسمك وبريدك لنخصّص بطاقتك.';

  @override
  String get labelFirstName => 'الاسم الأول';

  @override
  String get labelLastName => 'اسم العائلة';

  @override
  String get labelEmail => 'البريد الإلكتروني';

  @override
  String get labelPassword => 'كلمة المرور';

  @override
  String get labelPasswordConfirm => 'تأكيد كلمة المرور';

  @override
  String get labelBirthdate => 'تاريخ الميلاد';

  @override
  String get hintFirstName => 'مثال: ليلى';

  @override
  String get hintLastName => 'مثال: حدّاد';

  @override
  String get hintEmail => 'username@domain.com';

  @override
  String get hintBirthdate => 'اليوم / الشهر / السنة';

  @override
  String get birthdateHelpText => 'اختر تاريخ ميلادك';

  @override
  String get hintPassword => '٨ أحرف على الأقل';

  @override
  String get hintPasswordConfirm => 'أعد إدخال كلمة المرور';

  @override
  String get agreementText => 'أوافق على';

  @override
  String get terms => 'الشروط';

  @override
  String get and => 'و';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsBody => 'باستخدامك لتطبيق GymPass فإنك توافق على اشتراك واحد يمنحك الوصول إلى جميع النوادي ضمن شبكة الشركاء. تحدد باقتك (فضية، ذهبية، بلاتينية، ماسية) النوادي التي يمكنك دخولها وعدد الزيارات في كل دورة. تُحتسب الزيارات لحظة مسح رمز QR، وتُعاد كل 30 يوماً اعتباراً من تاريخ بدء اشتراكك. لا نقوم باسترداد الزيارات غير المستخدمة في نهاية الدورة. يمكنك إيقاف التجديد التلقائي في أي وقت، وسيبقى اشتراكك فعّالاً حتى نهاية فترة الفوترة الحالية. أي إساءة لاستخدام رمز QR — بما في ذلك مشاركة حسابك أو محاولة تجاوز قيود الباقات — قد تؤدي إلى تعليق الحساب. قد نقوم بتحديث هذه الشروط مع إشعارك عبر التطبيق، ويُعدّ استمرارك في الاستخدام بعد الإشعار قبولاً للتحديث.';

  @override
  String get privacyPolicyBody => 'نجمع فقط البيانات اللازمة لتشغيل عضويتك: رقم هاتفك، بريدك الإلكتروني، اسمك، جنسك، تاريخ ميلادك، وكلمة مرور مشفّرة. تُسجَّل كل عملية تسجيل دخول ناجحة (النادي، الوقت، باقة اشتراكك) في سجل التدقيق لدفع مستحقات النوادي الشريكة بشكل صحيح ولتمكينك من مراجعة سجل زياراتك. لا تتم مشاركة هاتفك أو بريدك مع النوادي الشريكة — يرون فقط باقتك واسمك عند الدخول. نستخدم مزوّد دفع لمعالجة الفواتير، ولا تصل بيانات بطاقتك إلى خوادمنا. تُستخدم بيانات الموقع على جهازك فقط لعرض النوادي القريبة في صفحة الاستكشاف — لا نحتفظ بسجل GPS الخاص بك. يمكنك طلب تصدير بياناتك أو حذفها في أي وقت من الإعدادات ← الخصوصية. نحتفظ بسجلات التدقيق لمدة 24 شهراً لأغراض مكافحة الاحتيال والمحاسبة؛ ما عدا ذلك يُحذف خلال 30 يوماً من إغلاق الحساب.';

  @override
  String get createMyPass => 'أنشئ حسابي';

  @override
  String get errorFirstNameRequired => 'الاسم الأول مطلوب';

  @override
  String get errorLastNameRequired => 'اسم العائلة مطلوب';

  @override
  String get errorEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get errorEmailInvalid => 'صيغة البريد الإلكتروني غير صحيحة';

  @override
  String get errorPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get errorPasswordTooShort => 'يجب أن تكون كلمة المرور ٨ أحرف على الأقل';

  @override
  String get errorPasswordWeak => 'يجب أن تحتوي على حرف ورقم على الأقل';

  @override
  String get errorPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get errorAgreementRequired => 'عليك الموافقة للمتابعة';

  @override
  String get errorBirthdateRequired => 'يرجى اختيار تاريخ الميلاد';

  @override
  String get labelGender => 'الجنس';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get errorGenderRequired => 'يرجى اختيار الجنس';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get confirm => 'تأكيد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String homeGreetingName(String name) {
    return '$name،';
  }

  @override
  String get homeGreetingFallback => 'مرحبًا،';

  @override
  String get homeHeadlineLine1 => 'هيا';

  @override
  String get homeHeadlineAccent => 'الآن.';

  @override
  String get homeActive => 'نشط';

  @override
  String get homeVisits => 'زيارات';

  @override
  String homeLeftThisCycle(int n) {
    return 'ضل لك $n زيارة';
  }

  @override
  String homeCycleProgress(int cycle, int total, int days) {
    return 'الشهر $cycle من $total · تجديد الدورة بعد $days يوم';
  }

  @override
  String homeTermEndsIn(int days) {
    return 'تجديد الاشتراك بعد $days يوم';
  }

  @override
  String get homeManage => 'تعديل';

  @override
  String get homeNoPlanOverline => 'لسا ما اشتركت';

  @override
  String get homeNoPlanTitle => 'اختر اشتراكك';

  @override
  String get homeNoPlanBlurb => 'اختار باقة وافتح أبواب صالات المدينة. الاشتراك يبدأ لحظة الدفع.';

  @override
  String get homeNoPlanCta => 'شوف الباقات';

  @override
  String get homeNearYou => 'قريبة منك';

  @override
  String get homeNoGymsYet => 'لا توجد أندية شريكة في الشبكة بعد. اسحب للتحديث.';

  @override
  String get homeCategories => 'الأنواع';

  @override
  String get categoryGym => 'جيم';

  @override
  String get categoryCross => 'كروس';

  @override
  String get categoryMartial => 'قتال';

  @override
  String get categoryYoga => 'يوغا';

  @override
  String clubsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n نادٍ',
      many: '$n نادياً',
      few: '$n أندية',
      two: 'ناديان',
      one: 'نادٍ واحد',
      zero: 'لا أندية',
    );
    return '$_temp0';
  }

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabGyms => 'الأندية';

  @override
  String get tabExplore => 'استكشف';

  @override
  String get exploreOverline => 'استكشف';

  @override
  String get exploreViewProfile => 'الملف الشخصي';

  @override
  String get exploreSearchHint => 'ابحث عن نادٍ أو منطقة';

  @override
  String exploreSearchEmpty(String query) {
    return 'لا نتائج لـ \"$query\".';
  }

  @override
  String exploreCountStrip(int shown, int total) {
    return '$shown من $total نادٍ مطابق';
  }

  @override
  String exploreDistanceKm(String km) {
    return '$km كم';
  }

  @override
  String exploreGymCount(int n) {
    return '$n نادٍ';
  }

  @override
  String get exploreOneGymCount => 'نادٍ واحد';

  @override
  String get exploreSelectedGymHeader => 'تم التحديد';

  @override
  String get exploreSelectedViewProfile => 'عرض الملف';

  @override
  String exploreShowAllGyms(int n) {
    return 'عرض الكل ($n)';
  }

  @override
  String get exploreNoMatches => 'لا توجد نوادٍ مطابقة للفلاتر الحالية.';

  @override
  String get exploreFiltersTitle => 'الفلاتر';

  @override
  String get exploreFiltersReset => 'إعادة تعيين';

  @override
  String get exploreFiltersDone => 'تم';

  @override
  String get exploreFiltersCategorySection => 'الفئة';

  @override
  String get exploreFiltersTierSection => 'الباقة';

  @override
  String get exploreFiltersFavoritesLabel => 'عرض المفضلة فقط';

  @override
  String get exploreLocateServiceDisabled => 'فعّل خدمات الموقع من إعدادات الجهاز لتحديد موقعك.';

  @override
  String get exploreLocatePermissionDenied => 'إذن الموقع مطلوب لتوسيط الخريطة على موقعك.';

  @override
  String get exploreLocatePermissionDeniedForever => 'تم رفض إذن الموقع. اضغط على الإعدادات لتفعيله.';

  @override
  String get exploreLocateOpenSettings => 'الإعدادات';

  @override
  String get exploreLocateUnavailable => 'تعذّر تحديد موقعك. حاول مجددًا بعد قليل.';

  @override
  String get gymsCategoryAll => 'الكل';

  @override
  String get gymsCategoryGym => 'صالة';

  @override
  String get gymsCategoryCrossfit => 'كروسفت';

  @override
  String get gymsCategoryMartial => 'فنون قتالية';

  @override
  String get gymsCategoryYoga => 'يوغا';

  @override
  String get tabScan => 'مسح';

  @override
  String get tabProfile => 'الملف';

  @override
  String get gymsTitle => 'تصفّح الأندية';

  @override
  String get gymsHeadline => 'كل';

  @override
  String get gymsHeadlineAccent => 'نادٍ.';

  @override
  String get gymsSearchHint => 'ابحث باسم النادي أو المنطقة';

  @override
  String get gymsFilterAll => 'الكل';

  @override
  String get gymsFilterGym => 'جيم';

  @override
  String get gymsFilterCrossfit => 'كروس فت';

  @override
  String get gymsFilterMartial => 'فنون قتالية';

  @override
  String get gymsFilterYoga => 'يوغا';

  @override
  String get gymsEmpty => 'لا توجد نتائج مطابقة';

  @override
  String get gymsEmptyFavorites => 'لم تحفظ أي نادٍ بعد — اضغط القلب على بطاقة النادي ليظهر هنا.';

  @override
  String get gymOpen247 => 'مفتوح 24/7';

  @override
  String gymKmAway(String km) {
    return '$km كم';
  }

  @override
  String get gymAbout => 'نبذة';

  @override
  String get gymAmenityWifi => 'واي فاي';

  @override
  String get gymAmenityParking => 'موقف';

  @override
  String get gymAmenityShowers => 'حمّامات';

  @override
  String get gymAmenityLockers => 'خزائن';

  @override
  String get gymAmenityChangingRooms => 'غرف تغيير';

  @override
  String get gymAmenityTowels => 'مناشف';

  @override
  String get gymAmenityWaterFountain => 'ماء';

  @override
  String get gymAmenityAc => 'تكييف';

  @override
  String get gymAmenityFreeWeights => 'أوزان';

  @override
  String get gymAmenityCardioMachines => 'كارديو';

  @override
  String get gymAmenitySauna => 'ساونا';

  @override
  String get gymAmenityPool => 'مسبح';

  @override
  String get gymAmenitySteamRoom => 'بخار';

  @override
  String get gymAmenityGroupClasses => 'حصص';

  @override
  String get gymAmenityPersonalTraining => 'مدرّب';

  @override
  String get gymAmenityKidsArea => 'أطفال';

  @override
  String get gymAmenityWomenOnlyArea => 'للنساء';

  @override
  String get gymAmenityPrayerRoom => 'مصلّى';

  @override
  String get gymAmenityJuiceBar => 'بار عصائر';

  @override
  String get gymAmenityWheelchairAccess => 'وصول';

  @override
  String get gymCheckInHere => 'سجّل حضورك هنا';

  @override
  String get gymCheckedInRecently => 'تم تسجيل الحضور · الباس فعّال';

  @override
  String gymUpgradeTo(String tier) {
    return 'ترقية إلى $tier';
  }

  @override
  String get gymAccessIncluded => 'متضمّن في اشتراكك';

  @override
  String gymAccessRequiresTier(String tier) {
    return 'يتطلّب اشتراك $tier';
  }

  @override
  String gymDescriptionFallback(String area) {
    return 'مساحة تدريب متكاملة في $area. معدّات حديثة، أجواء منظمة، ودخول 24/7 لأعضاء جيم باس.';
  }

  @override
  String get checkinSuccess => 'تم تسجيل الحضور';

  @override
  String get checkinDemoButton => 'تجربة المسح';

  @override
  String get checkinLockedBannerTitle => 'وضع المعاينة';

  @override
  String get checkinLockedBannerBody => 'لا توجد لديك باقة مفعّلة بعد. مسح رمز أي صالة يفتح ملفها لمعاينة الوصول؛ يُفعَّل تسجيل الحضور بعد الاشتراك.';

  @override
  String get checkinSeePlansCta => 'عرض الباقات';

  @override
  String get checkinConfirmHintCaps => 'أكّد لتسجيل زيارتك';

  @override
  String get checkinConfirmEyebrow => 'تم التعرّف على الرمز';

  @override
  String get checkinConfirmPrompt => 'أنت على وشك الدخول إلى';

  @override
  String checkinConfirmCta(String gym) {
    return 'سجّل الدخول إلى $gym';
  }

  @override
  String get checkinCancelScan => 'مسح رمز آخر';

  @override
  String get checkinPassLabel => 'مرور';

  @override
  String get checkinPassEyebrow => 'تم منح الدخول';

  @override
  String get checkinEntryDetailsLabel => 'تفاصيل الدخول';

  @override
  String get checkinStatVisitsLeft => 'الزيارات المتبقية';

  @override
  String get checkinStatDaysToRenewal => 'أيام حتى التجديد';

  @override
  String get checkinStatThisTerm => 'هذه الدورة';

  @override
  String checkinLowVisitsWarning(int count) {
    return 'تبقّى $count زيارة في هذه الدورة — جدّد قبل المسح القادم.';
  }

  @override
  String get checkinViewPlans => 'عرض الباقات';

  @override
  String get checkinBackHome => 'العودة للرئيسية';

  @override
  String get checkinVisitGym => 'عرض النادي';

  @override
  String get checkinSuccessTitle => 'أنت';

  @override
  String get checkinSuccessTitleAccent => 'داخل.';

  @override
  String visitsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زيارة متبقية',
      many: '$count زيارة متبقية',
      few: '$count زيارات متبقية',
      two: 'زيارتان متبقيتان',
      one: 'زيارة واحدة متبقية',
      zero: 'لا زيارات متبقية',
    );
    return '$_temp0';
  }

  @override
  String get tierSilver => 'فضي';

  @override
  String get tierGold => 'ذهبي';

  @override
  String get tierPlatinum => 'بلاتيني';

  @override
  String get tierDiamond => 'ماسي';

  @override
  String get plansTitle => 'اختر';

  @override
  String get plansTitleAccent => 'باقتك.';

  @override
  String get plansOverline => 'اختر باقتك';

  @override
  String plansContinueWith(String tier) {
    return 'كمّل بـ$tier';
  }

  @override
  String plansSubscribeTo(String tier) {
    return 'اشترك بـ$tier';
  }

  @override
  String get plansSkipForNow => 'تخطَّ هلق';

  @override
  String get plansVisitsPerMonth => 'زيارة/شهر';

  @override
  String get plansUnlimited => 'غير محدود';

  @override
  String get plansPerMonth => 'د.أ/شهر';

  @override
  String get plansDurationHeading => 'مدة الاشتراك';

  @override
  String get plansDurationSwipeHint => 'اسحب لتشوف السنة كاملة';

  @override
  String get plansDuration1Month => 'شهر';

  @override
  String get plansDuration3Months => '3 شهور';

  @override
  String get plansDuration6Months => '6 شهور';

  @override
  String get plansDuration12Months => 'سنة';

  @override
  String plansDurationSave(int percent) {
    return 'وفّر $percent٪';
  }

  @override
  String plansDurationTotal(int amount) {
    return 'الإجمالي $amount د.أ';
  }

  @override
  String plansVisitsIncluded(int count) {
    return '$count زيارة مشمولة';
  }

  @override
  String plansFeaturePauseSingle(int days) {
    return 'جمّد اشتراكك $days يوم وكمّل عادي';
  }

  @override
  String plansFeaturePauseSplit(int days, int count) {
    return 'جمّد اشتراكك $count مرات وكمّل عادي بعدها';
  }

  @override
  String get plansTapToExpand => 'اضغط لتشوف التفاصيل';

  @override
  String plansNetworkCount(int count) {
    return '+$count نادٍ';
  }

  @override
  String plansStartsFrom(int amount) {
    return 'ابتداءً من $amount د.أ/شهر';
  }

  @override
  String plansDurationCardPerMonth(int amount) {
    return '$amount/شهر';
  }

  @override
  String plansNetworkSheetTitle(String tier) {
    return 'شبكة باقة $tier';
  }

  @override
  String get plansNetworkSheetBody => 'مسح QR واحد لكل نادٍ يومياً. زياراتك الـ30 الشهرية تعمل عبر كامل الشبكة.';

  @override
  String get plansNetworkVisitsBadge => '30/شهر';

  @override
  String get plansNetworkClose => 'تم';

  @override
  String get plansNetworkEmpty => 'سيتم إطلاق شركاء الشبكة قريباً.';

  @override
  String get plansCurrentPlan => 'الباقة الحالية';

  @override
  String get plansPickUpgrade => 'اختر باقة أعلى';

  @override
  String plansScheduleDowngradeTo(Object tier) {
    return 'التبديل إلى $tier عند التجديد';
  }

  @override
  String get plansCurrentPlanCta => 'هذه باقتك الحالية';

  @override
  String get plansCancelScheduledChange => 'إلغاء التبديل المجدول';

  @override
  String get plansScheduledBadge => 'مجدول';

  @override
  String plansScheduledFor(Object date) {
    return 'يبدأ $date';
  }

  @override
  String get plansDowngradeConfirmTitle => 'جدولة خفض الباقة؟';

  @override
  String plansDowngradeConfirmBody(Object date, Object tier) {
    return 'ستحتفظ بمزاياك الحالية حتى $date. عند التجديد، ستتحول باقتك إلى $tier وتتعدل الفوترة وفقاً لذلك.';
  }

  @override
  String plansScheduledSnack(Object date, Object tier) {
    return 'تم جدولة التبديل إلى $tier في $date.';
  }

  @override
  String get plansScheduledCancelledSnack => 'تم إلغاء التبديل المجدول.';

  @override
  String plansUpgradeTo(String tier) {
    return 'الترقية إلى $tier';
  }

  @override
  String get plansUpgradeConfirmTitle => 'تأكيد الترقية؟';

  @override
  String plansUpgradeConfirmBody(String tier, String duration) {
    return 'ستتم ترقيتك إلى $tier لمدة $duration. ستُفعَّل الباقة الجديدة من الزيارة القادمة وتبدأ دورة فوترة جديدة من اليوم.';
  }

  @override
  String plansSwitchPeriodTo(String duration) {
    return 'التبديل إلى $duration عند التجديد';
  }

  @override
  String get plansPeriodChangeConfirmTitle => 'جدولة تغيير المدة؟';

  @override
  String plansPeriodChangeConfirmBody(String duration, String date) {
    return 'ستستمر باقتك الحالية حتى $date. عند التجديد، سيتغير الالتزام إلى $duration وتتعدل الفوترة وفقاً لذلك.';
  }

  @override
  String plansPeriodScheduledSnack(String duration, String date) {
    return 'سيتم التبديل إلى $duration في $date.';
  }

  @override
  String plansExtendTo(String duration) {
    return 'التمديد إلى $duration';
  }

  @override
  String get plansExtendConfirmTitle => 'تمديد باقتك؟';

  @override
  String plansExtendConfirmBody(String duration, String renewDate) {
    return 'ثبّت $duration الآن — ستدفع الفارق فقط. سيتحول موعد التجديد إلى $renewDate وتنتقل الزيارات المستخدمة في هذه الدورة معك.';
  }

  @override
  String plansExtendedSnack(String renewDate) {
    return 'تم تمديد الباقة — تجديد في $renewDate.';
  }

  @override
  String get checkoutTitle => 'تأكيد';

  @override
  String get checkoutTitleAccent => 'والدفع.';

  @override
  String get checkoutOverline => 'دفع آمن';

  @override
  String checkoutPayAmount(int amount) {
    return 'ادفع $amount د.أ';
  }

  @override
  String get checkoutPayingOverlay => 'جاري معالجة الدفع';

  @override
  String get checkoutOneMonth => 'شهر واحد';

  @override
  String checkoutDurationSummary(int months) {
    return '$months شهور';
  }

  @override
  String get checkoutDurationYear => 'سنة';

  @override
  String checkoutDiscount(int percent) {
    return 'خصم ($percent%)';
  }

  @override
  String get checkoutSubtotal => 'المجموع الفرعي';

  @override
  String get checkoutTax => 'الضريبة (16%)';

  @override
  String get checkoutTotal => 'الإجمالي';

  @override
  String get checkoutPaymentMethod => 'طريقة الدفع';

  @override
  String get checkoutNoMethodsHint => 'لا توجد طريقة دفع مسجّلة. أضف واحدة للمتابعة.';

  @override
  String get checkoutAddPaymentMethod => 'إضافة طريقة دفع';

  @override
  String get checkoutAddAnother => 'إضافة أخرى';

  @override
  String get checkoutExtensionBadge => 'تمديد';

  @override
  String get checkoutCurrentPlanCredit => 'رصيد الباقة الحالية';

  @override
  String get checkoutExtensionRenewsOn => 'التجديد الجديد';

  @override
  String get errorPaymentMethod => 'اختر طريقة دفع صالحة';

  @override
  String welcomeBlurbLong(String visits) {
    return 'بطاقتك مفعّلة. $visits زيارة بانتظارك في جميع الأندية الشريكة ضمن الشبكة.';
  }

  @override
  String get subscriptionTitle => 'اشتراكك';

  @override
  String get subscriptionOverline => 'بطاقتك';

  @override
  String get subscriptionTitleAccent => 'الحالية.';

  @override
  String subscriptionRenewsOn(String date) {
    return 'نشط · يتجدّد في $date';
  }

  @override
  String subscriptionUpgradeTo(String tier) {
    return 'ترقية إلى $tier';
  }

  @override
  String get subscriptionChangePlan => 'تغيير الباقة';

  @override
  String get subscriptionPerks => 'ما الذي تحصل عليه';

  @override
  String get subscriptionEmptyOverline => 'لا توجد خطة بعد';

  @override
  String get subscriptionEmptyTitle => 'ابدأ اشتراكك';

  @override
  String get subscriptionEmptyBlurb => 'لم تختر فئة حتى الآن. تصفّح الخطط واشترك لفتح جميع الصالات الشريكة في المدينة.';

  @override
  String get subscriptionEmptyCta => 'تصفّح الخطط';

  @override
  String get profileOverline => 'الملف';

  @override
  String get profileMemberSince => 'عضو منذ مارس';

  @override
  String get profileVisitsThisMo => 'زيارات الشهر';

  @override
  String get profileStreak => 'التسلسل';

  @override
  String get profileThisMonth => 'هذا الشهر';

  @override
  String get profileNextTier => 'المستوى التالي';

  @override
  String get profileNextTierEmpty => 'لا توجد خطة';

  @override
  String get profileNoPlanChip => 'لا توجد خطة نشطة';

  @override
  String get profileMenuSubscription => 'اشتراكي';

  @override
  String get profileMenuFavorites => 'النوادي المفضلة';

  @override
  String get profileMenuNotifications => 'الإشعارات';

  @override
  String get favoritesOverline => 'المفضلة';

  @override
  String get favoritesHeadline => 'نواديك';

  @override
  String get favoritesHeadlineAccent => 'المحفوظة.';

  @override
  String get favoritesEmptyTitle => 'لا توجد نوادٍ مفضلة بعد';

  @override
  String get favoritesEmptyBody => 'اضغط على القلب في صفحة أي نادٍ لحفظه هنا للوصول السريع.';

  @override
  String get favoritesEmptyCta => 'تصفح النوادي';

  @override
  String get profileMenuBilling => 'سجل الفواتير';

  @override
  String get profileMenuHelp => 'المساعدة والدعم';

  @override
  String get profileMenuSettings => 'الإعدادات';

  @override
  String get profileMenuInvite => 'دعوة صديق';

  @override
  String get profileLogout => 'تسجيل الخروج';

  @override
  String get inviteOverline => 'دعوة صديق';

  @override
  String get inviteHeadline => 'شارك';

  @override
  String get inviteHeadlineAccent => 'الاشتراك.';

  @override
  String get inviteBlurb => 'أصدقاؤك يحصلون على أسبوع مجاني. أنت تحصل على مكافأة عند اشتراكهم.';

  @override
  String get inviteYourCode => 'رمزك';

  @override
  String get inviteShareLink => 'رابط المشاركة';

  @override
  String get inviteCopyCode => 'نسخ';

  @override
  String get inviteShare => 'مشاركة';

  @override
  String get inviteCodeCopied => 'تم نسخ الرمز';

  @override
  String get inviteLinkCopied => 'تم نسخ الرابط';

  @override
  String get inviteCountsPending => 'قيد الانتظار';

  @override
  String get inviteCountsConverted => 'مؤكدة';

  @override
  String get inviteCountsExpired => 'منتهية';

  @override
  String get inviteListTitle => 'المدعوّون';

  @override
  String get inviteListEmpty => 'لا توجد دعوات بعد. شارك رمزك للبدء.';

  @override
  String get inviteStatusPending => 'قيد الانتظار';

  @override
  String get inviteStatusConverted => 'مؤكدة';

  @override
  String get inviteStatusExpired => 'منتهية';

  @override
  String get inviteInvitedBy => 'دعاك';

  @override
  String get inviteInvitedByNone => 'لم تتم دعوتك';

  @override
  String get inviteClaimTitle => 'لديك رمز من صديق؟';

  @override
  String get inviteClaimBlurb => 'أدخل رمزه بصيغة GP-XXXXXX لنحتسب له دعوتك.';

  @override
  String get inviteClaimInputLabel => 'رمز الصديق';

  @override
  String get inviteClaimInputHint => 'GP-XXXXXX';

  @override
  String get inviteClaimCta => 'تأكيد الرمز';

  @override
  String inviteClaimSuccess(Object name) {
    return 'تمّ — سيُحتسب $name دعوتك.';
  }

  @override
  String get inviteClaimErrorInvalid => 'الرمز غير صالح.';

  @override
  String get inviteClaimErrorNotFound => 'لا يوجد عضو بهذا الرمز.';

  @override
  String get inviteClaimErrorOwnCode => 'هذا رمزك الخاص.';

  @override
  String get inviteClaimErrorAlready => 'لقد استخدمت رمز صديق سابقاً.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsLangArabic => 'العربية';

  @override
  String get settingsLangEnglish => 'English';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsNotifPlanReminders => 'تذكيرات الباقة';

  @override
  String get settingsNotifNewClubs => 'أندية جديدة قريبة';

  @override
  String get settingsNotifPromos => 'عروض وخصومات';

  @override
  String get settingsAccountEditProfile => 'تعديل الملف';

  @override
  String get settingsAccountSecurity => 'الأمان والخصوصية';

  @override
  String get settingsAccountTerms => 'شروط الخدمة';

  @override
  String get settingsAccountPrivacy => 'سياسة الخصوصية';

  @override
  String get settingsAccountLogout => 'تسجيل الخروج';

  @override
  String get settingsAppVersion => 'جيم باس 1.0 · صُنع في عمّان';

  @override
  String get notificationsOverline => 'المستجدّات';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notificationsMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get snackErrorGeneric => 'حدث خطأ. الرجاء المحاولة مرة أخرى.';

  @override
  String get supportOverline => 'احصل على مساعدة';

  @override
  String get supportHeadline => 'نحن هنا';

  @override
  String get supportHeadlineAccent => 'لمساعدتك.';

  @override
  String get supportBlurb => 'متوسط الرد خلال أقل من 4 ساعات. فريقنا في عمّان.';

  @override
  String get supportChannelsLabel => 'قنوات التواصل';

  @override
  String get supportChannelCallTitle => 'اتصل بفريقنا';

  @override
  String get supportChannelCallSubtitle => 'الأحد–الخميس · 9 ص – 7 م';

  @override
  String get supportChannelEmailTitle => 'الدعم عبر البريد';

  @override
  String get supportChannelEmailSubtitle => 'support@gym-pass.net';

  @override
  String get supportChannelWhatsappTitle => 'الدردشة عبر واتساب';

  @override
  String get supportChannelWhatsappSubtitle => 'عادةً يرد خلال 10 دقائق';

  @override
  String get supportSupportPhone => '+962 6 555 0100';

  @override
  String get supportMessageLabel => 'إرسال رسالة';

  @override
  String get supportSubjectLabel => 'الموضوع';

  @override
  String get supportSubjectHint => 'بماذا يتعلق؟';

  @override
  String get supportBodyLabel => 'كيف يمكننا المساعدة؟';

  @override
  String get supportBodyHint => 'أخبرنا بما يحدث…';

  @override
  String get supportSendBtn => 'إرسال الرسالة';

  @override
  String get supportSentSnackbar => 'شكراً — سنعود إليك خلال 24 ساعة.';

  @override
  String get supportMissingFields => 'الرجاء تعبئة الموضوع والرسالة.';

  @override
  String get faqOverline => 'قاعدة المعرفة';

  @override
  String get faqHeadline => 'الأسئلة';

  @override
  String get faqHeadlineAccent => 'الشائعة.';

  @override
  String get faqBlurb => 'إجابات سريعة لما يسأل عنه الأعضاء يومياً.';

  @override
  String get faqSearchHint => 'ابحث في الأسئلة…';

  @override
  String get faqEmpty => 'لا توجد أسئلة مطابقة. جرّب كلمات مختلفة أو تواصل مع الدعم.';

  @override
  String get faqContactFooter => 'لم تجد ما تبحث عنه؟';

  @override
  String get faqContactCta => 'تواصل مع الدعم';

  @override
  String get faqCategoryAll => 'الكل';

  @override
  String get faqCategoryGeneral => 'عام';

  @override
  String get faqCategoryBilling => 'الفواتير';

  @override
  String get faqCategoryCheckin => 'تسجيل الحضور';

  @override
  String get faqCategoryClasses => 'الحصص';

  @override
  String get faqQ1 => 'كيف يعمل تسجيل الحضور عبر QR؟';

  @override
  String get faqA1 => 'لكل نادٍ رمز QR خاص به. افتح تبويب تسجيل الحضور، وامسح الرمز عند الباب، وانتظر شاشة التأكيد. يتم تحديث عدد زياراتك فوراً.';

  @override
  String get faqQ2 => 'هل يمكنني تغيير الباقة في أي وقت؟';

  @override
  String get faqA2 => 'نعم. الترقية تُحتسب بالتناسب وتبدأ فوراً، والتخفيض يُطبّق في دورة الفوترة التالية.';

  @override
  String get faqQ3 => 'ماذا يحدث إذا فوّت شهراً؟';

  @override
  String get faqA3 => 'الزيارات غير المستخدمة لا تُرحّل. يعود عدد الزيارات إلى الصفر في بداية كل دورة فوترة.';

  @override
  String get faqQ5 => 'ما طرق الدفع المقبولة؟';

  @override
  String get faqA5 => 'فيزا، ماستركارد، CliQ، وApple Pay. جميع الفواتير بالدينار الأردني.';

  @override
  String get faqQ6 => 'هل يمكنني تجميد أو إلغاء الاشتراك؟';

  @override
  String get faqA6 => 'لا يوجد إجراء إلغاء — أنت غير مقيَّد. خطتك تنتهي ببساطة في آخر يوم من فترتك الحالية، ويمكنك اختيار التجديد (أو عدمه) في أي وقت. التجميد متاح للخطط نصف السنوية والسنوية: الفضية 10/24 يوماً، الذهبية 12/26، البلاتينية 14/28، الماسية 16/30 (6 أشهر/12 شهراً). التجميد كتلة واحدة لا تُقسَّم، وتتيح الخطة السنوية استخدامه مرتين. يُؤجِّل التجميد كلاً من موعد التجديد وتاريخ الانتهاء بعدد الأيام التي تستخدمها فعلياً.';

  @override
  String get faqQ7 => 'هل بياناتي تُشارك مع النوادي؟';

  @override
  String get faqA7 => 'فقط ما يلزم لتسجيل الحضور: اسمك وباقتك. رقم هاتفك وبريدك لا يغادران خوادمنا.';

  @override
  String get faqQ8 => 'ما الفرق بين الباقات؟';

  @override
  String get faqA8 => 'كل باقة تمنحك 30 زيارة شهرياً. الفرق هو شبكة النوادي التي تدخلها — الفضية تغطي الأندية الأساسية، والذهبية تضيف الفضية + الذهبية، والبلاتينية تضيف الأندية الراقية، والماسية تفتح جميع النوادي الشريكة في الشبكة.';

  @override
  String get reportOverline => 'الإبلاغ عن خلل';

  @override
  String get reportHeadline => 'هل هناك';

  @override
  String get reportHeadlineAccent => 'مشكلة؟';

  @override
  String get reportBlurb => 'أخبرنا بما حدث — الصور تساعدنا على الإصلاح أسرع.';

  @override
  String get reportCategoryLabel => 'الفئة';

  @override
  String get reportCategoryCheckin => 'تسجيل الحضور';

  @override
  String get reportCategoryPayment => 'الدفع';

  @override
  String get reportCategoryApp => 'التطبيق / الواجهة';

  @override
  String get reportCategoryAccount => 'الحساب';

  @override
  String get reportCategoryOther => 'أخرى';

  @override
  String get reportGymLabel => 'النادي (اختياري)';

  @override
  String get reportGymHint => 'أي نادٍ؟';

  @override
  String get reportDescLabel => 'ماذا حدث؟';

  @override
  String get reportDescHint => 'خطوة بخطوة إن أمكن…';

  @override
  String get reportAttachLabel => 'مرفق (اختياري)';

  @override
  String get reportAttachPlaceholder => 'إرفاق لقطة شاشة';

  @override
  String get reportAttachAttached => 'تم إرفاق لقطة شاشة · اضغط للإزالة';

  @override
  String get reportSubmitBtn => 'إرسال البلاغ';

  @override
  String get reportSubmittedTitle => 'تم استلام البلاغ';

  @override
  String reportSubmittedBody(String ref) {
    return 'شكراً لإبلاغك. رقم المرجع الخاص بك هو $ref — سنتابع معك عبر البريد.';
  }

  @override
  String get reportSubmittedClose => 'إغلاق';

  @override
  String get reportMissingFields => 'الرجاء اختيار الفئة ووصف المشكلة.';

  @override
  String get billingOverline => 'الفواتير · المدفوعات';

  @override
  String get billingHeadline => 'إدارة';

  @override
  String get billingHeadlineAccent => 'الفواتير.';

  @override
  String get billingBlurb => 'إدارة طرق الدفع، ومراجعة الفواتير، ومتابعة موعد التجديد القادم.';

  @override
  String get billingMethodsLabel => 'طرق الدفع';

  @override
  String get billingMethodsEmpty => 'لا توجد طريقة دفع بعد. أضف واحدة لتبقى اشتراكك نشطاً.';

  @override
  String get billingAddMethod => 'إضافة طريقة';

  @override
  String get billingSetDefault => 'اجعلها افتراضية';

  @override
  String get billingDefaultChip => 'افتراضية';

  @override
  String get billingRemoveMethod => 'إزالة';

  @override
  String billingRemoveConfirmBody(String label) {
    return 'هل تريد إزالة $label من طرق الدفع المحفوظة؟';
  }

  @override
  String get billingRemoveConfirmTitle => 'إزالة الطريقة';

  @override
  String get billingRemoveConfirmYes => 'إزالة';

  @override
  String get billingAddTitle => 'إضافة طريقة دفع';

  @override
  String get billingAddCard => 'بطاقة (Visa / Mastercard)';

  @override
  String get billingAddCliq => 'كليك';

  @override
  String get billingAddApple => 'Apple Pay';

  @override
  String get billingAddGoogle => 'Google Pay';

  @override
  String get billingAddSaveBtn => 'حفظ الطريقة';

  @override
  String get billingAddCardSection => 'تفاصيل البطاقة';

  @override
  String get billingAddCliqSection => 'تفاصيل كليك';

  @override
  String get billingAddApplePaySection => 'Apple Pay';

  @override
  String get billingAddGooglePaySection => 'Google Pay';

  @override
  String get billingAddCardNumberLabel => 'رقم البطاقة';

  @override
  String get billingAddCardNumberHint => '4242 4242 4242 4242';

  @override
  String get billingAddExpiryLabel => 'تاريخ الانتهاء';

  @override
  String get billingAddExpiryHint => 'MM / YY';

  @override
  String get billingAddCvvLabel => 'CVV';

  @override
  String get billingAddCvvHint => '123';

  @override
  String get billingAddHolderLabel => 'اسم حامل البطاقة';

  @override
  String get billingAddHolderHint => 'الاسم كما هو مطبوع على البطاقة';

  @override
  String get billingAddCliqAliasLabel => 'اسم كليك';

  @override
  String get billingAddCliqAliasHint => 'مثال: omar.jo';

  @override
  String get billingAddCliqPhoneLabel => 'رقم كليك';

  @override
  String get billingAddCliqPhoneHint => '+962 7X XXX XXXX';

  @override
  String get billingAddCliqModeAlias => 'الاسم المستعار';

  @override
  String get billingAddCliqModePhone => 'رقم الهاتف';

  @override
  String get billingAddApplePayBlurb => 'اربط Apple Pay للدفع باستخدام Face ID أو Touch ID. تبقى بطاقتك داخل المحفظة — نستلم رمز الدفع فقط.';

  @override
  String get billingAddApplePayConnect => 'ربط Apple Pay';

  @override
  String get billingAddApplePayConnecting => 'جارٍ الاتصال بالمحفظة…';

  @override
  String get billingAddApplePayConnected => 'تم ربط Apple Pay';

  @override
  String get billingAddGooglePayBlurb => 'اربط Google Pay للدفع ببصمتك أو فتح الجهاز. تبقى بطاقتك داخل Google Wallet — نستلم رمز الدفع فقط.';

  @override
  String get billingAddGooglePayConnect => 'ربط Google Pay';

  @override
  String get billingAddGooglePayConnecting => 'جارٍ الاتصال بـ Google Wallet…';

  @override
  String get billingAddGooglePayConnected => 'تم ربط Google Pay';

  @override
  String get billingAddErrCardNumber => 'أدخل رقم بطاقة صالح من 13 إلى 19 خانة.';

  @override
  String get billingAddErrExpiry => 'تاريخ الانتهاء يجب أن يكون MM/YY مستقبليًا.';

  @override
  String get billingAddErrCvv => 'CVV يجب أن يكون 3 أو 4 أرقام.';

  @override
  String get billingAddErrHolder => 'أدخل اسم حامل البطاقة.';

  @override
  String get billingAddErrCliq => 'أدخل اسم كليك أو رقم هاتف أردني صالح.';

  @override
  String get billingAddErrApplePay => 'اضغط \"ربط Apple Pay\" لإكمال ربط المحفظة.';

  @override
  String get billingAddErrGooglePay => 'اضغط \"ربط Google Pay\" لإكمال ربط المحفظة.';

  @override
  String get billingMethodAdded => 'تمت إضافة طريقة الدفع.';

  @override
  String get billingMethodRemoved => 'تمت إزالة طريقة الدفع.';

  @override
  String get billingDefaultUpdated => 'تم تحديث طريقة الدفع الافتراضية.';

  @override
  String get billingNextChargeLabel => 'الفاتورة القادمة';

  @override
  String billingNextChargeBody(String date, int amount) {
    return '$date · $amount د.أ';
  }

  @override
  String get billingHistoryLabel => 'سجل الفواتير';

  @override
  String get billingHistoryEmpty => 'لا توجد فواتير بعد.';

  @override
  String billingInvoicePaid(String iso, int amount) {
    return '$iso · $amount د.أ';
  }

  @override
  String get billingInvoiceReceipt => 'الإيصال';

  @override
  String get billingCardNetworkVisa => 'Visa';

  @override
  String get billingCardNetworkMastercard => 'Mastercard';

  @override
  String get billingCardNetworkCliq => 'كليك';

  @override
  String get billingCardNetworkApple => 'Apple Pay';

  @override
  String get billingCardNetworkGoogle => 'Google Pay';

  @override
  String get securityBlurb => 'غيّر رقم هاتفك، فعّل تسجيل الدخول بالبصمة، وتحقق من جلساتك النشطة.';

  @override
  String get securityChangePhoneDesc => 'تغيير رقم الهاتف المرتبط بحسابك.';

  @override
  String get securitySessionsDesc => 'شاهد الأجهزة المسجلة حالياً واسحب الصلاحية من أي جهاز غير معروف.';

  @override
  String get securityChangePhoneTitle => 'تغيير رقم الهاتف';

  @override
  String get securityChangePhoneNewLabel => 'رقم الهاتف الجديد';

  @override
  String get securityChangePhoneOtpNote => 'سنرسل رمز تحقق لتأكيد الرقم الجديد.';

  @override
  String get securityChangePhoneSubmit => 'إرسال الرمز';

  @override
  String get securityChangePhoneSuccess => 'تم إرسال رمز التحقق. راجع رسائل SMS.';

  @override
  String get securityChangePhoneInvalid => 'أدخل رقم هاتف صحيح.';

  @override
  String get securityChangePhoneOtpTitle => 'تحقق من رقمك';

  @override
  String securityChangePhoneOtpSubtitle(String phone) {
    return 'أدخل الرمز المكوّن من 4 أرقام الذي أرسلناه إلى $phone.';
  }

  @override
  String get securityChangePhoneVerifyBtn => 'تحقق';

  @override
  String get securityChangePhoneOtpError => 'الرمز غير صحيح أو منتهي.';

  @override
  String get securityChangePhoneInUse => 'هذا الرقم مستخدم في حساب آخر.';

  @override
  String get securitySessionsTitle => 'الجلسات النشطة';

  @override
  String get securitySessionsThisDevice => 'هذا الجهاز';

  @override
  String get securitySessionsActive => 'نشطة الآن';

  @override
  String get securitySessionsRevoke => 'إنهاء';

  @override
  String get securitySessionsRevoked => 'تم إنهاء الجلسة.';

  @override
  String get securitySessionsRevokeAll => 'تسجيل الخروج من الباقي';

  @override
  String securitySessionsLastActive(String when) {
    return 'آخر نشاط $when';
  }

  @override
  String get helpOverline => 'المساعدة · الدعم';

  @override
  String get helpHeadline => 'كيف يمكننا';

  @override
  String get helpHeadlineAccent => 'مساعدتك؟';

  @override
  String get helpBlurb => 'تحدّث إلى فريقنا، راجع الأسئلة الشائعة، أو أرسل بلاغاً — نحن هنا.';

  @override
  String get helpContactSupportDesc => 'اتصال، بريد إلكتروني، أو واتساب — فريقنا يرد خلال ساعات العمل.';

  @override
  String get helpFaqDesc => 'إجابات سريعة لأكثر الأسئلة التي يطرحها أعضاؤنا.';

  @override
  String get helpReportIssueDesc => 'هل هناك خلل؟ أرسل بلاغاً وسنتابع معك عبر البريد.';

  @override
  String get supportEmail => 'support@gym-pass.net';

  @override
  String get supportWhatsapp => '+962 7 9000 0100';

  @override
  String supportChannelCopied(String value) {
    return 'تم نسخ $value.';
  }

  @override
  String supportSentWithRef(String ref) {
    return 'شكراً — رقم التذكرة $ref. سنرد خلال 24 ساعة.';
  }

  @override
  String get supportSubmittedTitle => 'تم استلام رسالتك';

  @override
  String get reportAttachPickerTitle => 'إرفاق دليل';

  @override
  String get reportAttachScreenshot => 'لقطة شاشة حديثة';

  @override
  String get reportAttachCameraRoll => 'صورة من معرض الصور';

  @override
  String get reportAttachPhoto => 'التقاط صورة';

  @override
  String get reportAttachRemove => 'إزالة المرفق';

  @override
  String get billingReceiptTitle => 'إيصال';

  @override
  String get billingReceiptItemsLabel => 'بنود الفاتورة';

  @override
  String get billingReceiptLineBase => 'اشتراك شهري';

  @override
  String billingReceiptLineTax(int amount) {
    return 'ضريبة · $amount د.أ';
  }

  @override
  String get billingReceiptTotalLabel => 'الإجمالي';

  @override
  String get billingReceiptSendEmail => 'إرسال إلى البريد';

  @override
  String get billingReceiptEmailQueued => 'تم إرسال الإيصال إلى بريدك خلال دقيقة.';

  @override
  String get billingReceiptCloseBtn => 'إغلاق';

  @override
  String securityChangePhoneUpdated(String phone) {
    return 'تم تحديث رقم الهاتف إلى $phone.';
  }

  @override
  String get forgotOverline => 'استعادة كلمة المرور';

  @override
  String get forgotTitle => 'أعد';

  @override
  String get forgotTitleAccent => 'تعيين كلمتك.';

  @override
  String get forgotStep1 => 'الخطوة 1 من 3 — اختر الطريقة';

  @override
  String get forgotStep2 => 'الخطوة 2 من 3 — أدخل الرمز';

  @override
  String get forgotStep3 => 'الخطوة 3 من 3 — كلمة مرور جديدة';

  @override
  String get forgotBlurb1 => 'اختر كيف تريد استلام الرمز المكوّن من 4 أرقام.';

  @override
  String get forgotMethodSmsTitle => 'أرسل رمزاً برسالة';

  @override
  String forgotMethodSmsSubtitle(String phone) {
    return 'إلى الرقم $phone';
  }

  @override
  String get forgotMethodEmailTitle => 'أرسل رمزاً بالبريد';

  @override
  String forgotMethodEmailSubtitle(String email) {
    return 'إلى $email';
  }

  @override
  String get forgotMethodEmailMissing => 'لا يوجد بريد مسجّل. استخدم الرسائل القصيرة.';

  @override
  String get forgotSendCode => 'إرسال الرمز';

  @override
  String forgotCodeBlurb(String target) {
    return 'أرسلنا رمزاً مكوّناً من 4 أرقام إلى $target. أدخله بالأسفل.';
  }

  @override
  String get forgotResendCode => 'إعادة الإرسال';

  @override
  String get forgotVerifyCode => 'تحقق من الرمز';

  @override
  String get forgotNewPasswordBlurb => 'اختر كلمة مرور جديدة. ستستخدمها لتسجيل الدخول من الآن.';

  @override
  String get forgotSetNewPassword => 'تحديث كلمة المرور';

  @override
  String get forgotResetSuccess => 'تم تحديث كلمة المرور. يمكنك تسجيل الدخول بها الآن.';

  @override
  String get forgotErrAccountMissing => 'لا يوجد حساب مسجّل على هذا الرقم.';

  @override
  String get forgotErrCodeInvalid => 'الرمز غير متطابق. حاول مجدداً.';

  @override
  String get forgotDevHint => 'وضع التطوير: أي رمز من 4 أرقام يعمل، و1234 هو الرمز المعتمد.';

  @override
  String get securityBiometricTitle => 'تسجيل الدخول بالبصمة';

  @override
  String get securityBiometricDesc => 'استخدم بصمة الإصبع أو الوجه أو رمز الجهاز بدلاً من كتابة كلمة المرور.';

  @override
  String get securityBiometricNoPassword => 'حدّد كلمة مرور أولاً لتفعيل تسجيل الدخول بالبصمة.';

  @override
  String get securityBiometricUnavailable => 'هذا الجهاز لا يدعم البصمة أو لم يتم ضبط قفل للشاشة.';

  @override
  String get biometricEnrollTitle => 'أكّد كلمة المرور';

  @override
  String biometricEnrollBlurb(String biometric) {
    return 'أعد إدخال كلمة المرور لنحفظها خلف $biometric.';
  }

  @override
  String get biometricEnrollPasswordLabel => 'كلمة المرور';

  @override
  String get biometricEnrollPasswordHint => 'أدخل كلمة المرور';

  @override
  String get biometricEnrollSubmit => 'تأكيد';

  @override
  String get biometricUnlockReason => 'افتح GymPass لتسجيل الدخول';

  @override
  String get biometricEnrollReason => 'أكّد لحفظ بيانات الدخول';

  @override
  String get biometricSignInBtn => 'الدخول بالبصمة';

  @override
  String get biometricEnabled => 'تم تفعيل الدخول بالبصمة.';

  @override
  String get biometricDisabled => 'تم إيقاف الدخول بالبصمة.';

  @override
  String get biometricCancelled => 'تم إلغاء طلب البصمة.';

  @override
  String get biometricGenericLabel => 'البصمة';

  @override
  String get billingNoSubscriptionTitle => 'لا يوجد اشتراك فعّال';

  @override
  String get billingNoSubscriptionBlurb => 'ليست لديك خطة حالياً، لذلك لا توجد أي رسوم مجدولة. اختر فئة لتبدأ بمسح الصالات الشريكة.';

  @override
  String get billingNoSubscriptionCta => 'تصفّح الخطط';

  @override
  String get gymNotFoundTitle => 'الصالة غير موجودة';

  @override
  String gymNotFoundBody(String slug) {
    return 'تعذّر العثور على صالة بالاسم \"$slug\". ربما تمت إزالتها.';
  }

  @override
  String get gymNotFoundBackToExplore => 'العودة إلى الاستكشاف';

  @override
  String get legalLastUpdated => 'آخر تحديث';

  @override
  String get legalReadTermsAction => 'شروط الخدمة';

  @override
  String get legalReadPrivacyAction => 'سياسة الخصوصية';

  @override
  String get legalSignupConsent => 'بمتابعتك تكون موافقاً على شروط الخدمة وسياسة الخصوصية.';

  @override
  String get legalSignupConsentPrefix => 'بمتابعتك تكون موافقاً على';

  @override
  String get termsTitle => 'شروط الخدمة';

  @override
  String get termsSubtitle => 'جيم باس · اتفاقية العضو';

  @override
  String get termsUpdatedAt => 'أيار 2026';

  @override
  String get termsAcceptanceHeadline => 'الموافقة على هذه الشروط';

  @override
  String get termsAcceptanceBody => 'بإنشائك حساباً على GymPass أو اشتراكك في باقة أو دخولك إلى أحد الأندية الشريكة عبر مسح رمز QR، فإنك تؤكد أنك قرأت هذه الشروط وتوافق على الالتزام بها. إن لم توافق على أي بند فيها، يُرجى عدم استخدام الخدمة.';

  @override
  String get termsAccountHeadline => 'حسابك';

  @override
  String get termsAccountBody => 'تُسجِّل الدخول برقم هاتف أردني ورمز لمرة واحدة. حافظ على تحديث رقمك — نستخدمه لاستعادة الحساب وإيصالات الدفع والإشعارات الحساسة زمنياً. أنت مسؤول عن أي نشاط يحصل على حسابك وعن حماية جهازك. أبلغ الدعم فوراً إن شككت بأي استخدام غير مصرّح.';

  @override
  String get termsMembershipHeadline => 'فئات الاشتراك';

  @override
  String get termsMembershipBody => 'تحدد فئتك (فضّية، ذهبية، بلاتينية، أو ماسية) الأندية الشريكة التي يحقّ لك دخولها وعدد الزيارات الشهرية المتاحة. تُعاد ميزانية الزيارات في أول كل شهر ولا تُرحَّل. الترقية أو التخفيض يسري في التجديد التالي، ما لم يُنصَّ على غير ذلك في تدفُّق الترقية.';

  @override
  String get termsPaymentHeadline => 'الدفعات والتجديد';

  @override
  String get termsPaymentBody => 'تتجدد الاشتراكات تلقائياً في بداية كل فترة فوترة ما لم تُلغَها مسبقاً. نخصم المبلغ من طريقة الدفع المسجَّلة لديك. إذا فشل الخصم، قد نُعيد المحاولة أو نوقف الوصول أو ننهي الاشتراك. تظهر الأسعار بالدينار الأردني (د.أ)، وتشمل الضرائب عند وجوبها.';

  @override
  String get termsCheckinHeadline => 'دخول الأندية وتسجيل الزيارة';

  @override
  String get termsCheckinBody => 'لكل نادٍ شريك رمز QR ثابت عند مدخله. مسح الرمز عبر التطبيق يُسجِّل زيارة ويخصم زيارة واحدة من رصيدك الشهري. الدخول مشروط بأن تسمح فئتك بالنادي، وأن يتبقى لديك رصيد زيارات، وأن يكون حسابك سليماً. قد نحدّ من تكرار المسح في النادي ذاته لمنع الخصم المزدوج.';

  @override
  String get termsConductHeadline => 'سلوك العضو';

  @override
  String get termsConductBody => 'توافق على الالتزام بأنظمة كل نادٍ شريك ومعاملة الموظفين والأعضاء الآخرين باحترام، وعلى استخدام الخدمة للوصول الشخصي غير التجاري. مشاركة الحساب أو بيع الزيارات أو محاولة المسح برمز QR عضوٍ آخر ممنوع، وقد يؤدي إلى إنهاء فوري للحساب.';

  @override
  String get termsTerminationHeadline => 'إنهاء الخدمة';

  @override
  String get termsTerminationBody => 'يمكنك الإلغاء في أي وقت من ملفك الشخصي. يسري الإلغاء في نهاية فترة الفوترة الحالية، ولا تُسترد المبالغ بالتناسب. قد نوقف أو ننهي الحسابات بسبب عدم الدفع، الاحتيال، الإساءة إلى نادٍ شريك، أو انتهاك هذه الشروط. تستمر السجلات المالية وسجلات التدقيق بعد الإنهاء وفق سياسة الخصوصية.';

  @override
  String get termsLiabilityHeadline => 'حدود المسؤولية';

  @override
  String get termsLiabilityBody => 'GymPass منصة حجز ووصول؛ نحن لسنا مشغّل الأندية الشريكة ولا نتحمّل مسؤولية الإصابات أو فقدان المقتنيات أو النزاعات التي قد تقع في موقع شريك — تبقى تلك مسائل بينك وبين النادي. وفق ما يسمح به القانون الأردني، تقتصر مسؤوليتنا على المبلغ الذي دفعته خلال الأشهر الثلاثة السابقة للمطالبة.';

  @override
  String get termsChangesHeadline => 'التغييرات على هذه الشروط';

  @override
  String get termsChangesBody => 'قد نُحدِّث هذه الشروط من وقت لآخر. عند أي تغيير جوهري، سنُخطرك داخل التطبيق قبل سريانه بسبعة أيام على الأقل. استمرارك في استخدام الخدمة بعد التاريخ المعلَن يُعدّ موافقة.';

  @override
  String get termsContactHeadline => 'تواصل معنا';

  @override
  String get termsContactBody => 'لأي استفسار حول هذه الشروط، يمكنك التواصل عبر صفحة الدعم داخل التطبيق أو البريد support@gym-pass.net. نردّ بالعربية أو الإنجليزية، أيهما تكتب به.';

  @override
  String get privacyTitle => 'سياسة الخصوصية';

  @override
  String get privacySubtitle => 'جيم باس · كيف نتعامل مع بياناتك';

  @override
  String get privacyUpdatedAt => 'أيار 2026';

  @override
  String get privacyDataWeCollectHeadline => 'البيانات التي نجمعها';

  @override
  String get privacyDataWeCollectBody => 'نجمع: رقم الهاتف الذي تُسجِّل به؛ أي اسم أو بريد إلكتروني أو تاريخ ميلاد تضيفه إلى ملفك؛ تفاصيل طريقة الدفع (يعالجها مزوّد الدفع — نحن لا نخزّن رقم بطاقتك الكامل، فقط الأرقام الأربعة الأخيرة ونوع البطاقة)؛ سجلّ زياراتك (أي نادٍ، متى، نجاح أو فشل وسبب الفشل)؛ موقع جهازك أثناء فتحك تبويب الاستكشاف؛ ونوع جهازك لتشخيص الأعطال.';

  @override
  String get privacyPurposeHeadline => 'لماذا نجمعها';

  @override
  String get privacyPurposeBody => 'رقم الهاتف — هويّة الحساب وتسجيل الدخول بـ OTP. حقول الملف — اسم العرض وإرسال الإيصالات. بيانات الدفع — معالجة الاشتراكات. سجلّ الزيارات — احتساب رصيدك ودفع الأندية الشريكة عن كل زيارة ورصد الاحتيال. الموقع — إيجاد الأندية القريبة منك في الخارطة. معلومات الجهاز — تشخيص الأعطال والتحقيقات الأمنية.';

  @override
  String get privacySharingHeadline => 'مع من نُشارك بياناتك';

  @override
  String get privacySharingBody => 'تطّلع الأندية الشريكة على نسخة مُقنَّعة من بياناتك عند تسجيل الزيارة (انظر القسم التالي). يستلم مزوّد الدفع البيانات اللازمة لإتمام الفوترة فقط. مزوّدو الاستضافة والتحليلات يعالجون البيانات التقنية اللازمة لتشغيل الخدمة. لا نبيع بياناتك للمعلنين أو المسوّقين أو وسطاء البيانات. قد نُفصِح عن البيانات عند طلب قانوني أردني صالح.';

  @override
  String get privacyMaskingHeadline => 'ماذا يرى الشريك عنك';

  @override
  String get privacyMaskingBody => 'يرى الشريك: اسمك الأول وحرف اسم العائلة الأول (مثال: «أحمد خ.»)، آخر أربعة أرقام من هاتفك (مثال: «•• ••• 4567»)، وقت تسجيل الزيارة، ومعرّفاً داخلياً للدعم. لا يرى الشريك أبداً رقم هاتفك الكامل أو بريدك أو عنوانك أو معلومات الدفع. هذا التقنيع مفروض من واجهتنا البرمجية، ولا يمكن للشريك تجاوزه.';

  @override
  String get privacyRetentionHeadline => 'مدة الاحتفاظ بالبيانات';

  @override
  String get privacyRetentionBody => 'تُحفظ بيانات ملفك واشتراكك ما دام حسابك نشطاً. بعد حذف الحساب، نُبقي السجلات المالية وسجلات التدقيق لسبع سنوات استيفاءً للمتطلبات الضريبية وحماية المستهلك الأردنية؛ ما عداها يُمحى خلال 30 يوماً. الزيارات المرتبطة بدفعة شراكة مدفوعة لا تُحذف حتى تُسوّى تلك الدفعة.';

  @override
  String get privacySecurityHeadline => 'كيف نحمي بياناتك';

  @override
  String get privacySecurityBody => 'تستخدم اتصالاتك بخوادمنا تشفير TLS. كلمات المرور تُخزَّن مُجزَّأة (hashed) ولا نخزّنها بصيغة قابلة للقراءة. بيانات الدفع تُرمَّز عبر مزوّد الدفع؛ نحن لا نرى رقم البطاقة كاملاً. الوصول الداخلي إلى بياناتك مقيَّد بأدوار (المسؤولون فقط، مع تسجيل تدقيقي لكل قراءة لسجلات شخصية).';

  @override
  String get privacyRightsHeadline => 'حقوقك';

  @override
  String get privacyRightsBody => 'يمكنك: مراجعة بياناتك وتعديلها من تبويب الإعدادات؛ تنزيل بياناتك عبر الدعم؛ طلب حذف حسابك في أي وقت (مع تأكيد سريان استثناءات الاحتفاظ السبعية للسجلات المالية فقط)؛ سحب موافقتك على إشعارات التسويق (تجدها في الإعدادات ← الإشعارات)؛ تقديم شكوى لدى الهيئة الأردنية لحماية البيانات الشخصية.';

  @override
  String get privacyChildrenHeadline => 'الأطفال';

  @override
  String get privacyChildrenBody => 'GymPass غير موجّه للأطفال دون السادسة عشرة. إن علمت بأن قاصراً قد سجّل، تواصل مع الدعم وسنقوم بإزالة الحساب.';

  @override
  String get privacyChangesHeadline => 'تغييرات هذه السياسة';

  @override
  String get privacyChangesBody => 'قد نُحدِّث هذه السياسة. عند أي تغيير جوهري في تعاملنا مع بياناتك، سنُخطرك داخل التطبيق قبل سريانه بسبعة أيام على الأقل. استمرارك في الاستخدام بعد التاريخ المعلَن يُعدّ موافقة.';

  @override
  String get privacyContactHeadline => 'تواصل معنا';

  @override
  String get privacyContactBody => 'راسلنا على privacy@gym-pass.net أو استخدم صفحة الدعم. نردّ بالعربية أو الإنجليزية. يمكن التواصل مع مسؤول حماية البيانات على نفس العنوان.';
}
