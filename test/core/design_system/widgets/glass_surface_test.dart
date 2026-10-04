import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _onSurface(
  Widget child, {
  ThemeData? theme,
  Size size = const Size(320, 240),
}) => evaAmbientHarness(
  theme: theme,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: Center(child: child),
  ),
);

/// A busy backdrop, so a `.blur` surface has something to blur.
///
/// A flat fill behind a `BackdropFilter` blurs to the same flat fill, and
/// `GlassTier.blur` would then be indistinguishable from [GlassTier.tint] — which
/// is precisely the mistake the "the two goldens must differ" requirement exists
/// to catch. Every blur assertion here therefore runs over [Backdrop].
const Widget _busy = _BusyBackdrop();

class _BusyBackdrop extends StatelessWidget {
  const _BusyBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF000000),
          Color(0xFFFFFFFF),
          Color(0xFFFF0000),
        ],
        stops: <double>[0, 0.5, 1],
      ),
    ),
    child: SizedBox.expand(),
  );
}

/// ## WHY THERE IS NO `tester.ensureSemantics()` HERE
///
/// `09-quality-gates.md` §14's correction says the working pattern per page is
/// `final handle = tester.ensureSemantics(); … handle.dispose();`, and it is
/// right that a handle must not leak. It is not needed for these assertions:
/// `AutomatedTestWidgetsFlutterBinding` turns the semantics tree **on** for every
/// `testWidgets`, so `find.bySemanticsLabel` and `tester.getSemantics` work
/// without one. Asking for a handle anyway is not harmless in both directions —
/// leaving it to `addTearDown` trips "a SemanticsHandle was active at the end of
/// the test", and disposing it in the body trips
/// `'_outstandingHandles > 0': is not true`, because the framework already
/// balanced the one it was holding.
void main() {
  group('GlassTier is an enum, not a bool', () {
    test('has exactly the two treatments §13.4 budgets', () {
      expect(GlassTier.values, <GlassTier>[GlassTier.tint, GlassTier.blur]);
    });

    test('tint is the default, because it is right on four of six screens', () {
      const GlassSurface surface = GlassSurface(child: SizedBox.shrink());
      expect(surface.tier, GlassTier.tint);
    });
  });

  group('GlassSurface.tint', () {
    testWidgets('paints the fill, rim and ambient from tokens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      const EvaColors colors = EvaColors.dark();
      expect(decoration.color, colors.glassFill);
      expect((decoration.border! as Border).top.color, colors.glassBorder);
      expect((decoration.border! as Border).top.width, 1);
      expect(decoration.boxShadow!.single.color, colors.glassShadow);
      expect(decoration.boxShadow!.single.offset, const Offset(0, 4));
      expect(decoration.boxShadow!.single.blurRadius, 24);
    });

    testWidgets('has no BackdropFilter anywhere in its subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
        reason: '§13.4 — a tint is not a saveLayer',
      );
    });

    testWidgets('rounds its corners to EvaRadii.card by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(EvaRadii.card),
      );
    });

    testWidgets('pads to EvaSpacing.card', (WidgetTester tester) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final Padding padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(EvaSpacing.card));
      expect(EvaSpacing.card, 20.0);
    });

    testWidgets('can drop the rim', (WidgetTester tester) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(border: false, child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).border, isNull);
    });
  });

  group('GlassSurface.blur', () {
    testWidgets('puts exactly one BackdropFilter in the subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.blur, child: SizedBox.shrink()),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
        reason:
            '§13.4 — every blur is one saveLayer, so the count is the budget',
      );
    });

    testWidgets('publishes the sigma, as far as the SDK can be asked', (
      WidgetTester tester,
    ) async {
      // `ImageFilter.blur` exposes no getter for its sigma, so the *number*
      // cannot be read back off the filter: `kGlassBlurSigma` is asserted here as
      // a constant and the filter as an `ImageFilter`, and the sigma itself is
      // pinned by the golden pair below. The name says so rather than claiming a
      // round trip that does not exist.
      //
      // **`24`, and it is the prototype's own number for this surface.** It used to
      // be `20`, justified as "the median of the eight prototype radii" — which was
      // false of the list it gave (the median of `8, 12, 12, 16, 16, 20, 20, 24` is
      // 16) and of the sites it named (Home's panel is `HomeScreen.tsx:39`'s
      // `blur(24px)`, not `20`). Only one site blurs, so there was never a
      // compromise to make; `glass_surface.dart`'s doc carries the whole correction.
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.blur, child: SizedBox.shrink()),
        ),
      );
      final BackdropFilter filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(kGlassBlurSigma, 24.0);
      expect(filter.filter, isA<ui.ImageFilter>());
    });

    testWidgets('the tint and blur goldens DIFFER over a busy backdrop', (
      WidgetTester tester,
    ) async {
      // Two captures in one body, and that is safe **here**: swapping a
      // `GlassTier` is not a theme change, so there is no `AnimatedTheme` lerp
      // to out-run. `streak_flame_test.dart` documents the mechanism and the
      // case where the same arrangement is not safe.
      tester.view.physicalSize = const Size(240, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pump(GlassTier tier, String name) async {
        await tester.pumpWidget(
          evaAmbientHarness(
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: _busy),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassSurface(
                      tier: tier,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(GlassSurface),
          matchesGoldenFile('goldens/glass_surface_$name.png'),
        );
      }

      await pump(GlassTier.tint, 'tint');
      await pump(GlassTier.blur, 'blur');
    });

    testWidgets('the two surfaces differ in pixels, not just in the tree', (
      WidgetTester tester,
    ) async {
      // The golden pair above is the record; this is the reason it must differ.
      // Without a busy backdrop a blur of a flat fill is the fill, and the pair
      // would be two identical images.
      tester.view.physicalSize = const Size(240, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget surface(GlassTier tier) => evaAmbientHarness(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _busy),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GlassSurface(
                  tier: tier,
                  padding: EdgeInsets.zero,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(surface(GlassTier.tint));
      await tester.pump();
      final List<int> tint = await _screenPixels(tester);

      await tester.pumpWidget(surface(GlassTier.blur));
      await tester.pump();
      final List<int> blur = await _screenPixels(tester);

      expect(tint.length, blur.length);
      expect(
        tint.toString(),
        isNot(blur.toString()),
        reason: 'a BackdropFilter over a gradient must change the pixels',
      );
    });
  });

  group('interaction and semantics', () {
    testWidgets('a plain surface adds no semantics node of its own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: Text('John 3:1-5'))),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Semantics),
        ),
        findsNothing,
        reason:
            'a panel the reader cannot act on must not appear in the '
            'semantics tree at all',
      );
      expect(find.text('John 3:1-5'), findsOneWidget);
    });

    testWidgets('a tappable surface is an InkWell in a Material', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () {},
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('a tappable surface announces itself as a button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () {},
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Today\'s reading'), findsOneWidget);
      final SemanticsNode node = tester.getSemantics(find.byType(GlassSurface));
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('a tappable surface fires onTap', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () => taps++,
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.tap(find.byType(GlassSurface));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the rim is the same pixel with and without `onTap`', (
      WidgetTester tester,
    ) async {
      // M4. Phase 3 passed `idleBorder: Border.all(colors.glassBorder, width: 1)`
      // to the `EvaFocusRing`, which is *the same border at the same 1px inset*
      // the inner `DecoratedBox` already paints — so `onTap: null` → `() {}`
      // double-drew the rim on every interactive panel. Measured over a 320-wide
      // dark canvas: the left-edge rim read R=32 without `onTap` and **R=43** with
      // it (43 = 32 + (255 − 32) × 0.078 — the same `glassBorder` alpha, laid down
      // twice), and 2272 of the panel's 12000 sampled bytes differed.
      //
      // The golden pair could not see any of it: `goldens/glass_surface_tint_*` is
      // captured from the **non-interactive** form, so the interactive variant had
      // no reference image at all. Hence a pixel assertion.
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<List<int>> rim(VoidCallback? onTap) async {
        await tester.pumpWidget(
          evaAmbientHarness(
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                child: GlassSurface(
                  onTap: onTap,
                  semanticLabel: "Today's reading",
                  padding: EdgeInsets.zero,
                  child: const SizedBox(width: 200, height: 60),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final RenderRepaintBoundary boundary = tester
            .renderObject<RenderRepaintBoundary>(
              find.descendant(
                of: find.byType(Align),
                matching: find.byType(RepaintBoundary),
              ),
            );
        final List<int>? bytes = await tester.runAsync<List<int>>(() async {
          final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          image.dispose();
          return data.buffer.asUint8List();
        });
        expect(bytes, isNotNull, reason: 'the panel produced no pixels at all');
        return bytes!;
      }

      final List<int> plain = await rim(null);
      final List<int> tappable = await rim(() {});

      // Read as **R of the left-edge pixel on the middle row**, which is the rim
      // and not the fill. `image.toByteData(format: rawRgba)` is premultiplied, so
      // over the harness's transparent backdrop `glassFill` (`#0DFFFFFF`) reads 13
      // and the rim over it (`#14FFFFFF`) reads 32. Both numbers are derived, not
      // asserted as literals — a gate that pinned 32 would fail the day the token
      // moved for a reason that has nothing to do with `onTap`.
      int leftRim(List<int> px) => px[(30 * 200) * 4];
      int fillR(List<int> px) => px[(30 * 200 + 1) * 4];
      expect(fillR(plain), 13, reason: 'glassFill over a transparent backdrop');
      expect(leftRim(plain), 32, reason: 'one glassBorder over that fill');

      expect(
        leftRim(tappable),
        leftRim(plain),
        reason:
            '§14 / M4 — `onTap` must not change the resting rim by one pixel. The '
            'ring REPLACES the idle border in the same band, and this surface '
            'already owns its resting border in its own decoration, so the ring\'s '
            'idle state has nothing to add.',
      );
      // The whole panel, not one pixel: a second draw anywhere — a corner arc, a
      // rounded edge — is the same defect wearing a smaller hat.
      expect(
        tappable.toString(),
        plain.toString(),
        reason: 'an interactive glass panel is pixel-identical to an inert one',
      );
    });

    testWidgets('a tappable surface without a label is a programming error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(GlassSurface(onTap: () {}, child: const SizedBox.shrink())),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('theming', () {
    testWidgets('light mode uses the light glass triple', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(child: SizedBox.shrink()),
          theme: EvaThemeLight.theme,
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      const EvaColors colors = EvaColors.light();
      expect(decoration.color, colors.glassFill);
      expect(decoration.boxShadow!.single.color, colors.glassShadow);
    });

    // The theme loop is deliberately OUTSIDE `testWidgets`, one test per theme:
    // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
    // `kThemeAnimationDuration`, and the single zero-duration `pump()` after
    // `pumpWidget` does not advance it — so two captures in one body wrote the
    // first palette into the second file and
    // `goldens/glass_surface_tint_light.png` was a byte-identical copy of the
    // dark one. See `streak_flame_test.dart`'s "why the goldens are one test per
    // theme" group, which pins the mechanism.
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('a golden per theme — $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(280, 180);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(child: SizedBox(width: 40, height: 20)),
            theme: theme,
            size: const Size(280, 180),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(GlassSurface),
          matchesGoldenFile('goldens/glass_surface_tint_$label.png'),
        );
      });
    }
  });

  group('the sigma doc table, against the prototype it transcribes', () {
    // The rows of `kGlassBlurSigma`'s doc table: name, prototype file, line, radius.
    // Parsed out of the doc comment itself, so the table is the subject and not a
    // second copy of it living here.
    //
    // The name is matched as **anything up to the parenthesis**, not as a backticked
    // token, and that is not looseness for its own sake: four of the nine rows are not
    // a single backticked name (`` `SealFAB` dock item ``, `` Login form ``), and a
    // parser that only understood the tidy five would have quietly covered five of
    // nine — which is the failure this group exists to prevent, one level up. The
    // first version of this pattern allowed backticks but not a space-separated name
    // and matched **two** of nine, which is why the anti-vacuity test below asserts a
    // count and not merely a non-empty list: a parser change is a silent coverage
    // change otherwise.
    final List<RegExpMatch> rows =
        RegExp(
              r'\|\s*([^|]+?)\s*\(`([^`]+):(\d+)`\)\s*\|\s*(\d+)\s*\|',
              multiLine: true,
            )
            .allMatches(
              File('lib/core/design_system/widgets/glass_surface.dart')
                  .readAsStringSync(),
            )
            .toList();

    test('the table is parsed out of the doc, and is not empty', () {
      // Anti-vacuity. Every check below iterates `rows`, so a reformat of the table
      // would otherwise turn this whole group into a green walk over nothing — which
      // is the exact shape of the failure this table already had once.
      expect(
        rows,
        hasLength(9),
        reason:
            'the table must list all nine prototype sites — seven in `ds.tsx` plus '
            'the two inline. Found ${rows.length}. A smaller number means a row was '
            'dropped or the table was reformatted, and every check below silently '
            'stopped covering it.',
      );
    });

    for (final RegExpMatch row in rows) {
      // Backticks stripped, so `_cutSites` spells a site the way a reader would.
      final String name = row.group(1)!.replaceAll('`', '').trim();
      final String file = row.group(2)!;
      final int line = int.parse(row.group(3)!);
      final int radius = int.parse(row.group(4)!);

      test('$name is really blur(${radius}px) at $file:$line', () {
        final File source = File('eva/src/${_prototypePath(file)}');
        expect(source.existsSync(), isTrue, reason: '$file does not exist');

        final List<String> lines = source.readAsLinesSync();
        expect(
          line - 1,
          lessThan(lines.length),
          reason: '$file has ${lines.length} lines, so `$line` is past the end',
        );

        expect(
          lines[line - 1],
          contains('blur(${radius}px)'),
          reason:
              '`glass_surface.dart` says `$name` is `blur(${radius}px)` at '
              '`$file:$line`, and that line says:\n${lines[line - 1]}\n\n'
              'A table of another repository numbers is a claim until something '
              'checks it, and this is what checks it.',
        );
      });
    }

    test('and the shipped sigma is the radius of the ONE site that blurs', () {
      // The claim the whole correction rests on: `HomeScreen.tsx:39` writes
      // `blur(24px)`, Home panel is the only `GlassTier.blur` site, and therefore
      // the sigma is `24` and not a compromise between eight radii. Read against the
      // prototype rather than against the constant, so a change that moved the
      // number and left the argument is red.
      final List<String> home = File('eva/src/screens/HomeScreen.tsx')
          .readAsLinesSync();

      expect(home[38], contains('blur(24px)'));
      expect(
        kGlassBlurSigma,
        24.0,
        reason:
            'only one site blurs, so there is no median to take: the sigma is the '
            'prototype own radius for that site',
      );
    });

    test('and NO surviving site is a 20, which is what the old median missed', () {
      // The falsifying check, and the one the old doc made impossible to write. The
      // two `20` sites are `PassageCard` and the `SealFAB` button, both cut — so `20`
      // was the median of a list in which the relevant entries are not present.
      final Set<int> shipping = <int>{
        for (final RegExpMatch row in rows)
          if (!_cutSites.contains(row.group(1)!.replaceAll('`', '').trim()))
            int.parse(row.group(4)!),
      };

      expect(
        shipping,
        <int>{8, 12, 16, 24},
        reason:
            'the radii of the sites that survive into the shipped app. If a cut '
            'screen is restored this list changes, and the sigma justification has '
            'to be re-derived rather than inherited.',
      );
      expect(
        shipping.contains(20),
        isFalse,
        reason:
            'a surviving `20` site is exactly the premise decision 34 relied on and '
            'the measurement showed does not exist',
      );
    });
  });
}

/// The prototype file a doc row names, relative to `eva/src`.
String _prototypePath(String name) => switch (name) {
  'ds.tsx' => 'components/ds.tsx',
  'HomeScreen.tsx' => 'screens/HomeScreen.tsx',
  'LoginScreen.tsx' => 'screens/LoginScreen.tsx',
  _ => throw StateError(
    'the sigma doc names a prototype file this test cannot find: $name. Add it to '
    '_prototypePath rather than skipping the row — an unmapped file means an '
    'unchecked claim.',
  ),
};

/// The doc-table sites that do **not** ship, and why.
///
/// A hard-coded set, and the reason it is *not* read from the table's third column is
/// that a self-certifying table proves nothing: the check has to live outside the
/// thing it checks. Adding a row here is a deliberate act with a reason attached.
const Set<String> _cutSites = <String>{
  'SealFAB dock item',
  'PassageCard',
  'SealFAB button',
};

Future<List<int>> _screenPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    image.dispose();
    return <int>[
      for (int i = 0; i < data.lengthInBytes; i += 997) data.getUint8(i),
    ];
  });
  return bytes ?? const <int>[];
}
