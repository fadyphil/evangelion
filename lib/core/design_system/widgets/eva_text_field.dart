import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// The field's rim, fill, ink and focus glow, for one state combination.
///
/// §6 says a widget's conditionals belong in a testable function, and this one
/// earns it twice over: prototype defect #8 made the field `readOnly` and
/// defect #10 made its focus and error states literals, so "which state is this
/// field in" had never been a question the prototype asked. Naming the answer is
/// the fix.
///
/// The **box** is `redesign.html:376-379`'s; the **label** above it is still
/// `ds.tsx:297-300`'s, because `.field` in the redesign is bare and declares no
/// label at all. The split is recorded on [EvaTextField.label] and not here.
@immutable
class EvaTextFieldStyle {
  /// A field treatment.
  const EvaTextFieldStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.glow,
  });

  /// The field's fill.
  final Color background;

  /// The entered text's ink.
  final Color foreground;

  /// The rim. Never null — a field with no rim is not this design system's field.
  final Border border;

  /// Shadows over the fill. Empty unless focused.
  final List<BoxShadow> glow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaTextFieldStyle &&
          other.background == background &&
          other.foreground == foreground &&
          other.border == border &&
          listEquals(other.glow, glow);

  @override
  int get hashCode =>
      Object.hash(background, foreground, border, Object.hashAll(glow));
}

/// The field box's rim width. `redesign.html:376` — `border: 1px solid
/// var(--glass-line)`.
///
/// **1px, where `ds.tsx:307` wrote `1.5px`.** This is the only geometry number
/// the box's restyle moves, and it moves because the redesign's single
/// declaration for a field box is 1px and the old prototype's was 1.5.
///
/// It does **not** move the focused rim: §14's ring is 2px
/// ([evaFocusRingSpec]) and `focus_ring_gate_test` and `login_geometry_test`
/// both read it. §14 is the mandatory list and a widget that put a 1px rim where
/// §14 says 2px would be trading an accessibility guarantee for a
/// millimetre.
///
/// **It is `1`, which is `Border.all`'s own default width**, so the one
/// `Border.all` it feeds does not spell it — the same trade
/// `IconActionButton.pillRimWidth` makes, and for the same reason: an argument
/// that matches the default says nothing the default does not already say, and
/// `avoid_redundant_argument_values` (a `dart analyze --fatal-infos` gate) says
/// so too. What keeps the number honest is a test asserting this constant, which
/// is `eva_text_field_test.dart`'s `1.5` rows replaced below.
const double kEvaTextFieldRimWidth = 1;

/// Resolves the field treatment.
///
/// Three inputs and one answer. The **box** is `redesign.html`'s; the **states**
/// are `ds.tsx`'s, because `.field input` declares no error state at all — it
/// has a `:focus` rule (`:378`) and nothing else:
///
/// | state | `redesign.html` | here |
/// | --- | --- | --- |
/// | idle rim | `1px solid var(--glass-line)` (:376) | [EvaColors.glassBorder] at [kEvaTextFieldRimWidth] |
/// | error rim | **no line.** `ds.tsx:307` — `hex.err` | `colors.err`, same 1px |
/// | focused rim | `rgba(232,176,75,.6)` (:378) | **`evaFocusRingBorder`** — see below |
/// | idle fill | `rgba(255,255,255,.04)` (:376) | `glassFill` (5% dark / 3% light) |
/// | focused fill | **no line.** `ds.tsx:308` — `rgba(#fff \| #000, .06)` | `ink` at 6% |
/// | focus glow | `0 0 0 3px rgba(232,176,75,.12)` (:378) | as written |
/// | error text | `var(--ember)` (:379) | `errInk`, `bodySmall` w500 |
///
/// ## TWO HALOS BECOME ONE, AND THE COUNT IS THE WHOLE CHANGE
///
/// `ds.tsx:310` wrote two shadows — `0 0 0 3px rgba(ember,.18)` (a spread ring)
/// **and** `0 0 20px rgba(ember,.12)` (a fog). `redesign.html:378` writes one:
/// `0 0 0 3px rgba(232,176,75,.12)`. So the 20px fog is dropped and the spread
/// ring's alpha goes from `.18` to `.12`.
///
/// Dropping it is not a loss of accessibility signal and it is not a
/// simplification: the 3px spread ring is the part §14's focus row is about, and
/// the fog was a second, weaker copy of the same statement in a different
/// channel. Two halos meant the indicator's strength varied with what was behind
/// the field.
///
/// ## THE ONE VALUE §14 OVERRIDES, AND WHY IT IS NOT A TRANSCRIPTION
///
/// `redesign.html:378` gives a focused field `border-color:
/// rgba(232,176,75,.6)` — a 60%-alpha gold rim on a 1px border.
/// `09-quality-gates.md` §14 mandates "a 2px `ember` ring at 40% alpha on every
/// interactive widget". Both describe a band around the same box, so they cannot
/// both hold.
///
/// §14 wins, and it won before this restyle too — the rule it displaced was
/// `ds.tsx:307`'s `1.5px solid ember` at **full** opacity, and the reason has not
/// changed. `focused` was a literal prop that defect #10 records as baked in, so
/// nothing in the app ever moved it. There is no accessibility behaviour behind
/// either alpha, only a still picture of one, and §14's list is the
/// mandatory-fix list. So the focused rim stays [evaFocusRingBorder], and the
/// redesign's **halo** is transcribed unchanged, because a halo is a different
/// effect from a rim and it is the part that reads as "this field is live".
///
/// ## AND AN ERRORED FIELD THAT IS FOCUSED STILL SHOWS THE RING
///
/// Focus is the reader's cursor position, so it wins the rim; the error is
/// carried by the helper text, an icon and the semantics label instead. §14
/// bans colour-only state, which is precisely why losing the red rim here costs
/// nothing — and `chip_beads_field_test.dart` asserts the three carriers exist.
EvaTextFieldStyle resolveTextFieldStyle({
  required EvaColors colors,
  required bool focused,
  required bool hasError,
  required bool enabled,
}) {
  final bool showRing = focused && enabled;
  // `ds.tsx:308` — `rgba(#fff | #000, focused ? 0.06 : 0.03)`.
  //
  // **No redesign line.** `redesign.html:376` gives one background for the field
  // and `:378` changes only `border-color` and `box-shadow` — so a focused field
  // in the redesign has the *same* fill as an idle one, where `ds.tsx:308` had
  // two. The old value is kept and this row is why: the redesign says nothing,
  // which is a gap in the reference rather than an instruction to flatten the
  // fill.
  //
  // The idle fill is `glassFill`, not a second literal copy of 0.04: the token is
  // 5% in dark and 3% in light, so the light palette is exact and dark is one
  // point heavier. `redesign.html:15` and `:57` agree with each other and not
  // with the token, which is the Phase-2 non-repair recorded on
  // `EvaColors.glassFill`. The focused fill stays a literal because `glassFill`
  // is a different number and Phase 1 published no token for it.
  final Color fill = !enabled
      // No prototype value: the prototype's `Input` has no `disabled` prop at
      // all, and `redesign.html`'s `.field input` has none either. `ink` at 2%
      // is "the field is there and cannot be typed in", which is the state a
      // login field is in while the request is in flight.
      ? colors.ink.withValues(alpha: 0.02)
      : focused
      ? colors.ink.withValues(alpha: 0.06)
      : colors.glassFill;
  return EvaTextFieldStyle(
    background: fill,
    // `redesign.html:376` — `color: var(--ink-0)`; `ds.tsx:309` — `color: T.ink`.
    // A disabled field inks with `ink3`, the token's documented role for
    // disabled text.
    foreground: enabled ? colors.ink : colors.ink3,
    border: showRing
        ? evaFocusRingBorder(colors)
        : Border.all(
            // `redesign.html:376` — `error ? … : var(--glass-line)`, at
            // [kEvaTextFieldRimWidth]. `ds.tsx:307` is the only line in either
            // prototype that names an **error** rim (`hex.err`), and it is kept
            // at the redesign's width. A disabled field drops the error rim: it
            // cannot be corrected, so a red rim on it is an unfixable complaint.
            color: hasError && enabled ? colors.err : colors.glassBorder,
            // **No `width:`** — see the constant's doc. This is `Border.all`'s own
            // default of 1, so naming it here would restate the default rather
            // than cite the prototype, and `eva_text_field_test.dart` is what
            // keeps the number honest rather than a redundant argument.
          ),
    // `redesign.html:378` — `box-shadow: 0 0 0 3px rgba(232,176,75,.12)`.
    glow: showRing
        ? <BoxShadow>[
            // Zero offset and zero blur, which makes this a 3px *spread ring*
            // rather than a glow; `spreadRadius` is what that is, and
            // transcribing it as a blur would put a visible fog around the field
            // instead of a halo. The `ds.tsx:310` fog this replaced was
            // `0 0 20px rgba(ember,.12)`, the same `.12` at a different radius —
            // which is why only the radius and not the alpha had to move.
            BoxShadow(
              color: colors.ember.withValues(alpha: 0.12),
              spreadRadius: 3,
            ),
          ]
        : const <BoxShadow>[],
  );
}

/// The prototype's field height. `ds.tsx:306` — `height: 52`.
///
/// **Kept, and the redesign's divergence is recorded here rather than chased.**
/// `redesign.html:377` gives `.field input` `padding: 14px 16px` and a 14px
/// label beside it, and no height — so the redesign's field is roughly
/// **14 + 14 + 14 + 1 = 43–45px** where this one is 52. Two harnesses read
/// 52: `login_geometry_test`'s `dsClaims` asserts `kEvaTextFieldHeight == 52` as
/// a transcription claim against `ds.tsx:306`, and §14's affordance floor is the
/// same number on every screen this field appears on. A 45px field is 7px
/// shorter than a 52px control standing beside it on `/login` — the CTA — and a
/// form whose two fields do not agree in height reads as a mistake even when
/// every value in it is transcribed.
///
/// So the gap is **43–45 vs 52**, it is named here, and it is a decision to be
/// revisited in Phase 5.1 rather than a value nobody looked at.
const double kEvaTextFieldHeight = 52;

/// The prototype's field radius. `ds.tsx:306` — `borderRadius: 14`, which is
/// [EvaRadii.input].
///
/// **Kept, and it is worth saying why, because the box is otherwise the
/// redesign's.** `redesign.html:376` writes `border-radius: 14px` — the same
/// number — and that is the one piece of the box's geometry that did *not*
/// become a pill. The restyle moved the rim's width from 1.5px to 1px and the
/// halo from two to one, and left the corners alone, because a text field is not
/// a button: a pill you tap once is a command, and a pill you type into is a
/// surface with a lot of content on it. `EvaTextFieldHeight` is asserted at 52
/// by the same harness that asserts `EvaRadii.input == 14`, so both halves are
/// visible in one place.
const double kEvaTextFieldRadius = EvaRadii.input;

/// The prototype's inner padding. `ds.tsx:309` — `padding: '0 44px 0 16px'`.
///
/// The 44 is a literal because it is not a scale step: it is the `rightIcon`'s
/// inset (14, `ds.tsx:315`) plus the icon's own 18, and the prototype wrote the
/// sum. 16 **is** a token — [EvaSpacing.lg] — and `redesign.html:377` writes
/// the same `14px 16px` horizontally, so this row is a transcription that two
/// prototypes agree on.
///
/// It is the *vertical* half that diverges and it does not: `redesign.html:377`
/// pads 14px top and bottom where this widget pads none and fixes the height at
/// 52 instead. Same trade, same reason, same place to revisit it
/// ([kEvaTextFieldHeight]).
const EdgeInsets kEvaTextFieldPadding = EdgeInsets.only(
  left: EvaSpacing.lg,
  right: 44,
);

/// Vertical gap between the label, the field and the error text.
/// `ds.tsx:296` — `gap: 6`.
///
/// 6 is not on the 4px scale, so it is named here rather than invented at each
/// of the two gaps the column creates.
const double kEvaTextFieldStackGap = 6;

/// A real text field.
///
/// ## WHAT IS THE REDESIGN'S AND WHAT IS **NOT**, AND WHERE EACH ONE IS CITED
///
/// | | source | note |
/// | --- | --- | --- |
/// | the box: 1px rim, halo, fill | `redesign.html:376-379` | moved this restyle |
/// | the 52 height, the 14 radius, the 16/44 insets | `ds.tsx:306,309` | **kept** — [kEvaTextFieldHeight] names the `43–45 vs 52` divergence |
/// | the label | `ds.tsx:297-300` | **kept** — see [label]; the redesign has none |
/// | the error text | `redesign.html:379` | colour only; size and weight are `ds.tsx:320` |
/// | `blur(8px)` | **nothing** | §13.4's budget, collapsed to [GlassTier.tint] at the call site |
///
/// The fourth row is the one that is easiest to misread as a gap. `EvaTextField`
/// does not blur and never has; `.field input` in the redesign is a flat
/// `rgba(255,255,255,.04)` and the blur that used to be here was
/// `ds.tsx:308`'s `backdrop-filter`, collapsed to the tint tier by the §13.4
/// budget before this restyle and untouched by it.
///
/// ## WHAT MAKES IT REAL, AND WHAT THE PROTOTYPE DID NOT HAVE
///
/// Defect #8: `Input` is `readOnly` with no `value`, no `onChanged` and no
/// `onSubmitted` (`ds.tsx:303`) — the Login form could not be filled in. Defect
/// #10: Login hardcodes `focused` on the email field and an error string on the
/// password field (`LoginScreen.tsx:49-52`), so "this field has focus" and "this
/// field is in error" were pictures, not state.
///
/// So the controller is the caller's ([controller], not created here — a
/// design-system widget must not own the text it is editing), and focus is this
/// widget's own [FocusNode] read through a [Focus] so the border can change. The
/// `onChanged` side is [controller]: a caller adds a listener, and §6's rule that
/// the widget must not bury logic is satisfied because the widget stores nothing
/// but [TextEditingController.text].
class EvaTextField extends StatefulWidget {
  /// A labelled text field editing [controller].
  const EvaTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    super.key,
  });

  /// The mono-caps label above the field, and the field's accessible name
  /// (§14: "`EvaTextField` supplies `Semantics(label: label)` to the field").
  ///
  /// ## WHY THIS KEEPS `ds.tsx:297-300` AND THE BOX MOVED TO `redesign.html`
  ///
  /// Because the redesign's field has **no label**. `redesign.html:376-379` is
  /// three rules — the input, its `:focus`, and `.field .msg` — and not one of
  /// them mentions a `<label>`; `.field` itself (`:376`) is a bare wrapper with a
  /// `margin-bottom`. Re-pointing this parameter's citation to `:376` would make
  /// the number resolve *and* be about the wrong line, which is recorded decision
  /// 8's own "a citation can resolve and still be about the wrong line" — the
  /// failure `IconActionButton`'s `pilled` doc also found and fixed.
  ///
  /// So the split is the honest one and it is the one the Task 4.2 status block
  /// records: **the box is the redesign's, the label is the React prototype's.**
  /// `ds.tsx:297-300` is `F.mono, 10, 700, letterSpacing 0.12em,
  /// textTransform: uppercase, color: T.ink2` — which is what renders above the
  /// field on all six screens.
  final String label;

  /// Greyed placeholder text drawn while the field is empty. `null` means none.
  ///
  /// ## WHY THIS WAS MISSING FOR THREE PHASES, AND WHAT IT COST
  ///
  /// `ds.tsx:301` types the field's `placeholder` straight onto the `<input>`, and
  /// `LoginScreen.tsx:49,51` pass `you@example.com` and `••••••••`. Phase 3
  /// transcribed `ds.tsx`'s `Input` and did not transcribe its `placeholder`, and
  /// Phase 5's `LoginPage` passed no value because **there was no parameter to pass
  /// one to**. So the prototype draws greyed text inside both empty fields and this
  /// app drew nothing.
  ///
  /// The interesting part is not the missing text; it is that the gap was invisible
  /// to a suite whose whole subject is comparing this screen against the prototype.
  /// `login_geometry_test.dart` parsed every `key: N` in `LoginScreen.tsx` — a
  /// string with no number is not a row in that table — and `dsClaims` reads
  /// `fontSize` / `height` / `padding` lines only. **A line map of numbers cannot
  /// see a missing string.** That is recorded rather than fixed here, because the
  /// harness's limits are decision 8's own "what it still cannot see" section.
  ///
  /// `hintStyle` is derived from the entered text's own style with `colors.ink3`,
  /// because §5.1 gives `ink3` the role of "de-emphasised ink" and the prototype's
  /// placeholder is `rgba(#fff | #000, 0.35)` — the same colour `ds.tsx:315` uses
  /// for the field's own `rightIcon`.
  ///
  /// ## AND ALL THREE OF THIS WIDGET'S **STRINGS** TAKE THE AMBIENT ARM
  ///
  /// [label], [hintText] and [errorText] are all caller-supplied, all localised by
  /// `AppLocalizations`, and none had a family parameter — so on the Arabic arm
  /// `البريد الإلكتروني` and `كلمة المرور` rendered in **Space Mono** and the other
  /// two in DM Sans, on the one screen a reader reaches before any content exists.
  /// Each is wrapped in [arabicAware], which is the whole of the fix and costs no
  /// constructor argument. The error is the one that mattered most, and
  /// [ErrorView]'s doc says why: a `Failure.message` is the **server's** text.
  final String? hintText;

  /// The text. Owned by the caller: this widget never disposes it, never
  /// initialises it, and never writes to it.
  final TextEditingController controller;

  /// The error helper text below the field. `null` or empty means no error.
  final String? errorText;

  /// Whether to mask the entry.
  final bool obscureText;

  /// Forwarded to [TextField.keyboardType].
  final TextInputType? keyboardType;

  /// Forwarded to [TextField.textInputAction].
  final TextInputAction? textInputAction;

  /// Forwarded to [TextField.onSubmitted].
  final ValueChanged<String>? onSubmitted;

  /// A control in the field's right inset — the prototype's `rightIcon`
  /// (`ds.tsx:314-318`), which Login uses for the show/hide-password toggle.
  ///
  /// The **widget** goes here, not a callback, so the caller's button brings its
  /// own semantics and its own focus node: nesting a focusable inside a
  /// `TextField`'s own focus scope would make two tab stops for one field.
  final Widget? trailing;

  @override
  State<EvaTextField> createState() => _EvaTextFieldState();
}

class _EvaTextFieldState extends State<EvaTextField> {
  final FocusNode _focus = FocusNode(debugLabel: 'EvaTextField');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    // Focus drives the rim, so the shell has to rebuild when it moves. The
    // `ListenableBuilder` lives in `_FieldShell` because that is the widget
    // whose decoration changes.
    final Widget row = Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            // §14, verbatim: the field has no programmatic label in the
            // prototype because it is a bare `<input>` with a sibling
            // `<label>` and nothing ties them together.
            //
            // ## WHY IT WRAPS THE `TextField` AND NOT THE WHOLE COLUMN
            //
            // Because `EditableText` publishes a semantics node of its own
            // (`isTextField == true`), and an ancestor's `Semantics(label:)`
            // merges into that node only when nothing between them is a
            // semantics boundary — and a `trailing` control is one: it is
            // focusable and carries its own `Semantics`. Measured on `/login`'s
            // password field, whose `trailing` is the show/hide toggle:
            //
            // ```
            // "Password"                  <- the Semantics around the column
            //   ""          tap=true      <- EditableText's node, **unlabelled**
            //   "Show password" tap=true  <- the toggle, correctly named
            // ```
            //
            // The node a reader activates to reach the field had no name at
            // all, which is §14's "no unlabeled interactive node" — found by
            // walking the tree rather than by reading this comment. A field
            // with no `trailing` merged into one labelled node and read
            // fine, which is why the email field on the same screen was
            // never a problem and the password field was.
            //
            // ## AND WHY NOT *ALSO* AROUND THE COLUMN
            //
            // Because two annotations of the same label on the same merged
            // node do not read as one. The first version of this fix put a
            // second `Semantics(label:)` **inside** the outer one and kept
            // both; the field's node came out with an **empty** label and
            // `find.bySemanticsLabel('Password')` matched nothing at all —
            // `chip_beads_field_test.dart`'s §14 assertion caught it on the
            // first run. The outer annotation is removed rather than
            // duplicated.
            label: widget.label,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              // **No `hintText` here**, and the placeholder is drawn by
              // [_Placeholder] instead — for a measured accessibility reason,
              // not a stylistic one. Routing it through
              // `InputDecoration.hintText` merges the placeholder into
              // `EditableText`'s own semantics node, so the field's accessible
              // name becomes `"Email" + "\n" + "you@example.com"`; probed,
              // exactly that, and `find.bySemanticsLabel('Email')` then matches
              // nothing. A browser does not put an `<input>`'s `placeholder` in
              // its accessible name — only the `<label>` — so excluding it is
              // the faithful transcription, not a loss.
              //
              // The label is above the field and is the semantics name;
              // Material's own would duplicate it.
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              // `ds.tsx:305,309` — `F.ui, fontSize: 15, fontWeight: 400,
              // color: T.ink`. `bodyLarge` is Material 3's 16sp slot.
              //
              // **Swapped for the ambient arm**, like the label above. This is the one
              // run on the widget that is not the app's own string — it is whatever
              // the reader **types** — and `bodyLarge` is DM Sans, which carries no
              // Arabic glyph at all, so an Arabic keyboard on the Arabic arm produced
              // tofu in a field with room for it. Amiri carries ASCII as well, so a
              // Latin address and a transliterated one both render.
              style: arabicAware(
                Theme.of(context).textTheme.bodyLarge!,
                Directionality.of(context),
              ).copyWith(color: colors.ink),
              cursorColor: colors.ember,
            ),
          ),
        ),
        if (widget.trailing case final Widget control)
          Padding(
            padding: const EdgeInsets.only(right: EvaSpacing.sm),
            child: IconTheme.merge(
              // `ds.tsx:315-316` — `right: 14, color: T.ink3`.
              data: IconThemeData(color: colors.ink2),
              child: control,
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // `ds.tsx:297-300` — `F.mono, 10, 700, letterSpacing 0.12em,
        // textTransform: uppercase, color: T.ink2`.
        //
        // Excluded from semantics because the field's own node already carries this
        // exact string as its name; leaving both in makes a screen reader say
        // "Email, Email".
        ExcludeSemantics(
          child: Text(
            // `ds.tsx:299` — `textTransform: 'uppercase'`, which Flutter has
            // no equivalent for.
            widget.label.toUpperCase(),
            style: arabicAware(
              EvaTypography.monoCaps(colors),
              Directionality.of(context),
            ).copyWith(color: colors.ink2, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: kEvaTextFieldStackGap),
        _FieldShell(
          focusNode: _focus,
          hasError: _hasError,
          radius: kEvaTextFieldRadius,
          child: Padding(
            padding: kEvaTextFieldPadding,
            // The placeholder is a **sibling** of the row rather than a decoration
            // of it, so it can be `ExcludeSemantics`-ed without reaching inside
            // `EditableText`. See the `decoration:` comment below.
            //
            // **And only when there is one.** With no `hintText` the stack would be
            // a `Stack` around a single child plus a `ValueListenableBuilder`
            // firing on every keystroke for no visual result. That is not only
            // wasted work: the extra frame boundary moved the caret's blink phase
            // and broke `eva_text_field_state_focused.png` by 56px — a 2×38 bar at
            // the caret's own coordinates, measured. A golden that encodes a blink
            // phase is not a golden, so the branch is here rather than accepted.
            child: widget.hintText == null
                ? row
                : ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder:
                        (
                          BuildContext context,
                          TextEditingValue value,
                          Widget? inner,
                        ) => Stack(
                          // ## WHY `StackFit.expand`, AND WHY IT IS THE WHOLE FIX
                          //
                          // A reader reported that a typed run sat at the TOP of the
                          // field while the placeholder it replaced sat in the
                          // middle. Measured on the 52px shell: the placeholder
                          // centres at y=433 and the typed run at y=419 — 14px
                          // apart, the difference you see.
                          //
                          // The cause is not `contentPadding`, and fixing that alone
                          // would have hidden the symptom rather than the cause.
                          // `_FieldShell` hands its child a
                          // `SizedBox(height: kEvaTextFieldHeight)`, but a `Stack`
                          // **sizes itself to its largest non-positioned child** — so
                          // the 52px was discarded and the row collapsed to its
                          // intrinsic 24px line height, pinned to the top by the
                          // `Stack`'s default `topStart` alignment. The
                          // placeholder was unaffected because it centres itself
                          // with `Align(centerStart)` inside whatever box it is
                          // given, and the box it was given was the full 52.
                          //
                          // `expand` makes the row fill that same 52, which is what
                          // `TextAlignVertical.center` on the `TextField` below
                          // needs in order to mean anything: centring inside a 24px
                          // row and centring inside the 52px field are different
                          // answers, and only the second one matches the hint.
                          //
                          // Without this, `textAlignVertical: center` is a no-op in
                          // practice — it centres within a box that was already the
                          // wrong box. VERIFIED: restoring `StackFit.loose` puts the
                          // typed run back at y=419 and turns both new assertions
                          // red.
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (value.text.isEmpty)
                              _Placeholder(
                                text: widget.hintText!,
                                colors: colors,
                              ),
                            inner!,
                          ],
                        ),
                    child: row,
                  ),
          ),
        ),
        if (_hasError) ...<Widget>[
          const SizedBox(height: kEvaTextFieldStackGap),
          _ErrorText(message: widget.errorText!, colors: colors),
        ],
      ],
    );
  }
}

/// The bordered box the [TextField] sits in.
///
/// Split out so the rim and the glow are drawn by one `DecoratedBox` rather than
/// by an `InputDecoration`, which cannot express `borderRadius: 14` on a
/// borderless field without a `ShapeBorder` wrapper per call site.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.focusNode,
    required this.hasError,
    required this.radius,
    required this.child,
  });

  final FocusNode focusNode;
  final bool hasError;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: focusNode,
    builder: (BuildContext context, Widget? inner) {
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: context.colors,
        focused: focusNode.hasFocus,
        hasError: hasError,
        enabled: true,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(radius),
          border: style.border,
          boxShadow: style.glow,
        ),
        child: SizedBox(height: kEvaTextFieldHeight, child: inner),
      );
    },
    child: child,
  );
}

/// `ds.tsx:301`'s `placeholder`, drawn by this widget rather than by
/// `InputDecoration.hintText`.
///
/// [EvaTextField]'s `decoration:` argument explains the accessibility reason. The
/// two visual requirements are ordinary: it sits behind the text at the text's own
/// baseline position, and it disappears the moment there is a character to show
/// instead. [EvaTextField] owns the second by rebuilding this through a
/// [ValueListenableBuilder] over the controller.
///
/// `IgnorePointer` because it is drawn *over* the row's area: without it the
/// placeholder would swallow taps aimed at the field.
class _Placeholder extends StatelessWidget {
  /// Greyed placeholder text.
  const _Placeholder({required this.text, required this.colors});

  /// What the prototype's `placeholder` attribute carries.
  final String text;

  /// The palette, for the de-emphasised ink.
  final EvaColors colors;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      // `AlignmentDirectional`, so the placeholder starts at the text's own edge in
      // both directions rather than always on the left.
      alignment: AlignmentDirectional.centerStart,
      child: ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          // Swapped for the ambient arm, like the label above. The
          // geometry is untouched — `bodyLarge` is still the style this run was
          // built from, and only its family is resolved for the direction.
          style:
              arabicAware(
                Theme.of(context).textTheme.bodyLarge!,
                Directionality.of(context),
              ).copyWith(
                // `colors.ink3`, the same de-emphasised ink `ds.tsx:315` gives the
                // field's own `rightIcon` and this project's token table gives any
                // text that is present but not the content.
                color: colors.ink2,
              ),
        ),
      ),
    ),
  );
}

/// The error helper text: `ds.tsx:320` — `F.ui, 12, 500, color: T.err`.
///
/// ## THE COLOUR IS NOW ALSO THE REDESIGN'S, AND IT IS `errInk` NOT `err`
///
/// `redesign.html:379` — `.field .msg{font-family:var(--mono);font-size:9.5px;
/// letter-spacing:.1em;margin-top:5px;min-height:13px;color:var(--ember)}` — is
/// the second prototype's line for this text, and it agrees on the hue. It does
/// not agree on the size (9.5 against 12), the family (`mono` against `ui`) or
/// the letter-spacing, and **none of the three moved**: the redesign's own
/// `[dir=rtl]` arm (`:380`) replaces all three at once, so applying half of a
/// rule whose other half is a direction branch would be applying a declaration
/// the prototype then withdraws.
///
/// `errInk` rather than `err` is Decision 153, and it was already right before
/// this restyle — verified rather than changed. In light, `err` measures 3.73:1
/// as text, and this is error copy on `/login` and `/settings`.
///
/// Plus the icon and the semantics label §14 demands, because an error signalled
/// by the rim's colour alone is exactly the colour-only state the section bans —
/// and the rim is no longer even red while the field is focused.
class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message, required this.colors});

  final String message;
  final EvaColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    // Announced as an error rather than as more label text.
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.error_outline, size: EvaSpacing.lg, color: colors.errInk),
        const SizedBox(width: EvaSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: arabicAware(
              Theme.of(context).textTheme.bodySmall!,
              Directionality.of(context),
            ).copyWith(color: colors.errInk),
          ),
        ),
      ],
    ),
  );
}
