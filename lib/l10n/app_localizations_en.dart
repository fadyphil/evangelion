// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authWordmark => 'Evangelion';

  @override
  String get authTagline => 'Read. Reflect. Remember.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => '••••••••';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNewHere => 'New here?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authDivider => 'or';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSealLabel => 'Evangelion';

  @override
  String get authUnavailableSuffix => 'unavailable in this build';

  @override
  String get homeWordmark => 'Evangelion';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingSeparator => ', ';

  @override
  String get homeStreakGlowing => 'Your streak is glowing. Keep it alive.';

  @override
  String get homeStreakResting => 'Start a streak today. One reading is all it takes.';

  @override
  String get homeStreakLabel => 'Streak';

  @override
  String get homeAvatarLabel => 'Account';

  @override
  String get homeUnavailableSuffix => 'unavailable in this build';

  @override
  String get homeTodayReading => 'Today\'s reading';

  @override
  String get homeContinueReading => 'Continue reading';

  @override
  String get homeReadingComplete => 'Reading complete';

  @override
  String get homeReflectionProgress => 'Reflections answered';

  @override
  String get homeNoQuestionsToday => 'No reflection questions today';

  @override
  String get homeContinueLabel => 'Continue';

  @override
  String get homeStartReflection => 'Start reflection';

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
  String get quizAlreadyAnsweredSuffix => 'already answered, so it cannot be submitted again';

  @override
  String get quizUnavailableSuffix => 'there is no answer to show';

  @override
  String get quizRetry => 'Try again';

  @override
  String get quizNoQuestionsTitle => 'Nothing to reflect on';

  @override
  String get quizNoQuestionsMessage => 'Today\'s reading came with no questions to answer.';

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
  String get readingBeginReflection => 'Begin reflection';

  @override
  String get readingUnavailableSuffix => 'unavailable in this build';

  @override
  String get readingPassage => 'Scripture passage';

  @override
  String get readingVerse => 'Verse';

  @override
  String get readingRetry => 'Try again';

  @override
  String readingCaptionFor(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits questions',
      one: '$digits question',
      zero: '$digits questions',
    );
    return '$_temp0';
  }

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
  String get resultCompleteMessage => 'Correct, and today\'s reading is complete.';

  @override
  String get resultPartialMessage => 'Correct. The reading is not finished yet.';

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
}
