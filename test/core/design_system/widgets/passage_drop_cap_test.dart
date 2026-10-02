import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

const TextStyle _body = TextStyle(
  fontFamily: 'EBGaramond',
  fontSize: 19,
  height: 1.8,
);

/// Keys the paragraph so it can be addressed exactly.
///
/// `find.byType(RichText)` is not usable: a `Text` builds a `RichText` internally,
/// so the cap inside the `WidgetSpan` contributes a second one and every
/// position, size and golden assertion silently measures the *letter* rather than
/// the paragraph.
const Key _paragraphKey = ValueKey<String>('drop-cap-paragraph');

Widget _paragraph(
  PassageDropCap cap, {
  String rest = 'n the beginning was the Word.',
}) => evaAmbientHarness(
  child: SizedBox(
    width: 340,
    height: 240,
    child: Center(
      child: RepaintBoundary(
        key: _paragraphKey,
        child: cap.paragraph(rest: rest, bodyStyle: _body),
      ),
    ),
  ),
);

/// The drop cap's own glyph inside [widget].
Finder _capIn(Finder widget) =>
    find.descendant(of: widget, matching: find.byType(Text));

void main() {
  group('geometry — the inventory\'s signature', () {
    test('the letter is required and there is no default', () {
      // `04-widget-inventory.md:277-284` — `required this.letter`.
      const PassageDropCap cap = PassageDropCap(letter: 'I');
      expect(cap.letter, 'I');
    });

    test('it defaults to English and three lines', () {
      const PassageDropCap cap = PassageDropCap(letter: 'I');
      expect(cap.direction, TextDirection.ltr);
      expect(cap.lines, 3);
    });

    test('the line height is the prototype\'s scripture 19px on 1.8', () {
      expect(PassageDropCap.lineHeight, 1.8);
    });

    test('a three-line cap is about three lines tall', () {
      const PassageDropCap cap = PassageDropCap(letter: 'I');
      // `lines * lineHeight * bodyFontSize` is the em box the cap must span; the
      // glyph is sized to fill it, so dividing by the cap-height ratio is the
      // font size that does it.
      expect(cap.fontSizeFor(19), closeTo(3 * 1.8 * 19 / 0.7, 1e-9));
      expect(
        cap.fontSizeFor(19) * PassageDropCap.capHeightRatio,
        closeTo(3 * 1.8 * 19, 1e-9),
      );
    });

    test('the cap height ratio is a serif\'s, published and not folklore', () {
      expect(PassageDropCap.capHeightRatio, 0.7);
    });

    test('four lines is taller than three', () {
      expect(
        const PassageDropCap(letter: 'I', lines: 4).fontSizeFor(19),
        greaterThan(const PassageDropCap(letter: 'I').fontSizeFor(19)),
      );
    });

    test('the width grows with the letter count', () {
      expect(
        const PassageDropCap(letter: 'II').widthFor(19),
        greaterThan(const PassageDropCap(letter: 'I').widthFor(19)),
      );
    });
  });

  group('the span', () {
    test('is a WidgetSpan aligned on the alphabetic baseline', () {
      final InlineSpan span = const PassageDropCap(letter: 'I').span(_body);
      expect(span, isA<WidgetSpan>());
      final WidgetSpan widgetSpan = span as WidgetSpan;
      expect(widgetSpan.alignment, PlaceholderAlignment.baseline);
      expect(widgetSpan.baseline, TextBaseline.alphabetic);
    });

    test('the child carries the scripture family and the scaled size', () {
      final WidgetSpan span =
          const PassageDropCap(letter: 'I').span(_body) as WidgetSpan;
      final Text child = span.child as Text;
      expect(child.data, 'I');
      expect(child.style!.fontFamily, EvaTypography.scriptureFamily);
      expect(child.style!.fontSize, closeTo(146.57, 0.01));
    });

    test('an explicit colour wins over the inherited one', () {
      final WidgetSpan span = PassageDropCap(
        letter: 'I',
        color: const EvaColors.dark().ember,
      ).span(_body) as WidgetSpan;
      expect((span.child as Text).style!.color, const EvaColors.dark().ember);
    });

    test('without one the body colour is inherited', () {
      final WidgetSpan span = const PassageDropCap(
        letter: 'I',
      ).span(_body.copyWith(color: const EvaColors.dark().ink)) as WidgetSpan;
      expect((span.child as Text).style!.color, const EvaColors.dark().ink);
    });
  });

  group('D6 — the direction, and it is not optional', () {
    // `WidgetSpan` has NO `textDirection` in this SDK. A placeholder is laid out
    // by the PARAGRAPH's direction and by the child's own `Text.textDirection`.
    // Getting either wrong puts the opening letter of every Arabic passage on
    // the wrong side of the screen and nothing throws.

    test('the glyph takes the direction it was given', () {
      final WidgetSpan rtl = const PassageDropCap(
        letter: 'ا',
        direction: TextDirection.rtl,
      ).span(_body) as WidgetSpan;
      expect((rtl.child as Text).textDirection, TextDirection.rtl);

      final WidgetSpan ltr =
          const PassageDropCap(letter: 'I').span(_body) as WidgetSpan;
      expect((ltr.child as Text).textDirection, TextDirection.ltr);
    });

    test('the paragraph carries the direction too', () {
      expect(
        const PassageDropCap(
          letter: 'I',
          direction: TextDirection.rtl,
        ).paragraph(rest: 'x', bodyStyle: _body).textDirection,
        TextDirection.rtl,
      );
      expect(
        const PassageDropCap(letter: 'I')
            .paragraph(rest: 'x', bodyStyle: _body)
            .textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('the cap opens the paragraph on the leading side', (
      WidgetTester tester,
    ) async {
      // THE RTL ASSERTION. Not "the two goldens differ" — the cap's own x
      // position inside the same-width box, which is the thing that is wrong in
      // every Arabic passage if the direction is dropped.
      await tester.pumpWidget(_paragraph(const PassageDropCap(letter: 'I')));
      final Finder ltrBox = find.byKey(_paragraphKey);
      final double ltrCapLeft = tester.getTopLeft(_capIn(ltrBox)).dx;
      final double ltrParagraphLeft = tester.getTopLeft(ltrBox).dx;

      await tester.pumpWidget(
        _paragraph(
          const PassageDropCap(letter: 'I', direction: TextDirection.rtl),
        ),
      );
      final Finder rtlBox = find.byKey(_paragraphKey);
      final double rtlCapLeft = tester.getTopLeft(_capIn(rtlBox)).dx;
      final double rtlParagraphLeft = tester.getTopLeft(rtlBox).dx;

      expect(
        ltrCapLeft,
        closeTo(ltrParagraphLeft, 1.0),
        reason: 'an English passage opens on the left',
      );
      expect(
        rtlCapLeft,
        greaterThan(ltrCapLeft + 50),
        reason:
            'an Arabic passage opens on the right — this is the assertion '
            'that would fail if the direction were dropped',
      );
      expect(rtlParagraphLeft, closeTo(ltrParagraphLeft, 0.01));
    });

    testWidgets('both directions fit the same column', (
      WidgetTester tester,
    ) async {
      // RTL is a layout direction, not a different width: the reading column is
      // the same in both, so the paragraph must occupy the same box.
      await tester.pumpWidget(_paragraph(const PassageDropCap(letter: 'I')));
      final Size ltr = tester.getSize(find.byKey(_paragraphKey));
      await tester.pumpWidget(
        _paragraph(
          const PassageDropCap(letter: 'I', direction: TextDirection.rtl),
        ),
      );
      final Size rtl = tester.getSize(find.byKey(_paragraphKey));
      expect(rtl.width, closeTo(ltr.width, 0.01));
      expect(rtl.height, closeTo(ltr.height, 0.01));
    });

    testWidgets('neither direction overflows its box', (
      WidgetTester tester,
    ) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          _paragraph(
            PassageDropCap(letter: 'I', direction: direction),
            rest: 'n the beginning was the Word, and the Word was with God.',
          ),
        );
        expect(tester.takeException(), isNull, reason: direction.name);
      }
    });

    testWidgets('a 1.22x text scale is passed through, not reset', (
      WidgetTester tester,
    ) async {
      // §14 requires the app to scale to 1.22x without overflowing, and a drop
      // cap is the first thing that would overflow.
      await tester.pumpWidget(
        evaAmbientHarness(
          child: SizedBox(
            width: 340,
            height: 240,
            child: Center(
              child: const PassageDropCap(letter: 'I').paragraph(
                rest: 'n the beginning was the Word.',
                bodyStyle: _body,
                textScaler: const TextScaler.linear(1.22),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final (String label, TextDirection direction)
        in <(String, TextDirection)>[
          ('ltr', TextDirection.ltr),
          ('rtl', TextDirection.rtl),
        ]) {
      testWidgets('paragraph on $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(340, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _paragraph(
            PassageDropCap(letter: 'I', direction: direction),
            rest: 'n the beginning was the Word.',
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(_paragraphKey),
          matchesGoldenFile('goldens/passage_drop_cap_$label.png'),
        );
      });
    }

    testWidgets('the bare widget on dark', (WidgetTester tester) async {
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const RepaintBoundary(
            key: _paragraphKey,
            child: Center(
              child: DefaultTextStyle(
                style: _body,
                child: PassageDropCap(letter: 'I'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(_paragraphKey),
        matchesGoldenFile('goldens/passage_drop_cap_bare.png'),
      );
    });
  });
}
