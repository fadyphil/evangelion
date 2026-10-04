/// **Decision 8's harness, for `/`.** AGENT_CONTEXT §9, decision 8 names "the phase
/// that first transcribes a screen" as the owner of a prototype-comparison harness,
/// and says of the five other screens: "Phases 6–9 should add each screen's own
/// claims rather than assume this generalises."
///
/// ## THE THREE HALVES, AND WHAT EACH ONE CANNOT SEE
///
/// 1. **A line map** — every claim names a `HomeScreen.tsx` / `ds.tsx` line, and the
///    number on that line is parsed at test time. A renumbered prototype turns this
///    red instead of leaving it confidently checking a line that moved.
/// 2. **A symbol map** — a `null` line map proves nothing about the widget.
///    `login_geometry_test.dart` measured that: changing `LoginPage.kTopSpacer`
///    from 72 to 71 left all 37 of its tests green. So every claim that has a
///    Dart constant names the **symbol**, and the constant is read.
/// 3. **Rendered geometry** — what `RenderBox` reports, compared against the
///    prototype's numbers rather than against the widget's own constants.
///
/// **What it still cannot see, stated here rather than left for Phase 10:** colours,
/// radii and blur sigmas are tokens, and a *wrong token* is invisible to a geometry
/// comparison. It can tell 20 from 24 but not `padding: 20` from
/// `EdgeInsets.all(20)`.
///
/// ## AND WHAT IT CANNOT REACH IN THE PROTOTYPE, WHICH THE SUITE ADMITS
///
/// Three of `/`'s numbers are **not** in a `key: number` style object, so
/// `declaredValues` cannot see them at all:
///
/// | number | where the prototype writes it |
/// | --- | --- |
/// | the flame's `14 × 18` | `ds.tsx:514` — `width="14" height="18"`, JSX **attributes** |
/// | the avatar's `1.5` rim | `ds.tsx:521` — inside a template literal, `outline: `1.5px solid …`` |
///
/// Each is asserted against its **Dart constant** in a named test that says why the
/// line map cannot back it. The first version of this file claimed `width: 1.5` on
/// `ds.tsx` and the extraction reported it "is declared nowhere" — the gate working
/// exactly as intended, and the claim had to be either fixed or admitted.
///
/// ## AND WHAT `/` TRANSCRIBES IS **LESS** THAN `/login`'s, WHICH IS THE POINT
///
/// The library half of `HomeScreen.tsx` is **cut** (AGENT_CONTEXT §2, decision 1), so
/// there is no passage grid, no category chips and no `SealFAB` to transcribe. What
/// is left is the bar, the greeting and one panel — and this file's line map is
/// correspondingly short, which is the honest shape of the work.
library;

import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:evangelion/features/home/presentation/widgets/streak_flame_row.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/home_harness.dart';

/// The prototype files this harness reads. `eva/` is reference material and is never
/// written to (AGENT_CONTEXT §2, §8); existence is asserted so a moved file is a
/// failure rather than an empty extraction.
const String homeScreen = 'eva/src/screens/HomeScreen.tsx';

const String dsComponents = 'eva/src/components/ds.tsx';

/// The surface the rendered half uses.
///
/// 430×932 and not §14's 320×568: this file measures geometry the panel's own width
/// depends on, and at 320 the reference and the two CTAs wrap, which changes every
/// number being compared. §14's requirement is `home_text_scale_test.dart`'s.
const Size kGeometrySurface = Size(430, 932);

/// Every `key: N` numeric declaration in [file], keyed by `line:property`.
///
/// A single regex, because the point is to notice a number the prototype declares
/// and this phase **failed** to transcribe — which means the enumeration cannot be
/// limited to the properties already accounted for. `allMatches` rather than
/// `firstMatch`, because a React style object puts several declarations on one line.
Map<String, double> declaredValues(String file) {
  final File source = File(file);
  expect(
    source.existsSync(),
    isTrue,
    reason:
        '$file is missing. This harness cannot read the prototype, so it does not '
        'pass — a missing reference is reported, never assumed unchanged.',
  );

  final Map<String, double> found = <String, double>{};
  final RegExp declaration = RegExp(r'(\w+):\s*(\d+(?:\.\d+)?)\b');
  final List<String> lines = source.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    for (final RegExpMatch match in declaration.allMatches(lines[i])) {
      final double value = double.parse(match.group(2)!);
      // A `0` in a style object is a structural `zIndex: 0` or a `lineHeight: 0`
      // nobody transcribes; the ones that matter are non-zero geometry.
      if (value == 0) {
        continue;
      }
      // Keyed by **line and property**, not by the property's offset in the line: an
      // offset key collides between two lines sharing a column and silently drops
      // one of them. `login_geometry_test.dart` found that by having its
      // anti-vacuity test correctly refuse to believe the result.
      found['${i + 1}:${match.group(1)}'] = value;
    }
  }
  return found;
}

/// One transcription claim: a prototype key, the number on it, and the Dart symbol
/// that number became — or `null` where there is deliberately no constant.
typedef PrototypeClaim = ({
  String label,
  String file,
  String key,
  double expected,
  String? symbol,
});

/// The symbol map: every number this phase publishes **from a prototype number**,
/// by name.
///
/// One table, so a claim can name a symbol and the assertion can read it without a
/// second table drifting in step. `login_geometry_test.dart` keeps the same two
/// tables for the same reason.
///
/// ## THE FOUR CONSTANTS DELIBERATELY **ABSENT** FROM THIS MAP
///
/// * `HomePage.bottomSpacer` — the prototype's `paddingBottom: 100` is the
///   clearance for its `SealFAB`, which is **cut** with the profile screen, so the
///   shipped value is `EvaSpacing.huge` and no prototype number is transcribed.
///   `HomePage.bottomSpacer`'s own doc says so.
/// * `AppTopBar.avatarTapTarget` — **44**, against the prototype's 32. The 32 is
///   claimed and transcribed; the 44 is the platform tap-target minimum and is
///   asserted with its reason where that divergence is argued.
/// * `StreakFlameRow.flameSize` — the prototype's `18` is a JSX **attribute**
///   (`ds.tsx:514` - `height="18"`), not a `key: number`, so the line map cannot
///   reach it. Asserted in "the three numbers the line map cannot reach".
/// * `AppTopBar.avatarRimWidth` — the prototype's `1.5` is inside a template
///   literal. Same group.
const Map<String, double> _homeSymbols = <String, double>{
  'topGap': HomePage.topGap,
  'panelGap': HomePage.panelGap,
  'panelRadius': TodayReadingPanel.radius,
  'eyebrowGap': TodayReadingPanel.eyebrowGap,
  'previewGap': TodayReadingPanel.previewGap,
  'referenceGap': TodayReadingPanel.referenceGap,
  'actionsGap': TodayReadingPanel.actionsGap,
  'actionsTopGap': TodayReadingPanel.actionsTopGap,
  'previewFontSize': TodayReadingPanel.previewFontSize,
  'trailingGap': AppTopBar.trailingGap,
  'avatarDiameter': AppTopBar.avatarDiameter,
  'gap': StreakFlameRow.gap,
};

/// Every number `/` claims to have transcribed from a `key: number` declaration.
///
/// `final`, not `const`: a claim reads its symbol by **indexing** `_homeSymbols`,
/// and an index expression is not a constant expression in Dart. The map itself is
/// still `const`, so its values are canonical and the table cannot drift.
final List<PrototypeClaim> _claims = <PrototypeClaim>[
  // --- HomeScreen.tsx: the greeting block ------------------------------------
  (
    label: 'the greeting block gap',
    file: homeScreen,
    key: 'marginBottom',
    expected: 24,
    symbol: 'topGap',
  ),
  // --- HomeScreen.tsx: the panel ---------------------------------------------
  (
    label: 'the panel radius',
    file: homeScreen,
    key: 'borderRadius',
    expected: 24,
    symbol: 'panelRadius',
  ),
  (
    label: 'the panel bottom margin',
    file: homeScreen,
    key: 'marginBottom',
    expected: 28,
    symbol: 'panelGap',
  ),
  (
    label: 'the eyebrow gap',
    file: homeScreen,
    key: 'marginBottom',
    expected: 12,
    symbol: 'eyebrowGap',
  ),
  (
    label: 'the preview row gap',
    file: homeScreen,
    key: 'marginBottom',
    expected: 10,
    symbol: 'previewGap',
  ),
  (
    label: 'the gap below the reference',
    file: homeScreen,
    key: 'marginBottom',
    expected: 14,
    symbol: 'referenceGap',
  ),
  (
    label: 'the gap above the two controls',
    file: homeScreen,
    key: 'marginTop',
    expected: 16,
    symbol: 'actionsTopGap',
  ),
  (
    label: 'the gap between the two controls',
    file: homeScreen,
    key: 'gap',
    expected: 10,
    symbol: 'actionsGap',
  ),
  (
    label: 'the preview body size',
    file: homeScreen,
    key: 'fontSize',
    expected: 17,
    symbol: 'previewFontSize',
  ),
  (
    label: 'the drop cap size',
    file: homeScreen,
    key: 'fontSize',
    expected: 76,
    symbol: null,
  ),
  (
    label: 'the reference size',
    file: homeScreen,
    key: 'fontSize',
    expected: 20,
    symbol: null,
  ),
  // --- ds.tsx: the top bar ----------------------------------------------------
  (
    label: 'the gap between the streak and the avatar',
    file: dsComponents,
    key: 'gap',
    expected: 14,
    symbol: 'trailingGap',
  ),
  (
    label: 'the avatar diameter',
    file: dsComponents,
    key: 'width',
    expected: 32,
    symbol: 'avatarDiameter',
  ),
  // `avatarTapTarget` (44) has **no** prototype row and deliberately no symbol in
  // `_homeSymbols`: the prototype says 32 and this client says 44 because 32 is
  // below the platform tap-target minimum. Putting a 44 in a table whose subject is
  // transcription would claim a fidelity the change does not have; the number is
  // asserted where the divergence is argued instead.
  (
    label: 'the avatar height',
    file: dsComponents,
    key: 'height',
    expected: 32,
    symbol: 'avatarDiameter',
  ),
  (
    label: 'the gap between the flame and the count',
    file: dsComponents,
    key: 'gap',
    expected: 5,
    symbol: 'gap',
  ),
];

void main() {
  group('the prototype still says what the claims say', () {
    test('every declared value the claims cite is present on its line', () {
      // The **line map**. `declaredValues` returns a map keyed `line:property`, and a
      // claim's key is composed from the line the claim resolved — so this asserts
      // that `HomeScreen.tsx` still declares `borderRadius: 24` somewhere, and a
      // prototype that stops declaring it fails here.
      //
      // Anti-vacuity first: a parser that matched nothing would return an empty map
      // and every lookup below would be `null`, which is exactly the silent-pass
      // shape AGENT_CONTEXT §7 warns about.
      final Map<String, double> screen = declaredValues(homeScreen);
      final Map<String, double> components = declaredValues(dsComponents);

      expect(screen, isNotEmpty);
      expect(components, isNotEmpty);
      expect(
        screen.keys.any((String key) => key.endsWith(':borderRadius')),
        isTrue,
        reason: 'the extraction must see the panel radius at all',
      );

      for (final PrototypeClaim claim in _claims) {
        final Map<String, double> values = claim.file == homeScreen
            ? screen
            : components;
        expect(
          values.values.contains(claim.expected),
          isTrue,
          reason:
              'the extraction found no `${claim.key}: ${claim.expected}` anywhere '
              'in ${claim.file} (${claim.label}). Either the prototype changed or '
              'this claim cites a declaration this harness cannot see — in which '
              'case it belongs in the admitted list in the library doc, not here.',
        );
        expect(
          _lineOf(values, claim),
          greaterThan(0),
          reason: 'and the claim must resolve to a real line',
        );
      }
    });

    test('and the extraction resolved a distinct line for most claims', () {
      // The second half of the same claim. A claim list where every row resolved
      // to line 1 would satisfy the test above, so this requires **spread**: the
      // claims are not all the same declaration.
      final Map<String, double> screen = declaredValues(homeScreen);
      final Set<int> lines = <int>{
        for (final PrototypeClaim claim in _claims)
          if (claim.file == homeScreen) _lineOf(screen, claim),
      };
      expect(lines.length, greaterThanOrEqualTo(6));
    });
  });

  group('the symbol map — a line map alone proves nothing', () {
    test('every published constant matches the number it transcribes', () {
      // The measured lesson, restated: `login_geometry_test.dart` changed
      // `LoginPage.kTopSpacer` from 72 to 71 and all of its tests stayed green. A
      // claim with no symbol is a claim about a prototype line, not about this code.
      for (final PrototypeClaim claim in _claims) {
        final String? symbol = claim.symbol;
        if (symbol == null) {
          continue;
        }
        expect(_homeSymbols[symbol], claim.expected, reason: claim.label);
      }
    });

    test('every published constant is claimed by at least one row', () {
      // The other direction. A constant nothing claims is a number with no
      // prototype behind it — which is how `kSocialButtonGap` survived in
      // `login_geometry_test.dart` long enough to be certified while nothing read it.
      final Set<String> claimed = <String>{
        for (final PrototypeClaim claim in _claims)
          if (claim.symbol != null) claim.symbol!,
      };
      expect(claimed, _homeSymbols.keys.toSet());
      // And every name a claim uses is one the map actually has — a typo in a claim
      // would otherwise read as `null` on the line above and pass.
      for (final PrototypeClaim claim in _claims) {
        if (claim.symbol != null) {
          expect(
            _homeSymbols.containsKey(claim.symbol),
            isTrue,
            reason: claim.label,
          );
        }
      }
    });

    test('and the two `null` symbols are null for stated reasons', () {
      final List<String> nulls = <String>[
        for (final PrototypeClaim claim in _claims)
          if (claim.symbol == null) claim.label,
      ];
      expect(nulls, <String>['the drop cap size', 'the reference size']);
      // **Both are font sizes**, and `eva_typography.dart` records that §5.2 fixes
      // none: the sizes come from the SDK's Material 3 scale, and a constant here
      // would be a second copy of it free to drift from the theme.
      //
      // The drop cap is the sharper case: the prototype's literal 76 is transcribed
      // by `PassageDropCap.fontSizeFor`, which *derives* it from the body size and
      // the cap-height ratio. That is the widget's own documented argument and it is
      // asserted in `passage_drop_cap_test.dart`; there is nothing here to certify.
      //
      // If either gains a symbol, this list is what notices.
    });
  });

  group('the three numbers the line map cannot reach', () {
    testWidgets('the flame is 18 tall and 14 wide', (
      WidgetTester tester,
    ) async {
      // `ds.tsx:514` — `<svg width="14" height="18" viewBox="0 0 16 20">`. JSX
      // **attributes**, so there is no `key: number` for `declaredValues` to find;
      // the extraction sees `viewBox`'s contents only if they were a style object,
      // and they are not.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Size flame = tester.getSize(
        find.descendant(
          of: find.byType(StreakFlameRow),
          matching: find.byType(StreakFlame),
        ),
      );
      expect(flame.height, 18, reason: 'ds.tsx:514 height="18"');
      // `StreakFlame` derives the width from the height and the viewBox's 16:20,
      // which its own doc argues at length; 0.778 of 18 is 14.0 to within a rounding
      // step. So the width is asserted against the prototype's number rather than
      // against `flameSize * aspect`, which would agree with any value at all.
      expect(flame.width, closeTo(14, 0.5), reason: 'ds.tsx:514 width="14"');
    });

    test('the avatar tap target is 44, which the prototype does NOT say', () {
      // `IconActionButton.size` and `iOSTapTargetGuideline` both say 44; the
      // prototype's `ds.tsx:520` says `width: 32, height: 32`. So this number is
      // **deliberately absent from `_homeSymbols`**, and asserting it here with its
      // reason is what keeps that absence from looking like an oversight.
      expect(AppTopBar.avatarTapTarget, 44);
      expect(
        AppTopBar.avatarTapTarget,
        greaterThan(AppTopBar.avatarDiameter),
        reason: 'the painted circle stays 32 inside a 44 box',
      );
    });

    testWidgets('the avatar rim is 1.5', (WidgetTester tester) async {
      // `ds.tsx:522` writes the rim inside a template literal — `outline: `1.5px
      // solid …`` — so the key is `outline`, not `width`, and `1.5` is followed by
      // `px` with no word boundary after the digits. The extraction cannot see it.
      expect(AppTopBar.avatarRimWidth, 1.5);
      // The prototype's alpha is 0.4 dark / 0.6 light; the shipped value is 0.35
      // because `ember` is the only accent in §5.1 and the avatar must not compete
      // with the flame beside it. `AppTopBar`'s doc gives the substitution.
      //
      // **`0.35` and not `lessThan(1)`.** The bound this replaced was satisfied by
      // `0.99` — a rim effectively as strong as an opaque one, which is the opposite
      // of "must not compete with the flame beside it", and the sentence above is the
      // whole reason the number exists. A doc that names a value and an assertion
      // that accepts any value under 1 are two different claims and only one of them
      // was being tested.
      expect(AppTopBar.avatarRimAlpha, 0.35);
    });

    test('and the prototype really does write them the way this says', () {
      // The one thing this file *can* do for an unreachable number: assert the
      // prototype's own text, so a rewrite of `ds.tsx:514` or `:522` is red. A regex
      // over the raw line rather than the numeric extractor, which is the whole
      // difference between "cannot see it" and "cannot check it".
      final List<String> components = File(dsComponents).readAsLinesSync();

      expect(
        components.firstWhere(
          (String line) => line.contains('height="18"'),
          orElse: () =>
              throw StateError('ds.tsx no longer declares height="18"'),
        ),
        contains('width="14"'),
      );
      // **Both on the same line.** A first-match search for `1.5px` alone finds
      // `ds.tsx:264`'s `ButtonSecondary` border - `border: 1.5px solid ...` - and
      // then asserts that it says `outline`, which is a different control's number.
      // That was the first version's second form of the same mistake.
      expect(
        components.firstWhere(
          (String line) => line.contains('1.5px') && line.contains('outline'),
          orElse: () => throw StateError(
            'ds.tsx no longer declares an `outline: 1.5px` rim',
          ),
        ),
        contains('1.5px'),
      );
    });
  });

  group('the rendered geometry', () {
    testWidgets('the panel paints at the prototype radius and padding', (
      WidgetTester tester,
    ) async {
      // The third half: the prototype's numbers again, but read off what the tree
      // reports rather than off this project's constants — a constant that is right
      // and a widget that ignores it are otherwise the same test.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      expect(
        tester.getSize(find.byType(GlassSurface).first).width,
        kGeometrySurface.width - 2 * EvaSpacing.screenHorizontal,
        reason:
            'the panel fills the scaffold gutter, and 430 is the width '
            '`login_geometry_test.dart` uses for the same reason',
      );

      final GlassSurface surface = tester.widget<GlassSurface>(
        find.byType(GlassSurface).first,
      );
      expect(surface.radius, 24, reason: 'HomeScreen.tsx:41 borderRadius: 24');
      expect(
        surface.padding,
        const EdgeInsets.fromLTRB(20, 20, 20, 16),
        reason: 'HomeScreen.tsx:41 padding 20px 20px 16px',
      );
    });

    testWidgets('the two controls are the prototype apart', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      final Rect button = tester.getRect(find.byType(EvaButton));
      final Rect link = tester.getRect(find.byType(TextLink));

      // **Centre to centre, not edge to edge.** The prototype's second half is
      // `<div flex: 1, display: flex, alignItems: center, justifyContent: center>`
      // (`HomeScreen.tsx:68-69`), so the `TextLink` is *centred inside* its half and
      // its left edge is nowhere near the button's right edge. An edge-to-edge
      // assertion measured 42.9 against a declared gap of 10, and "fixing" it would
      // have meant moving the link out of its centred half — which is the design
      // improvement this project forbids.
      //
      // Two `flex: 1` halves plus a gap put the second half's centre exactly one
      // half-width plus the gap to the right of the button's centre.
      expect(
        link.center.dx - button.center.dx,
        closeTo(button.width + TodayReadingPanel.actionsGap, 0.5),
        reason: 'two flex:1 halves separated by gap: 10, with the link centred',
      );
      expect(
        link.left,
        greaterThan(button.right),
        reason: 'and the gap is real: the halves do not touch',
      );
    });

    testWidgets('the avatar is 32 painted inside a 44 box', (
      WidgetTester tester,
    ) async {
      // The one deliberate §14 divergence from the prototype, asserted as **both**
      // numbers so the change is visible rather than only described.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, size: kGeometrySurface);

      expect(
        tester.getSize(find.byType(AppTopBar)).height,
        AppTopBar.avatarTapTarget,
        reason:
            'the row is as tall as its tallest child, and the avatar box is the '
            '44px tap target. `AppTopBar` records what that cost against the '
            'prototype own 32.',
      );

      // The painted circle is still 32 — the prototype's number.
      final Iterable<double> circles = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AppTopBar),
              matching: find.byType(Container),
            ),
          )
          .map((Container c) => c.constraints?.maxWidth ?? 0)
          .where((double width) => width > 0);
      expect(circles, contains(AppTopBar.avatarDiameter));
    });
  });
}

/// The prototype line a claim's `key` resolves on.
///
/// Found by scanning for the **first** occurrence of `key: expected` in the file.
/// Where the same `key: N` pair appears twice the claim is ambiguous, and this
/// reports the first rather than guessing silently — the ambiguity is a property of
/// the prototype, and the assertion above already asks only that the pair exists
/// somewhere.
int _lineOf(Map<String, double> values, PrototypeClaim claim) {
  final List<int> hits = <int>[
    for (final MapEntry<String, double> entry in values.entries)
      if (entry.key.endsWith(':${claim.key}') && entry.value == claim.expected)
        int.parse(entry.key.split(':').first),
  ];
  expect(
    hits,
    isNotEmpty,
    reason:
        '`${claim.key}: ${claim.expected}` is declared nowhere in '
        '${claim.file} — the prototype changed',
  );
  return hits.first;
}
