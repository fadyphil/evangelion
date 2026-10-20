import 'dart:convert';
import 'dart:io';

import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// The prototype file this suite reads. Read-only — `eva/` is reference material
/// (AGENT_CONTEXT §2, §8), and `reading_geometry_test.dart` / `home_l10n_test.dart`
/// read it the same way rather than quoting it.
const String prototype = 'eva/redesign.html';

/// The `/reading` sentences that are **composed** rather than translated —
/// `reading_l10n.dart`'s whole surface — and the seven ARB rows behind them.
///
/// ## WHAT THE PREVIOUS VERSION OF THIS FILE ASSERTED, AND WHY IT IS GONE
///
/// It asserted one thing, well: `readingCaptionFor`, the ARB's only `/reading`
/// plural, selected all six of Arabic's agreement classes, and the `two` class
/// rendered `٢ سؤالان` where the hand-rolled table it replaced had said
/// `٢ أسئلة`. **That key is deleted in Task 5.3, and the dual goes with it**,
/// which is a real loss of Arabic grammar and is written here rather than left to
/// be rediscovered as a bug.
///
/// ## AND THE MOVEMENT IS THREE PLURAL KEYS DOWN TO TWO, NOT A COUNT OF ONE FEATURE
///
/// `readingCaptionFor` was **one of exactly three `plural` keys in the ARB pair**
/// — `resultTotalCaption`, `leaderboardRowSemantics` and it. Task 5.3 leaves
/// **two**. That number is asserted as a **named set** in
/// `test/l10n/app_localizations_test.dart`'s `and no OTHER key claims to be a
/// plural`, and it stays at two by coincidence: the group was already called "the
/// two ICU plurals" before Phase 1 added the third. A future reader who finds two
/// where a comment once said three needs the argument below, not the diff — and a
/// reader who wants the manifest to be about `/reading` alone should note it never
/// was: all three plurals are other features' strings.
///
/// The reason is the prototype. `eva/redesign.html:1347` writes the caption as
///
/// ```js
/// el('qctaLabel').textContent = `${tr('quiz')} · ${N(qEff)} ${tr('questions')}`;
/// ```
///
/// — one word for every count, taken from a table whose `questions` row carries
/// **no** ICU forms at all. Adopting the caption means adopting the table, and a
/// plural the prototype does not have is a client inventing a design decision.
/// This is the same trade `home_l10n.dart` already made for `verseCount`,
/// `selahSeconds` and `scrollsOpen`, with the same recorded loss, so this is a
/// pattern rather than a precedent being set here.
///
/// **What the reader sees at a count of 2, stated plainly:** `اختبار · ٢ أسئلة`,
/// where correct Arabic is `اختبار · سؤالان`. That is the cost, and it buys a
/// caption that is byte-comparable with `:1347`.
///
/// **What replaced the assertions:** three composed methods, seven whole-literal
/// ARB rows, and the discipline `home_l10n_test.dart` established — the
/// prototype is **parsed at test time** and the generated getters are compared
/// against the parsed pairs, so the ARB cannot drift from `redesign.html` without
/// something going red.
///
/// ## AND WHY THE PROTOTYPE IS PARSED HERE AND NOT QUOTED
///
/// Quoting the seven rows into this file would make the test and the ARB two
/// transcriptions of one line with nothing comparing them — which is precisely
/// the failure the ARB pair already made once, recorded below.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();
  final AppLocalizationsAr ar = AppLocalizationsAr();

  group('the CTA caption, from the prototype\'s own table', () {
    test('both arms, at a singular and a plural count', () {
      // The verify item. `reading_l10n.dart`'s doc records the shape; this row
      // checks the words came out of `redesign.html` rather than out of a comment
      // in this file, by composing the expectation from the parsed rows.
      final Map<String, (String, String)> i18n = _i18nRow();
      expect(
        en.quizCaption(3),
        '${i18n['quiz']!.$1} · ${en.digits(3)} ${i18n['questions']!.$1}',
        reason: 'the Latin arm, three questions',
      );
      expect(
        ar.quizCaption(3),
        '${i18n['quiz']!.$2} · ${ar.digits(3)} ${i18n['questions']!.$2}',
        reason: 'the Arabic arm, three questions',
      );
      // **And the literal, so a reader does not have to run the suite to see the
      // sentence.** The prototype's own markup at `:546-548` draws
      // `quiz · 3 questions` inside `#qctaLabel`.
      expect(en.quizCaption(3), 'quiz · 3 questions');
      expect(ar.quizCaption(3), 'اختبار · ٣ أسئلة');
      // One word for one and for three. **This is the row that would fail if a
      // future editor "restores" the plural**: `:1347` has no ICU syntax, so
      // `questions` cannot change with the count and there is no English
      // singular to restore it to.
      expect(en.quizCaption(1), 'quiz · 1 questions');
      expect(ar.quizCaption(1), 'اختبار · ١ أسئلة');
    });

    test('a count of zero is still a caption, and it is reachable', () {
      // `TodayReadingMapper` **skips** an unreadable question rather than refusing
      // the passage (AGENT_CONTEXT recorded decision 40), so `questionCount == 0`
      // is a state the cubit can produce. `reading_page.dart` gates the sticky CTA
      // on `passage.questionCount > 0`, so a reader never *sees* this sentence —
      // and the method is still honest rather than throwing or inventing a
      // singular, which is the property worth pinning while the gate exists.
      expect(en.quizCaption(0), 'quiz · 0 questions');
      expect(ar.quizCaption(0), 'اختبار · ٠ أسئلة');
      expect(en.quizCaption(0), isNot(en.quizCaption(1)));
    });

    test('the separator is U+00B7, and NOT the ARABIC COMMA', () {
      // Asserted as a **codepoint**, because the whole failure this guards is two
      // characters that render alike in a diff and differently on screen.
      //
      // `home_l10n_test.dart` pins `homeGreetingSeparator` at U+060C
      // (ARABIC COMMA) because `:993` writes `سلام، مريم` — one Arabic sentence.
      // `:1347` writes ` · ` on **both** arms, so this separator is arm-independent
      // and a second grammar's separator must not leak in: reusing U+060C here
      // would put an Arabic comma into the English caption.
      //
      // ## `runes.elementAt(1)`, NOT `runes.first` — MEASURED
      //
      // Home's separator is `', '`, so the punctuation is the FIRST rune and
      // `runes.first` names it. **This one is `' · '` — the middle dot is the
      // middle character**, and `runes.first` returned `32` (U+0020) on the first
      // run of this row. Asserting the whole triple is the version that cannot be
      // got wrong that way: a dropped space is as much a transcription error as a
      // wrong codepoint, and `:1347`'s ` · ` has a space on each side.
      const String separator = ' · ';
      expect(separator.runes, <int>[
        0x20,
        0x00B7,
        0x20,
      ], reason: 'U+0020 · U+00B7 · U+0020, exactly as `:1347` writes it');
      expect(en.quizCaption(1).contains(separator), isTrue);
      expect(ar.quizCaption(1).contains(separator), isTrue);
      expect(
        en.quizCaption(1).contains('،'),
        isFalse,
        reason: 'the Arabic arm keeps the prototype\'s middle dot too',
      );
      expect(ar.quizCaption(1).contains('،'), isFalse);
      // And it is the prototype's: both arms draw the same ` · `, so a future edit
      // that reaches for `homeGreetingSeparator` fails on BOTH arms rather than one.
      expect(
        en.quizCaption(1).split(separator),
        hasLength(2),
        reason: 'two clauses, one separator, no more',
      );
    });

    test('the numeral is the ARM\'s, and U+0663 is Arabic-block', () {
      // `redesign.html:982`'s `N()` maps ASCII digits to `٠١٢٣٤٥٦٧٨٩` on the
      // Arabic arm; `digits` (`l10n.dart`) is this client's `N`. The codepoint is
      // the load-bearing half: **U+0663 is an Arabic-block character**, so it is
      // tofu in the mono face for exactly the reason scripture is, which is why
      // `reading_glyph_test.dart` reads the rendered family of this string.
      //
      // ## THE CLAIM IS "THE ONLY DIGIT", NOT "THE FIRST CHARACTER" — MEASURED
      //
      // The first version asserted `runes.first == 0x0663` and read **1575**,
      // which is U+0627 ALEF — the caption opens with `اختبار`, not with the
      // numeral, and it never could have been otherwise. Asserting the first rune
      // would only hold for a string that begins with a count. Collecting the
      // digits and requiring exactly `[U+0663]` says the stronger thing: the
      // Arabic arm carries one digit and it is Arabic-Indic, with no ASCII twin
      // hiding behind the word `questions`.
      expect(ar.quizCaption(3).runes.where(_isArabicIndicDigit), <int>[
        0x0663,
      ], reason: 'U+0663, and it is the only digit in the Arabic caption');
      expect(en.quizCaption(3).runes.where(_isAsciiDigit), <int>[
        0x33,
      ], reason: 'U+0033 on the Latin arm, and it is the only one there too');
      expect(
        ar.quizCaption(3).contains('3'),
        isFalse,
        reason:
            'an ASCII digit on the Arabic arm is the §2.1 numeral regression',
      );
      expect(en.quizCaption(3), isNot(contains('٣')));
    });

    test('and the caption carries no duration, because the payload has none', () {
      // `ReadingEnScreen.tsx:89` wrote `5 questions · about a minute` and `:31`
      // wrote `Chapter 1 · 4 min`. **Neither duration has a source** — there is no
      // duration field anywhere in `GET /readings/today/{lang}` (verified live
      // against `HEAD = 4a1c834`, AGENT_CONTEXT §5) — and inventing one from a
      // word count is inventing a measurement. This survives the plural's
      // retirement unchanged, because the complaint was about the *sentence*, not
      // the plural.
      expect(
        en.quizCaption(5),
        isNot(contains('5 questions · about a minute')),
        reason: 'the prototype\'s literal was false by a factor of five anyway',
      );
      expect(en.quizCaption(5).contains('min'), isFalse);
      expect(en.quizCaption(5).contains('minute'), isFalse);
    });
  });

  group('crumbMeta — the sub-bar\'s three clauses', () {
    test('all three, in both arms, composed from the prototype\'s rows', () {
      final Map<String, (String, String)> i18n = _i18nRow();
      expect(
        en.crumbMeta(category: 'poetry', verses: 6, litStars: 3),
        'poetry · ${en.digits(6)} ${i18n['verses']!.$1} · '
        '${i18n['sky']!.$1} ${en.digits(3)}',
        reason: 'the Latin arm',
      );
      expect(
        ar.crumbMeta(category: 'poetry', verses: 6, litStars: 3),
        'poetry · ${ar.digits(6)} ${i18n['verses']!.$2} · '
        '${i18n['sky']!.$2} ${ar.digits(3)}',
        reason:
            'the Arabic arm — note the CATEGORY stays Latin, because the caller '
            'passes `LibraryCategory.label(strings)` and a category is a '
            'catalogue fact, not a sentence this method may invent',
      );
      // The literal, for the reader. `:546` draws `poetry · 6 verses · en` as the
      // pre-JS markup and `:1346` replaces it with the three-clause form.
      expect(
        en.crumbMeta(category: 'poetry', verses: 6, litStars: 3),
        'poetry · 6 verses · sky 3',
      );
      expect(
        ar.crumbMeta(category: 'poetry', verses: 6, litStars: 3),
        'poetry · ٦ آيات · سماء ٣',
      );
    });

    test('every argument renders the number the CALLER passed', () {
      // The discriminating row. A method that consulted the prototype's catalogue,
      // or hard-coded `:546`'s `6`, would render `6` for both of these and the
      // first row above would still pass.
      expect(
        en.crumbMeta(category: 'gospel', verses: 5, litStars: 0),
        'gospel · 5 verses · sky 0',
      );
      expect(
        en.crumbMeta(category: 'gospel', verses: 1, litStars: 12),
        'gospel · 1 verses · sky 12',
      );
      expect(
        ar.crumbMeta(category: 'gospel', verses: 5, litStars: 12),
        'gospel · ٥ آيات · سماء ١٢',
      );
      // **Zero lit stars is honest, not a placeholder.** `:1131` opens
      // `let skyN=0` and the sky observer at `:1145` increments it, so a reader
      // who has scrolled nothing yet is shown `sky 0`. Asserting it keeps the
      // method from growing a "no data" branch the prototype does not have.
      expect(
        en.crumbMeta(category: 'poetry', verses: 6, litStars: 0),
        endsWith('sky 0'),
      );
      // And the numeral is the arm's in every clause, which is why `:1346`'s
      // `N(skyN)` is `digits` here too.
      expect(
        ar.crumbMeta(category: 'poetry', verses: 6, litStars: 3).runes,
        contains(0x0666),
        reason: 'U+0666, from the `٦` of the verse count',
      );
    });

    test('`verses` is the REAL passage count, and the prototype\'s is a fiction', () {
      // ## THE DIVERGENCE, AND WHY THE RIGHT ANSWER IS THE CALLER\'S NUMBER
      //
      // `eva/redesign.html:1346` writes
      // `` `${CATS[b.cat][li()]} · ${N(b.en.length)} ${tr('verses')}` `` — and
      // `b.en.length` is the **catalogue's fictional excerpt length**. ADR-0022
      // killed that fiction on `/`: `library_catalogue_local_data_source_test.dart`
      // and `home_l10n.dart`'s `verseCount` both carry it only because `/` draws a
      // catalogue card, and the record says which surfaces have a measured
      // endpoint behind them.
      //
      // `/reading` is not drawing a catalogue card. It is drawing the server's
      // passage — `reading_page.dart` passes `passage.verses` down to
      // `ScriptureBlock` — and the crumb sits **directly above the verses it
      // counts**. So rendering the fiction's excerpt length there would be the
      // fiction leaking back into the one line a reader uses to check how long
      // the passage they are about to read is. AGENT_CONTEXT §5 records the
      // seeded reading as John 3:1-5, five verses.
      //
      // **Measured, not assumed:** the prototype's psalms excerpt is six quoted
      // verses, which is why `:546`'s own markup reads `poetry · 6 verses`. So
      // the two numbers genuinely differ for the same book, and this row shows
      // the method rendering the caller's five rather than the fiction's six.
      expect(
        _excerptVerseCount('psalms'),
        6,
        reason:
            'the fiction `:1346` would read: six quoted entries in '
            '`BOOKS.psalms.en`, which is where `:546`\'s `poetry · 6 verses` '
            'comes from',
      );
      expect(
        en.crumbMeta(category: 'poetry', verses: 5, litStars: 3),
        'poetry · 5 verses · sky 3',
      );
      expect(
        en.crumbMeta(category: 'poetry', verses: 5, litStars: 3),
        isNot(contains('6')),
        reason:
            'and it is not the catalogue\'s six. If this ever fails because a '
            'future reader re-transcribed `:1346` literally, the fiction is the '
            'bug — see ADR-0022',
      );
    });
  });

  group('listeningUnavailable — the suffix is a PARAMETER', () {
    test('both arms, with the prototype\'s own em dash', () {
      // `reading_l10n.dart`'s doc records why the control is inert: `:1399` is the
      // whole of the prototype's listen behaviour and `speechSynthesis`,
      // `AudioContext`, `new Audio` and `.play()` appear **zero** times in the
      // file. So the name a screen reader hears carries the reason, exactly as
      // `/login`'s two ghost pills do, and `/`'s deleted `SealFab` items did.
      expect(
        en.listeningUnavailable(en.readingUnavailableSuffix),
        'listen — unavailable in this build',
      );
      expect(
        ar.listeningUnavailable(ar.readingUnavailableSuffix),
        'استمع — غير متاح في هذه النسخة',
      );
      // The join is U+2014 EM DASH with spaces, not the `·` of the crumb — a third
      // punctuation in three sentences, which is exactly why each is asserted.
      // **`elementAt(1)` again**, for the reason the caption's separator row
      // records: `' — '` opens with U+0020, so `runes.first` reads 32.
      expect(' — '.runes, <int>[0x20, 0x2014, 0x20]);
      expect(en.listeningUnavailable('X').runes, contains(0x2014));
    });

    test('and the method must not PICK a suffix — the three screens differ', () {
      // ## WHY THE SUFFIX IS AN ARGUMENT
      //
      // `/login`, `/` and `/reading` each own a differently-worded suffix key
      // (`authUnavailableSuffix`, `homeUnavailableSuffix`,
      // `readingUnavailableSuffix`), and the first two hold the **same** string
      // while `quizUnavailableSuffix` says something else entirely.
      // `app_localizations_test.dart` asserts that shape for all four. A method
      // that baked one in would silently pick a wording for three screens, and
      // the disagreement would be invisible exactly where it is most expensive:
      // a control that is dead for a *different* reason than the name says.
      //
      // So the negative control is a sentinel no ARB key can produce — if the
      // method concatenated a table value, this is where it goes red.
      const String sentinel = 'ZZZ-SENTINEL';
      expect(en.listeningUnavailable(sentinel), 'listen — $sentinel');
      expect(ar.listeningUnavailable(sentinel), 'استمع — $sentinel');
      expect(
        en.listeningUnavailable(sentinel),
        isNot(en.listeningUnavailable(en.readingUnavailableSuffix)),
      );
      // And the two arms' own suffixes are not each other, which is the claim
      // the "one word for every count" style of test cannot make.
      expect(en.listeningUnavailable('a'), isNot(en.listeningUnavailable('b')));
    });
  });

  group('the seven new rows take NO placeholder, on either arm', () {
    test('neither a `{…}` slot nor a `placeholders` block, in either ARB', () {
      // ## THE RECORDED REASON, FROM `reading_l10n.dart`'s OWN DOC
      //
      // A placeholder **name** is Latin — `{count}`, `{verses}` — and
      // `app_localizations_test.dart`'s Latin gate fails any Arabic-arm value
      // holding Latin script outside its documented set. So a number-taking ARB
      // key on the Arabic arm is a defect by construction, and the composition is
      // Dart's instead. Home made the same call for six keys and asserts the
      // shape the same way (`home_l10n_test.dart`'s `no ARB key behind them takes
      // a placeholder`).
      //
      // ## AND THE METADATA SHAPE MATTERS MORE THAN IT LOOKS
      //
      // **Every** key in both files carries an `@key` block with a `description`,
      // so "the key has metadata" proves nothing. The parameterisation lives one
      // level down, in `placeholders`, and that is the member this row reads — a
      // check written against `@key` existing would pass over every key in the
      // table.
      const List<String> sources = <String>[
        'readingVerses',
        'readingQuiz',
        'readingQuestions',
        'readingListen',
        'readingSky',
        'readingBookmarkOn',
        'readingBookmarkOff',
      ];
      for (final String arm in <String>['en', 'ar']) {
        final Map<String, dynamic> table = _arb(arm);
        for (final String key in sources) {
          expect(
            table[key],
            isA<String>().having(
              (String value) => value.contains('{'),
              'contains a placeholder',
              isFalse,
            ),
            reason: '`$arm.$key` must be a whole literal',
          );
          expect(
            table[key],
            isA<String>().having(
              (String value) => value.isNotEmpty,
              'is non-empty',
              isTrue,
            ),
            reason: '`$arm.$key` renders nothing on screen if it is blank',
          );
          expect(
            (table['@$key'] as Map<String, dynamic>?)?['placeholders'],
            isNull,
            reason:
                '`$arm.@$key` declares placeholders, which is the shape '
                '`reading_l10n.dart` refuses: the composition is Dart\'s and the '
                'reason is the Latin-script gate a placeholder name would fail',
          );
        }
      }
    });

    test('and none of the seven holds a digit, on either arm', () {
      // `:546`'s `6 verses` and `:975`'s `١٢ يومًا` are the prototype's
      // *renderings*, drawn by `N()` — this client draws numerals through
      // `digits`, so a literal digit in a **whole-literal** row is a hard-coded
      // count.
      //
      // ## WHY THIS SCANS SEVEN KEYS AND NOT THE TABLE — MEASURED
      //
      // The first version walked every key in both files and failed on
      // `leaderboardRowSemantics`, whose English value legitimately contains
      // `one{1 point}`: a plural template writes the numeral **into the `one`
      // arm** because English has no other way to say "1 point". That is the
      // reason `home_l10n_test.dart`'s table-wide scan is the weaker `^\d+$` rule
      // — a value that is *nothing but* digits — rather than "no digit anywhere".
      //
      // So this row asserts the strict rule on exactly the rows it is true of: the
      // seven Task 5.3 added, every one of which is a whole literal that must
      // never grow a `{…}` slot to carry a count. The table-wide weaker rule is
      // not duplicated here; it already has an owner.
      const List<String> rows = <String>[
        'readingVerses',
        'readingQuiz',
        'readingQuestions',
        'readingListen',
        'readingSky',
        'readingBookmarkOn',
        'readingBookmarkOff',
      ];
      for (final String arm in <String>['en', 'ar']) {
        final Map<String, dynamic> table = _arb(arm);
        for (final String key in rows) {
          expect(
            RegExp(r'[0-9٠-٩]').hasMatch(table[key] as String),
            isFalse,
            reason:
                'ar/en `$arm.$key` holds a digit — every number on this screen is '
                'composed by `digits`, and a literal one is a count nobody measured',
          );
        }
      }
    });
  });

  group('every ARB citation names the line the row is actually on', () {
    test('measured against the prototype, on both arms', () {
      // ## THE MEASUREMENT THIS ROW STARTED AS, AND WHY IT IS NOW A GATE
      //
      // The seven `@key` descriptions first cited their prototype row **one line
      // above** where it is: `:967` for verses/quiz/questions, `:966` for listen,
      // `:969` for sky, `:975` for bmk/bmkOff, against rows measured at `:966`,
      // `:965`, `:968` and `:974`. The uniform offset is the signature of a
      // transcription taken against a file that had one line fewer above the
      // literal.
      //
      // **Nothing in the toolchain noticed.** `tool/gates/citation_check.py`
      // checks that a cited line *exists* and is in range, which a line one too
      // high satisfies; it cannot check that the line says what the claim says,
      // and its own doc says so. AGENT_CONTEXT's recorded decision 8 says the
      // same: a `NNN` citation is an unverified assertion unless a test names it.
      //
      // So a test named it, which is how the error was found — and the fix
      // belonged in the two ARB descriptions, which the writing slice did not own.
      // **The row below is the corrected form and it is strictly stronger**: it
      // no longer encodes the discrepancy, it forbids it. Each key's description
      // is read, its leading `:NNN` extracted, and compared against the line the
      // key's row is measured on. A corrected ARB now *passes* here instead of
      // failing, and the next drift fails with both numbers in the message.
      const Map<String, String> keyOf = <String, String>{
        // ARB key -> the prototype's own name for that row.
        'readingVerses': 'verses',
        'readingQuiz': 'quiz',
        'readingQuestions': 'questions',
        'readingListen': 'listen',
        'readingSky': 'sky',
        'readingBookmarkOn': 'bmk',
        'readingBookmarkOff': 'bmkOff',
      };
      for (final String arm in <String>['en', 'ar']) {
        final Map<String, dynamic> table = _arb(arm);
        for (final MapEntry<String, String> entry in keyOf.entries) {
          final int measured = _rowLine(entry.value);
          expect(
            measured,
            greaterThanOrEqualTo(i18nFirstLine),
            reason:
                '`${entry.value}` was found outside the I18N literal, so this '
                'comparison would be meaningless',
          );
          final String description =
              (table['@${entry.key}'] as Map<String, dynamic>)['description']
                  as String;
          final RegExpMatch? cited = RegExp(r'^`:(\d+)`')
              .firstMatch(description);
          expect(
            cited,
            isNotNull,
            reason:
                'transcribes, in the form `:NNN — ${description.substring(0, 40)}`',
          );
          expect(
            int.parse(cited!.group(1)!),
            measured,
            reason:
                '`$arm.${entry.key}` cites `redesign.html:${cited.group(1)}` and the '
                '`${entry.value}` row is on `:$measured`. One of the two sides '
                'moved: if `redesign.html` shifted, every citation under the '
                'literal moves with it.',
          );
        }
      }
    });

    test('and the two stale lines an earlier phase carried in are gone', () {
      // Found in the same sweep, and fixed in the same change: `homeSecondsOfSilence`
      // cited `:966` for a row that is on `:970`, and `@authEnterTheWord`'s
      // secondary citation said `:954` for `enter:`, which is on `:965`. Both are
      // out of this screen's scope and both would have been **stale claims a
      // reader could not check**, which is the failure mode AGENT_CONTEXT's
      // decision 8 is about.
      final Map<String, dynamic> en = _arb('en');
      expect(
        ((en['@homeSecondsOfSilence']! as Map<String, dynamic>)['description']!
            as String),
        contains('redesign.html:970'),
        reason: '`secs:` is on `:970`, beside `selah:`',
      );
      expect(
        ((en['@authEnterTheWord']! as Map<String, dynamic>)['description']!
            as String),
        isNot(contains('redesign.html:954')),
        reason: '`enter:` is on `:965`, beside `listen:`',
      );
    });
  });

  group('the strings that name `/reading`\'s controls', () {
    test('every interactive node has a name that is not its glyph', () {
      // §14's first row, applied to `/reading`'s controls. A name that is the
      // glyph ("Aa") is not a name, and the prototype's back and bookmark are
      // `<button>`s around an inline `<svg>` with nothing at all.
      expect(en.readingBack, isNotEmpty);
      expect(en.readingTextSize, isNotEmpty);
      expect(en.readingBookmark, isNotEmpty);
      // Which is why the `Aa` control is an `IconActionButton`: §14's row lists
      // `Aa` among the icon-only buttons, and `IconActionButton`'s own doc names it
      // as one of "the `Aa` and bookmark controls" this screen composes.
      expect(
        en.readingTextSize,
        isNot('Aa'),
        reason:
            'and if it ever were, the glyph would need to be the name and the '
            'widget would have to change',
      );
    });

    test('the unavailable reason is appended by the CALL SITE, not baked in', () {
      // The same rule as `listeningUnavailable` above, on the bookmark: the
      // suffix is a fact about the *control being inert*, so a table that baked
      // it in would produce "unavailable in this build — unavailable in this
      // build" the moment two inert controls shared a label. §14 asks for the
      // reason in the accessible name; it does not ask for it in the word the
      // sighted reader also reads.
      expect(en.readingBookmark, isNot(contains(en.readingUnavailableSuffix)));
      expect(en.readingBookmark, isNot(contains(ar.readingUnavailableSuffix)));
      expect(en.readingUnavailableSuffix, isNotEmpty);
    });

    test('and `readingTextSize` and `readingFontSize` stay TWO keys', () {
      // The bug `reading_accessibility_test.dart` caught: one string for the `Aa`
      // **disclosure you press** and for **the slider it reveals** put two nodes
      // on screen with the identical label, so a screen-reader user heard "Text
      // size" twice and could not tell the button from the thing it opened.
      expect(en.readingTextSize, isNot(en.readingFontSize));
      expect(ar.readingTextSize, isNot(ar.readingFontSize));
    });

    test('the bookmark has an ON and an OFF word, and they are not each other', () {
      // `:975`'s two rows. A toggle that announces only one state cannot be turned
      // off blind, which is the same argument `reading_l10n.dart` records for
      // keeping both — and the values are *distinct* rather than one an inflected
      // form of the other, so a reader is told which state the control is leaving.
      expect(en.readingBookmarkOn, 'bookmarked');
      expect(en.readingBookmarkOff, 'bookmark removed');
      expect(ar.readingBookmarkOn, 'تم الحفظ');
      expect(ar.readingBookmarkOff, 'أُزيل الحفظ');
      expect(en.readingBookmarkOn, isNot(en.readingBookmarkOff));
      expect(ar.readingBookmarkOn, isNot(ar.readingBookmarkOff));
      // **And the `✦` is deliberately absent from `readingBookmarkOn`.** `:975`
      // writes `bmk:["✦ bookmarked","✦ تم الحفظ"]`; U+2726 is in no bundled family
      // (measured — `arabic_typography_test.dart` failed with `[10022]` on the
      // selah glyph before it became a painted star), so a toast carrying it would
      // ship a tofu box. Asserting the absence is what keeps a well-meaning
      // "restore the prototype's glyph" edit from doing exactly that.
      expect(en.readingBookmarkOn, isNot(contains('✦')));
    });
  });

  group('the parse is not vacuous', () {
    test('the scoped I18N literal yielded rows, and it is the right block', () {
      // Anti-vacuity, and the reason it is a row and not a comment. `_i18nRow`
      // cuts the literal out before matching `key:["en","ar"]`, because **that
      // shape is not unique across the file** — an unanchored search matched 134
      // rows once, and `home_l10n_test.dart`'s `_catsTable` records the same
      // failure for the same reason. A parse that returned an empty map would make
      // every "composed from the prototype" assertion above a comparison of two
      // strings this file wrote.
      //
      // The row below counts **every** row in the scoped block rather than the
      // seven this suite needs, because a scope that cut the wrong block would
      // still return seven rows if those seven happened to be inside it — the
      // count is what proves the block is the whole table.
      expect(
        _allI18nRows(),
        hasLength(greaterThan(100)),
        reason:
            'the I18N literal holds a hundred-odd rows; a much smaller number '
            'means the scope cut the wrong block and every derived expectation '
            'above silently became a constant',
      );
      final Map<String, (String, String)> i18n = _i18nRow();
      for (final String key in <String>[
        'quiz',
        'questions',
        'verses',
        'sky',
        'listen',
        'bmk',
        'bmkOff',
      ]) {
        expect(
          i18n.containsKey(key),
          isTrue,
          reason: '`$key` is not a row of the literal any more',
        );
      }
      // The scope itself: the block starts at `const I18N={` and ends at its `};`,
      // and the rows the two composed sentences need sit inside it.
      expect(i18nFirstLine, lessThan(_rowLine('quiz')));
      expect(_rowLine('bmkOff'), lessThan(i18nEndLine));
    });
  });
}

/// The decoded ARB for [arm] — `lib/l10n/app_<arm>.arb`.
Map<String, dynamic> _arb(String arm) =>
    jsonDecode(File('lib/l10n/app_$arm.arb').readAsStringSync())
        as Map<String, dynamic>;

/// The first line of the prototype's I18N literal, measured at test time.
///
/// `:924` is `const I18N={` today. It is **measured rather than quoted** because
/// the line-number drift recorded in this file's citation group is exactly the
/// failure a quoted line number cannot catch — if the literal moves, the bound
/// moves with it and the "is this key inside the literal?" assertion still means
/// something.
final int i18nFirstLine = _literalBounds().$1;

/// The last line of the prototype's I18N literal.
final int i18nEndLine = _literalBounds().$2;

(int, int) _literalBounds() {
  final List<String> lines = File(prototype).readAsLinesSync();
  final int first = lines.indexWhere(
    (String l) => l.startsWith('const I18N={'),
  );
  if (first < 0) {
    throw StateError(
      'the prototype has no `const I18N={` literal any more. The table was '
      'renamed or removed, and this harness must read the reading screen\'s '
      'seven rows again.',
    );
  }
  // 1-based, because every citation in this repository is 1-based.
  final int from = first + 1;
  for (int i = first; i < lines.length; i++) {
    if (lines[i].trim() == '};') return (from, i + 1);
  }
  throw StateError(
    'the prototype\'s I18N literal opens at line $from and never closes, so the '
    'scope below it is the rest of the file — which is how an unanchored parse '
    'comes to match 134 rows.',
  );
}

/// One `key:["en","ar"]` pair out of the prototype's I18N literal.
///
/// A key that moved, or grew a third element, throws here with the prototype's
/// own shape in the message — the same contract `home_l10n_test.dart`'s `_pair`
/// keeps, because a `null` silently interpolated would turn a derived expectation
/// into the string `'null'`.
(String, String) _pair(String key) {
  final (int from, int to) = _literalBounds();
  final List<String> lines = File(prototype).readAsLinesSync();
  final String block = lines.sublist(from - 1, to).join('\n');
  final RegExpMatch? match = RegExp('$key:\\["([^"]*)","([^"]*)"\\]')
      .firstMatch(block);
  if (match == null) {
    throw StateError(
      '`$key` is no longer a row of the prototype\'s I18N literal (lines '
      '$from-$to). A word that moved, or grew a third element, is a change this '
      'harness must read — and one it cannot read through a rule at all.',
    );
  }
  return (match.group(1)!, match.group(2)!);
}

/// The 1-based line the prototype declares row [key] of the I18N literal on.
///
/// **Not a citation — a measurement**, which is the distinction this file exists
/// to keep: the ARB descriptions *claim* a line and this reads where the row
/// actually is. Returns `0` when the key is absent, so a caller comparing it to a
/// claimed line fails with a number rather than a `null`.
int _rowLine(String key) {
  final List<String> lines = File(prototype).readAsLinesSync();
  final RegExp pattern = RegExp('\\b$key:\\["');
  for (int i = 0; i < lines.length; i++) {
    if (pattern.hasMatch(lines[i])) return i + 1;
  }
  return 0;
}

/// The prototype's own rows, keyed by their JS names.
Map<String, (String, String)> _i18nRow() => <String, (String, String)>{
  for (final String key in <String>[
    'verses',
    'quiz',
    'questions',
    'listen',
    'sky',
    'bmk',
    'bmkOff',
  ])
    key: _pair(key),
};

/// Every `key:["en","ar"]` row of the scoped literal, keyed by its JS name.
///
/// Only the anti-vacuity row reads this. `_i18nRow` is the seven-row subset the
/// composed sentences need, and a subset cannot prove the scope was right — a
/// block cut too small still answers every question this suite asks.
Map<String, (String, String)> _allI18nRows() {
  final (int from, int to) = _literalBounds();
  final String block = File(prototype)
      .readAsLinesSync()
      .sublist(from - 1, to)
      .join('\n');
  return <String, (String, String)>{
    for (final RegExpMatch match in RegExp(
      r'(\w+):\["([^"]*)","([^"]*)"\]',
    ).allMatches(block))
      match.group(1)!: (match.group(2)!, match.group(3)!),
  };
}

/// Whether [rune] is U+0660–U+0669 — `l10n.dart`'s Arabic-Indic block.
bool _isArabicIndicDigit(int rune) => 0x0660 <= rune && rune <= 0x0669;

/// Whether [rune] is ASCII `0`–`9` — the Latin arm's numeral block.
bool _isAsciiDigit(int rune) => 0x30 <= rune && rune <= 0x39;

/// How many quoted verses `BOOKS.<id>.en` holds in the prototype — the
/// **fictional** excerpt length `:1346` reads as `b.en.length`.
///
/// Counted from the file rather than typed, for the same reason every other
/// number in this suite is: a typed `6` and the prototype's `6` would agree today
/// and could not tell a reader which one is being asserted.
int _excerptVerseCount(String id) {
  final String html = File(prototype).readAsStringSync();
  final int start = html.indexOf('$id:{name:');
  if (start < 0) {
    throw StateError(
      'the prototype has no `BOOKS.$id` entry, so the fictional excerpt length '
      'this suite measures the real passage count against cannot be read.',
    );
  }
  final RegExpMatch? en = RegExp(r'en:\[((?:"(?:[^"\\]|\\.)*"\s*,?\s*)+)\]')
      .firstMatch(html.substring(start));
  if (en == null) {
    throw StateError(
      '`BOOKS.$id` has no `en:[…]` array, or it is shaped differently from the '
      'one quoted verse per string this harness reads.',
    );
  }
  // One quoted string per entry — **splitting on the comma would be wrong**, and
  // the psalms excerpt is why: several of its verses contain a comma inside the
  // quotation marks, so a naive split over-counts.
  return RegExp(r'"(?:[^"\\]|\\.)*"').allMatches(en.group(1)!).length;
}
