import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// How long one column's bar takes to grow — `eva/redesign.html:297`'s
/// `transition:transform .6s`.
///
/// **The prototype grows each bar for this long, and each bar starts at its
/// own delay** (`:1097`'s `120 + k*80`), so the three bars are still at
/// different heights at 600 ms — the third one finishes at 880 ms. A single
/// 600 ms controller with the delay folded into the interval would instead
/// make the third bar grow for 320 ms and finish with the others, which is
/// not what `:1097` says.
const int _kPodiumGrowthMs = 600;

/// `eva/redesign.html:1097`'s `120 + k*80` — the delay of the `k`-th column in
/// the prototype's 2nd/1st/3rd order.
const int _kPodiumFirstDelayMs = 120;

/// `eva/redesign.html:1097`'s `*80` — the step between the columns' delays.
const int _kPodiumDelayStepMs = 80;

/// The last column's delay: `120 + 2*80` = 280 ms.
const int _kPodiumLastDelayMs = _kPodiumFirstDelayMs + 2 * _kPodiumDelayStepMs;

/// The whole entrance, in one controller: the last delay plus the growth —
/// **880 ms**.
///
/// One controller drives all three columns, so it has to outlast the last
/// one; each column then takes its own slice of it, and the slice is the
/// prototype's: it starts at the column's delay and runs for
/// [_kPodiumGrowthMs].
const int _kPodiumEntranceMs = _kPodiumLastDelayMs + _kPodiumGrowthMs;

/// The top-3 podium in `/communion` (`eva/redesign.html:627`, `:1084-1098`, D8).
///
/// Order: **2nd, 1st, 3rd** with heights 84 / 112 / 64 px.
///
/// ## A MISSING POSITION IS SKIPPED, NOT A REASON TO HIDE THE PODIUM
///
/// The prototype's `order.forEach` returns early on a position it has no row for
/// (`eva/redesign.html:1087`'s `if(!p) return;`), so a cohort of two gets a 1st
/// and a 2nd column and no 3rd. This does the same: the column is a `SizedBox`
/// of the right height and the other two are drawn. A cohort of one still gets its
/// 1st.
///
/// ## AND THE MONOGRAM IS THE MAPPER'S, NOT THE PROTOTYPE'S FIRST CHARACTER
///
/// See `LeaderboardRow.initials`'s own doc for the measurement and the reason:
/// the prototype's monogram is `dispName(p,idx).trim()[0]` (`:1072`), a single
/// character, and this repository's mapper produces two letters from the first
/// and last token. The divergence is recorded there, once, for both orbs.
///
/// ## THE BLOOM IS IN EACH BAR, AND IT IS THE HOUSE'S OWN
///
/// `eva/redesign.html:299` puts the wash **inside** the bar:
/// `.podbar .bloom{position:absolute;left:10%;right:10%;bottom:-55%;height:90%;
/// background:radial-gradient(ellipse at 50% 100%,var(--bh),transparent 70%);
/// filter:blur(14px);pointer-events:none}`, and `:1094` writes the per-reader
/// colour onto that one element (`style="--bh:${p.gl}"`).
///
/// So the wash is drawn **once per bar**, not once behind the podium, and it
/// is the design system's own: a `GlassSurface` with `tier: GlassTier.bloom`
/// and a `bloomColor` — the tier that paints a radial wash **without** a
/// `saveLayer`, and the parameter the prototype's `--bh` is read through
/// (`glass_surface.dart:602-654` records that `--bh` has no global definition
/// and is therefore a per-host colour).
///
/// The wash's **host** is a `GlassSurface` here, and the tier's own doc argues
/// against that (`glass_surface.dart:154-165`: the `.podbar` is "a composite
/// rather than a `GlassSurface`"). The doc is right about the *surface*, and
/// the decision here is about the *wash*: the tier is the one mechanism this
/// repository has for the `.bloom` gradient, and a hand-rolled
/// `RadialGradient` in a feature would be the second spelling of a paint the
/// design system already owns — which is what the shipped version did, and
/// what this file's own comment used to claim while no `GlassTier` was used
/// anywhere in it. What the tier cannot switch off is its own fill, rim and
/// ambient shadow, and those are recorded below.
///
/// The `pointer-events:none` of `:299` is the design system's own: the tier
/// paints its wash inside an `IgnorePointer`
/// (`glass_surface.dart:879-884`), so the wash takes no taps.
///
/// ## EACH COLUMN GROWS FOR ITS OWN 600 MS
///
/// `:297` transitions `transform` over `.6s` and `:1097` adds the class that
/// starts it, `setTimeout(()=>bar.classList.add('in'), 120+k*80)` — so the
/// 2nd column grows from 120 ms to 720 ms, the 1st from 200 ms to 800 ms and
/// the 3rd from 280 ms to 880 ms, and the three bars are at three different
/// heights for most of the entrance.
///
/// One controller runs the whole entrance ([_kPodiumEntranceMs] = 880 ms) and
/// each column takes the slice `Interval(delay / 880, (delay + 600) / 880)`
/// of it. Folding the delay into a 600 ms controller instead — one interval
/// per column over the same 600 ms — makes the third bar grow for 320 ms and
/// finish with the first, which is a different animation.
///
/// `MediaQuery.disableAnimationsOf(context)` still switches the whole thing
/// off: the delays collapse to zero and the bars are drawn at rest.
///
/// ## EVERY DIVERGENCE FROM THE PROTOTYPE, RECORDED WHERE IT HAPPENS
///
/// The repository's rule is that a divergence is recorded **at the site**, with
/// the prototype's line it diverges from, so this list is the whole of it:
///
/// 1. **The per-reader hue is gone** (`:1055-1064`, `:1091`, `:1115`). The
///    prototype gives every reader an `hx`/`gl` pair and tints the orb's
///    gradient and the bar's bloom with it; the client has no per-reader
///    colour, so **a token stands in** — the bar's wash takes the `--bh`
///    default ([EvaColors.bloom], the fallback `redesign.html:254` reads) and
///    the orb takes a flat fill. What the client *can* mark is the **place**,
///    and it does: the first place's orb, name, rim and hairline are gold.
///    Recorded here rather than in `GlassSurface`, because the substitution is
///    this widget's and not the tier's.
/// 2. **The wash's insets and fade stop** (`:299`). The prototype's `.bloom` is
///    inset `left:10% right:10%`, hangs `bottom:-55%` below the bar and fades
///    at `70%`; the tier paints one full-bleed wash at `68%`. That is the
///    tier's own recorded substitution for the three hosts that are not
///    `.hcard` (`glass_surface.dart:154-171`) and it is not restated here.
/// 3. **The bar's fill and rim are the house's glass tokens** (`:296`).
///    `.podbar` is `background:var(--glass-fill)` and
///    `border:1px solid var(--glass-line)`, and the house's [EvaColors.glassFill]
///    / [EvaColors.glassBorder] are those two: 5% white over 4% black, and a
///    rim at 8% white. The prototype's **light** `--glass-fill` is
///    `rgba(255,255,255,.55)` (`:57`) and the house's light fill is 4% black,
///    so the light bar is the house's dimmer panel and not the prototype's
///    bright one. The token is the design system's and this is where the
///    substitution becomes visible.
/// 4. **The bar carries the glass ambient** (`:296`). `.podbar` declares no
///    `box-shadow`; the tier's surface brings the `.hcard`'s
///    `0 4px 24px rgba(0,0,0,.35)` with it, and the tier has no switch for
///    it. The bar is therefore darker than the prototype's.
/// 5. **The hairline is not clipped** (`:296`, `:302-303`). The prototype's
///    `.podbar` has `overflow:hidden`, which cuts the `::before` to the 0.5px
///    that falls inside the padding box and cuts its glow with it; this draws
///    the declared 1.5px and lets the glow spill.
/// 6. **The `.pod` gap is 6px, not 8px** (`:292`). The column's two internal
///    gaps (orb→name, rank→bar) are 6px.
/// 7. **The sizes** (`:294`, `:295`, `:300`). `.pname` is 12px and this is
///    11px; `.pv` is 11px and this is 13px at `w700`; `.prk` is 9px here too,
///    with 1.4px of tracking against the prototype's `.14em`. The
///    `padding-top:10` of `:297` is matched.
/// 8. **The first place's name is gold** (`:294`). `.pname` is `--ink-0` in
///    every column; the client marks the place (see 1).
/// 9. **The " · you" suffix on the reader's column** (`:1092`, `:1116`). The
///    prototype's podium name is `dispName(p,idx)`, and `dispName` returns the
///    reader's **bare** name (`:1069-1070`); the " · you" suffix exists only in
///    the **list** row (`:1116`). It is kept here because the prototype marks
///    the reader on the podium with a **colour** — `hx:'#E8B04B'` on `:1059` —
///    and this client has no per-reader colour to mark them with (1), so the
///    suffix is the only thing on the podium that says which column is the
///    reader's. A reader who is in the top three sees their own name followed
///    by " · you" on their column, and nowhere else on the podium.
/// 10. **The podium's padding** (`:291`). The prototype's `.podium` is
///     `14px 18px 0`; this is `16px` on top and `8px` under, and the page's own
///     gutter provides the horizontal inset.
class CommunionPodium extends StatefulWidget {
  /// Creates the podium for [topRows].
  const CommunionPodium({
    required this.topRows,
    required this.metric,
    required this.isVeiled,
    this.readerStandingRank,
    super.key,
  });

  /// The top ranked rows (up to 3).
  final List<LeaderboardRow> topRows;

  /// Active metric.
  final LeaderboardMetric metric;

  /// Whether the communal veil is on.
  final bool isVeiled;

  /// Reader's rank from standing, if available.
  final int? readerStandingRank;

  @override
  State<CommunionPodium> createState() => _CommunionPodiumState();
}

class _CommunionPodiumState extends State<CommunionPodium>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The three columns' growth, in the prototype's 2nd/1st/3rd order.
  ///
  /// Each is the controller driven through the column's own slice of the
  /// entrance — the delay, then 600 ms of growth — and each is built **once**
  /// rather than per frame: `CurvedAnimation` adds a status listener to its
  /// parent on every construction and the SDK's own doc says to create it
  /// once and dispose it (`animations.dart:410-414`), so the driven
  /// `CurveTween` is the spelling that needs no disposal.
  late final List<Animation<double>> _growths;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kPodiumEntranceMs),
    );
    _growths = <Animation<double>>[
      for (int column = 0; column < 3; column++) _growthFor(column),
    ];
    _controller.forward();
  }

  /// The `column`-th column's slice of the entrance: its own delay, and then
  /// [_kPodiumGrowthMs] of growth.
  ///
  /// `eva/redesign.html:1097` starts the `k`-th column at `120 + k*80` and
  /// `:297` transitions it over `.6s`, so the slice is
  /// `Interval(delay / 880, (delay + 600) / 880)` of the one controller.
  Animation<double> _growthFor(int column) {
    final int delayMs = _kPodiumFirstDelayMs + column * _kPodiumDelayStepMs;
    return _controller.drive(
      CurveTween(
        curve: Interval(
          delayMs / _kPodiumEntranceMs,
          (delayMs + _kPodiumGrowthMs) / _kPodiumEntranceMs,
          // `--e-spring` — `:18`'s `cubic-bezier(.34,1.56,.64,1)`, which
          // overshoots, as the design system's achievement curve does.
          curve: EvaMotion.achievementCurve,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Podium positions order: 2nd (index 1), 1st (index 0), 3rd (index 2)
    final LeaderboardRow? p2 = widget.topRows.length > 1
        ? widget.topRows[1]
        : null;
    final LeaderboardRow? p1 = widget.topRows.isNotEmpty
        ? widget.topRows[0]
        : null;
    final LeaderboardRow? p3 = widget.topRows.length > 2
        ? widget.topRows[2]
        : null;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // 2nd place
          Expanded(
            child: p2 != null
                ? _PodiumColumn(
                    row: p2,
                    place: 2,
                    barHeight: 84,
                    orbSize: 40,
                    growth: _growths[0],
                    isFirst: false,
                    metric: widget.metric,
                    isVeiled: widget.isVeiled,
                    isReader: widget.readerStandingRank == p2.rank,
                    controller: _controller,
                    reduceMotion: reduceMotion,
                  )
                : const SizedBox(height: 84),
          ),
          const SizedBox(width: 8),
          // 1st place
          Expanded(
            child: p1 != null
                ? _PodiumColumn(
                    row: p1,
                    place: 1,
                    barHeight: 112,
                    orbSize: 46,
                    growth: _growths[1],
                    isFirst: true,
                    metric: widget.metric,
                    isVeiled: widget.isVeiled,
                    isReader: widget.readerStandingRank == p1.rank,
                    controller: _controller,
                    reduceMotion: reduceMotion,
                  )
                : const SizedBox(height: 112),
          ),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(
            child: p3 != null
                ? _PodiumColumn(
                    row: p3,
                    place: 3,
                    barHeight: 64,
                    orbSize: 36,
                    growth: _growths[2],
                    isFirst: false,
                    metric: widget.metric,
                    isVeiled: widget.isVeiled,
                    isReader: widget.readerStandingRank == p3.rank,
                    controller: _controller,
                    reduceMotion: reduceMotion,
                  )
                : const SizedBox(height: 64),
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.row,
    required this.place,
    required this.barHeight,
    required this.orbSize,
    required this.growth,
    required this.isFirst,
    required this.metric,
    required this.isVeiled,
    required this.isReader,
    required this.controller,
    required this.reduceMotion,
  });

  final LeaderboardRow row;
  final int place;
  final double barHeight;
  final double orbSize;

  /// This column's growth — the entrance's slice for this column.
  final Animation<double> growth;

  final bool isFirst;
  final LeaderboardMetric metric;
  final bool isVeiled;
  final bool isReader;
  final AnimationController controller;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    final String displayName = isVeiled && !isReader
        ? strings.leaderboardWitness(strings.digits(place))
        : (isReader
              ? '${row.fullName} · ${strings.leaderboardYou}'
              : row.fullName);

    final String valueText = switch (metric) {
      LeaderboardMetric.light => strings.digits(row.score),
      LeaderboardMetric.streaks => strings.digits(row.currentStreak),
    };

    final double monogramSize = 0.42 * orbSize;

    final Widget bar = _buildBar(colors, direction, valueText);

    final Widget animatedBar = reduceMotion
        ? bar
        : AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(
                // `transform:scaleY(0) → 1` with `transform-origin:bottom`
                // (`:296-297`).
                scaleY: growth.value,
                alignment: Alignment.bottomCenter,
                child: child,
              );
            },
            child: bar,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Orb
        Container(
          width: orbSize,
          height: orbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst
                ? colors.ember.withValues(alpha: 0.25)
                : colors.surface,
            border: Border.all(
              color: isFirst ? colors.emberInk : colors.glassBorder,
              width: isFirst ? 1.5 : 1.0,
            ),
            boxShadow: isFirst
                ? <BoxShadow>[
                    BoxShadow(
                      // `.pod.p1 .porb{box-shadow:0 0 22px
                      // rgba(232,176,75,.55)}` — `:304`.
                      color: colors.ember.withValues(alpha: 0.55),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isVeiled && !isReader
              ? FourPointedStar(
                  size: monogramSize,
                  color: colors.ink2,
                  outline: true,
                )
              : Text(
                  row.initials,
                  style: TextStyle(
                    fontSize: monogramSize,
                    fontWeight: FontWeight.w700,
                    color: isFirst ? colors.emberInk : colors.ink,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: arabicAware(
            Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFirst ? colors.emberInk : colors.ink,
            ),
            direction,
          ),
        ),
        // Rank mono — `eva/redesign.html:1093` prints `N(o.i+1)`, which is the bare
        // digit through the locale's numeral system, with no `#` in front of it.
        Text(
          strings.digits(place),
          style: arabicAware(
            EvaTypography.monoCaps(colors)
                .copyWith(fontSize: 9, color: colors.ink2, letterSpacing: 1.4),
            direction,
          ),
        ),
        const SizedBox(height: 6),
        // Bar
        animatedBar,
      ],
    );
  }

  /// The `.podbar` — `eva/redesign.html:296-304`.
  ///
  /// ## THE BOX, THE WASH, THE RIM AND THE HAIRLINE, IN THAT ORDER
  ///
  /// * **The box** is the `GlassSurface` (the fill *and* the wash), cut to the
  ///   prototype's `16px 16px 6px 6px` radius by a `ClipRRect`. The tier's own
  ///   `radius` is uniform, so the shape is the clip's, not the parameter's.
  /// * **The wash** is the tier's — `GlassTier.bloom` — and it is inside the
  ///   bar, as `:299` puts it.
  /// * **The rim** is painted over the surface, not under it: the surface's
  ///   fill is translucent, and a rim under it reads as a half-veiled line.
  /// * **The hairline** is the first place's only (`:302-303`).
  Widget _buildBar(
    EvaColors colors,
    TextDirection direction,
    String valueText,
  ) {
    // `.podbar{border-radius:16px 16px 6px 6px}` — `:296`.
    const BorderRadius barRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(6),
    );

    // `.podbar{border:1px solid var(--glass-line)}` — `:296` — and
    // `.pod.p1 .podbar{border-color:rgba(232,176,75,.5)}` — `:301`.
    final Color rim = isFirst
        ? colors.emberInk.withValues(alpha: 0.5)
        : colors.glassBorder;

    return Container(
      height: barHeight,
      width: double.infinity,
      // The bar's **shape**, and nothing else: the fill and the rim are the
      // layers below, and the shape is what the wash is cut to.
      decoration: const BoxDecoration(borderRadius: barRadius),
      child: Stack(
        children: <Widget>[
          // The bar's own surface — the fill (`:296`'s `var(--glass-fill)`) and
          // the `.bloom` wash inside it (`:299`).
          Positioned.fill(
            child: ClipRRect(
              borderRadius: barRadius,
              child: GlassSurface(
                tier: GlassTier.bloom,
                // The tier's radius is uniform; the clip above carries the
                // prototype's `16 16 6 6`.
                radius: 16,
                // The rim is painted below, in the prototype's two colours.
                border: false,
                // `.podbar` has no `.hor` — `:299`, and the tier's own doc
                // (`glass_surface.dart:546-548`).
                seam: false,
                // `.podbar{padding-top:10px}` — `:297`.
                padding: const EdgeInsets.only(top: 10),
                // The wash's colour. The prototype writes the **reader's** own
                // hue here (`:1094`'s `--bh:${p.gl}`); the client has no
                // per-reader colour, so the `--bh` default stands in — see the
                // class doc.
                bloomColor: colors.bloom,
                child: Align(
                  // `.podbar{display:flex;justify-content:center}` — `:297`.
                  alignment: Alignment.topCenter,
                  child: Text(
                    valueText,
                    style: arabicAware(
                      EvaTypography.monoCaps(colors).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        // `.podbar .pv{color:var(--gold)}` — `:300` — and the
                        // gold is in **every** bar, not only the first.
                        color: colors.emberInk,
                      ),
                      direction,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The first place's hairline — `.pod.p1 .podbar::before` at
          // `:302-303`: `top:-1px; left:15%; right:15%; height:1.5px;
          // border-radius:2px; background:linear-gradient(90deg,transparent,
          // rgba(232,176,75,.7),transparent); box-shadow:0 0 12px
          // rgba(232,176,75,.5)`.
          if (isFirst)
            Positioned(
              // The `top:-1px` is measured from the `.podbar`'s **padding
              // box**, which is one pixel inside its border box, so the
              // hairline sits *on* the bar's top edge rather than above it.
              top: 0,
              left: 0,
              right: 0,
              height: 1.5,
              child: FractionallySizedBox(
                // `left:15%; right:15%` — 70% of the bar's width.
                widthFactor: 0.7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        colors.emberInk.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.emberInk.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // The rim, over the surface and over the hairline — the CSS paints a
          // parent's border over its children (`:296`, `:301`).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: barRadius,
                border: Border.all(color: rim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
