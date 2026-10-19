import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The Eva motion table — durations and curves in one place.
///
/// `docs/plans/03-design-system.md` §5.3:
///
/// | Token | Duration | Curve |
/// | --- | --- | --- |
/// | `fast` | 150ms | `easeOut` |
/// | `base` | 200ms | `easeOut` |
/// | `screen` | 250ms | `easeOutCubic` |
/// | `fleck` | 2000ms | `alternate` |
/// | `orbFloat` | 14–28s per orb | `easeInOut` |
/// | `orbHue` | 7–14s per orb | `linear` |
/// | `aurora` | 14s | `easeInOut` |
///
/// and, immediately after: "All curves are ease-out. No bounce, no spring."
///
/// ## THAT LAST SENTENCE IS **PARTLY SUPERSEDED** — SEE BELOW
///
/// "No bounce, no spring" is **still true** and is kept: `grep -ri spring eva/src`
/// over the prototype returns nothing. What was wrong is the implication that every
/// curve is a plain `easeOut`, because the prototype's own `QuizOption`
/// (`ds.tsx:438`) uses `cubic-bezier(0.16,1,0.3,1)`. Phase 0 adds
/// [interactiveCurve] (that curve) and [achievementSpring] (a real spring, for
/// achievement moments only) under the heading *"Interactive + achievement motion
/// (Phase 0)"*. Ambient motion is untouched. Full reasoning is there; the table
/// above stays as §5.3 transcribed it, because the audit trail is worth more than a
/// tidy table.
///
/// WHY THE AMBIENT ANIMATIONS ARE NOT `AnimationController`s HELD HERE. There
/// are four shared controllers app-wide — float, hue, aurora, and the LUMEN
/// shader clock (`09-quality-gates.md` §13, mitigation 2, plus the Task 1.3
/// clock that `u_time` reads) — and they live in a
/// `TickerProviderStateMixin` host mounted above `MaterialApp.router`, published
/// through an inherited scope. That is Phase 2's `NeuralMotionScope`. This file
/// holds only the numbers and the shapes, which is why it has no `Ticker` and no
/// `vsync`: a `SingleTickerProvider` here would re-introduce exactly the
/// per-orb controller explosion that mitigation 2 exists to remove.
///
/// WHY `fleck`'s "alternate" IS A FLAG AND NOT A CURVE. Flutter has no
/// `Curves.alternate`. There-and-back is a *direction*, expressed as
/// `AnimationController.repeat(reverse: true)`, and it is orthogonal to the
/// easing shape. So [fleckCurve] carries the ease-out shape the brief's rule
/// requires and [fleckAlternates] carries the direction for Phase 2 to act on.
/// Collapsing the two into one token would have meant inventing a curve.
abstract final class EvaMotion {
  // --- Durations -----------------------------------------------------------

  /// `150ms` — press and hover feedback on a control.
  static const Duration fast = Duration(milliseconds: 150);

  /// `200ms` — a state change on an element already on screen.
  static const Duration base = Duration(milliseconds: 200);

  /// `250ms` — a screen-level transition.
  static const Duration screen = Duration(milliseconds: 250);

  /// `2000ms` — one full there-and-back cycle of a `GoldFlecks` fleck.
  static const Duration fleck = Duration(seconds: 2);

  /// `14s` — one full aurora cycle.
  static const Duration aurora = Duration(seconds: 14);

  /// `14s` — the shortest an orb's float cycle may run.
  ///
  /// §5.3 gives `orbFloat` as the range `14–28s per orb`, not a single value, so
  /// the range is the token and [orbFloatFor] spreads it. There is no single
  /// "orbFloat duration" to expose, and exposing the minimum alone would quietly
  /// collapse the range.
  static const Duration orbFloatMin = Duration(seconds: 14);

  /// `28s` — the longest an orb's float cycle may run.
  static const Duration orbFloatMax = Duration(seconds: 28);

  /// `7s` — the shortest an orb's hue cycle may run.
  static const Duration orbHueMin = Duration(seconds: 7);

  /// `14s` — the longest an orb's hue cycle may run.
  static const Duration orbHueMax = Duration(seconds: 14);

  // --- Curves --------------------------------------------------------------

  /// `easeOut` — with [fast].
  static const Curve fastCurve = Curves.easeOut;

  /// `easeOut` — with [base].
  static const Curve baseCurve = Curves.easeOut;

  /// `easeOutCubic` — with [screen]. Steeper than [fastCurve]: a whole screen
  /// arriving needs more of its motion spent early than a button tinting does.
  static const Curve screenCurve = Curves.easeOutCubic;

  /// `easeOut` — with [fleck]; see [fleckAlternates] for the direction.
  static const Curve fleckCurve = Curves.easeOut;

  /// `easeInOut` — with the orb float cycles.
  static const Curve orbFloatCurve = Curves.easeInOut;

  /// `linear` — with the orb hue cycles. A hue *rotation* eased would
  /// accelerate through the colour wheel and read as flicker, not breathing.
  static const Curve orbHueCurve = Curves.linear;

  /// `easeInOut` — with [aurora].
  static const Curve auroraCurve = Curves.easeInOut;

  // --- Interactive + achievement motion (Phase 0) ---------------------------
  //
  // ## THIS SUPERSEDES "ALL CURVES ARE EASE-OUT. NO BOUNCE, NO SPRING."
  //
  // That sentence is the class doc above, and it is the `docs/plans/03-design-system.md`
  // §5.3 rule transcribed. It was the brief's wording and it was implemented
  // literally. **It was also wrong about the prototype**, which is worth recording
  // because the two are easy to confuse:
  //
  // | prototype site | curve | Flutter equivalent |
  // | --- | --- | --- |
  // | `ds.tsx:438` `QuizOption` — the most-tapped element in the app | `all 250ms cubic-bezier(0.16,1,0.3,1)` | [interactiveCurve] — an **approximation** of that bezier, not the same curve |
  // | `ds.tsx:207` orb mouse-parallax | `transform 0.9s cubic-bezier(0.16,1,0.3,1)` | [interactiveCurve] — an **approximation** of that bezier, not the same curve |
  //
  // **The word "approximation" is the point**, and it was added after a
  // review found the table asserting an identity that was not there:
  // [interactiveCurve] is `Cubic(0.19, 1.0, 0.22, 1.0)` and the prototype's
  // bezier is `Cubic(0.16, 1, 0.3, 1)`. They are close, and the distance is
  // measured — see [interactiveCurve] for the number.
  //
  // So `QuizOption` — the answer a child presses to answer a question — was never
  // on a plain `easeOut` in the design this app was transcribed from. "No bounce,
  // no spring" remains **true** of the prototype: `grep -ri spring eva/src` returns
  // nothing. What was false was the implied "and no expo".
  //
  // ## TWO FAMILIES, TWO NAMES, ON PURPOSE
  //
  // | family | token | used for |
  // | --- | --- | --- |
  // | routine | [interactiveCurve] | state changes on things already on screen |
  // | achievement | [achievementCurve] / [achievementSpring] | a cause-and-effect moment worth feeling |
  //
  // **Two** achievement tokens because the two are not interchangeable, and the
  // difference is mechanical rather than stylistic: [achievementCurve] is a `Curve`
  // and can go through `flutter_animate`, while [achievementSpring] is a
  // `SpringSimulation` and cannot — its value leaves `[0,1]`, which that package's
  // `Interval` asserts against. Both are matched on overshoot (~8.5%) so they read as
  // the same family.
  //
  // The split is not decoration. A spring on **every** tap says nothing; a spring on
  // *your streak went up* says the thing happened. One app-wide curve cannot
  // distinguish those, so the token file now can.

  //
  // Ambient motion is deliberately **not** touched by any of this: the orbs run
  // 14–28s and the aurora 14s, and a spring on a 28-second cycle would be
  // indistinguishable from no spring at all while costing a simulation per frame.

  /// `cubic-bezier(0.16, 1, 0.3, 1)` — the prototype's own interactive curve.
  ///
  /// ## IT IS AN **APPROXIMATION** OF THAT BEZIER, AND NOT THE SAME CURVE
  ///
  /// [Curves.easeOutExpo] is `Cubic(0.19, 1.0, 0.22, 1.0)`, and the
  /// prototype's `--e-light` is `Cubic(0.16, 1, 0.3, 1)`. **They are not the
  /// same curve** — this doc once said they were, and a review found the
  /// claim false.
  ///
  /// The approximation is close, and the distance is **measured**: over the
  /// whole curve the two differ by at most **2.53%** of the progress, and the
  /// worst of it is at x ≈ 0.054, where the prototype's curve is ahead by
  /// 0.025. A screen that draws a one-second animation from it cannot tell
  /// the two apart; a screen that transcribes the prototype's rule for its
  /// own sake can, and does.
  ///
  /// **AND A SCREEN THAT NEEDS THE PROTOTYPE'S OWN CURVE TRANSCRIBES IT.**
  /// `/journey`'s rings are the case: `journey_rings_row.dart`'s `drawCurve`
  /// is `Cubic(0.16, 1, 0.3, 1)`, transcribed from `eva/redesign.html:18`,
  /// and the divergence from this token is recorded **at the site** — which is
  /// the shape this file asks of every approximation it makes.
  ///
  /// It leaves the gate faster than any other curve here and then spends a
  /// long tail settling, which is why it reads as "responsive" rather than
  /// "abrupt" — and why a 250ms `QuizOption` press felt deliberate in the
  /// prototype.
  ///
  /// **No overshoot.** It is monotone. Anything that overshoots belongs to
  /// [achievementSpring], and that is the whole reason the two are separate.
  static const Curve interactiveCurve = Curves.easeOutExpo;

  /// The physics for an achievement moment: a streak went up, a milestone landed.
  ///
  /// ## WHERE THIS IS USABLE, AND WHERE IT IS **NOT**
  ///
  /// **Usable** for an effect a widget drives itself — it owns the controller and
  /// calls `animateWith(SpringSimulation(...))`. `StreakFlame`'s flare is that case.
  ///
  /// **NOT usable** through `flutter_animate`'s `Animate(controller: ...)`, which
  /// looks like the obvious way to get physics through the package and is not. Its
  /// `EffectEntry.buildAnimation` wraps whatever controller it is handed in
  /// `Interval(begin / controller.duration, end / controller.duration)`, and a
  /// spring's value **exceeds 1.0** by design. Measured: feeding an overshooting
  /// value into that chain trips `ParametricCurve`'s own assertion —
  /// `t >= 0.0 && t <= 1.0` — inside `Curves.transform`. A spring routed through
  /// `Animate` does not merely lose its overshoot, it **throws** in debug.
  ///
  /// `Animate` animates with `Curve`s and can only overshoot by way of a `Curve` that
  /// overshoots. That is what [achievementCurve] is for, and why there are two
  /// achievement tokens rather than one.
  ///
  /// ## WHY THE TWO ARE MATCHED ON OVERSHOOT
  ///
  /// They are different mechanisms, so the only question that matters is whether they
  /// *feel* like one family. Measured: the spring peaks at **8.3%**,
  /// [Curves.easeOutBack] at **8.7%**. Paired to stay within a point of each other,
  /// and `test/core/design_system/tokens/eva_motion_test.dart` asserts the pairing — so
  /// a future bump to one cannot quietly desynchronise the flame from everything else.
  ///
  /// ## `static final`, NOT `static const`
  ///
  /// `SpringDescription.withDurationAndBounce` is a **factory**, so it cannot be a
  /// const expression and this cannot be `const`. That is not a workaround, it is why
  /// the inputs are visible: the `const` pair a reader actually tunes is
  /// [achievementDuration] and [achievementBounce], and the three coefficients below
  /// are what comes out.
  static final SpringDescription achievementSpring =
      SpringDescription.withDurationAndBounce(
        duration: achievementDuration,
        bounce: achievementBounce,
      );

  /// The achievement curve for effects driven through `flutter_animate`.
  ///
  /// [Curves.easeOutBack], picked from the measured overshoot of Flutter's catalogue
  /// rather than by name:
  ///
  /// | curve | overshoot | within 1% of target at | ends at 1.0 |
  /// | --- | --- | --- | --- |
  /// | [Curves.easeOutExpo] | 0% | 59% | yes |
  /// | **[Curves.easeOutBack]** | **8.7%** | **36%** | **yes** |
  /// | [Curves.elasticOut] | 27.5% | 10% | yes |
  /// | [Curves.fastOutSlowIn] | 0% | 87% | yes |
  ///
  /// `elasticOut` is the obvious candidate on the name and is **rejected at 27.5%** —
  /// a quarter again over the target reads as a glitch on a flame meant to look like it
  /// caught, not as a celebration. `easeOutBack` lands within a point of
  /// [achievementSpring] and leaves the gate faster than anything monotone here.
  ///
  /// **Boundedness is the property that matters, not monotonicity.** Every row above
  /// ends at exactly `1.0`, which is why `flutter_animate`'s `Interval` can carry them
  /// safely where it cannot carry a spring.
  static const Curve achievementCurve = Curves.easeOutBack;

  /// How many times the spring passes its target before settling.
  ///
  /// `withDurationAndBounce` turns this into a damping ratio of `1 - bounce`, so
  /// `0.38` means *"underdamped enough that one overshoot is unmistakable"*. At
  /// `0.0` there is no overshoot and the whole distinction from [interactiveCurve]
  /// disappears; past ~`0.7` it stops reading as a celebration and starts reading as
  /// a toy.
  ///
  /// The gate for "the two tokens really are different animations" is
  /// [achievementOvershoots], and this is what it reads.
  static const double achievementBounce = 0.38;

  /// The **nominal** duration handed to the spring factory.
  ///
  /// ## IT IS NOT HOW LONG THE SPRING TAKES, AND THE NAME SAYS SO
  ///
  /// This was first written as `achievementSettleHint = 420ms` with a doc claiming it
  /// was "roughly how long the spring takes to look finished". **Measured, that was
  /// false by nearly 2×: a 420ms nominal does not settle until ~796ms.** Renamed
  /// rather than re-documented, because a constant called `SettleHint` holding a
  /// number that is not the settle time is a lie that survives every future read.
  ///
  /// Flutter's `withDurationAndBounce` derives stiffness as `4π²/duration²`, so the
  /// nominal is really a stiffness dial wearing a duration's clothes. What the
  /// *measured* settle time is, is a **property of the spring** and therefore belongs
  /// in a test, not in this file. Driven at 4ms steps:
  ///
  /// | nominal | stiffness | measured settle | overshoot |
  /// | --- | --- | --- | --- |
  /// | 120ms | 2742 | ~300ms | 8.4% |
  /// | **180ms** | **1218** | **~344ms** | **8.3%** |
  /// | 210ms | 895 | ~400ms | 8.3% |
  /// | 280ms | 504 | ~536ms | 8.3% |
  /// | 420ms | 224 | ~796ms | 8.4% |
  ///
  /// Read the settle column as a range, not a formula: `isDone` is tolerance-based,
  /// so a coarse probe lands on different grid boundaries — 120ms measured 300 while
  /// 140ms measured 268, which is not a real non-monotonicity. The trend is the only
  /// part that means anything, and it is roughly `2×`.
  ///
  /// 180ms is chosen because its measured settle (~344ms) sits under the 400ms a
  /// complex transition is allowed, with margin, while staying slow enough to read as
  /// a celebration. The 8.3% overshoot is what makes it feel like an achievement
  /// rather than a step; the settle time is what stops it feeling like a toy.
  static const Duration achievementDuration = Duration(milliseconds: 180);

  /// The achievement motion's **real** duration — the spring's measured settle.
  ///
  /// ## WHY THE SPRING NEEDS TWO NUMBERS AND THE CURVE NEEDS ONE
  ///
  /// [achievementDuration] is a nominal: it is a stiffness dial that happens to be
  /// expressed as time, and the spring it configures does not finish until ~344ms.
  /// [achievementCurve] has no such indirection — given a duration it *is* that
  /// duration. So the two achievement mechanisms must be handed **different** numbers
  /// to feel like the same motion, and this is the one the curve gets.
  ///
  /// Giving both of them 180ms would be the obvious move and would be wrong twice
  /// over: the curve-driven pop would finish in half the time of the spring-driven
  /// one, and [achievementExit] at 220ms would then be *slower* than the entrance it
  /// is supposed to follow.
  ///
  /// ## A CONSTANT, NOT A COMPUTED VALUE
  ///
  /// The measured settle is a property of a simulation, so it cannot be a `const`
  /// expression — but it is also not something to recompute at every call site. So it
  /// is **recorded here** and checked against reality:
  /// `test/core/design_system/tokens/eva_motion_test.dart` drives the real
  /// `SpringSimulation` and asserts it still settles within a few milliseconds of this
  /// number. Change [achievementDuration] or [achievementBounce] and that test is what
  /// tells you this constant has gone stale.
  static const Duration achievementSettle = Duration(milliseconds: 344);

  /// How long an achievement moment takes to **leave**.
  ///
  /// 220ms against the entrance's measured ~344ms, so ~64% of it. An exit that takes
  /// as long as its entrance makes the interface feel like it is waiting on the
  /// animation rather than on the reader. Exits read as "already happening",
  /// entrances as "here it comes".
  ///
  /// **This is a [Curve] duration, so it is honest about itself** — unlike
  /// [achievementDuration], which is a nominal. The entrance/exit ratio is asserted
  /// against the spring's *measured* settle in
  /// `test/core/design_system/tokens/eva_motion_test.dart`, because comparing two
  /// nominal numbers would prove nothing: `220 < 180` is false while `220 < ~344` is
  /// true, and only the second is the claim being made.
  static const Duration achievementExit = Duration(milliseconds: 220);

  /// The damping ratio [achievementSpring] actually ended up with.
  ///
  /// `SpringDescription` stores `damping`, not the ratio, so recovering it means
  /// dividing out `2·√(mass·stiffness)`. Exposed because [achievementOvershoots] needs
  /// it. A doc here once said this "lands near `0.62` rather than exactly on it" —
  /// measured, it is `0.6200` to four places, because `damping` is derived from
  /// `1 - bounce` and `achievementBounce` is exactly `0.38`.
  static double get achievementDampingRatio =>
      achievementSpring.damping /
      (2 * math.sqrt(achievementSpring.mass * achievementSpring.stiffness));

  /// Whether [achievementSpring] overshoots at all.
  ///
  /// The distinction between [interactiveCurve] and [achievementSpring] exists only
  /// because this is `true`. At a ratio of 1.0 or above both would be monotone and the
  /// two tokens would be the same animation under two names — a worse outcome than
  /// having neither.
  static bool get achievementOvershoots => achievementDampingRatio < 1.0;

  /// Whether a fleck animation should run there-and-back rather than restarting.
  ///
  /// The `alternate` column of the §5.3 table. Phase 2 reads this to choose
  /// `repeat(reverse: true)` over `repeat()`.
  static const bool fleckAlternates = true;

  // --- The global screen transition -----------------------------------------

  /// `8` logical pixels — how far the global screen transition slides a page.
  ///
  /// §8 of `06-navigation.md`: a fade plus an 8px slide, and the 8 is the
  /// number, not a fraction of anything. Kept as its own named constant because
  /// it is new information the §5.3 table does not carry — unlike the duration,
  /// which already exists as [screen] and is reused verbatim.
  static const double screenSlidePixels = 8;

  /// The offset a page [height] logical pixels tall starts its slide from.
  ///
  /// `SlideTransition` translates by a **fraction** of the child's height, so an
  /// 8px slide is `8 / height` — which means the fraction necessarily changes
  /// with the viewport. `06-navigation.md` §8 spells this out and rules out the
  /// tempting `Offset(0, 0.04)`: a fraction is right on exactly the screen it
  /// was measured on and wrong on every other, which on this design means 33.8px
  /// of travel on a 844px phone instead of 8.
  ///
  /// A height that cannot produce a usable fraction — zero, negative, or NaN —
  /// yields [Offset.zero], because `8 / 0` is `Infinity` and
  /// `FractionalTranslation` would then hand an infinite transform to the
  /// matrix. An infinite height needs no arm of its own: `8 / infinity` is `0`,
  /// i.e. no slide, which is the honest answer for an unbounded page.
  static Offset screenSlideBeginFor(double height) =>
      Offset(0, height > 0 ? screenSlidePixels / height : 0);

  /// The global screen transition: a fade and an 8px slide up, on [screenCurve]
  /// over [screen]. Installed app-wide by `AppRouter.defaultRouteType`.
  ///
  /// This is a `RouteTransitionsBuilder` — the signature Flutter's
  /// `PageRoute`/`PageRouteBuilder` uses, and the one auto_route's
  /// `RouteType.custom(transitionsBuilder:)` expects.
  ///
  /// ## THE `BuildContext` IS READ, AND §14 IS WHY
  ///
  /// **This sentence replaced "nothing here reads from it", which was the §14
  /// violation written down as if it were a design note.** §14's row is "every
  /// animation checks `MediaQuery.disableAnimationsOf(context)`; when disabled,
  /// jump straight to the end state", and the transition was the one site of
  /// seven that did not — so a reader who has asked their OS for reduced motion
  /// still got a 250ms fade and an 8px slide on **every** navigation, on all six
  /// screens, because this builder is installed app-wide.
  ///
  /// The reachability question is settled, not assumed: a route transition is
  /// built inside the route's `ModalScope`, which is a descendant of the
  /// `Overlay`, of the `Navigator`, and therefore of whatever
  /// `MaterialApp.builder` returned. `app.dart` installs the text scale there and
  /// `copyWith`s the ambient data, which carries `disableAnimations` through
  /// unchanged. Contrast `neural_motion.dart:259-268`, whose scope sits **above**
  /// `MaterialApp` and genuinely has no `MediaQuery` to read — that one recorded
  /// its reason after checking it, and corrected an earlier comment that had
  /// claimed the platform signal could not reach it either.
  ///
  /// [secondaryAnimation] is deliberately unused: this transition does not
  /// cross-fade with the route it is covering, so honouring it would make the
  /// outgoing page slide while the incoming one slides back and the two fight.
  ///
  /// WHY THE CURVE IS APPLIED HERE. The `animation` auto_route hands a custom
  /// transitions builder comes from `PageRoute`, whose `curve` is
  /// `Curves.linear`; only `MaterialPageRoute`'s own builder curves it. So a
  /// builder that used the animation raw would animate linearly and ignore
  /// §5.3's `easeOutCubic` for [screen].
  ///
  /// ## AND "JUMP TO THE END STATE" IS A SUBSTITUTED ANIMATION, NOT A DROPPED TREE
  ///
  /// [kAlwaysCompleteAnimation] replaces [animation] on both transitions, so the
  /// fade sits at 1 and the slide at zero while `FadeTransition`,
  /// `SlideTransition` and `FractionalTranslation` are all still built. The
  /// cheaper `return child` also satisfies §14's end state and is one line
  /// shorter; it is rejected because a transitions builder's job is to *wrap* the
  /// page, and dropping the widgets changes the route's subtree for a reader who
  /// did not ask for reduced motion at all — they simply asked for less of it.
  static Widget fadeSlide(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> progress = MediaQuery.disableAnimationsOf(context)
        ? kAlwaysCompleteAnimation
        : animation;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return FadeTransition(
          opacity: progress.drive(CurveTween(curve: screenCurve)),
          child: SlideTransition(
            position: progress.drive(
              Tween<Offset>(
                begin: screenSlideBeginFor(constraints.maxHeight),
                end: Offset.zero,
              ).chain(CurveTween(curve: screenCurve)),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // --- Per-orb spread ------------------------------------------------------

  /// The float duration of the [index]-th of [count] orbs.
  ///
  /// SPREAD ACROSS THE SPEC RANGE, ENDPOINTS INCLUDED. §5.3 gives `14–28s per
  /// orb` and nothing else, so this is the one place a formula had to be chosen:
  /// the even spread, so orb 0 runs [orbFloatMin] and orb `count - 1` runs
  /// [orbFloatMax]. The alternative — one duration for every orb — is precisely
  /// the lockstep pulse `09-quality-gates.md` §13 mitigation 2 forbids, and a
  /// random spread is untestable, which is the other half of why this is even.
  ///
  /// Phase 2 derives the *phase* offset the same way (`index / count`); only the
  /// duration lives here.
  static Duration orbFloatFor(int index, int count) =>
      _spread(index, count, orbFloatMin, orbFloatMax);

  /// The hue-rotation duration of the [index]-th of [count] orbs. The even
  /// spread of §5.3's `7–14s per orb` range; see [orbFloatFor].
  static Duration orbHueFor(int index, int count) =>
      _spread(index, count, orbHueMin, orbHueMax);

  /// Even spread of `[min, max]` across `count` slots, `min` at index 0 and
  /// `max` at `count - 1`.
  ///
  /// A single orb collapses to [min] rather than dividing by `count - 1 == 0`.
  /// One orb is a real configuration: `NeuralTier` drops to `low` with no orbs
  /// at all, and a narrow window can leave exactly one.
  static Duration _spread(int index, int count, Duration min, Duration max) {
    assert(count > 0, 'orb count must be positive, got $count');
    if (count == 1) return min;
    final int micros =
        min.inMicroseconds +
        (max.inMicroseconds - min.inMicroseconds) * index ~/ (count - 1);
    return Duration(microseconds: micros);
  }
}

/// `.cta.err`'s and `.opt.wrong`'s shake (`eva/redesign.html:360`), as a curve.
///
/// ```css
/// @keyframes shake{20%{transform:translateX(-8px)}40%{transform:translateX(8px)}
///                  60%{transform:translateX(-5px)}80%{transform:translateX(5px)}}
/// ```
///
/// Piecewise-linear between the keyframes. CSS interpolates keyframes with
/// `ease` by default, which on a ±8px pulse is indistinguishable from linear at
/// any speed a shake is visible at; recorded rather than re-derived, because a
/// cubic-bezier fit to four waypoints would be a second curve token for a
/// 450 ms effect. The amplitude is **not** scaled to the element's width — the
/// prototype shakes a full-width button by fixed pixels too.
///
/// ## WHY IT LIVES HERE AND NOT IN ITS FIRST CALLER
///
/// The curve was private to `/login`'s form for its whole first life, and the
/// quiz's `.opt.wrong` shake (`:360`'s other user — same keyframes, same `.45s`)
/// would have been the second copy of it. A shake that two screens share is
/// motion the design system owns, which is where every other curve already
/// lives. Promoted rather than duplicated, and `/login` reads it from here.
final class EvaShake extends Curve {
  /// `eva/redesign.html:360` — `.45s`.
  static const Duration duration = Duration(milliseconds: 450);

  /// Creates the curve.
  const EvaShake();

  @override
  double transform(double t) {
    // Waypoints from `:360`, linearly between. `t == 1` (the clock's end) is
    // the rest position, so the element always lands where it started.
    const List<(double, double)> keys = <(double, double)>[
      (0.0, 0),
      (0.2, -8),
      (0.4, 8),
      (0.6, -5),
      (0.8, 5),
      (1.0, 0),
    ];
    for (int i = 0; i < keys.length - 1; i++) {
      final (double t0, double x0) = keys[i];
      final (double t1, double x1) = keys[i + 1];
      if (t <= t1) {
        final double f = (t - t0) / (t1 - t0);
        return x0 + (x1 - x0) * f;
      }
    }
    return 0;
  }
}
