/// The bilingual table — red-first for the property §14 and
/// `no_adjacent_strings_in_list` both care about: **no English left in the Arabic
/// arm, and no missing value**.
///
/// ## WHY THE FIELD LIST IS READ FROM THE SOURCE AND THE VALUES FROM THE OBJECTS
///
/// Dart has no `dart:mirrors` on this platform, so "every field, compared" cannot
/// be a reflection loop. `LoginStrings`' suite split it the same way and this copies
/// the split rather than reinventing it:
///
/// * the **field names** come from `home_strings.dart`'s own declarations, so a
///   field added tomorrow is in tomorrow's run — and an anti-vacuity test fails if
///   the walk finds nothing;
/// * the **values** come from executing `en()` and `ar()`, so the assertions are
///   about the strings a reader would see rather than about the file's text.
///
/// What it cannot do is tell a *deliberately* untranslated string from a forgotten
/// one. What it does refuse: an empty value on either arm, and Latin script in the
/// Arabic arm outside the two places where Latin is correct.
///
/// ## AND WHY ONE TEST HERE IS A **DIRECTORY WALK**
///
/// The group at the bottom owns "what the prototype hard-coded and this feature may
/// not contain", and two of its three tests read **source** rather than a widget
/// tree — because the defect they guard is a value that is *not yet* on screen. See
/// `no prototype name or monogram appears ANYWHERE in the feature` for the
/// measurement that made the walk necessary.
///
/// ## AND THE `ds.tsx` LINE NUMBERS IN THE DOCS BELOW WERE WRONG
///
/// They read `ds.tsx:507,516,525` for the three literals. Measured: `Evangelion` is
/// at **508**, `12` at **516**, `MK` at **525** — so the first was off by one and
/// the other two were swapped, and a reviewer sent to `:525` to check the streak
/// found `MK`. §9's rule is "no report without `file:line`", and that is a rule
/// about **claims**, not only about reports; these were claims.
library;

import 'dart:io';

import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The identity literals the prototype hard-codes and this feature must not.
///
/// Two values, and both are measured in `eva/src`: `HomeScreen.tsx:27`'s `Miriam` in
/// the greeting and `ds.tsx:525`'s `MK` in the avatar. Neither has a backend behind
/// it — there is no user endpoint, and §2 decision 3 makes login UI-only — so both
/// arrive through `AuthSession` at runtime and neither may exist as a literal
/// anywhere under `lib/features/home/`.
///
/// **Literals and not identifiers**, deliberately: a constant, a parameter default
/// and a `switch` arm all contain the same quoted value, and only the value is the
/// thing that must not come back.
const List<String> prototypeIdentityLiterals = <String>['Miriam', 'MK'];

void main() {
  /// Every `final String` member of [HomeStrings], in declaration order.
  List<String> declaredFields() {
    final RegExp declaration = RegExp(
      r'^\s*(?:///.*\n\s*)*final String (\w+);',
      multiLine: true,
    );
    return declaration
        .allMatches(
          File('lib/features/home/presentation/home_strings.dart')
              .readAsStringSync(),
        )
        .map((RegExpMatch match) => match.group(1)!)
        .toList();
  }

  /// Reads [field] off [strings]. Exhaustive, so a field the walk finds and this
  /// switch does not is a **compile error** rather than a field that quietly stops
  /// being checked.
  String read(HomeStrings strings, String field) => switch (field) {
    'wordmark' => strings.wordmark,
    'greetingMorning' => strings.greetingMorning,
    'greetingAfternoon' => strings.greetingAfternoon,
    'greetingEvening' => strings.greetingEvening,
    'greetingSeparator' => strings.greetingSeparator,
    'streakGlowing' => strings.streakGlowing,
    'streakResting' => strings.streakResting,
    'streakLabel' => strings.streakLabel,
    'avatarLabel' => strings.avatarLabel,
    'unavailableSuffix' => strings.unavailableSuffix,
    'todayReading' => strings.todayReading,
    'continueReading' => strings.continueReading,
    'readingComplete' => strings.readingComplete,
    'reflectionProgress' => strings.reflectionProgress,
    'noQuestionsToday' => strings.noQuestionsToday,
    'continueLabel' => strings.continueLabel,
    'startReflection' => strings.startReflection,
    'retry' => strings.retry,
    _ => throw StateError('no accessor for $field — add one here'),
  };

  /// The fields whose English and Arabic values **must** differ.
  ///
  /// Enumerated rather than derived, and the exclusions are the point:
  ///
  /// * `wordmark` — the product's name in every language; transliterating a brand
  ///   mark is a product decision (`LoginStrings.ar` says the same).
  /// * `unavailableSuffix` — still Arabic, and still different. It is *not*
  ///   excluded.
  ///
  /// Everything else on the list differs because it is a sentence a reader reads.
  const Set<String> mustDiffer = <String>{
    'greetingSeparator',
    'greetingMorning',
    'greetingAfternoon',
    'greetingEvening',
    'streakGlowing',
    'streakResting',
    'streakLabel',
    'avatarLabel',
    'unavailableSuffix',
    'todayReading',
    'continueReading',
    'readingComplete',
    'reflectionProgress',
    'noQuestionsToday',
    'continueLabel',
    'startReflection',
    'retry',
  };

  group('both arms', () {
    test('the walk finds the fields, so the comparison below is not vacuous', () {
      expect(declaredFields(), isNotEmpty);
      expect(
        declaredFields(),
        hasLength(18),
        reason:
            '18 `final String` fields. A new one must be added to `mustDiffer` '
            'and to the accessor switch above, and this count is what notices.',
      );
    });

    test('every field is non-empty in both arms', () {
      for (final String field in declaredFields()) {
        expect(
          read(const HomeStrings.en(), field).trim(),
          isNotEmpty,
          reason: 'en.$field',
        );
        expect(
          read(const HomeStrings.ar(), field).trim(),
          isNotEmpty,
          reason: 'ar.$field',
        );
      }
    });

    test('and every one but the wordmark differs between the arms', () {
      for (final String field in declaredFields()) {
        if (field == 'wordmark') {
          expect(
            read(const HomeStrings.ar(), field),
            read(const HomeStrings.en(), field),
            reason:
                'the wordmark is the product\'s name in every language. If this '
                'ever changes, the exclusion above has to change with it — do '
                'not just delete the check.',
          );
          continue;
        }
        expect(
          read(const HomeStrings.ar(), field),
          isNot(read(const HomeStrings.en(), field)),
          reason:
              'ar.$field is the same string as en.$field, which for this app means '
              'an English sentence shipped to an Arabic reader',
        );
      }
    });

    test('the `mustDiffer` list covers every field but the wordmark', () {
      // The two lists can drift apart — a field added to the class and forgotten
      // here would otherwise be compared by the loop above *and* be excused by
      // this set if the set grew. Asserted in both directions.
      expect(
        declaredFields().where((String f) => f != 'wordmark').toSet(),
        mustDiffer,
      );
    });

    test('no Latin script survives in the Arabic arm outside the wordmark', () {
      for (final String field in declaredFields()) {
        if (field == 'wordmark') {
          continue;
        }
        expect(
          RegExp('[A-Za-z]').hasMatch(read(const HomeStrings.ar(), field)),
          isFalse,
          reason:
              'ar.$field contains Latin script: ${read(const HomeStrings.ar(), field)}',
        );
      }
    });

    test('and the Arabic arm has real Arabic script, not transliteration', () {
      // The other half of the same check. A table that replaced Arabic with
      // transliterated Latin would pass "no English left" and fail this.
      for (final String field in <String>[
        'greetingMorning',
        'todayReading',
        'retry',
        'continueLabel',
      ]) {
        expect(
          RegExp('[؀-ۿ]').hasMatch(read(const HomeStrings.ar(), field)),
          isTrue,
          reason:
              'ar.$field is not Arabic script: ${read(const HomeStrings.ar(), field)}',
        );
      }
    });
  });

  group('HomeStrings.of', () {
    test('picks the arm from the locale code', () {
      expect(
        HomeStrings.of(const Locale('ar')).greetingEvening,
        const HomeStrings.ar().greetingEvening,
      );
      expect(
        HomeStrings.of(const Locale('en')).greetingEvening,
        const HomeStrings.en().greetingEvening,
      );
    });

    test('and falls back to English for anything else', () {
      // `LoginStrings.of`'s rule, for `LoginStrings.of`'s reason: the app declares
      // exactly two `supportedLocales`, so this arm exists for a widget pumped
      // outside a `MaterialApp`.
      for (final Locale locale in <Locale>[
        const Locale('fr'),
        const Locale('en', 'US'),
        // Not `Locale('')` — that asserts in the framework's own constructor, so
        // it cannot be built at all, let alone passed here. `en_GB` is the real
        // shape of "a locale this app does not declare": a known language with an
        // undeclared country.
        const Locale('en', 'GB'),
      ]) {
        expect(
          HomeStrings.of(locale).greetingEvening,
          const HomeStrings.en().greetingEvening,
          reason: 'locale $locale',
        );
      }
    });
  });

  group('the greeting', () {
    test('the word is a switch over all three periods', () {
      const HomeStrings en = HomeStrings.en();
      expect(en.greetingWord(GreetingPeriod.morning), 'Good morning');
      expect(en.greetingWord(GreetingPeriod.afternoon), 'Good afternoon');
      expect(en.greetingWord(GreetingPeriod.evening), 'Good evening');

      const HomeStrings ar = HomeStrings.ar();
      expect(ar.greetingWord(GreetingPeriod.morning), 'صباح الخير');
      expect(ar.greetingWord(GreetingPeriod.evening), 'مساء الخير');
    });

    test('with a name, the lead-in ends in the separator', () {
      // `HomeScreen.tsx:26` — `<span ...>Good evening, </span>`, then the name in a
      // second ember span. The trailing space is load-bearing: without it the name
      // is welded to the comma.
      expect(
        const HomeStrings.en().greetingLead(
          GreetingPeriod.evening,
          hasName: true,
        ),
        'Good evening, ',
      );
    });

    test('without a name, the sentence is closed', () {
      // The case this phase makes reachable: the name comes from the session and
      // there may not be one.
      expect(
        const HomeStrings.en().greetingLead(
          GreetingPeriod.evening,
          hasName: false,
        ),
        'Good evening.',
      );
    });

    test('and the Arabic separator is U+060C, not U+002C', () {
      // Asserted as a **codepoint**, because the whole failure this guards is the
      // two characters rendering alike in a diff and differently on screen.
      expect(
        const HomeStrings.en().greetingSeparator,
        ', ',
        reason: 'Latin comma',
      );
      expect(
        const HomeStrings.ar().greetingSeparator,
        '، ',
        reason: 'ARABIC COMMA U+060C',
      );
      expect(const HomeStrings.ar().greetingSeparator.runes.first, 0x060C);
      expect(const HomeStrings.en().greetingSeparator.runes.first, 0x002C);
    });

    test('both arms close with the same full stop', () {
      for (final HomeStrings strings in <HomeStrings>[
        const HomeStrings.en(),
        const HomeStrings.ar(),
      ]) {
        for (final GreetingPeriod period in GreetingPeriod.values) {
          expect(
            strings.greetingLead(period, hasName: false).endsWith('.'),
            isTrue,
            reason: '$strings / ${period.name}',
          );
          expect(
            strings.greetingLead(period, hasName: true).endsWith(' '),
            isTrue,
            reason:
                '$strings / ${period.name} — the name needs a space after the '
                'separator or it is welded to it',
          );
        }
      }
    });
  });

  group('what this table must NOT contain', () {
    test('no reader name, because the prototype\'s is hard-coded', () {
      // `HomeScreen.tsx:27` renders `Miriam` and `ds.tsx:525` renders `MK`. There
      // is no user endpoint, so a name in this file would be a constant pretending
      // to be data. The real one comes from `AuthSession.displayName`.
      //
      // **A `HomeStrings` *field* is not the same question as a constant anywhere in
      // the feature**, and the second test below is the one that matters. This one
      // stays because the table is the most likely place for a name to land, and a
      // test that has been narrowed should say so.
      final List<String> fields = declaredFields();
      for (final String forbidden in <String>[
        'userName',
        'displayName',
        'name',
        'greeting',
      ]) {
        expect(
          fields,
          isNot(contains(forbidden)),
          reason: 'HomeStrings must not carry a reader name',
        );
      }
    });

    test('no prototype name or monogram appears ANYWHERE in the feature', () {
      // ## WHY THIS IS A **FEATURE-WIDE SOURCE SCAN** AND NOT A STRING-TABLE CHECK
      //
      // The rendered value was already pinned: `home_page_test.dart` asserts
      // `find.text('Miriam')` and `find.text('MK')` are `findsNothing`, so a *live*
      // hard-coded name is 2 failures. What nothing pinned was the **constant**.
      //
      // Measured: adding `const String kUnusedReaderName = 'Miriam';` and
      // `const String kUnusedMonogram = 'MK';` to `home_page.dart` passed all 1520
      // tests. A **private** unused constant is caught incidentally, by the
      // analyzer's `unused_element`; a **public** one is caught by nothing at all —
      // and one edit turns it live.
      //
      // ## THE MECHANISM IS `injection_test.dart`'s, ALREADY BUILT
      //
      // `test/app/di/injection_test.dart:642-677` walks `lib/features/home/`
      // line-by-line refusing `features/reading/` and `features/auth/` imports —
      // **the exact loop, in the exact shape, one file over**. It is not reused by
      // extraction because it asserts a different thing over a different root and
      // neither copy is long; what is reused is the *decision* to walk executable
      // lines of a directory rather than to inspect a widget tree, which is the part
      // that was missing.
      //
      // ## WHY **LITERALS** AND NOT IDENTIFIERS
      //
      // The literal is the thing that must not reappear, and matching the value is
      // what makes this total: a constant named `kFallbackDisplayName`, a parameter
      /// named `defaultName`, and a `switch` arm all contain `'Miriam'`, and all three
      // are caught. An identifier-based rule would have caught one of them.
      //
      // **Directives only** — the same reason the import scan skips doc comments: a
      // doc comment *naming* `Miriam` is this very file and `home_page.dart`'s table
      // telling a reader what it must not contain, and refusing that would make the
      // documentation of the defect into a violation of it.
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory(
        'lib/features/home',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final String line in entity.readAsLinesSync()) {
          final String trimmed = line.trimLeft();
          if (trimmed.startsWith('//')) continue;
          for (final String literal in prototypeIdentityLiterals) {
            if (trimmed.contains("'$literal'") ||
                trimmed.contains('"$literal"')) {
              offenders.add('${entity.path}: $trimmed');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a reader name or monogram is data, and data arrives through '
            '`AuthSession`. `HomeScreen.tsx:27` and `ds.tsx:525` wrote them as '
            'literals; this feature may not:\n${offenders.join('\n')}',
      );

      // Anti-vacuity, and the reason it is not one line. A scan that walks a
      // directory and finds nothing has proved nothing unless it also proves it
      // looked. `injection_test.dart`'s walk has the same guard for the same reason.
      expect(
        Directory('lib/features/home')
            .listSync(recursive: true)
            .whereType<File>()
            .length,
        greaterThan(5),
        reason:
            'the walk found almost no files, so the scan above passed over nothing '
            'rather than over a clean tree',
      );
    });

    test('no streak number, in any form', () {
      // `ds.tsx:507,516,525` hard-code `12`, `MK` and `Evangelion`. Two of those
      // three are gone; the wordmark is a product name and stays.
      final String source = File(
        'lib/features/home/presentation/home_strings.dart',
      ).readAsStringSync();
      for (final String line in source.split('\n')) {
        final String trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
          continue;
        }
        // A bare numeric literal in a value position, which is what a hard-coded
        // streak would be. Double-quoted because the pattern needs a `'` inside and
        // this project sets `prefer_single_quotes`, which permits that. The `"` is
        // written `\x22` rather than `\"` because a Dart raw string has no escapes,
        // so `\"` would close the literal instead of matching a quote.
        expect(
          RegExp(r"=\s*['\x22]?\d+['\x22]?\s*[,;]?\s*$").hasMatch(trimmed),
          isFalse,
          reason:
              'a literal number in a string table is a hard-coded value: $trimmed',
        );
      }
    });
  });
}
