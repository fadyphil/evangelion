import 'dart:async';

import 'package:evangelion/core/common/cycle_phase.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:evangelion/core/domain/entities/selah_countdown.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Sixty seconds of silence, and the control that starts them.
///
/// `redesign.html:530-533` — `.selah`, its two lines, and the `.breathing` circle.
///
/// ## AND NOW THE BUTTON **DOES** SOMETHING
///
/// `:1330-1342` is the prototype's timer: a 60-second countdown, a live number
/// in the card's corner, `.selah.active` swapping the button to a filled gold,
/// and `focusDim = true` dimming the screen around the reader. Phase 7 Step 3
/// owns all of it ("Ritual. Selah timer · focus mode · vespers auto-dim ·
/// breath guide · haptics"), and this file is that step's timer.
///
/// The **counting** is `core/domain/entities/selah_countdown.dart`'s — the
/// arithmetic is a domain fact and the clock is a widget's — and the **haptic
/// vocabulary** is `core/domain/entities/ritual_haptic.dart`'s.
///
/// ## THE COUNT IS THE **READER'S** CHOICE
///
/// `UserSettings.selahLengthSec` is the length the reader picked in the
/// Workshop (`eva/redesign.html:684` — a 15…120 second range, stepped by 5),
/// and it is what [seconds] carries. The prototype's `selahDur` is the same
/// fact in the same place: `:1324` declares it and `:1518` restores it.
///
/// ## AND THE PROTOYPE'S THREE-PART RHYTHM BECOMES **ONE** BUZZ
///
/// `:1330` asks for `haptic([30,40,30])` — two buzzes with a pause — and
/// `HapticFeedback` has no pattern API. `ritual_haptic.dart` records that
/// loss: the rhythm becomes its strongest element, a heavy impact.
///
/// ## AND THE PROTOTYPE'S **FLARE** IS **NOT** PORTED — AND WHY, IN FULL
///
/// The prototype's completion is one line (`eva/redesign.html:1330`):
///
/// ```js
/// if(done){ toast(tr('amen')); addStar(true); if(V)V.spike=.5; haptic([30,40,30]); }
/// ```
///
/// Three of its four halves are here. The **toast** is the home page's (see
/// [onCompleted]); the **spike** is [kSelahCompletionSpike] through
/// `LumenScene.raiseSpike`; the **haptic** is `RitualHaptic.selahCompleted`.
/// The fourth — `addStar(true)` — is the **flare**: a bigger star in the
/// **witness sky** (`:1148`, `big?5:3+Math.random()*2`, with the wide halo
/// from `starShadows`), and it is **not** ported.
///
/// **The reason is the sky's key space, and it is not a shortcut.** This
/// client's witness sky is **verse-keyed**: `SkyEntry`
/// (`core/domain/entities/sky_entry.dart`) carries a book, a chapter and a
/// verse, and `/reading` lights one star per verse as it crosses the scroll
/// threshold (`:1219`). **A selah lights no verse.** There is no honest key
/// for it:
///
/// * `SkyEntry`'s `chapter` and `verse` are **required `int`s**, and `0` is
///   not a verse of any book — a synthetic key would be a made-up verse;
/// * the entity is **`freezed`**, so making the verse optional is a change to
///   the constructor and the generated copy, and the key space is shared with
///   `/reading`'s real stars and with the constellation's book-scoped polyline
///   (`:1167-1185`), where a point that belongs to no book is a visible
///   fiction; and
/// * ADR-0022's fiction table governs what may be fabricated, and the
///   starfield's row says the **storage** is a stub
///   (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:59`) —
///   not that its keys may be invented.
///
/// **And there is a second, independent reason, which is the one that would
/// have sunk it anyway: the sky is not on this screen.** The prototype's sky is
/// a **global background layer** — `:500`'s `<div id="sky">` is a direct child
/// of `.screen`, and `:116`'s `#sky{position:absolute;inset:0;z-index:2}` puts
/// it over every route — so a flare lit from the home is visible at once. This
/// client mounts `WitnessSky` on **`/reading` only**
/// (`features/reading/presentation/pages/reading_page.dart:604`), and the home
/// feature **reads the sky nowhere**: the only mentions of `Sky` under
/// `lib/features/home/` are prose — this paragraph and a doc comment in the
/// library catalogue's port (`domain/library_catalogue_repository.dart:26`).
/// A star lit on `/` would be invisible where the selah ended, and would
/// appear later — among the verses — in a screen the reader is not on.
///
/// **The precedent is the cheer, and it is the same shape.** `:1123` — the
/// communion cheer — also ends in `addStar(true)`, and
/// `core/design_system/widgets/leaderboard_row_tile.dart` resolved it the same
/// way: "`SkyEntry` is **verse-keyed** … and `/communion` has no verse", so
/// the flare is **row-local and transient** rather than a sky entry. **A
/// card-local flare is the same answer for the selah**, and it is the ready-made
/// follow-up for whoever owns the sky: one `FourPointedStar` in the card's own
/// corner, fading, in place of a sky entry this client cannot honestly name.
class SelahCard extends StatefulWidget {
  /// The card: the word, the duration, and the control that starts the silence.
  const SelahCard({
    required this.seconds,
    required this.beginLabel,
    required this.endLabel,
    required this.hapticsEnabled,
    this.onCompleted,
    super.key,
  });

  /// How long the silence is, in seconds. `redesign.html:1324` —
  /// `selahDur = 60` — and the reader's own choice in the Workshop.
  final int seconds;

  /// The control's accessible name while the silence is **not** running.
  ///
  /// **Written, and not transcribed**: the prototype's button carries
  /// `title="selah"` (`:533`), which names the thing rather than the action,
  /// and this client names the action because §14 asks for a control whose
  /// name says what it does.
  final String beginLabel;

  /// The control's accessible name while the silence **is** running.
  ///
  /// Written for the same reason as [beginLabel].
  final String endLabel;

  /// Whether the reader has asked for haptics.
  ///
  /// `UserSettings.haptics` — the Workshop's own switch (`:689`).
  final bool hapticsEnabled;

  /// Runs when the silence has run its course.
  ///
  /// The page's half of the prototype's `toast(tr('amen'))` (`:1330`) — the
  /// toast is anchored to the screen root and the screen owns it.
  ///
  /// ## AND THE CARD **NO LONGER** DRAWS THE AMEN
  ///
  /// The prototype raises the amen as a **toast** — `:1330`'s
  /// `toast(tr('amen'))` — and a toast is anchored to the screen root
  /// (`:466`). This card used to draw it **in the count's corner** and record
  /// the divergence, on the grounds that "this client has no app-level toast
  /// surface: the communion page builds its own, and `/` has none".
  ///
  /// **That reason has stopped being true.** The toast is now a **shared
  /// design-system widget** (`core/design_system/widgets/eva_toast.dart`) —
  /// one implementation of the prototype's `.toast` for the amen, the cheer
  /// and the restore — and the **home page** owns it, exactly as the
  /// prototype's screen root does. So the amen is a toast again, and this
  /// card's only job is to say that the silence has run its course.
  ///
  /// The card therefore has **no message of its own** any more, and that is
  /// the point: a card that carried the string would be a second place the
  /// amen lives, and the second place is where the divergence was recorded
  /// before. The message itself is the app's own — `homeSelahAmen`, the
  /// prototype's `amen:["selah · amen","سِلاه · آمين"]` (`:970`) — and the
  /// home page holds it.
  final VoidCallback? onCompleted;

  /// The silence's length. `redesign.html:1323` — `let selahDur = 60`.
  static const int defaultSeconds = 60;

  /// The card's corner rounding. `redesign.html:261` — `border-radius: 20px`.
  ///
  /// **Not `EvaRadii.card`** (`18`), and the difference is the prototype's: `.selah`
  /// and `.bcard` are both `20` while `.glass-line` cards elsewhere are `18`. A
  /// local constant beside the citation is the honest spelling; moving the token
  /// would silently change every card that uses it.
  static const double radius = 20;

  /// The card's padding. `redesign.html:262` — `padding: 16px 18px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  /// The gap between the word block and the circle. `redesign.html:262` — `gap: 14px`.
  static const double gap = 14;

  /// The word's size. `redesign.html:264` — `.selah .dt{font-size:14.5px}`.
  static const double titleSize = 14.5;

  /// The gap under the word. `redesign.html:265` — `margin-top: 2px`.
  static const double subtitleGap = 2;

  /// The subtitle's size under LTR. `redesign.html:265` — `font-size: 9px`.
  static const double subtitleSize = 9;

  /// The subtitle's size on the Arabic arm. `redesign.html:266` — `10.5px`, and the
  /// same rule drops its tracking and its uppercase.
  static const double subtitleSizeArabic = 10.5;

  /// The subtitle's tracking under LTR. `redesign.html:265` — `.14em`.
  static const double subtitleTracking = 0.14;

  /// The circle's diameter. `redesign.html:267` — `width: 44px; height: 44px`.
  static const double diameter = 44;

  /// The circle's rim width. `redesign.html:267` — `border: 1.5px solid …`.
  static const double rimWidth = 1.5;

  /// The circle's rim alpha. `redesign.html:267` — `rgba(232,176,75,.6)`.
  static const double rimAlpha = 0.6;

  /// The circle's fill alpha. `redesign.html:268` — `rgba(232,176,75,.08)`.
  static const double fillAlpha = 0.08;

  /// The glyph's size. `redesign.html:269` — `font-size: 11px`, in the mono face.
  static const double glyphSize = 11;

  /// The glyph. `redesign.html:531` — `<button class="breathing" …>✦</button>`.
  ///
  /// **Painted, not typed — and that is a measured correction, not a preference.**
  /// The prototype writes the character and a browser falls back per character
  /// to draw it; **no bundled family carries U+2726** (`0x2726` = `10022`), so the
  /// first build typed it and `arabic_typography_test.dart`'s `expectNoTofuInAnyRun`
  /// failed with `Actual: [10022]`. This client has nothing to fall back **to**:
  /// the glyph is in no bundled font at all, so `fontFamilyFallback` would be a
  /// longer list of misses.
  ///
  /// So [FourPointedStar] paints the shape the character denotes at [glyphSize],
  /// the box the CSS's `font-size` names, and the character itself is kept in
  /// [glyph] as the *record* of what the prototype wrote — asserted by
  /// `home_geometry_test.dart` to be absent from the rendered text so the two
  /// cannot silently swap places.
  ///
  /// ## THE MEASUREMENT LIVES WITH THE SHAPE, NOT HERE
  ///
  /// Which fonts were checked, and how, is recorded in full on
  /// `core/design_system/widgets/four_pointed_star.dart` — the file that owns the
  /// decision, and the one a future call site reads. It is deliberately **not**
  /// restated here: two copies of one measurement is one measurement and two
  /// chances to be stale, and this file's copy already was one. It read "the
  /// twenty shipped `.ttf`s" where `assets/fonts/` holds **nineteen**;
  /// `AGENTS.md` and `test/support/font_coverage.dart`'s own header still say
  /// twenty. None of those three is this slice's to edit, so the number is
  /// measured on the shared file and published there rather than propagated.
  static const String glyph = '✦';

  @override
  State<SelahCard> createState() => _SelahCardState();
}

class _SelahCardState extends State<SelahCard> {
  /// The countdown, or `null` while the silence is not running.
  SelahCountdown? _countdown;

  /// The clock behind the countdown.
  ///
  /// **Cancelled in [dispose], and that is not tidiness.** `flutter_test` fails
  /// a test on a pending timer, and a reader who leaves `/` inside a silence
  /// would otherwise be counted down by a timer whose widget is gone.
  Timer? _timer;

  /// Whether this card is holding the app's focus dim.
  ///
  /// The scene's dim is a **count** (see `LumenScene.dimFocus`), so a card
  /// that is disposed while it is dimming has to give its hold back — and the
  /// flag is what says whether it has one.
  bool _dimming = false;

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_dimming) {
      _scene?.undimFocus();
      _dimming = false;
    }
    super.dispose();
  }

  /// The aurora's scene, or `null` before the first dependency read.
  ///
  /// **A field and not a lookup at the point of use**, because
  /// `NeuralMotionScope.of` is a *dependent* lookup and Flutter forbids one in
  /// [dispose] — which is exactly where the dim has to be given back.
  LumenScene? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scene = NeuralMotionScope.of(context).lumenScene;
  }

  /// Begins the silence.
  void _begin() {
    // A silence of no seconds is not a state the reader can reach — the
    // Workshop's range is 15…120 (`:684`) — and a countdown that finished
    // before it began would toast an amen nobody waited for. So the card
    // refuses it at its own boundary rather than letting the domain throw
    // inside a tap handler.
    final int total = widget.seconds > 0
        ? widget.seconds
        : SelahCard.defaultSeconds;
    _timer?.cancel();
    setState(() {
      _countdown = SelahCountdown.start(total);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    // `:1338` — `focusDim=true; haptic(20);`
    _scene?.dimFocus();
    _dimming = true;
    fireRitualHaptic(RitualHaptic.selahStarted, enabled: widget.hapticsEnabled);
  }

  /// Ends the silence early — the prototype's `selahStop(false)`.
  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _countdown = null;
    });
    _releaseDim();
  }

  /// One second of the silence.
  void _onTick(Timer timer) {
    final SelahCountdown? current = _countdown;
    if (current == null) return;
    final SelahCountdown next = current.tick();
    if (next.isComplete) {
      _complete();
      return;
    }
    setState(() {
      _countdown = next;
    });
  }

  /// The silence has run its course — the prototype's `selahStop(true)`.
  void _complete() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _countdown = null;
    });
    _releaseDim();
    // `:1330` — `if(done){ toast(tr('amen')); addStar(true); if(V)V.spike=.5;
    // haptic([30,40,30]); }`
    //
    // ## THE **SPIKE** IS PORTED, AND THE **FLARE** IS NOT
    //
    // `V.spike=.5` is the aurora's kick, and this client has the mechanism:
    // `LumenScene.raiseSpike` — so the selah raises it, by the prototype's
    // own number ([kSelahCompletionSpike]).
    //
    // `addStar(true)` is the **flare** — a bigger star in the **witness sky**
    // (`:1148`, `big?5:3+Math.random()*2`) — and it is **not** ported, because
    // this client's sky is keyed `book:chapter:verse` and **a selah lights no
    // verse**. The full account, and the two independent reasons, are on
    // [SelahCard]'s class doc.
    _scene?.raiseSpike(kSelahCompletionSpike);
    fireRitualHaptic(
      RitualHaptic.selahCompleted,
      enabled: widget.hapticsEnabled,
    );
    // **The amen is the page's.** The prototype's `toast(tr('amen'))` is
    // anchored to the screen root (`:466`) and the screen owns it — so the
    // card's only half of it is this callback, and the home page raises the
    // toast.
    widget.onCompleted?.call();
  }

  /// Gives the app's focus dim back, if this card was holding it.
  void _releaseDim() {
    if (!_dimming) return;
    _dimming = false;
    _scene?.undimFocus();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final SelahCountdown? countdown = _countdown;
    final bool running = countdown != null;

    return GlassSurface(
      // `tint`, and not `bloom`: `.selah` (`:261-262`) carries no `.bloom` child.
      // It does declare `backdrop-filter: blur(10px)`, which is a second blur site
      // and is refused by §13.4's one-per-app budget — spent, once, on the day's
      // own card. `tint` is also the default, so the line is the comment's — recorded
      // here rather than left for a reader to find in the CSS.
      radius: SelahCard.radius,
      padding: SelahCard.padding,
      // `:263` — `.selah.active{border-color:rgba(232,176,75,.5);
      // background:rgba(232,176,75,.06)}`. The card turns gold while the silence
      // runs, and `GlassSurface`'s two overrides are how it says so.
      //
      // **The prototype TRANSITIONS them** (`:262` — `transition:.3s
      // var(--e-spring)`) and this client does not: the glass surface's
      // decoration is not animated, and animating it would mean a second
      // decoration model in the design system. The change snaps, which is also
      // what §14 asks for under reduced motion.
      fill: running
          ? colors.ember.withValues(alpha: kSelahActiveFillAlpha)
          : null,
      borderColor: running
          ? colors.ember.withValues(alpha: kSelahActiveBorderAlpha)
          : null,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.homeSelah,
                  // `.dt{font-weight:600; font-size:14.5px}` — `:264`, with no
                  // family of its own, so it inherits the route's.
                  //
                  // `arabicAware`, and the word is Arabic on that arm: the I18N
                  // pair at `:970` is `["Selah","سِلاه"]`, tashkeel and all.
                  style: arabicAware(
                    Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: SelahCard.titleSize,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                    direction,
                  ),
                ),
                const SizedBox(height: SelahCard.subtitleGap),
                Text(
                  // **Uppercased under LTR**, like every `.mono` run: `.ds` at `:265`
                  // declares `text-transform: uppercase` and `[dir=rtl] .mono` (`:136`)
                  // removes it on the Arabic arm only.
                  monoCapsText(strings.selahSeconds(widget.seconds), direction),
                  // `.ds{font-family: var(--mono); font-size:9px;
                  // letter-spacing:.14em; text-transform:uppercase; color:var(--ink-2)}`
                  // — `:265`, and `[dir=rtl] .selah .ds` at `:266` swaps the
                  // family for `--ui-ar`, the size for 10.5px and drops the
                  // tracking and the uppercase.
                  //
                  // **`arabicAware` reaches Amiri rather than `--ui-ar`'s IBM Plex
                  // Sans Arabic, and that is this app's rule rather than the
                  // prototype's** — `arabic_typography_gate.dart` asserts every
                  // Arabic run renders in `EvaTypography.arabicFamily`, one family
                  // for the whole arm. Both bundled faces carry the block; the gate
                  // is what chooses.
                  style: arabicAware(
                    EvaTypography.monoCaps(colors).copyWith(
                      fontSize: direction == TextDirection.rtl
                          ? SelahCard.subtitleSizeArabic
                          : SelahCard.subtitleSize,
                      letterSpacing: direction == TextDirection.rtl
                          ? 0
                          : SelahCard.subtitleTracking,
                      color: colors.ink2,
                    ),
                    direction,
                  ),
                ),
              ],
            ),
          ),
          // ## THE COUNT, AND WHERE IT IS DRAWN
          //
          // `:532` — `<span class="mono" id="selahCount" style="color:var(--gold);
          // font-size:16px;display:none">60</span>`. It sits **between** the word
          // block and the button, it is **hidden** until the silence starts, and
          // the prototype's `N()` renders the number in this arm's numerals.
          //
          // The gap is the card's own `gap: 14px` (`:262`), and a hidden element
          // creates no gap in CSS — so the count's `SizedBox` is here rather
          // than a constant gap before the button.
          //
          // **The count is the count, and nothing else.** It used to double as
          // the amen's carrier — the divergence this card recorded before the
          // toast was a shared widget — and the two are now separate: the
          // amen is a **toast** on the home page, anchored to the screen root
          // (`:466`), and the corner is the countdown's alone.
          if (running) ...<Widget>[
            const SizedBox(width: SelahCard.gap),
            Text(
              strings.digits(countdown.remaining),
              style: EvaTypography.monoCaps(colors).copyWith(
                fontSize: kSelahCountSize,
                letterSpacing: 0,
                color: colors.ember,
              ),
            ),
          ],
          const SizedBox(width: SelahCard.gap),
          _BreathingButton(
            active: running,
            label: running ? widget.endLabel : widget.beginLabel,
            onPressed: running ? _stop : _begin,
          ),
        ],
      ),
    );
  }
}

/// The 44px circle with the `✦` in it, and the ring that breathes.
///
/// `redesign.html:267-271`. Private, so the only way to draw one is through
/// [SelahCard] — the same arrangement `AppTopBar`'s `_Avatar` used, and the
/// reason this class's behaviour cannot be bypassed by a call site that forgets
/// to pass a label.
///
/// ## AND THE **RING** IS THE PROTOTYPE'S `breatheRing`
///
/// `:269-270` — `animation:breatheRing 8s ease-in-out infinite`, and `:271` —
/// `.selah.active .breathing{animation-duration:2s;…}` — the same animation at
/// four times the speed while the silence runs.
///
/// **The period is the prototype's and the curve is CSS's `ease-in-out`** —
/// which is byte-for-byte Flutter's `Curves.easeInOut` (`Cubic(0.42, 0, 0.58,
/// 1)`), so the client applies the prototype's own curve and not an
/// approximation of it.
class _BreathingButton extends StatefulWidget {
  const _BreathingButton({
    required this.active,
    required this.label,
    required this.onPressed,
  });

  /// Whether the silence is running.
  final bool active;

  /// The control's accessible name.
  final String label;

  /// Runs when the control is pressed.
  final VoidCallback onPressed;

  @override
  State<_BreathingButton> createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<_BreathingButton>
    with SingleTickerProviderStateMixin {
  /// The ring's clock.
  ///
  /// **A controller of its own, and the §13.2 budget is not engaged.** §13.2's
  /// collapse is about the **ambient** — the prototype's sixty-four orb
  /// animations — and the dock's own beam and ink already own a controller
  /// (`lumen_dock.dart`). A control's own pulse is not an ambient orb.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  /// Whether the ring is currently running.
  ///
  /// **A flag and not the controller's state**, because the controller is
  /// *stopped* under reduced motion and *running* otherwise, and the two are
  /// the same answer asked twice.
  bool _running = false;

  /// The ring's period.
  ///
  /// `:269` — `8s` — and `:271` — `2s` while the silence runs.
  Duration get _period =>
      widget.active ? kSelahActiveRingPeriod : kSelahRingPeriod;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **Not in [initState]**, because `MediaQuery.disableAnimationsOf` is an
    // inherited-widget lookup and Flutter forbids one before
    // `initState` completes. The ring therefore starts on the first
    // dependency pass, which is the framework's own answer to "read an
    // inherited widget".
    _sync();
  }

  @override
  void didUpdateWidget(_BreathingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    // `:271` — the running pulse is the same animation at four times the
    // speed. The phase **restarts**, which is not what CSS does (a changed
    // `animation-duration` keeps the elapsed time and recomputes the
    // progress) — and the restart is the better picture: the silence's
    // faster pulse begins with the silence.
    _controller.duration = _period;
    _controller.repeat();
    _running = true;
  }

  /// Runs the ring, or holds it still under reduced motion.
  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      // §14: "jump straight to the end state". The ring's end state is its
      // **0%/100% keyframe** — `scale(.92)` and no glow — which is the state it
      // rests at, and not the 50% peak.
      _controller.value = 0;
      _controller.stop(canceled: false);
      _running = false;
      return;
    }
    if (_running) return;
    _controller.repeat();
    _running = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Semantics(
      button: true,
      // **Explicitly enabled**, because a node that offers a tap and does not
      // say whether it is enabled reads as `Tristate.none` — and a screen
      // reader is then left to guess. The old inert circle said
      // `enabled: false`; this one says `true`, and the change is the
      // behaviour change.
      enabled: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            // The ring's own keyframes — `:270`:
            // `@keyframes breatheRing{0%,100%{transform:scale(.92);
            // box-shadow:0 0 0 0 rgba(232,176,75,.25)}
            // 50%{transform:scale(1.06);box-shadow:0 0 22px 4px rgba(232,176,75,.28)}}`
            //
            // The triangle is `core/common/cycle_phase.dart`'s, and the curve is
            // CSS's `ease-in-out` — which is `Curves.easeInOut` exactly.
            final double half = halfCycleProgress(_controller.value);
            final double eased = Curves.easeInOut.transform(half);
            final double scale =
                kSelahRingScaleMin +
                (kSelahRingScaleMax - kSelahRingScaleMin) * eased;
            final double glow =
                kSelahRingGlowMin +
                (kSelahRingGlowMax - kSelahRingGlowMin) * eased;

            return Transform.scale(
              scale: scale,
              child: Container(
                width: SelahCard.diameter,
                height: SelahCard.diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.active
                      // `:271` — `.selah.active .breathing{…color:#1c1608;
                      // background:var(--gold)}`. The button fills gold and the
                      // glyph goes to the ink on it.
                      ? colors.ember
                      : colors.ember.withValues(alpha: SelahCard.fillAlpha),
                  border: Border.all(
                    color: widget.active
                        ? colors.ember
                        : colors.ember.withValues(alpha: SelahCard.rimAlpha),
                    width: SelahCard.rimWidth,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colors.ember.withValues(alpha: glow),
                      blurRadius: glow,
                      spreadRadius: kSelahRingGlowSpread,
                    ),
                  ],
                ),
                child: FourPointedStar(
                  size: SelahCard.glyphSize,
                  // `colors.ember` passed rather than baked into the star:
                  // `:267-268`'s `rgba(232,176,75,.6)` rim and
                  // `rgba(232,176,75,.08)` fill are the *circle's*, and the glyph
                  // inside it is the prototype's `--gold` at full strength —
                  // which on this palette is `ember`, not the 60%-alpha rim a
                  // reader would otherwise expect from a 44px ring. See
                  // `four_pointed_star.dart`'s `color` for why the widget takes
                  // it.
                  //
                  // **And the ink flips when the circle fills** — `:271`'s
                  // `color:#1c1608`, which is the prototype's ink on its gold.
                  color: widget.active ? colors.onEmber : colors.ember,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The ring's period while the silence is **not** running.
///
/// `eva/redesign.html:269` — `animation:breatheRing 8s ease-in-out infinite`.
const Duration kSelahRingPeriod = Duration(seconds: 8);

/// The ring's period while the silence **is** running.
///
/// `eva/redesign.html:271` — `.selah.active .breathing{animation-duration:2s;…}`.
const Duration kSelahActiveRingPeriod = Duration(seconds: 2);

/// The ring's smallest scale. `eva/redesign.html:270` — `0%,100%{transform:
/// scale(.92);…}`.
const double kSelahRingScaleMin = 0.92;

/// The ring's largest scale. `eva/redesign.html:270` — `50%{transform:
/// scale(1.06);…}`.
const double kSelahRingScaleMax = 1.06;

/// The ring's smallest glow. `eva/redesign.html:270` — `0 0 0 0`.
const double kSelahRingGlowMin = 0;

/// The ring's largest glow. `eva/redesign.html:270` — `0 0 22px 4px`.
const double kSelahRingGlowMax = 22;

/// The ring's glow's spread. `eva/redesign.html:270` — the `4px` of
/// `0 0 22px 4px`.
const double kSelahRingGlowSpread = 4;

/// The card's gold wash while the silence runs.
///
/// `eva/redesign.html:263` — `background:rgba(232,176,75,.06)`.
const double kSelahActiveFillAlpha = 0.06;

/// The card's gold rim while the silence runs.
///
/// `eva/redesign.html:263` — `border-color:rgba(232,176,75,.5)`.
const double kSelahActiveBorderAlpha = 0.5;

/// The count's size. `eva/redesign.html:532` — `font-size:16px`.
const double kSelahCountSize = 16;

/// The spike the aurora takes when the silence ends.
///
/// `eva/redesign.html:1330` — `if(V)V.spike=.5;`.
///
/// ## AND IT IS **ASSIGNED**, NOT ACCUMULATED
///
/// `LumenScene.raiseSpike`'s doc says the same of the prototype: `V.spike=.5`
/// is an assignment, and a caller that raises the spike while another is
/// decaying it replaces it rather than adding to it.
const double kSelahCompletionSpike = 0.5;
