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

  group('the ARB pair, structurally', () {
    test('the walk finds the keys, so nothing below is vacuous', () {
      // The anti-vacuity half. A parser that returned an empty map would make every
      // "both arms" assertion a comparison over two empty sets — green, and about
      // nothing. The count is asserted exactly so a key silently dropped from the
      // file is a failure rather than a smaller green.
      expect(
        keysOf(en).length,
        126,
        reason:
            'the ARB is the whole bilingual surface. A different number means a key '
            'was added or removed — update this number and say why in the same '
            'commit, because the plural tests below are written against a named '
            'manifest and a silent drop would leave them passing.\n\n'
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
            'bilingual surface that no reader can reach. `seal_fab_test.dart` asserts '
            'Language is absent from the dial for the same reason.\n\n'
            '`sealFabLeaderboard` occupies the prototype\'s `Profile` slot: Profile is a '
            'cut screen with no endpoint, and a dial offering a dead route is why the '
            'component was cut. `seal_fab_test.dart` asserts Profile is absent so it '
            'cannot creep back.\n\n'
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
        'settingsFontScale': 'SettingsScreen.tsx:66',
        'settingsDecreaseFontSize': 'SettingsScreen.tsx:66',
        'settingsIncreaseFontSize': 'SettingsScreen.tsx:66',
        'settingsReduceMotion': 'no motion row',
        'settingsMotionOn': 'EvaToggle',
        'settingsMotionOff': 'EvaToggle',
        'settingsLanguageSheetTitle': 'SettingsScreen.tsx:77',
        'settingsLanguageEnglish': 'SettingsScreen.tsx:88',
        // Both added in Phase 10, and both are working around the same absence:
        // `SettingsScreen.tsx` cannot fail, because every value on it is a
        // `useState` in a file with no data layer, so the prototype has no error
        // state and nothing to transcribe. `settingsRetry` carries the same words the
        // *other three* retry keys carry for the same reason — see `homeRetry`.
        //
        // The phrase is `no error state` rather than `no data layer` because that is
        // what the two descriptions actually say, and the assertion below is a
        // substring match on the description. It is deliberately strict: a `written`
        // entry that drifts from the wording it is checking is a manifest that no
        // longer describes anything, which is the failure this test exists to catch.
        'settingsPreferencesUnavailable': 'no error state',
        'settingsRetry': 'no error state',
      };
      final List<String> keys = keysOf(
        en,
      ).where((String key) => key.startsWith('settings')).toList()..sort();

      expect(
        keys,
        hasLength(23),
        reason:
            'the /settings ARB surface. This is a declared count so that a dropped '
            'key is a failure rather than a smaller green, exactly as the file-level '
            'count is above. **21 → 23 in Phase 10**, for the failure notice; the '
            'two added keys are in the `written` map above with the reason they were '
            'invented.',
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
        'homeSealed': 'redesign.html:972',
        'homeVerses': 'redesign.html:966',
        'homeDays': 'redesign.html:925',
        // Phase 9, `/settings`. The full citation list, one per transcribed key.
        'settingsTitle': 'SettingsScreen.tsx:43',
        'settingsBack': 'SettingsScreen.tsx:39',
        'settingsAppearance': 'SettingsScreen.tsx:47',
        'settingsTheme': 'SettingsScreen.tsx:50',
        'settingsThemeLight': 'SettingsScreen.tsx:52',
        'settingsThemeDark': 'SettingsScreen.tsx:52',
        'settingsThemeSystem': 'SettingsScreen.tsx:52',
        'settingsFontSize': 'SettingsScreen.tsx:62',
        'settingsReading': 'SettingsScreen.tsx:70',
        'settingsDefaultLanguage': 'SettingsScreen.tsx:76',
        'settingsLanguageArabic': 'SettingsScreen.tsx:88',
        'settingsAbout': 'SettingsScreen.tsx:107',
        'settingsVersion': 'SettingsScreen.tsx:115',
        'quizCheckAnswer': 'QuizScreen.tsx:127',
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
        'resultReflectAgain': 'ResultScreen.tsx:77',
        'resultLongestYet': 'ResultScreen.tsx:65',
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

    test('the four `*UnavailableSuffix` keys are FOUR distinct strings', () {
      // The four-way name collision, asserted where cross-key identity can be seen.
      //
      // `authUnavailableSuffix`, `homeUnavailableSuffix` and `readingUnavailableSuffix`
      // all read "unavailable in this build" — one string, three owners, which is
      // §14's obligation that a screen reader is told WHY. `quizUnavailableSuffix`
      // reads "there is no answer to show", because that is why *that* control is
      // dead and "unavailable in this build" would be a non-answer.
      //
      // So three of the four are the same and the fourth is not, and this asserts
      // exactly that shape rather than "all four differ" — which would be satisfied
      // by a translator harmonising them and would be *wrong*.
      const List<String> keys = <String>[
        'authUnavailableSuffix',
        'homeUnavailableSuffix',
        'readingUnavailableSuffix',
        'quizUnavailableSuffix',
      ];
      for (final String key in keys) {
        expect(keysOf(en), contains(key), reason: '$key must exist');
      }
      expect(en['authUnavailableSuffix'], en['homeUnavailableSuffix']);
      expect(en['homeUnavailableSuffix'], en['readingUnavailableSuffix']);
      expect(
        en['quizUnavailableSuffix'],
        isNot(en['authUnavailableSuffix']),
        reason:
            'the four-way collision resolved to three identical suffixes and one '
            'different one. If the /quiz one said "unavailable in this build" it '
            'would be true and useless — §14 asks for the reason, and the reason '
            'there is that there is no answer to submit.',
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
      // `ReadingEnScreen.tsx:89` hard-codes `5 questions` and the live reading
      // carries ONE question, so the prototype's literal is false by a factor of
      // five. **This row stopped being tautological in Task 5.3**: it used to be a
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
      // drawn by `result_page.dart` in `displayLarge` one line above, so folding the
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
      //   is drawn by `result_page.dart` in `displayLarge` one line above, so this
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
      // and the ARB asserts 93 keys in both arms, so the two are cross-checked.
      // (93 = the 72 the five hand-rolled tables carried, plus the 21 `settings*`
      // keys Phase 9 added — see `settings_page.dart`'s own cut table for the four
      // prototype rows that produced no keys at all.)
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
