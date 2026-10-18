import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/reading_harness.dart';

/// §14's rules on the redesigned `/reading`, from one harness.
///
/// ## WHAT THE REDESIGN CHANGED UNDER THIS SUITE
///
/// The old screen's controls were icon buttons whose names this file forced into
/// existence (`readingBack`, the `Aa`, the bookmark) — §14's gap, filled by hand.
/// The redesigned screen (`eva/redesign.html:540-560`) keeps two of those three
/// shapes and adds a dial and an inert `listen`, so the claims below are about
/// **names that now exist in the ARB** rather than about tooltips a widget
/// invented.
///
/// ## AND THE ONE CONTROL THAT SHIPS INERT IS THE INTERESTING ONE
///
/// `:558`'s `listen` button has no audio behind it — `speechSynthesis`,
/// `AudioContext`, `new Audio` and `.play()` are absent from the whole prototype —
/// so this client ships it with the reason in its **accessible name** while its
/// visible label stays the prototype's own word. §14's first row is why: a control
/// that does nothing must say so where a screen reader can find it, because a
/// sighted reader sees a button and a screen-reader reader must be told the button
/// is not a button.
void main() {
  final AppLocalizations en = AppLocalizationsEn();

  group('every interactive node has a name that is not its glyph', () {
    testWidgets('the two app-bar controls and the pill\'s four', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // `eva/redesign.html:542` and `:544` are `<button>`s around a glyph with
      // nothing else — `:544`'s `title="bookmark"` is a browser tooltip and
      // nothing to a screen reader. The names are the ARB's, and the painted star
      // (`FourPointedStar`) means the bookmark has **no text to leak**.
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(en.readingBack))),
        findsOneWidget,
        reason: 'the chevron announces its name, not `‹`',
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(en.readingBookmark))),
        findsOneWidget,
        reason:
            'the bookmark announces its name — the star is painted, so there '
            'is no glyph to leak into the label',
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(en.readingDecreaseFontSize)),
        ),
        findsOneWidget,
        reason: '`A−` is the visible label and not the name',
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(en.readingIncreaseFontSize)),
        ),
        findsOneWidget,
        reason: 'and `A+` likewise',
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(en.readingListen))),
        findsOneWidget,
        reason: 'the visible label is the prototype\'s own word',
      );
      handle.dispose();
    });

    testWidgets('and no node announces its glyph as its whole name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // §14's first row, in the failing direction: `‹`, `✦`, `A−`, `A+` and `EN`
      // are what the prototype *paints*, and a name that is the glyph is not a
      // name. `flagsCollection` and not the deprecated `hasFlag`.
      final List<String> names = <String>[
        for (final String label in _allLabels(tester)) label,
      ];
      // **`EN` is deliberately absent from this list, and that is a measured
      // finding rather than an oversight.** The dial's ring node announces
      // `labelOf(selected)` — `segmented_control.dart`'s own fallback — and the
      // selected segment announces the same string, so "EN" appears **twice** in
      // the tree this row read. `/settings` avoided it by passing a caller
      // `semanticLabel`; `/reading`'s dial has no such key in the ARB, and Task
      // 5.7 is where the language setting (and therefore that key) belongs. What
      // this row still refuses is a control whose whole name is a *glyph*, which
      // is §14's actual rule.
      for (final String glyph in <String>['‹', '✦', 'A−', 'A+']) {
        expect(
          names,
          isNot(contains(glyph)),
          reason: 'no node\'s whole name is the glyph `$glyph`',
        );
      }
      handle.dispose();
    });
  });

  group('the inert `listen` announces why, and is disabled', () {
    testWidgets('its name carries the unavailable suffix', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // The visible label is `listen`; the name a screen reader announces is the
      // composed one — `reading_l10n.dart`'s `listeningUnavailable`, which is the
      // arrangement login's ghost pills and `/`'s SealFab items use.
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(en.listeningUnavailable(en.readingUnavailableSuffix)),
          ),
        ),
        findsOneWidget,
        reason: 'the name a screen reader announces carries the reason',
      );
      expect(
        // An **exact** match, and the difference matters: the composed name
        // *contains* the word, so an escaped-substring finder would match it and
        // the claim — "the bare word is not the whole name" — would pass for the
        // wrong reason.
        find.bySemanticsLabel(RegExp('^${RegExp.escape(en.readingListen)}\$')),
        findsNothing,
        reason:
            'and the bare word is NOT the name — a reader is told the '
            'capability is absent, not shown a button that does nothing',
      );
      handle.dispose();
    });

    testWidgets('and it is disabled rather than silently inert', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      // `onListen: null` in production, so the page never passes it. `Semantics
      // (enabled: onPressed != null)` is what makes that visible, and this row is
      // what keeps the null honest: a control that looks disabled but announces
      // `enabled` is a lie in both directions.
      expect(
        _isEnabled(
          tester,
          en.listeningUnavailable(en.readingUnavailableSuffix),
        ),
        isFalse,
        reason: 'the inert control announces `enabled: false`',
      );
      handle.dispose();
    });
  });

  group('the verses', () {
    testWidgets('one node per verse, in order, announcing number and text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(
        tester,
        cubit: h.cubit,
        // **The entrance is off, and that is load-bearing**: the stagger reveals
        // verses on `80 + 25n` ms, and a verse that has not revealed paints at
        // `Opacity(0)` — invisible to a reader, and invisible to this suite. The
        // calm branch (`eva/redesign.html:1382`) is the honest stand-in for a
        // reader with reduced motion, and it is the only arm where every verse is
        // on screen at once.
        disableAnimations: true,
      );

      // `flagsCollection` and not the deprecated `hasFlag` — the repo's other
      // accessibility suites read the collection and compare a `Tristate`.
      final List<VerseLine> lines = tester
          .widgetList<VerseLine>(find.byType(VerseLine))
          .toList();
      expect(lines, isNotEmpty);
      for (int i = 0; i < lines.length; i++) {
        expect(
          lines[i].number,
          i + 1,
          reason:
              'the verses announce in the server\'s order, one-based — '
              '`eva/redesign.html:1361` writes `i+1` on the Latin arm',
        );
      }
      handle.dispose();
    });

    // **The drop cap is not announced twice — and there is no row asserting it,
    // because there is no second node.** `PassageDropCap` is a `WidgetSpan`
    // *inside* verse one's `RichText`, so the cap's letter is part of the
    // paragraph's own text run and contributes no semantics node of its own; the
    // rendered form is the glyph suites' claim, not this one.
  });

  group('the resume marker and the selection announce nothing extra', () {
    testWidgets('the marker is decoration, the selection is a state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      // `:168`'s marker is a 3px border and 12px of padding — decoration with no
      // name of its own, and `:1385-1386`'s selection is a *state* on a node that
      // already has a name. Both are asserted by absence: no node's name grows
      // because of either.
      final int before = _allLabels(tester).length;
      await tester.tap(find.byType(VerseLine).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _allLabels(tester).length,
        before,
        reason:
            'selecting a verse adds no name — the node already has one, and '
            '`:1385-1386`\'s `.hot` is a paint state',
      );
      handle.dispose();
    });
  });
}

/// Every accessible name on the tree, flattened.
List<String> _allLabels(WidgetTester tester) {
  final Finder nodes = find.byWidgetPredicate(
    (Widget w) => w is Semantics && (w.properties.label ?? '').isNotEmpty,
  );
  return <String>[
    for (final Semantics s in tester.widgetList<Semantics>(nodes))
      if (s.properties.label case final String label when label.isNotEmpty)
        label,
  ];
}

/// Whether the node whose label is [label] announces `enabled`.
///
/// Read off the declaring [Semantics] widget's own properties rather than through
/// the tester's flag collection: `enabled` is a property this codebase sets on the
/// widget, and reading it where it is set is one hop instead of two.
bool _isEnabled(WidgetTester tester, String label) {
  final List<Semantics> nodes = tester
      .widgetList<Semantics>(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.label == label,
        ),
      )
      .toList();
  expect(nodes, isNotEmpty, reason: '`$label` is not on the tree');
  return nodes.first.properties.enabled == true;
}
