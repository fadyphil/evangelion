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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The product's name, above the tagline. Transcribed: LoginScreen.tsx:29.
  ///
  /// DELIBERATELY THE SAME IN BOTH ARMS. The wordmark stays `Evangelion` in Arabic too: it is the product's name in every language, and transliterating a brand mark is a product decision rather than a translation. This is the ONLY auth/home string permitted to hold Latin script on the Arabic arm, and `test/l10n/app_localizations_test.dart` excepts exactly this key by name.
  ///
  /// In en, this message translates to:
  /// **'Evangelion'**
  String get authWordmark;

  /// Transcribed: LoginScreen.tsx:32.
  ///
  /// The prototype is ENGLISH ONLY — `eva/src` has one `LoginScreen.tsx` and no Arabic variant — so every Arabic value in this file is written rather than transcribed, and none of them is presented as the prototype's. The three words are the product's own: the same three the design already carries, and reading and remembering are the point of a Sunday-school reading app.
  ///
  /// In en, this message translates to:
  /// **'Read. Reflect. Remember.'**
  String get authTagline;

  /// The email field's label, which is also its semantics name. Transcribed: LoginScreen.tsx:49.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// The email field's placeholder. Transcribed: LoginScreen.tsx:49.
  ///
  /// DELIBERATELY LATIN ON THE ARABIC ARM. An email address is an ASCII-domain string by definition; transliterating it would produce an address that cannot be typed.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get authEmailHint;

  /// The password field's label. Transcribed: LoginScreen.tsx:51.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// The password field's placeholder. Transcribed: LoginScreen.tsx:51.
  ///
  /// DELIBERATELY IDENTICAL IN BOTH ARMS, because Arabic digits and Latin digits both differ per locale and a masked placeholder that changed shape would be re-measuring the field on every locale switch.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get authPasswordHint;

  /// The primary button. Transcribed: LoginScreen.tsx:64.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// The "Forgot password?" control. Transcribed: LoginScreen.tsx:66.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// The half of the sign-up row that is not a control. Transcribed: LoginScreen.tsx:69.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authNewHere;

  /// The "Create account" control. Transcribed: LoginScreen.tsx:71.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// The label in the divider. Transcribed: LoginScreen.tsx:78.
  ///
  /// `HairlineDivider`'s own doc records why this is a caller string at all: `LoginPage` passes this and has nothing else to say, so a hard-coded English literal in `core/` would be the half-translated UI this app exists not to ship.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authDivider;

  /// The Google button. Transcribed: LoginScreen.tsx:84.
  ///
  /// This control, and the three beside it, SHIP DISABLED by design — there is no auth endpoint on the backend (AGENT_CONTEXT §2 decision 3) — which is why `authUnavailableSuffix` exists.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// The Apple button. Transcribed: LoginScreen.tsx:85. Ships disabled, as `authContinueWithGoogle` says.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// The password toggle's name while the password is masked. Written, not transcribed — the prototype's toggle is an icon-only `<button>` with no accessible name at all.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// The password toggle's name while the password is visible. Written, as `authShowPassword` says.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// The seal's accessible name. Transcribed from `SealMonogram.semanticLabel`.
  ///
  /// DELIBERATELY `Evangelion` AND NOT `authWordmark`'s transliterated form, because it names the SEAL — the monogram mark — and not the wordmark above it. The Arabic value is the prototype's brand form `إنجيل`; see `authWordmark` for why that is a different decision.
  ///
  /// In en, this message translates to:
  /// **'Evangelion'**
  String get authSealLabel;

  /// Appended to a permanently-disabled control's name, so a screen reader announces WHY it cannot be pressed instead of only that it cannot.
  ///
  /// NAMESPACED `auth*` because FOUR features carry a field of this name and they are NOT the same string: /quiz's says there is no answer to show. See `quizUnavailableSuffix`.
  ///
  /// APPENDED BY THE CALL SITE, NEVER BAKED IN — two inert controls on `/login` share labels, and a suffix inside the label would render "unavailable in this build - unavailable in this build".
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get authUnavailableSuffix;

  /// The product's name, in the top bar. Transcribed: ds.tsx:508.
  ///
  /// DELIBERATELY LATIN ON THE ARABIC ARM, for `authWordmark`'s reason — it is a brand mark, not a sentence. `app_top_bar.dart` records a measurement here: replacing this with the Arabic transliteration was tried and reverted.
  ///
  /// NAMESPACED `home*` because `authWordmark` is a different control drawing the same mark.
  ///
  /// In en, this message translates to:
  /// **'Evangelion'**
  String get homeWordmark;

  /// 05:00-11:59. `HomeScreen.tsx:26` writes `Good evening, `; the three words are `greeting_period.dart`'s decision and that file says so.
  ///
  /// The split into three keys rather than one key plus a period is because the prototype's own string is a single lead-in (`…evening, `) and the client's greeting is period-dependent from a live clock.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// 12:00-17:59. See `homeGreetingMorning` — the prototype writes no afternoon arm at all.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// 18:00-04:59. The prototype's own word: `HomeScreen.tsx:26`.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// What follows the greeting word when a name comes after it.
  ///
  /// A KEY AND NOT A CHARACTER IN CODE, because it is the one place the two arms genuinely differ and it is the difference a translator would otherwise have to find by reading the greeting code. English takes `, `; Arabic takes `، ` — U+060C ARABIC COMMA, a DIFFERENT codepoint from U+002C which renders at a different height. Substituting one for the other produces text that is right and looks wrong, which is the failure mode a bilingual string table exists to prevent.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get homeGreetingSeparator;

  /// Under the greeting, when the streak is alive. Transcribed VERBATIM: HomeScreen.tsx:30.
  ///
  /// CONDITIONAL where the prototype's was not — see `homeStreakResting`.
  ///
  /// In en, this message translates to:
  /// **'Your streak is glowing. Keep it alive.'**
  String get homeStreakGlowing;

  /// Under the greeting, when the streak is at zero.
  ///
  /// NOT IN THE PROTOTYPE, AND NOT OPTIONAL. HomeScreen.tsx:30 is an unconditional literal, so on the live payload — `streak/summary.current_streak` is `0` — the app would tell a reader their streak is glowing while drawing a flame beside the number `0`. That is the same class of defect as the hard-coded greeting name Phase 7 removed: a prototype string that contradicts live data.
  ///
  /// REJECTED: shipping `homeStreakGlowing` unconditionally and recording the lie. Rejected because the number is on screen two inches away.
  ///
  /// In en, this message translates to:
  /// **'Start a streak today. One reading is all it takes.'**
  String get homeStreakResting;

  /// The streak count's accessible name, as a PREFIX. `StreakFlame.semanticLabel`.
  ///
  /// A PREFIX AND NOT A PLURALISED PHRASE, and the reason is recorded rather than assumed: the announcement is composed by the row as `$streakLabel: $count`. Converting this to an ICU plural would change the announcement's SHAPE from "Streak: 5" to "5-day streak", which is a UX change and not a localization one. The Arabic value is already a PLURAL NOUN (`أيام متتالية`, "consecutive days"), so a count beside it is grammatically sound. See `readingCaptionFor` for a count that IS genuinely plural-dependent.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get homeStreakLabel;

  /// The avatar's accessible name when the session has no name to read.
  ///
  /// ds.tsx:525 renders the monogram `MK` inside a `<button>` with NO LABEL AT ALL — §14's first row, and defect #11. So the button is named, and when there is a session the name is better than a noun: `HomePage` passes the display name and falls back to this.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get homeAvatarLabel;

  /// Appended to the avatar's name while the control is inert.
  ///
  /// The same wording, and the same reasoning, as `authUnavailableSuffix`: a screen reader should be told WHY the control cannot be pressed, not only that it cannot. NAMESPACED `home*` because four features carry this field name and /quiz's differs.
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get homeUnavailableSuffix;

  /// The panel's accessible name. `GlassSurface.semanticLabel`.
  ///
  /// In en, this message translates to:
  /// **'Today\'s reading'**
  String get homeTodayReading;

  /// The panel's eyebrow. Transcribed: HomeScreen.tsx:44.
  ///
  /// CONDITIONAL, because the live reading is finished (`is_fully_completed: true`) and the prototype's literal would then be false. See `homeReadingComplete`; this is the STATUS line the panel's `isFullyCompleted` drives.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get homeContinueReading;

  /// The eyebrow when `is_fully_completed` is true. NOT in the prototype — the prototype has no data layer and so no completed state.
  ///
  /// In en, this message translates to:
  /// **'Reading complete'**
  String get homeReadingComplete;

  /// `ProgressBeads.semanticLabel`'s prefix.
  ///
  /// The prototype's beads described PASSAGE progress across a cut grid (HomeScreen.tsx:65 — `total={5} completed={2} current={2}`); these count REFLECTION QUESTIONS, which is what the live payload carries. `ProgressBeads` appends "N of M complete" itself.
  ///
  /// KNOWN GAP, OUT OF SCOPE HERE, RECORDED: that "of N M complete" tail is a hard-coded English literal inside `core/design_system/widgets/progress_beads.dart:146`, so it reaches a screen reader in English on the Arabic arm. Fixing it means changing a design-system widget's signature, which is a different task from ARB migration. Not fixed, not hidden.
  ///
  /// In en, this message translates to:
  /// **'Reflections answered'**
  String get homeReflectionProgress;

  /// In place of the bead row when a reading carries no questions.
  ///
  /// A DECISION, RECORDED RATHER THAN LEFT TO AN ACCIDENT. `ProgressBeads` clamps `total` to `0` and returns `SizedBox.shrink()`, so a reading with no questions would render NOTHING between the reference and the buttons — a gap that looks like a rendering bug and reads as "there is nothing here" with no way to tell that from a layout failure. This line says which it is.
  ///
  /// In en, this message translates to:
  /// **'No reflection questions today'**
  String get homeNoQuestionsToday;

  /// The primary CTA. Transcribed: HomeScreen.tsx:71 — `ButtonPrimary`.
  ///
  /// KEPT AS THE PROTOTYPE'S, DELIBERATELY: it names an ACTION (open today's reading) and that action is available whether or not the reading is finished. The state-dependent string is the eyebrow above, which is what actually changes.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinueLabel;

  /// The secondary CTA. Transcribed: HomeScreen.tsx:72 — `ButtonText`.
  ///
  /// In en, this message translates to:
  /// **'Start reflection'**
  String get homeStartReflection;

  /// `ErrorView.retryLabel`. There is NO prototype error state at all — `eva/src` has none, because it has no data layer that can fail — so this is WRITTEN, and it says WHAT IT DOES ("Try again") rather than "Retry".
  ///
  /// NAMESPACED `home*`: three features carry this field name (`homeRetry`, `quizRetry`, `readingRetry`).
  ///
  /// `ErrorView` is the precedent for all three: a hard-coded English string inside `core/` is the half-translated UI this app exists not to ship, so the wording lives with the caller and the widget takes it.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get homeRetry;

  /// The close control's accessible name.
  ///
  /// WRITTEN, NOT TRANSCRIBED: QuizScreen.tsx:46-50 is a `<button>` around a bare inline `<svg>` cross with NO LABEL AT ALL — §14's first row, verbatim. The same obligation that forced `readingBack` forces this.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get quizExit;

  /// `ProgressBeads`' accessible-name prefix. See its own `semanticLabel`.
  ///
  /// See `homeReflectionProgress`'s description for the recorded English tail this prefix sits on.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get quizProgress;

  /// The word between the two counts in the quiz progress label.
  ///
  /// A KEY AND NOT A CONSTANT, because the two arms genuinely differ — `of` against `من` — and a constant would have had to be a `switch` over a private anchor object to stay `const`, which is more machinery than the string is worth. `reading` had a `_space` constant once because both arms spell the space identically; this is the other case, and the difference is the reason.
  ///
  /// KEY NAME: `quizOfWord` rather than `of`, because ARB keys share ONE flat namespace with every other key and `of` is both a Dart keyword and too generic to survive a grep.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get quizOfWord;

  /// The CTA before the answer is graded. Transcribed: QuizScreen.tsx:127.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get quizCheckAnswer;

  /// The CTA after the answer is graded, with a question still to come. Transcribed: QuizScreen.tsx:127.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get quizNextQuestion;

  /// The CTA on the last question. WRITTEN, NOT TRANSCRIBED: the prototype's CTA is `{checked ? 'Next question' : 'Check answer'}` — there is NO TERMINAL STATE, because the prototype has exactly one hard-coded question.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get quizSeeResults;

  /// Appended to the correct option's accessible name once it is revealed.
  ///
  /// THE SPOILER BOUNDARY'S VOCABULARY, AND IT IS BILINGUAL. The boundary itself is `QuizPage`'s; this is the word that makes it visible to a screen reader.
  ///
  /// A CITATION THAT USED TO NAME A FILE THAT DID NOT EXIST, AND THE CLAIM IS HELD TWO FILES OVER INSTEAD. An earlier version of this doc said `quiz_accessibility_test.dart` asserts the string is in the semantics tree only after a check. There is no such file and there never was. The claim is nevertheless real and is held by `quiz_page_test.dart`: its "before the reader commits to an answer" group asserts no node's label carries this string, and its "the SEMANTICS tree carries the verdict the card colours carry" test asserts exactly one does after a check.
  ///
  /// NOT CORRECTED BY CREATING THE FILE. A second /quiz test file whose subject is a subset of that spoiler group would give the boundary two homes and make "nothing leaks before a check" a claim about whichever file a reader opened.
  ///
  /// In en, this message translates to:
  /// **'correct answer'**
  String get quizCorrectSuffix;

  /// Appended to the chosen-but-wrong option's accessible name, once revealed.
  ///
  /// In en, this message translates to:
  /// **'your answer, incorrect'**
  String get quizIncorrectSuffix;

  /// The feedback banner's text on a correct answer.
  ///
  /// WRITTEN, NOT TRANSCRIBED. QuizScreen.tsx:116 reads "Exactly. Light — before anything else.", which describes THE PROTOTYPE'S OWN INVENTED OPTION SET, and this client's question is a different one. Transcribing it would put a claim about the wrong passage on the screen.
  ///
  /// In en, this message translates to:
  /// **'Correct.'**
  String get quizVerdictCorrect;

  /// The feedback banner's text on a wrong answer. Written, for `quizVerdictCorrect`'s reason.
  ///
  /// In en, this message translates to:
  /// **'Not this time.'**
  String get quizVerdictIncorrect;

  /// Appended to an option's accessible name when the wire says it is answered.
  ///
  /// §14's disabled row: a reader has to be told WHY a control cannot be pressed, not only that it cannot. `LoginPage`'s four inert social buttons and `AppTopBar`'s avatar are the precedent, and they are the reason /quiz can ship a dead CTA honestly at all.
  ///
  /// In en, this message translates to:
  /// **'already answered, so it cannot be submitted again'**
  String get quizAlreadyAnsweredSuffix;

  /// Appended to the CTA's accessible name when there is nothing to submit.
  ///
  /// NAMESPACED `quiz*` BECAUSE THIS IS NOT THE SAME STRING AS THE OTHER THREE. `authUnavailableSuffix`, `homeUnavailableSuffix` and `readingUnavailableSuffix` all say "unavailable in this build"; this one says why *this* control is unavailable, which is §14's actual requirement and a different fact.
  ///
  /// In en, this message translates to:
  /// **'there is no answer to show'**
  String get quizUnavailableSuffix;

  /// `ErrorView.retryLabel`. Written — the prototype has no data layer, so it has no error state and nothing to transcribe. NAMESPACED `quiz*`; see `homeRetry` for the three-way collision.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get quizRetry;

  /// The empty state's heading.
  ///
  /// WRITTEN, NOT TRANSCRIBED, BECAUSE THE STATE IS REACHABLE: `questions: []` is reachable — `today_reading_mapper.dart` SKIPS an unreadable question rather than refusing the passage (recorded decision 50), and decision 70 already gates /reading's CTA on `questionCount > 0`. The prototype has no such state.
  ///
  /// In en, this message translates to:
  /// **'Nothing to reflect on'**
  String get quizNoQuestionsTitle;

  /// The empty state's body. Written, for `quizNoQuestionsTitle`'s reason.
  ///
  /// In en, this message translates to:
  /// **'Today\'s reading came with no questions to answer.'**
  String get quizNoQuestionsMessage;

  /// The back control's accessible name.
  ///
  /// WRITTEN, NOT TRANSCRIBED: ReadingEnScreen.tsx:14-16 and ReadingArScreen.tsx:26-28 are `<button>`s wrapping an inline `<svg>` chevron with nothing at all — §14's first row, verbatim.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get readingBack;

  /// The `Aa` control's accessible name.
  ///
  /// **NOT `Aa`.** §14's first row lists `Aa` among the icon-only buttons that have no accessible name, and `IconActionButton`'s own doc names it as one of "the `Aa` and bookmark controls Phase 7 composes" — which is why this control is that widget with a tooltip rather than a text button whose label is its own name.
  ///
  /// A SEPARATE KEY FROM `readingFontSize`, AND A TEST PROVED IT. The first version reused one string for both, on the reasoning that "they name the same control from two positions". They do not: `readingTextSize` names the DISCLOSURE YOU PRESS and `readingFontSize` names THE SLIDER THE DISCLOSURE REVEALS — two different nodes, both focusable-adjacent, both announced. Sharing one string put two nodes on screen with the identical label, which is a §14 failure in the one place §14 is unambiguous: a screen-reader user hears "Text size" twice and cannot tell the button from the thing it opened. `reading_accessibility_test.dart` caught it in the failing direction — `_nodeLabelled` found the button's node instead of the slider's and the `isSlider` flag was false.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readingTextSize;

  /// The `FontSizeStepper`'s track, as the SLIDER's own accessible name. The Arabic pair is `حجم الخط` (the button) and `مقياس حجم الخط` (the scale itself) — see `readingTextSize`'s description for the test that forced these to be two keys.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get readingFontSize;

  /// The `FontSizeStepper`'s decrement button, as an `IconActionButton` tooltip and accessible name.
  ///
  /// WRITTEN HERE AND NOT LEFT IN THE DESIGN SYSTEM AS A LITERAL, which is what it was: `FontSizeStepper` hard-coded 'Decrease font size' and 'Increase font size', so a reader who opened the `Aa` panel on the Arabic arm was told, IN ENGLISH, what the two buttons beside them did. `ErrorView.retryLabel` is the precedent for the alternative — a design-system widget that renders a caller's script takes the caller's string, because a hard-coded English string in `core/` is the half-translated UI this app exists not to ship.
  ///
  /// AND THE PROTOTYPE HAS NO WORDING TO TRANSCRIBE: SettingsScreen.tsx:66-68 is a bare range input with `-` and `+` and no labels at all.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get readingDecreaseFontSize;

  /// The `FontSizeStepper`'s increment button. Written, for `readingDecreaseFontSize`'s reason.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get readingIncreaseFontSize;

  /// The bookmark control's accessible name, BEFORE any suffix. The bookmark has no endpoint and no port — ReadingEnScreen.tsx:19-21 draws one with no handler — so it ships INERT and says so via `readingUnavailableSuffix`.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get readingBookmark;

  /// The sticky CTA. Transcribed from BOTH prototype arms, and this is the only genuinely bilingual transcription in the file: ReadingEnScreen.tsx:87 — `ButtonPrimary` with `Begin reflection`; ReadingArScreen.tsx:85 — `ابدأ التأمل`.
  ///
  /// In en, this message translates to:
  /// **'Begin reflection'**
  String get readingBeginReflection;

  /// Appended to a control's name while that control is inert.
  ///
  /// The same wording, and the same reasoning, as `authUnavailableSuffix` and `homeUnavailableSuffix`: a reader should be told WHY a control cannot be pressed, not only that it cannot. NAMESPACED `reading*`; /quiz's is a different string.
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get readingUnavailableSuffix;

  /// The name `ScriptureBlock` gives its merged semantics node, so a screen-reader user arriving at the reading body hears WHAT they have entered rather than a bare collection of verses.
  ///
  /// Transcribed from `ScriptureBlock.semanticLabel`. Note the noun is `passage` and not `reading`: `reading` is this app's name for a whole day's session, which `/reading` is, and using it here would make the block's name and the screen's name the same word for two different things.
  ///
  /// In en, this message translates to:
  /// **'Scripture passage'**
  String get readingPassage;

  /// The PREFIX for a verse marker's accessible name, as in `Verse 3`.
  ///
  /// DELIBERATELY **NOT** AN ICU PLURAL, and this is one of the two counts that are genuinely not plural-dependent. English never writes "Verses 3" for a single marker — the marker NAMES an index, it does not count a set — and the Arabic `الآية` takes an Arabic-Indic numeral the same way. A plural here would select an `other` branch identical to the `one` branch and assert that the two agree, which is a test that cannot fail. See `readingCaptionFor` for a count that IS.
  ///
  /// In en, this message translates to:
  /// **'Verse'**
  String get readingVerse;

  /// `ErrorView.retryLabel`. The prototype has no error state at all — `eva/src` has no data layer that can fail — so this is written. NAMESPACED `reading*`; see `homeRetry` for the three-way collision.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get readingRetry;

  /// The sticky CTA's caption for a number of questions. THIS IS A REAL ICU PLURAL, and it is the reason the whole migration is worth 302 renamed test references.
  ///
  /// WHAT IT REPLACED: two hand-rolled keys (`questionSingular`/`questionPlural`) plus a `count == 1 ? … : …` expression in Dart. That expression implemented exactly ONE boundary, and `reading_strings.dart` recorded the rest as acknowledged debt.
  ///
  /// THE ARABIC DEBT THIS PAYS OFF, MEASURED. Arabic plural agreement has FOUR classes the old table did not have — 2 dual (`سؤالان`), 3-10 plural (`أسئلة`), 11-99 singular accusative (`سؤالًا`). The old `captionFor(2)` returned `٢ أسئلة`, where correct Arabic is `٢ سؤالان`. That gap was accepted then on three grounds, and all three are now obsolete: `HomeStrings.streakLabel` had declined the same decision as out of scope, the live payload carried one question, and every other class needed a number the client had never seen. ICU supplies all six classes for free and `arabic_typography_test.dart` holds the dual.
  ///
  /// TWO PLACEHOLDERS, AND WHY. `count` (int) is the ICU SELECTOR — Arabic's agreement classes are a function of the integer, so selection genuinely needs the number. `digits` (String) is the RENDERED NUMERAL, and it is a String because `gen_l10n` emits the selector as a raw Dart `int` interpolation (`'$count'`), which renders LATIN digits on the Arabic arm. That would silently undo `arabicIndicDigits` — a domain function pinned by `arabic_digits_test.dart` and `font_coverage_test.dart` — and would leave the Arabic screens showing `٥` beside `٥`, half-translated. So the numeral is supplied by the caller, from the same domain function, and this key owns only the WORDING. Verified: `flutter gen-l10n` on a single-`{count}` version emitted `'$count أسئلة'` for the `few` branch.
  ///
  /// THE COUNT IS NEVER FAKE. ReadingEnScreen.tsx:89 hard-codes `5 questions` and the live reading carries ONE question, so the prototype's literal is false by a factor of five and a hard-coded 5 is fake data that happens to match nothing the server sends.
  ///
  /// NO DURATION, AND IT IS NOT COMING. ReadingEnScreen.tsx:31 (`Genesis · Chapter 1 · 4 min`) and :89 (`5 questions · about a minute`) both carry durations, and `GET /readings/today/{lang}` has NO duration field anywhere (verified live against HEAD = 4a1c834). Deriving one from a word count is inventing a measurement, so both durations are GONE and not replaced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, zero{{digits} questions} one{{digits} question} other{{digits} questions}}'**
  String readingCaptionFor(int count, String digits);

  /// The primary button. Transcribed: ResultScreen.tsx:77.
  ///
  /// In en, this message translates to:
  /// **'Reflect again'**
  String get resultReflectAgain;

  /// The secondary button.
  ///
  /// WRITTEN, NOT TRANSCRIBED, AND TRANSCRIBING WOULD HAVE BEEN A LIE: the prototype's label is `Back to library` (ResultScreen.tsx:78) and there IS no library — AGENT_CONTEXT §2 decision 1 cut it, and the destination is `/`. The label says where the button actually goes.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get resultBackHome;

  /// The first stat tile: what this answer scored. Written, because the prototype's tile read `14 Read` and days-read is profile history with no endpoint behind it (§2 decision 1 cut the profile).
  ///
  /// In en, this message translates to:
  /// **'This answer'**
  String get resultThisAnswer;

  /// The second stat tile: the reader's best run of days.
  ///
  /// THERE IS NO THIRD TILE, and the reason is arithmetic rather than taste: the submit response has four drawable numbers and they are ALL used — on the headline, in the pill, and in these two tiles. The prototype's three tiles are profile history (days read, reflections, best score), and no endpoint could produce them. A third tile would repeat one of the other four.
  ///
  /// In en, this message translates to:
  /// **'Best run'**
  String get resultBestRun;

  /// The streak pill's leading noun. Transcribed: ResultScreen.tsx:65 — `Day 12`.
  ///
  /// DELIBERATELY **NOT** AN ICU PLURAL, and this is the judgement call in this file. The pill renders a LABEL FORM (`Day 12`, `اليوم ١٢`), not a count phrase: English `Day 12` is correct for every count including one, and Arabic `اليوم` with an Arabic-Indic numeral is the conventional label too. Making it a plural would render `Days 12` in English — ALTERING A TRANSCRIBED PROTOTYPE STRING to fix nothing — and would change the pill's visual shape on every screen that shows a streak.
  ///
  /// The count that IS genuinely plural-dependent on this screen is `resultTotalCaption`, below. `readingCaptionFor` is the other. Every other count in the app was checked and recorded in AGENT_CONTEXT decision 104.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get resultDay;

  /// Appended to the streak label when the reader is at their best. Transcribed: ResultScreen.tsx:65 — the ` — your longest yet` half of `Day 12 — your longest yet`.
  ///
  /// THE COMPARISON IS THIS CLIENT'S, NOT THE PROTOTYPE'S: the prototype's own sentence sits beside `longest_streak: 6` with `Day 12`, a hard-coded mismatch in the fixture it drew. So the words are transcribed and the `>=` test is not. See `resultStreakLabelFor`'s Dart doc for why it is `>=` and not `==`, and why a streak of `0` never claims it.
  ///
  /// In en, this message translates to:
  /// **'your longest yet'**
  String get resultLongestYet;

  /// The headline sentence: right, and the reading is finished.
  ///
  /// THREE MESSAGES AND NOT ONE, BECAUSE THE SERVER SENDS THREE STATES. `SubmitResult` carries `is_correct` AND `reading_completed`, and AGENT_CONTEXT §5 trap 4 says the streak fields only move on the second. A single "Correct." would say the same thing whether or not the reader's day is done, which is the one thing this screen exists to tell them.
  ///
  /// In en, this message translates to:
  /// **'Correct, and today\'s reading is complete.'**
  String get resultCompleteMessage;

  /// The headline sentence: right, and there is more to do. See `resultCompleteMessage`.
  ///
  /// In en, this message translates to:
  /// **'Correct. The reading is not finished yet.'**
  String get resultPartialMessage;

  /// The headline sentence: the answer was wrong.
  ///
  /// WRITTEN, NOT TRANSCRIBED. `ResultScreen.tsx:50` ships `So close. One more read and you've got it.`, which is keyed on its own hard-coded `4/5` - and this client has neither number: `SubmitResult` carries `points_earned` and `current_total_points` and **no question count** (AGENT_CONTEXT 2's route table gives `/result` no repository), so a sentence about being 'one read away' would be a claim about a measurement that does not exist. This is decision 45's rejected 'invent a measurement', and it is the largest single divergence on the screen.
  ///
  /// The consolation clause is deliberate and it is the product's, not the prototype's: a wrong answer on a five-question set is one of five, and saying so is true for every count the server can send.
  ///
  /// In en, this message translates to:
  /// **'Not this time. Every question counts.'**
  String get resultIncorrectMessage;

  /// The caption under the headline score. THIS IS A REAL ICU PLURAL, SELECTION ONLY.
  ///
  /// SELECTION ONLY, WITH NO `{digits}`, AND THAT IS THE POINT: the score itself is drawn by the page in `displayLarge` one line above, so folding the numeral in here would print it TWICE. What the count selects is the NOUN, which is exactly the thing that has to agree with it.
  ///
  /// WHY THE OLD BARE NOUN WAS AN ARABIC CORRECTNESS BUG. The value was `نقطة` — SINGULAR — for every score. `٥ نقطة` is wrong Arabic; 3-10 takes the plural `نقاط` and the dual is `نقطتان`. A noun that cannot agree with the number above it is the same class of defect as the Arabic-only plural gap `readingCaptionFor` records, and it is fixed here by the same mechanism.
  ///
  /// WHY THE ENGLISH OUTPUT DOES NOT CHANGE: every score in this app's tests and fixtures is greater than one, so the `other` branch ('points') is what was already rendered. `one{point}` is the branch that was MISSING.
  ///
  /// PASSED `result.currentTotalPoints`, the same integer the page renders above it — one count, one source.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{point} other{points}}'**
  String resultTotalCaption(int count);

  /// The screen's title, beside the back chevron. Transcribed: SettingsScreen.tsx:43 writes `Settings` in `F.display 26 / 600 / ink`.
  ///
  /// The prototype is English-only — `eva/src` has one `SettingsScreen.tsx` and no Arabic variant — so the Arabic value is written, not transcribed.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// The header row's chevron's accessible name. Transcribed by position from SettingsScreen.tsx:39-42, which draws a bare `<button>` around an inline `<svg>` with **no label at all** — §14's first row, and the reason the name is a caller string rather than a design-system default.
  ///
  /// Deliberately the same word `readingBack` uses. Two features, one sentence: a back control is called Back in both, and a second wording would be a translation decision nobody made.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBack;

  /// The first section label. Transcribed: SettingsScreen.tsx:47 writes `Appearance` through its local `SectionLabel`, which `EvaSectionHeader` now renders.
  ///
  /// The prototype's third group is `Account` (`:93`) and is CUT with the profile screen, so this screen has three groups where the prototype has four.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// The theme picker's row title. Transcribed: SettingsScreen.tsx:50 writes `Theme`.
  ///
  /// The prototype's picker is a `useState<'Light' | 'Dark' | 'System'>` whose initial value is `'Dark'`, which is why `UserSettings.themeMode`'s default is `dark` and not `system` — see `app_theme_mode.dart`'s doc.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// One of the three segments on the theme track. Transcribed: SettingsScreen.tsx:52 writes `Light`.
  ///
  /// The prototype renders the labels through `textTransform: 'uppercase'`, which Flutter has no equivalent for; `SegmentedControl` uppercases each label itself and is asserted on that. So the ARB value is the prototype's own casing and the widget changes it.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// One of the three segments on the theme track. Transcribed: SettingsScreen.tsx:52 writes `Dark`.
  ///
  /// This is the prototype's initial value (`useState<…>('Dark')`), so it is also the value a reader who has never opened this screen is in.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// One of the three segments on the theme track. Transcribed: SettingsScreen.tsx:52 writes `System`.
  ///
  /// `System` is NOT the app's default: `app_theme_mode.dart` records why it is dark instead, and this segment is the reader's way to ask for the OS's answer rather than the app's.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// The stepper's row title. Transcribed: SettingsScreen.tsx:62 writes `Font size`.
  ///
  /// NAMESPACED `settings*` rather than reused from `readingTextSize`, which is the `Aa` disclosure's tooltip on `/reading`. Same control, two positions on two screens, and the two widgets ask for their own string so a translator can move one without the other.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSize;

  /// The stepper track's slider label, announced as a slider. The prototype has no accessible name for its `<input type="range">` at all (SettingsScreen.tsx:66), so this is §14's first row applied to a control the row does not name.
  ///
  /// A distinct string from `settingsFontSize` because the two name the control from two positions — a row title and a slider — and `FontSizeStepperLabels`'s doc argues for exactly one value for its own three strings for the opposite reason.
  ///
  /// In en, this message translates to:
  /// **'Font scale'**
  String get settingsFontScale;

  /// The stepper's decrement button's tooltip and accessible name. **Written, not transcribed** — the prototype's range input supplies its own stepper affordances with no labels of its own, so §14 required two names here that the prototype never wrote.
  ///
  /// Deliberately the same sentence as `readingDecreaseFontSize`: two screens draw the same control and a second wording would be a translation decision nobody made.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get settingsDecreaseFontSize;

  /// The stepper's increment button's tooltip and accessible name. Written, as `settingsDecreaseFontSize` says.
  ///
  /// Deliberately the same sentence as `readingIncreaseFontSize`, for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get settingsIncreaseFontSize;

  /// The switch's row title. **NOT IN THE PROTOTYPE** — `SettingsScreen.tsx` has no motion row, and this control exists because AGENT_CONTEXT §14 asks for reduced motion and `app.dart` recorded that a later phase would replace the platform-only default with the persisted `UserSettings` value. This is that phase.
  ///
  /// Placed under APPEARANCE rather than READING because what it changes is how the app moves, not what it says.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// The switch's accessible name while it is on. Written, not transcribed: `EvaToggle` shipped hard-coding the English words `On` and `Off` for six phases, and no gate could see it because a semantics label is not painted — the Arabic glyph gate walks the painted tree. Phase 9 made the switch's labels required and this is the shipped spelling.
  ///
  /// The Arabic is a participle rather than a transliterated `On`, so the Arabic arm holds no Latin script and `app_localizations_test.dart`'s exception list does not grow.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsMotionOn;

  /// The switch's accessible name while it is off. Written, as `settingsMotionOn` says.
  ///
  /// `Off` and `On` are the words a screen reader has to distinguish to answer "is animation on?", so neither value may be empty and neither may be the other's translation of itself.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsMotionOff;

  /// The second section label. Transcribed: SettingsScreen.tsx:70 writes `Reading` through the same local `SectionLabel`.
  ///
  /// This group ships ONE row of the prototype's two. `SettingsScreen.tsx:92`'s verse-numbers switch is cut for scope reasons recorded at length on `SettingsPage`, because `ScriptureBlock` has no `showVerseNumbers` parameter and its marker is load-bearing for four gates this phase does not own.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsReading;

  /// The language row's title, and the row that opens the sheet. Transcribed: SettingsScreen.tsx:76 writes `Default language`.
  ///
  /// This row is where **defect #7** is fixed, and the fix is not the row — the prototype's row was never broken. It is that the control writes `UserSettings.language` and `app.dart` installs it as `MaterialApp.locale`. The sheet is `features/settings/presentation/widgets/language_sheet.dart` and its doc records that the FAB this defect names was cut with the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Default language'**
  String get settingsDefaultLanguage;

  /// The sheet's own heading. **Written, not transcribed** — the prototype draws its language pills inline (SettingsScreen.tsx:77-90) and defines no sheet, no heading and no dismiss affordance at all. A bottom sheet needs a name for §14's first row, and inventing a row for it inside the screen is this client's own contribution.
  ///
  /// The sentence is an instruction rather than a noun phrase because the sheet's two rows are both languages and neither can be named "the language".
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get settingsLanguageSheetTitle;

  /// The English row in the language sheet. Transcribed in **kind** from SettingsScreen.tsx:88, which writes the pill's own label as `l === 'EN' ? 'English' : 'العربية'` — so the prototype already draws one end of this pair in Arabic, which is where the Arabic form of `العربية` comes from.
  ///
  /// The Arabic value here is `الإنجليزية` and not `English`, deliberately: an Arabic reader who cannot read Latin would otherwise be unable to choose English, which is the one choice whose absence locks them out of the other arm. That decision also keeps `app_localizations_test.dart`'s `latinIsCorrect` exception list from growing, which an earlier draft of `settings_l10n.dart` claimed was not the case.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// The Arabic row in the language sheet. **Same word in both arms**, and that is the whole of its rule: a language names itself in its own script, and the prototype's own `العربية` pill label is the evidence.
  ///
  /// `SettingsScreen.tsx:88` writes the two-letter codes `EN` and `AR` on the pill and the full names beside them; this client draws the **names only**, because `EN` and `AR` are Latin script on the Arabic arm and the two codes are also exactly what `ReadingLanguage.code` already holds for the API path — so they are rendered from the domain enum rather than translated.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get settingsLanguageArabic;

  /// The third section label. Transcribed: SettingsScreen.tsx:107 writes `About` through the same local `SectionLabel`.
  ///
  /// The group ships ONE row of the prototype's two: `SettingsScreen.tsx:118`'s Privacy policy is cut because it is a legal document with no URL, no screen and no endpoint, and an inert row that answers "unavailable in this build" is worse than no row at all for that particular question.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// The version row's title. Transcribed: SettingsScreen.tsx:115 writes `Version`, with the value beside it.
  ///
  /// The **value** is `AppConfig.appVersion`, not an ARB key, because it is not prose: it is `pubspec.yaml`'s own `version:` with a build suffix, and `settings_page_test.dart` parses `pubspec.yaml` and asserts the two agree. Putting it in this file would have been a number a translator could edit and nothing would check.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
