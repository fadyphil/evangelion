// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authEmailHint => 'البريد الإلكتروني';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authPasswordHint => 'كلمة المرور';

  @override
  String get authEnterTheWord => 'ادخل الكلمة';

  @override
  String get authEmailInvalid => 'البريد غير مكتمل';

  @override
  String get authPasswordTooShort => 'كلمة المرور قصيرة';

  @override
  String get authUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get homeGreetingMorning => 'صباح النور';

  @override
  String get homeGreetingAfternoon => 'نهارك نور';

  @override
  String get homeGreetingEvening => 'مساء النور';

  @override
  String get homeGreetingSeparator => '، ';

  @override
  String get homeStreakLabel => 'أيام متتالية';

  @override
  String get homeUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get homeGreetingVigil => 'سهر الليل';

  @override
  String get homePeace => 'سلام';

  @override
  String get homeDays => 'أيام';

  @override
  String get homeVerseOfTheDay => 'آية اليوم';

  @override
  String get homeLastLight => 'آخر نور';

  @override
  String get homeNoLightRef => '—';

  @override
  String get homeNoLight => 'لم يُستقبل نور بعد — افتح كتابًا بالأسفل';

  @override
  String get homeResumeHint => 'عُد إلى حيث تركت النور';

  @override
  String get homeSelah => 'سِلاه';

  @override
  String get homeSecondsOfSilence => 'ثانية من الصمت';

  @override
  String get homeTheLibrary => 'المكتبة';

  @override
  String get homeScrolls => 'دروج';

  @override
  String get homeOpenBooks => 'مفتوحة';

  @override
  String get homeVerses => 'آيات';

  @override
  String get homeSealed => 'مختوم';

  @override
  String get homeCategoryPoetry => 'شعر';

  @override
  String get homeCategoryGospel => 'إنجيل';

  @override
  String get homeCategoryTorah => 'توراة';

  @override
  String get homeCategoryProphets => 'أنبياء';

  @override
  String get homeCategoryHistory => 'تاريخ';

  @override
  String get homeCategoryApocalypse => 'رؤيا';

  @override
  String get leaderboardTitle => 'ترتيب المجموعة';

  @override
  String get leaderboardWindowWeekly => 'الأسبوع';

  @override
  String get leaderboardWindowMonthly => 'الشهر';

  @override
  String get leaderboardWindowAllTime => 'منذ البداية';

  @override
  String get leaderboardEmptyTitle => 'لا توجد نتائج بعد';

  @override
  String get leaderboardEmptyBody =>
      'عند بدء إجابات المجموعة سيظهر الترتيب هنا.';

  @override
  String get leaderboardYourRank => 'أنت';

  @override
  String get leaderboardUnranked => 'غير مصنّف بعد';

  @override
  String get leaderboardScoreLabel => 'نقطة';

  @override
  String get leaderboardOpenFull => 'عرض الكل';

  @override
  String leaderboardRowSemantics(
    int count,
    String digits,
    String initials,
    String rank,
    String isReader,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نقطة',
      many: 'نقطة',
      few: 'نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط',
    );
    String _temp1 = intl.Intl.selectLogic(isReader, {
      'true': '، هذا أنت',
      'other': '',
    });
    return '$_temp0، $initials، المركز $rank$_temp1';
  }

  @override
  String get homeRetry => 'حاول مرة أخرى';

  @override
  String get quizExit => 'إغلاق';

  @override
  String get quizProgress => 'السؤال';

  @override
  String get quizOfWord => 'من';

  @override
  String get quizCheckAnswer => 'تحقق من الإجابة';

  @override
  String get quizNextQuestion => 'السؤال التالي';

  @override
  String get quizSeeResults => 'اعرض النتيجة';

  @override
  String get quizCorrectSuffix => 'الإجابة الصحيحة';

  @override
  String get quizIncorrectSuffix => 'إجابتك غير صحيحة';

  @override
  String get quizVerdictCorrect => 'إجابة صحيحة.';

  @override
  String get quizVerdictIncorrect => 'ليس هذه المرة.';

  @override
  String get quizAlreadyAnsweredSuffix =>
      'تمت الإجابة عنها، فلا يمكن إرسالها مجددًا';

  @override
  String get quizUnavailableSuffix => 'لا توجد إجابة لعرضها';

  @override
  String get quizRetry => 'حاول مرة أخرى';

  @override
  String get quizNoQuestionsTitle => 'لا شيء للتأمل فيه';

  @override
  String get quizNoQuestionsMessage =>
      'لا تحتوي قراءة اليوم على أسئلة للإجابة عنها.';

  @override
  String get readingBack => 'رجوع';

  @override
  String get readingTextSize => 'حجم الخط';

  @override
  String get readingFontSize => 'مقياس حجم الخط';

  @override
  String get readingDecreaseFontSize => 'تصغير الخط';

  @override
  String get readingIncreaseFontSize => 'تكبير الخط';

  @override
  String get readingBookmark => 'إشارة مرجعية';

  @override
  String get readingBeginReflection => 'ابدأ التأمل';

  @override
  String get readingUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get readingPassage => 'نص الآية';

  @override
  String get readingVerse => 'الآية';

  @override
  String get readingRetry => 'حاول مرة أخرى';

  @override
  String readingCaptionFor(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits سؤال',
      many: '$digits سؤالًا',
      few: '$digits أسئلة',
      two: '$digits سؤالان',
      one: '$digits سؤال واحد',
      zero: '$digits أسئلة',
    );
    return '$_temp0';
  }

  @override
  String get resultReflectAgain => 'تأمل مرة أخرى';

  @override
  String get resultBackHome => 'العودة';

  @override
  String get resultThisAnswer => 'هذه الإجابة';

  @override
  String get resultBestRun => 'أطول سلسلة';

  @override
  String get resultDay => 'اليوم';

  @override
  String get resultLongestYet => 'أطول سلسلة لك';

  @override
  String get resultCompleteMessage => 'إجابة صحيحة، وقد اكتملت قراءة اليوم.';

  @override
  String get resultPartialMessage => 'إجابة صحيحة. لم تكتمل القراءة بعد.';

  @override
  String get resultIncorrectMessage => 'ليس هذه المرة. كل سؤال يُحتسب.';

  @override
  String resultTotalCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نقطة',
      many: 'نقطة',
      few: 'نقاط',
      two: 'نقطتان',
      one: 'نقطة',
      zero: 'نقاط',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsBack => 'رجوع';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsFontSize => 'حجم الخط';

  @override
  String get settingsFontScale => 'مقياس حجم الخط';

  @override
  String get settingsDecreaseFontSize => 'تصغير الخط';

  @override
  String get settingsIncreaseFontSize => 'تكبير الخط';

  @override
  String get settingsReduceMotion => 'تقليل الحركة';

  @override
  String get settingsMotionOn => 'مفعّل';

  @override
  String get settingsMotionOff => 'معطّل';

  @override
  String get settingsPreferencesUnavailable =>
      'تعذّر حفظ تفضيلاتك على هذا الجهاز.';

  @override
  String get settingsRetry => 'حاول مرة أخرى';

  @override
  String get settingsReading => 'القراءة';

  @override
  String get settingsDefaultLanguage => 'اللغة الافتراضية';

  @override
  String get settingsLanguageSheetTitle => 'اختر اللغة';

  @override
  String get settingsLanguageEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String get sealFabOpen => 'افتح القائمة';

  @override
  String get sealFabClose => 'أغلق القائمة';

  @override
  String get sealFabSettings => 'الإعدادات';

  @override
  String get sealFabLeaderboard => 'الترتيب';
}
