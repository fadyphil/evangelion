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
  String get leaderboardTitle => 'Cohort standings';

  @override
  String get leaderboardWindowWeekly => 'Week';

  @override
  String get leaderboardWindowMonthly => 'Month';

  @override
  String get leaderboardWindowAllTime => 'All time';

  @override
  String get leaderboardEmptyTitle => 'No scores yet';

  @override
  String get leaderboardEmptyBody =>
      'Once the cohort starts answering, the standings appear here.';

  @override
  String get leaderboardYourRank => 'You';

  @override
  String get leaderboardUnranked => 'Not ranked yet';

  @override
  String get leaderboardScoreLabel => 'points';

  @override
  String get leaderboardOpenFull => 'See all';

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
      other: '$digits points',
      one: '1 point',
      zero: 'no points',
    );
    String _temp1 = intl.Intl.selectLogic(isReader, {
      'true': ', that is you',
      'other': '',
    });
    return '$_temp0, $initials, rank $rank$_temp1';
  }

  @override
  String get homeRetry => 'Try again';

  @override
  String get quizExit => 'Close';

  @override
  String get quizProgress => 'Question';

  @override
  String get quizOfWord => 'of';

  @override
  String get quizCheckAnswer => 'Check answer';

  @override
  String get quizNextQuestion => 'Next question';

  @override
  String get quizSeeResults => 'See results';

  @override
  String get quizCorrectSuffix => 'correct answer';

  @override
  String get quizIncorrectSuffix => 'your answer, incorrect';

  @override
  String get quizVerdictCorrect => 'Correct.';

  @override
  String get quizVerdictIncorrect => 'Not this time.';

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
  String get settingsTitle => 'Settings';

  @override
  String get settingsBack => 'Back';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsFontScale => 'Font scale';

  @override
  String get settingsDecreaseFontSize => 'Decrease font size';

  @override
  String get settingsIncreaseFontSize => 'Increase font size';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsMotionOn => 'On';

  @override
  String get settingsMotionOff => 'Off';

  @override
  String get settingsPreferencesUnavailable =>
      'Your preferences could not be saved on this device.';

  @override
  String get settingsRetry => 'Try again';

  @override
  String get settingsReading => 'Reading';

  @override
  String get settingsDefaultLanguage => 'Default language';

  @override
  String get settingsLanguageSheetTitle => 'Choose a language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'Arabic';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get sealFabOpen => 'Open menu';

  @override
  String get sealFabClose => 'Close menu';

  @override
  String get sealFabSettings => 'Settings';

  @override
  String get sealFabLeaderboard => 'Leaderboard';

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
}
