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
    return Semantics(
      // §14, verbatim: the field has no programmatic label in the prototype
      // because it is a bare `<input>` with a sibling `<label>` and nothing ties
      // them together.
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // `ds.tsx:297-300` — `F.mono, 10, 700, letterSpacing 0.12em,
          // textTransform: uppercase, color: T.ink2`.
          //
          // Excluded from semantics because the enclosing [Semantics] already
          // names the field with this exact string; leaving both in makes a
          // screen reader say "Email, Email".
          ExcludeSemantics(
            child: Text(
              // `ds.tsx:299` — `textTransform: 'uppercase'`, which Flutter has
              // no equivalent for.
              widget.label.toUpperCase(),
              style: EvaTypography.monoCaps(colors)
                  .copyWith(color: colors.ink2, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: kEvaTextFieldStackGap),
          _FieldShell(
            focusNode: _focus,
            hasError: _hasError,
            radius: kEvaTextFieldRadius,
            child: Padding(
              padding: kEvaTextFieldPadding,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      obscureText: widget.obscureText,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      onSubmitted: widget.onSubmitted,
                      // The label is above the field and is the semantics name;
                      // Material's own would duplicate it.
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      // `ds.tsx:305,309` — `F.ui, fontSize: 15, fontWeight: 400,
                      // color: T.ink`. `bodyLarge` is Material 3's 16sp slot.
                      style: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: colors.ink),
                      cursorColor: colors.ember,
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
              ),
            ),
          ),
          if (_hasError) ...<Widget>[
            const SizedBox(height: kEvaTextFieldStackGap),
            _ErrorText(message: widget.errorText!, colors: colors),
          ],
        ],
      ),
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
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: colors.err),
          ),
        ),
      ],
    ),
  );
}
