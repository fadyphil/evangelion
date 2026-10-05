import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// The field's border, fill, ink and focus glow, for one state combination.
///
/// §6 says a widget's conditionals belong in a testable function, and this one
/// earns it twice over: prototype defect #8 made the field `readOnly` and
/// defect #10 made its focus and error states literals, so "which state is this
/// field in" had never been a question the prototype asked. Naming the answer is
/// the fix.
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

/// Resolves the field treatment.
///
/// Three inputs and one answer, transcribed from `ds.tsx`'s `Input`:
///
/// | state | `ds.tsx` | here |
/// | --- | --- | --- |
/// | idle rim | `1.5px solid rgba(#fff \| #000, 0.1)` (:307) | [EvaColors.glassBorder], 1.5 |
/// | error rim | `hex.err` (:307) | `colors.err`, 1.5 |
/// | focused rim | `hex.ember`, opaque (:307) | **`evaFocusRingBorder`** — see below |
/// | idle fill | `rgba(#fff \| #000, 0.03)` (:308) | `glassFill` (5% dark / 3% light) |
/// | focused fill | `rgba(#fff \| #000, 0.06)` (:308) | `ink` at 6% |
/// | focus glow | `0 0 0 3px rgba(ember,.18), 0 0 20px rgba(ember,.12)` (:310) | as written |
/// | error text | `T.err`, 12, w500 (:320) | `colors.err`, `bodySmall` w500 |
///
/// ## THE ONE VALUE §14 OVERRIDES, AND WHY IT IS NOT A TRANSCRIPTION
///
/// `ds.tsx:307` gives a focused field `1.5px solid ember` at **full opacity**.
/// `09-quality-gates.md` §14 mandates "a 2px `ember` ring at 40% alpha on every
/// interactive widget". Both describe the same 2px band around the same box, so
/// they cannot both hold.
///
/// §14 wins. The prototype's focused rim is not a focus *indicator* — `focused`
/// is a literal prop that defect #10 records as baked in, so nothing in the app
/// ever moved it. There is no accessibility behaviour behind 100% alpha, only a
/// still picture of one, and §14's list is the mandatory-fix list. The
/// prototype's **glow** is transcribed unchanged, because a glow is a different
/// effect from a rim and it is the part that reads as "this field is live".
///
/// ## AND AN ERRORED FIELD THAT IS FOCUSED STILL SHOWS THE RING
///
/// Focus is the reader's cursor position, so it wins the rim; the error is
/// carried by the helper text, an icon and the semantics label instead. §14
/// bans colour-only state, which is precisely why losing the red rim here costs
/// nothing — and `eva_text_field_test.dart` asserts the three carriers exist.
EvaTextFieldStyle resolveTextFieldStyle({
  required EvaColors colors,
  required bool focused,
  required bool hasError,
  required bool enabled,
}) {
  final bool showRing = focused && enabled;
  // `ds.tsx:308` — `rgba(#fff | #000, focused ? 0.06 : 0.03)`.
  //
  // The idle fill is `glassFill`, not a second literal copy of 0.03: the token is
  // 5% in dark and 3% in light, so the light palette is exact and dark is two
  // points heavier. The focused fill stays a literal because `glassFill` is a
  // different number and Phase 1 published no token for it.
  final Color fill = !enabled
      // No prototype value: the prototype's `Input` has no `disabled` prop at
      // all. `ink` at 2% is "the field is there and cannot be typed in", which
      // is the state a login field is in while the request is in flight.
      ? colors.ink.withValues(alpha: 0.02)
      : focused
      ? colors.ink.withValues(alpha: 0.06)
      : colors.glassFill;
  return EvaTextFieldStyle(
    background: fill,
    // `ds.tsx:309` — `color: T.ink`. A disabled field inks with `ink3`, the
    // token's documented role for disabled text.
    foreground: enabled ? colors.ink : colors.ink3,
    border: showRing
        ? evaFocusRingBorder(colors)
        : Border.all(
            // `ds.tsx:307` — `error ? hex.err : rgba(#fff | #000, 0.1)`, both
            // at `1.5px`. A disabled field drops the error rim: it cannot be
            // corrected, so a red rim on it is an unfixable complaint.
            color: hasError && enabled ? colors.err : colors.glassBorder,
            width: 1.5,
          ),
    // `ds.tsx:310` — `focused ? ... : 'none'`.
    glow: showRing
        ? <BoxShadow>[
            // The first shadow has zero offset and zero blur, which makes it a
            // 3px *spread ring* rather than a glow; `spreadRadius` is what that
            // is, and transcribing it as a blur would put a visible fog around
            // the field instead of a halo.
            BoxShadow(
              color: colors.ember.withValues(alpha: 0.18),
              spreadRadius: 3,
            ),
            BoxShadow(
              color: colors.ember.withValues(alpha: 0.12),
              blurRadius: 20,
            ),
          ]
        : const <BoxShadow>[],
  );
}

/// The prototype's field height. `ds.tsx:306` — `height: 52`.
const double kEvaTextFieldHeight = 52;

/// The prototype's field radius. `ds.tsx:306` — `borderRadius: 14`, which is
/// [EvaRadii.input].
const double kEvaTextFieldRadius = EvaRadii.input;

/// The prototype's inner padding. `ds.tsx:309` — `padding: '0 44px 0 16px'`.
///
/// The 44 is a literal because it is not a scale step: it is the `rightIcon`'s
/// inset (14, `ds.tsx:315`) plus the icon's own 18, and the prototype wrote the
/// sum. 16 **is** a token — [EvaSpacing.lg].
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
              data: IconThemeData(color: colors.ink3),
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
                color: colors.ink3,
              ),
        ),
      ),
    ),
  );
}

/// The error helper text: `ds.tsx:320` — `F.ui, 12, 500, color: T.err`.
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
        Icon(Icons.error_outline, size: EvaSpacing.lg, color: colors.err),
        const SizedBox(width: EvaSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: arabicAware(
              Theme.of(context).textTheme.bodySmall!,
              Directionality.of(context),
            ).copyWith(color: colors.err),
          ),
        ),
      ],
    ),
  );
}
