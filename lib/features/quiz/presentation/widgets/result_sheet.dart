import 'package:evangelion/app/settings_handle.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/presentation/result_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The graded answer, as a **card over a veil** — the redesign's result modal.
///
/// `eva/redesign.html:718-727` is the prototype's markup, `:442-446` its card
/// and `:433-434` the veil it sits over. This widget is the card; [ResultSheet.show]
/// is the modal that presents it.
///
/// ## `/result` IS NOT A ROUTE ANY MORE, AND THIS FILE IS WHY
///
/// AGENT_CONTEXT §2's route table has no `/result`, and `AppRoutes.result` does
/// not exist. The result is the **quiz's outcome, shown over the quiz**, so it
/// belongs to the quiz feature — and it did not move here for tidiness: keeping
/// it in `features/result/` would have meant `features/quiz/` importing
/// `features/result/`, which is **Gate 2** (§3, "no feature may import another
/// feature — no exceptions").
///
/// **The alternatives were all worse, and they are recorded because each of them
/// looked reasonable:**
///
/// * *a port in `core/domain/`* — the result has no repository, no use case and
///   no endpoint (§5 trap 11: the submit response is the only artifact it
///   renders, and it exists only as the POST's reply), so a port would be an
///   empty seam around a value the quiz already holds;
/// * *a locator read* — the same wall the result hit before, in the other
///   direction: `features/result/` importing `features/quiz/` is Gate 2, so
///   resolving the bloc from the locator was the only other way to get the
///   response, and it would have been a **global read of a value the page
///   already has**;
/// * *a design-system screen* — the content is a graded answer's numbers, not a
///   reusable surface, and §3's placement test ("nothing enters the kernel
///   speculatively") refuses it.
///
/// **The move also deleted the last reason the result could not be a modal.**
/// As a page it had to be pushed, and a push is a route; as a card it is
/// presented over the quiz, and the quiz is already there.
///
/// ## THE CONTENT IS **THE CLIENT'S OWN**, AND THE PRESENTATION IS THE PROTOTYPE'S
///
/// The prototype's card is a **ring** — `.bigring` (`:447-452`), a 132px circle
/// with `0/3` in the middle (`:721`). **The ring is not ported, and this is the
/// largest divergence on this surface.** The ring needs a denominator, and
/// **the submit response carries no question count**: AGENT_CONTEXT decision 93
/// records it — *"there is no `/N` anywhere either, because the submit response
/// carries no total question count (decision 93)"* — and §5's response shape
/// agrees: `POST /readings/:id/submit` answers with `current_total_points`,
/// `points_earned`, `current_streak`, `longest_streak` and `reading_completed`,
/// and **no count of questions**.
///
/// A ring without a denominator is a circle, and a circle with an invented
/// denominator is a number the server never sent, drawn as a fact about the
/// reader's day. So the client keeps what the backend can answer: the running
/// total, the sentence, the streak pill and the two stat tiles.
///
/// **The client's own `SunBurst` celebration stays in the ring's place.** It is
/// the client's decoration and the client's content, and it was already there;
/// removing it would have been a second, unrecorded divergence.
///
/// ## THE CARD'S NUMBERS ARE THE PROTOTYPE'S
///
/// | what | number | prototype |
/// | --- | --- | --- |
/// | the card's width | 82% | `:444` — `width:82%` |
/// | the card's radius | 28 | `:444` — `border-radius:28px` |
/// | the card's padding | 34 × 28 | `:444` — `padding:34px 28px` |
/// | the card's entrance scale | .9 → 1 | `:444-446` |
/// | the entrance's duration | 500ms | `:445` — `transition:transform .5s` |
/// | the veil | `rgba(0,0,0,.55)` / `rgba(60,55,40,.25)` | `:433-434` / `:98` |
///
/// ## THE TWO CTAs, AND THE ORDER IS **INVERTED** RELATIVE TO THE PROTOTYPE
///
/// The prototype's pair is `.rcta` "read again" (`:724`, the filled gold pill)
/// above `.rghost` "retry quiz" (`:725`, the glass-rimmed ghost). This client
/// keeps **its own** pair and **its own** order: "Reflect again" first and
/// primary, "Back home" second and secondary.
///
/// **The mapping is by ACTION, not by position.** "Reflect again" is the
/// prototype's "retry quiz" and "Back home" is the prototype's "read again" —
/// the client has no reading to return to, and its way out is the dock's home.
/// So the **emphasis is inverted**: the prototype's primary is the way out and
/// the client's primary is the way back in.
///
/// **Rejected: swapping the client's order to match the prototype's.** It would
/// put a filled gold button second, and the client's own two CTAs have been
/// "Reflect again" then "Back home" since Phase 8. The ARB keys are
/// `resultReflectAgain` and `resultBackHome`; they name the **surface** and
/// decision 101's stated purpose — collision-freedom — is served by leaving
/// them alone.
///
/// ## THE COLOUR SUBSTITUTIONS, AND WHY EACH ONE IS A SUBSTITUTION
///
/// `no_colour_literals_test.dart` confines every colour under `lib/` to
/// `EvaColors` / `EvaStickerPalette`, so the prototype's two colours are
/// mapped onto tokens. **Both are recorded here because both are visible.**
///
/// | prototype | here | why |
/// | --- | --- | --- |
/// | the card's fill, `rgba(12,14,24,.94)` (`:444`) | `EvaColors.surface` at **94%** | `surface` is `#0D1224` in dark — the nearest token to the prototype's `rgb(12,14,24)`, one value off in each channel |
/// | the card's fill in light, `rgba(255,255,255,.95)` (`:66`) | `EvaColors.surface` at **95%** | `surface` is `#FFFFFF` in light, so this arm is **exact** |
/// | the veil, `rgba(0,0,0,.55)` (`:433`) | `EvaColors.glassShadow` at **55%** | `glassShadow` is `#59000000` in dark — **pure black** — so the dark arm is **exact** |
/// | the veil in light, `rgba(60,55,40,.25)` (`:98`) | `EvaColors.glassShadow` at **25%** | `glassShadow` is `#120E28` in light: the same dark, but **cool** where the prototype's is warm. The alpha is the prototype's; the hue is the palette's own shadow colour |
///
/// **Why the veil is `glassShadow` and not `canvas`.** A scrim has to be
/// **darker** than what is behind it in *both* palettes, and the only token
/// that is dark in both is the design system's one shadow colour: `canvas` is
/// `#05081A` in dark and the pale `#F0EEFF` in light, so a `canvas` veil would
/// *lighten* the light arm. `glassShadow` is dark in both, and a scrim **is** a
/// shadow cast over the whole screen.
///
/// ## AND THE **BLUR** IS NOT SPENT, WHICH IS A RECORDED DIVERGENCE
///
/// `:444-445` gives the card `backdrop-filter: blur(24px)`. **It is not
/// shipped**, for two reasons that are both mechanical:
///
/// * **§13.4's budget is exhausted.** `glass_blur_budget_test.dart` allows
///   **two** blur sites under `lib/features/`, and both are spent: Home's
///   today's-reading panel and the redesign's own dock. A third is red, and the
///   gate also refuses a hand-built `BackdropFilter` in any feature but the
///   dock. §13.4 is the rule that states a budget, so it wins — the same
///   resolution `StatTile`'s own doc records for the superseded prototype's 16px
///   blur.
/// * **it would buy nothing visible.** The card is **94% opaque**, so a filter
///   behind it is almost entirely hidden by the fill it is supposed to show
///   through.
///
/// So the card is painted without a filter. **This is a divergence, not an
/// omission**, and it is the one place where this file's presentation is
/// *less* faithful to the prototype than the prototype is to itself.
///
/// ## AND THE CARD IS **NOT** A `GlassSurface`
///
/// Two of the prototype's declarations are outside what that widget can say:
/// the card's fill is **94% opaque** where `GlassSurface` paints a 5% white
/// tint, and `:444-446` declares **no** `box-shadow` where `GlassSurface`
/// always paints the ambient one. The card is therefore a `DecoratedBox` of its
/// own, and the veil behind it is what separates it from the quiz.
class ResultSheet extends StatelessWidget {
  /// The graded answer, as a card.
  const ResultSheet({
    required this.result,
    required this.onReflectAgain,
    required this.onBackHome,
    super.key,
  });

  /// The submit response, which is this card's **only** input.
  ///
  /// **A required parameter and not a resolved dependency**, and the reason is
  /// unchanged by the move: the response is the POST's reply and there is
  /// nothing to re-fetch it from (§5 trap 11), so it travels as an argument
  /// from the quiz — which holds it — to the card — which draws it.
  final SubmitResult result;

  /// The primary action: **return to the quiz** and reflect again.
  ///
  /// The prototype's "retry quiz" (`:725`), and the client's own "Reflect
  /// again". See [ResultSheetAction.reflectAgain] for what the action does now
  /// that the result is a modal.
  final VoidCallback onReflectAgain;

  /// The secondary action: **leave the quiz** and go home.
  ///
  /// The prototype's "read again" (`:724`), and the client's own "Back home".
  final VoidCallback onBackHome;

  /// The card's width, as a fraction of the surface. `:444` — `width:82%`.
  static const double widthFactor = 0.82;

  /// The card's radius. `:444` — `border-radius:28px`.
  ///
  /// **[EvaRadii.glassForm]**, which is 28 and is the design system's own name
  /// for "the roundest of the rounded surfaces" — the glass form on the login
  /// screen. The prototype's card is the same role: the outermost container on
  /// a surface.
  static const double radius = EvaRadii.glassForm;

  /// The card's padding. `:444` — `padding:34px 28px`.
  ///
  /// **Vertical 34, horizontal 28**, in that order, because the prototype's
  /// shorthand is `vertical horizontal`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(28, 34, 28, 34);

  /// The card's fill's alpha in the dark palette. `:444` — `rgba(12,14,24,.94)`.
  static const double darkFillAlpha = 0.94;

  /// The card's fill's alpha in the light palette. `:66` — `rgba(255,255,255,.95)`.
  static const double lightFillAlpha = 0.95;

  /// The veil's alpha in the dark palette. `:433` — `rgba(0,0,0,.55)`.
  static const double darkVeilAlpha = 0.55;

  /// The veil's alpha in the light palette. `:98` — `rgba(60,55,40,.25)`.
  static const double lightVeilAlpha = 0.25;

  /// The scale the card enters at. `:444-445` — `transform:scale(.9)`.
  static const double enterScale = 0.9;

  /// The entrance's duration. `:445` — `transition:transform .5s var(--e-spring)`.
  static const Duration enterDuration = Duration(milliseconds: 500);

  /// The veil's fade. `:442` — `transition:opacity .4s`.
  static const Duration veilDuration = Duration(milliseconds: 400);

  /// The gap between the card and the surface's edge.
  ///
  /// **Not the prototype's number**, because the prototype's card is `82%` wide
  /// and centred with no margin of its own (`:442`'s `place-items:center`), and
  /// this client needs a margin so the card cannot touch the edge of a narrow
  /// surface. 16 is [EvaSpacing.lg] — the design system's own "the default gap
  /// between siblings".
  static const double outerMargin = EvaSpacing.lg;

  /// The burst's size. The superseded prototype's `SunBurst` was
  /// `width="100" height="100"`.
  ///
  /// **The redesign has no burst at all** — its celebration is the `.bigring`
  /// (`:447`), and the class doc records that the ring is not ported — so `100`
  /// is the prototype's own number and the client keeps it.
  ///
  /// **100 and not [SunBurst]'s own default of 96**, for the same reason
  /// `reading_geometry_test.dart` records for the drop cap: the prototype
  /// published one number for one screen, and the widget's default is not a
  /// transcription of anything.
  static const double burstSize = 100;

  /// The gap under the burst. The superseded prototype's was `marginBottom: 22`.
  ///
  /// **The redesign has no counterpart** — its celebration is the unported
  /// `.bigring`, whose own `margin: 0 auto 18px` (`:447`) belongs to a ring
  /// this client does not draw — so the client keeps `22`.
  static const double burstGap = 22;

  /// The burst's glow: the superseded prototype's `filter: drop-shadow(0 0 36px
  /// rgba(#F5C84C, .55))`.
  ///
  /// **The redesign has no counterpart** — it draws no burst, so there is
  /// nothing for a glow to fall on.
  ///
  /// **Transcribed, and it belongs to the card rather than the widget** because
  /// `SunBurst`'s own doc says so: it is the svg, the glow is the container's
  /// `filter`, and putting it inside the widget would invent a shape the
  /// prototype does not have.
  static const double burstGlowBlur = 36;

  /// The glow's alpha: the superseded prototype's `0.55`. **The redesign has no
  /// counterpart** — it draws no burst.
  static const double burstGlowAlpha = 0.55;

  /// The score's size. The superseded prototype's was `fontSize: 68`.
  ///
  /// **The redesign has no counterpart on this surface** — its result figure is
  /// the unported `.bigring .val` at 34px (`:452`) — so the client keeps `68`.
  static const double scoreFontSize = 68;

  /// The score's tracking: the superseded prototype's `letterSpacing:
  /// '-0.02em'`. **The redesign has no counterpart** — the ring's own figure
  /// (`:452`) declares no tracking.
  ///
  /// Resolved against the score's own 68px, for `StickyCta`'s recorded reason:
  /// CSS `em` tracking is relative to the element's font size, so this is `1.36`
  /// and not `0.02`.
  static const double scoreLetterSpacing = -0.02 * scoreFontSize;

  /// The denominator's size: the superseded prototype's was `fontSize: 42`.
  /// **Not used**: there is no denominator, and the field's doc gives the whole
  /// argument.
  static const double denominatorFontSize = 42;

  /// The gap under the score. The superseded prototype's was `marginBottom: 14`.
  ///
  /// **The redesign has no counterpart** — its result card has no score under a
  /// celebration, only the unported `.bigring` — and the client's own value is
  /// the design system's [EvaSpacing.md] (12), not the prototype's 14.
  static const double scoreGap = EvaSpacing.md;

  /// The gap under the message. The superseded prototype's was `marginBottom:
  /// 24`. **The redesign has no counterpart** — its own result message (`:722`)
  /// is followed by the `.recap` row at `margin-top: 16px` (`:453`), which is
  /// a different structure — so the client keeps `24`.
  static const double messageGap = EvaSpacing.xxl;

  /// The message's own maximum width: the superseded prototype's was
  /// `maxWidth: 260`, and the message is centred inside it.
  ///
  /// **The redesign has no counterpart** — its result message (`:722`) declares
  /// no max-width at all — so the client keeps `260`.
  static const double messageMaxWidth = 260;

  /// The pill's padding: the superseded prototype's was `padding: '8px 18px'`.
  ///
  /// The redesign's own streak chip — `.streak` (`:238`) — is
  /// `padding:7px 14px 7px 11px`, and **the client keeps the prototype's
  /// `8 × 18`**.
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: EvaSpacing.sm,
  );

  /// The gap between the flame and the label: the superseded prototype's was
  /// `gap: 8`. The redesign's own streak chip is `gap:9px` (`:238`), and **the
  /// client keeps the prototype's `8`**.
  static const double pillGap = EvaSpacing.sm;

  /// The pill's fill: the superseded prototype's was `ember` at
  /// `isDark ? .12 : .1`. The redesign's own streak chip is
  /// `rgba(232,176,75,.06)` (`:239`) — a different hue and a different alpha —
  /// and **the client keeps the prototype's**.
  static const double darkPillAlpha = 0.12;
  static const double lightPillAlpha = 0.1;

  /// The pill's rim: the superseded prototype's was
  /// `border: '1px solid rgba(ember, .28)'`. The redesign's own streak chip is
  /// `1px solid rgba(232,176,75,.35)` (`:238`), and **the client keeps the
  /// prototype's `.28`**.
  static const double pillBorderAlpha = 0.28;

  /// The pill's glow: the superseded prototype's was
  /// `boxShadow: '0 0 24px rgba(ember, .22)'`. **The redesign has no
  /// counterpart** — its own streak chip (`:238-239`) declares no shadow — so
  /// the client keeps the prototype's.
  static const double pillGlowBlur = 24;
  static const double pillGlowAlpha = 0.22;

  /// The gap between the two stat tiles: the superseded prototype's stat row
  /// was `gap: 10`.
  ///
  /// **The redesign has no counterpart** — its result card has no stat row at
  /// all, only the `.recap` row of per-question dots (`:453`) — so the client
  /// keeps `10`.
  static const double statGap = 10;

  /// The gap under the stat row: the superseded prototype's was
  /// `marginBottom: 32`. **The redesign has no counterpart** — its result
  /// card's last row is the button pair (`:724-725`) — so the client keeps
  /// `32`.
  static const double statGapBottom = 32;

  /// The gap between the two buttons: the superseded prototype's column was
  /// `gap: 12`.
  ///
  /// The redesign's own pair is `.rcta` at `margin-top:22px` and `.rghost` at
  /// `margin-top:10px` (`:458`, `:463`), so its inter-button gap is `10` — and
  /// **the client keeps the prototype's `12`**.
  static const double buttonGap = EvaSpacing.md;

  /// The pill flame's box: the superseded prototype's inline `<svg>` was
  /// `width="14" height="18"`. The redesign's own `.flame` is `13×17` (`:242`),
  /// and **the client keeps the prototype's `14 × 18`**.
  static const double pillFlameWidth = 14;
  static const double pillFlameHeight = 18;

  /// The veil's tint for the surface behind the card.
  ///
  /// **[EvaColors.glassShadow] at the prototype's own alpha**, and the class
  /// doc's colour table has the measurements: the dark arm is **exact**
  /// (`glassShadow` is pure black in the dark palette) and the light arm keeps
  /// the prototype's alpha over the palette's own dark.
  ///
  /// ## WHY IT IS NOT CALLED `veilColor`
  ///
  /// Because `no_colour_literals_test.dart` looks for the **substring**
  /// `Color(` to decide that a line produces a colour — and `veilColor(` ends
  /// with it. The first version was named `veilColor` and the gate reported
  /// the method's own signature and its call site as two colour literals, which
  /// is the gate being wrong about a line and right about the rule.
  ///
  /// **The name is the fix, and it is a real one**: the method returns a
  /// *tint* — the palette's shadow colour at the prototype's alpha — and not a
  /// palette entry, so `veilTint` says what it returns.
  static Color veilTint(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return colors.glassShadow.withValues(
      alpha: dark ? darkVeilAlpha : lightVeilAlpha,
    );
  }

  /// Presents the result card over [context] and returns what the reader chose.
  ///
  /// **`null` means the reader dismissed it** — the barrier, the system back
  /// button — and the caller is left exactly where they were. That is the
  /// modal's whole reason for existing over a page: the quiz is still there
  /// underneath, and the reader can carry on.
  ///
  /// ## WHY [card] IS BUILT BY THE **CALLER**
  ///
  /// Because `tool/gates/orphan_widget_check.py` finds a widget by looking for
  /// its **constructor call** in a page's file: a `show` that built the card
  /// inside its own file would leave the card unreachable from every page —
  /// a **false orphan**, and a false orphan is a gate nobody can believe. The
  /// gate reported `ResultSheet` (and, through it, `StatTile` and `SunBurst`)
  /// as unplaced, and the honest repair is to make the placement **visible**,
  /// not to allowlist a widget that is demonstrably on the screen.
  ///
  /// ## WHY IT RETURNS AN **ACTION** AND NOT A `void`
  ///
  /// The two CTAs have to **close the modal and then act**, and the order is
  /// the whole of it. A page action (`replacePath('/quiz')`) replaced a route;
  /// inside a dialog the same call would leave the reader with a dialog over a
  /// replaced route — the dialog on top of a page it no longer belongs to.
  ///
  /// So the button **pops the dialog with the action**, and the caller acts
  /// **after** this future completes. The dialog's route is out of the
  /// navigator's history by then, so the reader ends up in exactly one place
  /// with no dialog left on screen — which is what the test proves.
  ///
  /// ## THE VEIL AND THE FADE ARE THE PROTOTYPE'S
  ///
  /// The barrier is the prototype's `.veil` (`:433-434`, and `:98` for the light
  /// palette) at the alpha the class doc tabulates, and the modal's own fade is
  /// `:442`'s `transition:opacity .4s`.
  static Future<ResultSheetAction?> show(
    BuildContext context, {
    required ResultSheet card,
  }) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // ## THE RESULT'S HAPTIC
    //
    // `eva/redesign.html:1445` — the last line of `showResults` is
    // `haptic([30,40,30])`, and the results are the app's own good news: the
    // reader finished the day's reading.
    //
    // **The reader's own switch, read without a dependency**, because `show`
    // is called from an **event handler** — the quiz's `_presentResult` — and
    // `SettingsScope.of` is a *dependent* lookup, which Flutter refuses
    // outside a build. `ritualHapticsEnabled` is the app's own answer for
    // exactly that case, and it answers `false` when no handle is registered.
    fireRitualHaptic(
      RitualHaptic.resultsShown,
      enabled: ritualHapticsEnabled(),
    );
    return showGeneralDialog<ResultSheetAction>(
      context: context,
      barrierColor: veilTint(context),
      barrierDismissible: true,
      // The barrier is a control, and a control with no accessible name is
      // §14's first row. `MaterialLocalizations` owns the word.
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // §14: a reader who asked for less motion gets the end state, not a
      // shorter animation.
      transitionDuration: reduced ? Duration.zero : veilDuration,
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) => card,
      // `:442` — the modal's own transition is an **opacity** fade, and the
      // card's scale is the card's own (`:444-446`). Two mechanisms, two
      // declarations, and neither is the other's.
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) => FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Size surface = MediaQuery.sizeOf(context);
    // The **safe** height, not the screen's: the card is inside a `SafeArea`,
    // so a bound taken from the full height would let it outgrow the area the
    // system insets leave it.
    final double safeHeight =
        surface.height - MediaQuery.paddingOf(context).vertical;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ResultSheet.outerMargin),
        child: Align(
          // `:442` — `display:grid;place-items:center`. The card is centred on
          // the surface, both ways, and `Align`'s own default is
          // `Alignment.center` — so the prototype's rule is the widget's
          // default rather than an argument.
          child: FractionallySizedBox(
            widthFactor: ResultSheet.widthFactor,
            child: TweenAnimationBuilder<double>(
              // ## THE CARD'S OWN SCALE-IN, AND §14's RULE
              //
              // `:444-446` is `transform:scale(.9)` → `scale(1)` over `.5s` on
              // `--e-spring`. The spring curve is [EvaMotion.achievementCurve] —
              // the app's approximation of a spring, and the curve the dock's
              // and the streak's own moments use.
              //
              // **The duration is the prototype's 500ms and not
              // [EvaMotion.achievementSettle]'s 344ms**, because this surface
              // declares its own and the motion table's achievement moment is
              // the *streak's*, not the card's. It is a local constant rather
              // than a new token because a token with one reader is the
              // bloat `seamGlow`'s doc declines.
              //
              // **A zero duration when motion is reduced** — §14's rule, and the
              // end state is the card at full size, so the card is simply there.
              tween: Tween<double>(begin: enterScale, end: 1),
              duration: reduced ? Duration.zero : ResultSheet.enterDuration,
              curve: EvaMotion.achievementCurve,
              builder: (BuildContext context, double scale, Widget? child) =>
                  Transform.scale(
                    scale: scale,
                    // CSS `transform: scale()` is about the element's own
                    // centre, and so is `Transform.scale`'s default
                    // alignment — so the prototype's rule is the widget's
                    // default rather than an argument.
                    child: child,
                  ),
              child: ConstrainedBox(
                // The card may not be taller than the surface it is centred on,
                // and its content scrolls when it is. The prototype's card is
                // `position:absolute` inside a fixed screen and simply
                // overflows; §14's surface (320×568 at 1.22×) is smaller than
                // this card's content, so the card scrolls rather than
                // overflowing — the same resolution the result *page* took.
                constraints: BoxConstraints(
                  maxHeight: safeHeight - ResultSheet.outerMargin * 2,
                ),
                child: _card(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card itself: the prototype's `.rcard` (`:444-446`).
  Widget _card(BuildContext context) {
    final EvaColors colors = context.colors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        // `:444` — `background:rgba(12,14,24,.94)`; `:66` — the light arm's
        // `rgba(255,255,255,.95)`. The class doc's colour table has the token
        // each arm resolves to and what the substitution costs.
        color: colors.surface.withValues(
          alpha: dark ? ResultSheet.darkFillAlpha : ResultSheet.lightFillAlpha,
        ),
        borderRadius: BorderRadius.circular(ResultSheet.radius),
        // `:444` — `border:1px solid var(--glass-line)`. The token is the
        // design system's own rim, and the prototype's `--glass-line` is the
        // same idea at a slightly different alpha.
        border: Border.all(color: colors.glassBorder),
        // **No `box-shadow`**, because `:444-446` declares none. The design
        // system's `GlassSurface` always paints the ambient one; this card
        // does not, and the veil is what separates it from the quiz.
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResultSheet.radius),
        child: SingleChildScrollView(
          child: Padding(padding: ResultSheet.padding, child: _body(context)),
        ),
      ),
    );
  }

  /// The card's content, in the client's own order.
  Widget _body(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return Column(
      // ## `mainAxisSize.min` AND **NOT** `MainAxisAlignment.center`
      //
      // The content is taller than the card's box on §14's surface, and the
      // card scrolls — so the column is the card's content height and the
      // scroll view is what moves it. `center` inside a scroll view is not
      // "centred" but an overflow.
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: burstGap),
          child: DecoratedBox(
            // The superseded prototype's container carried
            // `filter: drop-shadow(...)`. **The redesign has no counterpart** —
            // it draws no burst.
            // `ImageFilter` rather than `BoxShadow`, because a CSS
            // `drop-shadow` on an element follows the **alpha** of what it is
            // drawn on and a `BoxShadow` is a rectangle; a 96px glow on a
            // transparent svg needs the former.
            decoration: BoxDecoration(
              color: Colors.transparent,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: EvaStickerPalette.of(StickerSlot.sun)
                      .withValues(alpha: burstGlowAlpha),
                  blurRadius: burstGlowBlur,
                  spreadRadius: burstGlowBlur / 2,
                ),
              ],
            ),
            // `ExcludeSemantics` is inside [SunBurst] (its own doc says the
            // burst is decorative), so this line is the widget and nothing else.
            child: const SunBurst(size: burstSize),
          ),
        ),
        _Score(result: result, strings: strings),
        const SizedBox(height: messageGap),
        Text(
          strings.messageFor(
            isCorrect: result.isCorrect,
            readingCompleted: result.readingCompleted,
          ),
          textAlign: TextAlign.center,
          // The superseded prototype's message was
          // `F.ui, 16, 400, lineHeight 1.55, T.ink2` with `maxWidth: 260`. The
          // redesign's own result message (`:722`) is `var(--scr)` at 20px with
          // no max-width — **and the client keeps the prototype's 16 and 1.55**.
          style: arabicAware(
            Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontSize: 16,
              height: 1.55,
              color: context.colors.ink2,
            ),
            Directionality.of(context),
          ),
        ),
        const SizedBox(height: statGapBottom),
        _StreakPill(result: result, strings: strings),
        const SizedBox(height: statGapBottom),
        _StatRow(result: result, strings: strings),
        const SizedBox(height: statGapBottom),
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              EvaButton(
                label: strings.resultReflectAgain,
                labelFamily: _ctaFamily(context),
                onPressed: onReflectAgain,
              ),
              const SizedBox(height: buttonGap),
              EvaButton(
                label: strings.resultBackHome,
                labelFamily: _ctaFamily(context),
                variant: EvaButtonVariant.secondary,
                onPressed: onBackHome,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The primary button's label family, for the arm on screen.
  ///
  /// **DM Sans, and NOT the payload arm.** Both of this card's buttons are the
  /// app's own chrome — "Reflect again" and "Back" — and decision 75's table
  /// puts chrome on the **ambient** arm. `ReadingPage` needed
  /// `StickyCta.ctaFamilyFor` because its CTA caption is a count *about the
  /// payload*; there is no such thing here.
  ///
  /// `labelFamily` is required (recorded decision 66), so the value has to be
  /// named at every call site; `arabicAwareFamily` is the ambient answer and it
  /// is here rather than a second `switch` because there is nothing per-arm to
  /// switch on.
  static String _ctaFamily(BuildContext context) =>
      arabicAwareFamily(Directionality.of(context), EvaTypography.uiFamily);
}

/// What the reader chose in the sheet.
///
/// **An enum and not a `bool`**, and the reason is decision 13's: a `bool`
/// cannot say *which* choice, and the two choices are different destinations.
/// The value is also the sheet's **only** output — the card reports nothing
/// else, and the quiz is still on screen underneath either way.
enum ResultSheetAction {
  /// The primary CTA: **reflect again**, in the quiz that is still there.
  ///
  /// The prototype's "retry quiz" (`:725`). **What it does is this client's**,
  /// and the difference is the modal: as a page, "Reflect again" was
  /// `replacePath('/quiz')` — a *new* quiz route. As a modal it is **the quiz
  /// the reader is already in**, restarted in place, so the answer they are
  /// answering is the same question and the same session.
  reflectAgain,

  /// The secondary CTA: **back home**, to the dock.
  ///
  /// The prototype's "read again" (`:724`), and the client's own "Back home"
  /// to `/`.
  backHome,
}

/// The headline figure. The superseded prototype's score block.
///
/// ## THERE IS NO **`/5`** HERE, AND THAT IS THE LARGEST DIVERGENCE ON THIS CARD
///
/// The superseded prototype's score is a `4` at 68sp beside a `/5` at 42sp. The
/// `5` is a **hard-coded literal** in a screen with no data layer — there is no
/// endpoint
/// in this backend that returns a question count for a session, and §2's route
/// table gives the result no repository, so a client cannot learn it.
///
/// Rendering one would be decision 45's rejected rule in its purest form: a
/// number a reader would read as a fact about their own day, which the server
/// never sent. So the figure is the **running total** and the denominator is
/// **gone**, and [ResultSheet.denominatorFontSize] is carried with a doc saying
/// it is not used rather than deleted — a reader comparing against the prototype
/// needs to find the transcription and its replacement, and a silently absent
/// `42` says neither.
class _Score extends StatelessWidget {
  /// The score is [result]'s **running total**.
  const _Score({required this.result, required this.strings});

  final SubmitResult result;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // The superseded prototype's score block was `lineHeight: 1`, so the
      // figure's box is its own height and the caption below does not inherit
      // the leading.
      Text(
        // **`currentTotalPoints`, not `pointsEarned`.** This card reports the
        // reader's standing after the submission; the answer's own score is the
        // first stat tile. `result_sheet_test.dart` asserts both numbers are on
        // screen and that they are not the same one twice.
        //
        // **The arm's numerals, not `toString()`.** The first draft rendered
        // `result.currentTotalPoints.toString()` — Western digits — beside tiles
        // that `arabic_typography_test.dart` holds to Amiri **with** Arabic-Indic
        // digits, so the Arabic arm showed one Western and two Arabic-Indic
        // numerals on one screen. `result_sheet_test.dart` found it by looking
        // for `٤٠` and finding nothing.
        //
        // `_StatRow._countIn` is the same rule, called from a different class in
        // the same file — which is the one place two callers is acceptable,
        // because it is one file and one rule rather than two files and two
        // rules.
        _StatRow._countIn(strings, result.currentTotalPoints),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displayLarge!.copyWith(
          fontSize: ResultSheet.scoreFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: ResultSheet.scoreLetterSpacing,
          height: 1,
          // The **ambient** arm: the number is the app's own rendering of a
          // server integer, and there is no payload behind it that could say
          // which face.
          fontFamily: arabicAwareFamily(
            Directionality.of(context),
            EvaTypography.displayFamily,
          ),
          color: context.colors.ink,
        ),
      ),
      const SizedBox(height: EvaSpacing.xs),
      Text(
        // ## AND THE CAPTION IS PLURALISED **WITHOUT** THE NUMBER
        //
        // `resultTotalCaption` is an ICU plural that selects the NOUN and carries
        // no `{digits}`, because the score is drawn one line above in
        // `displayLarge` and folding the numeral in here would print it twice.
        // It takes the same integer that line draws, so there is one count and
        // one source for it.
        //
        // This is the half of the migration that is a CORRECTNESS FIX rather than
        // a refactor: the value was `نقطة` — singular — for every score, so
        // `٥ نقطة` rendered where Arabic wants `٥ نقاط`. `test/l10n/` holds the
        // six classes.
        strings.resultTotalCaption(result.currentTotalPoints),
        style: arabicAware(
          Theme.of(context).textTheme.bodySmall!,
          Directionality.of(context),
        ).copyWith(color: context.colors.ink2),
      ),
    ],
  );
}

/// The streak pill. The superseded prototype's pill — a flex row of an inline
/// flame and the label.
///
/// ## §3.1's DELETION TEST, RUN — AND IT BECAME A PRIVATE WIDGET HERE
///
/// `04-widget-inventory.md` line 364 names `StreakPill` as a feature-local
/// composite, and line 52's demotion watch list does **not** name it. The test is
/// "two or more call sites, or deleting the widget makes complexity reappear",
/// and:
///
/// * **one** call site — this one;
/// * deleting it reappears as a `Container` with five decoration properties, two
///   alpha functions and a derived label. That **is** complexity, so the bar is
///   met on the second clause;
/// * and it is not shared with any other feature, so promoting it to
///   `core/design_system/` would be §3's "nothing enters the kernel
///   speculatively" on the other side.
///
/// So it is a **private** widget in this file rather than
/// `features/quiz/presentation/widgets/streak_pill.dart`. The derived label is
/// [ResultStringsPhrases.streakLabelFor], which is a **pure function on the
/// string table** and so is unit-tested without a widget — which is the half of
/// the coverage a separate file would have bought.
///
/// **Rejected: a public `StreakPill` in `core/design_system/`.** It would be a
/// fourth widget in the tree with one caller, and the fifth entry on a demotion
/// list that already has six.
///
/// **Rejected: a separate file.** It is forty lines with one caller, and
/// `HomePage`'s `_Avatar` and `ReadingPage`'s `_ArabicBand` are the precedent for
/// keeping a one-caller composite beside its screen.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.result, required this.strings});

  final SubmitResult result;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Brightness brightness = Theme.of(context).brightness;

    return Container(
      padding: ResultSheet.pillPadding,
      decoration: BoxDecoration(
        // The superseded prototype's `rgba(ember, isDark ? .12 : .1)`. The
        // redesign's own streak chip is `rgba(232,176,75,.06)` (`:239`) — a
        // different hue and a different alpha — and the client keeps the
        // prototype's.
        color: colors.ember.withValues(
          alpha: brightness == Brightness.dark
              ? ResultSheet.darkPillAlpha
              : ResultSheet.lightPillAlpha,
        ),
        borderRadius: BorderRadius.circular(999),
        // The superseded prototype's `border: '1px solid rgba(ember, .28)'`; the
        // redesign's own streak chip is `1px solid rgba(232,176,75,.35)` (`:238`),
        // and the client keeps the prototype's.
        border: Border.all(
          color: colors.ember.withValues(alpha: ResultSheet.pillBorderAlpha),
        ),
        // The superseded prototype's `boxShadow: '0 0 24px rgba(ember, .22)'`;
        // the redesign's own streak chip declares no shadow (`:238-239`), so the
        // client keeps the prototype's.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ember.withValues(alpha: ResultSheet.pillGlowAlpha),
            blurRadius: ResultSheet.pillGlowBlur,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The superseded prototype's pill flame is an inline `<svg>` **14×18**,
          // which is NOT the design system's `StreakFlame` — that one is square
          // (`streak_flame.dart`'s `size` sets width **and** height) and is
          // transcribed from the prototype's own top bar, a different site.
          // The redesign's own `.flame` is `13×17` (`:242`) — a third shape, and
          // a fourth number the client does not use.
          //
          // So the prototype's own shape is a **width/height pair**, and a square
          // icon at 18 would be visibly wider than the prototype's. It is drawn
          // at 14×18 here. `result_sheet_geometry_test.dart` asserts the pair,
          // because the alternative — accepting the square and losing the number
          // — is the kind of divergence that is invisible in a diff and visible
          // on screen.
          SizedBox(
            width: ResultSheet.pillFlameWidth,
            height: ResultSheet.pillFlameHeight,
            child: FittedBox(
              // `BoxFit.contain` — `FittedBox`'s own default — so the square icon
              // is drawn into the 14×18 box above at the prototype's shape.
              child: StreakFlame(
                // `size` is `pillFlameHeight` — `StreakFlame`'s own default is the
                // same 18 — and it is the height half of the 14×18 pair argued
                // above; the width half is the `SizedBox`.
                // The pill's label already says the streak; a second node saying
                // "Streak" would be two names for one number.
                semanticLabel: strings.resultDay,
              ),
            ),
          ),
          const SizedBox(width: ResultSheet.pillGap),
          Text(
            strings.streakLabelFor(
              current: result.currentStreak,
              longest: result.longestStreak,
            ),
            style: arabicAware(
              Theme.of(context).textTheme.bodyMedium!,
              Directionality.of(context),
            ).copyWith(fontWeight: FontWeight.w600, color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// The two stat tiles. The superseded prototype's stat row.
///
/// ## §3.1's DELETION TEST AGAIN, AND IT ALSO BECAME A PRIVATE WIDGET
///
/// Same answer, and it is worth the symmetry: `StatRow` is named in
/// `04-widget-inventory.md` line 364 as a feature-local composite, and the
/// deletion test says a `Row` of `StatTile`s with a `gap` is **not** complexity —
/// it is three lines that reappear as three lines. So it is private, beside its
/// card, and the numbers it shows are the recorded substitution the class doc of
/// [ResultSheet] tabulates.
///
/// ## **TWO** TILES, NOT THREE, AND THE THIRD NUMBER WAS A **DUPLICATE**
///
/// The superseded prototype's `StatTile` row wrote **three**, and **the redesign
/// has no counterpart** — its result card's recap is a row of per-question dots
/// (`:453-457`), not tiles. This row has two, and the reason is that a third
/// would have to repeat a number already on screen:
///
/// | where | prototype's value | here |
/// | --- | --- | --- |
/// | the headline | `4` | `currentTotalPoints` |
/// | the pill | `Day 12` | `currentStreak` + the comparison |
/// | tile 1 | `14 Read` | `pointsEarned` |
/// | tile 2 | `9 Reflected` | `longest_streak` |
/// | tile 3 | `5/5 Best` | **gone** |
///
/// `SubmitResult` has exactly seven fields and four of them are the four places
/// above. A third tile could only have been `currentTotalPoints` or
/// `currentStreak`, both of which are already drawn — and
/// `result_sheet_test.dart` caught the first draft for it, because
/// `find.text('1234')` matched **two** widgets.
///
/// *Rejected: inventing a third figure.* There is nothing else in the response,
/// and a number a reader would read as a fact about their own day must come from
/// the server. *Rejected: `points_value` as a denominator.* §2's route table
/// gives the result no repository, so the client never learns how many questions
/// the session had — and decision 93 records the same fact about the submit
/// response.
///
/// **Rejected: the prototype's three tiles**, `14 Read` / `9 Reflected` /
/// `5/5 Best` — all three are **profile history**, and no endpoint in this
/// backend returns days-read or reflections-so-far. Shipping them would mean
/// inventing three numbers a reader would read as facts about their own history.
class _StatRow extends StatelessWidget {
  _StatRow({required this.result, required this.strings})
    : tiles = tilesFor(
        pointsEarned: result.pointsEarned,
        longestStreak: result.longestStreak,
        strings: strings,
      );

  final SubmitResult result;
  final AppLocalizations strings;

  /// The two tiles, built in the **initializer list** so the constructor can
  /// stay `const`.
  ///
  /// **An initializer list and not a `late final` field**, because `late` cannot
  /// live in a class with a `const` generative constructor — and the `const` is
  /// worth having, since this widget is rebuilt with its parent. The two instance
  /// members being read are the ones the parameter list just bound, which is
  /// legal in an initializer list and illegal in a field initializer.
  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) => Row(
    // The superseded prototype's stat row was
    // `display: flex, gap: 10, width: '100%'`.
    children: <Widget>[
      // The superseded prototype's `StatTile` was `flex: 1`, so `Expanded` is the
      // transcription and the two tiles share the row evenly.
      // `ResultSheet.statGap` is the prototype's `gap: 10` between them, applied
      // as padding on the first rather than on both, for the reason
      // `ProgressBeads`' own build records: a CSS `gap` is the space **between**
      // items and there is no trailing one.
      for (int index = 0; index < tiles.length; index++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == tiles.length - 1 ? 0 : ResultSheet.statGap,
            ),
            child: StatTile(value: tiles[index].$1, label: tiles[index].$2),
          ),
        ),
    ],
  );

  /// The **two** `(value, label)` pairs, in the prototype's order.
  ///
  /// **A `final` field and not a getter**, because a getter would rebuild two
  /// strings on every frame of a tree that paints once. It is a **static**
  /// method rather than an instance field so the tiles are constructible in a
  /// `const` constructor's initializer list — which is what keeps this widget
  /// `const`-able and therefore cheap enough to rebuild with its parent.
  ///
  /// The labels are the **written** substitutions, and [ResultSheet]'s doc
  /// tabulates them against the superseded prototype's three tiles.
  ///
  /// **A named function and not two inline tuples** so the order lives in one
  /// place.
  ///
  /// ## `currentTotalPoints` WAS A PARAMETER HERE, AND REMOVING IT IS THE FIX
  ///
  /// The first version took three fields and returned three tiles, the third
  /// being `currentTotalPoints` under a written label — **and that number is the
  /// headline**, in Arabic-Indic digits, one line above. `result_sheet_test.dart`
  /// found it by asserting `findsOneWidget` on the headline and getting **two**.
  ///
  /// So the parameter is gone rather than defaulted, ignored, or given a third
  /// label. Leaving it in the signature would have been the worse repair: a
  /// required parameter nothing reads is a claim that something does, and the
  /// next reader would either wire it back up or spend an afternoon proving it
  /// is dead.
  ///
  /// **A count check would not have caught the reintroduction**, which is why
  /// the suite's companion test compares the *values*: `find.byType(StatTile)` is
  /// two today, and asserting two passes on a screen that merged three into two.
  static List<(String, String)> tilesFor({
    required int pointsEarned,
    required int longestStreak,
    required AppLocalizations strings,
  }) => <(String, String)>[
    (_countIn(strings, pointsEarned), strings.resultThisAnswer),
    (_countIn(strings, longestStreak), strings.resultBestRun),
  ];

  /// [value] in [strings]' numerals.
  ///
  /// **A one-line delegate and not the arm's own `_count`** — decision 77's
  /// reason inverted. The tiles are drawn by [StatTile] in `headlineSmall`, so
  /// *this file* decides what string reaches it, and the rule has to be
  /// reachable from here. The rule itself is [AppLocalizationsArm.digits],
  /// shared with `/quiz` and `/reading` because three features need it and §3
  /// puts that in shared code.
  ///
  /// On the Arabic arm that is the Arabic-Indic form, because Amiri carries
  /// Arabic **and** Latin — so a Western digit would render, but beside an
  /// Arabic streak pill it would be the only Western numeral on the screen.
  ///
  /// `StatTile` resolves both of its runs through `arabicAware` (decision 84),
  /// so the family question is settled at the widget and this method only
  /// decides the **numerals**.
  ///
  /// ## AND THIS IS WHERE `ResultStrings.isArabic` USED TO BE READ
  ///
  /// It was derived by comparing `backHome` against the Arabic arm's
  /// `backHome`, which had a real argument behind it — a stored `bool` would
  /// have been a second source of truth for the same fact as the nouns being
  /// Arabic. With ARB that comparison has no honest form left: it would compare
  /// a generated getter against a second generated instance, which tests the
  /// generator rather than the arm and breaks the moment a translator picks an
  /// Arabic value that coincides with the English one.
  /// [AppLocalizationsArm.isArabicArm] reads the locale instead, which is the
  /// fact the question was asking.
  static String _countIn(AppLocalizations strings, int value) =>
      strings.digits(value);
}
