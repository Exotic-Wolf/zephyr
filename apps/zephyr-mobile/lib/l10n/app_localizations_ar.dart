// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get goLiveInSeconds => 'ابدأ البث في ثوانٍ';

  @override
  String get checkingApi => 'جارٍ الفحص...';

  @override
  String get apiConnected => 'متصل';

  @override
  String get apiOffline => 'غير متصل';

  @override
  String get refreshApiStatus => 'تحديث حالة الاتصال';

  @override
  String get connecting => 'جارٍ الاتصال...';

  @override
  String get continueAsGuest => 'المتابعة كضيف';

  @override
  String get signingIn => 'جارٍ تسجيل الدخول...';

  @override
  String get continueWithGoogle => 'المتابعة مع Google';

  @override
  String get continueWithApple => 'المتابعة مع Apple';

  @override
  String get home => 'الرئيسية';

  @override
  String get live => 'مباشر';

  @override
  String get explore => 'استكشاف';

  @override
  String get inbox => 'الرسائل';

  @override
  String get me => 'أنا';

  @override
  String get noOneIsLiveRightNow => 'لا أحد يبث الآن. تحقق مجدداً بعد قليل.';

  @override
  String noResultsFor(String query) {
    return 'لا نتائج لـ \"$query\".';
  }

  @override
  String noOneIsLiveFrom(String location) {
    return 'لا أحد يبث من $location الآن.';
  }

  @override
  String get popular => 'مشهور';

  @override
  String get discover => 'اكتشاف';

  @override
  String get follow => 'متابعة';

  @override
  String get noPopularStreamersRightNow =>
      'لا يوجد بث مشهور الآن. تحقق مجدداً.';

  @override
  String noStreamersFrom(String location) {
    return 'لا يوجد بث من $location الآن.';
  }

  @override
  String noneOfPeopleYouFollowAreLive(String location) {
    return 'لا أحد ممن تتابعهم يبث من $location الآن.';
  }

  @override
  String get followSomeoneToSeeThemHere => 'تابع شخصاً لرؤيته هنا.';

  @override
  String get openingLive => 'جارٍ الفتح...';

  @override
  String get randomMatch => 'مطابقة عشوائية';

  @override
  String get goLive => 'ابدأ البث';

  @override
  String get startLiveStreamAndConnect =>
      'ابدأ بثاً مباشراً وتواصل\nمع جمهورك في الوقت الفعلي';

  @override
  String get starting => 'جارٍ البدء…';

  @override
  String get startLiveStream => 'بدء البث المباشر';

  @override
  String get level => 'المستوى';

  @override
  String levelValue(int level) {
    return 'المستوى $level';
  }

  @override
  String get keepStreamingToLevelUp =>
      'واصل البث واستقبال الهدايا والتفاعل للارتقاء في المستوى.';

  @override
  String get myBalance => 'رصيدي';

  @override
  String get coinBalance => 'رصيد العملات';

  @override
  String coinsAmount(int coins) {
    return '$coins عملة';
  }

  @override
  String get buyCoins => 'شراء عملات';

  @override
  String coinPackLabel(int coins, String label) {
    return '$coins عملة • $label';
  }

  @override
  String get buying => 'جارٍ الشراء...';

  @override
  String get buy => 'شراء';

  @override
  String get myRevenue => 'أرباحي';

  @override
  String get revenueFromGiftsAndCalls =>
      'تظهر هنا الأرباح من الهدايا والمكالمات المدفوعة.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get account => 'الحساب';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get language => 'اللغة';

  @override
  String get appearance => 'المظهر';

  @override
  String get search => 'بحث';

  @override
  String get closeSearch => 'إغلاق البحث';

  @override
  String get nameOrId => 'الاسم أو المعرف…';

  @override
  String get refresh => 'تحديث';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get followDeviceSetting => 'اتباع إعداد الجهاز';

  @override
  String get lightMode => 'فاتح';

  @override
  String get alwaysUseLightMode => 'استخدام الوضع الفاتح دائماً';

  @override
  String get darkMode => 'داكن';

  @override
  String get alwaysUseDarkMode => 'استخدام الوضع الداكن دائماً';

  @override
  String get owner => 'مالك';

  @override
  String get callSessionStarted => 'بدأت جلسة المكالمة. الفوترة نشطة.';

  @override
  String get notEnoughCoinsForRandomMatch =>
      'عملاتك غير كافية للمطابقة العشوائية. أعد الشحن أولاً.';

  @override
  String get noReceiverAvailable =>
      'لا يوجد مستقبل متاح للمكالمة المباشرة. جرب الوضع العشوائي.';

  @override
  String get callEndedInsufficientBalance => 'انتهت المكالمة: رصيد غير كافٍ.';

  @override
  String get callEnded => 'انتهت المكالمة.';

  @override
  String get noMessagesYet => 'لا رسائل بعد';

  @override
  String get noMessagesYetSayHello => 'لا رسائل بعد. قل مرحباً!';

  @override
  String get messageHint => 'رسالة…';

  @override
  String failedToSend(String error) {
    return 'فشل الإرسال: $error';
  }

  @override
  String get findAnyoneByNameOrId =>
      'ابحث عن أي شخص بالاسم أو المعرف المكون من 8 أرقام';

  @override
  String get nameOrIdHint => 'الاسم أو المعرف المكون من 8 أرقام…';

  @override
  String get discoverPeople => 'اكتشاف أشخاص';

  @override
  String get searchByNameOrId =>
      'ابحث بالاسم أو أدخل\nمعرفاً عاماً مكوناً من 8 أرقام';

  @override
  String get noUsersFound => 'لم يُعثر على مستخدمين';

  @override
  String get tryDifferentNameOrId => 'جرب اسماً أو معرفاً مختلفاً';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get id => 'المعرف';

  @override
  String get idCopiedToClipboard => 'تم نسخ المعرف';

  @override
  String get nickname => 'الاسم المستعار';

  @override
  String get enterNickname => 'أدخل اسماً مستعاراً';

  @override
  String get gender => 'الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get nonBinary => 'ثنائي غير محدد';

  @override
  String get preferNotToSay => 'أفضل عدم الإفصاح';

  @override
  String get birthday => 'تاريخ الميلاد';

  @override
  String get notSet => 'غير محدد';

  @override
  String get country => 'الدولة';

  @override
  String get yourIdIsPermanent => 'معرفك دائم ولا يمكن تغييره.';

  @override
  String get viewPublicProfile => 'عرض الملف العام';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromLibrary => 'الاختيار من المكتبة';

  @override
  String get ownerBadge => '👑  مالك';

  @override
  String get avatarUpdated => 'تم تحديث الصورة';

  @override
  String uploadFailed(String error) {
    return 'فشل الرفع: $error';
  }

  @override
  String get profileSaved => 'تم حفظ الملف الشخصي';

  @override
  String failedToSaveProfile(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get myCallPrice => 'سعر مكالمتي';

  @override
  String get spark => 'شرارة';

  @override
  String get youEarnSparks => 'تكسب شرارات في كل ثانية تقضيها في مكالمة';

  @override
  String get fairPricingGetsMoreCalls =>
      'التسعير العادل يجلب لك مزيداً من المكالمات';

  @override
  String get callersWillSee => 'سيرى المتصلون:';

  @override
  String get videoCall => 'مكالمة فيديو';

  @override
  String get perMinute => '/دقيقة';

  @override
  String get chooseYourRate => 'اختر سعرك';

  @override
  String yourLevelIs(int level) {
    return 'مستواك $level. تُفتح مستويات أعلى مع ارتفاع مستواك.';
  }

  @override
  String get tier => 'الفئة';

  @override
  String get youEarn => 'تكسب';

  @override
  String get callerPays => 'يدفع المتصل';

  @override
  String get callRateSaved => 'تم حفظ سعر المكالمة';

  @override
  String failedToSaveRate(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get lockedTiersUnlock =>
      'تُفتح الفئات المقفلة مع ارتفاع مستواك بالنشاط على Zephyr.';

  @override
  String videoCallWithRate(String rate) {
    return 'مكالمة فيديو $rate';
  }

  @override
  String get messageButton => 'رسالة';

  @override
  String get notAvailable => 'غير متاح';

  @override
  String get currentlyBusy => 'مشغول حالياً';

  @override
  String get followers => 'المتابعون';

  @override
  String get followButton => 'متابعة';

  @override
  String get followingButton => 'تتابع';

  @override
  String get about => 'نبذة';

  @override
  String get noBioYet => 'لا توجد نبذة بعد.';

  @override
  String get gifts => 'الهدايا';

  @override
  String get noGiftsYet => 'لا هدايا بعد.';

  @override
  String get getReady => 'استعد!';

  @override
  String get startingYourStream => 'جارٍ بدء بثك…';

  @override
  String get cancel => 'إلغاء';

  @override
  String get liveIndicator => 'مباشر';

  @override
  String get endLive => 'إنهاء البث؟';

  @override
  String get streamWillEndMessage => 'سينتهي بثك وسيتم قطع اتصال المشاهدين.';

  @override
  String get endLiveButton => 'إنهاء البث';

  @override
  String get startingCamera => 'جارٍ تشغيل الكاميرا…';

  @override
  String get cameraIsOff => 'الكاميرا مغلقة';

  @override
  String get micOn => 'الميك مفتوح';

  @override
  String get micOff => 'الميك مغلق';

  @override
  String get camera => 'الكاميرا';

  @override
  String get off => 'مغلق';

  @override
  String get flip => 'تبديل';

  @override
  String totalWatching(int total) {
    return '$total مشاهد';
  }

  @override
  String get noViewersYet => 'لا مشاهدين بعد';

  @override
  String andMoreWatching(int count) {
    return 'و$count آخرون يشاهدون…';
  }

  @override
  String get saySomething => 'قل شيئاً…';

  @override
  String get welcomeToLive => 'مرحباً ببثي المباشر! 👋';
}
