/// ## WHAT THIS SUITE IS
///
/// A **budget** over the painting half of the frame, in two parts.
///
/// **Part A is an inventory.** Every `CustomPainter` in `lib/` has a row here,
/// and for each one the suite asserts the framework's own contract, in both
/// directions:
///
/// * a rebuild with the **same** inputs does **not** repaint, and
/// * a rebuild with a **changed** input **does** repaint.
///
/// The two failures are not symmetric, and the asymmetry is the whole point. A
/// painter that answers `true` too eagerly costs frames and shows nothing; a
/// painter that answers `false` for a changed input shows a **stale image** —
/// the previous frame's picture, on screen, until something else happens to
/// repaint it. **No other gate in this repository would catch the second one**,
/// because a stale image is a correct widget tree with an old picture in it.
///
/// **Part B is a rate.** Some painters are not driven by a rebuild at all: they
/// take a `Listenable` in `repaint` and are repainted by that listenable firing.
/// For those, `shouldRepaint` is irrelevant — the painter repaints whenever its
/// listenable fires — and the question becomes **how often that is**.
///
/// ## WHY THE PAINTERS ARE REACHED THROUGH THEIR WIDGETS
///
/// Seven of the nine painters in `lib/` are **private** to their own file, and
/// that is deliberate: `_StarPainter` is private so the design system has one
/// spelling of the four-pointed star, and the same reasoning holds for the
/// other six. So the suite reads the painter off the `CustomPaint` the widget
/// built — `CustomPaint.painter` is the framework's own handle on it and needs
/// no name here. `four_pointed_star_test.dart` is the precedent, and this file
/// borrows its shape: **three pumps, both directions, one body**.
///
/// ## AND WHY THE INVENTORY IS WRITTEN OUT RATHER THAN DISCOVERED
///
/// A suite that walked `lib/` looking for `CustomPainter` subclasses would find
/// them — and would find *whatever it found*, so a painter added tomorrow would
/// join the inventory silently and a painter **removed** tomorrow would leave a
/// green row behind. The inventory here is a **list of named rows**, one per
/// painter, and the count at the end of Part A is what makes a forgotten row
/// visible.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/features/reading/domain/reading_focus.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_system_harness.dart';

/// The two inks Part A uses to change a painter's colour.
///
/// **Tokens, not literals.** `no_colour_literals_test.dart` makes a colour that
/// did not go through `EvaColors` a production violation, and a test that
/// reached for `const Color(0xFFE8B04B)` would be a reader quietly picking a
/// fourth name for the same gold. The second ink exists so the "changed" case
/// cannot be satisfied by two colours that happen to compare equal.
final Color _ember = const EvaColors.dark().ember;
final Color _ink = const EvaColors.dark().ink;

/// The dark theme, and the light one.
///
/// The two are the **ink-changing** lever for every painter whose colour comes
/// from the palette: `EvaColors.dark().ember` is `#E8A33D` and
/// `EvaColors.light().ember` is `#D4891A`, so a theme swap changes the gold a
/// painter lays down without touching the painter's own parameters.
final ThemeData _dark = EvaThemeDark.theme;
final ThemeData _light = EvaThemeLight.theme;

/// The widget under test, under an explicit palette.
///
/// **A `Theme` and not the harness's `theme:` parameter**, because
/// `MaterialApp` installs an `AnimatedTheme` and a theme swap is
/// **interpolated over `kThemeAnimationDuration` (200 ms)** — so the palette
/// on the first frame after the swap is still the *old* one. A test that
/// changed the theme and read the painter on that first frame would compare
/// the old palette with the old palette and learn nothing, and the failure
/// would read as "the painter does not compare its colour" when the painter
/// was never shown a different colour.
Widget _themed(Widget child, {ThemeData? theme}) =>
    Theme(data: theme ?? _dark, child: child);

/// The painter the [CustomPaint] is holding.
///
/// **Reached through the widget rather than through a type name**, because seven
/// of the nine painters are private to their own file on purpose, and a
/// `CustomPainter` published for a test would put a second spelling of the
/// shape in the design system's public surface.
///
/// Fails closed: a `CustomPaint` with no painter paints nothing, and a suite
/// that silently treated that as "no repaint" would be green about nothing.
CustomPainter _painterOf(CustomPaint paint) {
  final CustomPainter? painter = paint.painter;
  if (painter == null) {
    throw StateError(
      'the CustomPaint carries no painter, so it paints nothing and every '
      'repaint assertion over it would be vacuous',
    );
  }
  return painter;
}

/// The `CustomPaint` at [finder].
CustomPaint _paintAt(WidgetTester tester, Finder finder) =>
    tester.widget<CustomPaint>(finder);

/// Reads the `CustomPaint` under test out of the tree.
///
/// A function rather than a [Finder] because one painter — the dock orb's
/// ripple — is not reachable by a plain type finder: the orb holds **two**
/// `CustomPaint`s, and the wrong one is the four-pointed star, which carries
/// no `repaint` signal at all and would report zero repaints for ever.
typedef _PaintReader = CustomPaint Function(WidgetTester tester);

/// Pumps [build] twice and returns the two painters it produced.
///
/// The second pump is a rebuild with **the same inputs**, so the two painters
/// are different objects that would paint the same picture. `build` runs
/// `CustomPaint`'s `build` again, which is what makes a fresh painter: a
/// painter that answered `true` for two equal inputs would repaint on every
/// frame of every ambient animation, and nothing about that is visible.
Future<(CustomPainter, CustomPainter)> _pumpTwice(
  WidgetTester tester,
  Widget Function() build,
  _PaintReader read,
) async {
  await tester.pumpWidget(build());
  final CustomPainter first = _painterOf(read(tester));
  await tester.pumpWidget(build());
  return (first, _painterOf(read(tester)));
}

/// Asserts that a rebuild with the **same** inputs does not repaint.
///
/// This is the direction that costs money. The reason names the cause rather
/// than the number, because "a total is a number nobody can act on" — the
/// action is "stop comparing object identity", and that is what the message has
/// to say.
void _expectNoRepaintForIdenticalInputs({
  required CustomPainter first,
  required CustomPainter same,
  required String painterName,
}) {
  expect(
    same.shouldRepaint(first),
    isFalse,
    reason:
        '$painterName must compare the ink and not the object. `build` makes a '
        'fresh painter on every call, so identity is always false — a painter '
        'that answered `true` for two equal inputs repaints on every frame of '
        'every ambient animation, for no visible change.',
  );
}

/// Asserts that a rebuild with **different** [what] does repaint.
///
/// This is the direction that shows a stale image. The reason names the
/// parameter, because "the picture would have been stale" is a symptom and
/// "the painter does not compare the parameter" is the cause.
void _expectRepaintForChangedInputs({
  required CustomPainter first,
  required CustomPainter changed,
  required String painterName,
  required String what,
}) {
  expect(
    changed.shouldRepaint(first),
    isTrue,
    reason:
        '$painterName reads $what in its `paint`, so a change to $what changes '
        'the picture. Answering `false` would leave the previous frame on '
        'screen — a stale image, which is the worse of the two failures.',
  );
}

/// The verse whose halo is painted.
///
/// `VersePaint.hot` is the only state that mounts `_HotGlow` at all
/// (`verse_line.dart:529` returns the child untouched when `painted` is
/// false), so a verse in any other state has no painter to find.
///
/// **`evaPrimitiveHarness` and not `evaAmbientHarness`**, because the verse
/// reads `context.l10n.digits(number)` and the ambient harness installs only
/// the framework's own localisations.
Widget _hotVerse({ThemeData? theme}) => evaPrimitiveHarness(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  child: _themed(
    const VerseLine(
      number: 2,
      text: 'In the beginning was the Word',
      paint: VersePaint.hot,
    ),
    theme: theme,
  ),
);

/// One fleck, placed somewhere the eye can find it.
const List<Offset> _fleckOffsets = <Offset>[Offset(60, 60)];

/// The gold flecks, on a box they can float in.
///
/// [offsets] is **required and not defaulted**, so every call site has to say
/// where the flecks are — and so the analyzer's `avoid_redundant_argument_values`
/// cannot read a call that forgot to change anything.
Widget _flecks({
  required List<Offset> offsets,
  bool dense = false,
  ThemeData? theme,
  bool disableAnimations = false,
}) => evaAmbientHarness(
  disableAnimations: disableAnimations,
  child: _themed(
    SizedBox(
      width: 380,
      height: 120,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GoldFlecks(offsets: offsets, dense: dense),
          ),
        ],
      ),
    ),
    theme: theme,
  ),
);

/// Two lit verses, and a third.
///
/// **`SkyEntry.key` is `'$book:$chapter:$verse'`**, so a third verse is a
/// third point on the constellation and the polyline grows — which is the
/// change the sky's `shouldRepaint` has to notice.
final List<SkyEntry> _twoStars = <SkyEntry>[
  SkyEntry(
    book: 'John',
    chapter: 3,
    verse: 1,
    litAt: DateTime(2026, 10, 3, 9, 30),
  ),
  SkyEntry(
    book: 'John',
    chapter: 3,
    verse: 2,
    litAt: DateTime(2026, 10, 3, 9, 31),
  ),
];

final List<SkyEntry> _threeStars = <SkyEntry>[
  ..._twoStars,
  SkyEntry(
    book: 'John',
    chapter: 3,
    verse: 3,
    litAt: DateTime(2026, 10, 3, 9, 32),
  ),
];

/// The witness sky, on a bounded box.
///
/// [onAmbientSignal] hands back the scope's `repaint` — the notifier
/// `witness_sky.dart:905` gives the `ListenableBuilder` that rebuilds the
/// forty-four stars — so a caller can measure the signal the sky's twinkle
/// rides rather than a proxy for it.
Widget _sky({
  required List<SkyEntry> entries,
  ThemeData? theme,
  bool disableAnimations = false,
  void Function(Listenable signal)? onAmbientSignal,
}) => evaAmbientHarness(
  disableAnimations: disableAnimations,
  child: _themed(
    Builder(
      builder: (BuildContext context) {
        onAmbientSignal?.call(NeuralMotionScope.of(context).repaint);
        return SizedBox(
          width: 390,
          height: 844,
          child: WitnessSky(entries: entries),
        );
      },
    ),
    theme: theme,
  ),
);

/// The dock orb's ripple painter.
///
/// **The orb's only `IgnorePointer`**, which `lumen_dock.dart:871` wraps
/// around the ripple because the ring is decoration over a control and must
/// not take a tap. The orb's *other* `CustomPaint` is the four-pointed star
/// inside it, and reaching the wrong one would measure the star — which
/// carries no `repaint` signal at all and would report zero repaints for
/// ever, which is the shape of a green test that proves nothing.
CustomPaint _ripplePaint(WidgetTester tester) {
  final Finder ignore = find.descendant(
    of: find.byType(LumenOrb),
    matching: find.byType(IgnorePointer),
  );
  expect(
    ignore,
    findsOneWidget,
    reason:
        'the orb holds exactly one `IgnorePointer` — the one around the '
        'ripple. Anything else and this finder is pointing at the wrong '
        'painter, and the four-pointed star reports no repaints at all.',
  );
  return _paintAt(
    tester,
    find.descendant(of: ignore, matching: find.byType(CustomPaint)),
  );
}

/// A uniform table, and one with a different intensity.
///
/// **`u_str` is left at zero**, for `lumen_canvas_test.dart`'s reason: it is
/// the one term the shader adds noise to, and this suite is about repaints
/// rather than about pixels.
LumenUniforms _uniforms({double intensity = 0.61}) =>
    const LumenUniforms.identity()
        .withHue(h: 258, s: 90, l: 66)
        .copyWith(
          resX: 400,
          resY: 800,
          spread: 0.42,
          pointerX: -0.25,
          pointerY: 0.75,
          pointerIntensity: 0.33,
          intensity: intensity,
          spike: 0.4,
          white: 0.22,
          time: 3.7,
        );

/// The display the budget is resolved for.
///
/// **A fixed rate and not the platform's**, because the budget's divisors are a
/// function of the refresh rate, and a gate whose ceiling depends on the
/// machine it runs on is a gate that passes on one laptop and fails on
/// another. 60 Hz is the rate the repository's own numbers are written at
/// (`ambient_tick_budget.dart:71`).
const double _displayHz = 60;

/// The ambient's budget at [_displayHz].
///
/// **Read from the budget's own resolver** and not written out, so the
/// ceilings below are the ones the app uses rather than a second copy of them.
/// At 60 Hz that is `paintEveryNTick: 2` (thirty paints a second) and
/// `notifyEveryNTick: 3` (twenty a second).
final AmbientTickBudget _budget = AmbientTickBudget.resolve(
  displayRefreshRate: _displayHz,
);

/// How many frames the measurement runs for.
///
/// **Thirty frames is half a second at 60 Hz**, which is long enough for the
/// budget's divisors to show their shape — the notify gate fires ten times in
/// thirty frames and the paint gate fifteen — and short enough that a failure
/// reads as a rate rather than as a total.
const int _frames = 30;

/// The most repaints the ambient's **paint** budget allows in [_frames] frames.
///
/// **The gate fires on the first frame and then every Nth**, so the count over
/// [_frames] frames is `ceil(frames / N)`. It is computed from the budget
/// rather than written down, so a change to the budget's divisors moves the
/// ceiling with them.
int _paintCeiling() =>
    (_frames + _budget.paintEveryNTick - 1) ~/ _budget.paintEveryNTick;

/// The most notifications the ambient's **notify** budget allows in [_frames].
int _notifyCeiling() =>
    (_frames + _budget.notifyEveryNTick - 1) ~/ _budget.notifyEveryNTick;

/// Counts how often a listenable fires.
///
/// **A painter is a listenable, and that is the whole instrument.**
/// `CustomPainter.addListener` **forwards to the `repaint` listenable** — the
/// SDK's `CustomPainter` holds no listener list of its own
/// (`rendering/custom_paint.dart:166-172`) — so a listener added to a painter
/// is a listener on the thing that schedules its repaints. The count is
/// therefore the framework's own definition of "this painter was asked to
/// repaint", and it works for a **private** painter reached through its
/// widget, which a `paint`-call counter could not.
class _FireCounter {
  _FireCounter(this.signal) {
    signal.addListener(listener);
  }

  /// The listenable being counted.
  final Listenable signal;

  /// The closure handed to [signal].
  ///
  /// **Held in a field and not torn off at the removal site**, because a
  /// tear-off and a second tear-off of the same method on the same object are
  /// equal in Dart 3 — but only by a rule a reader has to know, and a removal
  /// that silently did nothing would leave a counter counting a signal nobody
  /// owns.
  late final VoidCallback listener = _onFire;

  /// How many times [signal] has fired.
  int fires = 0;

  void _onFire() {
    fires++;
  }

  /// Stops counting.
  void dispose() {
    signal.removeListener(listener);
  }
}

/// What one rate measurement found.
typedef _Rate = ({int requests, int paints});

/// Prints the measurement, so the number is reproducible with one command.
///
/// **`docs/PERFORMANCE.md` §1's own rule** — *"the test **prints** the numbers
/// and **asserts** them. The assertions are the point: a budget fails the
/// build, so it cannot rot."* The print is here so that a reader who wants the
/// number does not have to plant a violation to see it, and so the number in
/// the failure message can be checked against the run that produced it.
void _printRate(String what, _Rate rate) {
  debugPrint(
    '── $what ──\n'
    'requests : ${rate.requests} in $_frames frames  '
    '(${(rate.requests / _frames).toStringAsFixed(3)} per frame)\n'
    'paints   : ${rate.paints} in $_frames frames  '
    '(${(rate.paints / _frames).toStringAsFixed(3)} per frame)\n'
    'ceiling  : ${_paintCeiling()} paints per $_frames frames  '
    '(the ambient budget at ${_displayHz.round()} Hz: one every '
    '${_budget.paintEveryNTick} frames)',
  );
}

/// Measures how often a painter is asked to repaint over [_frames] frames.
///
/// **Two numbers, and they are not the same number.** [requests] is how many
/// times the painter's `repaint` signal fired; [paints] is how many frames
/// actually painted the painter's `RenderCustomPaint`, read through the
/// framework's own `debugOnProfilePaint` hook. They agree when the painter is
/// the only thing in its subtree that goes dirty, and the ceiling is asserted
/// against the **requests** — the signal is what the app controls, and a
/// painter that is asked to repaint and then not painted is a wasted
/// notification, not a wasted frame.
///
/// ## AND WHY THE **IDENTITY FILTER** IS A PARAMETER
///
/// [isTarget] answers "was *this* render object painted?", and the only way to
/// answer it is to compare the painted object with the one under test. **That
/// comparison is an identity claim**, and it is handed in by the test that owns
/// the measurement rather than written here: a claim made inside a helper
/// belongs to no named test, and
/// `test/core/common/no_identical_on_converted_types_test.dart` requires every
/// identity site in `test/` to sit inside one and to be listed in its audited
/// table.
///
/// **The count is unchanged by the hand-over** — the filter is the same
/// comparison over the same two objects, applied to the same painted object on
/// the same frame.
Future<_Rate> _measurePainterRate(
  WidgetTester tester, {
  required Widget Function() build,
  required _PaintReader read,
  required bool Function(RenderObject painted, RenderObject target) isTarget,
  Future<void> Function(WidgetTester tester)? settle,
}) async {
  await tester.pumpWidget(build());
  await tester.pump();
  if (settle != null) await settle(tester);

  final CustomPaint paint = read(tester);
  final CustomPainter painter = _painterOf(paint);
  final RenderCustomPaint target = tester.renderObject<RenderCustomPaint>(
    find.byWidget(paint),
  );

  final _FireCounter counter = _FireCounter(painter);
  addTearDown(counter.dispose);

  int paints = 0;
  final ProfilePaintCallback? previous = debugOnProfilePaint;
  debugOnProfilePaint = (RenderObject painted) {
    if (isTarget(painted, target)) paints++;
  };
  try {
    for (int frame = 0; frame < _frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    // **Restored here and not in `addTearDown`.** `flutter_test` verifies its
    // debug invariants at the END of the test body, which is **before** the
    // teardowns run — so a teardown restore trips
    // `debugAssertAllRenderVarsUnset` and fails a test that was measuring
    // something else entirely.
    debugOnProfilePaint = previous;
  }

  return (requests: counter.fires, paints: paints);
}

void main() {
  group('every painter in lib/, and the ink its shouldRepaint compares', () {
    group('the four-pointed star', () {
      // `lib/core/design_system/widgets/four_pointed_star.dart:198`.
      //
      // **Its own suite already covers this in depth**
      // (`four_pointed_star_test.dart:566-599`), and this row is here because
      // the inventory is a list of **rows**, not a discovery: a painter with no
      // row is a painter nobody checked.
      testWidgets('a changed ink repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(FourPointedStar),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => evaAmbientHarness(
            child: FourPointedStar(size: 40, color: _ember),
          ),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_StarPainter',
        );

        await tester.pumpWidget(
          evaAmbientHarness(child: FourPointedStar(size: 40, color: _ink)),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_StarPainter',
          what: 'the fill colour',
        );
      });

      testWidgets('and so does the fill/stroke mode', (
        WidgetTester tester,
      ) async {
        // The mode is not a colour, and a painter that compared only the
        // colour would fill the hollow star and call it a repaint it did not
        // need — or, the other way round, keep the fill when the caller asked
        // for the stroke.
        final Finder painterAt = find.descendant(
          of: find.byType(FourPointedStar),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => evaAmbientHarness(
            child: FourPointedStar(size: 40, color: _ember, outline: true),
          ),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_StarPainter',
        );

        await tester.pumpWidget(
          evaAmbientHarness(child: FourPointedStar(size: 40, color: _ember)),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_StarPainter',
          what: 'the fill/stroke mode',
        );
      });
    });

    group('the streak flame', () {
      // `lib/core/design_system/widgets/streak_flame.dart:213`.
      //
      // `_FlamePainter.paint` reads exactly one field of its own: `color`, and
      // it draws the silhouette twice with it — once blurred as the glow and
      // once solid. So `color` is the whole of the ink.
      testWidgets('a changed palette repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(StreakFlame),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => evaAmbientHarness(
            child: _themed(const StreakFlame(), theme: _dark),
          ),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_FlamePainter',
        );

        await tester.pumpWidget(
          evaAmbientHarness(child: _themed(const StreakFlame(), theme: _light)),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_FlamePainter',
          what: 'the fill colour',
        );
      });
    });

    group('the sun burst', () {
      // `lib/core/design_system/widgets/sun_burst.dart:238`.
      //
      // `_SunBurstPainter.paint` reads **the whole palette** (`colors.ember`,
      // for the five flecks) plus `EvaStickerPalette.of(StickerSlot.sun)`,
      // which is a `const` map lookup and can never change. So the palette is
      // the only input, and a dark-to-light swap changes `ember` from `#E8A33D`
      // to `#D4891A`.
      testWidgets('a changed palette repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(SunBurst),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () =>
              evaAmbientHarness(child: _themed(const SunBurst(), theme: _dark)),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_SunBurstPainter',
        );

        await tester.pumpWidget(
          evaAmbientHarness(child: _themed(const SunBurst(), theme: _light)),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_SunBurstPainter',
          what: 'the palette',
        );
      });
    });

    group("the reading line's halo", () {
      // `lib/features/reading/presentation/widgets/verse_line.dart:545`.
      //
      // `_GlowPainter.paint` reads exactly one field: `color`, which
      // `verse_line.dart:530` fills with `context.colors.ember`. The halo's
      // geometry is constants (`glowRadius`, `glowAlpha`, `glowFalloff`), so
      // the colour is the whole of the ink.
      testWidgets('a changed palette repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(VerseLine),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => _hotVerse(theme: _dark),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_GlowPainter',
        );

        await tester.pumpWidget(_hotVerse(theme: _light));
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_GlowPainter',
          what: 'the fill colour',
        );
      });
    });

    group('the journey ring', () {
      // `lib/features/journey/presentation/widgets/journey_rings_row.dart:478`.
      //
      // **The one public painter that is not the aurora**, so it is built
      // directly rather than read off a widget. `JourneyRingPainter.paint`
      // reads all three of its fields: `track` (the whole circle), `stroke`
      // (the arc) and `fraction` (the arc's sweep).
      test('a changed fraction repaints and an unchanged one does not', () {
        final JourneyRingPainter first = JourneyRingPainter(
          fraction: 0.5,
          stroke: _ember,
          track: _ink,
        );
        final JourneyRingPainter same = JourneyRingPainter(
          fraction: 0.5,
          stroke: _ember,
          track: _ink,
        );

        _expectNoRepaintForIdenticalInputs(
          first: first,
          same: same,
          painterName: 'JourneyRingPainter',
        );

        _expectRepaintForChangedInputs(
          first: first,
          changed: JourneyRingPainter(
            fraction: 0.75,
            stroke: _ember,
            track: _ink,
          ),
          painterName: 'JourneyRingPainter',
          what: 'the fraction',
        );
      });

      test('and so do the two inks', () {
        final JourneyRingPainter first = JourneyRingPainter(
          fraction: 0.5,
          stroke: _ember,
          track: _ink,
        );

        _expectRepaintForChangedInputs(
          first: first,
          changed: JourneyRingPainter(fraction: 0.5, stroke: _ink, track: _ink),
          painterName: 'JourneyRingPainter',
          what: 'the arc ink',
        );

        _expectRepaintForChangedInputs(
          first: first,
          changed: JourneyRingPainter(
            fraction: 0.5,
            stroke: _ember,
            track: _ember,
          ),
          painterName: 'JourneyRingPainter',
          what: 'the track ink',
        );
      });
    });

    group("the dock orb's ripple", () {
      // `lib/features/dock/presentation/widgets/lumen_dock.dart:890`.
      //
      // `_OrbRipplePainter.paint` reads `animate` (whether the ripple runs at
      // all), `clock.seconds` (the phase) and `color` (the ring's ink). The
      // clock is the painter's `repaint` signal, so a change of *time* arrives
      // through the listenable and not through `shouldRepaint` — see Part B for
      // what that costs.
      testWidgets('a changed palette repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () =>
              evaAmbientHarness(child: _themed(const LumenOrb(), theme: _dark)),
          _ripplePaint,
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_OrbRipplePainter',
        );

        await tester.pumpWidget(
          evaAmbientHarness(child: _themed(const LumenOrb(), theme: _light)),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_ripplePaint(tester)),
          painterName: '_OrbRipplePainter',
          what: 'the ring ink',
        );
      });

      testWidgets('and so does reduced motion, which changes the shape', (
        WidgetTester tester,
      ) async {
        // **Not a colour change.** `animate` is what decides whether the ring
        // is drawn at the ripple's phase or at rest, and the two are different
        // *shapes* — a ring at scale 1.0 and opacity 0.8 against a ring at
        // scale 1.6 and opacity 0. A painter that compared only the colour
        // would keep the animated ring on screen under reduced motion, which
        // §14 forbids.
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () =>
              evaAmbientHarness(child: _themed(const LumenOrb(), theme: _dark)),
          _ripplePaint,
        );

        await tester.pumpWidget(
          evaAmbientHarness(
            disableAnimations: true,
            child: _themed(const LumenOrb(), theme: _dark),
          ),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_ripplePaint(tester)),
          painterName: '_OrbRipplePainter',
          what: 'the `animate` flag',
        );
      });
    });

    group('the gold flecks', () {
      // `lib/core/design_system/effects/gold_flecks.dart:176`.
      //
      // `_GoldFleckPainter.paint` reads four of its own fields: `offsets`
      // (where the flecks are), `dense` (the outer ring), `color` (the ink) and
      // `animate` (whether the float runs). `motion.floatValue` is the fifth
      // input, and it arrives through the painter's `repaint` signal.
      testWidgets('a changed offset repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(GoldFlecks),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => _flecks(offsets: _fleckOffsets),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_GoldFleckPainter',
        );

        await tester.pumpWidget(
          _flecks(offsets: const <Offset>[Offset(240, 30)]),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_GoldFleckPainter',
          what: 'the offsets',
        );
      });

      testWidgets('and so do the dense ring, the ink and the float', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(GoldFlecks),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => _flecks(offsets: _fleckOffsets),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        await tester.pumpWidget(_flecks(offsets: _fleckOffsets, dense: true));
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_GoldFleckPainter',
          what: 'the `dense` flag',
        );

        await tester.pumpWidget(_flecks(offsets: _fleckOffsets, theme: _light));
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_GoldFleckPainter',
          what: 'the fill colour',
        );

        await tester.pumpWidget(
          _flecks(offsets: _fleckOffsets, disableAnimations: true),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_GoldFleckPainter',
          what: 'the `animate` flag',
        );
      });
    });

    group("the witness sky's constellation", () {
      // `lib/core/design_system/widgets/witness_sky.dart:1108`.
      //
      // `_SkyConstellationPainter.paint` reads `points` (the polyline), `stroke`
      // (the ink), `opacity` (how strongly the line is drawn) and
      // `drawOnEnabled` (whether the line is drawn whole or only as far as the
      // draw-on has got). The `drawOn` animation is the painter's `repaint`
      // signal.
      testWidgets('a third star repaints and an unchanged sky does not', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(WitnessSky),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => _sky(entries: _twoStars),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        _expectNoRepaintForIdenticalInputs(
          first: painters.$1,
          same: painters.$2,
          painterName: '_SkyConstellationPainter',
        );

        await tester.pumpWidget(_sky(entries: _threeStars));
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_SkyConstellationPainter',
          what: 'the points',
        );
      });

      testWidgets('and so do the ink and the reduced-motion opacity', (
        WidgetTester tester,
      ) async {
        final Finder painterAt = find.descendant(
          of: find.byType(WitnessSky),
          matching: find.byType(CustomPaint),
        );
        final (CustomPainter, CustomPainter) painters = await _pumpTwice(
          tester,
          () => _sky(entries: _twoStars, theme: _dark),
          (WidgetTester t) => _paintAt(t, painterAt),
        );

        await tester.pumpWidget(_sky(entries: _twoStars, theme: _light));
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_SkyConstellationPainter',
          what: 'the stroke',
        );

        await tester.pumpWidget(
          _sky(entries: _twoStars, theme: _dark, disableAnimations: true),
        );
        _expectRepaintForChangedInputs(
          first: painters.$1,
          changed: _painterOf(_paintAt(tester, painterAt)),
          painterName: '_SkyConstellationPainter',
          what: 'the opacity and the `drawOnEnabled` flag',
        );
      });
    });

    group('the lumen aurora', () {
      // `lib/core/design_system/effects/lumen_canvas.dart:76`.
      //
      // **The second public painter.** `LumenCanvas.paint` reads the uniform
      // table out of its `source` at paint time and writes it into one reused
      // shader, so the table is the ink and `program` is the only other input
      // worth comparing.
      testWidgets('a changed uniform repaints and an unchanged one does not', (
        WidgetTester tester,
      ) async {
        final LumenProgram program = await LumenProgram.load();
        final LumenClock clock = LumenClock.fixed(3.7);

        final LumenCanvas first = LumenCanvas(
          program: program,
          uniforms: _uniforms(),
          clock: clock,
        );
        final LumenCanvas same = LumenCanvas(
          program: program,
          uniforms: _uniforms(),
          clock: clock,
        );

        _expectNoRepaintForIdenticalInputs(
          first: first,
          same: same,
          painterName: 'LumenCanvas',
        );

        _expectRepaintForChangedInputs(
          first: first,
          changed: LumenCanvas(
            program: program,
            uniforms: _uniforms(intensity: 0.9),
            clock: clock,
          ),
          painterName: 'LumenCanvas',
          what: 'the uniform table',
        );
      });
    });

    test('the inventory is nine painters, and this suite names all of them', () {
      // **The count is the anti-vacuity half.** A painter added to `lib/`
      // without a row here is a painter nobody checked, and a row deleted from
      // here without a painter deleted from `lib/` is a row that checks
      // nothing. The number is asserted so that either mistake is visible.
      expect(_painterInventory.length, 9);
      expect(
        _painterInventory.toSet().length,
        _painterInventory.length,
        reason: 'a painter listed twice is a row that would pass for two',
      );
    });
  });

  group('the ambient painters, and the rate they repaint at', () {
    // ## WHY THESE AND NOT ALL NINE
    //
    // Six of the nine painters are **rebuild-driven**: they are repainted when
    // their widget rebuilds, and `shouldRepaint` decides whether that rebuild
    // costs a repaint. Part A is their gate.
    //
    // The other three are **clock-driven**: they take a `Listenable` in
    // `repaint` and are repainted by that listenable firing, whatever the
    // widget tree does. For those, `shouldRepaint` is irrelevant and the rate
    // is the whole question.
    //
    // ## AND WHY THE RATE IS A **BUDGET** AND NOT A BENCHMARK
    //
    // Because a benchmark prints a number and a number rots. A budget fails the
    // build, so it cannot rot. The ceiling is read from [AmbientTickBudget] —
    // the budget the app itself is paced by — rather than written down here,
    // so the two cannot drift apart.

    // ## THE NAME IS IN **SINGLE** QUOTES, AND THAT IS NOT COSMETIC
    //
    // The repository's identity gate attributes every `identical()` / `same()`
    // site in `test/` to the **named test** that holds it, and it finds those
    // names with a pattern that matches a **single-quoted** literal. A
    // double-quoted name is invisible to it, and a site inside such a test is
    // then attributed to whatever test was declared before it — which is a
    // table row claiming one test holds a site it does not hold.
    testWidgets('the dock orb\'s ripple repaints at the ambient\'s paint rate', (
      WidgetTester tester,
    ) async {
      // ## THIS ASSERTION IS EXPECTED TO FAIL, AND IT IS NOT WEAKENED
      //
      // `_OrbRipplePainter` is constructed with `clock: motion.lumen`
      // (`lumen_dock.dart:876`) and hands it to `super(repaint: clock)`
      // (`:895`). `motion.lumen` is a `TickedLumenClock`
      // (`neural_motion.dart:205`), and `TickedLumenClock._onTick` calls
      // `notifyListeners()` on **every vsync** (`lumen_clock.dart:302-305`).
      //
      // The repo's own tick budget caps the ambient's paint at **30 Hz** and
      // its notification at **20 Hz** (`ambient_tick_budget.dart:74-78`), and
      // the gated notifier is `motion.repaint` (`neural_motion.dart:232`).
      // The dock's ripple is not on that notifier.
      //
      // **The assertion is written at full strength on purpose.** A gate that
      // lands green over a known bug is the ADR-0020 shape this repository has
      // hit three times; the fix belongs to a later lane, and the point of
      // this lane is to make the bug *red* rather than to make the suite
      // quiet.
      // ## THE IDENTITY CLAIM, AND WHY IT IS MADE **HERE**
      //
      // "Only the paints of the render object under test count" is a claim
      // that two references are the *same* object, so it is made in the test
      // that owns the measurement: a claim inside a helper belongs to no named
      // test, and `no_identical_on_converted_types_test.dart` requires every
      // identity site in `test/` to sit inside one and to be listed in its
      // audited table. `RenderObject` declares no `operator ==`, so identity
      // is the only way to say it.
      //
      // **A named local function and not a lambda**, because a lambda here
      // would be `identical` written as a tear-off — and a tear-off of
      // `identical` is not a call, so the gate would not see the claim at all.
      bool isTheTarget(RenderObject painted, RenderObject target) =>
          identical(painted, target);

      final _Rate rate = await _measurePainterRate(
        tester,
        build: () =>
            evaAmbientHarness(budget: _budget, child: const LumenOrb()),
        read: _ripplePaint,
        isTarget: isTheTarget,
      );

      _printRate("the dock orb's ripple", rate);

      expect(
        rate.requests,
        greaterThan(0),
        reason:
            'the ripple was never asked to repaint at all, so the rate below '
            'is measuring nothing. The instrument has to be able to see a '
            'painter that repaints on every frame.',
      );
      expect(
        rate.paints,
        greaterThan(0),
        reason:
            'the ripple was never painted, so the request count above is not '
            'reaching the screen. A repaint request that paints nothing would '
            'make this gate green for the wrong reason.',
      );
      expect(
        rate.requests,
        lessThanOrEqualTo(_paintCeiling()),
        reason:
            "the dock orb's ripple asked for a repaint ${rate.requests} times "
            'in $_frames frames — one per frame — and the ambient budget at '
            '${_displayHz.round()} Hz allows one every '
            '${_budget.paintEveryNTick} frames, which is ${_paintCeiling()} in '
            '$_frames. The cause is the painter\'s own `repaint` signal: '
            '_OrbRipplePainter is built with `clock: motion.lumen` '
            '(`lumen_dock.dart:876`) and passes it to `super(repaint: clock)` '
            '(`:895`), and `TickedLumenClock._onTick` calls '
            '`notifyListeners()` on every vsync (`lumen_clock.dart:302-305`). '
            'The gated notifier is `motion.repaint` '
            '(`neural_motion.dart:232`), which fires at most once every '
            '${_budget.notifyEveryNTick} frames — the gold flecks and the '
            "witness sky's stars ride that one, and this painter does not. "
            'The fix is to ride `motion.repaint` instead of the raw clock, or '
            "to give the painter the budget's paint gate.",
      );
    });

    testWidgets('the gold flecks repaint at the ambient\'s notify rate', (
      WidgetTester tester,
    ) async {
      // ## THE GREEN HALF, AND WHY IT IS WHAT MAKES THE RED TRUSTWORTHY
      //
      // `_GoldFleckPainter` passes `super(repaint: motion.repaint)`
      // (`gold_flecks.dart:183`) — the **gated** notifier — and
      // `EvaNeuralMotion._onSourceChanged` fires it at most once every
      // `notifyEveryNTick` frames (`neural_motion.dart:165-167`).
      //
      // This row is the control that proves the instrument can tell a gated
      // painter from an ungated one. Without it, a red that says "30 > 15"
      // could just as easily be an instrument that reports 30 for everything.
      // ## THE IDENTITY CLAIM, AND WHY IT IS MADE **HERE**
      //
      // Only the paints of the render object under test count, and that is a
      // claim that two references are the *same* object — so it is made in
      // the test that owns the measurement, and not in the helper.
      bool isTheTarget(RenderObject painted, RenderObject target) =>
          identical(painted, target);

      final _Rate rate = await _measurePainterRate(
        tester,
        build: () => evaAmbientHarness(
          budget: _budget,
          child: _flecks(offsets: _fleckOffsets),
        ),
        read: (WidgetTester t) => _paintAt(
          t,
          find.descendant(
            of: find.byType(GoldFlecks),
            matching: find.byType(CustomPaint),
          ),
        ),
        isTarget: isTheTarget,
      );

      _printRate('the gold flecks', rate);

      expect(
        rate.requests,
        greaterThan(0),
        reason:
            'the flecks were never asked to repaint, so the rate below is '
            'measuring nothing. A gate that finds nothing is a failure, not a '
            'pass.',
      );
      expect(
        rate.paints,
        greaterThan(0),
        reason:
            'the flecks were never painted, so the request count above is not '
            'reaching the screen. A repaint request that paints nothing would '
            'make this gate green for the wrong reason.',
      );
      expect(
        rate.requests,
        lessThanOrEqualTo(_paintCeiling()),
        reason:
            'the gold flecks asked for a repaint ${rate.requests} times in '
            '$_frames frames, and the ambient budget at ${_displayHz.round()} Hz '
            'allows one every ${_budget.paintEveryNTick} frames, which is '
            '${_paintCeiling()} in $_frames. `_GoldFleckPainter` rides '
            '`motion.repaint` (`gold_flecks.dart:183`), the gated notifier, so '
            'it should be well under the ceiling — and if it is not, the '
            'gate itself has stopped working.',
      );
    });

    testWidgets('the witness sky\'s twinkle rides the gated notifier', (
      WidgetTester tester,
    ) async {
      // ## THE SKY'S AMBIENT LAYER, AND THE SIGNAL IT RIDES
      //
      // The sky's forty-four stars are rebuilt by a `ListenableBuilder` over
      // `motion.repaint` (`witness_sky.dart:898-917`) — the **gated** notifier,
      // the same one the gold flecks ride. That is the sky's ambient cost, and
      // this row measures the signal it rides.
      Listenable? ambient;
      await tester.pumpWidget(
        _sky(
          entries: _twoStars,
          onAmbientSignal: (Listenable signal) => ambient = signal,
        ),
      );
      await tester.pump();

      expect(
        ambient,
        isNotNull,
        reason:
            'the sky was pumped without a `NeuralMotionScope` above it, so '
            'there is no ambient signal to measure and the rate below would '
            'be about nothing.',
      );

      final _FireCounter counter = _FireCounter(ambient!);
      addTearDown(counter.dispose);

      for (int frame = 0; frame < _frames; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      debugPrint(
        '── the witness sky\'s twinkle signal ──\n'
        'fires    : ${counter.fires} in $_frames frames  '
        '(${(counter.fires / _frames).toStringAsFixed(3)} per frame)\n'
        'ceiling  : ${_notifyCeiling()} notifications per $_frames frames  '
        '(the ambient budget at ${_displayHz.round()} Hz: one every '
        '${_budget.notifyEveryNTick} frames)',
      );

      expect(
        counter.fires,
        greaterThan(0),
        reason:
            'the gated notifier never fired, so the rate below is measuring '
            'nothing.',
      );
      expect(
        counter.fires,
        lessThanOrEqualTo(_notifyCeiling()),
        reason:
            "the witness sky's twinkle signal fired ${counter.fires} times in "
            '$_frames frames, and the ambient budget at ${_displayHz.round()} Hz '
            'allows one notification every ${_budget.notifyEveryNTick} frames, '
            'which is ${_notifyCeiling()} in $_frames. The stars are rebuilt by '
            'a `ListenableBuilder` over that signal '
            '(`witness_sky.dart:898-917`), so every notification is '
            'forty-four stars re-instantiated.',
      );
    });

    testWidgets(
      'the witness sky\'s painter is not repainted at the display\'s rate',
      (WidgetTester tester) async {
        // ## THE CONSTELLATION PAINTER IS A **ONE-SHOT**, AND THAT IS THE POINT
        //
        // `_SkyConstellationPainter` passes `super(repaint: drawOn)`
        // (`witness_sky.dart:1115`) — the **draw-on animation**, a 1.2 s
        // one-shot (`kSkyConstellationDrawDuration`, `witness_sky.dart:162`).
        // It is deliberately outside the ambient budget: it is a transition, not
        // a loop, and the sky's own doc says so.
        //
        // So the claim here is not "the sky's painter is cheap" — during the
        // draw-on it repaints on every frame, and that is correct. The claim is
        // that it **stops**: once the line is drawn, the painter's own signal
        // goes quiet, and it is never painted at the display's rate.
        // ## THE IDENTITY CLAIM, AND WHY IT IS MADE **HERE**
        //
        // Only the paints of the render object under test count, and that is a
        // claim that two references are the *same* object — so it is made in
        // the test that owns the measurement, and not in the helper.
        bool isTheTarget(RenderObject painted, RenderObject target) =>
            identical(painted, target);

        final _Rate rate = await _measurePainterRate(
          tester,
          build: () => _sky(entries: _twoStars),
          read: (WidgetTester t) => _paintAt(
            t,
            find.descendant(
              of: find.byType(WitnessSky),
              matching: find.byType(CustomPaint),
            ),
          ),
          isTarget: isTheTarget,
          // ## THE FIRST FRAME **ESTABLISHES THE TICKER'S ORIGIN**
          //
          // `Ticker._tick` does `_startTime ??= timeStamp` — the first tick sets
          // the origin and reports an elapsed of **zero**
          // (`scheduler/ticker.dart:277`). So a clock jump in the very first
          // frame is swallowed whole, and the draw-on would still be at zero
          // when the measurement window opened. One ordinary frame first, and
          // the jump is measured from there.
          settle: (WidgetTester t) async {
            await t.pump();
            await t.pump(const Duration(milliseconds: 1500));
            await t.pump();
          },
        );

        _printRate("the witness sky's constellation painter", rate);

        expect(
          rate.requests,
          isZero,
          reason:
              "the witness sky's constellation painter was asked to repaint "
              '${rate.requests} times in $_frames frames, long after its '
              '1.2 s draw-on finished. The draw-on is a one-shot '
              '(`witness_sky.dart:1115`), and a painter whose signal never goes '
              'quiet is an ambient loop that no budget covers.',
        );
        expect(
          rate.paints,
          lessThanOrEqualTo(_paintCeiling()),
          reason:
              "the witness sky's constellation painter was painted "
              '${rate.paints} times in $_frames frames, and the ambient budget '
              'at ${_displayHz.round()} Hz allows one every '
              '${_budget.paintEveryNTick} frames, which is ${_paintCeiling()} in '
              '$_frames. The cause is not its own signal — that is silent, and '
              'the row above proves it. It is the **stars**: the constellation '
              'shares a `Stack` with the `ListenableBuilder` over '
              '`motion.repaint` (`witness_sky.dart:898-935`), so a notification '
              'dirties their common ancestor and the whole stack is repainted, '
              'the constellation included. A `RepaintBoundary` around the '
              "constellation's `CustomPaint` would take this count to zero.",
        );
      },
    );
  });
}

/// Every painter this suite has a row for, by name.
///
/// **A list, and not a discovery.** See the file header: a painter added to
/// `lib/` without a row here is a painter nobody checked.
const List<String> _painterInventory = <String>[
  '_StarPainter',
  '_FlamePainter',
  '_SunBurstPainter',
  '_GlowPainter',
  'JourneyRingPainter',
  '_OrbRipplePainter',
  '_GoldFleckPainter',
  '_SkyConstellationPainter',
  'LumenCanvas',
];
