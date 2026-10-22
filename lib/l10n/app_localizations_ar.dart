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
  String get authRoleLabel => 'الدور';

  @override
  String get authRoleKid => 'طفل';

  @override
  String get authRoleServant => 'خادم';

  @override
  String get authRoleAdmin => 'مُشرف';

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
  String get homeSelahBegin => 'ابدأ السِّلاه';

  @override
  String get homeSelahEnd => 'أنهِ السِّلاه';

  @override
  String get homeSelahAmen => 'سِلاه · آمين';

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
  String get leaderboardTitle => 'الشركة';

  @override
  String get leaderboardWindowWeekly => 'أسبوع';

  @override
  String get leaderboardWindowMonthly => 'شهر';

  @override
  String get leaderboardWindowAllTime => 'الكل';

  @override
  String get leaderboardEmptyTitle => 'لا توجد نتائج بعد';

  @override
  String get leaderboardEmptyBody =>
      'عند بدء إجابات المجموعة سيظهر الترتيب هنا.';

  @override
  String get leaderboardUnranked => 'غير مصنّف بعد';

  @override
  String leaderboardRowSemantics(
    int count,
    String digits,
    int streakCount,
    String streakDigits,
    String initials,
    String rank,
    String isReader,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits نقطة',
      many: '$digits نقطة',
      few: '$digits نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط',
    );
    String _temp1 = intl.Intl.pluralLogic(
      streakCount,
      locale: localeName,
      other: '$streakDigits شعلة',
      many: '$streakDigits شعلة',
      few: '$streakDigits شعلات',
      two: 'شعلتان',
      one: 'شعلة واحدة',
      zero: 'لا شعلات',
    );
    String _temp2 = intl.Intl.selectLogic(isReader, {
      'true': '، هذا أنت',
      'other': '',
    });
    return '$_temp0، $_temp1، $initials، المركز $rank$_temp2';
  }

  @override
  String get leaderboardMetricLight => 'نور';

  @override
  String get leaderboardMetricStreaks => 'شعلات';

  @override
  String leaderboardWitness(String position) {
    return 'شاهد $position';
  }

  @override
  String get leaderboardYou => 'أنت';

  @override
  String leaderboardGapLine(String name, String n) {
    return '$name يحمل $n نورًا أكثر';
  }

  @override
  String leaderboardPassHint(String n) {
    return 'تجاوز بـ نحو $n آيات';
  }

  @override
  String get leaderboardNoReset => 'لا تصفير · السماء تذكر';

  @override
  String leaderboardResetsIn(
    String days,
    String hours,
    String dayUnit,
    String hourUnit,
  ) {
    return 'يُصفّر بعد نحو $days$dayUnit $hours$hourUnit';
  }

  @override
  String leaderboardCheerSent(String name) {
    return 'تحية مُرسلة إلى $name';
  }

  @override
  String get leaderboardVeil => 'حجب الشهود';

  @override
  String get leaderboardRetry => 'حاول مرة أخرى';

  @override
  String get leaderboardScopeLabel => 'الفترة';

  @override
  String get leaderboardMetricLabel => 'مقياس الترتيب';

  @override
  String get leaderboardDayUnit => 'ي';

  @override
  String get leaderboardHourUnit => 'س';

  @override
  String get homeRetry => 'حاول مرة أخرى';

  @override
  String get quizExit => 'رجوع';

  @override
  String get quizProgress => 'تقدم الاختبار';

  @override
  String get quizRefraction => 'انعطاف';

  @override
  String get quizCheckAnswer => 'تحقق من الإجابة';

  @override
  String get quizNextQuestion => 'التالي';

  @override
  String get quizSeeResults => 'النتائج';

  @override
  String get quizCorrectSuffix => 'الإجابة الصحيحة';

  @override
  String get quizIncorrectSuffix => 'إجابتك غير صحيحة';

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
  String get readingUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get readingPassage => 'نص الآية';

  @override
  String get readingVerse => 'الآية';

  @override
  String get readingRetry => 'حاول مرة أخرى';

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
  String get settingsTitle => 'الورشة';

  @override
  String get settingsBack => 'رجوع';

  @override
  String get settingsLanguageLabel => 'اللغة';

  @override
  String get settingsWsLang => 'اللغة';

  @override
  String get settingsThemeGroup => 'السمة';

  @override
  String get settingsDaylight => 'وضع النهار';

  @override
  String get settingsWsLight => 'ورشة النور';

  @override
  String get settingsShaderEngine => 'محرك الشفق';

  @override
  String get settingsCurtainShape => 'شكل الستارة';

  @override
  String get settingsCurtainTop => 'أعلى';

  @override
  String get settingsCurtainBottom => 'أسفل';

  @override
  String get settingsCurtainSides => 'جوانب';

  @override
  String get settingsCurtainShafts => 'أشعة';

  @override
  String get settingsReach => 'الامتداد';

  @override
  String get settingsBrightness => 'السطوع';

  @override
  String get settingsTouchGlow => 'توهج اللمس';

  @override
  String get settingsHue => 'اللون';

  @override
  String get settingsMultichromeMelt => 'انصهار متعدد الألوان';

  @override
  String get settingsRayCombing => 'تمشيط الأشعة';

  @override
  String get settingsWhiteCores => 'قلوب بيضاء';

  @override
  String get settingsDotVeil => 'حجاب النقاط';

  @override
  String get settingsSkyGroup => 'السماء الشاهدة';

  @override
  String get settingsStars => 'النجوم';

  @override
  String get settingsConstellations => 'الأبراج';

  @override
  String get settingsStarCount => 'عدد النجوم';

  @override
  String get settingsStarBrightness => 'سطوع النجوم';

  @override
  String get settingsStarShape => 'شكل النجوم';

  @override
  String get settingsStarField => 'موضع النجوم';

  @override
  String get settingsTwinkle => 'وميض';

  @override
  String get settingsRitualGroup => 'التركيز والطقس';

  @override
  String get settingsFocusDelay => 'تأخير التركيز';

  @override
  String get settingsSelahLength => 'مدة سِلاه';

  @override
  String get settingsBreathGuide => 'دليل النَّفَس';

  @override
  String get settingsVespersAutoDim => 'خفوت الغروب';

  @override
  String get settingsReduceMotion => 'تقليل الحركة';

  @override
  String get settingsCalmMotion => 'حركة هادئة';

  @override
  String get settingsHaptics => 'الاهتزاز';

  @override
  String get settingsCommunionGroup => 'الشركة';

  @override
  String get settingsVeilWitnesses => 'حجب الشهود';

  @override
  String get settingsShowPodium => 'إظهار المنصة';

  @override
  String get settingsTypeSize => 'حجم الخط';

  @override
  String get settingsFontScale => 'مقياس حجم الخط';

  @override
  String get settingsDecreaseFontSize => 'تصغير الخط';

  @override
  String get settingsIncreaseFontSize => 'تكبير الخط';

  @override
  String get settingsRestoreDefaults => 'استعادة الافتراضي';

  @override
  String get settingsRestored => '↺ استُعيدت الافتراضيات';

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsShaders => 'الظلال';

  @override
  String get settingsTokens => 'الرموز';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String get settingsLanguageEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsPreferencesUnavailable =>
      'تعذّر حفظ تفضيلاتك على هذا الجهاز.';

  @override
  String get settingsRetry => 'حاول مرة أخرى';

  @override
  String get dockHome => 'الرئيسية';

  @override
  String get dockRead => 'اقرأ';

  @override
  String get dockToday => 'اليوم';

  @override
  String get dockBoard => 'الشركة';

  @override
  String get dockJourney => 'الرحلة';

  @override
  String get readingVerses => 'آيات';

  @override
  String get readingQuiz => 'اختبار';

  @override
  String get readingQuestions => 'أسئلة';

  @override
  String get readingListen => 'استمع';

  @override
  String get readingSky => 'سماء';

  @override
  String get readingBookmarkOn => 'تم الحفظ';

  @override
  String get readingBookmarkOff => 'أُزيل الحفظ';

  @override
  String get journeyTitle => 'الرحلة';

  @override
  String get journeyScribe => 'كاتبة · المستوى ٧';

  @override
  String get journeyStreakSub => 'أيام متتالية · أبقِ الشعلة';

  @override
  String get journeyRingVerses => 'آيات';

  @override
  String get journeyRingQuizzes => 'اختبارات';

  @override
  String get journeyRingAccuracy => 'دقة';

  @override
  String get journeySky => 'سماء';

  @override
  String get journeyStarsLit => 'نجوم مضاءة';

  @override
  String get journeyConstellations => 'أبراج';

  @override
  String get journeyMedals => 'الأوسمة';

  @override
  String get journeyMedalFirstLight => 'أول نور';

  @override
  String get journeyMedalPsalmist => 'مرنّمة';

  @override
  String get journeyMedalStreakSeven => '٧ أيام';

  @override
  String get journeyMedalJohn => 'يوحنا';

  @override
  String get journeyAccount => 'الحساب';

  @override
  String get journeyRowBoard => 'الشركة';

  @override
  String get journeyRowSettings => 'الإعدادات';

  @override
  String get journeyRowShare => 'مشاركة التقدم';

  @override
  String get journeyRowPlans => 'خطط القراءة';

  @override
  String get journeyUnavailableSuffix => 'غير متاح في هذه النسخة';

  @override
  String get journeyRetry => 'حاول مرة أخرى';

  @override
  String get servantHubTitle => 'بوابة الخدام';

  @override
  String get servantHubReportTitle => 'التقرير اليومي';

  @override
  String get servantHubScheduleTitle => 'جدولة قراءة';

  @override
  String get servantHubQuestionsTitle => 'صياغة الأسئلة';

  @override
  String get servantHubReaderTitle => 'اقرأ كقارئ';

  @override
  String get servantReportTitle => 'التقرير اليومي';

  @override
  String get servantReportGroupLabel => 'المجموعة';

  @override
  String get servantReportDateLabel => 'التاريخ';

  @override
  String get servantReportSubmit => 'اعرض القائمة';

  @override
  String get servantReportTotalStudents => 'الأطفال';

  @override
  String get servantReportCompleted => 'أكملوا';

  @override
  String get servantReportEmptyTitle => 'لا قائمة';

  @override
  String get servantReportEmptyMessage =>
      'لا يوجد أطفال في هذه المجموعة في ذلك اليوم.';

  @override
  String get servantReportRetry => 'حاول مرة أخرى';

  @override
  String get servantReportPoints => 'النقاط';

  @override
  String get servantReportStreak => 'أيام متتالية';

  @override
  String get servantReportProgress => 'الأسئلة';

  @override
  String get servantReportInvalidGroup => 'يجب أن تكون المجموعة عددًا صحيحًا.';

  @override
  String get servantReportMissingDate => 'التاريخ مطلوب.';

  @override
  String get servantReportInvalidDate => 'يجب كتابة التاريخ سنة ثم شهر ثم يوم.';

  @override
  String get servantScheduleTitle => 'جدولة قراءة';

  @override
  String get servantScheduleGroupIdsLabel => 'أرقام المجموعات';

  @override
  String get servantScheduleGroupIdsHint => 'مفصولة بفواصل';

  @override
  String get servantScheduleDateLabel => 'التاريخ';

  @override
  String get servantScheduleDateHint => 'سنة ثم شهر ثم يوم';

  @override
  String get servantScheduleBookLabel => 'رقم الكتاب';

  @override
  String get servantScheduleStartChapterLabel => 'الفصل الأول';

  @override
  String get servantScheduleStartVerseLabel => 'الآية الأولى';

  @override
  String get servantScheduleEndChapterLabel => 'الفصل الأخير';

  @override
  String get servantScheduleEndVerseLabel => 'الآية الأخيرة';

  @override
  String get servantScheduleExcludedLabel => 'الآيات المستثناة';

  @override
  String get servantScheduleExcludedHint => 'فصل ثم آية، مفصولة بفواصل';

  @override
  String get servantScheduleAiLabel => 'ولّد السؤال بالذكاء الاصطناعي';

  @override
  String get servantScheduleAiWarning =>
      'إعادة الجدولة لنفس المجموعة في نفس التاريخ مع تفعيل هذا تحذف الأسئلة المكتوبة لذلك التاريخ.';

  @override
  String get servantScheduleUpsertWarning =>
      'إعادة جدولة نفس المجموعة في نفس التاريخ تستبدل الفصل.';

  @override
  String get servantScheduleSubmit => 'جدولة القراءة';

  @override
  String get servantScheduleRetry => 'حاول مرة أخرى';

  @override
  String get servantScheduleErrorEmptyGroupIds =>
      'اذكر مجموعة واحدة على الأقل.';

  @override
  String get servantScheduleErrorInvalidNumber => 'هذا ليس عددًا صحيحًا.';

  @override
  String get servantScheduleErrorInvalidDate =>
      'يجب كتابة التاريخ سنة ثم شهر ثم يوم.';

  @override
  String get servantScheduleErrorInvalidExcludedVerse =>
      'تُكتب الآية المستثناة فصلًا ثم آية.';

  @override
  String get servantScheduleErrorReversedRange =>
      'لا يمكن أن يبدأ الفصل بعد نهايته.';

  @override
  String get servantQuestionsTitle => 'صياغة الأسئلة';

  @override
  String get servantQuestionsReadingIdLabel => 'معرّف القراءة';

  @override
  String get servantQuestionsReadingIdNote =>
      'لا توجد قائمة بالقراءات المجدولة، فهذا المعرّف هو ما أجب عنه الجدولة أو ما كتبته.';

  @override
  String get servantQuestionsTypeLabel => 'نوع السؤال';

  @override
  String get servantQuestionsTypeMcq => 'اختيار من متعدد';

  @override
  String get servantQuestionsTypeTrueFalse => 'صح أم خطأ';

  @override
  String get servantQuestionsTypeShortAnswer => 'إجابة قصيرة';

  @override
  String get servantQuestionsPromptArLabel => 'السؤال بالعربية';

  @override
  String get servantQuestionsPromptEnLabel => 'السؤال بالإنجليزية';

  @override
  String get servantQuestionsOptionArLabel => 'الخيار بالعربية';

  @override
  String get servantQuestionsOptionEnLabel => 'الخيار بالإنجليزية';

  @override
  String get servantQuestionsCorrectAnswerLabel => 'الإجابة الصحيحة';

  @override
  String get servantQuestionsPointsLabel => 'النقاط';

  @override
  String get servantQuestionsOrderLabel => 'الترتيب';

  @override
  String get servantQuestionsDraftButton => 'اطلب مسودة';

  @override
  String get servantQuestionsCommitButton => 'اعتمد السؤال';

  @override
  String get servantQuestionsAddOption => 'أضف خيارًا';

  @override
  String get servantQuestionsRemoveOption => 'احذف';

  @override
  String get servantQuestionsRetry => 'حاول مرة أخرى';

  @override
  String get servantQuestionsErrorMissingReadingId =>
      'اكتب معرّف القراءة أولًا.';

  @override
  String get servantQuestionsErrorEmptyPrompt => 'السؤال يحتاج إلى اللغتين.';

  @override
  String get servantQuestionsErrorEmptyCorrectAnswer => 'حدّد الإجابة الصحيحة.';

  @override
  String get servantQuestionsEmptyOptions =>
      'سؤال الإجابة القصيرة لا يحتاج خيارات.';

  @override
  String get servantQuestionsErrorInvalidNumber => 'هذا ليس عددًا صحيحًا.';

  @override
  String get servantQuestionsErrorDraftForAnotherReading =>
      'هذه المسودة عن قراءة أخرى. اطلب مسودة من جديد أو غيّر معرّف القراءة.';

  @override
  String get servantHubRoleAdmin => 'خادم مُشرف';

  @override
  String get servantHubRoleViewer => 'خادم';

  @override
  String get servantHubRoleReader => 'قارئ';

  @override
  String get servantHubReportBlurb => 'من أكمل قراءة اليوم.';

  @override
  String get servantHubScheduleBlurb =>
      'اختر المقطع الذي تقرؤه المجموعة التالية.';

  @override
  String get servantHubQuestionsBlurb => 'اكتب السؤال الذي تُقدَّم به القراءة.';

  @override
  String get servantHubReaderBlurb =>
      'قراءة اليوم، ولوحة المجموعة، ورحلة القارئ.';

  @override
  String get servantHubDutiesLabel => 'مهام المُشرف';

  @override
  String get servantCohortAndDayLabel => 'المجموعة واليوم';

  @override
  String get servantPassageLabel => 'المقطع';

  @override
  String get servantQuestionLabel => 'السؤال';

  @override
  String get servantTheReadingLabel => 'القراءة';

  @override
  String get servantAnswerLabel => 'الإجابة';
}
