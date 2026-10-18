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

  /// The email field's accessible name, which `EvaTextField` puts in `Semantics(label:)`. Transcribed: redesign.html:506 — `placeholder="email"`; the redesign's field has no `<label>`, so the placeholder word is the name a browser would read and the word carried here.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// The email field's visible placeholder. Transcribed: redesign.html:506 — `placeholder="email"`.
  ///
  /// LOCALIZED ON THE ARABIC ARM, unlike `you@example.com` before it. The old placeholder was an ASCII-domain sample string that no language translates; this one is a common noun naming what the reader should type, and the redesign's own dictionary translates every word a reader acts on (`emErr` carries `البريد`). The Arabic is the standard form, and it is the same noun `authEmailLabel` carries — placeholder and accessible name agree, as a browser's would.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get authEmailHint;

  /// The password field's accessible name. Transcribed: redesign.html:507 — `placeholder="password"`; see `authEmailLabel` for why the placeholder word is the name.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// The password field's visible placeholder. Transcribed: redesign.html:507 — `placeholder="password"`, replacing the masked `••••••••` the React prototype drew.
  ///
  /// A WORD AND NOT A MASK, and that is the redesign's choice, not a change of mind about masks: the placeholder names the field the way a browser's `placeholder="password"` does, and `authPasswordLabel` carries the same noun. Deliberately localized on the Arabic arm; the word is `كلمة المرور`, which is the exact noun `pwErr` (`redesign.html:976`) already carries — no new translation is invented.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get authPasswordHint;

  /// The sign-in CTA. Transcribed: redesign.html:508 — `data-i18n="enter"`, one of the THREE strings on the redesigned login the prototype itself translates (`redesign.html:954` — `enter:["enter the word","ادخل الكلمة"]`). The Arabic is the prototype's own, not a new translation.
  ///
  /// In en, this message translates to:
  /// **'enter the word'**
  String get authEnterTheWord;

  /// The email field's error line. Transcribed: redesign.html:976 — `emErr:["email looks incomplete","البريد غير مكتمل"]`, announced by `redesign.html:1305`'s one regex test. The Arabic is the prototype's own.
  ///
  /// RENDERED BY PRESENCE, NOT BY MATCHING: the page draws this sentence when `state.emailError != null` and never compares the domain's message text, so the wording in `login_credentials.dart` is the log-canonical copy and this key is the reader's.
  ///
  /// In en, this message translates to:
  /// **'email looks incomplete'**
  String get authEmailInvalid;

  /// The password field's error line. Transcribed: redesign.html:976 — `pwErr:["password too short","كلمة المرور قصيرة"]`, announced by `redesign.html:1306`'s one length test. Rendered by presence, as `authEmailInvalid` says.
  ///
  /// In en, this message translates to:
  /// **'password too short'**
  String get authPasswordTooShort;

  /// Appended to a permanently-disabled control's name, so a screen reader announces WHY it cannot be pressed instead of only that it cannot.
  ///
  /// NAMESPACED `auth*` because FOUR features carry a field of this name and they are NOT the same string: /quiz's says there is no answer to show. See `quizUnavailableSuffix`.
  ///
  /// APPENDED BY THE CALL SITE, NEVER BAKED IN — the two inert ghost pills on `/login` share labels, and a suffix inside the label would render "unavailable in this build - unavailable in this build".
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get authUnavailableSuffix;

  /// 05:00–11:59. Transcribed: `redesign.html:926` — `morn:["good morning","صباح النور"]`, set by `applyLang` (`:988`).
  ///
  /// **The Arabic arm changed with the screen.** It was `صباح الخير` — “good morning” in the ordinary sense — because the old greeting was a status line. The redesign's own word is `صباح النور` (“morning of light”), which is a different sentence, and transcribing it is the point of the phase.
  ///
  /// The English value keeps its capital: the run is a `.mono` and `[dir=rtl] .mono` at `redesign.html:136` removes the transform only on the Arabic arm, so under LTR both spellings paint as `GOOD MORNING`.
  ///
  /// In en, this message translates to:
  /// **'good morning'**
  String get homeGreetingMorning;

  /// 12:00–17:59. Transcribed: `redesign.html:926` — `noon:["good afternoon","نهارك نور"]`. See `homeGreetingMorning` for why the Arabic arm changed, and note the prototype's own grammar: `نهارك نور` is second-person (`your day is light`) where the English is an adjective phrase. Transcribed as written.
  ///
  /// In en, this message translates to:
  /// **'good afternoon'**
  String get homeGreetingAfternoon;

  /// 18:00–23:59. Transcribed: `redesign.html:926` — `eve:["good evening","مساء النور"]`. See `homeGreetingMorning` for why the Arabic arm changed.
  ///
  /// **The bucket's end is the redesign's**: `hourKey()` (`:983-984`) returns `eve` for every hour of the evening and sends 00:00–04:59 to `vigil`, where the old three-bucket clock sent them to evening.
  ///
  /// In en, this message translates to:
  /// **'good evening'**
  String get homeGreetingEvening;

  /// What follows `homePeace` when a name comes after it.
  ///
  /// **Its subject is the greeting's second line now**, where it used to be the old lead-in's: `redesign.html:993` writes `'سلام، مريم'` / `'peace, Mariam'`, and the comma is this key.
  ///
  /// A KEY AND NOT A CHARACTER IN CODE, because it is the one place the two arms genuinely differ and it is the difference a translator would otherwise have to find by reading the greeting code. English takes `, `; Arabic takes `، ` — U+060C ARABIC COMMA, a DIFFERENT codepoint from U+002C which renders at a different height. Substituting one for the other produces text that is right and looks wrong, which is the failure mode a bilingual string table exists to prevent.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get homeGreetingSeparator;

  /// The streak count's accessible name, as a PREFIX. `StreakChip.semanticLabel`.
  ///
  /// A PREFIX AND NOT A PLURALISED PHRASE, and the reason is recorded rather than assumed: the announcement is composed by the chip as `$semanticLabel: $days $daysLabel`. Converting this to an ICU plural would change the announcement's SHAPE from “Streak: 5 days” to “5-day streak”, which is a UX change and not a localization one. The Arabic value is already a PLURAL NOUN (`أيام متتالية`, “consecutive days”), so a count beside it is grammatically sound; the painted unit beside the number is `homeDays`. See `readingCaptionFor` for a count that IS genuinely plural-dependent.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get homeStreakLabel;

  /// Appended to a control's accessible name while the control is inert — the library's book cards and the selah circle.
  ///
  /// **Its subject was the avatar's and the avatar is gone.** `redesign.html:513-538` draws no avatar on `/`; the top bar that carried it was `ds.tsx:499-530`, which the redesign replaced with the greeting block. The wording is `authUnavailableSuffix`'s and the reasoning is its own: a screen reader should be told WHY the control cannot be pressed, not only that it cannot. NAMESPACED `home*` because four features carry this field name and `/quiz`'s differs.
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get homeUnavailableSuffix;

  /// 00:00–04:59. Transcribed: `redesign.html:926` — `vigil:["night vigil","سهر الليل"]`, the fourth arm of the prototype's `hourKey()` (`:983-984`, which returns `vigil` for every hour before five).
  ///
  /// **A fourth key where the three before it were this client's decision.** The redesign's own clock has four buckets, and the last one is not the prototype's English `evening` word but a different word with a different meaning — so the boundaries are now the prototype's and `greeting_period.dart` says so.
  ///
  /// In en, this message translates to:
  /// **'night vigil'**
  String get homeGreetingVigil;

  /// The greeting's second line, `redesign.html:993` — `el('hiName').textContent = lang==='ar' ? 'سلم، مريم' : 'peace, Mariam'`.
  ///
  /// **Half of the prototype's string, deliberately.** `hiName` is one literal with the reader's name inside it, and a name is not translatable — it is `AuthSession.displayName`. So the word and the comma live in this table and the page composes `homePeace` + `homeGreetingSeparator` + the name, which reproduces the prototype's sentence exactly on both arms. The Arabic is the prototype's own two-letter word for peace, not the four-letter greeting of a letter.
  ///
  /// In en, this message translates to:
  /// **'peace'**
  String get homePeace;

  /// The unit painted beside the streak number. Transcribed: `redesign.html:925` — `days:["days","أيام"]`, written into the chip's `.sl` span at `:516`.
  ///
  /// **Separate from `homeStreakLabel`, which is the announcement's prefix** and a plural noun in Arabic; see that key's description for why it stays a prefix rather than becoming a phrase.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get homeDays;

  /// The day's card eyebrow, and the card's accessible name. Transcribed: `redesign.html:927` — `votd:["verse of the day","آية اليوم"]`, written into `#votdCard` at `:521`.
  ///
  /// **It replaces `homeTodayReading`** (“Today's reading”), which described the panel this card replaces and named no string the redesign draws.
  ///
  /// In en, this message translates to:
  /// **'verse of the day'**
  String get homeVerseOfTheDay;

  /// The last-light card's eyebrow, and the card's accessible name. Transcribed: `redesign.html:928` — `lastW:["last light","آخر نور"]`, written into `#lastCard` at `:525`.
  ///
  /// In en, this message translates to:
  /// **'last light'**
  String get homeLastLight;

  /// The reference the same card shows when there is no light: an em dash. Transcribed: `redesign.html:1193` — `el('lastRef').textContent = '—'`.
  ///
  /// **The one key in this table whose two values are identical**, and the reason is that it is punctuation: no translation of a dash exists, and an Arabic-specific dash would be a reader-facing change nobody asked for. It replaced `homeWordmark` in `app_localizations_test.dart`'s `mustBeIdentical` set, so the “every other key must differ” rule still has a live exception rather than an empty list.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get homeNoLightRef;

  /// The last-light card's body when `GET /streak`'s `history` is empty. Transcribed: `redesign.html:929` — `noLight:[...]`, set by `updateLastWidget` at `:1194`.
  ///
  /// The state is real: `history` is the cohort's last thirty scheduled readings (`streak.service.ts:88-96`) and a cohort with none has a reader who has not opened a book. The sentence points at the carousel below it instead of apologising, which is the prototype's own choice and the reason the Arabic names the books rather than the failure.
  ///
  /// In en, this message translates to:
  /// **'no light received yet — open a book below'**
  String get homeNoLight;

  /// The last-light card's hint, shown only when there is a light to resume from. Transcribed: `redesign.html:928` — `resumeHint:[...]`, hidden by `updateLastWidget` when `lastRead` is null (`:1195`).
  ///
  /// **The `›` is part of the string and not a drawn glyph.** The prototype writes it into the text (`:528`), so it travels with the sentence and uppercases under LTR with the rest of the `.mono` run; a separate `Icon` would sit outside the run and stay lowercase beside an uppercase sentence.
  ///
  /// In en, this message translates to:
  /// **'resume where the light left you ›'**
  String get homeResumeHint;

  /// The selah card's title. Transcribed: `redesign.html:970` — `selah:["Selah","سِلاه"]`.
  ///
  /// **The Arabic keeps its tashkeel** (`سِلاه`, a kasra under the seen), because the prototype's own Arabic carries it and a bare `سلاه` is a different spelling of the word. The English is Latin on the Arabic arm's screen too, which is the prototype's arrangement and not an oversight here.
  ///
  /// In en, this message translates to:
  /// **'Selah'**
  String get homeSelah;

  /// The selah card's second line, **without the number**. Transcribed: `redesign.html:966` — `secs:["seconds of silence","ثانية من الصمت"]`.
  ///
  /// The prototype composes it: `el('selahSub').textContent = \`${N(selahDur)} ${tr('secs')}\`` (`:990`). Composing here rather than through a `{seconds}` placeholder is what keeps the Arabic value free of the ASCII placeholder name — `app_localizations_test.dart` fails any non-plural Arabic value holding Latin script, and see `readingCaptionFor`'s description for why the plural keys are the only ones exempt.
  ///
  /// In en, this message translates to:
  /// **'seconds of silence'**
  String get homeSecondsOfSilence;

  /// The carousel's left-hand label. Transcribed: `redesign.html:930` — `lib:["the library","المكتبة"]`, written into `.car-label` at `:535`.
  ///
  /// In en, this message translates to:
  /// **'the library'**
  String get homeTheLibrary;

  /// The carousel's first count's unit. Transcribed from `redesign.html:930`'s `libCount` — `"6 scrolls · 4 open"`.
  ///
  /// **Split in two because the prototype's string has the numbers baked into it and this client's do not.** The catalogue is `LibraryCatalogueRepository.books()` and its length is not a constant, so a single key would have needed an ARB placeholder; a non-plural key with a placeholder puts the ASCII placeholder name in the Arabic value. The page composes `{digits} {homeScrolls} · {digits} {homeOpenBooks}`, which is character-for-character the prototype's literal for the shipped catalogue.
  ///
  /// In en, this message translates to:
  /// **'scrolls'**
  String get homeScrolls;

  /// The carousel's second count's unit, and it agrees with `homeScrolls`. Transcribed from `redesign.html:930`'s `libCount` — see `homeScrolls` for why the pair exists.
  ///
  /// **Feminine plural in Arabic** (`مفتوحة`), because `دروج` is feminine and an Arabic adjective has to agree with its noun; `مفتوح` is the masculine form and reads as a separate word with no subject.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get homeOpenBooks;

  /// The unit in an open book card's caption. Transcribed: `redesign.html:966` — `verses:["verses","آيات"]`, composed at `:1313` as `${N(b.en.length)} ${tr('verses')}`.
  ///
  /// **Carried on open cards only.** `:1317` writes the category alone for a sealed one, because `SEALED` holds no verse array — see `LibraryBook.verseCount` for the null that distinguishes them.
  ///
  /// In en, this message translates to:
  /// **'verses'**
  String get homeVerses;

  /// The badge on a locked book card. Transcribed: `redesign.html:972` — `sealed:["sealed","مختوم"]`, rendered by `buildHome` into `.bcard .lock` at `:1317` and styled by `.bcard.sealed .lock` at `:287-288`.
  ///
  /// In en, this message translates to:
  /// **'sealed'**
  String get homeSealed;

  /// A book card's caption category. Transcribed: `redesign.html:1036` — `CATS = {poetry:["poetry","شعر"], ...}`.
  ///
  /// **A key and not a field on `LibraryBook`**, because the category's *name* is a translation decision while the book's name is catalogue data; the enum (`LibraryCategory`) is closed at six, so a seventh category is a compile error rather than a missing translation discovered on the Arabic arm.
  ///
  /// In en, this message translates to:
  /// **'poetry'**
  String get homeCategoryPoetry;

  /// A book card's caption category. Transcribed: `redesign.html:1036` — `CATS.gospel`. See `homeCategoryPoetry` for why the six categories are ARB keys and not a field.
  ///
  /// In en, this message translates to:
  /// **'gospel'**
  String get homeCategoryGospel;

  /// A book card's caption category. Transcribed: `redesign.html:1036` — `CATS.torah`. See `homeCategoryPoetry` for why the six categories are ARB keys and not a field.
  ///
  /// In en, this message translates to:
  /// **'torah'**
  String get homeCategoryTorah;

  /// A book card's caption category. Transcribed: `redesign.html:1036` — `CATS.prophets`. See `homeCategoryPoetry` for why the six categories are ARB keys and not a field.
  ///
  /// In en, this message translates to:
  /// **'prophets'**
  String get homeCategoryProphets;

  /// A book card's caption category, and only a **sealed** book carries it. Transcribed: `redesign.html:1036` — `CATS.history`, which in `SEALED` (`:1033`) belongs to Acts alone. See `homeCategoryPoetry` for why the six categories are ARB keys and not a field.
  ///
  /// In en, this message translates to:
  /// **'history'**
  String get homeCategoryHistory;

  /// A book card's caption category, and only a **sealed** book carries it. Transcribed: `redesign.html:1036` — `CATS.apocalypse`, which in `SEALED` (`:1034`) belongs to Revelation alone. See `homeCategoryPoetry` for why the six categories are ARB keys and not a field.
  ///
  /// In en, this message translates to:
  /// **'apocalypse'**
  String get homeCategoryApocalypse;

  /// App bar / section title for `/leaderboard`. The cohort's ranking over a chosen window.
  ///
  /// In en, this message translates to:
  /// **'Cohort standings'**
  String get leaderboardTitle;

  /// Segmented-control option for `LeaderboardWindow.weekly`.
  ///
  /// NOT the enum's wire code. The wire sends `weekly`, `monthly`, `all_time`; those are identifiers in `leaderboard_board.dart`, not words to put in front of a reader. `all_time` in particular would need a space and a lowercase 't' to read as English.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get leaderboardWindowWeekly;

  /// Segmented-control option for `LeaderboardWindow.monthly`. See `leaderboardWindowWeekly` for why this is not the wire code.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get leaderboardWindowMonthly;

  /// Segmented-control option for `LeaderboardWindow.allTime`. See `leaderboardWindowWeekly` for why this is not the wire code `all_time`.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get leaderboardWindowAllTime;

  /// Shown when the cohort has nobody ranked.
  ///
  /// A REAL STATE, NOT AN ERROR. Measured against the live endpoint: `{"group_id":3,"window":"weekly","total_ranked":0,"my_standing":null,"leaderboard":[]}`. Scores only enter Redis via `leaderboardService.recordScore`, called from `submissions.service.ts:105` on a *successful* submission, and submission cannot succeed against the memory fallback because the schemas require UUIDs the fallback does not mint. So the empty board is currently the ONLY reachable state in development.
  ///
  /// This is why the copy explains what will fill it instead of apologising for a failure.
  ///
  /// In en, this message translates to:
  /// **'No scores yet'**
  String get leaderboardEmptyTitle;

  /// Body under `leaderboardEmptyTitle`. Says what will populate the list, because the reader cannot tell whether the cohort is new or the app is broken.
  ///
  /// In en, this message translates to:
  /// **'Once the cohort starts answering, the standings appear here.'**
  String get leaderboardEmptyBody;

  /// Label on the reader's own row. NOT the reader's name and NOT their initials — the top bar already shows both, and repeating the initials next to the flame would be a second copy of the same identity.
  ///
  /// A reader must find their own row in a list of other children's monograms without their name appearing anywhere, which is the whole point of `LeaderboardRow` having no `fullName`.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get leaderboardYourRank;

  /// Shown instead of a position when `LeaderboardStanding.rank` is `null`.
  ///
  /// NEVER AN ARITHMETIC RESULT. `rank: null` with `score: 0` is the server's measured answer for a child who has not scored. Rendering it as `0` or `1` would put a fabricated position on someone who has none — the defect `LeaderboardStanding`'s doc is named for.
  ///
  /// In en, this message translates to:
  /// **'Not ranked yet'**
  String get leaderboardUnranked;

  /// Unit caption under a score. Lowercase and plural-invariant because the unit is fixed and the number is not; 'pts' was rejected as too terse to read as a word in Arabic, where a two-letter abbreviation carries no meaning.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get leaderboardScoreLabel;

  /// Link from Home's compact card to `/leaderboard`.
  ///
  /// Phrased as an action rather than a count, because the card cannot honestly say how many there are — `cohortSize` is `null` whenever the request's `limit` bound. 'See all' stays true whether there are four children or four hundred.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get leaderboardOpenFull;

  /// The screen-reader sentence for one ranked row.
  ///
  /// A REAL ICU PLURAL, and the reason this key exists rather than four separate strings. A row is four numbers and a monogram; a screen reader announcing "3, PG, 80, points" gives a reader four fragments and no sentence, so this composes one. The plural is over `count` with the digits interpolated separately, which is the same shape `readingCaptionFor` uses.
  ///
  /// `isReader` is a `select`, not a second plural: "that is you" is a clause, not a quantity, and folding it into the plural would multiply the arms for no gain.
  ///
  /// NEVER A NAME. `initials` is the monogram and nothing else can reach this string, which is the accessibility half of `LeaderboardRow` having no `fullName` — a voice-over user must not be able to hear a name the screen cannot show.
  ///
  /// `rank` and `digits` are **String** while `count` is **int**, and that split is load-bearing rather than fussy: `count` is what the plural selects on, and `digits` is what the reader sees. Passing the numeral twice means the shape does not have to change when a locale's digits are not ASCII — the Arabic arm renders U+0660…U+0669, and `intl`'s formatting would otherwise be a second source of truth about numerals. `readingCaptionFor` does the same thing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, zero{no points} one{1 point} other{{digits} points}}, {initials}, rank {rank}{isReader, select, true{, that is you} other{}}'**
  String leaderboardRowSemantics(
    int count,
    String digits,
    String initials,
    String rank,
    String isReader,
  );

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

  /// The stepper track's slider label, announced as a slider. **Written, not transcribed**: SettingsScreen.tsx:66 is the prototype's `<input type="range" min={1} max={5}>` and it carries **no accessible name at all**, so this is §14's first row applied to a control the row does not name.
  ///
  /// A distinct string from `settingsFontSize` because the two name the control from two positions — a row title and a slider — and `FontSizeStepperLabels`'s doc argues for exactly one value for its own three strings for the opposite reason.
  ///
  /// In en, this message translates to:
  /// **'Font scale'**
  String get settingsFontScale;

  /// The stepper's decrement button's tooltip and accessible name. **Written, not transcribed**: SettingsScreen.tsx:66 supplies its own stepper affordances on a native `<input type="range">`, and a native input brings its own buttons with **no labels of its own**, so §14 required two names here that the prototype never wrote.
  ///
  /// Deliberately the same sentence as `readingDecreaseFontSize`: two screens draw the same control and a second wording would be a translation decision nobody made.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get settingsDecreaseFontSize;

  /// The stepper's increment button's tooltip and accessible name. **Written, not transcribed**, for `settingsDecreaseFontSize`'s reason: SettingsScreen.tsx:66's native range input carries its own `+` with no label.
  ///
  /// Deliberately the same sentence as `readingIncreaseFontSize`, for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get settingsIncreaseFontSize;

  /// The switch's row title. **Written, not transcribed — and there is no prototype row to transcribe from**: `SettingsScreen.tsx` has no motion row at all. This control exists because AGENT_CONTEXT §14 asks for reduced motion and `app.dart` recorded that a later phase would replace the platform-only default with the persisted `UserSettings` value. This is that phase.
  ///
  /// Placed under APPEARANCE rather than READING because what it changes is how the app moves, not what it says.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// The switch's accessible name while it is on. **Written, not transcribed**: `EvaToggle` shipped hard-coding the English words `On` and `Off` into its `Semantics` node for six phases, and no gate could see it because a semantics label is not painted — the Arabic glyph gate walks the painted tree, and a golden captures no semantics. Phase 9 made the switch's labels required and this is the shipped spelling.
  ///
  /// The Arabic is a participle rather than a transliterated `On`, so the Arabic arm holds no Latin script and `app_localizations_test.dart`'s exception list does not grow.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsMotionOn;

  /// The switch's accessible name while it is off. **Written, not transcribed**, as `settingsMotionOn` says — and `EvaToggle` is the widget that used to hard-code the English.
  ///
  /// `Off` and `On` are the words a screen reader has to distinguish to answer "is animation on?", so neither value may be empty and neither may be the other's translation of itself.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsMotionOff;

  /// The notice shown when `SettingsStatus` is `failed`. **Written, not transcribed**, because the prototype has nothing to transcribe from: `eva/src` has no data layer and therefore no error state anywhere, and `SettingsScreen.tsx` cannot fail because every value on it is a `useState` in the same file. `homeRetry` makes the same argument for the same reason.
  ///
  /// THE SENTENCE IS **NOT** `Failure.message`, and that is the point of this key existing. Every other `ErrorView` in this app shows the mapper's wording — `error_view.dart` states that `ApiErrorMapper` is the only source of a displayable failure message, and that claim is true of all three of them. `/settings` is the fourth call site and the first **non-network** one: `SettingsRepositoryImpl._unreachable` builds `'The preferences could not be reached: $error'`, which interpolates the raw Dart exception, so rendering it would put a `MissingPluginException` on a reader's screen. A developer string and a reader's sentence are different things and only one of them is translated here.
  ///
  /// WRITTEN AS ONE SENTENCE COVERING BOTH FAILURE ARMS, because the cubit reports a failed READ and a failed WRITE through one status and the reader cannot tell from the screen which happened. 'Your preferences could not be saved' is true of both — the read failed, so what is on screen is not what is stored, which is the same fact from the other side.
  ///
  /// In en, this message translates to:
  /// **'Your preferences could not be saved on this device.'**
  String get settingsPreferencesUnavailable;

  /// The notice's action, which re-runs `SettingsCubit.load()`. **Written, not transcribed** — `SettingsScreen.tsx` has no error state and therefore no retry control, exactly as `homeRetry`, `quizRetry` and `readingRetry` do not.
  ///
  /// Deliberately the same sentence as those three, which is a pattern rather than a coincidence: `settingsBack` and `readingBack` share their wording for the same reason, and four independently-written keys saying 'Try again' in two languages is four translation decisions nobody made.
  ///
  /// NAMESPACED `settings*` because five features now carry this field name.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsRetry;

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

  /// The sheet's own heading. **Written, not transcribed** — SettingsScreen.tsx:77-90 draws the language pills inline and defines no sheet, no heading and no dismiss affordance at all. A bottom sheet needs a name for §14's first row, and inventing a row for it inside the screen is this client's own contribution.
  ///
  /// The sentence is an instruction rather than a noun phrase because the sheet's two rows are both languages and neither can be named "the language".
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get settingsLanguageSheetTitle;

  /// The English row in the language sheet. Transcribed in **kind** from SettingsScreen.tsx:88, which writes the pill's own label as `l === 'EN' ? 'English' : 'العربية'` — so the prototype already draws one end of this pair in Arabic, which is where the Arabic form of `العربية` comes from. **Written** for the other end: the prototype has no `الإنجليزية` string anywhere, so that half is this client's own.
  ///
  /// The Arabic value here is `الإنجليزية` and not `English`, deliberately: an Arabic reader who cannot read Latin would otherwise be unable to choose English, which is the one choice whose absence locks them out of the other arm. That decision also keeps `app_localizations_test.dart`'s `latinIsCorrect` exception list from growing, which an earlier draft of `settings_l10n.dart` claimed was not the case.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// The Arabic row in the language sheet. **Transcribed**: SettingsScreen.tsx:88 writes the pill's label as `l === 'EN' ? 'English' : 'العربية'`, so `العربية` is the prototype's own string for this row and it is the evidence for the rule the whole file follows — a language names itself in its own script.
  ///
  /// The prototype draws the two-letter codes `EN` and `AR` beside the names; this client draws the **names only**, because `EN` and `AR` are Latin script on the Arabic arm and the two codes are also exactly what `ReadingLanguage.code` already holds for the API path — so they are rendered from the domain enum rather than translated.
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

  /// `ds.tsx:559-564`'s 56px circle carries only the text `E`, so it has no accessible name of its own and a screen reader reaches an unnamed button. This is the trigger's shut name, and it says what activating does rather than what the control is.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get sealFabOpen;

  /// The same trigger while the dial is open. A toggling button needs two names, or the announcement describes the current state and not the action — which is the defect `SegmentedControl` shipped with.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get sealFabClose;

  /// A `SealFab` destination. `ds.tsx:538` offers `Settings`; rejected was dropping it, since the avatar on `/` is a 32px target in a top bar and this is a labelled destination one tap away.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sealFabSettings;

  /// A `SealFab` destination, and the reason this control exists. It occupies the prototype's `Profile` slot (`ds.tsx:537`): Profile is a cut screen with no endpoint, and `/leaderboard` is the only prototype destination with no other entry point on `/`.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get sealFabLeaderboard;
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
