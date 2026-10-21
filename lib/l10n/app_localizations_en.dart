// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'password';

  @override
  String get authEnterTheWord => 'enter the word';

  @override
  String get authEmailInvalid => 'email looks incomplete';

  @override
  String get authPasswordTooShort => 'password too short';

  @override
  String get authUnavailableSuffix => 'unavailable in this build';

  @override
  String get authRoleLabel => 'Role';

  @override
  String get authRoleKid => 'Kid';

  @override
  String get authRoleServant => 'Servant';

  @override
  String get authRoleAdmin => 'Admin';

  @override
  String get homeGreetingMorning => 'good morning';

  @override
  String get homeGreetingAfternoon => 'good afternoon';

  @override
  String get homeGreetingEvening => 'good evening';

  @override
  String get homeGreetingSeparator => ', ';

  @override
  String get homeStreakLabel => 'Streak';

  @override
  String get homeUnavailableSuffix => 'unavailable in this build';

  @override
  String get homeGreetingVigil => 'night vigil';

  @override
  String get homePeace => 'peace';

  @override
  String get homeDays => 'days';

  @override
  String get homeVerseOfTheDay => 'verse of the day';

  @override
  String get homeLastLight => 'last light';

  @override
  String get homeNoLightRef => '—';

  @override
  String get homeNoLight => 'no light received yet — open a book below';

  @override
  String get homeResumeHint => 'resume where the light left you ›';

  @override
  String get homeSelah => 'Selah';

  @override
  String get homeSecondsOfSilence => 'seconds of silence';

  @override
  String get homeSelahBegin => 'Begin the selah';

  @override
  String get homeSelahEnd => 'End the selah';

  @override
  String get homeSelahAmen => 'selah · amen';

  @override
  String get homeTheLibrary => 'the library';

  @override
  String get homeScrolls => 'scrolls';

  @override
  String get homeOpenBooks => 'open';

  @override
  String get homeVerses => 'verses';

  @override
  String get homeSealed => 'sealed';

  @override
  String get homeCategoryPoetry => 'poetry';

  @override
  String get homeCategoryGospel => 'gospel';

  @override
  String get homeCategoryTorah => 'torah';

  @override
  String get homeCategoryProphets => 'prophets';

  @override
  String get homeCategoryHistory => 'history';

  @override
  String get homeCategoryApocalypse => 'apocalypse';

  @override
  String get leaderboardTitle => 'The Communion';

  @override
  String get leaderboardWindowWeekly => 'week';

  @override
  String get leaderboardWindowMonthly => 'month';

  @override
  String get leaderboardWindowAllTime => 'all';

  @override
  String get leaderboardEmptyTitle => 'No scores yet';

  @override
  String get leaderboardEmptyBody =>
      'Once the cohort starts answering, the standings appear here.';

  @override
  String get leaderboardUnranked => 'Not ranked yet';

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
      other: '$digits points',
      one: '1 point',
      zero: 'no points',
    );
    String _temp1 = intl.Intl.pluralLogic(
      streakCount,
      locale: localeName,
      other: '$streakDigits streaks',
      one: '1 streak',
      zero: 'no streaks',
    );
    String _temp2 = intl.Intl.selectLogic(isReader, {
      'true': ', that is you',
      'other': '',
    });
    return '$_temp0, $_temp1, $initials, rank $rank$_temp2';
  }

  @override
  String get leaderboardMetricLight => 'light';

  @override
  String get leaderboardMetricStreaks => 'streaks';

  @override
  String leaderboardWitness(String position) {
    return 'witness $position';
  }

  @override
  String get leaderboardYou => 'you';

  @override
  String leaderboardGapLine(String name, String n) {
    return '$name holds $n more light';
  }

  @override
  String leaderboardPassHint(String n) {
    return 'pass with ≈$n verses';
  }

  @override
  String get leaderboardNoReset => 'no reset · the sky remembers';

  @override
  String leaderboardResetsIn(
    String days,
    String hours,
    String dayUnit,
    String hourUnit,
  ) {
    return 'resets in ≈$days$dayUnit $hours$hourUnit';
  }

  @override
  String leaderboardCheerSent(String name) {
    return 'cheer sent to $name';
  }

  @override
  String get leaderboardVeil => 'Veil witnesses';

  @override
  String get leaderboardRetry => 'Try again';

  @override
  String get leaderboardScopeLabel => 'Period';

  @override
  String get leaderboardMetricLabel => 'Ranking metric';

  @override
  String get leaderboardDayUnit => 'd';

  @override
  String get leaderboardHourUnit => 'h';

  @override
  String get homeRetry => 'Try again';

  @override
  String get quizExit => 'Back';

  @override
  String get quizProgress => 'Quiz progress';

  @override
  String get quizRefraction => 'Refraction';

  @override
  String get quizCheckAnswer => 'Check answer';

  @override
  String get quizNextQuestion => 'next ▸';

  @override
  String get quizSeeResults => 'see results';

  @override
  String get quizCorrectSuffix => 'correct answer';

  @override
  String get quizIncorrectSuffix => 'your answer, incorrect';

  @override
  String get quizAlreadyAnsweredSuffix =>
      'already answered, so it cannot be submitted again';

  @override
  String get quizUnavailableSuffix => 'there is no answer to show';

  @override
  String get quizRetry => 'Try again';

  @override
  String get quizNoQuestionsTitle => 'Nothing to reflect on';

  @override
  String get quizNoQuestionsMessage =>
      'Today\'s reading came with no questions to answer.';

  @override
  String get readingBack => 'Back';

  @override
  String get readingTextSize => 'Text size';

  @override
  String get readingFontSize => 'Font size';

  @override
  String get readingDecreaseFontSize => 'Decrease font size';

  @override
  String get readingIncreaseFontSize => 'Increase font size';

  @override
  String get readingBookmark => 'Bookmark';

  @override
  String get readingUnavailableSuffix => 'unavailable in this build';

  @override
  String get readingPassage => 'Scripture passage';

  @override
  String get readingVerse => 'Verse';

  @override
  String get readingRetry => 'Try again';

  @override
  String get resultReflectAgain => 'Reflect again';

  @override
  String get resultBackHome => 'Back';

  @override
  String get resultThisAnswer => 'This answer';

  @override
  String get resultBestRun => 'Best run';

  @override
  String get resultDay => 'Day';

  @override
  String get resultLongestYet => 'your longest yet';

  @override
  String get resultCompleteMessage =>
      'Correct, and today\'s reading is complete.';

  @override
  String get resultPartialMessage =>
      'Correct. The reading is not finished yet.';

  @override
  String get resultIncorrectMessage => 'Not this time. Every question counts.';

  @override
  String resultTotalCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'points',
      one: 'point',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'The Workshop';

  @override
  String get settingsBack => 'Back';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsWsLang => 'language';

  @override
  String get settingsThemeGroup => 'theme';

  @override
  String get settingsDaylight => 'Daylight mode';

  @override
  String get settingsWsLight => 'the light workshop';

  @override
  String get settingsShaderEngine => 'Aurora engine';

  @override
  String get settingsCurtainShape => 'Curtain shape';

  @override
  String get settingsCurtainTop => 'top';

  @override
  String get settingsCurtainBottom => 'bottom';

  @override
  String get settingsCurtainSides => 'sides';

  @override
  String get settingsCurtainShafts => 'shafts';

  @override
  String get settingsReach => 'Reach';

  @override
  String get settingsBrightness => 'Brightness';

  @override
  String get settingsTouchGlow => 'Touch glow';

  @override
  String get settingsHue => 'Hue';

  @override
  String get settingsMultichromeMelt => 'Multichrome melt';

  @override
  String get settingsRayCombing => 'Ray combing';

  @override
  String get settingsWhiteCores => 'White cores';

  @override
  String get settingsDotVeil => 'Dot veil';

  @override
  String get settingsSkyGroup => 'witness sky';

  @override
  String get settingsStars => 'Stars';

  @override
  String get settingsConstellations => 'Constellations';

  @override
  String get settingsStarCount => 'Star count';

  @override
  String get settingsStarBrightness => 'Star brightness';

  @override
  String get settingsStarShape => 'Star shape';

  @override
  String get settingsStarField => 'Star field';

  @override
  String get settingsTwinkle => 'Twinkle';

  @override
  String get settingsRitualGroup => 'focus & ritual';

  @override
  String get settingsFocusDelay => 'Focus delay';

  @override
  String get settingsSelahLength => 'Selah length';

  @override
  String get settingsBreathGuide => 'Breath guide';

  @override
  String get settingsVespersAutoDim => 'Vespers auto-dim';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsCalmMotion => 'Calm motion';

  @override
  String get settingsHaptics => 'Haptics';

  @override
  String get settingsCommunionGroup => 'communion';

  @override
  String get settingsVeilWitnesses => 'Veil witnesses';

  @override
  String get settingsShowPodium => 'Show podium';

  @override
  String get settingsTypeSize => 'Type size';

  @override
  String get settingsFontScale => 'Font scale';

  @override
  String get settingsDecreaseFontSize => 'Decrease font size';

  @override
  String get settingsIncreaseFontSize => 'Increase font size';

  @override
  String get settingsRestoreDefaults => 'Restore nocturne defaults';

  @override
  String get settingsRestored => '↺ nocturne defaults restored';

  @override
  String get settingsAbout => 'about';

  @override
  String get settingsShaders => 'Shaders';

  @override
  String get settingsTokens => 'Tokens';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'Arabic';

  @override
  String get settingsPreferencesUnavailable =>
      'Your preferences could not be saved on this device.';

  @override
  String get settingsRetry => 'Try again';

  @override
  String get dockHome => 'Home';

  @override
  String get dockRead => 'Read';

  @override
  String get dockToday => 'Today';

  @override
  String get dockBoard => 'Communion';

  @override
  String get dockJourney => 'Journey';

  @override
  String get readingVerses => 'verses';

  @override
  String get readingQuiz => 'quiz';

  @override
  String get readingQuestions => 'questions';

  @override
  String get readingListen => 'listen';

  @override
  String get readingSky => 'sky';

  @override
  String get readingBookmarkOn => 'bookmarked';

  @override
  String get readingBookmarkOff => 'bookmark removed';

  @override
  String get journeyTitle => 'Journey';

  @override
  String get journeyScribe => 'scribe · level 7';

  @override
  String get journeyStreakSub => 'day streak · keep the flame';

  @override
  String get journeyRingVerses => 'verses';

  @override
  String get journeyRingQuizzes => 'quizzes';

  @override
  String get journeyRingAccuracy => 'accuracy';

  @override
  String get journeySky => 'sky';

  @override
  String get journeyStarsLit => 'stars lit';

  @override
  String get journeyConstellations => 'constellations';

  @override
  String get journeyMedals => 'medals';

  @override
  String get journeyMedalFirstLight => 'first light';

  @override
  String get journeyMedalPsalmist => 'psalmist';

  @override
  String get journeyMedalStreakSeven => 'streak ×7';

  @override
  String get journeyMedalJohn => 'john';

  @override
  String get journeyAccount => 'account';

  @override
  String get journeyRowBoard => 'The Communion';

  @override
  String get journeyRowSettings => 'Settings';

  @override
  String get journeyRowShare => 'Share progress';

  @override
  String get journeyRowPlans => 'Reading plans';

  @override
  String get journeyUnavailableSuffix => 'unavailable in this build';

  @override
  String get journeyRetry => 'Try again';

  @override
  String get servantHubTitle => 'Servant portal';

  @override
  String get servantHubReportTitle => 'Daily report';

  @override
  String get servantHubScheduleTitle => 'Schedule a reading';

  @override
  String get servantHubQuestionsTitle => 'Author questions';

  @override
  String get servantHubReaderTitle => 'Read as a reader';

  @override
  String get servantReportTitle => 'Daily report';

  @override
  String get servantReportGroupLabel => 'Cohort';

  @override
  String get servantReportDateLabel => 'Date';

  @override
  String get servantReportSubmit => 'Show the roster';

  @override
  String get servantReportTotalStudents => 'Children';

  @override
  String get servantReportCompleted => 'Completed';

  @override
  String get servantReportEmptyTitle => 'No roster';

  @override
  String get servantReportEmptyMessage =>
      'This cohort has no children for that day.';

  @override
  String get servantReportRetry => 'Try again';

  @override
  String get servantReportPoints => 'Points';

  @override
  String get servantReportStreak => 'Streak';

  @override
  String get servantReportProgress => 'Questions';

  @override
  String get servantReportInvalidGroup => 'The cohort must be a whole number.';

  @override
  String get servantReportMissingDate => 'The date is required.';

  @override
  String get servantScheduleTitle => 'Schedule a reading';

  @override
  String get servantScheduleGroupIdsLabel => 'Cohort ids';

  @override
  String get servantScheduleGroupIdsHint => 'comma separated';

  @override
  String get servantScheduleDateLabel => 'Date';

  @override
  String get servantScheduleDateHint => 'year, month, day';

  @override
  String get servantScheduleBookLabel => 'Book number';

  @override
  String get servantScheduleStartChapterLabel => 'Start chapter';

  @override
  String get servantScheduleStartVerseLabel => 'Start verse';

  @override
  String get servantScheduleEndChapterLabel => 'End chapter';

  @override
  String get servantScheduleEndVerseLabel => 'End verse';

  @override
  String get servantScheduleExcludedLabel => 'Excluded verses';

  @override
  String get servantScheduleExcludedHint =>
      'chapter and verse, comma separated';

  @override
  String get servantScheduleAiLabel => 'Generate the question with AI';

  @override
  String get servantScheduleAiWarning =>
      'Scheduling the same cohort and date again with this on deletes the questions already written for that date.';

  @override
  String get servantScheduleUpsertWarning =>
      'Scheduling the same cohort and date again replaces the passage.';

  @override
  String get servantScheduleSubmit => 'Schedule the reading';

  @override
  String get servantScheduleRetry => 'Try again';

  @override
  String get servantScheduleErrorEmptyGroupIds => 'Name at least one cohort.';

  @override
  String get servantScheduleErrorInvalidNumber => 'That is not a whole number.';

  @override
  String get servantScheduleErrorInvalidDate =>
      'The date must be written as year, month, day.';

  @override
  String get servantScheduleErrorInvalidExcludedVerse =>
      'An excluded verse is written as a chapter and a verse.';

  @override
  String get servantScheduleErrorReversedRange =>
      'The start of the passage cannot be after its end.';

  @override
  String get servantQuestionsTitle => 'Author questions';

  @override
  String get servantQuestionsReadingIdLabel => 'Reading id';

  @override
  String get servantQuestionsReadingIdNote =>
      'There is no list of a cohort\'s scheduled readings, so this id is the one the schedule answered with or one you typed.';

  @override
  String get servantQuestionsTypeLabel => 'Question type';

  @override
  String get servantQuestionsTypeMcq => 'Multiple choice';

  @override
  String get servantQuestionsTypeTrueFalse => 'True or false';

  @override
  String get servantQuestionsTypeShortAnswer => 'Short answer';

  @override
  String get servantQuestionsPromptArLabel => 'Question in Arabic';

  @override
  String get servantQuestionsPromptEnLabel => 'Question in English';

  @override
  String get servantQuestionsOptionArLabel => 'Option in Arabic';

  @override
  String get servantQuestionsOptionEnLabel => 'Option in English';

  @override
  String get servantQuestionsCorrectAnswerLabel => 'Correct answer';

  @override
  String get servantQuestionsPointsLabel => 'Points';

  @override
  String get servantQuestionsOrderLabel => 'Order';

  @override
  String get servantQuestionsDraftButton => 'Ask for a draft';

  @override
  String get servantQuestionsCommitButton => 'Commit the question';

  @override
  String get servantQuestionsAddOption => 'Add an option';

  @override
  String get servantQuestionsRemoveOption => 'Remove';

  @override
  String get servantQuestionsRetry => 'Try again';

  @override
  String get servantQuestionsErrorMissingReadingId =>
      'Type the reading id first.';

  @override
  String get servantQuestionsErrorEmptyPrompt =>
      'The question needs both languages.';

  @override
  String get servantQuestionsErrorEmptyCorrectAnswer =>
      'Say which answer is correct.';

  @override
  String get servantQuestionsEmptyOptions =>
      'A short-answer question has no options.';

  @override
  String get servantQuestionsErrorInvalidNumber =>
      'That is not a whole number.';

  @override
  String get servantQuestionsErrorDraftForAnotherReading =>
      'This draft is about another reading. Ask for a draft again, or change the reading id.';
}
