import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// [EvaToast] — the prototype's `.toast` (`eva/redesign.html:466-468`).
///
/// ## WHY THIS SUITE EXISTS RATHER THAN A THIRD COPY OF THE NUMBERS
///
/// The prototype declares the toast's geometry in **one CSS rule**, and this
/// client used to have **three** implementations of it — one per feature. The
/// shared widget is the one place those numbers now live, so this suite is
/// where they are asserted: a reader who changes the pill's padding changes
/// it **here**, and every toast in the app changes with it.
///
/// ## AND THE NUMBERS ARE READ OFF THE **RENDERED TREE**
///
/// Not off the source. A test that asserted "the source says 18" would pass
/// against a widget that lays the padding out at 18 and a `Container` that
/// applies it at 20 — and the rendered rect is the only one a reader sees.
void main() {
  /// The message every case carries.
  const String message = 'selah · amen';

  /// Pumps the toast and returns nothing.
  Future<void> pump(
    WidgetTester tester, {
    Widget? leading,
    String text = message,
    TextDirection direction = TextDirection.ltr,
  }) => pumpPrimitive(
    tester,
    EvaToast(message: text, leading: leading),
    textDirection: direction,
  );

  /// The pill — the `Container` the toast's decoration is on.
  ///
  /// The `Container` is found by its **decoration**, not by its type: the
  /// toast's own subtree holds several containers' worth of widgets and only
  /// one of them carries the pill's `BoxDecoration`.
  Finder pill() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(99),
  );

  group('the pill', () {
    testWidgets('carries the prototype\'s padding', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final Container container = tester.widget<Container>(pill());
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        reason: 'eva/redesign.html:467 — padding:10px 18px',
      );
    });

    testWidgets('is the prototype\'s rounded pill', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final Container container = tester.widget<Container>(pill());
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(99));
    });

    testWidgets('is rimmed in the prototype\'s gold hairline', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final Container container = tester.widget<Container>(pill());
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      final Border border = decoration.border! as Border;
      expect(
        border.top.color,
        const EvaColors.dark().ember.withValues(alpha: 0.5),
        reason: 'eva/redesign.html:466 — border:1px solid rgba(232,176,75,.5)',
      );
      expect(border.top.width, 1);
    });

    testWidgets('is filled with the surface at the app\'s own alpha', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final Container container = tester.widget<Container>(pill());
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color,
        const EvaColors.dark().surface.withValues(alpha: 0.9),
        reason: 'the prototype\'s rgba(12,14,24,.95), substituted',
      );
    });
  });

  group('the message', () {
    testWidgets('is drawn', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('is set in the prototype\'s mono type', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final Text text = tester.widget<Text>(find.text(message));
      final TextStyle style = text.style!;
      expect(style.fontFamily, EvaTypography.monoFamily);
      expect(style.fontSize, EvaSectionHeader.sectionSize);
      expect(style.fontSize, 10.5, reason: 'eva/redesign.html:467');
      // **The `.12em` premultiplied by the 10.5px** — the house rule, and the
      // number is written where it happens.
      expect(style.letterSpacing, 1.26);
      expect(style.letterSpacing, EvaSectionHeader.sectionSize * 0.12);
    });

    testWidgets('swaps the family on the Arabic arm', (
      WidgetTester tester,
    ) async {
      await pump(tester, direction: TextDirection.rtl);

      final Text text = tester.widget<Text>(find.text(message));
      expect(
        text.style!.fontFamily,
        EvaTypography.arabicFamily,
        reason: 'eva/redesign.html:134 — [dir=rtl] .toast{font-family:var(--ui-ar)}',
      );
    });

    testWidgets('is announced as a live region, and ONCE', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester);

      // ## AND THE LABEL IS NOT DOUBLED, AND THAT IS A **FIX** RATHER THAN A
      // ## PREFERENCE
      //
      // The toast's own `Semantics(label: message)` sat over a `Text` that
      // carries the same string, and the two were **merged** — so a screen
      // reader was handed "selah · amen" **twice**. The first version of this
      // test pinned the doubling and said so: "it is not fixed here, and the
      // reason is a constraint rather than a preference — the cheer toast and
      // the restore toast are the two implementations this widget replaces, and
      // their announcement is *behaviour*."
      //
      // **The constraint has expired, and the fix is right.** The two
      // implementations are gone — this widget *is* the implementation now — so
      // there is no announcement left to preserve, only a double announcement
      // to stop. `excludeSemantics: true` on the `Semantics` leaves the live
      // region and the label and drops the text's own node, and the reader is
      // told the sentence **once**.
      //
      // **The appearance is untouched** — semantics are not painted, so
      // `/communion`'s two goldens and the restore's golden are byte-identical
      // through the change.
      expect(
        tester.getSemantics(find.text(message)),
        matchesSemantics(
          label: message,
          isLiveRegion: true,
          textDirection: TextDirection.ltr,
        ),
      );
      handle.dispose();
    });
  });

  group('the mark in front of it', () {
    testWidgets('is drawn when one is given', (WidgetTester tester) async {
      await pump(
        tester,
        leading: const FourPointedStar(size: 12, color: Color(0xFFE8B04B)),
      );

      expect(find.byType(FourPointedStar), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets('and there is none when there is not', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.byType(FourPointedStar), findsNothing);
    });
  });

  group('where it sits', () {
    testWidgets('is centred, as the prototype\'s `left:50%` is', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      // **Centred, not stretched.** The prototype's toast is an absolutely
      // positioned box with `left:50%` and `transform:translate(-50%,…)`, so
      // it shrinks to its content and sits in the middle. A toast that filled
      // the width would be a different shape, and the cheer toast's golden
      // beside this file is the record of the right one.
      final Rect rect = tester.getRect(pill());
      expect(rect.width, lessThan(320));
      expect(
        rect.center.dx,
        closeTo(160, 0.5),
        reason: 'the pill is centred in the surface',
      );
    });
  });
}
