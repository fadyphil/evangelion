import 'dart:convert';
import 'dart:io';

import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The identity literals the prototype hard-codes and this feature must not.
///
/// Two values, and both are measured in `eva/src`: `HomeScreen.tsx:27`'s `Miriam` in
/// the greeting and `ds.tsx:525`'s `MK` in the avatar. Neither has a backend behind
/// it — there is no user endpoint, and AGENT_CONTEXT §2 decision 3 makes login
/// UI-only — so both arrive through `AuthSession` at runtime and neither may exist as
/// a literal anywhere under `lib/features/home/`.
///
/// **Literals and not identifiers**, deliberately: a constant, a parameter default
/// and a `switch` arm all contain the same quoted value, and only the value is the
/// thing that must not come back.
///
/// ## WHY THIS GATE MOVED TO THIS FILE AND DID NOT MOVE WITH THE TABLE
///
/// It lived in `home_strings_test.dart`, and the *other* half of it — "the table has
/// no `userName` field" — died with the table, because a key set is now the ARB's
/// and `test/l10n/app_localizations_test.dart` owns that. The scan is a different
/// kind of gate and it stays in the feature: it walks **executable lines of a
/// directory**, and no amount of knowing the ARB's keys can tell you that a private
/// constant crept back into `home_page.dart`.
const List<String> prototypeIdentityLiterals = <String>['Miriam', 'MK'];

void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('the greeting', () {
    test('the word is a switch over all three periods', () {
      // §4's rule: a `switch` expression, exhaustive over the enum. A
      // `Map<GreetingPeriod, String>` would return `null` for a member added
      // tomorrow; this cannot, and the analyzer would refuse the new arm.
      expect(en.greetingWord(GreetingPeriod.morning), 'Good morning');
      expect(en.greetingWord(GreetingPeriod.afternoon), 'Good afternoon');
      expect(en.greetingWord(GreetingPeriod.evening), 'Good evening');

      expect(ar.greetingWord(GreetingPeriod.morning), 'صباح الخير');
      expect(ar.greetingWord(GreetingPeriod.evening), 'مساء الخير');
    });

    test('with a name, the lead-in ends in the separator', () {
      // `HomeScreen.tsx:26` — `<span ...>Good evening, </span>`, then the name in a
      // second ember span. The trailing space is load-bearing: without it the name
      // is welded to the comma.
      expect(
        en.greetingLead(GreetingPeriod.evening, hasName: true),
        'Good evening, ',
      );
    });

    test('without a name, the sentence is closed', () {
      // The case Phase 7 made reachable: the name comes from the session and there
      // may not be one.
      expect(
        en.greetingLead(GreetingPeriod.evening, hasName: false),
        'Good evening.',
      );
    });

    test('and the Arabic separator is U+060C, not U+002C', () {
      // Asserted as a **codepoint**, because the whole failure this guards is the
      // two characters rendering alike in a diff and differently on screen.
      expect(en.homeGreetingSeparator, ', ', reason: 'Latin comma');
      expect(ar.homeGreetingSeparator, '، ', reason: 'ARABIC COMMA U+060C');
      expect(ar.homeGreetingSeparator.runes.first, 0x060C);
      expect(en.homeGreetingSeparator.runes.first, 0x002C);
    });

    test('both arms close with the same full stop', () {
      // Arabic uses the same codepoint for a full stop; what differs is the
      // *placement* convention, which is a typographic setting no string carries.
      for (final AppLocalizations strings in <AppLocalizations>[en, ar]) {
        for (final GreetingPeriod period in GreetingPeriod.values) {
          expect(
            strings.greetingLead(period, hasName: false).endsWith('.'),
            isTrue,
            reason: '${strings.localeName} / ${period.name}',
          );
          expect(
            strings.greetingLead(period, hasName: true).endsWith(' '),
            isTrue,
            reason:
                '${strings.localeName} / ${period.name} — the name needs a space '
                'after the separator or it is welded to it',
          );
        }
      }
    });

    test('and the lead-in is a FUNCTION of the two, not a stored pair', () {
      // One implementation is the point: two `hasName ? … : …` expressions are one
      // refactor apart from disagreeing, and the disagreement would show up in one
      // arm only.
      expect(
        en.greetingLead(GreetingPeriod.evening, hasName: true),
        isNot(en.greetingLead(GreetingPeriod.evening, hasName: false)),
      );
    });
  });

  group('what this feature must NOT contain', () {
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
      // The mechanism is `injection_test.dart`'s, already built: walk executable
      // lines of a directory. It is not reused by extraction because it asserts a
      // different thing over a different root and neither copy is long; what is
      // reused is the *decision* to walk source rather than inspect a widget tree.
      //
      // **Directives only** — a doc comment *naming* `Miriam` is this very file and
      // `home_page.dart`'s own table telling a reader what it must not contain, and
      // refusing that would make the documentation of the defect into a violation.
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
      // looked.
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

    test('and no streak number, in any form', () {
      // `ds.tsx:507,516,525` hard-code `12`, `MK` and `Evangelion`. Two of those
      // three are gone; the wordmark is a product name and stays.
      //
      // ## THIS GATE GOT **STRONGER**, AND THE REASON IS THE FORMAT
      //
      // The old version regex-scanned the lines of one `.dart` file. This one parses
      // both ARB arms and asks whether **any key's value is nothing but digits** —
      // which is the shape a hard-coded streak takes (`"12"`), and which no amount
      // of knowing the key set could see.
      //
      // It also now covers a file the old scan never looked at. A number typed into
      // `app_ar.arb` is a JSON string, not a Dart literal, so the old `.dart`
      // scanner would have passed straight over it.
      for (final String arm in <String>['en', 'ar']) {
        for (final MapEntry<String, dynamic> entry in _arb(arm).entries) {
          if (entry.key.startsWith('@')) continue;
          expect(
            RegExp(r'^\d+$').hasMatch(entry.value.toString().trim()),
            isFalse,
            reason:
                'ar/en `$arm.${entry.key}` is the bare number '
                '`${entry.value}` — a literal count in a string table is a '
                'hard-coded value, and the live `current_streak` is the only '
                'source for one. `ds.tsx:507` wrote `12`.',
          );
        }
      }
    });
  });
}

/// The decoded ARB for [arm] — `lib/l10n/app_<arm>.arb`.
Map<String, dynamic> _arb(String arm) =>
    jsonDecode(File('lib/l10n/app_$arm.arb').readAsStringSync())
        as Map<String, dynamic>;
