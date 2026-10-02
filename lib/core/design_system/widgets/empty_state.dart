import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// "There is nothing here yet, and here is why."
///
/// **The prototype has neither this widget nor [ErrorView].** `04-widget-inventory.md`
/// §6 says so outright ("17. `EmptyState` · 18. `ErrorView` — the prototype has
/// neither"), and `grep` over `eva/src` finds no empty state and no error state:
/// every screen in the prototype renders a hardcoded payload and none of them can
/// fail, because there is no data layer behind it. So **every** value below is a
/// composition of tokens that exist, and none of them is transcribed from a line
/// of `ds.tsx`. Where a number appears it is a token or it is named.
///
/// ## WHY IT IS IN THE DESIGN SYSTEM AT ALL
///
/// Not for the composition — a state view is mostly typography. For the
/// **typography under a constrained box**, which is §14's live risk. Phase 1
/// decision 5 kept Material 3's type scale, so `displayLarge` is 57sp where the
/// prototype's largest type is 34px, and at 1.22× on a 320px screen it wraps to
/// four lines. An empty state is exactly where a `displayLarge` title goes, and
/// exactly where a reader with a narrow screen and large text would be hurt by
/// one. So this widget uses `headlineMedium` (28sp) — see [titleStyle] — and
/// `empty_state_text_scale_test.dart` proves it does not overflow at 1.22×/320px.
///
/// ## COLOUR-ONLY STATE
///
/// An empty state is not a state in the §14 sense — nothing is *selected* — but
/// the icon is `ink3` and the message is `ink2`, and those two inks are close
/// enough that the pairing is carried by the type scale and the icon's shape
/// rather than by hue alone.
class EmptyState extends StatelessWidget {
  /// An empty state for [title], explained by [message].
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  /// The leading glyph. An [IconData], for the same reason [IconActionButton]
  /// takes one: the meaning belongs to the call site, and a design-system widget
  /// that chose the glyph would be choosing the product's vocabulary.
  final IconData icon;

  /// The headline. Short — one or two words at most.
  final String title;

  /// The explanation. Longer, and the part that actually has to survive 1.22× on
  /// a 320px screen.
  final String message;

  /// An optional action — an [EvaButton] or a [TextLink] the call site builds.
  ///
  /// A `Widget` and not a callback so the action brings its own semantics, its
  /// own focus node and its own §14 ring. [EmptyState] must not become a second
  /// owner of a button's focus.
  final Widget? action;

  /// The icon's box. No prototype value: a state view needs an icon big enough to
  /// read as a glyph rather than as a dot, and `Icons.*` has no intrinsic size.
  static const double iconBox = EvaSpacing.huge * 2;

  /// The icon's size inside that box.
  static const double iconSize = EvaSpacing.xxxl + EvaSpacing.md;

  /// Gap between the icon, the title and the message. `EvaSpacing.lg`, because
  /// there is no prototype gap to transcribe and the scale step is the honest
  /// default.
  static const double stackGap = EvaSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Widget? control = action;

    return Center(
      child: SingleChildScrollView(
        // `EmptyState` lands in whatever box its caller has — a screen body, a
        // panel, a sheet. Scrolling is what makes it safe in all three, and a
        // state view that overflows is worse than one that scrolls.
        child: Padding(
          padding: const EdgeInsets.all(EvaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: iconBox,
                height: iconBox,
                child: Icon(icon, size: iconSize, color: colors.ink3),
              ),
              const SizedBox(height: stackGap),
              Text(
                title,
                textAlign: TextAlign.center,
                style: titleStyle(context),
              ),
              const SizedBox(height: EvaSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: colors.ink2),
              ),
              if (control != null) ...<Widget>[
                const SizedBox(height: EvaSpacing.xl),
                control,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The title's style.
  ///
  /// **`headlineMedium`, and the reason is §14 rather than taste.**
  /// `headlineMedium` is Material 3's 28sp slot. `displayLarge` — the slot a
  /// "nothing here" headline would normally reach for — is **57sp** after Phase 1
  /// decision 5, which is 1.7× the prototype's largest type (34px), and at the
  /// 1.22× §14 mandates, on a 320px screen, it wraps to four lines and overflows
  /// a centred column. `headlineMedium` at 1.22× is 34sp — which is the
  /// prototype's largest number exactly — and is the largest display slot that
  /// survives the requirement.
  ///
  /// Clamping the theme's display end instead would change every screen that uses
  /// it, which is a Phase-1 decision to undo and not this phase's to take.
  static TextStyle titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!
          .copyWith(color: context.colors.ink);
}
