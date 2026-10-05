// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get authWordmark => 'Evangelion';

  @override
  String get authTagline => 'اقرأ. تأمل. تذكّر.';

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authPasswordHint => '••••••••';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authNewHere => 'جديد هنا؟';

  @override
  String get authCreateAccount => 'أنشئ حسابًا';

  @override
  String get authDivider => 'أو';

  @override
  String get authContinueWithGoogle => 'المتابعة عبر Google';

  @override
  String get authContinueWithApple => 'المتابعة عبر Apple';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authSealLabel => 'إنجيل';

  @override
  String get authUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get homeWordmark => 'Evangelion';

  @override
  String get homeGreetingMorning => 'صباح الخير';

  @override
  String get homeGreetingAfternoon => 'نهار الخير';

  @override
  String get homeGreetingEvening => 'مساء الخير';

  @override
  String get homeGreetingSeparator => '، ';

  @override
  String get homeStreakGlowing => 'سلسلتك متوهجة. حافظ عليها.';

  @override
  String get homeStreakResting => 'ابدأ سلسلة اليوم. يكفي قراءة واحدة.';

  @override
  String get homeStreakLabel => 'أيام متتالية';

  @override
  String get homeAvatarLabel => 'الحساب';

  @override
  String get homeUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get homeTodayReading => 'قراءة اليوم';

  @override
  String get homeContinueReading => 'متابعة القراءة';

  @override
  String get homeReadingComplete => 'اكتملت القراءة';

  @override
  String get homeReflectionProgress => 'أسئلة التأمل المجابة';

  @override
  String get homeNoQuestionsToday => 'لا توجد أسئلة تأمل اليوم';

  @override
  String get homeContinueLabel => 'متابعة';

  @override
  String get homeStartReflection => 'ابدأ التأمل';

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
  String get quizAlreadyAnsweredSuffix => 'تمت الإجابة عنها، فلا يمكن إرسالها مجددًا';

  @override
  String get quizUnavailableSuffix => 'لا توجد إجابة لعرضها';

  @override
  String get quizRetry => 'حاول مرة أخرى';

  @override
  String get quizNoQuestionsTitle => 'لا شيء للتأمل فيه';

  @override
  String get quizNoQuestionsMessage => 'لا تحتوي قراءة اليوم على أسئلة للإجابة عنها.';

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
}
