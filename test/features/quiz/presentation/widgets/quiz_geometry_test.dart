/// `/quiz`'s transcribed geometry — the three claims four doc comments pointed at a
/// file that did not exist.
///
/// ## WHY THIS FILE IS SMALL, AND WHAT IT IS **NOT**
///
/// `login_geometry_test.dart`, `home_geometry_test.dart` and
/// `reading_geometry_test.dart` each carry a **per-arm line map**: every claim names
/// a prototype file and line, the prototype's own text on that line is read at test
/// time, and a renumbered prototype turns the suite red. That harness does not exist
/// for `/quiz`, and `reading_geometry_test.dart`'s own doc puts the generalisation in
/// the same category as colours and fonts — *"stated rather than left for Phase 10"*.
///
/// So this file is **not** that harness and must not be read as one. It covers the
/// claims that were **pointed at and unbacked**:
///
/// | claim | prototype | asserted by |
/// | --- | --- | --- |
/// | the two gold flecks hang **outside** the card, at **both** §14 surfaces | `QuizScreen.tsx:91-94` | [fleckOffsetsFor] below, no widget pumped |
/// | the header row's two ends are **both 44** | `QuizScreen.tsx:45` | [QuizHeader.endWidth] |
/// | the banner's dot is at its **leading edge** | `QuizScreen.tsx:107` | a pumped `FeedbackBanner` |
///
/// Each was cited by name from `lib/` and none existed. Two of the three are
/// deliberate divergences — a pair of flecks positioned by *relationship* rather than
/// by literal, and a dot that is not centred — which is exactly the class of change
/// that is invisible in a diff and visible on screen.
///
/// ## AND A CONSTANT NOBODY CLAIMS IS A NUMBER WITH NO PROTOTYPE BEHIND IT
///
/// `reading_geometry_test.dart`'s doc makes this its reverse direction and
/// `kSocialButtonGap` the example that motivated it. The three claims above are the
/// whole of what is claimed here; a fourth constant joining them would need a
/// prototype line of its own, and inventing one would be the "certified number
/// nothing reads" this file's siblings exist to prevent.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/quiz/presentation/quiz_strings.dart';
import 'package:evangelion/features/quiz/presentation/widgets/feedback_banner.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

void main() {
  group('the gold flecks hang OUTSIDE the card, at both surfaces', () {
    // `QuizOptionCard.fleckOffsetsFor`'s doc is the claim this is the witness for:
    // *"so `quiz_geometry_test.dart` can assert the right pair sits outside the card
    // at **both** 320 and 430 without pumping a widget."*
    //
    // A pure function is the instrument because the defect it guards against is
    // **positional**, and a widget test at one width would pass with the pair drawn
    // inside the card at the other. The prototype's own numbers are `356` and `362`
    // on a `350`-ish card (`QuizScreen.tsx:93-94`) — that is, `width + 6` and
    // `width + 12`, so the relationship is transcribed and the literal is not.
    for (final double width in <double>[320, 430]) {
      test('the right pair is past the right edge at $width', () {
        final List<Offset> offsets = QuizOptionCard.fleckOffsetsFor(width);

        expect(
          offsets,
          hasLength(4),
          reason: 'two per side, `QuizScreen.tsx:91-94`',
        );
        for (final Offset offset in offsets.take(2)) {
          expect(
            offset.dx,
            lessThan(0),
            reason:
                'the left pair hangs off the leading edge — $offset at $width',
          );
        }
        for (final Offset offset in offsets.skip(2)) {
          expect(
            offset.dx,
            greaterThan(width),
            reason:
                'the right pair is "just outside the right edge" per the prototype\'s '
                'own words, so $offset at $width is inside the card and would read as '
                'two flecks floating on the option',
          );
        }
      });
    }

    test('and the pair keeps the prototype\'s overhang at both widths', () {
      // The relationship, asserted as the relationship. `width + 6` and `width + 12`
      // is what `QuizScreen.tsx:93-94` says once the card's width is known, and the
      // first draft of this wrote `width - 6`, which put the inner one **inside**.
      final List<Offset> at320 = QuizOptionCard.fleckOffsetsFor(320);
      expect(at320[2].dx, 326);
      expect(at320[3].dx, 332);

      final List<Offset> at430 = QuizOptionCard.fleckOffsetsFor(430);
      expect(at430[2].dx, 436);
      expect(at430[3].dx, 442);
    });
  });

  group('the header row is `space-between` because BOTH ends are 44', () {
    test('so the spacer is 44 wide and not an `Expanded`', () {
      // `QuizHeader.endWidth`'s doc: *"The spacer is not a layout nicety:
      // `justifyContent: 'space-between'` on `:45` puts the beads in the middle
      // **because** both ends are 44 wide. With one end 44 and the other 0 the beads
      // sit off-centre by 22px."*
      //
      // So the claim is an equality between the two ends, and the number is the
      // prototype's own `width: 44, height: 44` on `QuizScreen.tsx:45`.
      expect(QuizHeader.endWidth, 44);
    });

    testWidgets('and both ends measure 44 on screen', (
      WidgetTester tester,
    ) async {
      // The constant is asserted above; this is the half that catches a widget
      // **ignoring** it, which a constant comparison cannot see — the defect class
      // `home_geometry_test.dart`'s doc calls "a wrong token is invisible to a
      // geometry comparison", and this row's whole layout depends on the spacer being
      // as wide as the button.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: const Scaffold(
            body: QuizHeader(
              current: 1,
              total: 3,
              completed: 1,
              language: ReadingLanguage.english,
              strings: QuizStrings.en(),
              onExit: _noop,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // **Rendered, and both ends measured.** The two ends are an `IconActionButton`
      // and a bare `SizedBox`, so neither is findable by a type that means "end" —
      // but both are 44 by construction and `endWidth` is what makes the second one
      // so. Asserting the button's rendered width is the half a constant comparison
      // cannot see: `IconActionButton(size: …)` ignoring its `size` would leave the
      // row with one end at 44 and the other at 0, and the beads 22px off centre,
      // which is the whole of the doc's claim.
      final Size buttonSize = tester.getSize(find.byType(IconActionButton));
      expect(
        buttonSize.width,
        moreOrLessEquals(QuizHeader.endWidth, epsilon: 0.5),
        reason: '`width: 44, height: 44` on `QuizScreen.tsx:45`, rendered',
      );
      expect(
        tester.getSize(find.byType(ProgressBeads)).width,
        lessThan(tester.getSize(find.byType(QuizHeader)).width),
        reason:
            'the beads are between the two ends, so the row is not degenerate. Two '
            'ends of 44 and nothing between them is not the prototype\'s `space-between`',
      );
    });
  });

  group('the banner\'s dot is at the LEADING edge, not centred', () {
    // `FeedbackBanner`'s doc: *"`QuizScreen.tsx:107` is `display: 'flex',
    // alignItems: 'center'` with no `justifyContent`, so the dot and the message sit
    // at the **start** of the row, and the banner hugs its text rather than centring
    // it. `mainAxisAlignment` is therefore absent here too, and
    // `quiz_geometry_test.dart` asserts the dot is at the banner's leading edge
    // rather than in the middle of it."*
    //
    // ## WHAT IS ASSERTABLE ABOUT "NOT CENTRED", AND WHAT IS NOT
    //
    // The message is an **`Expanded`**, so the row's children always fill the row's
    // width and `mainAxisAlignment` has **nothing to distribute** — measured: at the
    // 800-wide harness surface the message's box runs 32 → 784. Adding
    // `mainAxisAlignment: MainAxisAlignment.center` to this `Row` would move **no
    // pixel**, so "the row is not centred" is not a falsifiable claim about this
    // widget and asserting it would be the kind of test that only looks load-bearing.
    //
    // The claim that *is* falsifiable is the **dot's position**, and it is the one the
    // doc leads with: a leading-edge dot at `x == padding.left`. It fails if anyone
    // gives the message a natural width and centres the run — the shape the phrase
    // "in the middle of it" describes.
    const String aShortVerdict = 'Exactly.';

    /// The banner's dot.
    ///
    /// `find.byType(Container).first` and not a key: the dot is the only `Container`
    /// in `FeedbackBanner`, and the harness's own scaffolding is not a `Container`.
    Finder theDot() => find.descendant(
      of: find.byType(FeedbackBanner),
      matching: find.byType(Container),
    );

    testWidgets('its left edge IS the content edge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: const Scaffold(
            body: FeedbackBanner(tone: FeedbackTone.ok, message: aShortVerdict),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final Rect dotRect = tester.getRect(theDot());
      final Rect bannerRect = tester.getRect(find.byType(FeedbackBanner));

      expect(
        dotRect.left,
        moreOrLessEquals(
          bannerRect.left + FeedbackBanner.padding.left,
          epsilon: 0.5,
        ),
        reason:
            'the dot is the row\'s first child and the row starts at the content edge. '
            '`QuizScreen.tsx:114` puts it there; a centred run would put it at '
            'roughly the banner\'s midpoint',
      );
    });

    testWidgets('and it is the prototype\'s 8×8, vertically centred', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: const Scaffold(
            body: FeedbackBanner(tone: FeedbackTone.ok, message: aShortVerdict),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final Rect dotRect = tester.getRect(theDot());
      final Rect bannerRect = tester.getRect(find.byType(FeedbackBanner));

      // `width: 8, height: 8` on `QuizScreen.tsx:114`, asserted against the rendered
      // box rather than the constant — a widget that ignored `dotSize` would pass a
      // constant comparison, which is the defect class `home_geometry_test.dart`'s
      // doc calls out by name.
      expect(dotRect.width, moreOrLessEquals(8, epsilon: 0.5));
      expect(dotRect.height, moreOrLessEquals(8, epsilon: 0.5));

      // `alignItems: 'center'` on `:107` — the **other** half of that line, and the
      // one `flexShrink: 0` on `:114` exists to protect at 1.22×.
      expect(
        dotRect.center.dy,
        moreOrLessEquals(bannerRect.center.dy, epsilon: 0.5),
      );
    });

    testWidgets('and the gap to the message is the `gap: 10` token', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          child: const Scaffold(
            body: FeedbackBanner(tone: FeedbackTone.ok, message: aShortVerdict),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.getRect(find.text(aShortVerdict)).left -
            tester.getRect(theDot()).right,
        moreOrLessEquals(FeedbackBanner.gap, epsilon: 0.5),
        reason: '`gap: 10` on `QuizScreen.tsx:108`, as a token',
      );
    });
  });

  group(
    'the fill alpha, and the `tone` that is deliberately NOT a parameter',
    () {
      test('is the prototype\'s two numbers', () {
        // `rgba(hex.ok, isDark ? 0.1 : 0.08)` on `QuizScreen.tsx:107`. The values are
        // `FeedbackBanner`'s own; this is the transcription check.
        expect(FeedbackBanner.darkFillAlpha, 0.1);
        expect(FeedbackBanner.lightFillAlpha, 0.08);
        expect(
          FeedbackBanner.fillAlphaFor(Brightness.dark),
          FeedbackBanner.darkFillAlpha,
        );
        expect(
          FeedbackBanner.fillAlphaFor(Brightness.light),
          FeedbackBanner.lightFillAlpha,
        );
      });

      testWidgets('and both tones paint the SAME alpha', (
        WidgetTester tester,
      ) async {
        // The claim `fillAlphaFor`'s doc makes about itself: `err` and `ok` share the two
        // numbers because `ds.tsx` publishes no second banner. It used to be carried by a
        // **`FeedbackTone` parameter nothing read** — a required argument at the one call
        // site with no effect on the result, which is the shape `_StatRow` had in this
        // phase and which §7's "a knob nothing turns" is about. The parameter is gone, so
        // the claim has to be asserted here or it is asserted nowhere.
        Future<Color> fillOf(FeedbackTone tone) async {
          await tester.pumpWidget(
            evaPrimitiveHarness(
              theme: EvaThemeDark.theme,
              child: Scaffold(
                body: FeedbackBanner(tone: tone, message: 'Exactly.'),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
          final DecoratedBox box = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(FeedbackBanner),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          return (box.decoration as BoxDecoration).color!;
        }

        final Color ok = await fillOf(FeedbackTone.ok);
        final Color err = await fillOf(FeedbackTone.err);

        // **Alpha compared, not colour.** The two tones are different inks on purpose —
        // that is `inkFor` — so comparing the whole colour would compare the wrong thing.
        expect(ok.a, err.a, reason: 'one fill alpha for both tones');
        expect(
          ok.a,
          moreOrLessEquals(FeedbackBanner.darkFillAlpha, epsilon: 0.001),
        );
      });
    },
  );
}

/// The header's exit callback, which this file never presses.
///
/// A named `void` function rather than a closure so the `QuizHeader` above can be
/// `const`; §14's rule that the control be keyboard-activatable is `quiz_page_test`
/// and `quiz_option_card_test`'s subject, not this file's.
void _noop() {}
