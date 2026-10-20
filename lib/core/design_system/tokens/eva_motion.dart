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

  // --- The redesign's bottom dock --------------------------------------------
  //
  // The prototype's dock (`eva/redesign.html:208-234`) declares four timings of
  // its own and none of them is a §5.3 value, so they are added here rather than
  // written as literals at the call site. [EvaShake] is the precedent: a number
  // that belongs to one surface and is stated by the prototype belongs in the
  // motion table, not in the widget that spends it.

  /// `450ms` — the dock's beam growing out of the top edge.
  ///
  /// `eva/redesign.html:221` — `.beam{… transition:height .45s var(--e-light),
  /// opacity .3s}`. The **height** half; the opacity half is [dockFade], and the
  /// two are separate declarations of one transition list, which is why they are
  /// two tokens rather than one.
  static const Duration dockBeam = Duration(milliseconds: 450);

  /// `300ms` — the dock's beam fading in.
  ///
  /// `eva/redesign.html:222` — the `opacity .3s` half of the same transition
  /// list [dockBeam] names. The beam is `opacity:0` until its slot is active
  /// (`:221`), so this is the number the fade takes.
  static const Duration dockFade = Duration(milliseconds: 300);

  /// `250ms` — the dock's slot ink changing colour.
  ///
  /// `eva/redesign.html:217` — `.dtab{… transition:color .25s}`. **Not**
  /// [screen], which holds the same 250ms: that token is named for a screen-level
  /// transition, and spending it on a slot's ink would make the name a second
  /// answer to a question this token answers exactly.
  static const Duration dockInk = Duration(milliseconds: 250);

  /// `2600ms` — the dock's orb ripple.
  ///
  /// `eva/redesign.html:230` — `.orbmini::after{… animation:ripple 2.6s
  /// var(--e-out) infinite}`. The one **infinite** animation in the dock, and
  /// therefore the one that has to read a clock rather than own a controller —
  /// see `LumenOrb`'s doc.
  static const Duration dockRipple = Duration(milliseconds: 2600);

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

  /// `cubic-bezier(0,0,.2,1)` — the prototype's `--e-out`.
  ///
  /// `eva/redesign.html:18` declares it in `:root` as `--e-out`, and the dock's
  /// orb ripple is the one place this client spends it (`:230`).
  ///
  /// **Transcribed rather than approximated.** [interactiveCurve] is the app's
  /// `--e-light` stand-in and is deliberately *not* this curve; this one is the
  /// prototype's own bezier, read off the declaration, and there is no
  /// approximation to record because there is nothing to approximate — the
  /// value is a literal in the stylesheet.
  static const Curve dockRippleCurve = Cubic(0, 0, 0.2, 1);

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
  /// ## THE 2.53% IS MEASURED **THE WAY A BROWSER MEASURES IT**, AND THE
  /// ## METHOD IS PART OF THE NUMBER
  ///
  /// **2.53% is the distance between the two *beziers*, evaluated the way CSS
  /// evaluates a `cubic-bezier()`** — the polynomial approximation in CSS
  /// Timing Functions Level 1. That is the method a browser uses, so it is the
  /// method that describes the difference between the two *designs*.
  ///
  /// **Flutter's own evaluation of the same pair measures 3.08%**, because
  /// `Cubic.transformInternal` finds its parametric `t` by bisection to a
  /// tolerance and the samples it returns are quantised. The quantisation is
  /// visible in the numbers, and it is largest exactly where the curve is
  /// steepest — which is where the two curves differ most.
  ///
  /// Both figures are re-derived, with the method stated, by
  /// `test/core/design_system/tokens/eva_motion_test.dart`. A recorded
  /// measurement whose *method* is not stated is a number nobody can check,
  /// and this one had not been checked: the first attempt at that test
  /// compared the two curves with Flutter's evaluator, read **3.08%**, and
  /// looked like a contradiction until the method was pinned down.
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
  /// ## THIS BUILDER IS **RETAINED DELIBERATELY** AND WILL BE REMOVED
  ///
  /// The redesign's route transition is [goneSlide], and this one is the design
  /// `docs/plans/03-design-system.md` §5.3 describes — the *old* design's fade
  /// and 8px slide. It is **kept** while the router is rewired, because
  /// `AppRouter.defaultRouteType` still installs it and deleting it before that
  /// rewiring lands would break the build for a change that is not this file's
  /// to make. It will be deleted in the same change that installs [goneSlide]
  /// app-wide; until then its presence here is intentional and its doc says so.
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

  // --- The redesign's route transition -------------------------------------
  //
  // ## WHAT THE PROTOTYPE DECLARES
  //
  // `eva/redesign.html:128-133` is one transition and four poses:
  //
  // ```css
  // .route{…transition:transform .4s var(--e-light),opacity .4s var(--e-light)}
  // .route.gone-left{transform:translateX(-28%) scale(.96);opacity:0;pointer-events:none}
  // .route.gone-right{transform:translateX(38%) scale(.98);opacity:0;pointer-events:none}
  // .route.tab-pre{opacity:0;transform:translateY(10px) scale(.985)}
  // .route.tab-out{opacity:0;transform:translateY(-6px) scale(.99);pointer-events:none}
  // ```
  //
  // One transition — **400ms** on `--e-light` — and four poses, in two pairs: the
  // **route** pair (`gone-left` / `gone-right`) and the **tab** pair
  // (`tab-pre` / `tab-out`).
  //
  // ## THE TWO PAIRS ARE NOT THE SAME KIND OF THING, AND THE UNITS PROVE IT
  //
  // The route pair moves a route **across the screen**: `gone-left` is
  // `translateX(-28%)` and `gone-right` is `translateX(38%)`, both **fractions
  // of the route's own width**, because the route fills the viewport and a
  // percentage of it is a percentage of the screen.
  //
  // The tab pair moves a tab **a few pixels**: `tab-pre` is `translateY(10px)`
  // and `tab-out` is `translateY(-6px)`, both **absolute pixels**, because a tab
  // is a small offset from where it lands, not a displacement across the
  // screen. A tab that slid 38% of the screen would be a route.
  //
  // So the two pairs are transcribed in two different units, and a builder that
  // used one for the other would be wrong by an order of magnitude.
  //
  // ## WHY THE TOKEN NAMES ARE THE PROTOTYPE'S CLASS NAMES
  //
  // `goneRightFraction`, `goneLeftScale`, `tabPreOffset` and the rest are
  // named after the CSS class that states the number, so the citation is in the
  // identifier and a reader can go and look at the rule without a second
  // lookup. The alternative — `routeEnterOffset` — describes the *role* the
  // pose plays in this client, which is a thing this client decided and not a
  // thing the prototype says.

  /// `400ms` — the redesign's route transition.
  ///
  /// `eva/redesign.html:128` —
  /// `.route{…transition:transform .4s var(--e-light),opacity .4s var(--e-light)}`.
  ///
  /// **This is the prototype's number and not this repository's [screen]
  /// token.** [screen] is 250ms and comes from `docs/plans/03-design-system.md`
  /// §5.3, which describes the *previous* design; the redesign's own route
  /// transition is 400ms, and the redesign is the design this client is being
  /// rebuilt against. So the two numbers coexist deliberately, and the new one
  /// is named for the thing it is: [routeTransition] is the route transition,
  /// [screen] is §5.3's screen transition.
  ///
  /// The same 400ms is the budget the achievement spring was measured against
  /// — "its measured settle (~344ms) sits under the 400ms a complex transition
  /// is allowed" ([achievementDuration]) — so the number appears twice in this
  /// file for two unrelated reasons, which is why the two are not conflated.
  static const Duration routeTransition = Duration(milliseconds: 400);

  /// `38%` of the route's width — the `gone-right` pose's horizontal offset.
  ///
  /// `eva/redesign.html:130` —
  /// `.route.gone-right{transform:translateX(38%) scale(.98);opacity:0;…}`.
  ///
  /// **A fraction of the route's WIDTH**, not of the child's own size and not a
  /// pixel count. CSS's `translateX(38%)` is a percentage of the element's own
  /// border-box width, and the element is the route — which fills the viewport.
  /// [goneSlide] therefore reads this as a fraction of `constraints.maxWidth`
  /// rather than of the child, so a page that does not fill its route still
  /// travels the prototype's distance.
  ///
  /// **It is positive.** `gone-right` is the pose a route takes when it is
  /// leaving to the **right**, so its offset is to the right of the origin —
  /// and it doubles as the pose a route *arrives* from, which is what makes one
  /// reversible builder able to serve both the push and the pop.
  static const double goneRightFraction = 0.38;

  /// `-28%` of the route's width — the `gone-left` pose's horizontal offset.
  ///
  /// `eva/redesign.html:129` —
  /// `.route.gone-left{transform:translateX(-28%) scale(.96);opacity:0;…}`.
  ///
  /// A fraction of the route's width, for the same reason as
  /// [goneRightFraction], and **negative**: `gone-left` is the pose a route
  /// takes when it is leaving to the **left**, and it is the pose the route
  /// underneath a push ends in (`eva/redesign.html:1256` adds `gone-left` to
  /// the route being covered).
  static const double goneLeftFraction = -0.28;

  /// `0.98` — the `gone-right` pose's scale.
  ///
  /// `eva/redesign.html:130` — `.route.gone-right{…scale(.98)…}`.
  ///
  /// A **uniform** scale, applied about the route's **centre** — CSS's default
  /// `transform-origin: 50% 50%`, which is what `Transform.scale`'s default
  /// `Alignment.center` reproduces. Scaling about the centre and scaling about
  /// the top-left corner are different pictures, and the centre is the one the
  /// prototype draws.
  static const double goneRightScale = 0.98;

  /// `0.96` — the `gone-left` pose's scale.
  ///
  /// `eva/redesign.html:129` — `.route.gone-left{…scale(.96)…}`.
  ///
  /// A uniform scale about the route's centre, for the same reason as
  /// [goneRightScale].
  static const double goneLeftScale = 0.96;

  /// `10px` — the incoming tab's vertical offset.
  ///
  /// `eva/redesign.html:132` — `.route.tab-pre{opacity:0;transform:translateY(10px) scale(.985)}`.
  ///
  /// **Pixels, not a fraction** — the tab pair's unit, for the reason the
  /// section header above gives. The incoming tab *rises* 10px into place, so
  /// the offset is positive and it shrinks to zero as the tab settles.
  static const double tabPreOffset = 10;

  /// `0.985` — the incoming tab's scale.
  ///
  /// `eva/redesign.html:132` — `.route.tab-pre{…scale(.985)…}`.
  ///
  /// A uniform scale about the tab's centre. It is a much smaller step than the
  /// route pair's (`0.98` / `0.96`), because a tab is a small element: 1.5% of
  /// a phone's width is a couple of pixels, while 2% of a route's width is a
  /// visible shift.
  static const double tabPreScale = 0.985;

  /// The redesign's route transition: the route arrives from the right and the
  /// route it covers leaves to the left.
  ///
  /// ```dart
  /// static Widget goneSlide(
  ///   BuildContext context,
  ///   Animation<double> animation,
  ///   Animation<double> secondaryAnimation,
  ///   Widget child,
  /// )
  /// ```
  ///
  /// This is a `RouteTransitionsBuilder` — the signature auto_route's
  /// `RouteType.custom(transitionsBuilder:)` expects, and the same one
  /// [fadeSlide] has, so the two are interchangeable at the call site.
  ///
  /// ## ONE REVERSIBLE BUILDER, TWO DIRECTIONS, BECAUSE THE PROTOTYPE HAS TWO
  /// ## POSES AND USES THEM IN OPPOSITE DIRECTIONS
  ///
  /// The prototype's route transition is a **CSS transition between two
  /// states**, and the two states are named: `gone-left` (`:129`) and
  /// `gone-right` (`:130`). Every route motion in the prototype is one of those
  /// two states being entered or left:
  ///
  /// | prototype | what it does | this builder |
  /// | --- | --- | --- |
  /// | `push` (`:1256`) | the covered route gets `gone-left` | the route below moves to the `gone-left` pose |
  /// | `pop` (`:1261`) | the top route gets `gone-right` | the top route moves back to the `gone-right` pose |
  /// | `pop` (`:1262`) | the revealed route loses `gone-left` | the route below moves back to rest |
  ///
  /// So the two poses serve as the **enter** pose and the **exit** pose:
  ///
  /// * the **enter pose** is `gone-right` — `translateX(+38%) scale(.98)`, the
  ///   route's own `animation` runs `0 → 1` and carries it from there to rest;
  /// * the **exit pose** is `gone-left` — `translateX(-28%) scale(.96)`, the
  ///   route's own `secondaryAnimation` runs `0 → 1` and carries it from rest
  ///   to there.
  ///
  /// ## THE TWO ANIMATIONS, AND WHAT EACH ONE MEANS
  ///
  /// Flutter's own documentation of `ModalRoute.buildTransitions`
  /// (`routes.dart:1581-1584`) is the authority for the semantics, and it is
  /// quoted rather than paraphrased:
  ///
  /// > * `animation`: When the [Navigator] pushes a route on the top of its
  /// >   stack, the new route's primary [animation] runs from 0.0 to 1.0. When
  /// >   the [Navigator] pops the topmost route this animation runs from 1.0 to
  /// >   0.0.
  /// > * `secondaryAnimation`: When the Navigator pushes a new route on the top
  /// >   of its stack, the old topmost route's [secondaryAnimation] runs from
  /// >   0.0 to 1.0. When the Navigator pops the topmost route, the
  /// >   [secondaryAnimation] for the route below it runs from 1.0 to 0.0.
  ///
  /// So, for **this** route:
  ///
  /// | | `animation` | `secondaryAnimation` |
  /// | --- | --- | --- |
  /// | while this route is pushed | `0 → 1` | `0` (nothing above it) |
  /// | while this route is covered | `1` | `0 → 1` |
  /// | while this route is popped | `1 → 0` | `0` |
  /// | while this route is revealed | `1` | `1 → 0` |
  ///
  /// **The exit progress is `secondaryAnimation` itself and NOT
  /// `ReverseAnimation(secondaryAnimation)`.** The framework's own worked
  /// example (`routes.dart:1546-1570`) drives the route below's exit with
  /// `Tween(begin: Offset.zero, end: Offset(0, 1)).animate(secondaryAnimation)`
  /// — the secondary animation **unreversed**. The *reversed* secondary
  /// animation is the **reveal** progress (0 while covered, 1 while fully
  /// revealed), and it is the reveal that runs back to 0 on the pop (`:1262`
  /// removing `gone-left`). Getting this backwards is the one way to write
  /// this builder so that the route below slides *in* as it is covered.
  ///
  /// ## TWO TRANSLATIONS AND TWO SCALES, COMPOSED INTO **ONE** TRANSFORM
  ///
  /// The enter pose and the exit pose each want a translation and a scale, and
  /// they cannot be two widgets: two `SlideTransition`s each write their own
  /// transform and the last one wins, and two `Transform.scale`s do the same.
  /// So the four numbers are composed by hand into a single matrix, and the
  /// composition is the CSS one:
  ///
  /// * the **translation** is `width × (goneRightFraction × (1 - enter) +
  ///   goneLeftFraction × covered)` — a fraction of the **route's width**,
  ///   which is why it is read from `constraints.maxWidth` and not from the
  ///   child's size;
  /// * the **scale** is `lerp(goneRightScale, 1, enter) × lerp(1, goneLeftScale,
  ///   covered)` — the two factors are multiplied, and in the three states that
  ///   actually occur they never compound: a route is either entering or
  ///   covered, never both, so the product is `0.98`, `1.0` or `0.96` and
  ///   never `0.9408`;
  /// * the **opacity** is `min(enter, 1 - covered)` — 1 at rest and 0 at both
  ///   extremes, which is the prototype's `opacity:0` on both poses.
  ///
  /// The transform is applied as `Transform.translate` **outside**
  /// `Transform.scale`, because CSS composes `transform:translateX(…) scale(…)`
  /// left to right — the translation is applied last — and `Transform.scale`'s
  /// default `Alignment.center` reproduces CSS's default
  /// `transform-origin: 50% 50%`.
  ///
  /// ## THE CURVE IS `--e-light`, AND `--e-light` IS [interactiveCurve]
  ///
  /// `:128` puts `var(--e-light)` on both the transform and the opacity, and
  /// `:18` declares `--e-light:cubic-bezier(.16,1,.3,1)`. The repository's
  /// [interactiveCurve] is `Curves.easeOutExpo`, which is `Cubic(0.19, 1,
  /// 0.22, 1)` — **an approximation of that bezier, not the same curve**, and
  /// [interactiveCurve]'s own doc records the measured distance: at most
  /// **2.53%** of the progress, worst at x ≈ 0.054 — measured the way CSS
  /// evaluates a `cubic-bezier()`, and re-derived with that method stated in
  /// `test/core/design_system/tokens/eva_motion_test.dart`. A route transition
  /// is 400ms long and moves a whole screen, so 2.53% of the progress is
  /// about 10ms of difference at the steepest point — which is why the
  /// approximation is reused here instead of a second curve token, and why the
  /// exact curve is transcribed only where the exactness is the point (the
  /// journey's rings, `journey_rings_row.dart:231`).
  ///
  /// A custom transitions builder gets the **raw** animation: `PageRoute`'s own
  /// `curve` is `Curves.linear` and only `MaterialPageRoute`'s builder curves
  /// it, so a builder that used the animation raw would animate linearly and
  /// ignore `--e-light` entirely. That is why the curve is applied here, in
  /// this file, rather than left to the router.
  ///
  /// ## AND "JUMP TO THE END STATE" IS A SUBSTITUTED ANIMATION, NOT A DROPPED TREE
  ///
  /// §14's row is "every animation checks `MediaQuery.disableAnimationsOf(context)`;
  /// when disabled, jump straight to the end state", and the way to reach the
  /// end state is to **substitute** the animation, exactly as [fadeSlide] does:
  /// [kAlwaysCompleteAnimation] replaces the enter animation and
  /// [kAlwaysDismissedAnimation] replaces the covered one, so the route sits
  /// at rest and fully opaque while every widget is still built. `return child`
  /// would also satisfy §14 and is one line shorter; it is rejected for the
  /// reason [fadeSlide]'s doc gives — a transitions builder's job is to *wrap*
  /// the page, and dropping the widgets changes the route's subtree for a
  /// reader who asked for less motion, not for no widget.
  static Widget goneSlide(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // The end state is **at rest**, and at rest means *both* progresses are at
    // their resting values: the route has finished entering (`animation == 1`)
    // and it is not covered (`secondaryAnimation == 0`). So the substitution is
    // two constants and not one — `kAlwaysCompleteAnimation` for the enter
    // progress and `kAlwaysDismissedAnimation` for the covered one, which is
    // the framework's own name for "not dismissed" and the value a route with
    // nothing above it carries.
    //
    // Substituting `kAlwaysCompleteAnimation` for **both** would put the route
    // in the `gone-left` exit pose — the opposite of at rest — and the
    // reduced-motion path would then show a reader a page sliding off the
    // screen, which is the one thing §14 asks it not to do.
    final Animation<double> enter = reduced
        ? kAlwaysCompleteAnimation
        : animation;
    final Animation<double> covered = reduced
        ? kAlwaysDismissedAnimation
        : secondaryAnimation;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return AnimatedBuilder(
          // **Both** animations, because the two poses are driven by different
          // ones and a route that is *covered* does not tick its own
          // `animation` — it is already at 1. Listening to one of the two
          // would freeze the route below at rest while the route above slides
          // over it.
          animation: Listenable.merge(<Listenable>[enter, covered]),
          child: child,
          builder: (BuildContext context, Widget? page) {
            final double enterT = interactiveCurve.transform(enter.value);
            final double coveredT = interactiveCurve.transform(covered.value);
            final double dx =
                constraints.maxWidth *
                (goneRightFraction * (1 - enterT) +
                    goneLeftFraction * coveredT);
            final double scale =
                _lerp(goneRightScale, 1, enterT) *
                _lerp(1, goneLeftScale, coveredT);
            final double opacity = math.min(enterT, 1 - coveredT);
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(scale: scale, child: page),
              ),
            );
          },
        );
      },
    );
  }

  /// `6px` — the outgoing tab's vertical offset.
  ///
  /// `eva/redesign.html:133` — `.route.tab-out{opacity:0;transform:translateY(-6px) scale(.99);pointer-events:none}`.
  ///
  /// **Recorded, and deliberately NOT used by the shipped builder.** The
  /// prototype's outgoing tab *rises* 6px as it leaves — a smaller step than
  /// the incoming tab's 10px, in the opposite direction — and auto_route's
  /// `AutoTabsRouter` cannot show it: its `transitionBuilder` hook wraps the
  /// whole `IndexedStack`, and the `IndexedStack` paints only the active tab.
  /// The number is here so the divergence has a value and so the CSS check in
  /// `test/core/design_system/tokens/eva_motion_test.dart` has something to
  /// compare the prototype against.
  static const double tabOutOffset = 6;

  /// `0.99` — the outgoing tab's scale.
  ///
  /// `eva/redesign.html:133` — `.route.tab-out{…scale(.99)…}`.
  ///
  /// **Recorded, and deliberately NOT used by the shipped builder**, for the
  /// same reason as [tabOutOffset].
  static const double tabOutScale = 0.99;

  /// `400ms` — the redesign's tab swap.
  ///
  /// ## WHY IT IS 400ms AND NOT THE 260ms AT `:1266`
  ///
  /// The prototype's `tab()` writes two different numbers, and they are not the
  /// same thing:
  ///
  /// * `:1266` — `setTimeout(()=>{f.classList.add('hidden');f.classList.remove('tab-out');},260)`
  ///   is a **cleanup timer**. 260ms after the swap starts, the *outgoing* tab
  ///   is hidden and its `tab-out` class is removed. It is how long the
  ///   prototype waits before it stops drawing the outgoing tab — a DOM
  ///   housekeeping detail this client has no use for, because auto_route's
  ///   `IndexedStack` keeps the outgoing tab alive and simply stops painting it.
  /// * `:128` — `.route`'s own `transition:transform .4s …` is what actually
  ///   *moves* the incoming tab off its `tab-pre` pose, and it is 400ms.
  ///
  /// The visible motion is the second one, so the token is 400ms. The 260ms is
  /// recorded here because a reader who finds it in the prototype and looks for
  /// it in this file must find the reason it is absent.
  ///
  /// ## IT IS THE ROUTER'S DURATION, NOT THE BUILDER'S
  ///
  /// A transitions builder cannot choose how long it runs. `AutoTabsRouter`
  /// owns the controller (`auto_tabs_router.dart:249` — `duration`, default
  /// 300ms) and hands the builder an `Animation` already running on it. So
  /// this token is what the **caller** must pass:
  ///
  /// ```dart
  /// AutoTabsRouter(
  ///   duration: EvaMotion.tabTransition,
  ///   transitionBuilder: EvaMotion.tabSwap,
  /// )
  /// ```
  static const Duration tabTransition = Duration(milliseconds: 400);

  /// The redesign's tab swap: the incoming tab rises 10px into place while it
  /// fades in.
  ///
  /// ```dart
  /// static Widget tabSwap(
  ///   BuildContext context,
  ///   Widget child,
  ///   Animation<double> animation,
  /// )
  /// ```
  ///
  /// This is auto_route's `AutoTabsRouter.transitionBuilder` shape
  /// (`auto_tabs_router.dart:18` — `AnimatedIndexedStackTransitionBuilder`),
  /// **not** the `RouteTransitionsBuilder` shape [goneSlide] has. The two are
  /// different hooks with different argument orders, and a builder written for
  /// one cannot be handed to the other.
  ///
  /// ## THE INCOMING TAB IS REPRODUCED EXACTLY
  ///
  /// `eva/redesign.html:132` — `.route.tab-pre{opacity:0;transform:translateY(10px) scale(.985)}`
  /// — is the pose the incoming tab starts in, and the tab's own
  /// `transition:transform .4s var(--e-light),opacity .4s var(--e-light)`
  /// (`:128`) is what carries it to rest. So: `translateY(10px) scale(.985)` at
  /// `animation == 0`, at rest at `animation == 1`, with the opacity running
  /// `0 → 1` on the same curve.
  ///
  /// **The offset is in pixels and the scale is about the centre**, for the
  /// reasons the section header above gives: `translateY(10px)` is an absolute
  /// length, not a percentage, and CSS's default `transform-origin: 50% 50%`
  /// is what `Transform.scale`'s default `Alignment.center` reproduces.
  ///
  /// ## THE OUTGOING TAB IS **NOT** REPRODUCIBLE, AND THIS IS THE RECORD OF WHY
  ///
  /// `eva/redesign.html:133` — `.route.tab-out{opacity:0;transform:translateY(-6px) scale(.99);pointer-events:none}`
  /// — is the pose the *outgoing* tab leaves in, and it is **not observable**
  /// in auto_route's model. Two reasons, both mechanical:
  ///
  /// 1. `AutoTabsRouter` builds an `IndexedStack`, and an `IndexedStack` paints
  ///    **only the active child**. The outgoing tab is not on screen while the
  ///    swap runs, so there is nothing to give a pose to.
  /// 2. The `transitionBuilder` hook wraps the **whole stack** — one child, one
  ///    animation — not one tab. So even a builder that wanted to pose the
  ///    outgoing tab separately has nothing to address it with.
  ///
  /// The prototype can, because it keeps every route in the DOM at once
  /// (`position:absolute;inset:0` — `:128`) and adds a class to each. The
  /// `IndexedStack` cannot, because it paints one child.
  ///
  /// **What the prototype's outgoing tab does, then, is: nothing visible.** The
  /// incoming tab's rise and fade-in is the whole of the visible tab transition
  /// in this model, and it is reproduced exactly. The `tab-out` numbers are
  /// recorded as [tabOutOffset] and [tabOutScale] so the divergence has
  /// values, and the test suite asserts that the shipped builder never applies
  /// them — the prototype's outgoing tab *rises* 6px, and this builder's offset
  /// is never negative.
  static Widget tabSwap(
    BuildContext context,
    Widget child,
    Animation<double> animation,
  ) {
    final Animation<double> progress = MediaQuery.disableAnimationsOf(context)
        ? kAlwaysCompleteAnimation
        : animation;

    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (BuildContext context, Widget? page) {
        final double t = interactiveCurve.transform(progress.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, tabPreOffset * (1 - t)),
            child: Transform.scale(
              scale: _lerp(tabPreScale, 1, t),
              child: page,
            ),
          ),
        );
      },
    );
  }

  /// Linear interpolation between [a] and [b] at [t].
  ///
  /// `lerpDouble` lives in `dart:ui` and is **not** re-exported by
  /// `package:flutter/widgets.dart` (`painting/basic_types.dart`'s `dart:ui`
  /// export list does not carry it), so this file would have to import
  /// `dart:ui` for one call. The arithmetic is one line.
  ///
  /// **Written `a * (1 - t) + b * t` and not `a + (b - a) * t`**, because the
  /// first form is **exact at both endpoints**: at `t == 1` it is `b` and at
  /// `t == 0` it is `a`, bit for bit, while the second form returns
  /// `a + (b - a)`, which is a rounding away from `b` for most pairs — and
  /// "at rest" has to be *exactly* rest, because that is the state the
  /// reduced-motion path substitutes.
  static double _lerp(double a, double b, double t) => a * (1 - t) + b * t;

  // --- Per-orb spread ------------------------------------------------------
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
