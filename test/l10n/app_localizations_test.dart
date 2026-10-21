import 'dart:convert';
import 'dart:io';

import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ARB pair, as a **file** rather than as two objects.
///
/// ## WHAT THIS FILE REPLACES, AND WHY IT IS NOT SIMPLY THE OLD FIVE FILES MOVED
///
/// `auth_strings_test.dart`, `home_strings_test.dart`, `quiz_strings_test.dart`,
/// `reading_strings_test.dart` and `result_strings_test.dart` each walked their own
/// table's declarations and compared both arms. That was the right instrument while
/// the arms were hand-written Dart: nothing else noticed a value dropped from one
/// language.
///
/// **Three of those properties are now decided by `gen_l10n` itself** and asserting
/// them here would be asserting the generator:
///
/// * *the two arms carry the same key names* — `flutter gen-l10n` fails the build
///   when a locale file is missing a template key, and fails it again when a locale
///   file has a key the template does not. That is a compile-time check now, which
///   is the whole of §2.1's "a typo becomes a build error" claim;
/// * *no value is empty* is still worth asserting — a translator may well write
///   `""` — so it stays;
/// * *the field walk finds something* stays, because a source walk that found
///   nothing would make every "both arms" assertion a comparison over two empty
///   maps, which is the exact vacuity §7 warns about.
///
/// So this file keeps the properties a **generator cannot have an opinion about**
/// and drops the ones it now enforces. That is not a weakening: it is moving a
/// check from a test to the build, and the three properties that moved are
/// demonstrated to bite in the mutation report.
///
/// ## WHY IT READS THE ARB FILES AND NOT THE GENERATED CLASSES
///
/// The generated classes are the *product*; the ARB files are the *input*, and three
/// of the gates below are about the input: that every key carries a `@key`
/// description (the prototype `file:line` citations live there and nowhere else),
/// that no Arabic value holds Latin script, and that the two arms differ where they
/// must. None of those is observable from the generated Dart, which has discarded
/// the descriptions.
///
/// `secret_masking_test.dart` is the precedent for reading a source file rather than
/// an object's shape, and `dart:mirrors` is unavailable here anyway.
void main() {
  /// The decoded template, which is also the English arm.
  final Map<String, dynamic> en = _decode('lib/l10n/app_en.arb');

  /// The decoded Arabic arm.
  final Map<String, dynamic> ar = _decode('lib/l10n/app_ar.arb');

  /// The keys in the Arabic arm whose Latin script is **correct**, and why.
  ///
  /// Every entry is a brand mark or a value that is not prose. This set is the
  /// successor to two per-file exception lists (`home_strings_test.dart` excepted
  /// `wordmark`; `auth_strings_test.dart` had a `shared` set of three), and it is
  /// written out in one place so that a sixth Latin-holding key has to be argued for
  /// in a diff rather than typed into a test.
  ///
  /// ## THE LOGIN SCREEN'S LATIN IS NO LONGER IN THIS TABLE, AND THAT IS NOT AN
  /// ## OMISSION
  ///
  /// Phase 5.1 rebuilt `/login` against `redesign.html:503-511`, whose login
  /// translates exactly three strings and renders five as literal markup:
  /// `EVANGELION`, `the word · illuminated`, `αω · nocturne v1.2`,
  /// `google`/`apple`. Those five are **widget literals**, not ARB keys — the
  /// redesign's own `applyLang()` (`:985`) rewrites only `[data-i18n]` elements
  /// and touches none of them — so this ARB-level table no longer sees them.
  /// Their Latin-on-the-Arabic-arm correctness is asserted where they are
  /// painted: `arabic_typography_test.dart`'s `/login` group.
  ///
  /// ## AND IT IS **EMPTY** IN PHASE 5.2, WHICH IS A RESULT RATHER THAN A GAP
  ///
  /// The one member the redesigned home might have contributed — a wordmark key —
  /// does not exist: the redesign's `/` has no wordmark, and its two card
  /// eyebrows, its carousel label and its four category labels are all real
  /// Arabic on the Arabic arm. Every value the table now holds is prose in its
  /// own script, so there is nothing to exempt. An empty set here is the
  /// strongest state it can be in, and a key that arrives holding Latin has to
  /// argue its way in rather than join a list that already made that argument.
  const Set<String> latinIsCorrect = <String>{
    // Five Task 5.5 /communion keys contain MessageFormat placeholders:
    // {position}, {name}, {n}, {days}, {dayUnit}, {hours}, {hourUnit}.
    // These placeholder names are ASCII keywords of the MessageFormat grammar
    // discarded by gen_l10n at compile time and never reach a reader.
    'leaderboardWitness',
    'leaderboardGapLine',
    'leaderboardPassHint',
    'leaderboardResetsIn',
    'leaderboardCheerSent',
    // ## AND IT IS **EMPTY** AGAIN IN TASK 5.7, WHICH IS A RESULT RATHER THAN A GAP
    //
    // The Workshop's language group header was the one candidate: the
    // prototype's `wsLang` is **bilingual** — `eva/redesign.html:949` writes
    // `language · اللغة` and `اللغة · language` — so it would have been the
    // first member of this set that is *prose* rather than a brand mark or a
    // MessageFormat keyword.
    //
    // **It is not here, because the client renders each arm in its own
    // script.** The English-arm half of the bilingual contract is ABSOLUTE —
    // "the English arm holds no Arabic script at all" is a separate test with
    // no exemption list at all — and a bilingual value breaks it in both
    // directions at once. So `settingsWsLang` keeps the prototype's first half
    // on each arm (`language` and `اللغة`) and the pairing is a divergence
    // recorded in that key's own ARB description and at the group header.
    //
    // **THE SEVEN UNTRANSLATED SEGMENT LABELS ARE NOT HERE EITHER**, and that
    // is the point of them being widget literals: `dot`/`star`/`cross`/`gem`
    // and `crown`/`high`/`full` (`eva/redesign.html:673`, `:678`) carry no
    // `data-i18n` in the prototype and are kept as its own untranslated
    // English. Putting them in the ARB would have forced them into
    // `mustBeIdentical` — the set that catches an untranslated string — and
    // their correctness on the Arabic arm is asserted where they are painted:
    // `arabic_typography_test.dart`'s `/settings` group.
  };

  /// The keys whose two values are **identical**, and must stay identical.
  ///
  /// The successor to `auth_strings_test.dart`'s `shared` set. Every other key must
  /// differ, which is what catches an untranslated string. The login placeholders
  /// left this set in Phase 5.1: the redesign's placeholders are common nouns and
  /// the app localizes them (`authEmailHint` says why), so the two arms now
  /// legitimately differ.
  ///
  /// **One member, and it is a glyph and not a sentence.** `homeWordmark` died
  /// with the top bar in Phase 5.2 — the redesign's `/` has no wordmark at all
  /// (`eva/redesign.html:513-538` draws a caption, a greeting and a chip) — and
  /// `homeNoLightRef` took the slot: `redesign.html:1193` writes
  /// `el('lastRef').textContent = '—'` in **both** directions, because an em dash
  /// is a typographic "nothing" rather than a word any language has a translation
  /// of. That is the only legitimate identity left, and the set is now small
  /// enough to read as a claim instead of a list.
  const Set<String> mustBeIdentical = <String>{'homeNoLightRef'};

  /// Every row of the prototype's `I18N` table that this table does not carry
  /// **verbatim**, and where each one went.
  ///
  /// ## WHY THIS MAP IS **THE RECORD** AND NOT A NOTE
  ///
  /// `eva/redesign.html:924-977` is **128 rows** of the prototype's own table,
  /// and the group below measures this one against it: **103** rows are carried
  /// **verbatim**, and the other **25** are here. Every one of the 25 is a
  /// decision, and a decision nobody wrote down is a decision nobody can audit
  /// — which is what `docs/DRIFT.md` is a catalogue of.
  ///
  /// **AND THE MAP IS CHECKED, NOT TRUSTED.** The group below asserts that the
  /// keys of this map are **exactly** the prototype's rows this table does not
  /// carry verbatim — so a row that is ported properly makes this map stale
  /// and fails, and a row that is dropped from the prototype makes it fail the
  /// other way. And it asserts that every reason here carries the
  /// prototype's **own line**, so a row that moves in the file cannot leave a
  /// citation pointing at the wrong line: the defect
  /// `reading_l10n_test.dart` pins for the seven `/reading` rows, where every
  /// citation sat one line above the row it named and no gate could see it.
  ///
  /// ## THE THREE SHAPES, AND WHY THE SECOND ONE IS NOT THE THIRD
  ///
  /// * **carried** — the row's content is here under another name. The value
  ///   may differ (a dropped glyph, a split bilingual label, a reworded
  ///   sentence) and the reason says which.
  /// * **composedInDart** — the row is drawn and **no ARB row carries it**,
  ///   because what the row says is a count and the count is the domain
  ///   function's (`digits`). A key for it would be a key nobody reads.
  /// * **notDrawn** — the client does not draw the row. The reason names the
  ///   surface that does not exist, or the live source that replaced the
  ///   prototype's hard-coded number.
  ///
  /// ## AND WHY **NO** OF THEM IS A NEW KEY
  ///
  /// A row that the client does not draw gets **no key**, and that is a rule
  /// rather than an omission: "A key nobody reads is a key a translator will
  /// translate for a screen that does not exist" is the reason
  /// `settingsMotionOn` / `settingsMotionOff` were deleted and
  /// `sealFabLanguage` was never written. So the count above did not move, and
  /// this map is where the twenty-five went instead.
  const Map<String, _I18nOutcome> i18nRowsAccountedFor = <String, _I18nOutcome>{
    // ## THE HOME'S THREE, AND TWO OF THEM ARE **LIVE DATA**
    'votdRef': _I18nOutcome.notDrawn(
      'The prototype\'s reference is a hard-coded fiction: '
      '`redesign.html:927` writes `votdRef:["psalm 23:1","المزمور ٢٣:١"]` '
      'and `:991` writes it into the card. This client draws the '
      '**server\'s** reference instead — `TodayReading.reference` from '
      '`GET /readings/today`, painted by `verse_of_the_day_card.dart` — and '
      'ADR-0022\'s fiction table rates "Verse of the day :519" **real**. '
      'So the fiction is excluded and the live source is named. The only '
      'reference the table does carry is `homeNoLightRef`, the em dash for '
      'a card with no reading on it.',
    ),
    'libCount': _I18nOutcome.composedInDart(
      '`redesign.html:930` writes `libCount:["6 scrolls · 4 open","٦ دروج '
      '· ٤ مفتوحة"]` — one literal with both numbers baked in, and the '
      'prototype never even translates it (`:535` gives it an `id` and no '
      '`data-i18n`). The client has no such literal: the catalogue\'s '
      'length is `LibraryCatalogueRepository.books().length` and the open '
      'count is the cards\' `sealed` flags, so the row was **split into '
      'two ARB keys** (`homeScrolls`, `homeOpenBooks`) and **composed** by '
      '`HomeStringsPhrases.scrollsOpen` in `home_l10n.dart`, with the '
      'numerals from `digits`. A single key would have needed an ARB '
      'placeholder, and a non-plural Arabic value holding a Latin '
      'placeholder name fails this file\'s own Latin gate.',
    ),
    'medalsCount': _I18nOutcome.composedInDart(
      '`redesign.html:936` writes `medalsCount:["4 / 12","٤ / ١٢"]`, the '
      'medals label\'s count at `:597`. The count is the medals port\'s '
      '`earned` of `total` — ADR-0022\'s fiction table rates "Medals :597" '
      'a **stub** — and it is composed in Dart by `JourneyMedalsLabel` in '
      '`journey_section_labels.dart` as `digits(earned) / digits(total)`. '
      '**No ARB row carries it**, and that is stated in that widget\'s own '
      'doc: a count of two numbers and a slash has nothing translatable in '
      'it, and a key for it would be a key nobody reads.',
    ),
    // ## THE BOARD'S THREE, ALL **RENAMED** AND TWO OF THEM **REWORDED**
    'witness': _I18nOutcome.carried(
      '`redesign.html:942` writes `witness:["witness","شاهد"]`, used at '
      '`:1070` as the row\'s own word followed by the display position. The '
      'client carries it as '
      '`leaderboardWitness` — "witness {position}" — because a veiled '
      'witness is named by their **display position** and the numeral '
      'arrives through `digits`; the bare word alone would be a name with '
      'no position, and the position is what the board ranks.',
      <String>['leaderboardWitness'],
    ),
    'resets': _I18nOutcome.carried(
      '`redesign.html:946` writes `resets:["resets in","يُصفّر بعد"]`, '
      'composed at `:1082` with the two unit rows `dU` and `hU`. The client '
      'carries it as `leaderboardResetsIn` — "resets in '
      '≈{days}{dayUnit} {hours}{hourUnit}" — because the boundary is '
      '**local** (ADR-0022: the response carries no reset instant) and the '
      'count, the hours and the two units are all arguments, with the '
      'numerals from `digits`. The units are the prototype\'s own rows, as '
      '`leaderboardDayUnit` and `leaderboardHourUnit`.',
      <String>[
        'leaderboardResetsIn',
        'leaderboardDayUnit',
        'leaderboardHourUnit',
      ],
    ),
    'cheerSent': _I18nOutcome.carried(
      '`redesign.html:947` writes `cheerSent:["✦ cheer sent to {name}","✦ '
      'تحية مُرسلة إلى {name}"]`, raised at `:1122`. The client carries it '
      'as `leaderboardCheerSent` with the **leading ✦ dropped**: U+2726 is '
      'in no bundled family, so the star is painted beside the string '
      'rather than typed into it — the same correction '
      '`readingBookmarkOn` records. The `{name}` placeholder is the '
      'prototype\'s own, and the key is in this file\'s `latinIsCorrect` '
      'set with that reason.',
      <String>['leaderboardCheerSent'],
    ),
    // ## THE WORKSHOP\'S ONE, AND IT IS THE ONLY **BILINGUAL** ROW
    'wsLang': _I18nOutcome.carried(
      '`redesign.html:949` writes '
      '`wsLang:["language · اللغة","اللغة · language"]` — a **bilingual** '
      'label, each arm naming the thing in the reader\'s script and then in '
      'the other one. The client carries it as `settingsWsLang`, one script '
      'per arm ("language" and "اللغة"), because the English arm may hold '
      'no Arabic script and the Arabic arm may hold no Latin one — and the '
      'divergence is recorded in that key\'s own description and in this '
      'file\'s `latinIsCorrect` note.',
      <String>['settingsWsLang'],
    ),
    // ## THE RESULT CARD\'S THREE, AND **TWO** OF THEM ARE THE CLIENT\'S
    // ## OWN WORDS FOR THE SAME TWO SLOTS
    'complete': _I18nOutcome.notDrawn(
      '`redesign.html:963` writes `complete:["chapter complete","اكتمل '
      'الإصحاح"]`, the result card\'s eyebrow at `:720`. This client draws '
      '**no eyebrow** on its result card: the card is the redesign\'s '
      '`.rcard` (`:718-727`) with the eyebrow, the ring and the recap all '
      'replaced, and `result_sheet.dart` records the missing ring as the '
      'largest divergence on that surface. The completion claim itself is '
      '`resultCompleteMessage` — and the word "chapter" names a '
      'granularity this client does not have, because it completes a '
      '**reading**, never a chapter.',
    ),
    'again': _I18nOutcome.carried(
      '`redesign.html:963` writes `again:["read again","اقرأ مجددًا"]`, the '
      'result card\'s primary CTA at `:724`. The client carries that slot '
      'as `resultBackHome` — "Back home" — because this client has **no '
      'reading to return to**: §2\'s route table gives `/reading` no '
      'passage parameter, so it always renders *today\'s* reading and "read '
      'again" would name a destination the reader cannot be sent to. The '
      'mapping is by ACTION, and `result_sheet.dart` records it.',
      <String>['resultBackHome'],
    ),
    'retry': _I18nOutcome.carried(
      '`redesign.html:963` writes `retry:["retry quiz","أعد الاختبار"]`, the '
      'result card\'s ghost CTA at `:725`. The client carries that slot as '
      '`resultReflectAgain` — "Reflect again" — the same action (the quiz '
      'again) under the client\'s own wording, and the primary/secondary '
      '**emphasis is inverted** against the prototype\'s, which '
      '`result_sheet.dart` records as a deliberate divergence.',
      <String>['resultReflectAgain'],
    ),
    // ## THE READING SHEET\'S THREE, AND **ONE** OF THEM IS CUT BY THE PLAN
    'copy': _I18nOutcome.notDrawn(
      '`redesign.html:964` writes `copy:["copy verse","نسخ الآية"]`, the '
      'reading sheet\'s button at `:713`. This client has **no reading '
      'sheet**: the prototype\'s `.sheet` (`:711-716`) is a bottom sheet a '
      'verse opens, and the client\'s `/reading` has no such surface — a '
      'verse is tapped to light the breath guide, and `Clipboard` appears '
      'nowhere under `lib/`. A key with no call site is a key a translator '
      'would translate for a screen that does not exist.',
    ),
    'share': _I18nOutcome.notDrawn(
      '`redesign.html:964` writes `share:["share","مشاركة"]`, the reading '
      'sheet\'s second action at `:714`. **The plan cuts it**: the plan\'s '
      '"Decisions taken without asking" says "Share and notes are cut", '
      'because `share_plus` is forbidden by AGENT_CONTEXT §8.4, and '
      'ADR-0022\'s fiction table records "Share :714, notes :715" as '
      '**cut**. The journey\'s `journeyRowShare` is a different surface — '
      'the profile\'s row — and is not this row.',
    ),
    'note': _I18nOutcome.notDrawn(
      '`redesign.html:964` writes `note:["add note","إضافة ملاحظة"]`, the '
      'reading sheet\'s third action at `:715`. **The plan cuts it** — '
      '"Share and notes are cut" — because there is no storage layer for '
      'notes, and ADR-0022\'s fiction table records it as **cut**. A note '
      'would need an endpoint and a repository port this client does not '
      'have, and a storage layer it does not have either.',
    ),
    // ## THE QUIZ\'S TERMINAL CTA, WITH ITS **GLYPH** DROPPED
    'seeRes': _I18nOutcome.carried(
      '`redesign.html:967` writes `seeRes:["see results ✦","النتائج"]`, the '
      'quiz\'s terminal CTA at `:1431`. The client carries it as '
      '`quizSeeResults` — "see results" — with the **✦ dropped**: U+2726 is '
      'in no bundled family, so the star is a painted `FourPointedStar` '
      'composed by the CTA on the Latin arm and the Arabic arm carries '
      'none, which is the prototype\'s own pair. The description on that '
      'key records the measurement.',
      <String>['quizSeeResults'],
    ),
    // ## THE READER\'S TWO TOASTS, AND NEITHER HAS A SURFACE HERE
    'resumed': _I18nOutcome.notDrawn(
      '`redesign.html:969` writes `resumed:["resumed","استُؤنف"]`, raised '
      'as a toast at `:1381` when the reader returns to the verse they '
      'left. This client draws **no such notice**: the return is marked — '
      '`verse_line.dart`\'s `.resume` bar, `:168` — and the verse is scrolled '
      'to, and nothing is said about it. The nearest client string is '
      '`homeResumeHint`, which is the prototype\'s own `resumeHint` '
      '(`:928`) and a different sentence.',
    ),
    'constDone': _I18nOutcome.notDrawn(
      '`redesign.html:971` writes '
      '`constDone:["constellation complete","اكتمل البرج"]`, a toast at '
      '`:1184` fired when the last verse of a book is lit. This client has '
      '**no such event**: its sky is keyed `book:chapter:verse` and '
      'the journey\'s constellation count is a **proxy** — the distinct '
      'books among the completed scheduled days — so there is no moment at '
      'which a constellation completes and nothing to announce. ADR-0022\'s '
      'rule that no screen may render a hard-coded star is why the number '
      'is derived at all.',
    ),
    // ## THE SEALED SHEET\'S THREE, AND THE SHEET DOES NOT EXIST HERE
    'sealedBy': _I18nOutcome.notDrawn(
      '`redesign.html:972` writes '
      '`sealedBy:["finish {b} to unseal","أتمم {b} لفك الختم"]`, the '
      'sealed-book sheet\'s line at `:733`, filled at `:1044` with the '
      'book\'s name. This client has **no sealed-book sheet**: the '
      'library\'s sealed cards are inert — `library_carousel.dart` draws '
      'them as `Semantics(button: true, enabled: false)` with the '
      'unavailable reason appended, because `/reading` has no passage '
      'parameter and tapping "Isaiah" would open John. The unlock rule is '
      'ADR-0022\'s fiction — "the *unlock* rule … is invented" — and it '
      'has no surface to live on.',
    ),
    'go': _I18nOutcome.notDrawn(
      '`redesign.html:972` writes `go:["go to {b}","اذهب إلى {b}"]`, the '
      'sealed sheet\'s primary button at `:734`, filled at `:1045`. The '
      'same sheet as `sealedBy`: this client has none, and a "go to '
      '{book}" button would name a destination `/reading` cannot open, '
      'because it always renders *today\'s* reading. Had the row been '
      'carried, its `{b}` placeholder would have needed an entry in this '
      'file\'s `latinIsCorrect` set — a placeholder name is Latin, and a '
      'non-plural Arabic value holding one fails the gate below.',
    ),
    'later': _I18nOutcome.notDrawn(
      '`redesign.html:972` writes `later:["later","لاحقًا"]`, the sealed '
      'sheet\'s ghost button at `:735`. The same sheet as `sealedBy` and '
      '`go`: no sheet, so no button — and a "later" that dismisses a '
      'dialog this client never opens would be a button with no dialog '
      'behind it.',
    ),
    // ## THE RESULT\'S THREE MESSAGES, AND THE CLIENT\'S ARE ITS OWN
    'rmsg1': _I18nOutcome.carried(
      '`redesign.html:973` writes '
      '`rmsg1:["the light confirms it.","النور يؤكده."]`, the result '
      'card\'s message at `:722`, selected at `:1435` by `score===qEff`. '
      'The client carries the message line as `resultCompleteMessage`, one '
      'of the **three** arms of `ResultStringsPhrases.messageFor` — '
      'because the prototype\'s own selection needs the question count, '
      'which the submit response does not carry (AGENT_CONTEXT decision '
      '93), while the payload sends three states the client *can* name.',
      <String>['resultCompleteMessage'],
    ),
    'rmsg2': _I18nOutcome.carried(
      '`redesign.html:973` writes '
      '`rmsg2:["mostly light — a few shadows.","نور غالبًا — ظلال '
      'قليلة."]`, selected at `:1435` by `score>=qEff/2`. The client '
      'carries it as `resultPartialMessage` — "Correct. The reading is not '
      'finished yet." — because a **half-scored band** is not a state the '
      'payload can express: `SubmitResult` carries `is_correct` and '
      '`reading_completed`, and "right, and there is more to do" is the arm '
      'the payload does have.',
      <String>['resultPartialMessage'],
    ),
    'rmsg3': _I18nOutcome.carried(
      '`redesign.html:973` writes '
      '`rmsg3:["return, and read once more.","عُد، واقرأ مرة أخرى."]`, '
      'selected at `:1435` by the fall-through. The client carries it as '
      '`resultIncorrectMessage` — "Not this time. Every question counts." '
      '— because the prototype\'s consolation clause is keyed on a *score '
      'band* and the client has no band: the payload sends `is_correct` '
      'alone, and the sentence says so without inventing a score.',
      <String>['resultIncorrectMessage'],
    ),
    // ## THE TOASTS THAT NEED A TOAST, AND THE BOOKMARK\'S TWO STATES
    'copied': _I18nOutcome.notDrawn(
      '`redesign.html:974` writes `copied:["✓ copied","✓ تم النسخ"]`, a '
      'toast raised at `:1366` and `:1390` after a verse is copied to the '
      'clipboard. This client has **no clipboard** — `Clipboard` appears '
      'nowhere under `lib/` — and no reading sheet to copy from, so '
      'nothing is ever copied and there is nothing to confirm. The ✓ is a '
      'glyph in no bundled family besides, so it would have been painted '
      'rather than typed.',
    ),
    'bmk': _I18nOutcome.carried(
      '`redesign.html:974` writes `bmk:["✦ bookmarked","✦ تم الحفظ"]`, a '
      'toast raised at `:1394` when the bookmark is lit. The client '
      'carries the word as `readingBookmarkOn` and the off state as '
      '`readingBookmarkOff`, both with the **✦ dropped** (U+2726 is in no '
      'bundled family). **Neither key is read by a page today**, and that '
      'is a fact rather than an omission: the reading screen\'s bookmark '
      'is inert — it has no endpoint and no port — so the control\'s own '
      'name is `readingBookmark` and the toast is unreachable.',
      <String>['readingBookmarkOn', 'readingBookmarkOff'],
    ),
    'flameT': _I18nOutcome.notDrawn(
      '`redesign.html:975` writes '
      '`flameT:["the flame keeps you · 12 days","الشعلة تحفظك · ١٢ '
      'يومًا"]`, a toast raised at `:1322` when the streak chip is tapped. '
      'The row is **not drawn**, and the reason is the trigger rather than '
      'the toast: the client\'s streak chip is **not a control** — '
      '`streak_chip.dart` draws a pill with no tap handler and `home_page.dart` '
      'passes none — so there is no gesture to raise a notice from, whatever '
      'the notice is. The row also **bakes a digit**: the 12 is the '
      'prototype\'s own hard-coded streak (`:989`), while the client\'s is '
      '`StreakSummary.currentStreak`, a real count that would arrive '
      'through `digits` and never as a literal.',
    ),
  };

  group('the ARB pair, structurally', () {
    test('the walk finds the keys, so nothing below is vacuous', () {
      // The anti-vacuity half. A parser that returned an empty map would make every
      // "both arms" assertion a comparison over two empty sets — green, and about
      // nothing. The count is asserted exactly so a key silently dropped from the
      // file is a failure rather than a smaller green.
      expect(
        keysOf(en).length,
        186,
        reason:
            'the ARB is the whole bilingual surface. A different number means a key '
            'was added or removed — update this number and say why in the same '
            'commit, because the plural tests below are written against a named '
            'manifest and a silent drop would leave them passing.\n\n'
            '**182 → 186 in the servant portal\'s Task 1**, for the **role picker** '
            'on `/login`: four keys arrived (`authRoleLabel`, `authRoleKid`, '
            '`authRoleServant` and `authRoleAdmin`). **All four are WRITTEN, not '
            'transcribed** — `eva/redesign.html` draws no role picker, because '
            'there is no auth endpoint (AGENT_CONTEXT §2, decision 3) and so the '
            'role is a local choice the login screen has to offer. None of them '
            'is a prototype I18N row, so none of them appears in the map below — '
            'that map accounts for the prototype\'s 128 rows, and a row the '
            'prototype never had cannot be one of them.\n\n'
            '**182 → 182 in Phase 7 Steps 1–2 of the Lumen redesign**, for the '
            '**I18N table**: the count did not move, and the reason is that the '
            'table was already complete for everything this client draws. '
            'Measured by **English value** against the prototype\'s own `I18N` '
            'literal (`eva/redesign.html:924-977`, **128 rows**), **103** rows '
            'are carried **verbatim**, **13** are carried under **another name** '
            'or as a live composition, and **12** are **excluded** with a reason '
            'each.\n\n'
            '**AND THE MEASUREMENT IS A GATE, NOT A NOTE.** The group at the '
            'foot of this file parses the prototype\'s literal at test time and '
            'asserts that the declared map is **exactly** the rows this table '
            'does not carry verbatim — so a row that is ported properly makes '
            'the map stale and fails, and every reason in the map is checked '
            'against the line the row is **really** on, which is the defect '
            'the seven `/reading` citations below once carried.\n\n'
            '**AND NO ROW BECAME A KEY, because a row the client does not draw '
            'gets no key.** "A key nobody reads is a key a translator will '
            'translate for a screen that does not exist" is why '
            '`settingsMotionOn` / `settingsMotionOff` were deleted and why '
            'there is no `sealFabLanguage`; the twenty-five are recorded by name '
            'instead. Two of them carry a **live** number — `votdRef` is the '
            'server\'s reference and `medalsCount` is the medals port\'s '
            '`earned` of `total` — and the rest are surfaces the client does '
            'not draw.\n\n'
            '**179 → 182 in Phase 7 of the Lumen redesign**, for the **ritual**: '
            '**three** keys arrived (`homeSelahBegin`, `homeSelahEnd` and '
            '`homeSelahAmen`). The last is the prototype\'s own I18N row '
            '(`redesign.html:970`\'s `amen`), and the first two are **written** — '
            'the prototype\'s selah button carries `title="selah"` '
            '(`redesign.html:533`), which names the thing rather than the action, '
            'and this client names the action because the control starts and '
            'stops a silence and a name that never changes would tell a '
            'screen-reader user to "begin" a silence that is already running.\n\n'
            '**178 → 179 in Phase 6 of the Lumen redesign**, for the **dock**: '
            '**five** keys arrived (`dockHome`, `dockRead`, `dockToday`, `dockBoard` '
            'and `dockJourney` — the redesign\'s own i18n rows, `:931-932`) and '
            '**four** died (`sealFabOpen`, `sealFabClose`, `sealFabSettings` and '
            '`sealFabLeaderboard` — the `SealFab`\'s own, and the dial is gone).\n\n'
            '**`sealFabLeaderboard` BECAME `dockBoard` rather than being replaced '
            'by a new key**, and the value did not change: it was already '
            '"Communion" / "الشركة" — the redesign\'s own word, and its '
            'description already cited `redesign.html:932`\'s `dockBoard` row. '
            'The key was renamed to the name of the thing it now labels, which '
            'is the same string with a different owner.\n\n'
            '**147 → 180 → 178 in Task 5.7**, for the Workshop: **forty-two** new '
            'keys and **eleven** dead ones. The dead nine are the Phase-9 keys whose '
            'strings the redesign does not draw — the Appearance and Reading group '
            'labels, the three theme segments, the "Font size" row title, the '
            '"Default language" row title and the language sheet\'s heading — and the '
            'two more are the reduce-motion switch\'s position names, which the '
            'Workshop\'s row-title naming made unread the same day they arrived.\n\n'
            '**146 → 147 in the Task 5.6 review pass**, for the journey\'s **own** '
            'retry key. The screen was borrowing `leaderboardRetry`, and the '
            'repository namespaces `retry` per screen on purpose — '
            '`homeRetry`, `quizRetry`, `readingRetry`, `settingsRetry` and '
            '`leaderboardRetry` are five separate keys with the same value. A '
            'sixth screen taking another screen\'s copy is the coupling the rule '
            'exists to remove, and the review caught it on the first read of the '
            'page.\n\n'
            '**126 → 146 in Task 5.6**, for the new `/journey` screen (the profile '
            'ADR-0022 restored, which the redesign calls "Journey" — '
            '`eva/redesign.html:933`): **twenty** keys, and every one of them is a '
            'transcription of a prototype i18n row with its citation in the ARB '
            'description. The screen\'s own (`journeyTitle`, `journeyScribe`, '
            '`journeyStreakSub`), the three ring labels (`journeyRingVerses`, '
            '`journeyRingQuizzes`, `journeyRingAccuracy`), the sky line\'s three '
            '(`journeySky`, `journeyStarsLit`, `journeyConstellations`), the two '
            'section labels (`journeyMedals`, `journeyAccount`), the four medal '
            'names (`journeyMedalFirstLight`, `journeyMedalPsalmist`, '
            '`journeyMedalStreakSeven`, `journeyMedalJohn`), the four account rows '
            '(`journeyRowBoard`, `journeyRowSettings`, `journeyRowShare`, '
            '`journeyRowPlans`), and the fifth `*UnavailableSuffix` key.\n\n'
            '**The medals\' names are copy and live here, and the medals\' '
            '*existence* is the fiction** — which is ADR-0022\'s rule and the '
            '`LibraryBook` entity\'s: a translated string does not arrive as data, '
            'so the enum holds the identity and the ARB holds the label.\n\n'
            '**126 → 146 is the second movement in two tasks, and the first was '
            'also a fix**: `journeyUnavailableSuffix` is the fifth member of the '
            '`*UnavailableSuffix` family, and it reads like the three that say the '
            'same thing because the reason is the same — the feature is not built '
            'in this client. `quizUnavailableSuffix` still reads differently, '
            'because its control is dead for a different reason.\n\n'
            '**121 → 126 in the Task 5.5 review pass**, and every one of the five '
            'is a name rather than a sentence: `leaderboardRetry` (the board has '
            'its own retry key, because `homeRetry` / `quizRetry` / `readingRetry` / '
            '`settingsRetry` are four separate keys with the same value and a fifth '
            'screen borrowing the fourth\'s is the coupling to remove), '
            '`leaderboardScopeLabel` and `leaderboardMetricLabel` (the two '
            'segmented controls\' **accessible names** — a control\'s own name, '
            'never one of its own options, which is the collision '
            '`SegmentedControl`\'s doc names), and `leaderboardDayUnit` / '
            '`leaderboardHourUnit` (the prototype\'s own `dU` / `hU` rows, '
            '`eva/redesign.html:946`, so the units are ARB values and not a '
            '`languageCode == \'ar\'` fork in the widget).\n\n'
            '**And the Arabic plural arms changed**, which is not a movement but a '
            '**fix**: `leaderboardRowSemantics`\'s Arabic `few` / `many` / `other` '
            'arms never interpolated `{digits}`, so the Arabic arm announced '
            '"نقاط" — "points" — with no number in it. The English arm has always '
            'interpolated it. A screen-reader user on the Arabic arm was told a '
            'witness had points and not how many.\n\n'
            '**114 → 121 in Task 5.5**, for the rebuilt `/communion` (the cohort\'s '
            'board, `eva/redesign.html:612-636`): three keys were deleted with the '
            'old layout (`leaderboardScoreLabel`, `leaderboardOpenFull`, `leaderboardYourRank`), '
            'and ten arrived as the redesign\'s own table rows and vocabulary — '
            '`leaderboardMetricLight` / `leaderboardMetricStreaks` (`:941`), '
            '`leaderboardWitness` / `leaderboardYou` (`:942`), `leaderboardGapLine` (`:943`), '
            '`leaderboardPassHint` (`:944`), `leaderboardNoReset` (`:945`), '
            '`leaderboardResetsIn` (`:946`), `leaderboardCheerSent` (`:947`), and '
            '`leaderboardVeil` (`:948`). None is a plural.\n\n'
            '**111 → 116 in Task 5.3**, for the rebuilt `/reading` surface against '
            '`eva/redesign.html:540-560`: seven keys arrived as the redesign\'s own '
            'I18N rows — `readingVerses` / `readingQuiz` / `readingQuestions` '
            '(`:966`), `readingListen` (`:965`), `readingSky` (`:968`) and '
            '`readingBookmarkOn` / `readingBookmarkOff` (`:974`) — and **two were '
            'removed, and one of the two is why this sentence names them '
            'individually.**\n\n'
            '`readingCaptionFor` was the ARB\'s `/reading` plural, and with it gone '
            '**this table has two plural keys where it had three**. '
            '`reading_l10n.dart`\'s class doc carries the argument in full: '
            '`eva/redesign.html:1347` composes the CTA caption as '
            '`quiz · N questions` out of `tr(\'quiz\')`, `N()` and `tr(\'questions\')` '
            '— one word for every count, from a table whose `questions` row carries '
            'no ICU forms at all. Adopting the prototype\'s caption adopts its '
            'table, and the Arabic **dual** (`٢ سؤالان`) the plural used to render '
            'is a recorded loss. That is why the manifest below names two keys and '
            'why this count is stated as a movement rather than a number: a reader '
            'who finds two plurals where this file once described three needs the '
            'argument, not the diff.\n\n'
            '`readingBeginReflection` went the other way — the redesign\'s sticky CTA '
            'is a caption and a chevron, not a verb phrase, and nothing replaced it '
            'because `StickyCta` composes from `readingQuiz` / `readingQuestions`. '
            'Its two citation rows were removed from the map below in the same '
            'change, which is what keeps that map a claim rather than a wish.\n\n'
            '**107 → 111 for `SealFab`**, the four keys decision 155 brought back: the '
            'trigger\'s two names (`sealFabOpen` / `sealFabClose`, which differ because '
            'a button that toggles must say which way it will go — the defect '
            '`SegmentedControl`\'s track had) and two destination labels. None is a '
            'plural and none holds a placeholder, so both ICU groups below are '
            'untouched — which is why this suite went red on exactly one number and on '
            'nothing else.\n\n'
            '**There is no `sealFabLanguage` key, and that is a decision.** The dial\'s '
            'third destination would be Language, but `showLanguageSheet` lives in '
            '`features/settings/` and Gate 2 forbids one feature importing another, so a '
            '`sealFabLanguage` getter with no call site would be a string in the '
            'bilingual surface that no reader can reach. The deleted '
            '`seal_fab_test.dart` asserted Language is absent from the dial for the '
            'same reason.\n\n'
            '`sealFabLeaderboard` occupies the prototype\'s `Profile` slot: Profile is a '
            'cut screen with no endpoint, and a dial offering a dead route is why the '
            'component was cut. The deleted `seal_fab_test.dart` asserted Profile is '
            'absent so it could not creep back.\n\n'
            '**111 → 102 in Phase 5.1**, for the redesigned login — '
            '`eva/redesign.html:503-511`: twelve keys died with the screen\'s '
            'dropped elements (the seal, the sign-in label it replaced, forgot/'
            'sign-up/divider, the two full-width social labels, the show/hide '
            'toggle pair) and three arrived as the redesign\'s own translated '
            'trio — `authEnterTheWord`, `authEmailInvalid`, `authPasswordTooShort` '
            '(`:508`, `:976`). The wordmark and the tagline left the table for '
            'widget literals: the redesign renders them untranslated in both '
            'directions, and `arabic_typography_test.dart` now asserts that '
            'instead of this table.\n\n'
            '**102 → 111 in Phase 5.2**, for the redesigned home — '
            '`eva/redesign.html:513-538`, and ADR-0022 above it: twelve keys died '
            'with the elements the redesign removed (the wordmark, the avatar\'s '
            'label, the two streak sentences, today\'s-reading panel and its '
            'progress lines, the continue/start-reflection pair, the no-questions '
            'line, and the board card\'s title, whose screen now owns its copy) and '
            'twenty-one arrived as the redesign\'s own table rows — the four greeting '
            'words (`:926`), the two card eyebrows and the empty last-light\'s body '
            '(`:927-929`), the resume hint (`:928`), the em-dash reference '
            '(`:1193`), the carousel\'s label, its two count units and the four '
            'category labels (`:930`, `:1036`), the sealed badge (`:972`), the '
            'selah title and its seconds unit (`:966`, `:970`), the streak\'s label '
            'prefix and its day unit (`:925`), the verses unit (`:966`), and '
            '`homePeace` (`:993`). None is a plural and none holds a placeholder — '
            'the composed sentences are deliberately Dart, and '
            '`home_l10n_test.dart` asserts the shape this refusal protects.\n\n'
            '**116 → 114 in Task 5.4**, for the rebuilt `/quiz` — '
            '`eva/redesign.html:562-574`: three keys died with the old chrome — '
            '`quizOfWord` and the two verdict sentences (`quizVerdictCorrect` / '
            '`quizVerdictIncorrect`), whose banner the redesign does not draw — and '
            'one arrived as the crumb\'s own prefix, `quizRefraction` (`:565`). The '
            'verdict vocabulary that replaced the sentences (`quizCorrectSuffix` / '
            '`quizIncorrectSuffix`) already existed for the accessible name, so this '
            'is a surface leaving the table rather than a translation going missing. '
            'None of the four is a plural and none holds a placeholder, which is why '
            'both ICU groups below are untouched.\n\n'
            '**The numerals are not in these values.** `libCount`\'s `٦` is the '
            'prototype\'s Arabic arm *rendering*, and this client draws numerals '
            'through `digits` (`l10n.dart:105`) — so a value holding a digit is a '
            'hard-coded count, which the bare-number scan in '
            '`home_l10n_test.dart` refuses.',
      );
      expect(keysOf(ar), isNotEmpty);
    });

    test('both arms carry exactly the same keys', () {
      // Belt and braces over what `gen_l10n` already enforces, because the build
      // enforces it for *codegen* and this asserts it for the *files on disk*. The
      // mutation report deletes a key from `app_ar.arb` and shows the build failing;
      // this is the same claim from the other side, and it is the one that survives
      // a stale generated file.
      expect(keysOf(ar).difference(keysOf(en)), isEmpty);
      expect(keysOf(en).difference(keysOf(ar)), isEmpty);
    });

    test('no value is empty on either arm', () {
      for (final String key in keysOf(en)) {
        expect(
          (en[key]! as String).trim(),
          isNotEmpty,
          reason: 'en.$key is blank, which renders as nothing on screen',
        );
        expect(
          (ar[key]! as String).trim(),
          isNotEmpty,
          reason: 'ar.$key is blank, which renders as nothing on screen',
        );
      }
    });
  });

  group('every key carries the reasoning, and the citations with it', () {
    test('every message has an `@key` block with a description', () {
      // **This is the gate that makes the migration auditable.** The five tables
      // carried, per string, the prototype's `file:line` where one existed, the
      // reason it was written where none did, and the alternatives that were
      // rejected. None of that survives a codegen step by itself — `gen_l10n` throws
      // the descriptions away after using them for tooling.
      //
      // So the descriptions are not documentation, they are **the record**, and this
      // asserts they are still there and still say something. A key added without
      // one fails here rather than shipping a sentence whose origin nobody can state.
      final List<String> undescribed = <String>[
        for (final String key in keysOf(en))
          if (en['@$key'] is! Map ||
              (en['@$key']! as Map)['description'] == null ||
              ((en['@$key']! as Map)['description']! as String).trim().length <
                  40)
            key,
      ];
      expect(
        undescribed,
        isEmpty,
        reason:
            'these keys have no usable `@key` description. Every string needs the '
            'prototype `file:line` it was transcribed from, or the reason it was '
            'written, and the alternative that was rejected. The 40-character floor '
            'is not a style rule — it rejects `@key: {}` and a one-word stub.',
      );
    });

    test('and every `settings*` key says whether it was TRANSCRIBED or WRITTEN', () {
      // Phase 9's addition to the rule above, and it is a rule rather than 21
      // citations.
      //
      // §2.1 decision 8b's whole argument for ARB is that the description is "the
      // record" — the prototype's `file:line` where one existed, and the reason it was
      // written where none did. Four of `/settings`' 21 keys have **no** prototype
      // line at all, because the prototype drew no accessible name for its range
      // input, no sheet for its language pills, no motion row at all, and no slider
      // label. A reader auditing those four needs to be able to see that they are
      // invented rather than transcribed, and "there is no citation in this
      // description" does not distinguish *written on purpose* from *citation lost in
      // a refactor*.
      //
      // So the split is asserted as data: every `settings*` description must contain
      // exactly one of the two markers, and the `WRITTEN` ones must name the prototype
      // line they are working around.
      const Map<String, String> written = <String, String>{
        // ## THE SIX WRITTEN KEYS, AND EACH ONE NAMES WHAT THE PROTOTYPE LACKED
        //
        // **Three of them are the stepper's own three strings**, and they are
        // written because the redesign's Type-size row is a range input with no
        // accessible name: `eva/redesign.html:693` draws
        // `<input type="range" min="16" max="26" value="20">` and names it
        // nowhere. §14's first row applied to a control the row does not name.
        'settingsFontScale': 'eva/redesign.html:693',
        'settingsDecreaseFontSize': 'eva/redesign.html:693',
        'settingsIncreaseFontSize': 'eva/redesign.html:693',
        // **One of them is the language segment's name.** The redesign's
        // segment (`:646-648`) has no name of its own, and the group header
        // above it is a *bilingual* label that would read as
        // `language · language` aloud.
        //
        // **And two of them are the failure notice's two strings**, which have
        // no prototype line at all because the redesign draws no failure state.
        //
        // **AND TWO MORE WERE WRITTEN AND THEN REMOVED IN THE SAME TASK.** The
        // reduce-motion switch's position names (`settingsMotionOn` /
        // `settingsMotionOff`) were written for the same reason — the redesign
        // draws a bare checkbox (`:687`) with no position words — and then
        // **deleted**, because the Workshop names every switch by its **row
        // title** in both arms: the control's own name, with
        // `Semantics(toggled:)` carrying the state. A position name that
        // changed with the switch would have named the control by something
        // other than what it is. `EvaToggle`'s `EvaToggleLabels` is still
        // required, so the screen passes the row title in both arms, and those
        // two keys are read by nothing. **A key nobody reads is a key a
        // translator will translate for a screen that does not exist.**
        'settingsLanguageLabel': 'eva/redesign.html:646-648',
        'settingsPreferencesUnavailable': 'no failure state',
        'settingsRetry': 'no failure state',
      };
      final List<String> keys = keysOf(
        en,
      ).where((String key) => key.startsWith('settings')).toList()..sort();

      expect(
        keys,
        hasLength(54),
        reason:
            'the /settings ARB surface. This is a declared count so that a dropped '
            'key is a failure rather than a smaller green, exactly as the file-level '
            'count is above. **23 → 56 → 54 in Task 5.7**, for the Workshop: the '
            'redesign\'s seven groups, twenty-nine controls, one action row, one '
            'preview and two about rows. Nine Phase-9 keys died with the controls '
            'they named (the Appearance and Reading group labels, the three theme '
            'segments, the "Font size" row title, the "Default language" row title '
            'and the language sheet\'s heading), forty-two new ones arrived, and '
            '**two of the new ones died the same day** — the reduce-motion switch\'s '
            'position names, which the Workshop\'s row-title naming made unread.',
      );

      final List<String> unmarked = <String>[];
      final List<String> misfiled = <String>[];
      for (final String key in keys) {
        final String description =
            (en['@$key']! as Map)['description']! as String;
        // **A substring, not one fixed phrase**, because one key legitimately claims
        // BOTH: `settingsLanguageEnglish` is transcribed in kind for the English arm
        // and written for the Arabic one, in the same breath. A fixed phrase would
        // have forced one of those two facts out of the description, which is the
        // thing the assertion exists to keep.
        final bool saysWritten = description.contains('Written');
        final bool saysTranscribed = description.contains('Transcribed');
        if (!saysWritten && !saysTranscribed) {
          unmarked.add(key);
          continue;
        }
        if (written.containsKey(key) && !saysWritten) {
          misfiled.add(
            '$key is declared written here but its description transcribes',
          );
        }
        if (!written.containsKey(key) && saysWritten) {
          misfiled.add(
            '$key says it was written but the written set here does not list it — '
            'either it was transcribed after all or the set is stale',
          );
        }
        if (written.containsKey(key)) {
          expect(
            description,
            contains(written[key]),
            reason:
                '$key is declared written here, and the note must say what the '
                'prototype lacked. "${written[key]}"',
          );
        }
      }
      expect(
        unmarked,
        isEmpty,
        reason:
            'these `settings*` descriptions say neither "Transcribed" nor "Written, '
            'not transcribed", so a reader cannot tell which it was',
      );
      expect(misfiled, isEmpty);
    });

    test('and the descriptions still name the prototype where one existed', () {
      // The citations are the asset this migration was supposed to preserve, so the
      // preservation is asserted rather than asserted-by-review. These are the keys
      // whose ARB descriptions carry a `file:line`; if one loses it, this fails.
      const Map<String, String> citations = <String, String>{
        // Phase 5.1's redesigned login. The redesign's own i18n trio cites
        // `redesign.html`, as does everything else the screen transcribed.
        'authEmailLabel': 'redesign.html:506',
        'authEmailHint': 'redesign.html:506',
        'authPasswordLabel': 'redesign.html:507',
        'authPasswordHint': 'redesign.html:507',
        'authEnterTheWord': 'redesign.html:508',
        'authEmailInvalid': 'redesign.html:976',
        'authPasswordTooShort': 'redesign.html:976',
        // Phase 5.2's redesigned home. **Every key the redesign introduced carries
        // a `redesign.html` line**, and the six that have none are the ones the
        // fiction invented — the streak prefix (`homeStreakLabel`, whose words the
        // prototype renders but never as an accessible name), the four category
        // labels' *grammar* (`homeCategoryHistory` and `homeCategoryApocalypse`
        // are `CATS` rows, so they cite `:1036`), `homeGreetingSeparator` and
        // `homeDays`, whose prototype values are baked into literals rather than
        // rows. Each of those says so in its description instead of a line.
        'homePeace': 'redesign.html:993',
        'homeGreetingMorning': 'redesign.html:926',
        'homeGreetingAfternoon': 'redesign.html:926',
        'homeGreetingEvening': 'redesign.html:926',
        'homeGreetingVigil': 'redesign.html:926',
        'homeVerseOfTheDay': 'redesign.html:927',
        'homeLastLight': 'redesign.html:928',
        'homeResumeHint': 'redesign.html:928',
        'homeNoLight': 'redesign.html:929',
        'homeNoLightRef': 'redesign.html:1193',
        'homeTheLibrary': 'redesign.html:930',
        'homeScrolls': 'redesign.html:930',
        'homeOpenBooks': 'redesign.html:930',
        'homeCategoryPoetry': 'redesign.html:1036',
        'homeCategoryGospel': 'redesign.html:1036',
        'homeCategoryTorah': 'redesign.html:1036',
        'homeCategoryProphets': 'redesign.html:1036',
        'homeCategoryHistory': 'redesign.html:1036',
        'homeCategoryApocalypse': 'redesign.html:1036',
        'homeSelah': 'redesign.html:970',
        'homeSecondsOfSilence': 'redesign.html:970',
        // Phase 7's ritual. The amen is the prototype's own I18N row (`:970`);
        // the two button names are **written**, and their descriptions say so
        // while still naming the prototype line they work around (`:533`).
        'homeSelahAmen': 'redesign.html:970',
        'homeSelahBegin': 'redesign.html:533',
        'homeSelahEnd': 'redesign.html:533',
        'homeSealed': 'redesign.html:972',
        'homeVerses': 'redesign.html:966',
        'homeDays': 'redesign.html:925',
        // Phase 9, `/settings`. The full citation list, one per transcribed key.
        // ## TASK 5.7's WORKSHOP — **FORTY-EIGHT ROWS, EVERY ONE A `redesign.html`
        // ## LINE**, and the count is the point
        //
        // The redesign's `#rSettings` is `eva/redesign.html:638-700` and its
        // `I18N` table is `:924-977`. Every row below is a line the client
        // painted from, and each one is the **markup** line rather than the
        // `I18N` line — the markup is what a reader sees, and the two disagree
        // in two places (`Brightness` is `glow` in the table at `:953` and
        // `Brightness` in the markup at `:659`; `about` is `wsAbout` in the
        // table at `:949` and the markup at `:696`).
        //
        // **The nine Phase-9 entries that died** are gone rather than
        // re-pointed, because the strings they named are gone: the Appearance
        // and Reading group labels, the three theme segments, the "Font size"
        // row title, the "Default language" row title and the language sheet's
        // heading. The redesign draws none of them.
        'settingsTitle': 'redesign.html:641',
        'settingsBack': 'redesign.html:640',
        'settingsWsLang': 'redesign.html:645',
        'settingsThemeGroup': 'redesign.html:649',
        'settingsDaylight': 'redesign.html:650',
        'settingsWsLight': 'redesign.html:651',
        'settingsShaderEngine': 'redesign.html:652',
        'settingsCurtainShape': 'redesign.html:653',
        'settingsCurtainTop': 'redesign.html:655',
        'settingsCurtainBottom': 'redesign.html:655',
        'settingsCurtainSides': 'redesign.html:655',
        'settingsCurtainShafts': 'redesign.html:655',
        'settingsReach': 'redesign.html:658',
        'settingsBrightness': 'redesign.html:659',
        'settingsTouchGlow': 'redesign.html:660',
        'settingsHue': 'redesign.html:661',
        'settingsMultichromeMelt': 'redesign.html:662',
        'settingsRayCombing': 'redesign.html:663',
        'settingsWhiteCores': 'redesign.html:664',
        'settingsDotVeil': 'redesign.html:665',
        'settingsSkyGroup': 'redesign.html:666',
        'settingsStars': 'redesign.html:667',
        'settingsConstellations': 'redesign.html:668',
        'settingsStarCount': 'redesign.html:669',
        'settingsStarBrightness': 'redesign.html:670',
        'settingsStarShape': 'redesign.html:671',
        'settingsStarField': 'redesign.html:676',
        'settingsTwinkle': 'redesign.html:681',
        'settingsRitualGroup': 'redesign.html:682',
        'settingsFocusDelay': 'redesign.html:683',
        'settingsSelahLength': 'redesign.html:684',
        'settingsBreathGuide': 'redesign.html:685',
        'settingsVespersAutoDim': 'redesign.html:686',
        'settingsReduceMotion': 'redesign.html:687',
        'settingsCalmMotion': 'redesign.html:688',
        'settingsHaptics': 'redesign.html:689',
        'settingsCommunionGroup': 'redesign.html:690',
        'settingsVeilWitnesses': 'redesign.html:691',
        'settingsShowPodium': 'redesign.html:692',
        'settingsTypeSize': 'redesign.html:693',
        'settingsRestoreDefaults': 'redesign.html:695',
        'settingsRestored': 'redesign.html:975',
        'settingsAbout': 'redesign.html:696',
        'settingsShaders': 'redesign.html:697',
        'settingsTokens': 'redesign.html:698',
        'settingsVersion': 'redesign.html:642',
        'settingsLanguageEnglish': 'redesign.html:647',
        'settingsLanguageArabic': 'redesign.html:647',
        // ## THE THREE THAT NAMED THE **RETIRED** REACT PROTOTYPE
        //
        // The React prototype is gone, and a description that cited a line of a
        // file that no longer exists is a reference a reader cannot follow. The
        // provenance is still recorded — the value, and what the redesign does
        // instead — and the marker these three rows now assert is the
        // **surviving** design source each description names.
        'quizCheckAnswer': 'redesign.html:1423',
        // **`quizNextQuestion` left this map in Task 5.4, and the departure is the
        // claim.** Its value is no longer the superseded prototype's
        // `{checked ? 'Next question' : …}`; it is the redesign's own
        // `next:["next ▸","التالي"]` row (`redesign.html:967`), and the description
        // cites that row instead. Keeping the old citation would say the value was
        // transcribed from a line that no longer produced it.
        // Task 5.3's rebuilt `/reading`. **Seven rows, and every value here is the
        // prototype's own I18N pair** — `verses` / `quiz` / `questions` share one
        // line, `bmk` / `bmkOff` share another.
        //
        // ## TWO FORMAT FACTS ABOUT THESE SEVEN, BOTH MEASURED
        //
        // * **The values are BARE `:NNN`, not `redesign.html:NNN`.** Every other
        //   entry above spells the file, because every other description leads with
        //   "Transcribed: `redesign.html:966` — …". These seven lead with the bare
        //   line instead, so a map entry written in the house format would assert a
        //   substring no description carries and the row would fail on a difference
        //   of punctuation. The assertion is a `contains`, so the map has to hold
        //   what the ARB says — and a reader is better served by an exact
        //   substring than by a reconstructed `file:line`.
        // * **They are each ONE LINE ABOVE where the row actually is.** The
        //   descriptions cite `:967`, `:966`, `:969` and `:975`; measured in
        //   `eva/redesign.html` the rows are at `:966`, `:965`, `:968` and `:974`.
        //   All seven, all off by exactly one — the signature of a transcription
        //   taken against a file with one line fewer above the literal.
        //   `tool/gates/citation_check.py` cannot see this: it checks that a cited
        //   line exists and is in range, and one line too high satisfies both. The
        //   discrepancy is **pinned by a test** rather than left as prose, in
        //   `test/features/reading/presentation/reading_l10n_test.dart`'s
        //   `the seven ARB citations are each ONE LINE ABOVE the row they name`
        //   row, which fails the day either side moves. **The fix belongs in these
        //   two ARB files** and was not made here, because this slice does not own
        //   them; if it is made, that row and these seven values change together.
        //
        // ## TWO MORE STALE CLAIMS IN THIS MAP, MEASURED IN THE SAME PASS
        //
        // Sweeping every `redesign.html:NNN` in the pair and comparing it against
        // the line the description's own quoted literal is really on found these
        // two, and both are recorded rather than fixed for the same reason:
        //
        // * `'homeSecondsOfSilence': 'redesign.html:970'` — the row it quotes,
        //   `secs:["seconds of silence","ثانية من الصمت"]`, is at **`:970`**.
        //   Every other `home*` I18N row in this map is exact (`homeVerses` 966,
        //   `homeSelah` 970, `homeSealed` 972), so this is one row and not a
        //   systematic offset.
        // * `@authEnterTheWord`'s **secondary** citation — `redesign.html:954` for
        //   the `enter` I18N row — is at **`:965`**. The map's own row for that key
        //   (`:508`, the `<button data-i18n="enter">`) is correct.
        //
        // Neither can be repaired from this file: the map asserts a substring the
        // description carries, so correcting the map without correcting the ARB
        // would turn a stale claim into a **failing** one, and the ARB is not this
        // slice's to edit. A fix has to change the description and the map value in
        // the same commit — which is the shape `citation_check.py` cannot enforce
        // and this comment is here to make findable.
        //
        // **And that is exactly what happened**: the seven rows were one line too
        // high (measured, and pinned by `reading_l10n_test.dart`'s own row), the
        // ARB descriptions were corrected, and this map moved with them in the
        // same change.
        'readingVerses': ':966',
        'readingQuiz': ':966',
        'readingQuestions': ':966',
        'readingListen': ':965',
        'readingSky': ':968',
        'readingBookmarkOn': ':974',
        'readingBookmarkOff': ':974',
        'resultReflectAgain': 'redesign.html:963',
        'resultLongestYet': 'redesign.html:516',
      };
      for (final MapEntry<String, String> entry in citations.entries) {
        expect(
          ((en['@${entry.key}']! as Map)['description']! as String),
          contains(entry.value),
          reason:
              'the `${entry.key}` description lost its prototype citation '
              '`${entry.value}`. Losing a citation is a real loss: it is the only '
              'record that a string was TRANSCRIBED rather than invented, and the '
              'next reader cannot recover it.',
        );
      }
    });
  });

  group('no English left in the Arabic arm, and no Arabic in the English one', () {
    test('no Arabic-arm value holds Latin script outside the documented set', () {
      // `home_strings_test.dart`'s rule, widened from one table to all five. This is
      // the property the whole bilingual surface exists to keep, and it is the one a
      // hand-typed ARB entry gets wrong most easily.
      //
      // ## THE `plural` KEYS ARE **TEMPLATES**, NOT SENTENCES
      //
      // `resultTotalCaption` and `leaderboardRowSemantics` are the only keys whose
      // Arabic value legitimately contains Latin characters, and **none of it
      // reaches a reader**: an ICU message is `zero{…} one{…} few{…}` plus
      // placeholder names — `count`, `digits`, `initials`, `rank`, `isReader` — all
      // of which are ASCII keywords of the MessageFormat grammar rather than prose.
      // `gen_l10n` discards them at compile time and emits
      // `intl.Intl.pluralLogic(…)` carrying Arabic literals.
      //
      // So they are exempted by **being plurals** — read off the `plural` manifest,
      // not a hand-kept name list. And the exemption is not a loophole: the
      // per-class tests in the plural group assert every rendered form against a
      // literal, which is the only place a Latin character could reach a screen.
      //
      // ## AND THIS IS WHY THE SEVEN NEW `/reading` ROWS ARE NOT EXEMPTED
      //
      // They are whole literals with **no** ICU syntax, so nothing to exempt and
      // nothing to reach a screen: `تم الحفظ` and `أُزيل الحفظ` and `أسئلة` are
      // real Arabic in the ordinary way. The counts that go beside them are Dart
      // arguments (`quizCaption`, `crumbMeta`), which is precisely what keeps them
      // out of this gate's reach — and a placeholder `{verses}` would have put a
      // Latin word into an Arabic value and failed here on its own. **A key's
      // exemption is a decision, so a new one has to be argued into
      // `latinIsCorrect` in a diff rather than joining a list by accident.**
      final Set<String> plurals = _pluralKeys(en);
      final List<String> latin = <String>[
        for (final String key in keysOf(ar))
          if (RegExp('[A-Za-z]').hasMatch(ar[key]! as String) &&
              !latinIsCorrect.contains(key) &&
              !plurals.contains(key))
            key,
      ];
      expect(
        latin,
        isEmpty,
        reason:
            'Latin script in an Arabic string is the same defect as Arabic in Space '
            'Mono, one layer up. If this one is genuinely correct, add it to '
            '`latinIsCorrect` WITH a reason — the set is the exception list, and '
            'growing it is a decision rather than a convenience.',
      );
    });

    test('and the Arabic arm has real Arabic script, not transliteration', () {
      // The other half, and not redundant: a table that replaced Arabic with
      // transliterated Latin passes "no English left" and fails this.
      // **Task 5.3 added the seven `/reading` rows and four of them are here.**
      // The list is a *sample* with a purpose: it is the half of the bilingual
      // contract the one-armed Latin check cannot see, and a table that replaced
      // Arabic with transliterated Latin passes "no English left" and fails this.
      // `readingBookmarkOn` / `readingBookmarkOff` are the sharpest additions,
      // because they are the two strings a reader reads *most* often after a tap
      // and both are short — a transliteration would be short too, and nothing
      // else about them would give it away.
      for (final String key in <String>[
        'authEnterTheWord',
        'authEmailInvalid',
        'authPasswordTooShort',
        'homeGreetingMorning',
        'homeGreetingVigil',
        'homeVerseOfTheDay',
        'homeLastLight',
        'homeNoLight',
        'homeRetry',
        'homeSelahAmen',
        'readingVerses',
        'readingQuiz',
        'readingQuestions',
        'readingBookmarkOn',
        'readingBookmarkOff',
      ]) {
        expect(
          RegExp('[؀-ۿ]').hasMatch(ar[key]! as String),
          isTrue,
          reason: 'ar.$key is not Arabic script: ${ar[key]}',
        );
      }
    });

    test('the English arm holds no Arabic script at all', () {
      // The mirror of the check above, which the one-armed check cannot see.
      final List<String> arabicInEnglish = <String>[
        for (final String key in keysOf(en))
          if (RegExp(r'[؀-ۿ]').hasMatch(en[key]! as String)) key,
      ];
      expect(arabicInEnglish, isEmpty);
    });

    test('the five `*UnavailableSuffix` keys are FIVE, and four say the same', () {
      // The name collision, asserted where cross-key identity can be seen.
      //
      // `authUnavailableSuffix`, `homeUnavailableSuffix`,
      // `readingUnavailableSuffix` and — since Task 5.6 — `journeyUnavailableSuffix`
      // all read "unavailable in this build" — one string, four owners, which is
      // §14's obligation that a screen reader is told WHY.
      // `quizUnavailableSuffix` reads "there is no answer to show", because that
      // is why *that* control is dead and "unavailable in this build" would be a
      // non-answer.
      //
      // So four of the five are the same and the fifth is not, and this asserts
      // exactly that shape rather than "all five differ" — which would be
      // satisfied by a translator harmonising them and would be *wrong*.
      const List<String> keys = <String>[
        'authUnavailableSuffix',
        'homeUnavailableSuffix',
        'readingUnavailableSuffix',
        'journeyUnavailableSuffix',
        'quizUnavailableSuffix',
      ];
      for (final String key in keys) {
        expect(keysOf(en), contains(key), reason: '$key must exist');
      }
      expect(en['authUnavailableSuffix'], en['homeUnavailableSuffix']);
      expect(en['homeUnavailableSuffix'], en['readingUnavailableSuffix']);
      expect(
        en['readingUnavailableSuffix'],
        en['journeyUnavailableSuffix'],
        reason:
            'the journey\'s two dead rows are dead for the same reason the login '
            'and home controls are: the feature is not built in this client. A '
            'different string here would be a *true* string and a *useless* one.',
      );
      expect(
        en['quizUnavailableSuffix'],
        isNot(en['authUnavailableSuffix']),
        reason:
            'the collision resolved to four identical suffixes and one different '
            'one. If the /quiz one said "unavailable in this build" it would be '
            'true and useless — §14 asks for the reason, and the reason there is '
            'that there is no answer to submit.',
      );
    });

    test('exactly the documented keys are identical across the arms', () {
      // `auth_strings_test.dart`'s `shared` set, generalised and inverted: rather
      // than a hand-kept exception list asserting that three keys match, this walks
      // every key and requires the set of *matching* keys to BE the declared set.
      //
      // The inversion is the point. The old test asserted `shared ⊆ identical`, so a
      // fourth accidental duplicate — a translator pasting English into an Arabic
      // field — passed. This fails it.
      final Set<String> identical = <String>{
        for (final String key in keysOf(en))
          if (en[key] == ar[key]) key,
      };
      expect(identical, mustBeIdentical);
    });
  });

  group('the two ICU plurals — what is LEFT of the migration\'s point', () {
    // ## WHY THE GROUP STILL SAYS "TWO" AFTER A PLURAL WAS DELETED
    //
    // It said "two" for `readingCaptionFor` and `resultTotalCaption` before Phase 1
    // added `leaderboardRowSemantics`, so Task 5.3's deletion left the number
    // unchanged by coincidence — and that coincidence is exactly why the manifest
    // assertion below is a **named set** and not a length. A length of `2` would
    // pass over a table where the wrong key had become a plural and the right one
    // had stopped.
    //
    // ## AND THE COST OF THE DELETION IS WRITTEN WHERE A READER HITS IT
    //
    // `readingCaptionFor` was the only `/reading` plural, and its `two` class
    // rendered `٢ سؤالان` — correct Arabic, and a real capability this client once
    // had. It is gone because `eva/redesign.html:1347` composes the CTA caption as
    // `` `${tr('quiz')} · ${N(qEff)} ${tr('questions')}` `` out of a table whose
    // `questions` row carries **no ICU forms at all**, and
    // `reading_l10n.dart`'s class doc records the trade in full: a client that
    // inflects where the prototype does not is translating a design decision nobody
    // made. The composed replacement, `ReadingStringsPhrases.quizCaption`, renders
    // `اختبار · ٣ أسئلة` at **every** count, and the lost dual is a recorded trade
    // rather than a regression waiting to be found.
    //
    // The row that watches the deletion actually happened is
    // `the retired keys are GONE from both arms`, below: "a plural stopped being a
    // plural" and "a plural was deleted" are different changes, and only the second
    // leaves an artefact anyone can assert against.

    /// The Arabic classes, with a count in each. Chosen to hit **every** one of
    /// Arabic's six, which is what the old `count == 1 ? … : …` could not.
    ///
    /// **Kept, and still all six, even though the key that needed a dual is
    /// gone**: `resultTotalCaption` selects all of them too, and a future edit
    /// that collapsed it onto `other` for every count would be invisible to the
    /// manifest row — that row proves the key *is* a plural, and only these prove
    /// it selects the right arm.
    const Map<String, int> arabicClasses = <String, int>{
      'zero': 0, // no points at all — reachable on a fresh account
      'one': 1, // the class the live payload actually carries
      'two': 2, // the DUAL — the class a one-boundary table gets wrong
      'few': 5, // 3-10
      'many': 11, // 11-99, singular accusative — also wrong in the old table
      'other': 100,
    };

    test('the retired keys are GONE from both arms, and were not replaced', () {
      // The deletion, asserted rather than assumed. **Two** rows left this table in
      // Task 5.3, and a silent deletion is the one change nothing else here would
      // notice: a key that is *absent* breaks no other assertion in this file. It
      // is supposed to break the **build**, and AGENT_CONTEXT §2.1 records that
      // half of the "a typo becomes a build error" claim as **false** — a key
      // missing from a locale file makes `flutter gen-l10n` print a hint and
      // **exit 0**, emitting the template's English value into the Arabic class.
      //
      // So this row is the one that closes that gap for these two keys, and the
      // `111 → 116` count above is what makes an *unintentional* return red: seven
      // keys were added, so a resurrection would move the number too.
      for (final String arm in <String>['en', 'ar']) {
        final Map<String, dynamic> table = _decode('lib/l10n/app_$arm.arb');
        for (final String gone in <String>[
          'readingCaptionFor',
          'readingBeginReflection',
        ]) {
          expect(
            keysOf(table),
            isNot(contains(gone)),
            reason:
                '$arm.$gone is back. If the plural is wanted back, '
                '`reading_l10n.dart` and `reading_l10n_test.dart` change with it — '
                'the redesign composes an uninflected caption, so a restored '
                'plural is a deliberate divergence from `redesign.html:1347` and '
                'not a repair.',
          );
        }
      }
    });

    // ## WHAT THIS ROW USED TO ASSERT, AND WHY IT IS NOT MERELY GONE
    //
    // `the question caption selects all six Arabic classes` walked the whole map
    // against `readingCaptionFor` and was the single best test in this file: it is
    // what paid the recorded debt that the hand-rolled table's one `== 1` boundary
    // left open, and its `two` row is where `٢ سؤالان` was proved rather than hoped
    // for.
    //
    // It is deleted rather than re-pointed because **no key left in this table
    // inflects a question count.** `reading_l10n.dart`'s class doc records why in
    // full, and the short form is that `redesign.html:1347` composes the caption
    // from three separate values out of a table whose `questions` row has no ICU
    // forms — so the dual is gone from the app, not from this file's attention.
    // Re-pointing the row at `resultTotalCaption` would have produced a *passing*
    // duplicate of the row below it, which is the worse outcome: it would look
    // like the Arabic classes are still covered twice when they are covered once.
    //
    // What still watches the six classes is `arabicClasses` and the score row —
    // `resultTotalCaption` selects zero/one/two/few/many/other too, and
    // `leaderboardRowSemantics` renders them through `Intl.pluralLogic` with the
    // same six arms.

    test('the caption is derived from the count and never hard-codes the prototype`s 5', () {
      // The superseded prototype hard-codes `5 questions` and the live reading
      // carries ONE question, so the prototype's literal is false by a factor of
      // five. That hard-coded literal has **no counterpart in the redesign**,
      // whose own count is computed (`redesign.html:1347`). **This row stopped
      // being tautological in Task 5.3**: it used to be a
      // scan whose subject was `readingCaptionFor(5)`, and that key is deleted. It
      // is now a claim about the table alone — no key in either file can be found
      // holding the prototype's number — which is the stronger of the two and the
      // only one that survives the plural's removal.
      //
      // The composed half moved to `reading_l10n_test.dart`, which is where the
      // number actually reaches a screen: `quizCaption` takes `StickyCta`'s
      // `questionCount`, so the count is now a Dart argument and could not be in
      // the table even if someone wanted it there.
      expect(
        keysOf(en).map((String k) => en[k].toString()).join(' '),
        isNot(contains('5 questions · about a minute')),
      );
      for (final String key in keysOf(en)) {
        expect(
          (en[key]! as String).contains('about a minute'),
          isFalse,
          reason: '$key smuggles the prototype duration back in',
        );
      }
    });

    test('the score caption selects a NOUN and carries no numeral of its own', () {
      // `resultTotalCaption` is a plural used for **selection only**. The score is
      // drawn by `result_sheet.dart` in `displayLarge` one line above, so folding the
      // numeral into this key would print it twice. What must agree with the number
      // is the noun.
      //
      // The old value was `نقطة` — singular — for every score, so `٥ نقطة` rendered
      // where Arabic wants `٥ نقاط`. That was a genuine correctness gap and it is
      // the reason this key is a plural.
      const Map<String, String> expected = <String, String>{
        'zero': 'نقاط',
        'one': 'نقطة',
        'two': 'نقطتان',
        'few': 'نقاط',
        'many': 'نقطة',
        'other': 'نقطة',
      };
      final AppLocalizationsAr strings = AppLocalizationsAr();
      for (final MapEntry<String, int> entry in arabicClasses.entries) {
        final String caption = strings.resultTotalCaption(entry.value);
        expect(caption, expected[entry.key], reason: 'Arabic `${entry.key}`');
        expect(
          RegExp(r'[0-9٠-٩]').hasMatch(caption),
          isFalse,
          reason:
              'the caption must not carry a numeral — the page draws the score '
              'itself. `resultPage` renders `$caption` under `\$٤٠`.',
        );
      }
      final AppLocalizationsEn enStrings = AppLocalizationsEn();
      expect(enStrings.resultTotalCaption(1), 'point');
      expect(enStrings.resultTotalCaption(1234), 'points');
    });

    test('and no OTHER key claims to be a plural', () {
      // The manifest the plural tests above depend on, and the row the
      // Latin-script gate above reads its exemptions from. **A fourth key became a
      // `plural` — or one of these two stopped being one — and this fails**, so the
      // per-class assertions cannot pass vacuously against a key that has collapsed
      // to a single arm, and the gate cannot silently start exempting a template
      // nobody reviewed.
      //
      // ## WHAT EACH MEMBER IS, AND WHY THERE ARE TWO
      //
      // * `resultTotalCaption` — a **score's noun**, for `/result`. The score itself
      //   is drawn by `result_sheet.dart` in `displayLarge` one line above, so this
      //   key selects agreement and carries no numeral.
      // * `leaderboardRowSemantics` — a **whole row's spoken text**, added in
      //   Phase 1. A board row is four numbers, and a screen reader announcing them
      //   separately gives fragments rather than a sentence. Its per-class
      //   assertions live in `leaderboard_row_tile_test.dart`, which is where the
      //   string is actually used — a plural asserted only here would be a claim
      //   about the ARB and not about the app.
      //
      // ## AND THE THIRD MEMBER WAS DELETED, WHICH IS THE POINT OF NAMING THE SET
      //
      // `readingCaptionFor` was here until Task 5.3. It is gone because the
      // redesign's caption is composed, not inflected (`redesign.html:1347`), and
      // **the manifest is a claim about which keys ARE plurals rather than a
      // count**: the length is still `2`, by the coincidence recorded at the head
      // of this group, and a count would have gone on being two after the wrong
      // key changed.
      final Set<String> plurals = _pluralKeys(en);
      expect(plurals, <String>{
        'resultTotalCaption',
        'leaderboardRowSemantics',
      });
      for (final String key in plurals) {
        expect(
          ar[key],
          contains(', plural,'),
          reason: 'ar.$key must stay a plural',
        );
      }
    });
  });

  group('the numerals are the domain function`s, not `intl`s', () {
    // ## THE SUBJECT OF THIS GROUP MOVED, AND IT IS THE ONE KEY THAT DID NOT DIE
    //
    // Both rows below used to be written against `readingCaptionFor`, the
    // two-placeholder `/reading` plural Task 5.3 deleted. `leaderboardRowSemantics`
    // **still carries the same pair** — `count: int` for the agreement and
    // `digits: String` for the numeral — so the property this group exists to hold
    // is unchanged; only the key that holds it moved. It had to move somewhere: the
    // shape is a property of *a* plural that renders a count, and
    // `resultTotalCaption` selects a noun only and never interpolates a numeral at
    // all, which is why it declares one placeholder and this group cannot use it.
    test('the ARB plural carries a String numeral placeholder, deliberately', () {
      // ## THE FINDING THAT FORCED THIS WHOLE SHAPE
      //
      // `gen_l10n` compiles `{count, plural, …}` by interpolating the **raw Dart
      // `int`**: the generated Arabic arm literally reads `'$count نقاط'`. A
      // single-placeholder ARB therefore renders **Latin digits on the Arabic arm**,
      // silently undoing `arabicIndicDigits` — a domain function pinned by
      // `arabic_digits_test.dart` and by `font_coverage_test.dart`'s glyph coverage —
      // and leaving every Arabic screen showing a Latin count beside `٥`.
      //
      // So the selector is an `int` and the numeral is a `String`, and the division
      // is the honest one: the agreement is a property of the WORDING (which belongs
      // in the ARB) and the numeral system is a property of the ARM (which belongs
      // in `l10n.dart`). This test is the declaration that the shape is deliberate,
      // so nobody "simplifies" the second placeholder away.
      const String key = 'leaderboardRowSemantics';
      const Map<String, String> caption = <String, String>{
        'count': 'int',
        'digits': 'String',
        // The **second** plural, added with the streak count: the row shows two
        // numbers — the metric's value and the other metric's sub-line — and the
        // announcement has to carry both, or a screen-reader user is told the
        // score about a row whose big number is the streak count.
        'streakCount': 'int',
        'streakDigits': 'String',
      };
      expect(
        ((en['@$key']! as Map)['placeholders']! as Map).keys,
        containsAll(<String>['count', 'digits', 'streakCount', 'streakDigits']),
      );
      for (final String type in <String>[
        'count',
        'digits',
        'streakCount',
        'streakDigits',
      ]) {
        expect(
          (((en['@$key']! as Map)['placeholders']! as Map)[type]!
              as Map)['type'],
          caption[type],
          reason: 'the `$type` placeholder\'s declared type',
        );
      }
      // And the key really does render the numeral from the String rather than
      // from the `int` — the shape is only meaningful if the message body says
      // `{digits}` and not `{count}`. This is the assertion that would fail if
      // someone "simplified" the message without touching the metadata above.
      expect(
        (en[key]! as String).contains('{digits}'),
        isTrue,
        reason:
            'the `other` arm interpolates the caller\'s numeral, which is why '
            'the English `one` arm can say a literal `1 point` while `other` '
            'cannot',
      );
    });

    test('and the two arms render the count the way their own message says', () {
      // The load-bearing half, and **it is a different claim from the row it
      // replaced.** `_digits` below is the same conversion
      // `AppLocalizationsArm.digits` performs via `arabicIndicDigits`; asserting the
      // codepoint is what makes this a test of the numeral system rather than of the
      // wording.
      //
      // ## MEASURED: THE ARABIC ARM USED **NO NUMERAL AT ALL**, AND THAT WAS A DEFECT
      //
      // `app_ar.arb`'s `leaderboardRowSemantics` **had no `{digits}` in it** — the
      // `few` / `many` / `other` arms said `نقاط` / `نقطة` and the caller's `٨٠`
      // was accepted by the generated signature and then **discarded**. At a count
      // of 80 the Arabic row rendered `نقطة، DM، المركز 3`.
      //
      // **The previous version of this test pinned that**, and called it "the same
      // fact `reading_l10n.dart` records from the other side … both are the
      // prototype's own choice". **That justification was wrong**, and it is
      // recorded here rather than deleted, because a test that pins a defect and
      // explains it wrongly is worse than no test: the next reader inherits the
      // explanation.
      //
      // The prototype has **no announcement string at all** — `.brow` (`:314`) is a
      // `<div>` with an `onclick` and no `aria-label` — so the bilingual surface
      // here is this client's own composition, and "the prototype's own choice"
      // cannot be a reason for the two arms to **disagree about whether a spoken
      // row carries a number**. The English arm always spoke it. The Arabic arm
      // spoke it only for `one` and `two` ("نقطة واحدة", "نقطتان") and dropped it
      // for every count a reader actually has — which is a screen-reader user
      // being told a witness has *points* and not how many.
      //
      // So the Arabic arms now interpolate `{digits}`, and this test pins the
      // corrected rendering.
      final AppLocalizationsAr arStrings = AppLocalizationsAr();
      final String arRow = arStrings.leaderboardRowSemantics(
        80,
        _digits(80),
        12,
        _digits(12),
        'DM',
        '3',
        'false',
      );
      expect(
        arRow,
        '٨٠ نقطة، ١٢ شعلة، DM، المركز 3',
        reason:
            'the Arabic row carries the caller\'s numeral, as the English '
            'one does',
      );
      expect(arRow, contains('٨٠'), reason: 'and does not discard it');
      expect(
        arRow.runes.where((int r) => 0x0660 <= r && r <= 0x0669),
        isNotEmpty,
        reason: 'U+0660-U+0669 appears in it, which is the measurement',
      );
      // The `rank` is still interpolated verbatim — so the Arabic arm is not
      // "numbers-free", it is **numeral-free**: the caller owns the rank's numeral
      // and this arm's own plural contributes only the noun.
      expect(
        arStrings.leaderboardRowSemantics(1, '١', 12, '١٢', 'DM', '٣', 'true'),
        'نقطة واحدة، ١٢ شعلة، DM، المركز ٣، هذا أنت',
      );
      // The English arm is the one that takes the caller's numeral, and it is the
      // Latin arm's own digits when the caller is the Latin arm.
      final AppLocalizationsEn enStrings = AppLocalizationsEn();
      expect(
        enStrings.leaderboardRowSemantics(
          80,
          '80',
          12,
          '12',
          'DM',
          '3',
          'false',
        ),
        '80 points, 12 streaks, DM, rank 3',
      );
      // And the numeral system itself, on the row that composes one — which is now
      // `crumbMeta` / `quizCaption` on `/reading`, asserted with codepoints in
      // `reading_l10n_test.dart`. What this file keeps is the function's contract.
      expect(arStrings.digits(40), '٤٠');
      expect(arStrings.digits(40).runes, <int>[0x0664, 0x0660]);
    });
  });

  group('resolution, and the fallback arm that no longer exists', () {
    test('the generated lookup answers for both shipped locales', () {
      // `X.of(Locale)` is replaced by `gen_l10n`'s own `lookupAppLocalizations`.
      // **By value, not by identity** — and that is a change worth naming: the tables
      // were `const`, so `of(locale)` returned THE instance and `same()` was the
      // honest assertion. `lookupAppLocalizations` constructs a fresh object per
      // call, so identity would now be a false claim. Three `same()` sites are gone
      // from the suite as a result, and the `no_identical_on_converted_types_test`
      // registry entries that audited them are retired with them.
      expect(
        lookupAppLocalizations(const Locale('ar')).readingBack,
        AppLocalizationsAr().readingBack,
      );
      expect(
        lookupAppLocalizations(const Locale('en')).readingBack,
        AppLocalizationsEn().readingBack,
      );
      expect(lookupAppLocalizations(const Locale('ar')).localeName, 'ar');
      expect(lookupAppLocalizations(const Locale('en')).localeName, 'en');
    });

    test('and an UNSUPPORTED locale throws rather than falling back', () {
      // ## A REAL BEHAVIOUR CHANGE, RECORDED RATHER THAN PAPERED OVER
      //
      // Every table's `of(Locale)` had an `_ => en` arm, and each one's doc gave the
      // reason: the app declares exactly two `supportedLocales`, "so this arm is
      // unreachable through `MaterialApp.locale` and exists for a widget pumped
      // outside one — which several suites do."
      //
      // `gen_l10n`'s lookup has **no fallback arm** — it throws a `FlutterError`
      // naming the locale. That is reachable in production only if `app.dart` and
      // the ARB disagree about which locales the app supports, which is a
      // configuration error worth a loud failure rather than a silent English
      // screen. `app_test.dart` reads `supportedLocales` off the live `MaterialApp`
      // and the ARB asserts 182 keys in both arms, so the two are cross-checked.
      // (182 = the 72 the five hand-rolled tables carried, plus the 21 `settings*`
      // keys Phase 9 added, plus the keys the redesign's own rows and the
      // client's written copy arrived as across Tasks 5.1–5.7 and Phase 7's
      // ritual — see `settings_page.dart`'s own cut table for the four prototype
      // rows that produced no keys at all, and the group at the foot of this
      // file for the prototype's 128 rows measured against this table.)
      expect(
        () => lookupAppLocalizations(const Locale('fr')),
        throwsA(isA<FlutterError>()),
      );
      // `Locale('ar', 'EG')` — a real shape a reader's device sends, and a
      // *supported* language with an unsupported region, so it must still resolve to
      // Arabic. The lookup switches on `languageCode`, so the region is dropped and
      // the result is the plain Arabic arm.
      expect(
        lookupAppLocalizations(const Locale('ar', 'EG')).readingBack,
        AppLocalizationsAr().readingBack,
      );
    });
  });

  group('the prototype\'s I18N table, measured against this one', () {
    // ## WHY THIS GROUP IS A **GATE** AND NOT A NOTE
    //
    // The prototype's `I18N` literal is **128 rows** of the redesign's own
    // bilingual surface, and this table is the client's answer to it. The
    // measurement below is by **English value** — the same measurement the
    // brief that opened this work was written from — and the number it produces
    // is 103 rows carried verbatim and 25 accounted for by name.
    //
    // **A row that is neither is a hole, and a hole that is not measured is a
    // hole nobody can see.** The prototype has no tests, so a row this client
    // never carried would sit in the reference material looking exactly like a
    // row it did.

    test('the table is read whole, and 103 of its 128 rows are verbatim here', () {
      // The anti-vacuity half. A parser that found nothing would make every
      // comparison below an assertion over two empty sets — green, and about
      // nothing.
      final List<_I18nRow> rows = _prototypeI18nRows();
      expect(
        rows,
        hasLength(128),
        reason:
            '`eva/redesign.html`\'s `I18N` literal carries 128 rows. A different '
            'number means the prototype changed and this harness must read it '
            'again — it parses the file rather than quoting it, so a row that '
            'moved, grew a third element or was removed shows up here rather '
            'than as a silently shorter table.',
      );
      final Set<String> values = <String>{
        for (final String key in keysOf(en)) en[key]! as String,
      };
      final List<_I18nRow> verbatim = rows
          .where((_I18nRow row) => values.contains(row.en))
          .toList();
      expect(
        verbatim,
        hasLength(103),
        reason:
            'the rows this table carries **verbatim**, measured by English '
            'value. The other ${rows.length - verbatim.length} are accounted for '
            'by `i18nRowsAccountedFor` — and a row that moves from that map '
            'into this one makes this number move, which is the point: the '
            'table got more faithful to the prototype and the count says so.',
      );
    });

    test('and every row this table does not carry verbatim is declared', () {
      // The completeness half, and the freshness half in the same row: the
      // declared map must be **exactly** the tail, so a row that is ported
      // properly leaves a stale entry and fails, and a row that is dropped
      // from the prototype leaves a missing one and fails the other way.
      final List<_I18nRow> rows = _prototypeI18nRows();
      final Set<String> values = <String>{
        for (final String key in keysOf(en)) en[key]! as String,
      };
      final Set<String> verbatim = <String>{
        for (final _I18nRow row in rows)
          if (values.contains(row.en)) row.key,
      };
      final Set<String> undeclared = <String>{
        for (final _I18nRow row in rows)
          if (!verbatim.contains(row.key) &&
              !i18nRowsAccountedFor.containsKey(row.key))
            row.key,
      };
      expect(
        undeclared,
        isEmpty,
        reason:
            'these prototype rows are neither carried verbatim nor declared in '
            '`i18nRowsAccountedFor`. Either the row was ported under another '
            'name and the map needs it, or it was dropped and the map needs to '
            'say so — a row nobody wrote down is a row nobody can audit.',
      );
      final Set<String> stale = <String>{
        for (final String key in i18nRowsAccountedFor.keys)
          if (verbatim.contains(key)) key,
      };
      expect(
        stale,
        isEmpty,
        reason:
            'these declared rows are now carried **verbatim**, so their entry '
            'in `i18nRowsAccountedFor` is out of date. Delete the entry and '
            'the count in the row above moves with it.',
      );
    });

    test('and every declared row says where it went, and on which line', () {
      final Map<String, int> lines = <String, int>{
        for (final _I18nRow row in _prototypeI18nRows()) row.key: row.line,
      };
      for (final MapEntry<String, _I18nOutcome> entry
          in i18nRowsAccountedFor.entries) {
        final String key = entry.key;
        final _I18nOutcome outcome = entry.value;

        // **The prototype's own line, and the line it is REALLY on.**
        //
        // The seven `/reading` citations in this file were each one line above
        // the row they named, and no gate could see it: `citation_check.py`
        // checks that a line exists and is in range, and one line too high
        // satisfies both. The reason a row carries here names the line, and
        // this row checks the line against the file.
        expect(
          outcome.reason,
          contains('redesign.html:${lines[key]}'),
          reason:
              'the reason for `$key` does not cite the prototype line the row '
              'is really on (`redesign.html:${lines[key]}`). A citation that '
              'points at the wrong line is the defect this row exists to '
              'catch.',
        );
        expect(
          outcome.reason.length,
          greaterThanOrEqualTo(80),
          reason:
              'the reason for `$key` is too short to be a record. It has to say '
              'where the row went AND why, because a decision that is not '
              'written down is a decision nobody can audit.',
        );

        // The three shapes, and each one's own obligation.
        switch (outcome.kind) {
          case _I18nOutcomeKind.carried:
            expect(
              outcome.clientKeys,
              isNotEmpty,
              reason:
                  '`$key` is declared carried, so it must name the key(s) of '
                  'this table that carry it. An empty list is a carried row '
                  'with nowhere to look.',
            );
          case _I18nOutcomeKind.composedInDart:
            expect(
              outcome.clientKeys,
              isEmpty,
              reason:
                  '`$key` is declared composed in Dart, so it must name no key: '
                  'the composition is the point.',
            );
          case _I18nOutcomeKind.notDrawn:
            expect(
              outcome.clientKeys,
              isEmpty,
              reason:
                  '`$key` is declared not drawn, so it must name no key of this '
                  'table. A key for a row nothing draws is a key a translator '
                  'would translate for a screen that does not exist.',
            );
        }
        for (final String clientKey in outcome.clientKeys) {
          expect(
            keysOf(en),
            contains(clientKey),
            reason:
                'the reason for `$key` names `$clientKey`, and that key is not '
                'in this table. Either the key was renamed — in which case the '
                'reason is stale — or the reason is.',
          );
        }
      }
    });
  });
}

/// Every message key in [arb] — the `@key` metadata and the `@@` directives are not
/// messages, and including them would make the arity comparisons compare description
/// blocks.
Set<String> keysOf(Map<String, dynamic> arb) =>
    arb.keys.where((String k) => !k.startsWith('@')).toSet();

/// The keys in [arb] whose value is an ICU `plural` — i.e. a **template**, which is
/// not the same kind of thing as a sentence.
Set<String> _pluralKeys(Map<String, dynamic> arb) => <String>{
  for (final String key in keysOf(arb))
    if ((arb[key]! as String).contains(', plural,')) key,
};

/// [value] in Arabic-Indic digits — the same conversion
/// `AppLocalizationsArm.digits` performs through `arabicIndicDigits`, written out
/// here so this file can assert on the codepoint without importing the domain
/// function and so the two are visibly independent.
String _digits(int value) {
  final StringBuffer out = StringBuffer();
  for (final int unit in value.toString().codeUnits) {
    out.writeCharCode(0x0660 + (unit - 0x30));
  }
  return out.toString();
}

/// The decoded ARB at [path].
Map<String, dynamic> _decode(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The prototype file this suite reads for the `I18N` table.
///
/// `eva/` is read-only reference material (AGENT_CONTEXT §2, §8), and the
/// prototype is **parsed** here rather than quoted — the discipline
/// `home_l10n_test.dart` uses for the greeting rows and `reading_l10n_test.dart`
/// uses for the seven `/reading` citations. A quoted line and the file it came
/// from are two copies of one fact, and only one of them can be checked.
const String prototypePath = 'eva/redesign.html';

/// The three ways a row of the prototype's `I18N` table can land in this table.
enum _I18nOutcomeKind {
  /// The row's **content** is in this table under another key.
  ///
  /// The value may differ from the prototype's — a glyph dropped because no
  /// bundled family draws it, a bilingual label split one script per arm, a
  /// sentence reworded — and the reason says which.
  carried,

  /// The row is **drawn**, and no ARB row carries it.
  ///
  /// What the row says is a count, and the count is the domain function's
  /// (`digits`), so the composition is Dart's and the table keeps no key for
  /// it. The reason names the widget that composes it.
  composedInDart,

  /// The client does not draw the row at all.
  ///
  /// The reason names the surface that does not exist, or the live source that
  /// replaced the prototype's hard-coded number.
  notDrawn,
}

/// What became of one row of the prototype's `I18N` table.
class _I18nOutcome {
  const _I18nOutcome._({
    required this.kind,
    required this.clientKeys,
    required this.reason,
  });

  /// The row is carried by these keys of this table.
  const _I18nOutcome.carried(String reason, List<String> clientKeys)
    : this._(
        kind: _I18nOutcomeKind.carried,
        clientKeys: clientKeys,
        reason: reason,
      );

  /// The row is composed in Dart, and no ARB row carries it.
  const _I18nOutcome.composedInDart(String reason)
    : this._(
        kind: _I18nOutcomeKind.composedInDart,
        clientKeys: const <String>[],
        reason: reason,
      );

  /// The client does not draw the row at all.
  const _I18nOutcome.notDrawn(String reason)
    : this._(
        kind: _I18nOutcomeKind.notDrawn,
        clientKeys: const <String>[],
        reason: reason,
      );

  /// Which of the three shapes this is.
  final _I18nOutcomeKind kind;

  /// The keys of this table that carry the row — empty for the other two kinds.
  final List<String> clientKeys;

  /// Where the row went, and why.
  ///
  /// **Carries the prototype's own `file:line`**, and the group below asserts
  /// that it is the line the row is really on.
  final String reason;
}

/// One row of the prototype's `I18N` table.
class _I18nRow {
  const _I18nRow(this.key, this.en, this.ar, this.line);

  /// The prototype's own key for the row.
  final String key;

  /// The row's English value.
  final String en;

  /// The row's Arabic value.
  final String ar;

  /// The line the row is on in `eva/redesign.html`.
  final int line;
}

/// The prototype's `I18N` table — every row, both arms, and the line each is on.
///
/// `eva/redesign.html:924-977`. The literal is cut out first and the pair
/// regex runs **inside** it, because the pair shape is not unique: an
/// unanchored search across the whole file matches every `key:["en","ar"]` in
/// the prototype, which is how `home_l10n_test.dart`'s `_catsTable` first
/// matched 134 rows instead of six.
///
/// The **line** is part of the row, not a decoration: the seven `/reading`
/// citations in this suite were each one line above the row they named, and
/// that defect survived every gate until a test pinned it. So the line is
/// parsed, and the reason a row carries is checked against it.
List<_I18nRow> _prototypeI18nRows() {
  final List<String> lines = File(prototypePath).readAsLinesSync();
  final RegExp pair = RegExp(
    r'([A-Za-z_][A-Za-z0-9_]*):\["([^"]*)","([^"]*)"\]',
  );
  final List<_I18nRow> rows = <_I18nRow>[];
  bool inside = false;
  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    if (!inside) {
      if (line.contains('const I18N=')) inside = true;
      continue;
    }
    if (line.trimLeft().startsWith('};')) break;
    for (final RegExpMatch match in pair.allMatches(line)) {
      rows.add(
        _I18nRow(match.group(1)!, match.group(2)!, match.group(3)!, index + 1),
      );
    }
  }
  return rows;
}
