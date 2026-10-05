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
  const Set<String> latinIsCorrect = <String>{
    'authWordmark', // the product's name; a brand mark is not translated
    'homeWordmark', // the same mark, drawn by the top bar
    'authEmailHint', // an example address, and ASCII by definition
    'authPasswordHint', // bullets, not digits — identical so the field cannot re-measure
    'authContinueWithGoogle', // the vendor's own name inside an Arabic sentence
    'authContinueWithApple', // the vendor's own name inside an Arabic sentence
  };

  /// The keys whose two values are **identical**, and must stay identical.
  ///
  /// The successor to `auth_strings_test.dart`'s `shared` set. Every other key must
  /// differ, which is what catches an untranslated string.
  const Set<String> mustBeIdentical = <String>{
    'authWordmark',
    'authEmailHint',
    'authPasswordHint',
    'homeWordmark',
  };

  group('the ARB pair, structurally', () {
    test('the walk finds the keys, so nothing below is vacuous', () {
      // The anti-vacuity half. A parser that returned an empty map would make every
      // "both arms" assertion a comparison over two empty sets — green, and about
      // nothing. The count is asserted exactly so a key silently dropped from the
      // file is a failure rather than a smaller green.
      expect(
        keysOf(en).length,
        93,
        reason:
            'the ARB is the whole bilingual surface. A different number means a key '
            'was added or removed — update this number and say why in the same '
            'commit, because the plural tests below are written against a named '
            'manifest and a silent drop would leave them passing.',
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
      };
      final List<String> keys = keysOf(
        en,
      ).where((String key) => key.startsWith('settings')).toList()..sort();

      expect(
        keys,
        hasLength(21),
        reason:
            'the /settings ARB surface. This is a declared count so that a dropped '
            'key is a failure rather than a smaller green, exactly as the file-level '
            'count is above.',
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
        'authWordmark': 'LoginScreen.tsx:29',
        'authTagline': 'LoginScreen.tsx:32',
        'authSignIn': 'LoginScreen.tsx:64',
        'authDivider': 'LoginScreen.tsx:78',
        'authContinueWithGoogle': 'LoginScreen.tsx:84',
        'homeWordmark': 'ds.tsx:508',
        'homeStreakGlowing': 'HomeScreen.tsx:30',
        'homeContinueReading': 'HomeScreen.tsx:44',
        'homeContinueLabel': 'HomeScreen.tsx:71',
        'homeStartReflection': 'HomeScreen.tsx:72',
        'homeAvatarLabel': 'ds.tsx:525',
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
        'quizNextQuestion': 'QuizScreen.tsx:127',
        'readingBeginReflection': 'ReadingEnScreen.tsx:87',
        'readingBeginReflectionAr': 'ReadingArScreen.tsx:85',
        'resultReflectAgain': 'ResultScreen.tsx:77',
        'resultLongestYet': 'ResultScreen.tsx:65',
      };
      for (final MapEntry<String, String> entry in citations.entries) {
        if (entry.key == 'readingBeginReflectionAr') {
          // The Arabic arm's own citation, which lives on the same key.
          continue;
        }
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
      expect(
        ((en['@readingBeginReflection']! as Map)['description']! as String),
        contains('ReadingArScreen.tsx:85'),
        reason:
            '`readingBeginReflection` is the one bilingual transcription, and '
            'its Arabic arm\'s citation is in the same description',
      );
    });
  });

  group('no English left in the Arabic arm, and no Arabic in the English one', () {
    test('no Arabic-arm value holds Latin script outside the documented set', () {
      // `home_strings_test.dart`'s rule, widened from one table to all five. This is
      // the property the whole bilingual surface exists to keep, and it is the one a
      // hand-typed ARB entry gets wrong most easily.
      //
      // ## THE TWO `plural` KEYS ARE **TEMPLATES**, NOT SENTENCES
      //
      // `readingCaptionFor` and `resultTotalCaption` are the only keys whose Arabic
      // value legitimately contains Latin characters, and **none of it reaches a
      // reader**: an ICU message is `zero{…} one{…} few{…}` plus the placeholder
      // names `count` and `digits`, all of which are ASCII keywords of the
      // MessageFormat grammar rather than prose. `gen_l10n` discards them at compile
      // time and emits `intl.Intl.pluralLogic(…)` carrying Arabic literals.
      //
      // So they are exempted by **being plurals** — read off the `plural` manifest,
      // not a hand-kept name list. And the exemption is not a loophole: the two
      // per-class tests above assert every rendered form against a literal, which
      // is the only place a Latin character could reach a screen.
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
      for (final String key in <String>[
        'authTagline',
        'authSignIn',
        'homeGreetingMorning',
        'homeTodayReading',
        'homeRetry',
        'homeContinueLabel',
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

  group('the two ICU plurals, which are the point of the migration', () {
    /// The Arabic classes, with a count in each. Chosen to hit **every** one of
    /// Arabic's six, which is what the old `count == 1 ? … : …` could not.
    const Map<String, int> arabicClasses = <String, int>{
      'zero': 0, // no questions at all — reachable; see `TodayReadingMapper`
      'one': 1, // the class the live payload actually carries
      'two': 2, // the DUAL — the class the old table got wrong
      'few': 5, // 3-10, and the class `ReadingArScreen.tsx:87`'s `٥` is in
      'many': 11, // 11-99, singular accusative — also wrong in the old table
      'other': 100,
    };

    test('the question caption selects all six Arabic classes', () {
      // `readingCaptionFor` was `captionFor`'s one-boundary `== 1`. Its own doc
      // recorded the other three classes as **accepted debt**: `captionFor(2)`
      // returned `٢ أسئلة` where correct Arabic is `٢ سؤالان`.
      //
      // This is that debt, paid. It is asserted per class and against a literal, so
      // a `plural` that silently fell back to `other` for every count would fail on
      // five of the six rows.
      const Map<String, String> expected = <String, String>{
        'zero': '٠ أسئلة',
        'one': '١ سؤال واحد',
        'two': '٢ سؤالان', // ← was `٢ أسئلة`
        'few': '٥ أسئلة',
        'many': '١١ سؤالًا', // ← was `١١ أسئلة`
        'other': '١٠٠ سؤال',
      };
      final AppLocalizationsAr strings = AppLocalizationsAr();
      for (final MapEntry<String, int> entry in arabicClasses.entries) {
        expect(
          strings.readingCaptionFor(entry.value, _digits(entry.value)),
          expected[entry.key],
          reason:
              'Arabic `${entry.key}` (count ${entry.value}) — correct Arabic '
              'agreement is a correctness question, not a wording one',
        );
      }
    });

    test('and the English caption is one/other, which is all English has', () {
      final AppLocalizationsEn strings = AppLocalizationsEn();
      expect(strings.readingCaptionFor(0, '0'), '0 questions');
      expect(strings.readingCaptionFor(1, '1'), '1 question');
      expect(strings.readingCaptionFor(2, '2'), '2 questions');
      expect(strings.readingCaptionFor(11, '11'), '11 questions');
    });

    test('the caption is derived from the count and never hard-codes the prototype`s 5', () {
      // `ReadingEnScreen.tsx:89` hard-codes `5 questions` and the live reading
      // carries ONE question, so the prototype's literal is false by a factor of
      // five. Tautological against `readingCaptionFor(5)` on purpose: the claim is
      // that no key in this file can be found holding the prototype's number.
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
      // The manifest the two plural tests above depend on. If a third key became a
      // `plural` — or if one of these two stopped being one — this fails, so the
      // per-class assertions cannot pass vacuously against a key that has collapsed
      // to a single arm.
      final Set<String> plurals = _pluralKeys(en);
      expect(plurals, <String>{'readingCaptionFor', 'resultTotalCaption'});
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
    test(
      'the ARB plural carries a String numeral placeholder, deliberately',
      () {
        // ## THE FINDING THAT FORCED THIS WHOLE SHAPE
        //
        // `gen_l10n` compiles `{count, plural, …}` by interpolating the **raw Dart
        // `int`**: the generated Arabic arm literally reads `'$count أسئلة'`. A
        // single-placeholder ARB therefore renders **Latin digits on the Arabic arm**,
        // silently undoing `arabicIndicDigits` — a domain function pinned by
        // `arabic_digits_test.dart` and by `font_coverage_test.dart`'s glyph coverage —
        // and leaving every Arabic screen showing `5 questions` beside `٥`.
        //
        // So the selector is an `int` and the numeral is a `String`, and the division
        // is the honest one: the agreement is a property of the WORDING (which belongs
        // in the ARB) and the numeral system is a property of the ARM (which belongs
        // in `l10n.dart`). This test is the declaration that the shape is deliberate,
        // so nobody "simplifies" the second placeholder away.
        const Map<String, String> caption = <String, String>{
          'count': 'int',
          'digits': 'String',
        };
        expect(
          ((en['@readingCaptionFor']! as Map)['placeholders']! as Map).keys,
          caption.keys,
        );
        for (final String type in <String>['count', 'digits']) {
          expect(
            (((en['@readingCaptionFor']! as Map)['placeholders']! as Map)[type]!
                as Map)['type'],
            caption[type],
            reason: 'the `$type` placeholder\'s declared type',
          );
        }
      },
    );

    test('and the Arabic arm renders U+0660…U+0669, not ASCII', () {
      // The load-bearing half. `_digits` below is the same conversion
      // `AppLocalizationsArm.digits` performs via `arabicIndicDigits`; asserting the
      // codepoint is what makes this a test of the numeral system rather than of the
      // wording.
      final AppLocalizationsAr arStrings = AppLocalizationsAr();
      final String caption = arStrings.readingCaptionFor(5, _digits(5));
      expect(
        caption.codeUnits.first,
        0x0665,
        reason: 'U+0665 ARABIC-INDIC FIVE',
      );
      expect(caption, isNot(contains('5')));
      expect(arStrings.digits(40), '٤٠');
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
