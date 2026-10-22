/// The **runtime** layer census — §13.4's blur budget, measured on the screens
/// that exist rather than on the source that builds them.
///
/// ## WHAT THIS IS, AND WHAT IT IS NOT
///
/// `test/core/design_system/widgets/glass_blur_budget_test.dart` caps blur
/// **SITES** at **two**, by scanning the source for four spellings
/// (`GlassTier.blur`, `BackdropFilter(`, `ImageFiltered(` and a bare
/// `ImageFilter.blur(`). Its own header says why it is a source scan:
///
/// > A runtime count over today's stubs is zero, and it stays zero however many
/// > `.blur` sites Phase 3 adds, because the sites are source, not state.
///
/// **That sentence was true when the screens were stubs and it is out of date
/// now.** The screens are real. And a source-level count has a blind spot no
/// scan can close: **a site that MOUNTS more than once.** One
/// `GlassTier.blur` inside a list builder is *one site* and *N mounted
/// filters*, and the scan sees only the first number.
///
/// So the invariant this file holds is the runtime half of the same rule:
///
/// > **A site may exist once; it must MOUNT once.**
///
/// The source gate bounds the first clause; this bounds the second — and the
/// second is the one that costs a `saveLayer` plus a full read-back of
/// everything behind it, **per frame**.
///
/// ## THE INSTRUMENT
///
/// `test/support/layer_census.dart` walks the **render-object layer tree** —
/// the tree the engine composites — and counts what is mounted, by layer type,
/// with the painted area of the offset layers. It is modelled on
/// `test/support/rebuild_counter.dart` and carries the same standard of
/// explanation.
///
/// ## WHY **NOT** `pumpApp` FOR THE DOCK
///
/// The real app root is the faithful mount, and it is **not** used for `/`,
/// for a reason that is not a preference: `pumpApp` configures the production
/// graph, whose `HomeBloc` is built over `DioReadingRepository`, so the home
/// tab would open a **socket** to the deployed backend. A gate that reaches
/// the network is slow, flaky, and a test that depends on a server being up
/// is a test about the server.
///
/// So `/` is mounted through `app_harness.dart`'s own **`routerHost`** — the
/// app's shell, with the same `AppRouter`, the same `EvaThemeDark` palette and
/// the same `LumenPreferencesScope` the composition root installs — over a
/// **fake** `HomeBloc` (`home_harness.dart`'s `harness()`). The dock, the
/// home tab, the aurora and the two blur sites are all the production ones.
///
/// The one thing this mount does **not** have is the app root's `SkyScope`,
/// and it changes nothing here: the witness sky draws one star per **lit**
/// star, and a reader who has just opened the app has lit none. The
/// forty-four is the **cap**, not a mounted count — and the fourth test in the
/// opacity group measures that rather than asserting it.
///
/// ## A BUDGET, NEVER A MILLISECOND
///
/// `flutter test` runs a software rasteriser on a fake clock, so a wall-clock
/// bound asserted here would be a number no device produces. Everything below
/// is a **count** or an **area in logical pixels** — quantities a device
/// agrees with. A benchmark prints a number; a number rots. A budget fails the
/// build, so it cannot.
library;

import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/sky_scope.dart';
import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';
import 'support/design_system_harness.dart';
import 'support/home_harness.dart';
import 'support/layer_census.dart';
import 'support/reading_harness.dart';
import 'support/settings_harness.dart';

/// The surface `/` is measured on.
///
/// **390×844**, the app's own ambient surface, at a device pixel ratio of
/// **1.0** so the logical pixels and the device pixels are the same number
/// and the painted area is a number a reader can check by hand.
const Size kDockSurface = Size(390, 844);

/// A [ReevaluateListenable] that never notifies.
///
/// `ReevaluateListenable` is abstract and `AppRouter` takes one positionally,
/// so a test needs a concrete instance — and this is the same private class
/// `home_navigation_test.dart` declares, for the same reason: a router suite
/// needs a router of its own, and the app's own signal is not what it is
/// testing.
final class _SilentAuthChanges extends ReevaluateListenable {}

void main() {
  // The locator is process-wide, and `configureNavigation()` rejects a
  // duplicate registration, so a graph left behind would fail an unrelated
  // test with a confusing message. `app_harness.dart` owns the reset.
  setUp(resetServiceLocator);
  tearDown(resetServiceLocator);

  group('the blur census — the runtime half of §13.4', () {
    testWidgets('`/` mounts exactly TWO backdrop filters: the dock and the '
        'verse card', (WidgetTester tester) async {
      final LayerCensus census = await _pumpDock(tester);

      // ## THE MEASUREMENT
      //
      // `BackdropFilterLayer × 2` on `/`, measured on 390×844 with
      // `flutter test test/layer_census_test.dart`.
      //
      // **Which two**, and this is the half the source scan cannot give:
      //
      // | layer | who asked for it |
      // | --- | --- |
      // | the dock's **σ22** | `lumen_dock.dart:306` — the redesign's own `backdrop-filter:blur(22px)` (`eva/redesign.html:210`), built by hand because `GlassSurface` paints a *panel* and the dock is a full-width **bar** |
      // | the verse card's **σ24** | `verse_of_the_day_card.dart:155` — `GlassTier.blur`, the design system's own spelling |
      //
      // **And what is NOT there**, which the source scan would also have
      // missed: `GlassTier.bloom` and `GlassTier.tint` build **no** filter at
      // all (`glass_surface.dart:826-830` — `GlassTier.tint => surface`,
      // `GlassTier.bloom => surface`), so every other glass surface on the
      // screen is a translucent fill with no `saveLayer` at all.
      expect(
        census.backdropFilters,
        lessThanOrEqualTo(2),
        reason:
            '§13.4 budgets ONE blur site across the screens, and the '
            "redesign's own dock is the second. The source gate "
            '(`glass_blur_budget_test.dart`) bounds the **sites**; this bounds '
            'the **mounted** filters, because a site that mounts twice is two '
            '`saveLayer`s and two read-backs per frame and the source scan '
            'cannot see it. Measured: 2, made of the dock\'s σ22 '
            '(`lumen_dock.dart:306`) and the verse-of-the-day card\'s σ24 '
            '(`verse_of_the_day_card.dart:155`). A third is red.\n'
            '${census.describeOffsetLayers()}',
      );
      expect(
        census.backdropFilters,
        2,
        reason:
            '**Exactly** two, and the count is asserted as an equality as well '
            'as a ceiling: the ceiling is the budget and the equality says '
            'what the budget is made of, so a filter that *disappears* is as '
            'visible as one that appears. The two are the dock\'s σ22 and the '
            'verse card\'s σ24.\n${census.describeOffsetLayers()}',
      );
    });

    testWidgets('`/reading` mounts NO backdrop filter at all', (
      WidgetTester tester,
    ) async {
      final LayerCensus census = await _pumpReading(tester);

      // ## THE MEASUREMENT
      //
      // `BackdropFilterLayer × 0` on `/reading`, measured on 430×932.
      //
      // The reading sanctuary is the one screen with **no glass**: its
      // chrome is text over the sky, and the prototype draws no
      // `backdrop-filter` on it. So this is an equality and not a ceiling —
      // a filter here would be a blur over a screen that has nothing behind
      // it to blur.
      expect(
        census.backdropFilters,
        0,
        reason:
            'the reading sanctuary mounts NO backdrop filter, and it is the '
            'one screen where that is free: the prototype draws no '
            '`backdrop-filter` on the reader, and there is nothing behind it '
            'but the sky. A filter here would be a per-frame `saveLayer` over '
            'a screen with no glass in it.\n${census.describe()}',
      );
    });

    testWidgets('and the census can SEE a filter it is handed — the negative '
        'control', (WidgetTester tester) async {
      // ## WHY THIS HALF EXISTS
      //
      // A census that counts nothing is a **green gate over nothing**, and
      // this repository has met that shape three times (AGENT_CONTEXT §7,
      // "a gate that cannot fail is worse than no gate"). A source scan
      // cannot rot that way, because a scan that finds nothing is asserted to
      // have found nothing — `setstate_budget_test.dart` is the model.
      //
      // A **runtime** census can: if the layer walk stopped descending, or if
      // `debugLayer` stopped answering, the count would fall to zero and
      // every budget above would pass vacuously. So the instrument is handed
      // **one filter it cannot possibly miss** and required to count it.
      await tester.pumpWidget(
        MaterialApp(
          home: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      final LayerCensus census = LayerCensus.of(
        tester.binding.renderViews.first,
      );
      expect(
        census.byType,
        isNotEmpty,
        reason:
            'a census that found NO layers at all is a census that stopped '
            'working, not a screen with nothing on it. Every budget above is '
            'vacuous over an empty census, so the empty census is the failure '
            'this assertion exists to catch.',
      );
      expect(
        census.backdropFilters,
        1,
        reason:
            'the instrument is handed exactly one `BackdropFilter` and must '
            'count exactly one mounted `BackdropFilterLayer`. If this is 0 '
            'the walk does not reach the layer tree and every ceiling in this '
            'file is passing over nothing.\n${census.describe()}',
      );
    });
  });

  group('the opacity census', () {
    testWidgets('`/reading` mounts SIX opacity layers, and this is what they '
        'are made of', (WidgetTester tester) async {
      final LayerCensus census = await _pumpReading(tester);

      // ## THE MEASUREMENT
      //
      // `OpacityLayer × 6` on `/reading`, measured on 430×932. **Not 44** —
      // and the difference is the finding, so it is spelled out here rather
      // than left for the next reader to discover.
      //
      // | the layer | who asked for it |
      // | --- | --- |
      // | 4 × full screen (430×932) | the **Material page route's** own transition — a `FadeTransition` per nested route, all four of them the framework's and not this app's |
      // | 1 × 430×101 | the reading page's **chrome dim** — the `AnimatedOpacity` at `reading_page.dart:844` that dims the app bar in focus mode (`eva/redesign.html:176`) |
      // | 1 × 378×106 | the **revealed verse** — the `Opacity` at `verse_line.dart:489` that fades a verse in |
      //
      // **The other four verses' `Opacity` widgets mount NO layer**, because
      // their alpha is 0 and the framework does not composite a fully
      // transparent subtree. A widget count and a layer count are different
      // questions.
      //
      // **And there is a FIFTH `FadeTransition` at 430×101 that mounts no
      // layer either** — the app bar's own `AnimatedSwitcher` fade, which
      // sits at alpha 0 in the state the harness parks the page in. So
      // `/reading` mounts six `FadeTransition`s and five `OpacityLayer`s
      // from them. A reader counting the widgets will get a different
      // number, and the reason is in the sentence above.
      //
      // **The headroom is two**, and the reason is the four framework layers:
      // a Flutter release that nests the page transition one level deeper
      // must not make this gate red, because nothing in this app changed.
      // The app-controlled part of the six is **two** — the chrome dim and
      // the revealed verse — and the fourth test in this group measures that
      // part exactly, without the framework's contribution in it.
      expect(
        census.opacityLayers,
        lessThanOrEqualTo(8),
        reason:
            '`/reading` mounts 6 `OpacityLayer`s, and the composition is: '
            '**4** from the Material page route\'s own `FadeTransition`s (the '
            'framework\'s, full screen, 430×932 each), **1** from the '
            'reading page\'s chrome dim (`reading_page.dart:844`, the '
            '`AnimatedOpacity` that dims the app bar in focus mode) and **1** '
            'from the revealed verse (`verse_line.dart:489`, the `Opacity` '
            'that fades a verse in). The other four verses\' `Opacity` '
            'widgets mount no layer at all — their alpha is 0 — and a sixth '
            '`FadeTransition` (the app bar\'s `AnimatedSwitcher`) is at alpha '
            '0 too, so **six fades, five layers**. The ceiling is 8 because '
            'four of the six are the framework\'s and a transition that nests '
            'one level deeper must not make this gate red.\n'
            '${census.describeOffsetLayers()}',
      );
    });

    testWidgets('and the witness sky mounts ONE layer per LIT star — the '
        'forty-four is a CAP', (WidgetTester tester) async {
      // ## THE FORTY-FOUR IS A **CAP**, NOT A MOUNTED COUNT
      //
      // `docs/PERFORMANCE.md` §2.2 and `rebuild_isolation_budget_test.dart`'s
      // own reason both say the sky is "44 stars × 5 widgets plus 44
      // composited `Opacity` layers". **Measured today, that is not what the
      // tree mounts.**
      //
      // `WitnessSky` draws one star per **lit** entry
      // (`witness_sky.dart:994` — `for (final SkyEntry entry in entries)
      // _star(entry)`), and the entries are the verses the reader has crossed
      // the threshold on. A reader who has just opened the app has lit
      // **none**. The **44** is `UserSettings.starCount` — the **cap** on how
      // many stars the sky may hold (`sky_cubit.dart`'s cap seam), not a
      // number of stars on screen.
      //
      // So this test mounts the sky at its cap and measures what that costs.
      // **The delta is the app-controlled number**: the framework's four
      // route-transition layers are in both measurements and cancel.
      final LayerCensus withoutStars = await _pumpReading(tester);
      final LayerCensus withStars = await _pumpReading(
        tester,
        stars: _litStars(44),
      );

      expect(
        withStars.opacityLayers - withoutStars.opacityLayers,
        44,
        reason:
            'the witness sky mints one `Opacity` per **lit** star '
            '(`witness_sky.dart:1052`), and every one of them that is not '
            'fully transparent is composited as its own `OpacityLayer` — one '
            'layer per star, at 3–5 px each. Forty-four lit stars add exactly '
            '**44** mounted opacity layers, and this delta is the '
            'app-controlled measurement: the four route-transition layers are '
            'in both halves and cancel, so a Flutter change to the page '
            'transition cannot move it.\n'
            'without stars: ${withoutStars.describe()}\n'
            'with 44 stars: ${withStars.describe()}',
      );
    });
  });

  group('the repaint-boundary census', () {
    testWidgets('`/reading` mounts FIFTEEN repaint boundaries and `/` mounts '
        'ELEVEN', (WidgetTester tester) async {
      final LayerCensus reading = await _pumpReading(tester);
      final LayerCensus dock = await _pumpDock(tester);

      // ## THE MEASUREMENTS
      //
      // | screen | mounted repaint boundaries | by owner |
      // | --- | --- | --- |
      // | `/reading` | **15** | 8 `RenderRepaintBoundary`, 5 `RenderAnimatedOpacity`, 1 `RenderOpacity`, 1 `RenderViewport` |
      // | `/` | **11** | 7 `RenderRepaintBoundary`, 2 `RenderOpacity`, 1 `RenderViewport`, 1 `_RenderSingleChildViewport` |
      //
      // **`/` is ELEVEN, and it was TEN** — the dock orb's ripple gained a
      // `RepaintBoundary` of its own (`lumen_dock.dart:900`), which is the
      // seventh `RenderRepaintBoundary` and the 30×30 one in the table below.
      //
      // **What each boundary is**, and this is the half that makes the number
      // actionable. The provenance was read off the **element** tree, so each
      // entry names the widget that owns the layer:
      //
      // | the layer | who owns it |
      // | --- | --- |
      // | `RenderRepaintBoundary` 390×844 (×3 on `/`), 430×932 (×3 on `/reading`) | one of the three is **the app's** — `LumenBackground`'s `RepaintBoundary`, `lumen_background.dart:219` — and the other two are the framework's own route boundaries (`routes.dart:1203` and `routes.dart:1228`). `Overlay`, `Scaffold` and `Material` add **none** |
      // | `RenderRepaintBoundary` 378×N (×5 on `/reading`) | the framework's `RepaintBoundary` around each **verse row** |
      // | `RenderRepaintBoundary` 168×132 (×2 on `/`) | the library carousel's **book cards** (`library_carousel.dart`, 132 px tall — `eva/redesign.html:275`), each wrapped in one by the framework's `SliverChildBuilderDelegate` (`scroll_delegate.dart:561`) |
      // | `RenderRepaintBoundary` 12×132 (on `/`) | the carousel's **card gap** — the `SizedBox(width: cardGap)` separator (`library_carousel.dart:292`, `cardGap` = 12), wrapped by the same delegate |
      // | `RenderRepaintBoundary` 30×30 (on `/`) | **the app's** — the dock orb's ripple's own `RepaintBoundary` (`lumen_dock.dart:900`), the app's **second** `RepaintBoundary` widget |
      // | `RenderAnimatedOpacity` 430×932 (×4 on `/reading`) | the **Material page route's** `FadeTransition`s — the framework's own route transition |
      // | `RenderAnimatedOpacity` 430×101 | the reading page's **chrome dim** — the `AnimatedOpacity` at `reading_page.dart:844` |
      // | `RenderOpacity` 378×106 | the **revealed verse** — the `Opacity` at `verse_line.dart:489` |
      // | `RenderOpacity` 390×844 (×2 on `/`) | the app's own two: the route transition's `Opacity` (`eva_motion.dart:849`) and the tab transition's (`eva_motion.dart:988`) |
      // | `RenderViewport` 430×699 | `/reading`'s `ListView.builder` (`reading_page.dart:971`) |
      // | `RenderViewport` 362×132 | the library carousel's `ListView.separated` (`library_carousel.dart:282`) |
      // | `_RenderSingleChildViewport` 390×844 | `/`'s own `SingleChildScrollView` (`home_page.dart:226`) |
      //
      // **The `RenderOpacity` / `RenderAnimatedOpacity` ones are repaint
      // boundaries nobody chose**: the framework makes one whenever an alpha
      // is neither 0 nor 1. A screen full of fading stars has one per star —
      // which is why the count on `/reading` is 15 and not 8.
      //
      // **And this app has exactly TWO `RepaintBoundary` widgets in all of
      // `lib/`** — the aurora's, at
      // `lib/core/design_system/effects/lumen_background.dart:219`, which
      // exists so "the page above never rebuilds" is a property of the tree
      // rather than an intention, and the dock orb's ripple's, at
      // `lib/features/dock/presentation/widgets/lumen_dock.dart:900`, which
      // exists so the ring's repaint does not re-record the layer that owns
      // the dock's σ22 blur. Every other `RepaintBoundary` on these two
      // screens is the framework's.
      //
      // **Mounted**, not "in the render tree": a route the `Overlay` has
      // covered is `Offstage`, and an offstage subtree owns no layer, so it
      // is not composited and it is not counted.
      expect(
        reading.repaintBoundaries,
        lessThanOrEqualTo(18),
        reason:
            '`/reading` mounts 15 repaint boundaries: 8 owned by a '
            '`RenderRepaintBoundary` (one is the aurora\'s, at '
            '`lumen_background.dart:219` — one of only TWO `RepaintBoundary` '
            'widgets in all of `lib/`, the other being the dock orb\'s '
            'ripple\'s at `lumen_dock.dart:900`, which is on `/` and not on '
            'this screen; two are the framework\'s full-screen ones and '
            'five are the framework\'s around the verse rows), 5 owned by a '
            '`RenderAnimatedOpacity` (the Material page route\'s four '
            '`FadeTransition`s at 430×932 and the reading page\'s chrome dim '
            'at `reading_page.dart:844`), 1 owned by a `RenderOpacity` (the '
            'revealed verse, `verse_line.dart:489`) and 1 by the '
            '`ListView.builder`\'s `RenderViewport` '
            '(`reading_page.dart:971`). The ceiling is 18 so a framework '
            'layer does not make this gate red.\n'
            '${reading.describeRepaintBoundaries()}',
      );
      expect(
        dock.repaintBoundaries,
        lessThanOrEqualTo(14),
        reason:
            '`/` mounts 11 repaint boundaries: 7 owned by a '
            '`RenderRepaintBoundary` (one is the app\'s aurora at '
            '`lumen_background.dart:219`, one is the dock orb\'s ripple at '
            '`lumen_dock.dart:900` — 30×30, the app\'s second `RepaintBoundary` '
            'widget — two are the framework\'s own full-screen route '
            'boundaries, two are the library carousel\'s book cards at 168×132 '
            'and one is the carousel\'s 12×132 card gap, each of those three '
            'wrapped by the framework\'s `SliverChildBuilderDelegate`), 2 by a '
            '`RenderOpacity` (the route transition\'s `Opacity` at '
            '`eva_motion.dart:849` and the tab transition\'s at '
            '`eva_motion.dart:988` — the app\'s own two, and the only two '
            'full-screen opacities on the screen), 1 by the carousel\'s '
            '`RenderViewport` (362×132, `library_carousel.dart:282`) and 1 by '
            'the home page\'s own `SingleChildScrollView` '
            '(`_RenderSingleChildViewport`). The ceiling is 14 — three above '
            'the measured 11 — so a framework layer or two does not make this '
            'gate red.\n'
            '${dock.describeRepaintBoundaries()}',
      );
    });
  });

  group('the painted-area census', () {
    testWidgets('`/reading` paints 3,456,256 logical px² and EIGHTY-ONE per '
        'cent of it is full-screen layers', (WidgetTester tester) async {
      final LayerCensus census = await _pumpReading(tester);

      // ## THE MEASUREMENT
      //
      // **3,456,256 logical px²** on 430×932 — which is **8.6 screens**'
      // worth of composited area, and the reason the number is worth
      // recording is that it is **not** the content.
      //
      // | the layer | area | share |
      // | --- | --- | --- |
      // | 3 × full-screen `RenderRepaintBoundary` (430×932) | 1,202,280 | 35 % |
      // | 4 × full-screen `RenderAnimatedOpacity` (430×932) | 1,603,040 | 46 % |
      // | the chrome dim (430×101) | 43,430 | 1 % |
      // | the scroll view (430×699) | 300,570 | 9 % |
      // | the verse rows and the app bar (five layers, 378×106…184) | 306,936 | 9 % |
      //
      // **So the finding is: eighty-one per cent of the composited area on
      // this screen is full-screen layers, and the content is under a tenth.**
      // That is the aurora's cost and the route transition's, and it is the
      // number `docs/PERFORMANCE.md` §3's aurora budget is arguing about —
      // in logical pixels, which is the unit §3.1 says that budget gets
      // wrong.
      //
      // **And the ceiling has headroom**, because four of the six full-screen
      // layers are the framework's route transition. The app's own share —
      // the aurora's boundary and the chrome dim — is 1,245,710.
      expect(
        census.paintedArea,
        lessThanOrEqualTo(3600000),
        reason:
            '`/reading` paints 3,456,256 logical px², which is 8.6 screens of '
            '430×932 — and 81 % of it is full-screen layers: the aurora\'s '
            '`RepaintBoundary` (430×932, 35 %) and the Material page route\'s '
            'four `FadeTransition` opacities (4 × 430×932, 46 %). The verse '
            'rows and the app bar are under a tenth of it. The ceiling is '
            '3,600,000 (about 4 % of headroom) because four of the six '
            'full-screen layers are the framework\'s.\n'
            '${census.describeOffsetLayers()}',
      );
    });

    testWidgets('and FORTY-FOUR STARS cost forty-four layers and 739 px²', (
      WidgetTester tester,
    ) async {
      // ## THE TWO QUESTIONS ARE DIFFERENT QUESTIONS
      //
      // "How many layers" and "how many pixels are being re-recorded" are
      // not the same question, and the witness sky is the cleanest proof in
      // the tree: forty-four stars are **forty-four composited layers** and
      // **738.77 logical px²** between them, and 44 extra `saveLayer`s per
      // frame.
      //
      // ## AND THE PERCENTAGE, WITH ITS DENOMINATOR
      //
      // **0.18 % of the screen, or 0.021 % of the composited area — and the
      // two are different questions**, so both are written here with the
      // area they were measured against:
      //
      // | against | the area | the share |
      // | --- | --- | --- |
      // | the screen's **logical** area | 430 × 932 = 400,760 px² | 738.77 ÷ 400,760 = **0.184 %** |
      // | the **composited** area the census measures | 3,456,256 px² | 738.77 ÷ 3,456,256 = **0.021 %** |
      //
      // **The figure this file printed before was the second one, and it was
      // printed as if it were the first.** "0.02 % of the screen's area" is
      // the composited-area share, and the composited total is 8.6 screens'
      // worth of area — so the same 738.77 px² is **0.18 %** of the screen a
      // reader is looking at. Both are printed now, with their
      // denominators, because a percentage without its denominator is the
      // number that rots.
      //
      // **The layer count is the budget that matters here.** A composited
      // layer is a texture the rasteriser has to allocate and the compositor
      // has to hand around, and its cost does not shrink with its size. The
      // pixels are what the aurora's budget in `docs/PERFORMANCE.md` §3.1 is
      // about, and the stars are not what that budget is protecting.
      final LayerCensus withoutStars = await _pumpReading(tester);
      final LayerCensus withStars = await _pumpReading(
        tester,
        stars: _litStars(44),
      );

      expect(
        withStars.paintedArea - withoutStars.paintedArea,
        lessThan(1000),
        reason:
            'forty-four lit stars add forty-four composited `OpacityLayer`s '
            'and under 1,000 logical px² between them — 738.77 px², which is '
            '0.18 % of the screen\'s own logical area (430 × 932 = 400,760 '
            'px²) and 0.021 % of the composited area the census measures '
            '(3,456,256 px²) — and forty-four extra `saveLayer`s per frame. '
            'That is the whole argument for keeping the two questions apart: '
            'the layer count is a per-frame cost that does not shrink with '
            'the size, and the area is not.\n'
            'without stars: ${withoutStars.paintedArea} px²\n'
            'with 44 stars: ${withStars.paintedArea} px²',
      );
    });
  });
}

/// The layers mounted on `/` — the dock shell, the home tab and the aurora.
///
/// **The real router, a fake `HomeBloc`, and the app's own
/// `LumenPreferencesScope`.** See the file header for why the app *root* is
/// not used: it would open a socket.
Future<LayerCensus> _pumpDock(WidgetTester tester) async {
  final HomeHarness home = harness();
  getIt.registerSingleton<HomeBloc>(home.bloc);
  addTearDown(() => getIt.unregister<HomeBloc>());

  final AppRouter router = AppRouter(
    FakeAuthStatus(),
    _SilentAuthChanges(),
    testRoleAccess(),
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = kDockSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    LumenPreferencesScope(
      preferences: const LumenPreferences(),
      child: routerHost(router),
    ),
  );
  // The home tab's reading, so the verse card renders its **blur** and not
  // its loading arm. The same wait `home_navigation_test.dart` uses, and for
  // the same reason: a wait that resolves before its subject is ready makes
  // every assertion after it pass about the previous frame.
  await pumpUntilFound(tester, find.textContaining('3:1-5'), limit: 24);

  return _census(tester, '/');
}

/// The layers mounted on `/reading` — the sanctuary, the sky and the aurora.
///
/// **A local pump rather than `reading_harness.dart`'s `pumpReading`**, and
/// the difference is one wrapper: the aurora's `LumenPreferencesScope`. The
/// composition root installs it above every route, and without it
/// `LumenBackground` paints the flat canvas instead of the aurora — so
/// without the wrapper this census would not see the one `RepaintBoundary`
/// this app has, and the screen it measured would not be the screen a reader
/// sees.
///
/// [stars] is the sky's **lit** entries, and the default is none: a reader
/// who has just opened the app has lit none.
Future<LayerCensus> _pumpReading(
  WidgetTester tester, {
  List<SkyEntry> stars = const <SkyEntry>[],
}) async {
  final ReadingHarness harness = readingHarness();
  tester.view.physicalSize = kGeometrySurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Widget page = settingsScope(tester, ReadingPage(cubit: harness.cubit));
  if (stars.isNotEmpty) {
    page = SkyScope(
      handle: SkyHandle(
        entriesReader: () => stars,
        recordEntry: (SkyEntry entry) async {},
      ),
      child: page,
    );
  }

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: LumenPreferencesScope(
        preferences: const LumenPreferences(),
        child: page,
      ),
    ),
  );
  await pumpReadingFrames(tester, 6);
  // **Past the focus mode's idle timer**, because `flutter_test` fails a test
  // with a pending timer and the reading page arms a four-second one on
  // entry. `reading_harness.dart`'s own paragraph gives the whole argument.
  await tester.pump(focusIdleDelay + const Duration(milliseconds: 100));

  return _census(tester, '/reading');
}

/// The census of the tree the test is looking at — **printed and returned**.
///
/// **The printing is not decoration.** `rebuild_isolation_budget_test.dart`
/// prints its numbers and asserts them, and the reason it prints is that an
/// assertion proves a number but does not *show* it: a reader who wants the
/// measurement without making the gate fail has to be able to run one
/// command and read it. So:
///
/// ```bash
/// flutter test test/layer_census_test.dart
/// ```
///
/// and the numbers are in the output.
LayerCensus _census(WidgetTester tester, String label) {
  final LayerCensus census = LayerCensus.of(tester.binding.renderViews.first);
  debugPrint('── the layer census · $label ──');
  debugPrint(census.describe());
  debugPrint('repaint boundaries: ${census.describeRepaintBoundaries()}');
  debugPrint(census.describeOffsetLayers());
  debugPrint('painted area: ${census.paintedArea} px²');
  return census;
}

/// [count] lit stars, for the sky.
///
/// The verses are numbered from 1 so the keys are distinct — the sky's own
/// `SkyEntry.key` is `book:chapter:verse`, and two entries with the same key
/// would be the same star.
List<SkyEntry> _litStars(int count) => <SkyEntry>[
  for (int verse = 1; verse <= count; verse++)
    SkyEntry(
      book: 'John',
      chapter: 3,
      verse: verse,
      litAt: DateTime.utc(2026, 10, 3, 9, 30, verse),
    ),
];
