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

  /// The sign-in CTA. Transcribed: redesign.html:508 — `data-i18n="enter"`, one of the THREE strings on the redesigned login the prototype itself translates (`redesign.html:965` — `enter:["enter the word","ادخل الكلمة"]`). The Arabic is the prototype's own, not a new translation.
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
  /// NAMESPACED `auth*` because **FIVE** features carry a field of this name and they are NOT all the same string: `/quiz`'s says there is no answer to show, and the other four say the same thing. See `quizUnavailableSuffix`.
  ///
  /// APPENDED BY THE CALL SITE, NEVER BAKED IN — the two inert ghost pills on `/login` share labels, and a suffix inside the label would render "unavailable in this build - unavailable in this build".
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get authUnavailableSuffix;

  /// Written, not transcribed: `eva/redesign.html` draws no role picker — the redesign's login (`:503-511`) has two fields, a CTA and two ghost pills, and nothing for choosing who you are. The control needs a name of its own because there is no auth endpoint (AGENT_CONTEXT §2, decision 3), so the role is a local choice, and a control with options but no name is §14's unnamed-control failure.
  ///
  /// **It is deliberately NOT the selected option's name.** `SegmentedControl`'s track is an activatable node of its own — the one thing that binds the control's focus node into the focus tree — so naming the track after the selected option would put two activatable nodes on screen with the identical label, which is recorded decision 129's defect and the reason that decision added `SegmentedControl.semanticLabel` at all.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get authRoleLabel;

  /// Written, not transcribed: `eva/redesign.html` has no role picker, so this string is the login screen's own copy. The label for `UserRole.kid` — the seed role, and the one `identity.middleware.ts:24` falls back to when the header is absent. Short on purpose: the three options share one row at the 320px surface the viewport matrix gate measures, and a longer word would be ellipsised.
  ///
  /// In en, this message translates to:
  /// **'Kid'**
  String get authRoleKid;

  /// Written, not transcribed: `eva/redesign.html` has no role picker. The short word for `UserRole.viewerServant` — a church servant who reads the daily roster report and changes nothing. "Servant" rather than "viewer servant" for two measured reasons: the three options share one row at 320px, where a two-word label does not fit; and in a church the two servant roles are told apart by what they do, not by the word "servant".
  ///
  /// In en, this message translates to:
  /// **'Servant'**
  String get authRoleServant;

  /// Written, not transcribed: `eva/redesign.html` has no role picker. The short word for `UserRole.adminServant` — a servant who may also schedule a reading and author its questions. Short on purpose, for the same reason as `authRoleServant`: the three options share one row at the 320px surface the viewport matrix gate measures.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get authRoleAdmin;

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
  /// **Its subject was the avatar's and the avatar is gone.** `redesign.html:513-538` draws no avatar on `/`; the top bar that carried it was the superseded prototype's own, which the redesign replaced with the greeting block. The wording is `authUnavailableSuffix`'s and the reasoning is its own: a screen reader should be told WHY the control cannot be pressed, not only that it cannot. NAMESPACED `home*` because **five** features carry this field name and `/quiz`'s differs.
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

  /// The selah card's second line, **without the number**. Transcribed: `redesign.html:970` — `secs:["seconds of silence","ثانية من الصمت"]`.
  ///
  /// The prototype composes it: `el('selahSub').textContent = \`${N(selahDur)} ${tr('secs')}\`` (`:990`). Composing here rather than through a `{seconds}` placeholder is what keeps the Arabic value free of the ASCII placeholder name — `app_localizations_test.dart` fails any non-plural Arabic value holding Latin script, and see `readingCaptionFor`'s description for why the plural keys are the only ones exempt.
  ///
  /// In en, this message translates to:
  /// **'seconds of silence'**
  String get homeSecondsOfSilence;

  /// Written, not transcribed: `redesign.html:533` gives the selah's button a `title="selah"`, which names the thing rather than the action, and this client names the action because AGENT_CONTEXT §14 asks for a control whose accessible name says what it does. The button starts a silence of the reader's own length — `UserSettings.selahLengthSec`, the Workshop's own 15…120 second range at `redesign.html:684` — and the prototype's own tooltip never said how long. The alternative rejected was a bare "Selah", which is the prototype's spelling and answers "what is this?" rather than "what does pressing it do?".
  ///
  /// In en, this message translates to:
  /// **'Begin the selah'**
  String get homeSelahBegin;

  /// Written, not transcribed: the selah's button changes what it does while the silence runs — `redesign.html:1334` stops the countdown on a second press — and a control whose action changes needs a name that changes with it, or a screen-reader user is told to "begin" a silence that is already running. The prototype has no string for this: its `title="selah"` at `redesign.html:533` never changes. The alternative rejected was naming the button "Selah" in both states, which leaves the second press with the same instruction as the first.
  ///
  /// In en, this message translates to:
  /// **'End the selah'**
  String get homeSelahEnd;

  /// Transcribed: `redesign.html:970` — `amen:["selah · amen","سِلاه · آمين"]`, the prototype's own I18N row for the toast the finished silence raises at `redesign.html:1330` (`if(done){ toast(tr('amen')); … }`). The middle dot is U+00B7, the prototype's own separator, and the Arabic keeps the tashkeel the prototype's value carries. The English is Latin on the Arabic arm's screen too, which is the prototype's arrangement and not an oversight here.
  ///
  /// In en, this message translates to:
  /// **'selah · amen'**
  String get homeSelahAmen;

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

  /// App bar / section title for `/communion`. The cohort's board over a chosen window.
  ///
  /// `eva/redesign.html:615` — `<span class="ttl" data-i18n="boardT">The Communion</span>` — and `:939`'s `commG` row, the redesign's own word for it.
  ///
  /// In en, this message translates to:
  /// **'The Communion'**
  String get leaderboardTitle;

  /// Segmented-control option for `LeaderboardWindow.weekly`.
  ///
  /// NOT the enum's wire code. The wire sends `weekly`, `monthly`, `all_time`; those are identifiers in `leaderboard_board.dart`, not words to put in front of a reader. `all_time` in particular would need a space and a lowercase 't' to read as English.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get leaderboardWindowWeekly;

  /// Segmented-control option for `LeaderboardWindow.monthly`. See `leaderboardWindowWeekly` for why this is not the wire code.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get leaderboardWindowMonthly;

  /// Segmented-control option for `LeaderboardWindow.allTime`. See `leaderboardWindowWeekly` for why this is not the wire code `all_time`.
  ///
  /// In en, this message translates to:
  /// **'all'**
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

  /// Shown instead of a position when the client cannot place the reader.
  ///
  /// **TWO SITUATIONS, and they are not the same.** `LeaderboardStanding.rank` is `null` — the server has no ranking for this reader at all. And `rank` is not `null` but the reader's **row is off the page** (the endpoint's `limit` is 50), so under the `streaks` metric — which the server does not rank and the client cannot rank a reader it has no row for — the card says the reader is unranked **on this board**.
  ///
  /// NEVER AN ARITHMETIC RESULT. `rank: null` with `score: 0` is the server's measured answer for a child who has not scored. Rendering it as `0` or `1` would put a fabricated position on someone who has none — the defect `LeaderboardStanding`'s doc is named for.
  ///
  /// In en, this message translates to:
  /// **'Not ranked yet'**
  String get leaderboardUnranked;

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
  /// **'{count, plural, zero{no points} one{1 point} other{{digits} points}}, {streakCount, plural, zero{no streaks} one{1 streak} other{{streakDigits} streaks}}, {initials}, rank {rank}{isReader, select, true{, that is you} other{}}'**
  String leaderboardRowSemantics(
    int count,
    String digits,
    int streakCount,
    String streakDigits,
    String initials,
    String rank,
    String isReader,
  );

  /// Segmented-control option and row sub-line unit for `LeaderboardMetric.light` — the response's own `score` for the selected window.
  ///
  /// Transcribed from `eva/redesign.html:941`'s `light` pair and `:1117`'s sub-line, which prints the OTHER metric beside each row's value.
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get leaderboardMetricLight;

  /// Segmented-control option and row sub-line unit for `LeaderboardMetric.streaks` — the row's `current_streak`.
  ///
  /// `eva/redesign.html:941` `streakM`; `:1117` prints this on a light-ranked row and prints `light` on a streak-ranked one.
  ///
  /// In en, this message translates to:
  /// **'streaks'**
  String get leaderboardMetricStreaks;

  /// A veiled witness's display name: their display position, never their name. `eva/redesign.html:942` `witness`, used by `:1070`'s `dispName` and `:1072`'s monogram.
  ///
  /// `{position}` is the row's DISPLAY position under the selected metric, and its digits arrive through `digits()` so the Arabic arm reads `شاهد ٢`.
  ///
  /// In en, this message translates to:
  /// **'witness {position}'**
  String leaderboardWitness(String position);

  /// The suffix appended to the reader's own row name, rendering as `Mariam Hanna · you`. `eva/redesign.html:942` `you`, appended at `:1115`.
  ///
  /// Also the trailing half of `leaderboardTitle`'s alternative reading? No — see `leaderboardYourRank`'s deletion: this replaces it.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get leaderboardYou;

  /// The you-card's gap sentence: the witness one display position above the reader, and how much more of the metric's value they hold. `eva/redesign.html:943` `gapLine`, composed at `:1105-1106`.
  ///
  /// `{name}` is already veil-resolved by the caller; `{n}` arrives through `digits()`.
  ///
  /// In en, this message translates to:
  /// **'{name} holds {n} more light'**
  String leaderboardGapLine(String name, String n);

  /// The you-card's advice half, appended after ` · ` and rendered on the LIGHT metric only. `eva/redesign.html:944`; the ÷15 constant is the rail's light economy (`:755`, "15 per verse read + 10 per correct answer").
  ///
  /// Under `streaks` it is not rendered at all: a streak gap is not a number of verses.
  ///
  /// **The ARABIC arm says نحو and not the prototype's `≈`.** The prototype writes `≈` in both arms (`:944`), and U+2248 is in **no** bundled family that can draw Arabic — Amiri, the Arabic UI family, does not carry it — so the Arabic arm substitutes the word for "about". `test/support/font_coverage_test.dart` pins the measurement: U+2248 is absent from Amiri and present in the other four.
  ///
  /// In en, this message translates to:
  /// **'pass with ≈{n} verses'**
  String leaderboardPassHint(String n);

  /// The reset line for `all_time`: the sky keeps every score, so there is no boundary to count down to. `eva/redesign.html:945` `noReset`, rendered at `:1081`.
  ///
  /// Printed verbatim, including the `·` (U+00B7), which `test/support/font_coverage_test.dart` pins as present in all five bundled families.
  ///
  /// In en, this message translates to:
  /// **'no reset · the sky remembers'**
  String get leaderboardNoReset;

  /// The approximate reset line for a bounded window. `eva/redesign.html:946` `resets`/`dU`/`hU`, composed at `:1082` against a locally derived boundary rather than a server instant.
  ///
  /// `{days}`, `{hours}` and the two units are Strings so `digits()` can convert the numerals while the units stay the locale's own words; the `≈` states that the boundary is local (ADR-0022 `:66-81`, `redis/leaderboard.service.ts:20-36`).
  ///
  /// In en, this message translates to:
  /// **'resets in ≈{days}{dayUnit} {hours}{hourUnit}'**
  String leaderboardResetsIn(
    String days,
    String hours,
    String dayUnit,
    String hourUnit,
  );

  /// The confirmation toast after a witness is cheered. `eva/redesign.html:947` `cheerSent`, shown for 1800 ms by `:1393`.
  ///
  /// The prototype writes a leading `✦`; it is PAINTED beside this string rather than typed into it, because U+2726 is in no bundled family.
  ///
  /// In en, this message translates to:
  /// **'cheer sent to {name}'**
  String leaderboardCheerSent(String name);

  /// The board header's eye button, and the Settings row Task 5.7 will build: replace every other witness's name with `witness {position}` and their monogram with the hollow star. `eva/redesign.html:948` `veilT`; applied at `:1069-1072`.
  ///
  /// A rendering choice over rows that already arrived — there is no veil endpoint (ADR-0022 `:243-245`).
  ///
  /// In en, this message translates to:
  /// **'Veil witnesses'**
  String get leaderboardVeil;

  /// The failure arm's retry label. The board has its OWN key, and not `/reading`'s: `homeRetry`, `quizRetry`, `readingRetry` and `settingsRetry` are four separate keys with identical values, and the repository namespaces `retry` per screen on purpose. A fifth screen borrowing the fourth's key is the coupling this key removes. `eva/redesign.html:627`'s screen has no retry of its own; the `ErrorView` it borrows is the design system's.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get leaderboardRetry;

  /// The ACCESSIBLE NAME of the scope segmented control — the week/month/all picker. It is a control's own name, and it must not be one of its own option labels: `SegmentedControl` puts this string on the track's node, and two activatable nodes with the same name is the failure `segmented_control.dart`'s own doc names. `eva/redesign.html:940`'s `week`/`month`/`all` row supplies the OPTIONS; this supplies the name of the thing that holds them.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get leaderboardScopeLabel;

  /// The ACCESSIBLE NAME of the metric segmented control — the light/streaks picker. Same rule as `leaderboardScopeLabel`: a control's name, never one of its own options. `eva/redesign.html:941`'s `light`/`streakM` row supplies the options; this supplies the name of the thing that holds them.
  ///
  /// In en, this message translates to:
  /// **'Ranking metric'**
  String get leaderboardMetricLabel;

  /// The day unit in the reset line — `d` in English, `ي` in Arabic. The prototype's own `dU` row (`eva/redesign.html:946`), and it is a KEY rather than a fork in the widget so that a third locale has somewhere to put its own letter instead of silently getting an English one. The Arabic value is `ي`, the prototype's own.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get leaderboardDayUnit;

  /// The hour unit in the reset line — `h` in English, `س` in Arabic. The prototype's own `hU` row (`eva/redesign.html:946`), and the same reasoning as `leaderboardDayUnit`.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get leaderboardHourUnit;

  /// `ErrorView.retryLabel`. There is NO prototype error state at all — the superseded prototype has none, because it has no data layer that can fail — so this is WRITTEN, and it says WHAT IT DOES ("Try again") rather than "Retry".
  ///
  /// NAMESPACED `home*`: three features carry this field name (`homeRetry`, `quizRetry`, `readingRetry`).
  ///
  /// `ErrorView` is the precedent for all three: a hard-coded English string inside `core/` is the half-translated UI this app exists not to ship, so the wording lives with the caller and the widget takes it.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get homeRetry;

  /// The back control's accessible name.
  ///
  /// REWORDED WITH THE CHROME IT NAMES. The old value ("Close") named a cross icon; the redesign replaces that control with the `.chev` chevron (`redesign.html:564`), whose click returns to the reader (`:1412` — `qBack` is `pop('reader')` then `enterReader()`, a back step and not a dismissal). The client's control is still `context.router.maybePop()`, which is the same move.
  ///
  /// Still WRITTEN, NOT TRANSCRIBED: `:564` is a `<button>` around a bare `‹` with NO LABEL AT ALL — §14's first row, verbatim. The same obligation that forced `readingBack` forces this.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get quizExit;

  /// `ProgressBeads`' accessible-name prefix for the re-homed dots row.
  ///
  /// REWORDED WITH ITS JOB. The old value ("Question") was the noun of the composed `Question 2 of 5` line, which the redesign's quiz screen does not have — its only progress surface is the `.dots` row (`redesign.html:568`, CSS `:328-332`). The row is a bare unlabelled `<div>` in the prototype, so this name is WRITTEN, NOT TRANSCRIBED — §14's colour-and-shape row needs the progress announced, and `ProgressBeads`' `Semantics` is where it lands.
  ///
  /// Semantics-only, never painted: `ProgressBeads` puts it in `Semantics(label:, excludeSemantics: true)`, so the Arabic-typography gate declines to declare it.
  ///
  /// In en, this message translates to:
  /// **'Quiz progress'**
  String get quizProgress;

  /// The crumb's first half — `Refraction · <reference>`.
  ///
  /// Transcribed from the prototype's I18N row (`redesign.html:967`, `refraction:["Refraction","انعطاف"]`), rendered at `:565` as the appbar's centred `#qCrumb` and filled from the reader's own passage (`:1348` — `` `${tr('refraction')} · ${bookTitle(b)}` ``). The client's second half is the payload's `reference`, carried on `QuizSession` and composed in `quiz_l10n.dart` — an ARB placeholder would fail the Latin/numeral gates, the `home_l10n.dart` precedent.
  ///
  /// In en, this message translates to:
  /// **'Refraction'**
  String get quizRefraction;

  /// The CTA while a choice is made and not yet graded.
  ///
  /// TRANSCRIBED FROM THE SUPERSEDED PROTOTYPE, AND THE VALUE IS STILL THE ONE IT WROTE. Its switch was `{checked ? 'Next question' : 'Check answer'}`; this is its unchecked arm, unchanged. The redesign has no such label at all: its grader is one-tap (`redesign.html:1423` — `pick` grades the instant a card is chosen), so `.qnext` only ever appears graded (`:1421` removes it; `:1430` shows it). This client's grade is a `POST` (`POST /readings/:id/submit`, §5 trap 10 — no successful submit may be fired on a mis-tap), so choosing and grading stay two presses and the second press needs a name the prototype never wrote.
  ///
  /// The value is kept because the step is the same: the prototype's label named the same step the client names, so the label survives even though the line that named it does not.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get quizCheckAnswer;

  /// The CTA after the answer is graded, with a question still to come.
  ///
  /// REWORDING, ON A MEASUREMENT. The old value ("Next question") was the superseded prototype's switch label. The redesign's own I18N row is `next:["next ▸","التالي"]` (`redesign.html:967`), and `.qnext` renders it mono, uppercase, tracked (`:364`) — so the rendered form is `NEXT ▸` exactly as the prototype draws it. The `▸` (U+25B8) is safe as TEXT on the English arm only because `.qnext` is mono (`:364`) and JetBrainsMono carries the codepoint — measured against all nineteen bundled TTFs, same instrument as `font_coverage.dart`. The Arabic value carries no arrow, which is the prototype's own pair.
  ///
  /// The terminal arm took the redesign's other label — see `quizSeeResults`.
  ///
  /// In en, this message translates to:
  /// **'next ▸'**
  String get quizNextQuestion;

  /// The CTA on the last graded question — the terminal arm.
  ///
  /// NOW TRANSCRIBED, AND THE VALUE REWORDED TO THE REDESIGN'S OWN. The old description called this key written because the old prototype had no terminal state. The redesign does: its I18N row is `seeRes:["see results ✦","النتائج"]` (`redesign.html:967`), applied at `:1431` (`label = last question ? tr('seeRes') : tr('next')`), and one click opens the results (`:1432`).
  ///
  /// THE ✦ IS NEVER TEXT. U+2726 is in NO bundled family — measured against all nineteen TTFs (`four_pointed_star.dart` carries the measurement) — so the star is the painted `FourPointedStar` composed by the CTA on the English arm, and the Arabic arm carries none, which is the prototype's own pair. The value here is therefore the words only.
  ///
  /// In en, this message translates to:
  /// **'see results'**
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

  /// Appended to an option's accessible name when the wire says it is answered.
  ///
  /// §14's disabled row: a reader has to be told WHY a control cannot be pressed, not only that it cannot. `LoginPage`'s four inert social buttons and `AppTopBar`'s avatar are the precedent, and they are the reason /quiz can ship a dead CTA honestly at all.
  ///
  /// In en, this message translates to:
  /// **'already answered, so it cannot be submitted again'**
  String get quizAlreadyAnsweredSuffix;

  /// Appended to the CTA's accessible name when there is nothing to submit.
  ///
  /// NAMESPACED `quiz*` BECAUSE THIS IS NOT THE SAME STRING AS THE OTHER FOUR. `authUnavailableSuffix`, `homeUnavailableSuffix`, `readingUnavailableSuffix` and `journeyUnavailableSuffix` all say "unavailable in this build"; this one says why *this* control is unavailable, which is §14's actual requirement and a different fact.
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
  /// WRITTEN, NOT TRANSCRIBED: the superseded prototype's two reading screens each drew a `<button>` wrapping an inline `<svg>` chevron with nothing at all — §14's first row, verbatim. The redesign's reader app bar draws the same glyph and no name either (`redesign.html:542`).
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
  /// AND THE PROTOTYPE HAS NO WORDING TO TRANSCRIBE: the superseded prototype's font-size row is a bare range input with `-` and `+` and no labels at all, and the redesign's Type-size row is a bare native range input too (`redesign.html:693`) with no labels of its own.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get readingDecreaseFontSize;

  /// The `FontSizeStepper`'s increment button. Written, for `readingDecreaseFontSize`'s reason.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get readingIncreaseFontSize;

  /// The bookmark control's accessible name, BEFORE any suffix. The bookmark has no endpoint and no port — the redesign draws one (`redesign.html:544`) and the superseded prototype drew one with no handler at all — so it ships INERT and says so via `readingUnavailableSuffix`.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get readingBookmark;

  /// Appended to a control's name while that control is inert.
  ///
  /// The same wording, and the same reasoning, as `authUnavailableSuffix`, `homeUnavailableSuffix` and `journeyUnavailableSuffix`: a reader should be told WHY a control cannot be pressed, not only that it cannot. NAMESPACED `reading*`; `/quiz`'s is a different string, and `/journey`'s is the same as this one.
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

  /// `ErrorView.retryLabel`. The prototype has no error state at all — the superseded prototype has no data layer that can fail — so this is written. NAMESPACED `reading*`; see `homeRetry` for the three-way collision.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get readingRetry;

  /// The primary button. The superseded React prototype's primary read `Reflect again`, and the value is that label verbatim. The redesign has no such label: its two result CTAs are `read again` and `retry quiz` — one I18N row, `redesign.html:963` — drawn as the `.rcta` at `:724` and the `.rghost` at `:725`. The client keeps the prototype's words, and `result_sheet.dart` records the action mapping.
  ///
  /// In en, this message translates to:
  /// **'Reflect again'**
  String get resultReflectAgain;

  /// The secondary button.
  ///
  /// WRITTEN, NOT TRANSCRIBED, AND TRANSCRIBING WOULD HAVE BEEN A LIE: the superseded React prototype's label is `Back to library` and there IS no library — AGENT_CONTEXT §2 decision 1 cut it, and the destination is `/`. The redesign's own `again` row reads `read again` (`redesign.html:963`), which is also not a destination for this client. The label says where the button actually goes.
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

  /// The streak pill's leading noun. The superseded prototype's pill read `Day 12`, and the noun is that one verbatim. The redesign's own streak chip (`.streak`, `redesign.html:238`) numbers the reader and calls its unit `days` (`redesign.html:516`) — so it has no `Day` of its own, and the client keeps the prototype's noun.
  ///
  /// DELIBERATELY **NOT** AN ICU PLURAL, and this is the judgement call in this file. The pill renders a LABEL FORM (`Day 12`, `اليوم ١٢`), not a count phrase: English `Day 12` is correct for every count including one, and Arabic `اليوم` with an Arabic-Indic numeral is the conventional label too. Making it a plural would render `Days 12` in English — ALTERING A TRANSCRIBED PROTOTYPE STRING to fix nothing — and would change the pill's visual shape on every screen that shows a streak.
  ///
  /// The count that IS genuinely plural-dependent on this screen is `resultTotalCaption`, below. `readingCaptionFor` is the other. Every other count in the app was checked and recorded in AGENT_CONTEXT decision 104.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get resultDay;

  /// Appended to the streak label when the reader is at their best. The superseded prototype's pill read `Day 12 — your longest yet`, and this is the ` — your longest yet` half of it, verbatim. The redesign's own streak chip calls its unit `days` (`redesign.html:516`) and has no counterpart for this half at all — so the client keeps the prototype's words.
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
  /// WRITTEN, NOT TRANSCRIBED. The superseded prototype's result screen shipped `So close. One more read and you've got it.`, which is keyed on its own hard-coded `4/5` - and this client has neither number: `SubmitResult` carries `points_earned` and `current_total_points` and **no question count** (AGENT_CONTEXT 2's route table gives `/result` no repository), so a sentence about being 'one read away' would be a claim about a measurement that does not exist. This is decision 45's rejected 'invent a measurement', and it is the largest single divergence on the screen.
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

  /// The screen's title, in the app bar's centred slot. Transcribed: `eva/redesign.html:641` writes `The Workshop`, and `:949` carries the same pair.
  ///
  /// **REPLACED THE PHASE-9 VALUE.** The old key said `Settings` and was transcribed from the superseded React prototype's settings screen, which this task supersedes. The redesign names the screen, and the name is the title.
  ///
  /// In en, this message translates to:
  /// **'The Workshop'**
  String get settingsTitle;

  /// The app bar's chevron's tooltip. Transcribed: `eva/redesign.html:640` draws the chevron, and the React prototype's tooltip is kept because the redesign draws the glyph and no name.
  ///
  /// **The design system owns the name's family, so the string does not.** `IconActionButton.tooltipFamily` is required (decision 66), and the tooltip is Arabic on the Arabic arm.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBack;

  /// The language segment's accessible name. **Written, not transcribed** — `eva/redesign.html:646-648` draws the segment with no name of its own, and the group header above it is a *bilingual* label that would read as `language · language` aloud.
  ///
  /// §14's first row is a control with no name in the reader's own language, and the name has to name the **control** rather than the group it sits in. The prototype's own group header is `settingsWsLang`.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// The language group's header. Transcribed: `eva/redesign.html:645` writes `language · اللغة` and `:949` carries the pair.
  ///
  /// **THE PROTOTYPE'S LABEL IS BILINGUAL AND THIS ONE IS NOT, and that is a divergence with a gate behind it.** `:949`'s two arms are `language · اللغة` and `اللغة · language` — each names the thing in the reader's script and then in the *other* one, which is a language-picker flourish and cannot be one ARB value: the English arm would hold Arabic script and the Arabic arm would hold Latin script.
  ///
  /// `app_localizations_test.dart` holds both halves of the bilingual contract, and the English half is **absolute** — no English-arm value may hold Arabic script, with no exemption list. So each arm keeps the prototype's first half: `language` on the English arm and `اللغة` on the Arabic one, which is the same word in each arm's own script.
  ///
  /// **THE PROTOTYPE'S BRAND-MARK LITERALS ARE NOT HERE**, and the distinction is the precedent. Task 5.1 gave `/login` five widget literals — `EVANGELION`, `αω · nocturne v1.2` — precisely so the ARB would not have to hold a value in two scripts at once. A **brand mark** may be a literal; a **group header** is prose, and prose belongs in the ARB, translated, in one script per arm.
  ///
  /// In en, this message translates to:
  /// **'language'**
  String get settingsWsLang;

  /// The theme group's header. Transcribed: `eva/redesign.html:649` writes `theme` and `:950` carries the pair.
  ///
  /// **THE GROUP HOLDS ONE CONTROL.** The redesign's theme group is the Daylight toggle alone (`:650`); the Phase-9 Light/Dark/System segmented picker is gone.
  ///
  /// In en, this message translates to:
  /// **'theme'**
  String get settingsThemeGroup;

  /// The Daylight mode row's title. Transcribed: `eva/redesign.html:650` writes `Daylight mode` and `:950` carries the pair.
  ///
  /// **THE TOGGLE IS TWO-STATE AGAINST A THREE-STATE FIELD.** On means the light palette and off means the dark one; a stored `system` renders the toggle off and the stored value is not changed until the reader touches it. The `system` arm of `AppThemeMode` therefore becomes unreachable from the UI, and that regression is recorded in the Task 5.7 plan block.
  ///
  /// In en, this message translates to:
  /// **'Daylight mode'**
  String get settingsDaylight;

  /// The light workshop group's header. Transcribed: `eva/redesign.html:651` writes `the light workshop` and `:949` carries the pair.
  ///
  /// **The ten controls under it drive the aurora.** Task 5.8 mounted `LumenCanvas` in the screen root: `LumenPreferences.fromSettings` is the projection of the ten `eva.shader.*` preferences onto the shader's uniforms, and `LumenScene` is what turns them into the sixteen the shader reads. The deferral — citing `docs/superpowers/plans/2026-10-13-lumen-redesign.md:805-811` — is discharged.
  ///
  /// In en, this message translates to:
  /// **'the light workshop'**
  String get settingsWsLight;

  /// The Aurora engine row's title. Transcribed: `eva/redesign.html:652` writes `Aurora engine` and `:951` carries the pair.
  ///
  /// **The switch turns the aurora off.** The prototype hides its canvas (`eva/redesign.html:1468`), and the client's ambient falls back to the legacy background while it is hidden.
  ///
  /// In en, this message translates to:
  /// **'Aurora engine'**
  String get settingsShaderEngine;

  /// The Curtain shape row's title. Transcribed: `eva/redesign.html:653` writes `Curtain shape` and `:952` carries the pair.
  ///
  /// **TWO DIVERGENCES FROM THE PROTOTYPE'S OWN ROW, and the second one was nearly missed.**
  ///
  /// **THE LABEL GOES ABOVE THE CONTROL.** The four-segment control cannot share a row with a 14.5px label at 320px — the standing 320×568 viewport matrix is a gate, and the prototype's own `min-width:44px` (`:183`) is a tap-target floor this client does not shrink. Recorded at the row and at `SettingsTile.stacked`.
  ///
  /// **AND THE CONTROL'S GEOMETRY IS THE WIDE ONE, WHERE THE PROTOTYPE'S IS THE PLAIN ONE.** The prototype's `:654` is a plain `.segp` — `:183`'s `10px` label and `8px 10px` padding — and the client's is the wide geometry of `:188-189`: `:189`'s `11px` label and `12px 0` padding, with equal quarters. The **only** `.segp.wide` in the prototype is the language control at `:646`, and the client uses the wide geometry here because it is the geometry that fits a full-width row.
  ///
  /// In en, this message translates to:
  /// **'Curtain shape'**
  String get settingsCurtainShape;

  /// One of the four Curtain shape segments. Transcribed: `eva/redesign.html:655` writes `top` and `:952` carries the pair.
  ///
  /// `CurtainShape.top` is `u_shape` 0 — the prototype's `data-s="0"`.
  ///
  /// In en, this message translates to:
  /// **'top'**
  String get settingsCurtainTop;

  /// One of the four Curtain shape segments. Transcribed: `eva/redesign.html:655` writes `bottom` and `:952` carries the pair.
  ///
  /// `CurtainShape.bottom` is `u_shape` 1 — the prototype's `data-s="1"`.
  ///
  /// In en, this message translates to:
  /// **'bottom'**
  String get settingsCurtainBottom;

  /// One of the four Curtain shape segments. Transcribed: `eva/redesign.html:655` writes `sides` and `:952` carries the pair.
  ///
  /// In en, this message translates to:
  /// **'sides'**
  String get settingsCurtainSides;

  /// One of the four Curtain shape segments. Transcribed: `eva/redesign.html:655` writes `shafts` and `:952` carries the pair.
  ///
  /// **The one shape the prototype gates above about 2 Mpx** — the shafts measure 5.04 ns/px against the bands' 2.98. The client does not mount the shader, so the gate has nothing to act on yet.
  ///
  /// In en, this message translates to:
  /// **'shafts'**
  String get settingsCurtainShafts;

  /// The Reach row's title. Transcribed: `eva/redesign.html:658` writes `Reach` and `:953` carries the pair.
  ///
  /// The slider runs 18-110 with a default of 42 — the prototype's own `min`, `max` and `value` attributes.
  ///
  /// In en, this message translates to:
  /// **'Reach'**
  String get settingsReach;

  /// The Brightness row's title. Transcribed: `eva/redesign.html:659` writes `Brightness` and `:953` carries the pair.
  ///
  /// **THE TABLE'S KEY IS `glow` AND ITS VALUE IS `Brightness`**, which is the same word the markup carries — so there is nothing to resolve between the two, and the row is transcribed from the markup.
  ///
  /// **NOT A UNIFORM.** The prototype folds it into the ambient target (`:891`) and never sends it to the GPU.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get settingsBrightness;

  /// The Touch glow row's title. Transcribed: `eva/redesign.html:660` writes `Touch glow` and `:951` carries the pair.
  ///
  /// The slider runs 0-100 with a default of 55. The prototype's conversion is `(v/100)*0.6` (`:1471`) — the ceiling the glow may reach — and it is not the same `/100` the other two sliders use.
  ///
  /// In en, this message translates to:
  /// **'Touch glow'**
  String get settingsTouchGlow;

  /// The Hue row's title. Transcribed: `eva/redesign.html:661` writes `Hue` and `:953` carries the pair.
  ///
  /// The slider runs 0-360 with a default of **312** — the declared control default at `:661`. The prototype's *boot* state is 258 (`:882`), and the two disagree; the declared default is the one transcribed, and the disagreement is recorded at the field.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get settingsHue;

  /// The Multichrome melt row's title. Transcribed: `eva/redesign.html:662` writes `Multichrome melt` and `:954` carries the pair.
  ///
  /// The switch is off in the prototype's markup, which is the default the field carries.
  ///
  /// In en, this message translates to:
  /// **'Multichrome melt'**
  String get settingsMultichromeMelt;

  /// The Ray combing row's title. Transcribed: `eva/redesign.html:663` writes `Ray combing` and `:954` carries the pair.
  ///
  /// The switch is `checked` in the prototype's markup, which is the default the field carries.
  ///
  /// In en, this message translates to:
  /// **'Ray combing'**
  String get settingsRayCombing;

  /// The White cores row's title. Transcribed: `eva/redesign.html:664` writes `White cores` and `:954` carries the pair.
  ///
  /// The switch is `checked` in the prototype's markup, which is the default the field carries.
  ///
  /// In en, this message translates to:
  /// **'White cores'**
  String get settingsWhiteCores;

  /// The Dot veil row's title. Transcribed: `eva/redesign.html:665` writes `Dot veil` and `:954` carries the pair.
  ///
  /// The switch is off in the prototype's markup, which is the default the field carries.
  ///
  /// In en, this message translates to:
  /// **'Dot veil'**
  String get settingsDotVeil;

  /// The witness sky group's header. Transcribed: `eva/redesign.html:666` writes `witness sky` and `:955` carries the pair.
  ///
  /// **All seven controls under it are consumed**, by `/reading`'s `WitnessSky` and by the sky's cap. That is the one group in the Workshop whose switches change what is on screen today.
  ///
  /// In en, this message translates to:
  /// **'witness sky'**
  String get settingsSkyGroup;

  /// The Stars row's title. Transcribed: `eva/redesign.html:667` writes `Stars` and `:955` carries the pair.
  ///
  /// **OFF HIDES THE SKY; IT DOES NOT DELETE IT.** The prototype's Stars-off calls `clearStars()` (`:1483`), but the prototype has no persistence — its stars are DOM elements — while this client's sky is a reader's own record of what they have read. The divergence is recorded at the control.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get settingsStars;

  /// The Constellations row's title. Transcribed: `eva/redesign.html:668` writes `Constellations` and `:955` carries the pair.
  ///
  /// The prototype **removes the constellation's `svg` outright** (`:1484-1485`) rather than hiding it, and `WitnessSky` has the same shape: the `showConstellation` switch decides whether the line is drawable at all.
  ///
  /// In en, this message translates to:
  /// **'Constellations'**
  String get settingsConstellations;

  /// The Star count row's title. Transcribed: `eva/redesign.html:669` writes `Star count` and `:956` carries the pair.
  ///
  /// The slider runs 0-60 with a default of 44 — the prototype's `starCap=44` (`:1131`). **This is the sky's CAP, not a paint parameter**: it decides how many lit verses the store keeps.
  ///
  /// In en, this message translates to:
  /// **'Star count'**
  String get settingsStarCount;

  /// The Star brightness row's title. Transcribed: `eva/redesign.html:670` writes `Star brightness` and `:956` carries the pair.
  ///
  /// The slider runs 30-150 with a default of 100. The prototype writes `--starB = v/100` (`:1488`) and `WitnessSky.brightness` takes 0.3-1.5, so the conversion is `/100`.
  ///
  /// In en, this message translates to:
  /// **'Star brightness'**
  String get settingsStarBrightness;

  /// The Star shape row's title. Transcribed: `eva/redesign.html:671` writes `Star shape` and `:957` carries the pair.
  ///
  /// **THE SEGMENT'S FOUR LABELS ARE THE PROTOTYPE'S OWN UNTRANSLATED ENGLISH** — `dot`, `star`, `cross`, `gem` at `:673` — and they are kept as they are, because they are widget literals and not ARB keys. Putting them in this file would force them into `app_localizations_test.dart`'s `mustBeIdentical` set, and that set is the gate that catches an untranslated string. The Arabic typography gate declares the runs as they render.
  ///
  /// **AND THE ROW HAS THE SAME TWO DIVERGENCES AS THE CURTAIN SHAPE'S** — the label above the control, and the wide geometry where the prototype's `:672` is a plain `.segp`. See `settingsCurtainShape` for both.
  ///
  /// In en, this message translates to:
  /// **'Star shape'**
  String get settingsStarShape;

  /// The Star field row's title. Transcribed: `eva/redesign.html:676` writes `Star field` and `:957` carries the pair.
  ///
  /// **THE SEGMENT'S THREE LABELS ARE THE PROTOTYPE'S OWN UNTRANSLATED ENGLISH** — `crown`, `high`, `full` at `:678` — and they are kept as they are, for `settingsStarShape`'s reason.
  ///
  /// **AND THE ROW HAS THE SAME TWO DIVERGENCES AS THE CURTAIN SHAPE'S** — the label above the control, and the wide geometry where the prototype's `:677` is a plain `.segp`. See `settingsCurtainShape` for both.
  ///
  /// In en, this message translates to:
  /// **'Star field'**
  String get settingsStarField;

  /// The Twinkle row's title. Transcribed: `eva/redesign.html:681` writes `Twinkle` and `:957` carries the pair.
  ///
  /// **COMBINED WITH REDUCE MOTION, NEVER INSTEAD OF IT.** The prototype's handler sets `notwinkle` when the switch is off **or** reduce motion is on (`:1489`), and the client combines the reader's preference with the platform's the same way.
  ///
  /// In en, this message translates to:
  /// **'Twinkle'**
  String get settingsTwinkle;

  /// The focus & ritual group's header. Transcribed: `eva/redesign.html:682` writes `focus & ritual` and `:958` carries the pair.
  ///
  /// **SIX OF THE SEVEN CONTROLS UNDER IT ARE READ TODAY, AND THE COUNT WAS “SIX ARE READ BY NOTHING” UNTIL PHASE 7 SHIPPED.**
  ///
  /// **The six, and who reads them:** the focus delay (`features/reading/presentation/pages/reading_page.dart` — the focus dim's idle observer), the selah length (`features/home/presentation/widgets/selah_card.dart` — the silence's length), the breath guide (`features/reading/presentation/pages/reading_page.dart` — the anchor it draws under), the vespers auto-dim (`core/design_system/effects/lumen_preferences.dart` → the ambient's `0.78` factor), reduce motion (`app.dart` and `/reading`) and the haptics (`core/design_system/effects/ritual_haptics.dart` — nine call sites).
  ///
  /// **AND THE SEVENTH IS `calmMotion`, WHICH PERSISTS AND IS READ BY NOTHING** — and that is the prototype's own behaviour rather than a gap: its `CALM` flag is never read by its loop either, and its Workshop deliberately preserves it across a restore.
  ///
  /// **AND THE SIX INCLUDE THE TWO THE RESTORE DELIBERATELY LEAVES ALONE** — the calm motion and the haptics — which the prototype's own reset (`:1499-1525`) also leaves alone, because they are comfort choices rather than light settings.
  ///
  /// In en, this message translates to:
  /// **'focus & ritual'**
  String get settingsRitualGroup;

  /// The Focus delay row's title. Transcribed: `eva/redesign.html:683` writes `Focus delay` and `:958` carries the pair.
  ///
  /// The slider runs 2-15 with a default of 4, and the unit is **seconds** — the prototype multiplies it by 1000 at `:1292`, and `:1287` is where the value is declared.
  ///
  /// In en, this message translates to:
  /// **'Focus delay'**
  String get settingsFocusDelay;

  /// The Selah length row's title. Transcribed: `eva/redesign.html:684` writes `Selah length` and `:958` carries the pair.
  ///
  /// The slider runs 15-120 in **steps of 5** (`:684`'s `step="5"`) — the prototype's only stepped slider — with a default of 60.
  ///
  /// In en, this message translates to:
  /// **'Selah length'**
  String get settingsSelahLength;

  /// The Breath guide row's title. Transcribed: `eva/redesign.html:685` writes `Breath guide` and `:959` carries the pair.
  ///
  /// The switch is `checked` in the prototype's markup. **The breath ring under the hot verse is Phase 7's, and it SHIPPED** — `features/reading/presentation/pages/reading_page.dart` draws the guide under the reader's chosen verse, and the line's own arithmetic is `features/reading/domain/breath_guide.dart`'s, which is **pure Dart**.
  ///
  /// In en, this message translates to:
  /// **'Breath guide'**
  String get settingsBreathGuide;

  /// The Vespers auto-dim row's title. Transcribed: `eva/redesign.html:686` writes `Vespers auto-dim` and `:959` carries the pair.
  ///
  /// The switch is `checked` in the prototype's markup. The gate is 21:00-05:00 (`:886`), and **the dimming itself is Phase 7's and it SHIPPED** — `core/design_system/effects/lumen_preferences.dart` carries the reader's switch into the scene, and the factor and the hour test are `core/domain/entities/vespers.dart`'s, which is **pure Dart**.
  ///
  /// In en, this message translates to:
  /// **'Vespers auto-dim'**
  String get settingsVespersAutoDim;

  /// The Reduce motion row's title. Transcribed: `eva/redesign.html:687` writes `Reduce motion` and `:960` carries the pair.
  ///
  /// **The field was already there** — `UserSettings.reducedMotion` — and the prototype's switch is the same switch. It is an *existing* reader choice, and the restore action deliberately does not touch it.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// The Calm motion row's title. Transcribed: `eva/redesign.html:688` writes `Calm motion` and `:962` carries the pair.
  ///
  /// The prototype's meaning is that the staggers collapse to zero (`:1097`, `:1126`) and the verse reveal becomes instant (`:1382`).
  ///
  /// **The restore action does NOT reset it**, even though it is a new field: the prototype's own reset leaves it alone, because it is a comfort choice rather than a light setting.
  ///
  /// In en, this message translates to:
  /// **'Calm motion'**
  String get settingsCalmMotion;

  /// The Haptics row's title. Transcribed: `eva/redesign.html:689` writes `Haptics` and `:962` carries the pair.
  ///
  /// **Persisted AND answered — and the second half arrived in Phase 7, which is why this description used to say “not yet answered”.** The client had no haptics until the Lumen redesign's Phase 7, so the Workshop was mute against the prototype, which answers every toggle with a haptic (`:1482`, `:1498`). The vocabulary is `core/domain/entities/ritual_haptic.dart`'s and the platform call is `core/design_system/effects/ritual_haptics.dart`'s — the only file that calls `HapticFeedback`, because `core/domain/` is Flutter-free. **And the switch is answered by the switch itself**: the tap that turns haptics **on** fires with the **new** value, because a client that read the stored value would stay silent on the very tap a reader most wants to know it worked.
  ///
  /// **The restore action does NOT reset it**, for `settingsCalmMotion`'s reason.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get settingsHaptics;

  /// The communion group's header. Transcribed: `eva/redesign.html:690` writes `communion` and `:948` carries the pair.
  ///
  /// **The two toggles under it were already there** — `UserSettings.veilWitnesses` and `UserSettings.showPodium` — and Task 5.5 added them for `/communion` to read.
  ///
  /// In en, this message translates to:
  /// **'communion'**
  String get settingsCommunionGroup;

  /// The Veil witnesses row's title. Transcribed: `eva/redesign.html:691` writes `Veil witnesses` and `:948` carries the pair.
  ///
  /// The switch is off in the prototype's markup, and it is off in the field — the veil is opt-in, and the reader's own name is never the one that is hidden.
  ///
  /// In en, this message translates to:
  /// **'Veil witnesses'**
  String get settingsVeilWitnesses;

  /// The Show podium row's title. Transcribed: `eva/redesign.html:692` writes `Show podium` and `:948` carries the pair.
  ///
  /// The switch is `checked` in the prototype's markup, and the field carries the same default.
  ///
  /// In en, this message translates to:
  /// **'Show podium'**
  String get settingsShowPodium;

  /// The Type size row's title. Transcribed: `eva/redesign.html:693` writes `Type size` and `:961` carries the pair.
  ///
  /// **REPLACED THE PHASE-9 `settingsFontSize`**, which was transcribed from the superseded React prototype's font-size row.
  ///
  /// **THE PROTOTYPE'S SLIDER IS NOT TRANSCRIBED.** `:693` is a 16-26px range input, and the client keeps the 1-5 step model that `docs/superpowers/plans/2026-10-13-lumen-redesign.md:1172-1173` already decided on. The row is the existing `FontSizeStepper` plus the preview line, and the divergence is recorded at the row.
  ///
  /// In en, this message translates to:
  /// **'Type size'**
  String get settingsTypeSize;

  /// The stepper's track's slider label, announced as a slider. **Written, not transcribed**: `eva/redesign.html:693` is the redesign's `<input type="range" min="16" max="26" value="20">` and it carries **no accessible name at all**, so this is §14's first row applied to a control the row does not name.
  ///
  /// A distinct string from `settingsTypeSize` because the two name the control from two positions — a row title and a slider.
  ///
  /// In en, this message translates to:
  /// **'Font scale'**
  String get settingsFontScale;

  /// The stepper's decrement button's tooltip and accessible name. **Written, not transcribed**, for `settingsFontScale`'s reason: `eva/redesign.html:693`'s native range input carries its own `+` with no label.
  ///
  /// Deliberately the same sentence as `readingDecreaseFontSize`, for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get settingsDecreaseFontSize;

  /// The stepper's increment button's tooltip and accessible name. **Written, not transcribed**, for `settingsFontScale`'s reason: `eva/redesign.html:693`'s native range input carries its own `+` with no label.
  ///
  /// Deliberately the same sentence as `readingIncreaseFontSize`, for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get settingsIncreaseFontSize;

  /// The restore action row's title. Transcribed: `eva/redesign.html:695` writes `Restore nocturne defaults` and `:961` carries the pair.
  ///
  /// **THE RESET IS SCOPED, AND THE SCOPE IS THE PROTOTYPE'S.** It restores the light, the sky, the ritual and the communion settings to the prototype's literals and it touches **nothing else** — not the language, not the type size, not the palette, not the reduce motion, and not the calm motion or the haptics, which the prototype's own handler (`:1499-1525`) leaves alone as well.
  ///
  /// The per-field tables are in the Task 5.7 plan block, each row citing its prototype line.
  ///
  /// In en, this message translates to:
  /// **'Restore nocturne defaults'**
  String get settingsRestoreDefaults;

  /// The confirmation toast after a restore. Transcribed: `eva/redesign.html:975` writes `↺ nocturne defaults restored` and the handler raises it at `:1525`; the toast shows for 1800ms (`:1393`).
  ///
  /// **THE `↺` (U+21BA) IS IN NO BUNDLED MONO OR SCRIPTURE FACE** — measured against `JetBrainsMono`, `EBGaramond` and `Amiri` — and it is in `Inter` and `IBMPlexSansArabic`. It is therefore rendered with a `fontFamilyFallback`, so the mono face draws the letters and Inter draws the arrow.
  ///
  /// In en, this message translates to:
  /// **'↺ nocturne defaults restored'**
  String get settingsRestored;

  /// The about group's header. Transcribed: `eva/redesign.html:696` writes `about` and `:949` carries the pair.
  ///
  /// **REPLACED THE PHASE-9 VALUE'S SOURCE**, though the painted result is the same: `EvaSectionHeader` upper-cases the label, so `about` and `About` both paint `ABOUT`.
  ///
  /// In en, this message translates to:
  /// **'about'**
  String get settingsAbout;

  /// The Shaders row's title. Transcribed: `eva/redesign.html:697` writes `Shaders` and `:962` carries the pair.
  ///
  /// **The value beside it is the prototype's own literal** — `aurora.frag v8` — and it names the *design system's* shader asset, not this client's. The client's own aurora is `shaders/lumen.frag`; see `settingsWsLight`.
  ///
  /// In en, this message translates to:
  /// **'Shaders'**
  String get settingsShaders;

  /// The Tokens row's title. Transcribed: `eva/redesign.html:698` writes `Tokens` and `:962` carries the pair.
  ///
  /// **The value beside it is the prototype's own literal** — `lumen v1.2` — and it is the design system's version, transcribed.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get settingsTokens;

  /// The app bar's version chip's accessible name. Transcribed: `eva/redesign.html:642` writes the chip, and the React prototype's `Version` row title is kept because the redesign draws a chip and no name.
  ///
  /// **THE CHIP CARRIES THE APP'S REAL VERSION**, which is `AppConfig.appVersion` and not an ARB key, because it is not prose: it is `pubspec.yaml`'s own `version:` with a build suffix, and the settings suite parses `pubspec.yaml` and asserts the two agree. Putting it in this file would have been a number a translator could edit and nothing would check.
  ///
  /// **THE PROTOTYPE'S CHIP IS THE DESIGN SYSTEM'S VERSION** (`v1.2`, the same string as the Tokens row), and the divergence is recorded at the chip.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// The language segment's English option. Transcribed: `eva/redesign.html:647` writes `English`.
  ///
  /// **THE ARABIC ARM NAMES IT IN ARABIC** — `الإنجليزية` — which is the `settings_l10n.dart` rule: a language names itself in its own script, on both arms. The prototype writes `English` in Latin on the Arabic arm, and the divergence is recorded at the segment.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// The language segment's Arabic option. Transcribed: `eva/redesign.html:647` writes `العربية`, which the prototype carries in Arabic on **both** arms.
  ///
  /// **THE ENGLISH ARM IS ALSO ARABIC** — `العربية` — and the prototype does the same, so there is no divergence on this one. The face is the one `eva/redesign.html:186` asks for: an Arabic option inside a Latin screen is drawn in the Arabic face, which is what `SegmentedControl.labelFamilyOf` exists for.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get settingsLanguageArabic;

  /// The failure notice's sentence, on the `/settings` arm. **Written, not transcribed** — the redesign draws no failure state at all.
  ///
  /// It is the app's own localised sentence and deliberately not `state.failure!.message`: `SettingsRepositoryImpl._unreachable` interpolates the raw Dart exception, which on a real device is a `MissingPluginException`.
  ///
  /// In en, this message translates to:
  /// **'Your preferences could not be saved on this device.'**
  String get settingsPreferencesUnavailable;

  /// The failure notice's retry button's label. **Written, not transcribed** — the redesign draws no failure state at all.
  ///
  /// **NAMESPACED `settings*` rather than reused from `homeRetry`, `quizRetry` and `readingRetry`**, which are three separate keys with identical values; the repository namespaces `retry` per screen on purpose.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsRetry;

  /// `eva/redesign.html:931` — `dockHome:["Home","الرئيسية"]`, the first of the five slots of the redesign's dock (`:702-708`). It is the label under the house glyph, and the slot is the **first tab**: `/` is the shell's own path and the home tab is its first child.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dockHome;

  /// `eva/redesign.html:931` — `dockRead:["Read","اقرأ"]`, the second slot of the redesign's dock (`:704`). **It is not a tab**: the prototype's own click handler (`:1277`) opens the reader rather than switching, and the client's second slot is a push action that opens `/reading` over the shell.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get dockRead;

  /// `eva/redesign.html:931` — `dockToday:["Today","اليوم"]`, the third slot of the redesign's dock (`:705`). **It is not a tab either**: the handler (`:1278`) pops the orb and opens the quiz, and the client's third slot is a push action that opens `/quiz` over the shell. The slot's glyph is the prototype's `✦` orb.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dockToday;

  /// `eva/redesign.html:932` — `dockBoard:["Communion","الشركة"]`, the **fourth** slot of the redesign's dock (`:706`) and the **second** of the client's three real tabs. The word is the redesign's own, and it is the same word as the screen's title (`:615`'s `boardT`); the prototype's journey calls the same screen "The Communion" at `:939`'s `rowBoard`.
  ///
  /// In en, this message translates to:
  /// **'Communion'**
  String get dockBoard;

  /// `eva/redesign.html:931` — `dockJourney:["Journey","الرحلة"]`, the **fifth** slot of the redesign's dock (`:707`) and the **third** of the client's real tabs. **The prototype carries the same word twice** — `journey:["Journey","الرحلة"]` at `:933` is the screen's own title — and the client keeps both keys for the same reason: the dock's slot and the screen's heading are two different surfaces.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get dockJourney;

  /// `:966` — `verses:["verses","آيات"]`. The unit the crumb counts with (`${N(b.en.length)} ${tr('verses')}`, `:1346`); home owns the same word under `homeVerses` because the two screens compose different sentences.
  ///
  /// In en, this message translates to:
  /// **'verses'**
  String get readingVerses;

  /// `:966` — `quiz:["quiz","اختبار"]`. The caption the CTA is built around (`:1347`), not a heading: the prototype writes `` `${tr('quiz')} · ${N(qEff)} ${tr('questions')}` ``.
  ///
  /// In en, this message translates to:
  /// **'quiz'**
  String get readingQuiz;

  /// `:966` — `questions:["questions","أسئلة"]`. The unit beside the CTA's numeral. **Not a plural**: the prototype renders one word for every count, exactly as home's `verseCount` and `selahSeconds` do.
  ///
  /// In en, this message translates to:
  /// **'questions'**
  String get readingQuestions;

  /// `:965` — `listen:["listen","استمع"]`. The pill's last button (`#listen`, `:559`).
  ///
  /// In en, this message translates to:
  /// **'listen'**
  String get readingListen;

  /// `:968` — `sky:["sky","سماء"]`. The crumb's third clause (`` `${tr('sky')} ${N(skyN)}` ``, `:1346`) — the count of lit stars, which is `SkyState.count`.
  ///
  /// In en, this message translates to:
  /// **'sky'**
  String get readingSky;

  /// `:974` — `bmk:["✦ bookmarked","✦ تم الحفظ"]`, and the leading `✦` is **deliberately dropped**: U+2726 is in no bundled family (measured — `arabic_typography_test.dart` failed with `[10022]` on the selah glyph before it became a painted star), so a toast carrying it would ship a tofu box. The glyph is decoration on a transient label; the word is the information. `readingBookmark` keeps the button's own name, which `:544` writes as `title="bookmark"` with no glyph at all.
  ///
  /// In en, this message translates to:
  /// **'bookmarked'**
  String get readingBookmarkOn;

  /// `:974` — `bmkOff:["bookmark removed","أُزيل الحفظ"]`. The toggle's off label; a bookmark that reports only the on state cannot be turned off blind.
  ///
  /// In en, this message translates to:
  /// **'bookmark removed'**
  String get readingBookmarkOff;

  /// `eva/redesign.html:933` — the i18n row `journey`, rendered by `:579`'s `.ttl`.
  ///
  /// The screen's own name, and it is the redesign's name for the **profile**: ADR-0022 restored the profile ADR-0001 cut, and the redesign calls it "Journey". The route is `/journey` for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get journeyTitle;

  /// `eva/redesign.html:933` — the i18n row `scribe`, rendered by `:588`'s `.jrole`.
  ///
  /// **The level is an unconditioned literal and there is no levels endpoint.** The backend ships fourteen routes and none of them is a level, a rank or a title; the prototype writes `scribe · level 7` and never changes it. So the whole line is transcribed copy, and the "7" is **not** derived from anything — recorded as a divergence at the widget.
  ///
  /// **The Arabic arm embeds the Arabic-Indic `٧` in the source string** (the prototype's own row, `:933`), so it is a literal in the ARB rather than a `digits()` call at the call site.
  ///
  /// In en, this message translates to:
  /// **'scribe · level 7'**
  String get journeyScribe;

  /// `eva/redesign.html:934` — the i18n row `streakSub`, rendered by `:590`.
  ///
  /// The line under the hero number. The hero number above it is the reader's **real** `current_streak` (`GET /streak/summary`); this line is the prototype's own copy.
  ///
  /// In en, this message translates to:
  /// **'day streak · keep the flame'**
  String get journeyStreakSub;

  /// `eva/redesign.html:935` — the i18n row `rlVerses`, rendered by `:592`.
  ///
  /// **The label is the prototype's, and the quantity behind it is not.** The backend counts **questions**, not verses (`streak.service.ts:5-17` carries `total_questions` / `answered_questions` / `correct_answers` and no verse count at all), so the ring under this label is a **scheduled-day completion ratio**. The divergence is recorded at the derivation, and it is the same shape as recorded decision 27's "beads count questions".
  ///
  /// In en, this message translates to:
  /// **'verses'**
  String get journeyRingVerses;

  /// `eva/redesign.html:935` — the i18n row `rlQuizzes`, rendered by `:593`.
  ///
  /// **This ring is a count, and it is the only one that is.** The prototype writes `data-v="86"` with **no** percent sign where its two neighbours write `83%` and `92%` — an inconsistency in the prototype's own markup, resolved **deliberately** rather than transcribed: the quantity is the number of questions answered, so a percent sign on it would be a unit the number does not have.
  ///
  /// In en, this message translates to:
  /// **'quizzes'**
  String get journeyRingQuizzes;

  /// `eva/redesign.html:935` — the i18n row `rlAcc`, rendered by `:594`.
  ///
  /// Correct answers over answered questions, across the thirty-day history the endpoint returns.
  ///
  /// In en, this message translates to:
  /// **'accuracy'**
  String get journeyRingAccuracy;

  /// `eva/redesign.html:968` — the i18n row `sky`, rendered by `:596`.
  ///
  /// In en, this message translates to:
  /// **'sky'**
  String get journeySky;

  /// `eva/redesign.html:968` — the i18n row `stars`, rendered by `:596`.
  ///
  /// **Real.** `SkyRepository.count()` — the port's own doc already names `journey` as the consumer of it, and the prototype's `jSkyN` (`:596`) is written by `updateSkyWidget` (`:1186-1187`) from the same live star set.
  ///
  /// In en, this message translates to:
  /// **'stars lit'**
  String get journeyStarsLit;

  /// `eva/redesign.html:968` — the i18n row `consts`, rendered by `:596`.
  ///
  /// **The prototype's own meaning is "books whose final verse was lit"** (`constDone`, `:1132`, set at `:1156-1157`). This client has no book-completion record, so the count is a **proxy** — the distinct books among the completed scheduled days — and the proxy is recorded at the derivation with what it gives up.
  ///
  /// In en, this message translates to:
  /// **'constellations'**
  String get journeyConstellations;

  /// `eva/redesign.html:936` — the i18n row `medals`, rendered by `:597`'s `.car-label`.
  ///
  /// In en, this message translates to:
  /// **'medals'**
  String get journeyMedals;

  /// `eva/redesign.html:937` — the i18n row `m1`, rendered by `:599`'s `.mn`.
  ///
  /// **One of four medals the prototype draws as static markup.** The four medals, their glyphs and their count are ADR-0022's fiction: "No screen may render a hard-coded … medal …; the fiction lives in data sources". The **names** are copy and live here; **which** medals exist, and how many of the twelve are earned, come from the medals port.
  ///
  /// In en, this message translates to:
  /// **'first light'**
  String get journeyMedalFirstLight;

  /// `eva/redesign.html:937` — the i18n row `m2`, rendered by `:600`'s `.mn`.
  ///
  /// The only one of the four whose emblem is a **typographic** glyph — `❧` (U+2767), which the `cmap` measurement puts in **EBGaramond only**. It is therefore drawn in the scripture family, pinned, on both arms.
  ///
  /// In en, this message translates to:
  /// **'psalmist'**
  String get journeyMedalPsalmist;

  /// `eva/redesign.html:937` — the i18n row `m3`, rendered by `:601`'s `.mn`.
  ///
  /// The `×` is U+00D7, which is in all five bundled families. The `7` is Latin in the prototype's own string; the Arabic arm is the prototype's `٧ أيام`.
  ///
  /// In en, this message translates to:
  /// **'streak ×7'**
  String get journeyMedalStreakSeven;

  /// `eva/redesign.html:937` — the i18n row `m4`, rendered by `:602`'s `.mn`.
  ///
  /// In en, this message translates to:
  /// **'john'**
  String get journeyMedalJohn;

  /// `eva/redesign.html:938` — the i18n row `account`, rendered by `:604`'s `.car-label`.
  ///
  /// In en, this message translates to:
  /// **'account'**
  String get journeyAccount;

  /// `eva/redesign.html:939` — the i18n row `rowBoard`, rendered by `:605`'s `.srow`.
  ///
  /// The board's own title — the same word the screen it navigates to uses (`leaderboardTitle`, `eva/redesign.html:939`'s `commG` row).
  ///
  /// In en, this message translates to:
  /// **'The Communion'**
  String get journeyRowBoard;

  /// `eva/redesign.html:938` — the i18n row `rowSet`, rendered by `:606`'s `.srow`.
  ///
  /// **The app bar's gear button names the same destination**, so the tooltip and the row share this one string rather than two that can drift.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get journeyRowSettings;

  /// `eva/redesign.html:938` — the i18n row `rowShare`, rendered by `:607`'s `.srow`.
  ///
  /// **The prototype has no handler for this row either** — `el('rowShare')` appears nowhere in the prototype's script, so the button is rendered-and-inert there too. Here it is rendered-**and-disabled**, with the reason in its accessible name, because §14 asks a reader to be told *why* a control cannot be pressed.
  ///
  /// In en, this message translates to:
  /// **'Share progress'**
  String get journeyRowShare;

  /// `eva/redesign.html:938` — the i18n row `rowPlans`, rendered by `:608`'s `.srow`.
  ///
  /// **No handler in the prototype, and no endpoint in the backend** — the fourteen routes include nothing for reading plans. Same treatment as `journeyRowShare`: rendered-and-disabled, with the reason in the accessible name.
  ///
  /// In en, this message translates to:
  /// **'Reading plans'**
  String get journeyRowPlans;

  /// Appended to a control's accessible name when the control is **inert** — and the
  /// reason is that the feature is not built in this client.
  ///
  /// §14's disabled row: a reader has to be told WHY a control cannot be pressed, not only that it cannot. `LoginPage`'s four inert social buttons and `/`'s avatar are the precedent, and they are the reason /quiz can ship a dead CTA honestly at all.
  ///
  /// **The fifth of the `*UnavailableSuffix` keys**, and it reads like the four that say the same thing — `authUnavailableSuffix`, `homeUnavailableSuffix`, `readingUnavailableSuffix` and this one all read "unavailable in this build" — because the reason is the same: the feature is not built in this client. `quizUnavailableSuffix` reads differently because its control is dead for a different reason.
  ///
  /// In en, this message translates to:
  /// **'unavailable in this build'**
  String get journeyUnavailableSuffix;

  /// `eva/redesign.html` has no retry on the journey — the prototype's screen has no
  /// data layer to fail — so this is the **fifth** of the per-screen `*Retry` keys
  /// and it reads like the other four.
  ///
  /// **The repository namespaces `retry` per screen on purpose**, and this key is the
  /// sixth instance of that rule rather than an exception to it: `homeRetry`,
  /// `quizRetry`, `readingRetry`, `settingsRetry` and `leaderboardRetry` are five
  /// separate keys with the same value, and the journey's screen borrowing the
  /// board's would have been the first screen to take another screen's copy.
  ///
  /// See `app_localizations_test.dart` for the assertion that keeps the family
  /// honest — it asserts the *shape* (six of them, five of which say the same
  /// thing) rather than that they are all equal, because a test that demanded
  /// they differ would be satisfied by a translator harmonising them and would
  /// be wrong.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get journeyRetry;

  /// Written, not transcribed: `eva/redesign.html` draws no servant portal at all — the redesign has seven reader screens and no admin surface, because the admin routes are the 2026-10-21 amendment (ADR-0026) and the prototype predates them. This is the hub's own section label.
  ///
  /// In en, this message translates to:
  /// **'Servant portal'**
  String get servantHubTitle;

  /// Written, not transcribed: the prototype draws no servant portal. This names the one section every servant role has — the cohort's roster for one day — and it is the same word the report screen's own title uses (`servantReportTitle`), because they are the same surface seen from two places.
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get servantHubReportTitle;

  /// Written, not transcribed: the prototype draws no servant portal. This names the admin servant's second section — choosing the passage a cohort reads next — and the backend's own route is `POST /admin/readings/schedule`.
  ///
  /// In en, this message translates to:
  /// **'Schedule a reading'**
  String get servantHubScheduleTitle;

  /// Written, not transcribed: the prototype draws no servant portal. This names the admin servant's third section — writing or drafting the questions a reading is served with — and the backend's own routes are `/admin/questions/commit` and `/admin/questions/ai-generate`.
  ///
  /// In en, this message translates to:
  /// **'Author questions'**
  String get servantHubQuestionsTitle;

  /// Written, not transcribed: the prototype draws no servant portal. This is the admin-can-use-the-kids'-app half of the portal: the entry opens the reader's own shell at `/`, because a servant is also a reader — the grant table's first three capabilities are every role's.
  ///
  /// In en, this message translates to:
  /// **'Read as a reader'**
  String get servantHubReaderTitle;

  /// Written, not transcribed: the prototype draws no servant portal. This is the report screen's own title, and it is the same word the hub uses for the section that opens it, because they are one surface seen from two places.
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get servantReportTitle;

  /// Written, not transcribed: the prototype draws no servant portal. The report's querystring names it `group_id` and the backend's rows are `groups`; the reader-facing word is the one the app's own `/communion` screen uses for the same cohort.
  ///
  /// In en, this message translates to:
  /// **'Cohort'**
  String get servantReportGroupLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The report's second querystring parameter, `date`, in the shape `YYYY-MM-DD` the backend echoes back as `report_date`.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get servantReportDateLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The report's one action, and it names what it does — the roster — rather than the request behind it.
  ///
  /// In en, this message translates to:
  /// **'Show the roster'**
  String get servantReportSubmit;

  /// Written, not transcribed: the prototype draws no servant portal. The caption of the report's first total, which is the server's own `total_students` — a count over the rows the server sent and never one this client counted.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get servantReportTotalStudents;

  /// Written, not transcribed: the prototype draws no servant portal. The caption of the report's second total, which is the server's own `completed_count` — the children whose approved questions are all answered.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get servantReportCompleted;

  /// Written, not transcribed: the prototype draws no servant portal. The empty state's headline, for a cohort with no children on that day — a real answer, because the report's query is a LEFT JOIN and produces rows even with no reading.
  ///
  /// In en, this message translates to:
  /// **'No roster'**
  String get servantReportEmptyTitle;

  /// Written, not transcribed: the prototype draws no servant portal. The empty state's explanation, and it names the day — a roster for another day is not an empty roster.
  ///
  /// In en, this message translates to:
  /// **'This cohort has no children for that day.'**
  String get servantReportEmptyMessage;

  /// Written, not transcribed: the prototype has no failure state at all. This is the servant portal's **first** per-screen `*Retry` key, and the repository namespaces `retry` per screen on purpose — `homeRetry`, `quizRetry`, `readingRetry`, `settingsRetry`, `leaderboardRetry` and `journeyRetry` are six more.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get servantReportRetry;

  /// Written, not transcribed: the prototype draws no servant portal. The roster row's first number, the child's lifetime `total_points` — the server's own figure, drawn beside the child's name.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get servantReportPoints;

  /// Written, not transcribed: the prototype draws no servant portal. The roster row's second number, the child's `current_streak` in days. The word is the app's own — the home screen's streak chip says the same thing.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get servantReportStreak;

  /// Written, not transcribed: the prototype draws no servant portal. The caption of the roster row's third number — the server's own `questions_progress` string, drawn **verbatim** as `3/5` and never re-parsed into two numbers.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get servantReportProgress;

  /// Written, not transcribed: the prototype draws no servant portal. The refusal the report form makes **before** it asks, because the report's querystring types the cohort as a number and the server's 400 would name a field the servant never saw.
  ///
  /// In en, this message translates to:
  /// **'The cohort must be a whole number.'**
  String get servantReportInvalidGroup;

  /// Written, not transcribed: the prototype draws no servant portal. The report form's second refusal. The server defaults the date to its own today when the querystring omits it, and this client always sends one — so an empty date is this client's own gap.
  ///
  /// In en, this message translates to:
  /// **'The date is required.'**
  String get servantReportMissingDate;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule screen's own title, and the same word the hub uses for the section that opens it, because they are one surface seen from two places.
  ///
  /// In en, this message translates to:
  /// **'Schedule a reading'**
  String get servantScheduleTitle;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's first field, which the backend types as `group_ids` — an array of at least one, so the form takes a list and the label says so.
  ///
  /// In en, this message translates to:
  /// **'Cohort ids'**
  String get servantScheduleGroupIdsLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The hint that says how the cohort list is written. The backend takes an array, and a form that took one id could not schedule a reading for two cohorts at once.
  ///
  /// In en, this message translates to:
  /// **'comma separated'**
  String get servantScheduleGroupIdsHint;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's date field, which the backend types as `scheduled_date` in a fixed `YYYY-MM-DD` shape and refuses anything else.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get servantScheduleDateLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The hint that says how the date is written — in words rather than in the machine's own separators, because the field is a plain text field and the backend's own error would not say it.
  ///
  /// In en, this message translates to:
  /// **'year, month, day'**
  String get servantScheduleDateHint;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's book field, which the backend types as `book_number` between 1 and 66 — one is Genesis and 43 is John.
  ///
  /// In en, this message translates to:
  /// **'Book number'**
  String get servantScheduleBookLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's first boundary, which the backend types as `start_chapter` and pairs with `start_verse` to name the passage's first word.
  ///
  /// In en, this message translates to:
  /// **'Start chapter'**
  String get servantScheduleStartChapterLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's first verse, which the backend types as `start_verse`.
  ///
  /// In en, this message translates to:
  /// **'Start verse'**
  String get servantScheduleStartVerseLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's last chapter, which the backend types as an **optional** `end_chapter` — the server's own transform substitutes the start chapter for a missing one, and this form leaves it empty rather than guessing.
  ///
  /// In en, this message translates to:
  /// **'End chapter'**
  String get servantScheduleEndChapterLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's last verse, which the backend types as `end_verse`.
  ///
  /// In en, this message translates to:
  /// **'End verse'**
  String get servantScheduleEndVerseLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's exclusion list, which the backend types as `excluded_verses` — an array of `{chapter, verse}` objects, so this form takes a pair at a time.
  ///
  /// In en, this message translates to:
  /// **'Excluded verses'**
  String get servantScheduleExcludedLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The hint that says how one excluded verse is written and how several are separated. The backend takes an array of pairs, and a field that took one pair at a time could not leave more than one verse out.
  ///
  /// In en, this message translates to:
  /// **'chapter and verse, comma separated'**
  String get servantScheduleExcludedHint;

  /// Written, not transcribed: the prototype draws no servant portal. The label of the schedule form's only switch, which the backend types as `generate_ai_questions` — and it says **generate the question**, not *schedule with AI*, because the server generates the question and attaches it to the reading it just wrote.
  ///
  /// In en, this message translates to:
  /// **'Generate the question with AI'**
  String get servantScheduleAiLabel;

  /// Written, not transcribed, and **it states a backend behaviour the screen must not hide**: `admin.routes.ts:195` runs `DELETE FROM questions WHERE reading_id = $1` when the AI switch is on, so re-scheduling the same cohort and date destroys the questions already written for it. The server does not say so in its answer.
  ///
  /// In en, this message translates to:
  /// **'Scheduling the same cohort and date again with this on deletes the questions already written for that date.'**
  String get servantScheduleAiWarning;

  /// Written, not transcribed, and **it states a backend behaviour the screen must not hide**: the insert is `ON CONFLICT (group_id, scheduled_date) DO UPDATE` (`admin.routes.ts:157`), so scheduling the same cohort and date again replaces the passage rather than failing or duplicating it.
  ///
  /// In en, this message translates to:
  /// **'Scheduling the same cohort and date again replaces the passage.'**
  String get servantScheduleUpsertWarning;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's one action, and it names what it does — the reading — rather than the request behind it.
  ///
  /// In en, this message translates to:
  /// **'Schedule the reading'**
  String get servantScheduleSubmit;

  /// Written, not transcribed: the prototype has no failure state at all. This is the servant portal's **second** per-screen `*Retry` key, and the repository namespaces `retry` per screen on purpose, so this screen does not borrow the report's.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get servantScheduleRetry;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's first refusal, and it is the server's own rule — `admin.routes.ts:9` types `group_ids` as an array with `min(1)` — checked before the request rather than after it.
  ///
  /// In en, this message translates to:
  /// **'Name at least one cohort.'**
  String get servantScheduleErrorEmptyGroupIds;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's refusal for a numeric field that is not a whole number, or is a number the server's own minimum and maximum refuse. The message names the fault and not the field, because the field carries it.
  ///
  /// In en, this message translates to:
  /// **'That is not a whole number.'**
  String get servantScheduleErrorInvalidNumber;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's refusal for a date that is not the shape `admin.routes.ts:10` types — a regex over the text, which the server would answer with a 400 naming a field the admin never saw.
  ///
  /// In en, this message translates to:
  /// **'The date must be written as year, month, day.'**
  String get servantScheduleErrorInvalidDate;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's refusal for an excluded verse that is not a pair. The backend types one as an object (`admin.routes.ts:16-28`) and this form writes the lower-case spelling of it.
  ///
  /// In en, this message translates to:
  /// **'An excluded verse is written as a chapter and a verse.'**
  String get servantScheduleErrorInvalidExcludedVerse;

  /// Written, not transcribed: the prototype draws no servant portal. The schedule form's range refusal, and it is the server's own rule: `admin.routes.ts:126-129` answers a passage whose start boundary is after its end boundary with a 400 and the sentence `start boundary cannot be after end boundary`.
  ///
  /// In en, this message translates to:
  /// **'The start of the passage cannot be after its end.'**
  String get servantScheduleErrorReversedRange;

  /// Written, not transcribed: the prototype draws no servant portal. The question editor's own title, and the same word the hub uses for the section that opens it, because they are one surface seen from two places.
  ///
  /// In en, this message translates to:
  /// **'Author questions'**
  String get servantQuestionsTitle;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's reading field, which the backend types as `reading_id` — a plain non-empty string, and not a uuid, because the ids this backend mints are not uuids either.
  ///
  /// In en, this message translates to:
  /// **'Reading id'**
  String get servantQuestionsReadingIdLabel;

  /// Written, not transcribed: the prototype draws no servant portal. **The note that says where the id came from**, because the backend has **no endpoint that lists a cohort's scheduled readings** — the schedule route is the only one that creates a reading, and it answers with the id. A screen that pretended a lookup existed would be lying about the backend.
  ///
  /// In en, this message translates to:
  /// **'There is no list of a cohort\'s scheduled readings, so this id is the one the schedule answered with or one you typed.'**
  String get servantQuestionsReadingIdNote;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's type control's accessible name, and it names the **control** rather than the selected option — the segmented control's track is an activatable node of its own, and naming it after the selected option would put two activatable nodes on screen with the same label.
  ///
  /// In en, this message translates to:
  /// **'Question type'**
  String get servantQuestionsTypeLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The label of the backend's `mcq` question type — the only one the AI route accepts by default, and the one the schedule route generates.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get servantQuestionsTypeMcq;

  /// Written, not transcribed: the prototype draws no servant portal. The label of the backend's `true_false` question type, the second of the two the AI route accepts.
  ///
  /// In en, this message translates to:
  /// **'True or false'**
  String get servantQuestionsTypeTrueFalse;

  /// Written, not transcribed: the prototype draws no servant portal. The label of the backend's `short_answer` question type — the one the AI route **refuses**, because `ai.routes.ts:10` types its request as an enum of two.
  ///
  /// In en, this message translates to:
  /// **'Short answer'**
  String get servantQuestionsTypeShortAnswer;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's Arabic prompt, which the commit schema types as `prompt_ar` — the app's two languages are the app's own, and the question is served to children in both.
  ///
  /// In en, this message translates to:
  /// **'Question in Arabic'**
  String get servantQuestionsPromptArLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's English prompt, which the commit schema types as `prompt_en`.
  ///
  /// In en, this message translates to:
  /// **'Question in English'**
  String get servantQuestionsPromptEnLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The Arabic half of one answer option, which the commit schema types as `{ar, en}` — a pair, so an option's editor has two fields and not one.
  ///
  /// In en, this message translates to:
  /// **'Option in Arabic'**
  String get servantQuestionsOptionArLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The English half of one answer option, which the commit schema types as `{ar, en}` — the same pair the AI draft returns, which is why a draft is editable and committable without a conversion.
  ///
  /// In en, this message translates to:
  /// **'Option in English'**
  String get servantQuestionsOptionEnLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's correct-answer field, which the commit schema types as `correct_answer` — a letter for a question with options, and the answer itself for a short answer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get servantQuestionsCorrectAnswerLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's point value, which the commit schema types as `points_value` and defaults to ten.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get servantQuestionsPointsLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's sort order, which the commit schema types as `sort_order` and defaults to one — the order the reader meets the questions in.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get servantQuestionsOrderLabel;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's AI action, and it names what it asks for — a **draft**, which the admin then edits before committing. The server's own route is `/admin/questions/ai-generate`.
  ///
  /// In en, this message translates to:
  /// **'Ask for a draft'**
  String get servantQuestionsDraftButton;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's one committing action, and it names what it does — the question is stored, not merely drafted.
  ///
  /// In en, this message translates to:
  /// **'Commit the question'**
  String get servantQuestionsCommitButton;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's control for one more answer option, which the commit schema types as an optional `options` map of lettered pairs.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get servantQuestionsAddOption;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's control for taking one answer option away again. **A short word on purpose**: it sits on a row that already names the option's letter.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get servantQuestionsRemoveOption;

  /// Written, not transcribed: the prototype has no failure state at all. This is the servant portal's **third** per-screen `*Retry` key, and the repository namespaces `retry` per screen on purpose, so this screen does not borrow the report's or the schedule form's.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get servantQuestionsRetry;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's first refusal, and it is the commit schema's own rule — `admin.routes.ts:36` types `reading_id` as a non-empty string — checked before the request rather than after it.
  ///
  /// In en, this message translates to:
  /// **'Type the reading id first.'**
  String get servantQuestionsErrorMissingReadingId;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's refusal for a missing prompt, and it names **both** languages because the commit schema types both prompts as `min(1)` — a question with one language is a question half the cohort cannot read.
  ///
  /// In en, this message translates to:
  /// **'The question needs both languages.'**
  String get servantQuestionsErrorEmptyPrompt;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's refusal for a question with no correct answer, and it is the commit schema's own rule — `admin.routes.ts:45` types `correct_answer` as `min(1)` — checked before the request.
  ///
  /// In en, this message translates to:
  /// **'Say which answer is correct.'**
  String get servantQuestionsErrorEmptyCorrectAnswer;

  /// Written, not transcribed: the prototype draws no servant portal. The note under the editor's empty options list, and it says **why** the list is empty rather than leaving a reader to wonder whether the form had broken.
  ///
  /// In en, this message translates to:
  /// **'A short-answer question has no options.'**
  String get servantQuestionsEmptyOptions;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's refusal for a point value or an order that is not a whole number, and it is the commit schema's own rule — `admin.routes.ts:46-47` types both as `z.number().int()`.
  ///
  /// In en, this message translates to:
  /// **'That is not a whole number.'**
  String get servantQuestionsErrorInvalidNumber;

  /// Written, not transcribed: the prototype draws no servant portal. The editor's refusal for a draft that the AI wrote about ONE reading's passage while the form names ANOTHER — the commit would store the second reading's id with the first reading's question, so the commit is refused and the admin is told why. **The way out is in the sentence**: ask for a draft again, or change the reading id.
  ///
  /// In en, this message translates to:
  /// **'This draft is about another reading. Ask for a draft again, or change the reading id.'**
  String get servantQuestionsErrorDraftForAnotherReading;
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
