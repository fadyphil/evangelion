import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/design_system/leaderboard_l10n.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One ranked child in `/communion`: position, monogram/veil orb, name, sub-metric,
/// and value (`eva/redesign.html:314-327`, `:1114-1127`).
///
/// ## WHY IT LIVES IN THE DESIGN SYSTEM
///
/// Decision 139 placed this row here when both Home and the board rendered it.
/// With Home's board card deleted in Phase 5.2, this is now a single-consumer widget;
/// per decision 12 of the Phase 5 orchestrator decisions, it stays in
/// `core/design_system/widgets/` to avoid churn, and imports only entities from
/// `core/domain/`.
///
/// ## THE VEIL AND MONOGRAM (D11)
///
/// When [isVeiled] is `true` and [isReader] is `false`, the witness's name is replaced
/// by `witness {position}` (`:1070`) and their monogram by the painted outline
/// star [FourPointedStar] (`:1072`). The reader always retains their real name and
/// monogram — the prototype checks `p.id==='you'` **before** the veil, so the reader
/// is never veiled even in principle (`:1069-1070`).
///
/// ## THE READER HIGHLIGHT (.me, D9)
///
/// The reader's own row gains a 3px gold rail on its leading edge
/// (`colors.emberInk`, mirrored under RTL) plus a gold wash.
///
/// ## CHEER BEHAVIOUR (D12)
///
/// Non-reader rows are tappable once to cheer. Tapping plays the prototype's
/// **orb ring pulse** (`:327` → `@keyframes rp`, `:362`) and a **transient painted
/// star flare** in the row, and leaves a **persistent gold accent ring** on the orb.
///
/// ## AND THE CHEER IS A **CONTROL**, SO IT CARRIES §14's RING
///
/// The prototype's row is a `<div>` with an `onclick` (`:1119`), so the browser
/// gives it a focus ring it never asked for. This client has to ask.
///
/// The tappable surface is the **whole row** — that is the prototype's shape
/// (`row.onclick` is on the row, not on the orb) — so the ring goes around the
/// row, with `radius: 0` because `.brow` (`:314`) is a square-edged row and a
/// ring on a row that is not round would be a lie about the shape.
///
/// And the [Semantics] node carries the **action**, not just `button: true`:
/// `excludeSemantics: true` drops the inner `InkWell`'s tap along with the
/// label, so without it the row would be announced as a button and could not be
/// pressed. This is the defect Task 5.4 fixed on the quiz's chevron and CTA.
///
/// ## THE ENTRANCE, AND WHY IT IS A PROPERTY OF THE **LIST**
///
/// The prototype's row does not simply appear. `.brow` starts at
/// `opacity:0; transform:translateY(10px)` (`:315`) and `.brow.in` resolves both
/// (`:317`), and the board's JavaScript adds `.in` on a **staggered** delay —
/// `80 + k·45` ms, where `k` is the row's index in the list (`:1126`). This row
/// does the same: it fades in and rises 10px over the prototype's 300ms, each
/// row starting at `80 + k·45` ms.
///
/// **[entranceIndex] is that `k`**, and it is the reason the parameter exists.
/// It is **nullable**, and `null` means *this row is not one of a staggered
/// list* — a row drawn on its own, outside a board — and such a row does not
/// enter: it is simply there. The prototype's rows always enter, because the
/// prototype's list always builds them (`:1110`); a row on its own is not a
/// state the prototype has.
///
/// The board is what knows the stagger, so the board is what passes the index:
/// `CommunionPage` numbers the rows of `sorted.skip(3)` and hands each one its
/// own number, which is the same `k` the prototype's `forEach` counts.
///
/// ## AND UNDER REDUCED MOTION THERE IS **NO ENTRANCE**
///
/// The row is simply there. The prototype's own reduced-motion arm collapses
/// the row's transition to `0.01s` and its delay to `0`
/// (`:53`'s `.screen.rm .brow{transition-duration:.01s!important}` and
/// `:1126`'s `(reduceMotion||CALM)?0:…`), so the row is there on the first
/// frame there too; this client goes the whole way and runs no transition at
/// all, under [MediaQuery.disableAnimationsOf].
///
/// ## DIVERGENCES FROM `.brow` (`:314-327`), RECORDED HERE
///
/// * **The rail is a `Border`, not an inset box-shadow.** The prototype draws
///   `box-shadow: inset 3px 0 0 var(--gold)` (`:325-326`); Flutter's `BoxShadow` has
///   no inset variant, so the rail is a 3px leading `Border` on the row's own box.
///   The two put the same 3px of gold at the same edge, and the RTL arm mirrors it
///   the way `:326` does.
/// * **The entrance has no `blur`, and D7 is the decision that dropped it.** The
///   prototype's row starts at `opacity:0; transform:translateY(10px);
///   filter:blur(6px)` (`:315`) and `.brow.in` resolves all three (`:317`). This
///   row fades and rises and does **not** blur. D7 is the binding decision for
///   the drop, and this is the site the divergence happens at, with the `:315`
///   citation it names.
/// * **The row draws no `border-bottom` hairline.** `.brow` declares
///   `border-bottom:1px solid rgba(255,255,255,.05)` (`:314`); this row draws
///   no divider. The rows are separated by the **space** between them (the 8px
///   of vertical padding on each side) and the reader's own gold rail (`:325`)
///   is the only rule a row draws.
/// * **The spacing is the design system's, not the CSS's.** `.brow` (`:314`)
///   declares `padding:12px 18px` and `gap:12px`; this row uses
///   `EdgeInsets.symmetric(vertical: 8, horizontal: 4)` with gaps of
///   `EvaSpacing.sm` (8px, rank→orb) and `EvaSpacing.md` (12px, orb→name and
///   name→value). The horizontal inset is 4px rather than 18px because the
///   board is already inside the screen's 20px gutter — `CommunionPage` wraps
///   the whole column in `EvaSpacing.screenHorizontal` — and a row is a band
///   inside that gutter rather than a card with an inset of its own.
/// * **The type is the design system's too, with two exceptions.** The
///   prototype's row sets the name at 13.5px (`:321`), the rank column at 11px
///   (`:318`), the sub-line at 8.5px (`:322`) and the value at 11px (`:324`).
///   This row keeps the **name** at exactly 13.5px (the brief fixes it) and the
///   **rank column** at exactly 11px, and the two runs the prototype draws
///   small are drawn here at 10.5px (the sub-line) and **14px** (the value).
///   The value is the row's **primary figure** — the number of the metric the
///   board is ranked by — and the prototype separates it from the sub-line by
///   ink alone (gold against `--ink-2`); here it is also the larger of the two,
///   so the number the reader came for is the one the eye lands on. The
///   sub-line is the *other* metric's number and is deliberately the smaller
///   run.
/// * **The " · you" suffix is the prototype's, and this row is the only place
///   it has one.** `:1116` appends ` · you` to the reader's name in the
///   **list**, and so does this row. The prototype's *card* does not (`:1103` is
///   the bare name) and this client's card does — that copy is a divergence,
///   and it is recorded at the card.
/// * **The entrance plays once, when the row is mounted.** The prototype
///   rebuilds the list from scratch on every render (`:1109-1110` —
///   `list.innerHTML=''` and a fresh `forEach`), so its rows re-enter whenever
///   the board is redrawn. This client keeps the rows' state across a re-rank
///   and a reload, so a row that is already on the board does not enter a
///   second time.
class LeaderboardRowTile extends StatefulWidget {
  /// A ranked row for [row].
  const LeaderboardRowTile({
    required this.row,
    required this.isReader,
    this.displayPosition,
    this.metric = LeaderboardMetric.light,
    this.isVeiled = false,
    this.isCheered = false,
    this.entranceIndex,
    this.onCheer,
    super.key,
  });

  /// The ranked child.
  final LeaderboardRow row;

  /// Whether this is the reader's own row.
  final bool isReader;

  /// The row's 1-indexed display position in the current metric's sorted order.
  /// Defaults to [LeaderboardRow.rank].
  final int? displayPosition;

  /// The active metric determining which value is primary and which is sub-line.
  final LeaderboardMetric metric;

  /// Whether the communal veil is on.
  final bool isVeiled;

  /// Whether this witness has already received a cheer in this session.
  final bool isCheered;

  /// The row's 0-based index in the board's **list**, which is the `k` in the
  /// prototype's `80 + k·45` ms stagger (`eva/redesign.html:1126`).
  ///
  /// **`null` means the row is not one of a staggered list** — a row drawn on
  /// its own rather than in a board — and such a row does not enter: it is
  /// simply there. See the class doc for why the entrance belongs to the list.
  final int? entranceIndex;

  /// Invoked when a non-reader row is tapped to send a cheer.
  final VoidCallback? onCheer;

  /// `eva/redesign.html:318` — the rank column width.
  static const double rankWidth = 24;

  /// `eva/redesign.html:319` — the monogram orb diameter.
  static const double markSize = 30;

  @override
  State<LeaderboardRowTile> createState() => _LeaderboardRowTileState();
}

class _LeaderboardRowTileState extends State<LeaderboardRowTile>
    with SingleTickerProviderStateMixin {
  /// The prototype's transition length — `.brow`'s `transition: … .3s` (`:316`).
  static const int entranceDurationMs = 300;

  /// The prototype's first row's delay — the `80` of `80 + k·45` (`:1126`).
  static const int entranceBaseDelayMs = 80;

  /// The prototype's stagger — the `45` of `80 + k·45` (`:1126`).
  static const int entranceStaggerMs = 45;

  /// How far below its resting place the row starts — `translateY(10px)`
  /// (`:315`).
  static const double entranceRisePx = 10;

  /// The entrance's clock, or `null` when the row does not enter.
  ///
  /// **One controller carries the delay and the transition**, so the row's
  /// progress is a pure function of the elapsed time rather than of a timer
  /// that has to be cancelled.
  AnimationController? _entrance;

  /// Whether the entrance has been started.
  bool _started = false;

  /// The delay for the row at [index] in the list.
  static int _delayMsFor(int index) =>
      entranceBaseDelayMs + index * entranceStaggerMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started **once**. `didChangeDependencies` runs again whenever an
    // inherited widget changes, and `forward()` on a finished controller
    // replays it from the beginning — so this guard is what keeps a rebuild
    // from re-running the entrance.
    if (_started) return;
    _started = true;
    final int? index = widget.entranceIndex;
    if (index == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _delayMsFor(index) + entranceDurationMs),
    );
    _entrance = controller;
    controller.forward();
  }

  @override
  void dispose() {
    _entrance?.dispose();
    super.dispose();
  }

  /// The entrance's progress, `0` … `1`.
  ///
  /// The delay is folded into the controller's duration, so the transition
  /// itself is the last 300ms of it, and the curve is the prototype's
  /// `--e-light` — `cubic-bezier(.16,1,.3,1)` (`:18`) — which is
  /// [EvaMotion.interactiveCurve].
  ///
  /// **The two ends are exact.** `Curves.easeOutExpo` is `1 - 2^(-10t)`, so
  /// `transform(1)` is `0.999…` and not `1`; a row that ended a thousandth
  /// short of opaque would be a row that never quite arrives. So the ends are
  /// answered before the curve is asked.
  double _entranceProgress(AnimationController controller, int delayMs) {
    final int total = delayMs + entranceDurationMs;
    final double elapsed = controller.value * total;
    final double raw = (elapsed - delayMs) / entranceDurationMs;
    if (raw <= 0) return 0;
    if (raw >= 1) return 1;
    return EvaMotion.interactiveCurve.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final TextDirection direction = Directionality.of(context);
    final int position = widget.displayPosition ?? widget.row.rank;

    // The prototype prints the position through its `N()` digit transform
    // (`eva/redesign.html:1114`), so the Arabic arm reads `٢` and not `2`.
    final String positionText = strings.digits(position);

    final String displayName = widget.isVeiled && !widget.isReader
        ? strings.leaderboardWitness(positionText)
        : (widget.isReader
              ? '${widget.row.fullName} · ${strings.leaderboardYou}'
              : widget.row.fullName);

    final String sublineText = switch (widget.metric) {
      LeaderboardMetric.light =>
        '${strings.digits(widget.row.currentStreak)} ${strings.leaderboardMetricStreaks}',
      LeaderboardMetric.streaks =>
        '${strings.digits(widget.row.score)} ${strings.leaderboardMetricLight}',
    };

    final String valueText = switch (widget.metric) {
      LeaderboardMetric.light => strings.digits(widget.row.score),
      LeaderboardMetric.streaks => strings.digits(widget.row.currentStreak),
    };

    final Widget content = Container(
      decoration: BoxDecoration(
        color: widget.isReader
            ? colors.ember.withValues(alpha: 0.08)
            : Colors.transparent,
        border: widget.isReader
            ? Border(
                left: direction == TextDirection.ltr
                    ? BorderSide(color: colors.emberInk, width: 3)
                    : BorderSide.none,
                right: direction == TextDirection.rtl
                    ? BorderSide(color: colors.emberInk, width: 3)
                    : BorderSide.none,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: LeaderboardRowTile.rankWidth,
            child: Text(
              positionText,
              textAlign: TextAlign.center,
              style: arabicAware(
                EvaTypography.monoCaps(colors).copyWith(
                  fontSize: 11,
                  color: widget.isReader ? colors.emberInk : colors.ink2,
                ),
                direction,
              ),
            ),
          ),
          const SizedBox(width: EvaSpacing.sm),
          _CheerOrb(
            isVeiled: widget.isVeiled,
            isReader: widget.isReader,
            isCheered: widget.isCheered,
            initials: widget.row.initials,
            colors: colors,
          ),
          const SizedBox(width: EvaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: arabicAware(
                    text.bodyMedium!.copyWith(
                      fontSize: 13.5,
                      fontWeight: widget.isReader
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: widget.isReader ? colors.emberInk : colors.ink,
                    ),
                    direction,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublineText,
                  style: arabicAware(
                    EvaTypography.monoCaps(colors)
                        .copyWith(fontSize: 10.5, color: colors.ink2),
                    direction,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: EvaSpacing.md),
          Text(
            valueText,
            style: arabicAware(
              EvaTypography.monoCaps(colors).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.emberInk,
              ),
              direction,
            ),
          ),
        ],
      ),
    );

    final bool isCheerable = !widget.isReader && widget.onCheer != null;

    final Widget row = Semantics(
      label: strings.leaderboardRowAnnouncement(
        widget.row,
        isReader: widget.isReader,
        isVeiled: widget.isVeiled,
        displayPosition: position,
      ),
      excludeSemantics: true,
      button: isCheerable,
      // ## AND THE **ACTION**, WHICH `button: true` ALONE DID NOT GIVE
      //
      // `excludeSemantics: true` drops the `InkWell`'s tap action along with
      // the inner text, so without this the row would be announced as a button
      // and could **not be pressed** — a screen reader would offer a control
      // with no way to use it. This is the same defect Task 5.4 fixed on the
      // quiz's back chevron and CTA, and the fix is the same: the action goes
      // on the [Semantics] node.
      onTap: isCheerable ? widget.onCheer : null,
      child: isCheerable
          ? EvaFocusRing(
              // A row is not a pill. The prototype's `.brow` (`:314`) is a
              // full-bleed row with square corners, so the ring around the tap
              // target is square too.
              radius: 0,
              child: EvaInk(
                onPressed: widget.onCheer,
                borderRadius: BorderRadius.zero,
                child: content,
              ),
            )
          : content,
    );

    // ## THE ENTRANCE
    //
    // No index means the row is not one of a staggered list, and reduced
    // motion means the row is simply there — in both cases the row is
    // returned as it is, with no opacity layer and no transform.
    final int? index = widget.entranceIndex;
    final AnimationController? controller = _entrance;
    if (index == null || controller == null) return row;
    if (MediaQuery.disableAnimationsOf(context)) return row;

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _entranceProgress(controller, _delayMsFor(index));
        if (t >= 1) {
          // **At rest the row is the row.** An `Opacity` at 1.0 is still a
          // composited layer, and a board can carry fifty of them; dropping
          // the wrapper once the entrance is over leaves the list with no
          // layers at all.
          return row;
        }
        return Opacity(
          opacity: t,
          // **The semantics survive the fade.** The prototype's row is a DOM
          // element with a CSS opacity, and an element's opacity does not take
          // it out of the accessibility tree — so the row is announced from
          // the first frame here too, rather than arriving to a screen-reader
          // user 80ms after the page did.
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, entranceRisePx * (1 - t)),
            child: child,
          ),
        );
      },
      child: row,
    );
  }
}

/// The monogram orb, and the two things a cheer does to it.
///
/// ## THE PULSE AND THE FLARE (D12)
///
/// The prototype plays two effects on a cheer, and this widget plays both:
///
/// * the **ring pulse** — `.brow.cheered .borb{animation:rp 1s var(--e-out) 1}`
///   (`:327`), which is `@keyframes rp{0%{box-shadow:0 0 0 0 rgba(232,176,75,.5)}
///   100%{box-shadow:0 0 0 14px rgba(232,176,75,0)}}` (`:362`): a gold halo that
///   grows from nothing to 14px while it fades out, **once**;
/// * the **star flare** — the prototype's `addStar(true)` (`:1123`), which puts a
///   bigger star into the **witness sky**.
///
/// ## AND WHY THE FLARE IS **ROW-LOCAL AND TRANSIENT** HERE
///
/// `SkyEntry` is **verse-keyed**: it names a book and a verse, and `/communion` has
/// no verse. The prototype's sky is a decoration that happens to be on the same
/// screen; putting a board's cheer into it would mean inventing a verse key for a
/// witness. So the flare is painted **in the row** and fades away, and the only
/// evidence that survives the toast is the **persistent gold ring** on the orb.
///
/// The prototype's aurora spike (`V.spike=.35`, `:1124`) is **not** ported: this app
/// has no per-screen ambient machinery, and a board that spiked the whole shell's
/// aurora would be a louder event than the prototype's.
///
/// ## AND NO HAPTIC
///
/// The prototype calls `haptic(20)` (`:1123`). This app ships none — the login page
/// records adding the first as a product decision — so the cheer is silent, and the
/// toast is the confirmation.
class _CheerOrb extends StatefulWidget {
  const _CheerOrb({
    required this.isVeiled,
    required this.isReader,
    required this.isCheered,
    required this.initials,
    required this.colors,
  });

  final bool isVeiled;
  final bool isReader;
  final bool isCheered;
  final String initials;
  final EvaColors colors;

  @override
  State<_CheerOrb> createState() => _CheerOrbState();
}

class _CheerOrbState extends State<_CheerOrb>
    with SingleTickerProviderStateMixin {
  /// The pulse's duration — the prototype's `rp 1s` (`:362`).
  static const Duration pulseDuration = Duration(milliseconds: 1000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: pulseDuration,
  );

  @override
  void didUpdateWidget(_CheerOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **Only on the transition.** A rebuild that leaves the row cheered must not
    // replay the flare, or every parent rebuild would re-fire it.
    if (widget.isCheered && !oldWidget.isCheered) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = widget.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget orb = Container(
      width: LeaderboardRowTile.markSize,
      height: LeaderboardRowTile.markSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isReader
            ? colors.ember.withValues(alpha: 0.2)
            : colors.surface,
        border: Border.all(
          color: widget.isCheered
              ? colors.emberInk
              : (widget.isReader ? colors.emberInk : colors.glassBorder),
          width: widget.isCheered ? 1.5 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: widget.isVeiled && !widget.isReader
          ? FourPointedStar(size: 13, color: colors.ink2, outline: true)
          : Text(
              widget.initials,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isReader ? colors.emberInk : colors.ink,
              ),
            ),
    );

    if (reduceMotion) {
      // D12: "the ring and flare become instant/no-ops". The persistent mark is
      // still there — it is state, not an effect.
      return orb;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        // ## THE PULSE AND THE FLARE ARE **EFFECTS**, AND AN EFFECT BELONGS TO
        // ## THE TRANSITION THAT STARTED IT
        //
        // The gate is [_controller.isAnimating], and it is not decoration. A row
        // that is **built** already-cheered has never run the animation — and that
        // is reachable, not hypothetical: `CommunionPage` empties the board and
        // reloads it on a window change (`leaderboard_cubit.dart:143-150`), and
        // the cheers **survive** the reload, so a reader who cheered a witness and
        // then switched the window gets that row back already marked.
        //
        // With the flare gated on `isCheered` alone, such a row sat at `t == 0`
        // — which is the flare's *first* frame, painted at full opacity over the
        // monogram — and never moved, because the controller is only ever started
        // on a not-cheered → cheered **transition**. The effect was stuck on.
        //
        // The **persistent gold ring** on the orb is state, not an effect, and it
        // is drawn by the orb's own border below — so it survives the reload, as
        // it should, and the halo and the flare do not.
        final bool isPulsing = _controller.isAnimating;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // The prototype's `rp`: a gold halo that grows to 14px and fades out.
            boxShadow: isPulsing
                ? <BoxShadow>[
                    BoxShadow(
                      color: colors.ember.withValues(alpha: 0.5 * (1 - t)),
                      spreadRadius: 14 * t,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              child!,
              if (isPulsing && t < 0.6)
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: (1 - t / 0.6).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -12 * t),
                        child: Transform.scale(
                          scale: 0.5 + 1.1 * t,
                          child: FourPointedStar(
                            size: 14,
                            color: colors.emberInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: orb,
    );
  }
}
