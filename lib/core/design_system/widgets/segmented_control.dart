import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The value one step along [values] from [selected], wrapping at both ends.
///
/// The keyboard model Phase 3's gate names — "`SegmentedControl` selects via
/// keyboard" — is this function plus the direction below it. The prototype had
/// no keyboard model at all: its theme picker is three `<button>`s whose state
/// lives in a `useState` (`SettingsScreen.tsx:6,52-61`) and whose only input is
/// a click. A control a keyboard cannot reach is the §14 defect this widget is
/// built to close, so the model is written down and pinned before the widget.
///
/// **Wrapping rather than clamping.** Material's `SegmentedButton` clamps at the
/// ends, so ArrowRight on the last segment does nothing. Wrapping is the
/// behaviour a radio group has everywhere else in every platform, and it is what
/// makes "how many options are there?" answerable by pressing a key twice.
///
/// The four edge cases are deliberate and each one is a real state:
///
/// - an **empty** list returns `null` — nothing to select, and the widget
///   renders nothing;
/// - a **single** value returns itself — a one-option segmented control is a
///   label, and ArrowRight must not be a crash;
/// - a [selected] value **outside** the list snaps to an end. That is reachable
///   when a persisted setting names a value a rebuilt enum no longer has, and
///   returning `null` there would leave the control drawing no selection at all.
///   **"Snaps to the nearest end" is a claim about `abs(step) == 1`, and only
///   about that**: the `-1` branch is `index = values.length`, which is "one
///   before the first", so a forward step lands on `first` and a backward step
///   lands on `last`. It reads as a general property and is not one —
///   `step: 5` from an out-of-list `selected` in a three-item list wraps to the
///   **middle** (`'Dark'`), because the arithmetic below is modular and nothing
///   clamps it. `abs(step) == 1` is the only step this widget ever produces
///   ([selectionStepFor] returns `±1`, and [Home] / [End] are absolute rather
///   than expressed as a step), and it is the only step the tests cover — the
///   function is a model for this widget's keyboard, not a general list-stepper.
/// - any other `T` works. The widget is `SegmentedControl<T>` precisely so
///   `AppThemeMode` and `ReadingLanguage` share it.
T? nextSelection<T>({
  required List<T> values,
  required T selected,
  required int step,
}) {
  if (values.isEmpty) return null;
  if (values.length == 1) return values.first;
  final int index = values.indexOf(selected);
  final int from = index < 0 ? (step > 0 ? -1 : values.length) : index;
  final int next = (from + step) % values.length;
  return values[(next + values.length) % values.length];
}

/// The list step for an arrow key press.
///
/// [logicalKeyForward] is true for ArrowRight and false for ArrowLeft. In an RTL
/// screen "forward" is leftwards, so the two swap: without this, ArrowRight
/// walks an Arabic reader's options **backwards**, which is the same class of
/// bug as defect #2 (Arabic laid out with Latin assumptions).
int selectionStepFor({
  required TextDirection direction,
  required bool logicalKeyForward,
}) => direction == TextDirection.ltr
    ? (logicalKeyForward ? 1 : -1)
    : (logicalKeyForward ? -1 : 1);

/// A segmented picker over any enum or value type.
///
/// `04-widget-inventory.md` §3 collapses two prototype controls into this one:
/// the Settings **theme** picker (`SettingsScreen.tsx:51-62`) and the **language**
/// pills (`:77-90`). They disagree on shape — the theme picker is one joined
/// track, the language pills are two separate pills — and this widget transcribes
/// the **joined track**, which is the one with a track to press, because a
/// segmented control with no track is two buttons.
///
/// ## THE KEYBOARD MODEL, WHICH THE PROTOTYPE HAS NONE OF
///
/// One tab stop for the whole control, and arrow keys move *within* it. That is
/// the roving-focus pattern, and it is the correct one: three separately
/// focusable segments means Tab visits all three before leaving the control, so
/// a reader tabbing past a settings group stops three times for one answer.
///
/// - `ArrowRight` / `ArrowLeft` — change the selection through
///   [nextSelection] / [selectionStepFor], and **do not** let the default
///   `HorizontalTraversalIntent` move focus out. Handling it here is why
///   [EvaFocusRing.onKeyEvent] exists.
/// - `Home` / `End` — first and last, the convention for every list and slider.
/// - `Tab` — leaves. One press, one exit.
///
/// ## THE THUMB, AND THE SENTENCE THAT USED TO SAY IT DID NOT EXIST
///
/// This doc read "There is no hover-only affordance, no animated sliding thumb,
/// and no `selectedIcon`." **The middle clause was wrong and Phase 4.2 removes
/// it.** `redesign.html:179-182` is a `.segp .thumb`: absolutely positioned,
/// `top:3px;bottom:3px;left:3px`, `width:0` at rest, a gold
/// `linear-gradient(180deg, rgba(232,176,75,.95), rgba(232,176,75,.72))` with
/// `box-shadow:0 0 14px rgba(232,176,75,.45), inset 0 0 10px rgba(255,255,255,.28)`,
/// transitioning `left` **and** `width` over `.35s` on `var(--e-spring)`.
///
/// The prototype's React predecessor had no thumb — `SettingsScreen.tsx:56`
/// animated each button's own background — so the widget transcribed a control
/// that no longer exists in the design. What is left of the old claim is
/// accurate and kept: there is no hover-only affordance and no `selectedIcon`,
/// and the selection is still **announced** rather than merely coloured, so §14's
/// colour-only ban does not bite.
///
/// The thumb **replaces** the per-segment fill. That is a real behaviour change
/// and not only a visual one: `redesign.html:183-184`'s `button` has
/// `background:none`, and `:183`'s `z-index:2` puts the labels above the thumb
/// (which is `:182`'s `pointer-events:none`), so nothing paints a fill behind a
/// selected segment any more.
class SegmentedControl<T> extends StatefulWidget {
  /// A picker over [values], showing [selected].
  const SegmentedControl({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.semanticLabel,
    this.labelFamilyOf,
    this.wide = false,
    super.key,
  });

  /// Whether the control is the prototype's **wide** geometry.
  ///
  /// `redesign.html:188-189`:
  ///
  /// ```css
  /// .segp.wide{width:100%}
  /// .segp.wide button{padding:12px 0;font-size:11px}
  /// ```
  ///
  /// **A separate, opt-in geometry — it does not re-open the default mode's
  /// decision.** The default mode deliberately refuses the prototype's equal
  /// thirds, and the reason is written down on [SegmentedControl.segmentPadding]
  /// and in `_measureThumb`'s doc: a control that stops hugging its own content
  /// is a different control, and the default mode is used by every control the
  /// app has today.
  ///
  /// The wide mode exists for a **measured** reason, not a taste one: the
  /// four-segment control cannot share a row with a 14.5px label at 320px, and
  /// the standing 320×568 viewport matrix is a gate. The arithmetic is in
  /// [wideTrackMinimumWidth]'s doc.
  final bool wide;

  /// The family an option's label renders in, **when the label's script needs a
  /// different face from the control's**.
  ///
  /// ## WHY THIS EXISTS, MEASURED
  ///
  /// `redesign.html:186` — `.segp button[data-l=ar]{font-family:var(--ar);
  /// font-size:13px; text-transform:none}` — keys that face on the **option**, and
  /// `:191` keys the Latin option back to the mono face under RTL. So the rule is
  /// two-sided, and it is not the direction: on the **English** arm the Arabic
  /// option is still Amiri, because the selector is `data-l=ar`.
  ///
  /// A single `arabicAware` cannot express that — it is direction-keyed, so it is
  /// the identity on an LTR screen and the family swap on an RTL one — and the
  /// result on `/reading`'s dial was measured by the tofu gate: `ع` rendered in
  /// **JetBrains Mono** on the English arm, a face with no Arabic glyphs, reported
  /// as `(family: JetBrainsMono, label: ع)`. The Arabic arm was already correct,
  /// which is exactly the signature of a direction-keyed rule standing in for a
  /// label-keyed one.
  ///
  /// **`null` for every other caller**, because every other option in the app is
  /// Latin script and `arabicAware` already serves `/settings`'s theme labels —
  /// which are *wholly* Arabic, so the direction decides for them. The case here is
  /// a label that is Arabic **inside a Latin screen**: one character of one
  /// language, which only the option knows about.
  final String Function(T value)? labelFamilyOf;

  /// Every option, in paint order.
  final List<T> values;

  /// The chosen option. Must be one of [values].
  final T selected;

  /// The label for an option. A function rather than a `labelBuilder` callback
  /// taking an index, so a caller cannot read the wrong element of [values].
  final String Function(T) labelOf;

  /// The **track's** accessible name, or `null` for [labelOf] of the selected value.
  ///
  /// ## WHY A CALLER STRING, AND WHAT IT FIXES
  ///
  /// Phase 10 measured the default's result on `/settings`' theme picker, and it put
  /// **two activatable nodes on screen with the identical label**:
  ///
  /// ```text
  /// lbl="Dark"  tap=true  btn=false  sel=none     <- the track
  /// lbl="Dark"  tap=true  btn=true   sel=isTrue   <- the selected segment
  /// ```
  ///
  /// That is §14's failure in the one form this repository has already had once: one
  /// string naming two focusable, activatable nodes, which is what
  /// `reading_accessibility_test.dart` caught when `readingTextSize` described both
  /// the `Aa` disclosure and the slider it reveals and
  /// `app_localizations_test.dart` then forced apart into two keys. A screen reader
  /// reaches the track and hears the name of one of the track's own options.
  ///
  /// **The fix is a distinct string, not the removal of the track's node.** The
  /// comment at the `Semantics` below gives the measured reason the node has to exist
  /// at all — it is the only thing binding `EvaFocusRing`'s node into the focus tree —
  /// so it cannot be dropped, and a node with no name is the failure that comment says
  /// it already fixed once.
  ///
  /// ## AND WHY IT IS **OPTIONAL** RATHER THAN REQUIRED
  ///
  /// Unlike `EvaButton.labelFamily` (decision 66, required) and
  /// `FontSizeStepperLabels` (also required), requiring it here would make every
  /// caller name the control **and** its options, and [labelOf] already covers the
  /// options. The duplicate only exists because the track's fallback is drawn from
  /// that same list. A caller with a noun gets the correct shape; a caller without one
  /// still gets a **named** track — a duplicate, which is the state this repository
  /// shipped for nine phases, rather than an unnamed control, which is what the
  /// parameter's absence used to risk reintroducing.
  ///
  /// `SettingsPage` is the caller that passes it, with the row title it already draws
  /// — so the track is named "Theme", the segments are named "Light", "Dark" and
  /// "System", and no two activatable nodes collide. The row's painted title repeats
  /// "Theme" once, and that node is **not** activatable, which is the distinction
  /// `home_accessibility_test.dart`'s "the streak is ONE node, not two" turns on.
  final String? semanticLabel;

  /// Reports the new selection, already resolved through [nextSelection].
  final ValueChanged<T> onChanged;

  /// The track's radius. `redesign.html:178` — `border-radius:999px`.
  ///
  /// **Was** `SettingsScreen.tsx:51`'s `borderRadius: 8`, which is the number
  /// the old `.segp` never had. [EvaRadii.chip], so it is a token rather than a
  /// literal 999 — the redesign writes `999px` and `99px` in different places
  /// (`:178`, `:184`) and they are the same intent.
  ///
  /// One constant covers three elements, which is what the prototype does too:
  /// `.segp` (`:178`), `button` (`:184`'s own `border-radius:999px`) and the
  /// ink/ring around the whole control. All three are pills in the redesign, so
  /// splitting them would be three names for one number.
  static const double trackRadius = EvaRadii.chip;

  /// The track's padding, and therefore the thumb's inset.
  /// `redesign.html:178` — `padding:3px`, which `:179`'s `top:3px;bottom:3px;
  /// left:3px` matches exactly.
  ///
  /// **Was** [EvaSpacing.xs], which is also 4 — so this reads as a no-change and
  /// is not. `4` and `3` are both off the 4px scale, and the thumb's three
  /// insets are the prototype's own; keeping 4 would put the thumb 1px off its
  /// declared `left` on every selection change.
  static const double trackPadding = 3;

  /// Horizontal padding per segment. `SettingsScreen.tsx:58` —
  /// `padding: 5px 10px`.
  ///
  /// **Kept, and it is a divergence.** `redesign.html:184` says `8px 10px`; this
  /// ships [EvaSpacing.md] (12) horizontal and [EvaSpacing.xs] (4) vertical,
  /// which is neither prototype number. Re-pointing the padding was not in this
  /// phase's scope for this widget and the label's own `:183` size is the same
  /// story — recorded here so a reader comparing `:184` against this constant
  /// finds the difference named rather than discovering it.
  static const EdgeInsets segmentPadding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.md,
    vertical: EvaSpacing.xs,
  );

  /// The wide mode's label size. `redesign.html:189` — `font-size:11px`.
  ///
  /// **The wide mode transcribes `:189`'s own size rather than reusing the
  /// default mode's**, and the reason is arithmetic rather than taste. At 320px
  /// the content column is `320 − 2×24` = 272px, the row's own horizontal
  /// padding is 4px a side, so the row is 264px; the track's own
  /// `padding:3px` and 1px rim (`:178`) take 8 of it, so the four segments
  /// share **256px — 64 each**. "SHAFTS" at 11 × 1.22 = 13.4px in the mono
  /// face is about 54px — it fits, and `padding:12px 0` (zero horizontal) is
  /// what makes it fit. With the default mode's 12sp mono and 12px horizontal
  /// padding it would not.
  static const double wideLabelSize = 11;

  /// The wide mode's button padding. `redesign.html:189` — `padding:12px 0`.
  ///
  /// **Vertical 12, horizontal 0** — the CSS order.
  static const EdgeInsets wideSegmentPadding = EdgeInsets.symmetric(
    vertical: 12,
  );

  /// The label's tracking, in em. `redesign.html:184` — `letter-spacing:.08em`.
  ///
  /// **Premultiplied by the label's own size before it becomes a Flutter
  /// `letterSpacing`**, because Flutter's is a logical-pixel advance and CSS's
  /// is relative to the element's own font. See [wideLabelLetterSpacing] and
  /// the house rule in `stat_tile.dart:142-147`.
  static const double labelTracking = 0.08;

  /// The wide mode's label tracking, in logical pixels. **0.88.**
  ///
  /// `11 × 0.08`. The raw `0.08` would be **eight to twelve times too
  /// small**, and that is the single most likely defect in this widget: the
  /// handoff's lesson 1 records 5.6 shipping seven sites with the raw `em`
  /// number.
  static const double wideLabelLetterSpacing = wideLabelSize * labelTracking;

  /// The tap-target floor for one segment. `redesign.html:183` —
  /// `min-width:44px`.
  static const double segmentMinWidth = 44;

  /// The wide track's minimum width: the floor for every segment, times the
  /// number of segments.
  ///
  /// ## WHY THE FLOOR IS REAL, AND WHY IT IS NOT THE SAME AS CSS'S
  ///
  /// `redesign.html:183` gives every button `min-width:44px` alongside
  /// `flex:1`, and the floor is a **tap-target** floor: a segment narrower than
  /// 44px is a target a finger cannot reliably hit.
  ///
  /// The brief's arithmetic is what makes this mode exist at all: at 320px the
  /// content column is `320 − 2×24` = **272px**, the row's own horizontal
  /// padding is 4px a side (`redesign.html:419`), so the row is **264px**, and
  /// the four-segment control's minimum is `4 × 44 = 176px`. A 14.5px label
  /// ("Curtain shape", about 88px) would then have `264 − 176 − 10 = 78px` and
  /// wrap to two lines. The three segmented rows therefore put the label
  /// **above** the control, and the control takes the row's full width — which
  /// gives the segments 256px, **64 each**, against the prototype's own 44px
  /// floor.
  ///
  /// **CSS would overflow its container rather than shrink; Flutter's
  /// constraints clamp instead.** So on a row narrower than the floor the
  /// segments would fall below 44px here, where the prototype would have
  /// overflowed. The floor holds wherever it is measured — the 320×568 matrix
  /// gives the wide rows 264px, which is 66px a segment — and the clamp is
  /// recorded here rather than pretended away.
  static double wideTrackMinimumWidth(int count) => segmentMinWidth * count;

  /// The thumb's slide. `redesign.html:182` —
  /// `transition:left .35s var(--e-spring),width .35s var(--e-spring)`.
  ///
  /// 350ms is not a token. [EvaMotion] has `fast` 150, `base` 200, `screen` 250
  /// and `screenCubic`-adjacent curves, and **none** of them is 350 — so this is
  /// a named constant on the widget rather than a rounding of an existing step,
  /// which is the rule `SegmentedControl`'s own `EvaMotion.base` comment states
  /// ("that is `EvaMotion.base` exactly, so unlike the button's 180ms this one
  /// needed no rounding"). Here it did need one, and the number is written down
  /// rather than approximated with 250 or 400.
  static const Duration thumbDuration = Duration(milliseconds: 350);

  /// The thumb's outer glow. `redesign.html:181` — `0 0 14px rgba(232,176,75,.45)`.
  ///
  /// [EvaColors.ember] at `.45`, and 14 is [kGlassSeamGlowBlur]'s number too —
  /// the redesign uses `0 0 14px` for the thumb's glow and for `.hor`'s
  /// (`redesign.html:257`), which is why it is spelled here rather than imported:
  /// a glass seam's radius living in `glass_surface.dart` is not a dependency a
  /// segmented control should have.
  static const double thumbGlowBlur = 14;

  /// The thumb's inner sheen radius. `redesign.html:181` —
  /// `inset 0 0 10px rgba(255,255,255,.28)`.
  static const double thumbSheenBlur = 10;

  /// The thumb's fill. `redesign.html:180` —
  /// `linear-gradient(180deg,rgba(232,176,75,.95),rgba(232,176,75,.72))`.
  ///
  /// [EvaColors.ember] at two alphas. The prototype's `#E8B04B` is `--gold` in
  /// dark; this palette's dark `ember` is `#E8A33D`, which is Phase 2's settled
  /// value and not this phase's to revisit. **Both palettes use it** — `:69`'s
  /// light override re-points the `.segp` **track** and never the thumb, so a
  /// light thumb is the same gold gradient, and `redesign.html:185`'s `.on`
  /// colour is likewise not overridden.
  static const double thumbFillTop = 0.95;

  /// The thumb's fill at its bottom edge. `redesign.html:180`'s `.72`.
  static const double thumbFillBottom = 0.72;

  /// The thumb's outer glow alpha. `redesign.html:181` — `rgba(232,176,75,.45)`.
  static const double thumbGlowAlpha = 0.45;

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  /// One key per segment, in [SegmentedControl.values] order.
  ///
  /// Sized in [initState] and trimmed in [didUpdateWidget], so a `values` list
  /// that grows or shrinks cannot leave a stale key pointing at a segment that no
  /// longer exists — the thumb would then slide to a rectangle belonging to
  /// another value.
  late List<GlobalKey> _segmentKeys = _keysFor(widget.values.length);

  /// The `Stack` the thumb is positioned inside, which is the track's **content
  /// box** — inside the border and the [SegmentedControl.trackPadding], exactly
  /// as CSS positions `.segp .thumb` against the padding box of its
  /// `position:relative` parent.
  final GlobalKey _trackKey = GlobalKey(debugLabel: 'segp.track');

  /// The measured thumb rectangle, or `null` until the first frame that can
  /// measure one.
  ///
  /// **`null` means the thumb is not painted**, which is a one-frame decision and
  /// not a fudge: the alternative is painting it at a guessed position and then
  /// animating away from the guess, which is the version a reader sees as the
  /// control jumping. The thumb is a [Positioned] child, so while it is missing
  /// **nothing else changes size** — the [Row] is the only thing that measures
  /// the track, and every geometry harness reads the track.
  double? _thumbLeft;
  double? _thumbWidth;

  static List<GlobalKey> _keysFor(int count) => <GlobalKey>[
    for (int i = 0; i < count; i++) GlobalKey(debugLabel: 'segp.segment.$i'),
  ];

  /// The prototype transitions `all 200ms` (`SettingsScreen.tsx:59`). That is
  /// `EvaMotion.base` exactly, so unlike the button's 180ms this one needed no
  /// rounding to a token.
  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureThumb());
  }

  @override
  void didUpdateWidget(SegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length) {
      _segmentKeys = _keysFor(widget.values.length);
    }
    // A changed *value* is the ordinary case and needs no key churn, but it does
    // need a re-measure: the thumb has to be somewhere before the frame that
    // animates it to somewhere else.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureThumb());
  }

  /// Reads the selected segment's rect out of the laid-out tree.
  ///
  /// ## WHY A POST-FRAME CALLBACK AND NOT A [LayoutBuilder]
  ///
  /// A `LayoutBuilder` can report the **track's** width, and that is all it can
  /// report: the thumb's width is the selected *segment's*, and a segment's width
  /// is its label's intrinsic width plus [SegmentedControl.segmentPadding]. The
  /// segments are [Flexible] (loose) in a `Row(mainAxisSize: MainAxisSize.min)`,
  /// so "the width of segment *i*" is not arithmetic on any number this widget
  /// holds — it is what the layout produced. `Expanded` would make it arithmetic,
  /// and `redesign.html:183`'s `flex:1` does say `flex:1`, but a `Row` with
  /// `mainAxisSize: min` hands an `Expanded` child `maxWidth: infinity` and
  /// throws, so equal thirds would mean `mainAxisSize: max` and a control that
  /// stops hugging its own content. **The prototype's equal thirds are the one
  /// thing deliberately not transcribed**, and the reason is recorded on
  /// [SegmentedControl.segmentPadding].
  ///
  /// So the thumb's geometry is **measured**, which is the difference the Phase 4
  /// brief asks for: nothing here is a guess, an average, or a fraction of the
  /// track that assumes the segments are equal.
  ///
  /// ## AND WHAT THE DEFAULT MODE **RENDERS** TODAY, MEASURED
  ///
  /// The mechanism above is not the same as the rendering, and a reader
  /// comparing this mode with the wide one needs both. The `_Segment`'s
  /// `Container(alignment: Alignment.center)` expands to the **flex
  /// allocation** it is handed, so the default mode's segments come out
  /// **equal** — measured at **104px each** in a 320px surface with a
  /// three-segment control — and the track comes out **full width**.
  ///
  /// **The prototype's equal thirds are still not *transcribed*.** They are
  /// what the layout *produced*, not what this widget *asked for*: the widths
  /// are not arithmetic on any number the widget holds, and a change to the
  /// segment's own box — a wider label, a different padding — moves them.
  /// The **wide** mode is the one that *asks* for them (`Expanded`, a tight
  /// share each), which is what makes its geometry a **guarantee** rather than
  /// an outcome. That contrast is the reason the two modes are separate.
  void _measureThumb() {
    if (!mounted) return;
    final RenderObject? track = _trackKey.currentContext?.findRenderObject();
    if (track is! RenderBox || !track.hasSize) return;

    final int index = widget.values.indexOf(widget.selected);
    // An out-of-list `selected` — the case [Semantics]'s label below already
    // guards for — has no segment to sit on, so the thumb stays where it is
    // rather than sliding to a rectangle that is not there.
    if (index < 0 || index >= _segmentKeys.length) return;

    final RenderObject? segment = _segmentKeys[index].currentContext
        ?.findRenderObject();
    if (segment is! RenderBox || !segment.hasSize) return;

    final Offset at = segment.localToGlobal(Offset.zero, ancestor: track);
    if (at.dx == _thumbLeft && segment.size.width == _thumbWidth) return;
    setState(() {
      _thumbLeft = at.dx;
      _thumbWidth = segment.size.width;
    });
  }

  /// Moves the selection by [step] list positions.
  ///
  /// Wrapped in one [AnimatedPositioned] rather than one animated container per
  /// segment, because the prototype's prototype animated each button's own
  /// background (`SettingsScreen.tsx:56,59`) and `redesign.html:182` replaced
  /// that with **one** element that moves. The comment this replaces said "there
  /// is no moving thumb in the prototype to animate" — true of the React
  /// prototype, false of `redesign.html` since Phase 4.2.
  void _move(int step) {
    final T? next = nextSelection<T>(
      values: widget.values,
      selected: widget.selected,
      step: step,
    );
    // `null` only when `values` is empty, and then the widget draws nothing, so
    // there is nothing to report.
    if (next == null) return;
    widget.onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final int? step = switch (key) {
      LogicalKeyboardKey.arrowRight => selectionStepFor(
        direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        logicalKeyForward: true,
      ),
      LogicalKeyboardKey.arrowLeft => selectionStepFor(
        direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        logicalKeyForward: false,
      ),
      _ => null,
    };
    if (step != null) {
      _move(step);
      return KeyEventResult.handled;
    }
    // Home/End are **absolute**, so they cannot be expressed as a fixed step:
    // `-values.length` from the middle of a three-item list wraps back to the
    // middle, which is a Home key that does nothing. Confirmed by the test that
    // failed before this was fixed.
    if (key == LogicalKeyboardKey.home && widget.values.isNotEmpty) {
      widget.onChanged(widget.values.first);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && widget.values.isNotEmpty) {
      widget.onChanged(widget.values.last);
      return KeyEventResult.handled;
    }
    // Everything else, Tab included, is the framework's business. Returning
    // `ignored` here is what lets Tab leave in one press.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const SizedBox.shrink();
    }
    final EvaColors colors = context.colors;

    // The name of the whole control, for the track's own node. See the return
    // below for why it needs one, and [semanticLabel] for why it is a caller's
    // string whenever the caller has one.
    //
    // The fallback is guarded, because `nextSelection`'s doc records that an
    // out-of-list
    // `selected` is reachable — a persisted setting naming a value a rebuilt enum
    // no longer has — and `labelOf` is the caller's function over `values`, so
    // calling it with a value the list does not contain is a crash in `build`.
    // The first option is the fallback, and it is the same end a forward step
    // snaps to.
    final String controlLabel =
        widget.semanticLabel ??
        widget.labelOf(
          widget.values.contains(widget.selected)
              ? widget.selected
              : widget.values.first,
        );

    final List<Widget> segments = <Widget>[
      for (final (int i, T value) in widget.values.indexed)
        _Segment<T>(
          key: _segmentKeys[i],
          label: widget.labelOf(value),
          labelFamily: widget.labelFamilyOf?.call(value),
          selected: value == widget.selected,
          colors: colors,
          animate: _animate,
          wide: widget.wide,
          // Taps are per segment, so the segments are individual
          // `InkWell`s — but they take **no** focus node, because the
          // control's single tab stop is the ring's node above them.
          onTap: () => widget.onChanged(value),
        ),
    ];

    final Widget track = Container(
      // `redesign.html:178` —
      // `border:1px solid var(--glass-line)`, `border-radius:999px`,
      // `background:rgba(255,255,255,.05)`, `padding:3px`.
      //
      // `redesign.html:69` re-points both the fill and the rim in light
      // (`rgba(20,22,30,.06)` / `rgba(20,22,30,.16)`), and
      // [EvaColors.glassFill] / [EvaColors.glassBorder] are this design system's
      // transcriptions of exactly those two roles. The rim is **new**: the old
      // `SettingsScreen.tsx:51` track had no `border` at all, only a fill.
      padding: const EdgeInsets.all(SegmentedControl.trackPadding),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Stack(
        // ## `StackFit.passthrough`, AND IT IS NOT OPTIONAL
        //
        // `glass_surface.dart` records the measurement: `StackFit.loose` — the
        // **default** — is `constraints.loosen()`, and inserting a `Stack` under
        // it shrink-wrapped three panels to the width of their own text and
        // diffed `stat_tile_{dark,light}.png` by 2177px (1.20%). The same trap is
        // open here and was left open by whoever wrote the first version of this
        // thumb: `loose` would loosen the constraints the `Row` receives, so in a
        // tight box the control would stop filling it.
        //
        // `passthrough` hands non-positioned children `constraints` verbatim, so
        // the `Row` below measures exactly what it measured before the `Stack`
        // existed — the pre-thumb chain, which is what every geometry harness and
        // every golden of this control was recorded against.
        fit: StackFit.passthrough,
        key: _trackKey,
        children: <Widget>[
          // ## THE THUMB IS THE **FIRST** CHILD, AND THE ORDER IS THE FIX
          //
          // `redesign.html:183` puts `z-index:2` on the `button` and `:182` puts
          // `pointer-events:none` on the thumb: in the prototype the **labels paint
          // above** the thumb. A `Stack` paints its children in list order, last on
          // top, so the labels have to come **second**.
          //
          // The first version of this widget had it the other way round, and the
          // thumb's own fill — `:180`'s gold gradient at 0.95→0.72 alpha — painted
          // over the selected label. Measured by reading the rendered pixels
          // rather than the style objects: the selected label against the thumb
          // beneath it was **1.015:1 dark and 1.033:1 light**, where §14 asks
          // 4.5:1. It is not that the label was "low contrast" — at 0.95 alpha it
          // was gone.
          //
          // **Why no test caught it**, stated because it is the generalisable part:
          // every assertion in this file's suite read the widget tree or a
          // `TextStyle`, and both are correct while the pixels are not. The suite
          // was green for a control whose selected label was invisible. The fix is
          // only durable if something reads the **painted result**, so
          // `segmented_control_test.dart` now samples the label's own rectangle
          // out of the rendered layer.
          if (_thumbLeft != null && _thumbWidth != null)
            AnimatedPositioned(
              // `:179` — `top:3px;bottom:3px`, and the `left`/`width` that
              // `:182` transitions. Inside the content box both are 0, because
              // the padding the prototype insets from *is* this box's edge.
              left: _thumbLeft,
              top: 0,
              bottom: 0,
              width: _thumbWidth,
              duration: _animate
                  ? SegmentedControl.thumbDuration
                  : Duration.zero,
              // `var(--e-spring)` is `cubic-bezier(.34,1.56,.64,1)` — a slow
              // start that **overshoots** and settles. No `EvaMotion` curve is
              // that: `interactiveCurve` (`easeOutExpo`) is fast-out with no
              // overshoot, and `Curves.easeOutBack` overshoots but starts fast.
              // `easeOutExpo` is taken because it is an existing token and
              // inventing a curve for one widget is the same token-table bloat
              // `kGlassSeamGlowBlur`'s doc declines; the missing overshoot is
              // recorded rather than approximated with a second curve.
              curve: EvaMotion.interactiveCurve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    SegmentedControl.trackRadius,
                  ),
                  // `:180` — a 180deg (top-to-bottom) gold gradient.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      colors.ember.withValues(
                        alpha: SegmentedControl.thumbFillTop,
                      ),
                      colors.ember.withValues(
                        alpha: SegmentedControl.thumbFillBottom,
                      ),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    // `:181` — `0 0 14px rgba(232,176,75,.45)`.
                    BoxShadow(
                      color: colors.ember.withValues(
                        alpha: SegmentedControl.thumbGlowAlpha,
                      ),
                      blurRadius: SegmentedControl.thumbGlowBlur,
                    ),
                    // `:181` — `inset 0 0 10px rgba(255,255,255,.28)`.
                    //
                    // The white is [EvaColors.emberSheen] rather than a literal
                    // because the colour gate resolves every colour in `lib/`
                    // through a token and there is no white in this palette that
                    // means "a sheen on a gold fill" in **both** modes — `ink`
                    // inverts and `seam` is re-hued gold in light. See that
                    // token's doc.
                    BoxShadow(
                      color: colors.emberSheen,
                      blurRadius: SegmentedControl.thumbSheenBlur,
                    ),
                  ],
                ),
              ),
            ),
          // **Second, and only because it is second.** See the z-order block above
          // the thumb: `redesign.html:183`'s `z-index:2` is this line.
          Row(
            // ## THE WIDE MODE'S TWO LAYOUT DECISIONS, AND THEY ARE **EXPLICIT**
            //
            // `:188` — `.segp.wide{width:100%}` — and `:183`'s `flex:1`, which
            // is the prototype's equal thirds.
            //
            // The wide mode takes the available width by construction
            // (`mainAxisSize: max`) and its segments are equal by construction
            // (`Expanded`, which hands each child a **tight** share of the
            // track). The default mode leaves both to the layout — its segments
            // are `Flexible` (loose) in a `mainAxisSize: min` row — and
            // `_measureThumb`'s doc records what that actually renders.
            //
            // **The difference is guarantee versus outcome**, and it is the
            // whole reason the mode is separate. The default mode's equal
            // thirds today are an *emergent* property of the segment's own box
            // expanding to its flex allocation; the wide mode's are *asked
            // for*, so a change to a label's width cannot move them.
            mainAxisSize: widget.wide ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              for (final Widget segment in segments)
                // `Expanded` in the wide mode, `Flexible` in the default one.
                // The default's tree is **unchanged** — `Flexible` is what it
                // has always used, and the goldens of the default mode are
                // recorded against it.
                widget.wide
                    ? Expanded(child: segment)
                    : Flexible(child: segment),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      // ## WHY THE TRACK'S NODE IS NAMED
      //
      // This node is a **button** — the `EvaInk` below publishes a tap action on
      // it — and it used to carry no label at all, so `/settings` shipped two
      // buttons (the theme picker and the language pills) that a screen reader
      // could land on and could not name. That is §14's first row applied to a
      // widget the row does not mention by name, and it is the same shape as the
      // unnamed `IconActionButton` the row *does* name.
      //
      // The obvious alternative — dropping the track's `onPressed` so only the
      // three labelled segments are actionable — **breaks the keyboard model**,
      // and the reason is `EvaFocusRing`'s: the ring owns the `FocusNode` but
      // inserts no `Focus`, because `InkResponse` builds one internally and a
      // second would make the node its own parent. The `EvaInk` below is the only
      // thing that binds that node into the focus tree, so a track with no
      // `onPressed` is a control Tab cannot reach at all. The node is therefore
      // load-bearing and has to be named.
      //
      // `labelOf(selected)` is the name because it is the one fact about the
      // control that is true at every moment, and it is the fact the arrow keys
      // are about to replace. A second string meaning "advance the selection"
      // would be more descriptive and is not available: this is a bilingual app
      // with no string table yet, and `ErrorView.retryLabel` and
      // `ProgressBeads.semanticLabel` both record that a design-system widget
      // does not invent an English string.
      label: controlLabel,
      child: EvaFocusRing(
        // No `idleBorder`: the prototype's track has none, and a rim around the
        // whole control would double the track's own edge.
        radius: SegmentedControl.trackRadius,
        onKeyEvent: _onKey,
        child: EvaInk(
          // The ring's node is the control's tab stop; the `InkWell` here only
          // supplies the ink for a tap that lands on the track's padding.
          onPressed: () => _move(1),
          borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
          // ## THE WIDE MODE'S FLOOR, AND IT IS THE **TRACK'S** WIDTH
          //
          // `:183` gives every button `min-width:44px`. In CSS that is a floor
          // on the button; in Flutter the honest translation is a floor on the
          // **track**, because the track is what hands the buttons their
          // widths — so the track's minimum is `44 × the number of segments`
          // and every button inherits its share of it.
          //
          // **The default mode has no floor**, and that is not an oversight:
          // the default control is short (three segments) and the floor is the
          // wide mode's geometry. The wide mode's own doc carries the
          // arithmetic.
          child: widget.wide
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: SegmentedControl.wideTrackMinimumWidth(
                      widget.values.length,
                    ),
                  ),
                  child: track,
                )
              : track,
        ),
      ),
    );
  }
}

/// One segment.
///
/// Private so the only way to draw one is through [SegmentedControl], which
/// means the clamping and the keyboard model cannot be bypassed.
class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.labelFamily,
    required this.selected,
    required this.colors,
    required this.animate,
    required this.wide,
    required this.onTap,
    super.key,
  });

  final String label;

  /// The label's own family, or `null` for the control's. See
  /// [SegmentedControl.labelFamilyOf].
  final String? labelFamily;

  final bool selected;
  final EvaColors colors;
  final bool animate;

  /// Whether this segment belongs to the **wide** control.
  ///
  /// `redesign.html:189` — `.segp.wide button{padding:12px 0;font-size:11px}`.
  /// Both halves are the wide mode's own, and **neither** is the default
  /// mode's: the default keeps [SegmentedControl.segmentPadding] and the
  /// `monoCaps` slot's own size.
  final bool wide;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // **THE DIRECTION, ONCE.** `redesign.html:190` gives the `.segp button`
    // rule under RTL a family swap, **no tracking** and **no transform** — and
    // the transform is the one that changes the *string* rather than the style.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Widget body = Semantics(
      // §14's prescription for a selectable chip, and the reason the segments
      // need their own nodes: without `selected`, a screen-reader user cannot
      // tell which of the three options is chosen.
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedDefaultTextStyle(
        // `redesign.html:183` — `transition:color .3s`. That is 300ms, which is
        // [EvaMotion.screen] exactly, so this one needed no rounding either.
        duration: animate ? EvaMotion.screen : Duration.zero,
        curve: EvaMotion.baseCurve,
        // The style lives **here**, not on the `Text` below: an explicit
        // `Text.style` wins over the ambient default, so putting it on the `Text`
        // would make the colour snap and leave this animation painting nothing.
        // **`labelFamily` inside the style and `arabicAware` outside it** — the
        // order matters in one direction only: `arabicAware` is the identity on an
        // LTR screen, so it cannot rescue a label whose script is Arabic on a
        // screen that is not, and a `labelFamily` set here does exactly that. Under
        // RTL the two agree for a caller that supplies both, because Amiri is what
        // `arabicAware` resolves to anyway.
        style: arabicAware(
          EvaTypography.monoCaps(colors).copyWith(
            fontFamily: labelFamily,
            // ## THE WIDE MODE'S OWN SIZE AND TRACKING, AND THE `em` RULE
            //
            // `:189` — `.segp.wide button{…font-size:11px}` — and `:184` —
            // `letter-spacing:.08em`.
            //
            // **The tracking is the em value PREMULTIPLIED by the size**,
            // because Flutter's `letterSpacing` is a logical-pixel advance and
            // CSS's `em` is relative to the element's own font: `11 × 0.08 =
            // 0.88`. The raw `0.08` would be **eleven times too small**, and
            // the house rule is in `stat_tile.dart:142-147` and
            // `eva_section_header.dart:191-206`.
            //
            // **`null` in the default mode, which keeps the slot's own values**
            // — so the default mode's rendering is byte-for-byte what it was.
            fontSize: wide ? SegmentedControl.wideLabelSize : null,
            // **AND IT IS **ZERO** UNDER RTL**, which is `redesign.html:190`:
            // `[dir=rtl] .segp button{font-family:var(--ui-ar);letter-spacing:0;
            // text-transform:none}`.
            //
            // The prototype states it for the `.segp` class exactly as `:135`
            // states it for `.mono`, and this widget's labels are a `.mono` run
            // inside a `.segp button` — so the rule applies twice over and the
            // tracking is zero either way.
            //
            // **AND IT IS ALSO THE RIGHT THING FOR THE SCRIPT.** The Workshop's
            // seven untranslated segment labels are **Latin literals** — `dot`,
            // `star`, `cross`, `gem`, `crown`, `high`, `full` — and on the Arabic
            // arm the prototype writes them in their own case
            // (`text-transform:none`), so upper-casing them there is a second
            // divergence from `:190`, and one a reader sees: `DOT` where the
            // prototype writes `dot`.
            letterSpacing: wide && !rtl
                ? SegmentedControl.wideLabelLetterSpacing
                : null,
            // `redesign.html:185` — `.segp button.on{color:#1c1608;
            // font-weight:600}`.
            //
            // **Was `colors.emberInk`, and in dark that was gold on gold.**
            // The prototype's own answer to this is `#1c1608`: the selected label
            // is dark ink because it sits on the gold thumb. `emberInk` is the
            // palette's *text* gold, and gold text on a gold thumb is a contrast
            // defect `.on` exists to fix — live in this widget, because dark
            // `emberInk` == dark `ember` == the thumb's own fill.
            //
            // [EvaColors.onEmber] is this design system's name for "legible ink
            // on `ember`", at 9.17:1 in dark and 5.41:1 in light.
            color: selected ? colors.onEmber : colors.ink2,
            // ## THE UNSELECTED LABEL'S COLOUR IS **NOT** TRANSCRIBED IN LIGHT
            //
            // `redesign.html:184` gives `.segp button` `color:var(--ink-2)`, which
            // is the dark value and is what `colors.ink2` is in dark. The prototype
            // then **re-points it in light** at `:70` —
            // `.screen[data-mode=light] .segp button{color:#707684}` — and `:70` is
            // not transcribed: this widget paints light `ink2` (`#5A5480`) where the
            // prototype writes `#707684`.
            //
            // ## NOT CHANGED HERE, AND WHY THAT IS A DECISION
            //
            // Phase 2 owns the palette mapping, and §5.2/§5.3 own the choice of
            // which prototype hex becomes which token; re-pointing `ink2` for one
            // widget's sake would move a **shared** token under every other
            // `ink2` consumer. So it is **recorded** rather than silently kept or
            // silently fixed — the third divergence this widget carries, with the
            // other two (the `w500` above and [EvaColors.onEmber]) named beside it.
            //
            // What it costs: light-mode unselected labels are *darker* than the
            // prototype's, i.e. more contrast against the track, not less. §14 is
            // therefore not at risk from this gap; a reader relying on the exact
            // hex is, which is why it is written down at all.
            // **Not** `:185`'s `font-weight:600`. `:184`'s unselected button
            // declares no weight either, and the weight stays whatever
            // `monoCaps` carries (`labelMedium`'s `w500`) so the two arms differ
            // by colour alone — which is what the thumb's edge gives a sighted
            // reader and what `selected: true` in the [Semantics] above gives
            // everyone else. Recorded because it is a divergence from `:185`.
            fontWeight: FontWeight.w500,
          ),
          // `arabicAware` for `/settings`'s theme control, whose three options
          // are the first Arabic ever to pass through `monoCaps`: without it the
          // gate reported `SpaceMono فاتح` — a Latin-only face asked for Arabic.
          // `label.toUpperCase()` below is a no-op on Arabic (it has no case), so
          // the string is untouched.
          Directionality.of(context),
        ),
        child: Container(
          // §14 — when animations are off the duration is zero, so the label
          // colour lands on the frame the selection changes: the end state,
          // immediately.
          //
          // `:189` — `.segp.wide button{padding:12px 0}` — and the default
          // mode's own [SegmentedControl.segmentPadding]. The wide mode's
          // padding has **zero horizontal**, and that is what makes a
          // four-segment control fit beside a 320px screen.
          padding: wide
              ? SegmentedControl.wideSegmentPadding
              : SegmentedControl.segmentPadding,
          alignment: Alignment.center,
          // **No fill.** `redesign.html:183` gives `button` `background:none` and
          // `:184` gives it `border-radius:999px`; the selected segment is drawn
          // by the thumb behind it (`:179`, `:183`'s `z-index:2`), not by a fill
          // of its own. The old `AnimatedContainer` here painted
          // `SettingsScreen.tsx:56`'s `rgba(…, 0.1)` and is gone.
          child: Text(
            // `SettingsScreen.tsx:55` / `redesign.html:183` —
            // `text-transform: uppercase`, which Flutter has no equivalent for.
            //
            // **AND IT IS SKIPPED UNDER RTL**, which is `redesign.html:190`:
            // `[dir=rtl] .segp button{…text-transform:none}`. On the Arabic arm
            // the prototype writes the label in its own case, and the
            // Workshop's seven untranslated labels are **Latin** — so the
            // client read `DOT` where the prototype writes `dot`.
            //
            // `toUpperCase()` is a no-op on Arabic itself (Arabic has no case),
            // so the change is invisible on a translated label and visible on
            // the prototype's own English ones.
            rtl ? label : label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
      child: InkWell(
        onTap: onTap,
        // No `focusNode`, and `canRequestFocus: false`: the control is one tab
        // stop and the arrow keys move the selection. See the class doc.
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(SegmentedControl.trackRadius),
        child: body,
      ),
    );
  }
}
