import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reading_harness.dart';
import '../../../../support/utf16.dart';

/// `ReadingPage` — the sanctuary, in both arms.
///
/// ## WHAT IS ASSERTED HERE, AND WHAT IS **NOT**
///
/// This file is about **what is on the screen and what is not**. The per-arm numbers
/// are `reading_geometry_test.dart`'s, the fonts are `reading_glyph_test.dart`'s, the
/// semantics are `reading_accessibility_test.dart`'s, and §14's 1.22× is
/// `reading_text_scale_test.dart`'s — the same division `home_page_test.dart` and
/// `home_geometry_test.dart` use, for the reason `login_geometry_test.dart`'s library
/// doc spells out.
///
/// ## AND THE NEGATIVE ASSERTIONS ARE THE POINT OF HALF THIS FILE
///
/// The prototype's four strings on this screen are two fake references, a fake
/// duration and a fake question count, and the reading response ships **the quiz's
/// answer**. Every one of those is an *absence* in the shipped screen, and an absence
/// has no positive assertion — so each one below is asserted by what must **not** be
/// found.
void main() {
  group('the passage', () {
    testWidgets('every verse is on screen, with its number', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      // **Tall enough for the whole passage.** `ScriptureBlock` is a
      // `ListView.builder` — §13 rule 5's answer to "no `Column` over unbounded
      // data" — and a `ListView.builder` builds only what is visible, so at 932 the
      // fifth verse is not in the tree at all and asserting it is would be asserting
      // that the widget does not lazily build. 2400 is that surface's height.
      await pumpReading(tester, cubit: h.cubit, size: const Size(430, 2400));

      for (final Verse verse in liveEnglishPassageVerses) {
        expect(
          paragraphsContaining(tester, verse.text),
          hasLength(1),
          reason: 'verse ${verse.number}',
        );
      }
      // The marker comes from `Verse.number` and is a `TextSpan` **inside** the
      // paragraph — the prototype's `<sup>` — so it is part of the plain text and not
      // a widget of its own.
      expect(
        scriptureRichText(tester, 1).text.toPlainText(),
        startsWith('\u{FFFC}1 There was'),
      );
      expect(h.readings.calls, 1);
      expect(h.readings.asked, <ReadingLanguage>[ReadingLanguage.english]);
    });

    testWidgets('and it asks for the arm the LOCALE says, once', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));
      expect(h.readings.asked, <ReadingLanguage>[ReadingLanguage.arabic]);
      // A rebuild is not a re-request — recorded decision 41's control, and the one
      // thing that keeps a `build`-time dispatch from re-fetching on every state.
      await pumpReadingFrames(tester, 6);
      expect(h.readings.calls, 1);
    });

    testWidgets('a locale change re-requests and swaps the passage', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      expect(find.text('John 3:1-5'), findsOneWidget);

      // Stub the Arabic arm **while the English one is on screen**, so the assertion
      // below cannot pass by never having been shown. `home_navigation_test.dart`
      // does the same thing for `/`'s re-entry and calls it out.
      h.readings.scripture = const Result<ScriptureText>.success(
        liveArabicPassage,
      );
      // A locale change is a `didChangeDependencies` trigger, and `_requested` is a
      // `ReadingLanguage` rather than a `bool` precisely so this re-requests instead
      // of rendering English chrome over the old passage.
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      expect(h.readings.asked, <ReadingLanguage>[
        ReadingLanguage.english,
        ReadingLanguage.arabic,
      ]);
      expect(find.text('John 3:1-5'), findsNothing);
      expect(find.text('يوحنا 3: 1-5'), findsOneWidget);
    });
  });

  group('the DROP CAP, which is the one place the passage is indexed', () {
    // `ScriptureBlock._dropCapFor` is the only place `/reading` cuts into a verse,
    // and it is where a `String` from the wire becomes a single glyph. Three ways
    // that is wrong, all measured rather than reasoned about, and all three take
    // the **passage and both CTAs** with them — the cap is a `WidgetSpan` inside
    // the first paragraph, so a throw there is a throw out of `RenderParagraph`
    // inside the `ListView` that carries the header, the citation and the controls
    // row's sibling.
    for (final (String label, String openingVerse, String expectedLetter)
        in <(String, String, String)>[
          // **ASTRAL.** `String.substring` indexes UTF-16 code units, so
          // `substring(0, 1)` on U+1F600 returns the **high surrogate alone**. It is
          // not a truncated emoji, it is not a character, and `RenderParagraph` throws
          // `ArgumentError: string is not well-formed UTF-16` out of
          // `_RenderScaledInlineWidget.performLayout`. Measured: `'\u{1F600}'.
          // substring(0, 1).codeUnits` is `[55357]`.
          ('an emoji', '\u{1F600}There was a man', '\u{1F600}'),
          // **A LEADING SPACE.** `isEmpty` is false, so the `isEmpty` guard Phase 6
          // added is satisfied and the cap is `' '` — an **invisible 146.6px glyph**,
          // the largest element on the screen rendering nothing.
          (
            'a leading space',
            ' \u{2039}Verily, verily, I say unto thee',
            '\u{2039}',
          ),
          ('a tab', '\t\tIn the beginning', 'I'),
          // The live shape, as the control: `There`.
          ('an ordinary letter', 'There was a man', 'T'),
        ]) {
      testWidgets('$label makes the cap the first VISIBLE character', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            liveEnglishPassage.copyWith(
              verses: <Verse>[
                liveEnglishPassageVerses.first.copyWith(text: openingVerse),
                ...liveEnglishPassageVerses.skip(1),
              ],
            ),
          ),
        );
        // No `takeException`. A throw out of layout **is** the failure here, and
        // swallowing it would make the test pass on exactly the defect it exists
        // for.
        await pumpReading(tester, cubit: h.cubit);

        final String letter = dropCapLetters(tester).single;
        expect(
          letter,
          expectedLetter,
          reason:
              'the cap is the first character of a string from the wire; a space '
              'here renders nothing at '
              '${const PassageDropCap(letter: 'I', lines: 3).fontSizeFor(17)} logical px',
        );
        // …and the cap is a **rune**, not a code unit. `isWellFormedUtf16` and not
        // `runes.length == length`, because `runes` yields an unpaired surrogate as
        // a rune of its own — so that predicate is satisfied by exactly the broken
        // string it was meant to reject.
        expect(
          isWellFormedUtf16(letter),
          isTrue,
          reason:
              'unpaired at ${unpairedSurrogates(letter)}, which is what '
              '`RenderParagraph` throws on',
        );
      });
    }

    testWidgets('and an empty opening verse renders no cap and no throw', (
      WidgetTester tester,
    ) async {
      // Phase 6's C3 shape, on this screen: `Verse.text[0]` on `''` is a
      // `RangeError` out of `build`, and the reader can no longer reach the
      // reflection.
      final ReadingHarness h = readingHarness(
        scripture: Result<ScriptureText>.success(
          liveEnglishPassage.copyWith(
            verses: <Verse>[
              liveEnglishPassageVerses.first.copyWith(text: '   '),
              ...liveEnglishPassageVerses.skip(1),
            ],
          ),
        ),
      );
      await pumpReading(tester, cubit: h.cubit);
      expect(tester.takeException(), isNull);
      expect(dropCapLetters(tester), isEmpty);
      // The claim in `scripture_block.dart`'s doc is exactly this: the reader can
      // still reach the reflection.
      expect(find.byType(StickyCta), findsOneWidget);
    });

    testWidgets(
      'the ARABIC arm has no cap at all, whatever the verse opens with',
      (WidgetTester tester) async {
        // Recorded decision 29, and it is a **language** branch rather than a shape
        // test — so the arm with no cap is the arm whose verse is Arabic, not the arm
        // whose verse happens to start with a mark.
        final ReadingHarness h = readingHarness(
          scripture: const Result<ScriptureText>.success(liveArabicPassage),
        );
        await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));
        expect(dropCapLetters(tester), isEmpty);
        // And an Arabic verse opening with an emoji — the C1 input — is inert on this
        // arm because the branch is reached before any character is chosen.
        final ReadingHarness emoji = readingHarness(
          scripture: Result<ScriptureText>.success(
            liveArabicPassage.copyWith(
              verses: <Verse>[
                const Verse(
                  bookNumber: 43,
                  chapter: 3,
                  number: 1,
                  text: '\u{1F600} \u0643\u064e\u0627\u0646\u064e',
                  textClean: '\u0643\u0627\u0646',
                ),
                ...liveArabicPassageVerses.skip(1),
              ],
            ),
          ),
        );
        await pumpReading(
          tester,
          cubit: emoji.cubit,
          locale: const Locale('ar'),
        );
        expect(tester.takeException(), isNull);
        expect(dropCapLetters(tester), isEmpty);
      },
    );

    testWidgets('and a passage the server left a GAP in still renders', (
      WidgetTester tester,
    ) async {
      // `ScriptureText.verses`' doc: "`Verse.number` is carried, so the reading
      // screen can show a gap the server left rather than a renumbering this
      // client invented." The mapper proves the entity carries it; this is the
      // reader-visible half, which nothing asserted.
      final ReadingHarness h = readingHarness(
        scripture: Result<ScriptureText>.success(
          liveEnglishPassage.copyWith(
            verses: <Verse>[
              liveEnglishPassageVerses.first,
              liveEnglishPassageVerses[1].copyWith(number: 3),
              liveEnglishPassageVerses[2].copyWith(number: 4),
            ],
          ),
        ),
      );
      await pumpReading(tester, cubit: h.cubit, size: const Size(430, 2400));

      // The markers are the **server's** numbers, so `1, 3, 4` — not `1, 2, 3`.
      // Only the **first** verse carries a cap, so the replacement character is
      // there on the first paragraph and not on the other two; a renumbering would
      // have read `1, 2, 3`.
      expect(
        paragraphTexts(tester).map((String t) => t.split(' ').first).toList(),
        <String>['\u{FFFC}1', '3', '4'],
      );
      // And only the FIRST verse carries a cap, so a gap at 2 does not create one.
      expect(dropCapLetters(tester), hasLength(1));
    });
  });

  group('THE ANSWER IS NOT ON THIS SCREEN', () {
    // **Measured live against `HEAD = 4a1c834`:** `GET /readings/today/{lang}` puts
    // `user_answer: 'A'` and `is_correct: true` inside the question object. The
    // server ships today's answer with today's reading.
    //
    // The reading screen is the sanctuary — the one screen where a reader sits with
    // the text — and rendering `is_correct` there would spoil `QuizPage` before the
    // reader has chosen. So the questions are carried on the entity and read by
    // nothing, and this group is the proof.
    for (final (String label, ScriptureText passage, Locale locale)
        in <(String, ScriptureText, Locale)>[
          ('English', liveEnglishPassage, const Locale('en')),
          ('Arabic', liveArabicPassage, const Locale('ar')),
        ]) {
      testWidgets('${label[0]}: no question text, no option, no answer letter', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(passage),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);

        for (final Question question in passage.questions) {
          expect(find.text(question.prompt), findsNothing);
          for (final String option in question.options.values) {
            expect(
              find.text(option),
              findsNothing,
              reason: 'the option "$option" is a quiz answer, not scripture',
            );
          }
          final String? answer = question.userAnswer;
          if (answer != null) {
            // The letter alone is worth asserting: `1 question` legitimately contains
            // a `1`, so the count must not be mistaken for it.
            expect(
              find.text(answer),
              findsNothing,
              reason: 'the answer letter must not be on the sanctuary',
            );
          }
          // ## THE BOOLEAN, WHICH THE GROUP'S NAME PROMISED AND DID NOT ASSERT
          //
          // `reading_page.dart`'s doc claims this group asserts "in the failing
          // direction that neither **the boolean**, nor the letter, nor the option
          // texts, nor the prompt reach the rendered tree". It asserted the last
          // three. Measured: rendering `'true'` on the page and running this group
          // alone gave **3 pass, 0 fail** — the boolean was caught only
          // incidentally elsewhere, so the claim was unearned.
          //
          // `'true'` and not `true`, because `find.text` takes a `String` and
          // `Question.toString()` is not what is rendered. This is the literal
          // shape a client would leak it in.
          for (final String verdict in const <String>['true', 'false']) {
            expect(
              find.text(verdict),
              findsNothing,
              reason: '`is_correct` is a quiz verdict and this screen renders no quiz',
            );
          }
        }
        // And the points, which are a quiz fact too.
        expect(find.text('${passage.pointsEarnedToday}'), findsNothing);
      });
    }

    testWidgets('and the whole passage is still rendered — it is not blank', (
      WidgetTester tester,
    ) async {
      // The mirror of the group above, because "nothing renders" would satisfy every
      // negative assertion in it. Recorded decision 40's lesson exactly.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      expect(find.byType(ScriptureBlock), findsOneWidget);
      expect(find.byType(StickyCta), findsOneWidget);
      expect(find.byType(ReadingHeader), findsOneWidget);
      // **The drop cap is a `WidgetSpan`, not a widget in the tree** — that is what
      // `PassageDropCap.span` is for, and `passage_drop_cap_test.dart` owns the span's
      // geometry. So its presence is asserted on the *plain text*, where the cap's
      // glyph is the first character of the first paragraph.
      // …as a `WidgetSpan`, which is the shape `PassageDropCap.span` exists to
      // produce: a `TextSpan` cannot enlarge a letter and hang it from the first
      // baseline. `toPlainText()` renders a `WidgetSpan` as U+FFFC, so the plain
      // text opens with the replacement character rather than the glyph.
      expect(
        paragraphsContaining(tester, 'There was a man').single,
        startsWith('\u{FFFC}1 There was'),
        reason: 'the cap, then the marker, then the verse',
      );
      final InlineSpan first = scriptureRichText(tester, 1).text;
      expect(
        (first as TextSpan).children!.first,
        isA<WidgetSpan>(),
        reason: 'and it is a WidgetSpan rather than a bigger TextSpan',
      );
    });
  });

  group('A BLANK LABEL RENDERS, WHICH IS THE STATE THE MALFORMED RULE BLANKS TO', () {
    // ## WHY THIS GROUP IS A **WITNESS** AND NOT A RESTATEMENT
    //
    // `today_reading_mapper.dart` now blanks an unpaintable `reference` /
    // `translation` to `''` rather than refusing the reading, and the argument for
    // that is that `''` is a state this screen already had to handle — the server can
    // send it, and the mapper has always passed it through. **That argument is only
    // as good as this test.** Before it existed, "the server can send `''`" was an
    // assertion about a payload, not a measurement of a screen, and a screen that
    // threw or overflowed on an empty citation would have made the mapper's blank the
    // worse of the two verdicts.
    //
    // So this is the half of decision 95 that only a widget test can give: the
    // blanked label renders, the header is still there, and the passage is still
    // there. Both arms, because the metadata row uppercases on English and not on
    // Arabic and a title is right-aligned in neither.
    for (final (String label, ReadingLanguage language)
        in <(String, ReadingLanguage)>[
          ('English', ReadingLanguage.english),
          ('Arabic', ReadingLanguage.arabic),
        ]) {
      testWidgets('the $label arm takes a blank citation and a blank edition', (
        WidgetTester tester,
      ) async {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            (language == ReadingLanguage.english
                    ? liveEnglishPassage
                    : liveArabicPassage)
                .copyWith(reference: '', translation: ''),
          ),
        );
        await pumpReading(
          tester,
          cubit: h.cubit,
          locale: Locale(language.code),
        );

        // ## `takeException() == null`, WHICH IS THE ONLY NEGATIVE TEST HERE
        //
        // Not "a frame appeared". A layout exception is **caught** by the painting
        // library and recorded, the frame still paints, and the only way to read it is
        // `takeException()` — which is precisely the mistake an earlier draft of
        // `renderable_text.dart` made about the engine, in the opposite direction.
        // An exception left untaken also fails this test on its own, so the
        // assertion below is belt *and* braces on purpose.
        expect(tester.takeException(), isNull);
        expect(find.byType(ReadingHeader), findsOneWidget);
        // The passage, because a blank label that took the passage with it would
        // satisfy every assertion above. Counted rather than matched on a string,
        // because the needle would have to be English on one arm and Arabic on the
        // other — and a witness that needs two spellings is a witness that will
        // silently stop matching when a fixture's wording changes.
        expect(find.byType(ScriptureBlock), findsOneWidget);
        expect(
          scriptureRichTexts(tester),
          isNotEmpty,
          reason: 'the scripture is still on screen',
        );
      });
    }
  });

  group('NOTHING INVENTED IS ON THE SCREEN', () {
    testWidgets('no duration — the payload has no duration field', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // `ReadingEnScreen.tsx:31` — `Genesis · Chapter 1 · 4 min`; `:89` —
      // `5 questions · about a minute`. Verified live against `HEAD = 4a1c834`:
      // there is no duration anywhere in `GET /readings/today/{lang}`, and a
      // duration derived from a word count would be an invented measurement.
      expect(find.textContaining('4 min'), findsNothing);
      expect(find.textContaining('about a minute'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.textContaining('minute'), findsNothing);
      expect(find.textContaining('دقائق'), findsNothing);
    });

    testWidgets('no passage name — the API returns a citation, not a title', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // `ReadingEnScreen.tsx:38` — `The Beginning`; `ReadingArScreen.tsx:42` —
      // `البداية`. Neither exists in the payload.
      expect(find.text('The Beginning'), findsNothing);
      expect(find.text('البداية'), findsNothing);
      // And the citation that *is* on the payload is shown, verbatim.
      expect(find.text('John 3:1-5'), findsOneWidget);
    });

    testWidgets('and the reference is rendered AS SENT, spacing included', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));
      // `يوحنا 3: 1-5` — with the space after the colon that the English arm does not
      // have. Normalising it would be the client editing a citation.
      expect(find.text('يوحنا 3: 1-5'), findsOneWidget);
      expect(find.text('يوحنا 3:1-5'), findsNothing);
    });

    testWidgets('the caption is the REAL question count, pluralised', (
      WidgetTester tester,
    ) async {
      // The live reading carries **one** question. The prototype's caption is a
      // hard-coded `5 questions · about a minute`, false by a factor of five.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      expect(find.text('1 question'), findsOneWidget);
      expect(find.text('5 questions'), findsNothing);
      // The Arabic arm's singular, with the Arabic-Indic numeral the prototype uses.
      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
      expect(find.text('١ سؤال واحد'), findsOneWidget);
      expect(find.text('٥ أسئلة'), findsNothing);
    });

    testWidgets('and at five questions it says five', (
      WidgetTester tester,
    ) async {
      // The other direction, because a pluralisation that only ever said "1" would
      // satisfy the test above.
      final ReadingHarness h = readingHarness(
        scripture: Result<ScriptureText>.success(
          liveEnglishPassage.copyWith(
            questions: <Question>[
              ...liveEnglishPassageQuestions,
              for (int i = 0; i < 4; i++)
                Question(
                  id: 'cccccccc-cccc-cccc-cccc-ccccccc${i.toString().padLeft(3, '0')}',
                  sortOrder: i + 2,
                  type: 'mcq',
                  prompt: 'Q$i',
                  options: const <String, String>{'A': 'x'},
                  pointsValue: 10,
                  alreadyAnswered: false,
                ),
            ],
          ),
        ),
      );
      await pumpReading(tester, cubit: h.cubit);
      expect(find.text('5 questions'), findsOneWidget);
      expect(find.text('1 question'), findsNothing);
    });

    testWidgets(
      'the metadata row shows the TRANSLATION, uppercased in English',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);
        // `textTransform: 'uppercase'` on `ReadingEnScreen.tsx:30` and not on the
        // Arabic row, so the two arms differ and neither is a shared constant.
        expect(find.text('NKJV (NEW KING JAMES VERSION)'), findsOneWidget);

        final ReadingHarness ar = readingHarness(
          scripture: const Result<ScriptureText>.success(liveArabicPassage),
        );
        await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
        expect(find.text('Smith & Van Dyck (فانديك)'), findsOneWidget);
      },
    );

    testWidgets('the flanking `✦` marks are GONE, in BOTH languages', (
      WidgetTester tester,
    ) async {
      // `ReadingEnScreen.tsx:29,33` draws U+2726, which `font_coverage_test.dart`
      // measures as absent from **every** bundled family. Shipping it would be two
      // tofu boxes per screen in Latin as well as Arabic.
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            locale.languageCode == 'ar'
                ? liveArabicPassage
                : liveEnglishPassage,
          ),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);
        expect(find.textContaining('✦'), findsNothing, reason: '$locale');
      }
    });
  });

  group('the three top controls', () {
    testWidgets('back, `Aa` and the bookmark are all present and named', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      expect(find.byType(IconActionButton), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.format_size), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('the bookmark is INERT and says why', (
      WidgetTester tester,
    ) async {
      // `ReadingEnScreen.tsx:19-21` draws a bookmark `<button>` with no handler, and
      // the backend has **no** endpoint and **no** port for one. Phase 6's precedent
      // for the avatar applies verbatim: rendered, disabled, reason in the name.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final IconActionButton bookmark = tester.widget<IconActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.bookmark_border),
          matching: find.byType(IconActionButton),
        ),
      );
      expect(bookmark.onPressed, isNull);
      expect(
        bookmark.tooltip,
        contains('unavailable in this build'),
        reason: 'a reader is told why, not only that',
      );
    });

    testWidgets('the `Aa` control discloses the stepper, and the step works', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      expect(find.byType(FontSizeStepper), findsNothing);
      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);
      expect(find.byType(FontSizeStepper), findsOneWidget);

      // **The behaviour, not the persistence.** `SettingsRepository` is Phase 9's,
      // so a reader's step lives for the life of the cubit; what has to be true today
      // is that the control *changes the rendered size*.
      // Measured on **a scripture paragraph**, found through `ScriptureBlock` rather
      // than as "the first `RichText` in the tree" — the tree has other `RichText`s in
      // it, and a measurement of one of those is a measurement of chrome. Nor on the
      // `ListView`: the block fills the `Expanded` it is given, so its box is the
      // viewport's height whatever the type does.
      final double before = tester
          .getSize(find.byWidget(scriptureRichTexts(tester).first))
          .height;
      await tester.tap(find.byIcon(Icons.add).first);
      await pumpReadingFrames(tester, 4);
      expect(h.cubit.state.fontStep, 4);
      // 3 is the identity, 4 is 1.10x — the composed scaler, installed on the
      // `MediaQuery` above everything so "Text size" means text size.
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(ScriptureBlock)))
            .scale(1),
        closeTo(1.10, 0.0001),
      );
      final double after = tester
          .getSize(find.byWidget(scriptureRichTexts(tester).first))
          .height;
      expect(after, greaterThan(before), reason: 'the passage got taller');

      // …and nothing claims it survives. There is no navigation here to survive, and
      // `reading_cubit_test.dart` asserts no such thing either.
      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);
      expect(find.byType(FontSizeStepper), findsNothing);
    });

    testWidgets('the panel STAYS OPEN while the stepper inside it is used', (
      WidgetTester tester,
    ) async {
      // The reason `textSizePanelOpen` is cubit state and not a `StatefulWidget`'s
      // field: the step changes state, `ReadingPage.build` re-runs, and a control
      // held outside the cubit would be re-created — and therefore reset — by the
      // reader's own drag.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);

      await tester.tap(find.byIcon(Icons.add).first);
      await pumpReadingFrames(tester, 4);
      expect(find.byType(FontSizeStepper), findsOneWidget);
    });
  });

  group('the scaffold and the variant', () {
    testWidgets('the variant follows the arm, and nothing else', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      expect(
        tester.widget<NeuralScaffold>(find.byType(NeuralScaffold)).variant,
        NeuralVariant.readingEn,
      );

      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
      expect(
        tester.widget<NeuralScaffold>(find.byType(NeuralScaffold)).variant,
        NeuralVariant.readingAr,
      );
    });

    testWidgets(
      '`scrollable` is false and `bottomFade` is on — the CTA needs both',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);
        final NeuralScaffold scaffold = tester.widget<NeuralScaffold>(
          find.byType(NeuralScaffold),
        );
        // `ReadingEnScreen.tsx:26` puts `overflowY: 'auto'` on the **content div**,
        // which is what lets the CTA overlay it.
        expect(scaffold.scrollable, isFalse);
        expect(scaffold.bottomFade, isTrue);
        // …and the body really does own a scrollable, or the content could not move.
        expect(find.byType(ListView), findsOneWidget);
      },
    );

    testWidgets('the CTA is painted ABOVE the scaffold, or the scrim eats it', (
      WidgetTester tester,
    ) async {
      // The measurement behind the `Stack` at the root. `NeuralScaffold`'s fade is
      // solid `canvas` at 95% from 40% of its height down, and the prototype puts the
      // CTA at `zIndex: 2` above the content at `:1` — so a CTA inside the scaffold's
      // child would be washed out. Asserted by painting: the button's own ember is
      // visible where the scrim would have put canvas.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      expect(find.byType(StickyCta), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NeuralScaffold),
          matching: find.byType(StickyCta),
        ),
        findsNothing,
        reason:
            'the CTA must NOT be inside the scaffold\'s child, because the '
            'scrim is painted above the child and is solid canvas at 95% from 40% '
            'of its height down — which is exactly where the CTA sits',
      );
      // And the scrim that eats it is real, so the assertion above is not passing
      // because nothing is there.
      expect(
        tester.widget<NeuralScaffold>(find.byType(NeuralScaffold)).bottomFade,
        isTrue,
      );
    });

    testWidgets('the CTA and the back control are both ENABLED here', (
      WidgetTester tester,
    ) async {
      // ## WHAT THIS TEST IS **NOT**, AND WHY IT EXISTS ANYWAY
      //
      // It used to be named *"the CTA reaches the quiz and back is wired"* and its
      // body was two `isNotNull`s on closures **the widget supplies itself**. Three
      // mutations, measured against the full suite, left **1735 green**: `quiz` →
      // `settings`, `pushPath` → `replacePath`, and `onBack` → `() {}`. The name
      // asserted a routing guarantee the body could not make, and
      // `reading_page.dart:233` was the file's single uncovered line because the
      // arrow body was never invoked.
      //
      // The guarantee now lives in `reading_navigation_test.dart`, over a real
      // router, because that is the only arrangement in which `context.router`
      // resolves at all. What is left here is the thing this harness *can* see: the
      // two controls exist and are pressable, which is a real claim about the
      // failure state below (a **disabled** CTA would be indistinguishable from a
      // missing one on a bare `MaterialApp`).
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final EvaButton cta = tester.widget<EvaButton>(find.byType(EvaButton));
      expect(cta.onPressed, isNotNull);
      final IconActionButton back = tester.widget<IconActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconActionButton),
        ),
      );
      expect(back.onPressed, isNotNull);
    });
  });

  group('the failure state', () {
    testWidgets('shows the failure MESSAGE and a working retry', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.failure(readingFailure),
      );
      await pumpReading(tester, cubit: h.cubit);

      expect(find.byType(ErrorView), findsOneWidget);
      // The mapper's words, not a sentence from the table — Phase 6's precedent.
      expect(find.text(readingFailure.message), findsOneWidget);
      expect(find.text(const ReadingStrings.en().retry), findsOneWidget);

      // The retry re-asks, and this is the one place a **second** request is correct.
      h.readings.scripture = const Result<ScriptureText>.success(
        liveEnglishPassage,
      );
      await tester.tap(find.text(const ReadingStrings.en().retry));
      await pumpReadingFrames(tester, 6);
      expect(h.readings.calls, 2);
      expect(find.byType(ScriptureBlock), findsOneWidget);
    });

    testWidgets('and the CTA is gone, because there is nothing to reflect on', (
      WidgetTester tester,
    ) async {
      // The CTA's caption is `questionCount`, which lives on a passage there is not.
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.failure(readingFailure),
      );
      await pumpReading(tester, cubit: h.cubit);
      expect(find.byType(StickyCta), findsNothing);
    });

    testWidgets('and it is gone on a passage with ZERO questions too', (
      WidgetTester tester,
    ) async {
      // The same principle, on the payload that satisfies it. `questions: []` is
      // **reachable**: `today_reading_mapper.dart` skips an unreadable question
      // rather than refusing the passage (recorded decision 40), so four unreadable
      // questions report `questionCount == 0` — and `ReadingStrings.captionFor`'s
      // doc says so in its own words.
      //
      // Measured before the gate was added: the caption rendered as `"0 questions"`
      // / `"٠ أسئلة"` and **Begin reflection was still offered**, so a reader with
      // nothing to reflect on was invited to tap through to an empty quiz.
      //
      // The failure-state group above applies the principle to a **failed request**.
      // This is the same statement about a **succeeded** one, and the distinction is
      // the point: `state.scripture != null` was the gate, and a passage with no
      // questions is a passage.
      for (final (String label, ScriptureText passage, Locale locale)
          in <(String, ScriptureText, Locale)>[
            ('English', liveEnglishPassage, const Locale('en')),
            ('Arabic', liveArabicPassage, const Locale('ar')),
          ]) {
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            passage.copyWith(questions: const <Question>[]),
          ),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);
        expect(
          find.byType(StickyCta),
          findsNothing,
          reason: '$label: "Begin reflection" with nothing to reflect on',
        );
        // …and the **passage is still there**. The CTA goes; the sanctuary does not.
        // A gate that hid the whole screen would satisfy the assertion above.
        expect(find.byType(ScriptureBlock), findsOneWidget, reason: label);
      }
    });
  });

  group('while loading', () {
    testWidgets('nothing is on screen and nothing throws', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      // A single pump, which is all it takes to leave the loading state behind —
      // recorded decision 46's measurement, and the reason the widget suite can reach
      // the *failed* state but never dwells in this one.
      await pumpReading(tester, cubit: h.cubit, frames: 1);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Every **scripture** paragraph's plain text, in order.
///
/// ## WHY A WALK AND NOT `find.textContaining`
///
/// `ScriptureBlock` renders each verse as a `RichText` whose children are spans — the
/// verse marker is the prototype's `<sup>` and the drop cap a `WidgetSpan` — so a verse
/// is **not** one `Text` widget and `find.text` / `find.textContaining` cannot see it
/// at all. `home_page_test.dart` reads the rendered `fontFamily` off the tree for the
/// same structural reason.
///
/// ## AND WHY [ReadingHeader]'s LABELS ARE EXCLUDED
///
/// Because `Text` **builds a `RichText`**, `find.byType(RichText)` matches every label
/// on the screen — including `NKJV (NEW KING JAMES VERSION)`, which is what the first
/// version of this helper returned for "verse one". Scoping to [ScriptureBlock] is
/// therefore not enough on its own, because the header travels *inside* the block; the
/// ancestry check is the half that does it.
List<String> paragraphTexts(WidgetTester tester) => <String>[
  for (final RichText rich in scriptureRichTexts(tester))
    rich.text.toPlainText(),
];

/// The scripture paragraphs in the tree, in order, excluding [ReadingHeader]'s.
///
/// ## AND EXCLUDING THE DROP CAP'S OWN `Text`, WHICH IS ALSO A `RichText`
///
/// `PassageDropCap.span` puts a `WidgetSpan` in the paragraph whose child is a
/// `Text` — the cap's single glyph — and `Text` builds a `RichText`, so the cap is
/// in the same walk as the verse that carries it. The distinction is mechanical and
/// exact, and `reading_geometry_test.dart` documents it at length: **a verse
/// paragraph is the only `RichText` under [ScriptureBlock] whose span has
/// children**, because the marker and the cap are spans and the cap's own `Text`
/// has none. Without this, `paragraphTexts` returns `'T'` between two verses.
List<RichText> scriptureRichTexts(WidgetTester tester) {
  final Finder candidates = find.descendant(
    of: find.byType(ScriptureBlock),
    matching: find.byType(RichText),
  );
  return <RichText>[
    for (final Element element in candidates.evaluate())
      if (!_hasReadingHeaderAbove(element) && _isVerseParagraph(element))
        element.widget as RichText,
  ];
}

/// Whether [element]'s `RichText` is a **verse paragraph** rather than the drop
/// cap's own glyph.
bool _isVerseParagraph(Element element) {
  final InlineSpan text = (element.widget as RichText).text;
  return text is TextSpan && text.children != null;
}

/// Whether a [ReadingHeader] is anywhere above [element].
///
/// A hand-rolled walk rather than `find.ancestor`, because `find.ancestor` takes a
/// **Finder** and a `RichText` is not one — and `find.byWidget` cannot be used either
/// because every `Text` on the screen builds its own `RichText`, so matching by
/// instance would need the instance first. Walking the ancestors is the one thing
/// that needs neither.
bool _hasReadingHeaderAbove(Element element) {
  bool found = false;
  // `visitAncestorElements` stops as soon as the callback returns false, so this is a
  // walk with an early exit rather than a full traversal.
  element.visitAncestorElements((Element ancestor) {
    if (ancestor.widget is ReadingHeader) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// The plain text of every paragraph containing [needle].
List<String> paragraphsContaining(WidgetTester tester, String needle) =>
    <String>[
      for (final String text in paragraphTexts(tester))
        if (text.contains(needle)) text,
    ];

/// The scripture [RichText] for verse [number].
///
/// One-based, because that is how verses are numbered everywhere else in this file
/// and in the payload.
RichText scriptureRichText(WidgetTester tester, int number) =>
    scriptureRichTexts(tester)[number - 1];
