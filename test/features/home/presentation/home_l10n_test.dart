import 'dart:convert';
import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';

/// The `/` strings that are **composed** rather than translated, and the two
/// arm-keyed reads that belong beside them — `home_l10n.dart`'s whole surface.
///
/// ## WHY THE PROTOTYPE IS PARSED HERE AND NOT QUOTED
///
/// `eva/redesign.html` carries the source of every value this file asserts: the
/// four greeting rows and the six category rows are two lines of a JS object
/// literal (`:925`, `:1033-1034`), and quoting them here would make the test and
/// the ARB two transcriptions of one line with nothing comparing them. So the
/// prototype is read at test time — the discipline
/// `home_geometry_test.dart` uses for the CSS and
/// `library_catalogue_local_data_source_test.dart` uses for the washes.
///
/// ## AND THE IDENTITY GATE IS STILL HERE, WITH A NEW NAME
///
/// The old suite scanned for the *old* prototype's literals (`Miriam` from
/// `HomeScreen.tsx`, `MK` from `ds.tsx`). The redesign has no avatar and so no
/// monogram — `MK` has nothing left to guard — and its own reader is `Mariam`
/// (`eva/redesign.html:515`, `:993`, and `Mariam Hanna` at `:587`, `:992`,
/// `:1059`). The scan walks the same directory for the same reason: a **public**
/// constant holding the value is caught by nothing else in the toolchain, which is
/// what the old suite measured by adding one and watching 1520 tests stay green.
const List<String> prototypeIdentityLiterals = <String>['Mariam'];

/// The prototype file this suite reads. Read-only — `eva/` is reference material
/// (AGENT_CONTEXT §2, §8).
const String prototype = 'eva/redesign.html';

void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('the greeting, transcribed from the prototype\'s own table', () {
    test('every period, in both arms, against `eva/redesign.html:925`', () {
      // `redesign.html:925` is one line of the I18N literal:
      // `morn:["good morning","صباح النور"], noon:[…], eve:[…], vigil:[…]`.
      // The pairs below are read out of that line, so a change to either arm is a
      // change to the prototype and this fails with the prototype's own words in
      // the message rather than with a quote that drifted.
      final Map<String, (String, String)> i18n = _i18nRow();
      final Map<GreetingPeriod, String> keys = <GreetingPeriod, String>{
        GreetingPeriod.morning: 'morn',
        GreetingPeriod.afternoon: 'noon',
        GreetingPeriod.evening: 'eve',
        GreetingPeriod.vigil: 'vigil',
      };
      for (final MapEntry<GreetingPeriod, String> period in keys.entries) {
        final (String enExpected, String arExpected) = i18n[period.value]!;
        expect(
          en.greetingWord(period.key),
          enExpected,
          reason: '${period.key.name} → `${period.value}`, English arm',
        );
        expect(
          ar.greetingWord(period.key),
          arExpected,
          reason: '${period.key.name} → `${period.value}`, Arabic arm',
        );
      }
    });

    test('and `vigil` is its own word, not the evening one at midnight', () {
      // The one the first table lost: 00:00–04:59 was transcribed as `evening`
      // because the enum had three members. `:925` gives the hours their own
      // value and `greeting_period_test.dart` walks them; this row pins the
      // *string*, which is where a silent alias would hide.
      expect(en.greetingWord(GreetingPeriod.vigil), 'night vigil');
      expect(ar.greetingWord(GreetingPeriod.vigil), 'سهر الليل');
      expect(
        en.greetingWord(GreetingPeriod.vigil),
        isNot(en.greetingWord(GreetingPeriod.evening)),
      );
    });
  });

  group('the composed strings, and why they are Dart and not ARB', () {
    test('no ARB key behind them takes a placeholder', () {
      // The recorded reason (home_l10n.dart's class doc): a **non-plural**
      // Arabic value holding Latin script fails `app_localizations_test.dart`'s
      // Latin gate, and a placeholder name is Latin — `{name}` in
      // `'سلام، {name}'` is the defect `auth_password_hint` would be. So the
      // shape is asserted here rather than trusted: every source key must have
      // neither a `{…}` slot in its value nor a `placeholders` block in its
      // metadata, on either arm.
      const List<String> sources = <String>[
        'homePeace',
        'homeGreetingSeparator',
        'homeScrolls',
        'homeOpenBooks',
        'homeSecondsOfSilence',
        'homeVerses',
      ];
      for (final String arm in <String>['en', 'ar']) {
        final Map<String, dynamic> table = _arb(arm);
        for (final String key in sources) {
          expect(
            table[key]!,
            isA<String>().having(
              (String value) => value.contains('{'),
              'contains a placeholder',
              isFalse,
            ),
            reason: '`$arm.$key` must be a whole literal',
          );
          // **`@key` metadata is normal; a `placeholders` block is not.** Every
          // ARB key carries a description under `@key`, so the presence of the
          // metadata proves nothing — the parameterisation lives one level down,
          // in `placeholders`, and that is the member this row reads.
          expect(
            (table['@$key'] as Map<String, dynamic>?)?['placeholders'],
            isNull,
            reason:
                '`$arm.@$key` declares placeholders, which is exactly the shape '
                'home_l10n.dart refuses: the composition is Dart\'s, and the '
                'reason is the Latin-script gate a placeholder name would fail',
          );
        }
      }
    });

    test('peaceWith joins the word, the separator and the FIRST name', () {
      // `redesign.html:993` — `'سلام، مريم'` / `'peace, Mariam'`, one literal
      // with the name baked in. The name is the session's and is not
      // translatable, so the join is Dart's; and it is the **first** token
      // because `:993`'s own `hiName` is `Mariam` where the journey's `jName`
      // (`:992`) is `Mariam Hanna`.
      expect(en.peaceWith('David Mina'), 'peace, David');
      expect(ar.peaceWith('مينا داود'), 'سلام، مينا');
    });

    test('and with no name, the sentence is the word alone', () {
      // The name comes from the session and there may not be one — the case
      // Phase 7's sign-out makes reachable. No separator, no dangling comma.
      expect(en.peaceWith(null), 'peace');
      expect(ar.peaceWith(null), 'سلام');
    });

    test('the separator is U+060C on the Arabic arm, U+002C on the Latin', () {
      // Asserted as a **codepoint**, because the whole failure this guards is the
      // two characters rendering alike in a diff and differently on screen.
      expect(en.homeGreetingSeparator, ', ', reason: 'Latin comma');
      expect(ar.homeGreetingSeparator, '، ', reason: 'ARABIC COMMA U+060C');
      expect(ar.homeGreetingSeparator.runes.first, 0x060C);
      expect(en.homeGreetingSeparator.runes.first, 0x002C);
      // And `peaceWith` really uses it, so a future edit that hard-codes a Latin
      // comma into the join fails here before it reaches a reader.
      expect(
        ar.peaceWith('مريم'),
        startsWith('سلام، '),
        reason: 'the join used the table\'s separator, not a typed comma',
      );
    });
  });

  group('firstNameOf — the pure function the greeting leans on', () {
    test('a two-word name gives its first token', () {
      // The prototype's own pair: `hiName` is `Mariam` (`:515`) where `jName` is
      // `Mariam Hanna` (`:992`). Painting the whole display name under a 23px
      // headline is the defect this function exists to prevent.
      expect(firstNameOf('David Mina'), 'David');
      expect(firstNameOf('مريم حنا'), 'مريم');
    });

    test('a one-word name is itself', () {
      // `split` on a string with no space returns the whole string, and the
      // prototype has no rule for inventing a split — camel case is not a word
      // boundary and guessing at one is guessing at a name.
      expect(firstNameOf('Mariam'), 'Mariam');
      expect(firstNameOf('مريم'), 'مريم');
    });

    test('leading and trailing space is trimmed before the split', () {
      // `AuthSession.displayName` is whatever the backend sent and nothing in
      // the client trims it, so `' David '` must not become `' '` — which is
      // what `indexOf(' ')` alone would give, and why the trim is in the
      // function rather than at the call site.
      expect(firstNameOf('  David Mina  '), 'David');
    });

    test('and a whitespace-only name is the empty string, not a space', () {
      // The third arm of the trim: `'   '` trims to `''`, `indexOf(' ')` on the
      // empty string is `-1`, and the function returns the empty string — which
      // `peaceWith` then joins as `peace, ` with nothing after it. That is the
      // honest rendering of an empty name and this row is what pins it, so a
      // future "fall back to peace alone" change is a *decision* recorded here
      // rather than a silent one.
      expect(firstNameOf('   '), '');
      expect(en.peaceWith('   '), 'peace, ');
    });
  });

  group('the numerals are the arm\'s, through `digits`', () {
    test('selahSeconds on the Latin arm uses ASCII, on Arabic Arabic-Indic', () {
      // `redesign.html:990` — `` `${N(selahDur)} ${tr('secs')}` `` where `N` is
      // `:988`'s digit-map. `digits` (`l10n.dart:105`) is this client's `N`, so
      // the *numeral* follows the arm the way the prototype's does and the
      // wording does not vary with the count.
      expect(en.selahSeconds(60), '60 seconds of silence');
      expect(ar.selahSeconds(60), '٦٠ ثانية من الصمت');
      expect(ar.selahSeconds(60).runes.first, 0x0660 + 6);
    });

    test('and one second is worded identically to sixty', () {
      // The plural keys are the only ARB keys allowed to vary with a number
      // (home_l10n.dart's class doc), and none of these three is a plural — so
      // asserting 1 alongside 60 is what catches a key that quietly became a
      // plural and started rendering "1 seconds".
      expect(en.selahSeconds(1), '1 seconds of silence');
      expect(ar.selahSeconds(1), '١ ثانية من الصمت');
    });

    test('scrollsOpen is the prototype\'s ` · ` literal with live counts', () {
      // `redesign.html:930` — `libCount:["6 scrolls · 4 open","٦ دروج · ٤
      // مفتوحة"]`, one literal with the numbers baked in. The middle dot is
      // U+00B7 and the numbers are the arm's; the *open* count is derived from
      // the catalogue's `sealed` flags by the carousel and passed in, which is
      // why the function takes both numbers rather than subtracting.
      expect(en.scrollsOpen(scrolls: 6, open: 4), '6 scrolls · 4 open');
      expect(ar.scrollsOpen(scrolls: 6, open: 4), '٦ دروج · ٤ مفتوحة');
      expect(
        en.scrollsOpen(scrolls: 6, open: 4).contains('·'),
        isTrue,
        reason: 'the separator is the prototype\'s own middle dot',
      );
    });

    test('and verseCount is `{n} verses`, the card caption\'s count', () {
      // `redesign.html:1313` — `N(b.en.length)` and `tr('verses')`. Asserted at
      // 4 and 6 because those are the prototype's own excerpt lengths, and the
      // Arabic numerals here are what `library_carousel_test.dart` sees in the
      // rendered caption.
      expect(en.verseCount(6), '6 verses');
      expect(en.verseCount(4), '4 verses');
      expect(ar.verseCount(6), '٦ آيات');
    });
  });

  group(
    'retryLabelFamily — the arm-based rule, and why it is not arabicAware',
    () {
      test('the Latin arm renders the label in the UI family', () {
        expect(en.retryLabelFamily, EvaTypography.uiFamily);
      });

      test('and the Arabic arm renders it in the Arabic family', () {
        expect(ar.retryLabelFamily, EvaTypography.arabicFamily);
      });

      test('and the two differ, so a family regression is visible', () {
        // The assertion that makes the two rows above mean something: if the
        // family ever became a constant, both arms would pass their own row and
        // the Arabic arm would render tofu in every ErrorView.
        expect(en.retryLabelFamily, isNot(ar.retryLabelFamily));
      });
    },
  );

  group('LibraryCategory.label, against `eva/redesign.html:1033-1034`', () {
    test('all six categories, in both arms', () {
      // The prototype's `CATS` is a six-element map and the ARB's six
      // `homeCategory*` keys are its transcription, so this row reads the JS and
      // asks the table to agree — the same discipline as the greeting row above.
      final Map<String, (String, String)> cats = _catsTable();
      expect(cats, hasLength(6), reason: 'the prototype names six categories');
      final Map<LibraryCategory, String> keys = <LibraryCategory, String>{
        LibraryCategory.poetry: 'poetry',
        LibraryCategory.gospel: 'gospel',
        LibraryCategory.torah: 'torah',
        LibraryCategory.prophets: 'prophets',
        LibraryCategory.history: 'history',
        LibraryCategory.apocalypse: 'apocalypse',
      };
      for (final MapEntry<LibraryCategory, String> category in keys.entries) {
        final (String enExpected, String arExpected) = cats[category.value]!;
        expect(
          category.key.label(en),
          enExpected,
          reason: '${category.key.name} → `${category.value}`, English arm',
        );
        expect(
          category.key.label(ar),
          arExpected,
          reason: '${category.key.name} → `${category.value}`, Arabic arm',
        );
      }
    });
  });

  group('LibraryBook.nameFor, by DIRECTION and not by locale', () {
    test(
      'the Latin direction reads `nameEn`, the Arabic direction `nameAr`',
      () {
        final LibraryBook book = _bookFromPrototype('psalms');
        expect(book.nameFor(TextDirection.ltr), 'psalms');
        expect(book.nameFor(TextDirection.rtl), 'المزامير');
      },
    );

    test('and the same pick the last-light card makes, for the same reason', () {
      // `redesign.html:1202` picks `b.arName` for the last-light card's
      // reference exactly as `:1313` does for the carousel's title — one rule,
      // two call sites, and this row exists so the second call site cannot be
      // "fixed" to the other rule without a failure naming it.
      final LibraryBook sealed = _bookFromPrototype('revelation');
      expect(sealed.nameFor(TextDirection.rtl), 'الرؤيا');
      expect(sealed.nameFor(TextDirection.ltr), 'revelation');
      // Sealed books carry names too, which is what makes a sealed card a
      // *named* card rather than a lock: the name is data the catalogue holds
      // even where the count is absent.
      expect(sealed.verseCount, isNull);
    });
  });

  group('what this feature must NOT contain', () {
    test('no prototype name appears ANYWHERE in the feature', () {
      // ## WHY THIS IS A **FEATURE-WIDE SOURCE SCAN** AND NOT A STRING-TABLE CHECK
      //
      // The rendered value was already pinned: `home_page_test.dart` asserts the
      // greeting is the *session's* name, so a *live* hard-coded name is a
      // failure there. What nothing pinned was the **constant** — and the old
      // suite measured that: adding a public constant holding the value passed
      // every test in the repo. A **private** one is caught incidentally by the
      // analyzer's `unused_element`; a **public** one is caught by nothing at
      // all, and one edit turns it live.
      //
      // The mechanism walks executable lines of a directory. It is not reused by
      // extraction because it asserts a different thing over a different root;
      // what is reused is the *decision* to walk source rather than inspect a
      // widget tree.
      //
      // **Directives only** — a doc comment *naming* the value is this very file
      // and `home_l10n.dart`'s own table telling a reader what it must not
      // contain, and refusing that would make the documentation of the defect
      // into a violation.
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
            'a reader name is data, and data arrives through `AuthSession`. '
            '`redesign.html:515` and `:993` write it as a literal; this feature '
            'may not:\n${offenders.join('\n')}',
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
            'the walk found almost no files, so the scan above passed over '
            'nothing rather than over a clean tree',
      );
    });

    test('and no streak number, in any form', () {
      // `eva/redesign.html:1059` hard-codes `streak:12` and `:989` writes
      // `N(12)` twice. The wordmark is a product name and stays.
      //
      // ## THIS GATE GOT **STRONGER**, AND THE REASON IS THE FORMAT
      //
      // The old version regex-scanned the lines of one `.dart` file. This one
      // parses both ARB arms and asks whether **any key's value is nothing but
      // digits** — which is the shape a hard-coded streak takes (`"12"`), and
      // which no amount of knowing the key set could see.
      //
      // It also covers a file the old scan never looked at. A number typed into
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
                'source for one. `redesign.html:989` wrote `N(12)`.',
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

/// The four greeting rows of the prototype's I18N literal.
///
/// `eva/redesign.html:925` writes four pairs on one line:
/// `morn:[…], noon:[…], eve:[…], vigil:[…]`. The regex reads each pair's two
/// quoted strings; a key that moved, or grew a third element, is a `null` here and
/// the caller's `!` fails the row with the prototype's own line in the reason.
Map<String, (String, String)> _i18nRow() {
  final String html = File(prototype).readAsStringSync();
  // The four keys `hourKey()` returns (`:983-984`), in the order the table writes
  // them. The *values* are deliberately not restated here — `_pair` reads them out
  // of the file, and restating them would be a second transcription of the line
  // this row exists to compare against.
  const List<String> keys = <String>['morn', 'noon', 'eve', 'vigil'];
  return <String, (String, String)>{
    for (final String key in keys) key: _pair(html, key),
  };
}

/// The six rows of the prototype's `CATS` literal — `eva/redesign.html:1033-1034`.
Map<String, (String, String)> _catsTable() {
  final String html = File(prototype).readAsStringSync();
  // **Scoped to the literal, because the pair shape is not unique.** Every row of
  // the I18N table (`:924-977`) is also `key:["en","ar"]`, and an unanchored
  // search across the whole file matched 134 of them — the first run of this row
  // failed with `has length of <134>` on an expectation of 6. So the `CATS={…}`
  // object is cut out first and the pair regex runs inside it.
  final int start = html.indexOf('const CATS={');
  if (start < 0) {
    throw StateError(
      'the prototype has no `CATS` literal any more. The category labels moved, '
      'or the table was renamed, and this harness must read them again.',
    );
  }
  final String cats = html.substring(start, html.indexOf('};', start));
  final Iterable<RegExpMatch> matches = RegExp(r'(\w+):\["([^"]*)","([^"]*)"\]')
      .allMatches(cats);
  return <String, (String, String)>{
    for (final RegExpMatch match in matches)
      match.group(1)!: (match.group(2)!, match.group(3)!),
  };
}

/// One `key:["en","ar"]` pair out of the prototype's I18N literal.
(String, String) _pair(String html, String key) {
  final RegExpMatch? match = RegExp('$key:\\["([^"]*)","([^"]*)"\\]')
      .firstMatch(html);
  if (match == null) {
    throw StateError(
      '`$key` is no longer a row of the prototype\'s I18N literal. A greeting '
      'that moved, or grew a third element, is a change this harness must read — '
      'and one it cannot read through a rule at all.',
    );
  }
  return (match.group(1)!, match.group(2)!);
}

/// One book out of the prototype's `BOOKS` / `SEALED` literals, by id.
///
/// The four open books are declared as `{name:…,arName:…,cat:…}` (`:1005`, `:1013`,
/// `:1019`, `:1025`) and the two sealed ones as `{id:…,name:…}` (`:1033`, `:1034`),
/// so one regex cannot read both and two are cheaper than a parser.
LibraryBook _bookFromPrototype(String id) {
  final String html = File(prototype).readAsStringSync();
  final RegExp open = RegExp(
    "\\{name:'([^']+)',arName:'([^']+)',cat:'([^']+)'",
  );
  for (final RegExpMatch match in open.allMatches(html)) {
    if (match.group(1) == id) {
      return LibraryBook(
        id: id,
        nameEn: match.group(1)!,
        nameAr: match.group(2)!,
        category: LibraryCategory.values.firstWhere(
          (LibraryCategory c) => c.name == match.group(3),
        ),
        sealed: false,
        bloomArgb: 0,
      );
    }
  }
  final RegExp sealed = RegExp(
    "\\{id:'([^']+)',name:'([^']+)',arName:'([^']+)',cat:'([^']+)'",
  );
  for (final RegExpMatch match in sealed.allMatches(html)) {
    if (match.group(1) == id) {
      return LibraryBook(
        id: id,
        nameEn: match.group(2)!,
        nameAr: match.group(3)!,
        category: LibraryCategory.values.firstWhere(
          (LibraryCategory c) => c.name == match.group(4),
        ),
        sealed: true,
        bloomArgb: 0,
      );
    }
  }
  throw StateError(
    '`$id` is no longer a book of the prototype\'s `BOOKS` or `SEALED` '
    'literal. A book that moved, or lost its name, is a change this harness must '
    'read.',
  );
}
