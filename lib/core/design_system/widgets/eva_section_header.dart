import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Which of the two prototype section labels this is.
///
/// `04-widget-inventory.md` §6 consolidates the shared `SectionLabel` with the
/// feature-local `ScreenSectionHeader` into one widget with a `size` variant,
/// because the two differ in nothing a caller would want to spell.
///
/// The prototypes disagree on more than size, though, and the difference is
/// recorded rather than averaged:
///
/// | | `SectionLabel` | `ScreenSectionHeader` |
/// | --- | --- | --- |
/// | source | `SettingsScreen.tsx:28-32` | `ProfileScreen.tsx:53` / `HomeScreen.tsx:78` |
/// | family | `F.mono` | `F.ui` |
/// | size | 9 | 16–17 |
/// | ink | `ink3` | `ink` |
///
/// The Settings label is the one with a surviving call site — the profile screen
/// was cut — so [section] is the mono-caps `ink3` form and is the default. [title]
/// is the bold UI form, for a header that introduces a screen rather than a group
/// inside one.
enum EvaSectionHeaderSize {
  /// The Settings group label: mono-caps, `ink3`. `SettingsScreen.tsx:28-32`.
  section,

  /// A screen title inside a body: UI sans, bold, `ink`. `ProfileScreen.tsx:53`.
  title,
}

/// A label above a block of content.
///
/// **The §3.1 deletion test is DEFERRED, not passed.** `04-widget-inventory.md`
/// §3.1 puts this widget on the demotion watch list: the Library and Profile cuts
/// left it with **one** shared call site, below the two-call-site bar §3.1 sets,
/// and says "Phase 1 must re-run the deletion test on all six and demote whatever
/// complexity does not reappear — most likely to a private `_`-prefixed widget
/// inside the feature that owns the single call site".
///
/// Phase 1 did not re-run it and no phase since has either, because **there is
/// still nowhere to put the result**: all four watch-list widgets below are used
/// only by the stub `SettingsPage`, and moving one into a feature that does not
/// use it would be inventing a call site to satisfy a rule rather than satisfying
/// the rule. Phase 5 built `features/auth/` and gave this widget no second caller
/// — the login screen needs a heading, not a section label — so the earlier
/// version of this comment, which said "no feature exists until Phase 5", stopped
/// being true at the end of that phase without this paragraph being updated.
/// It ships public, with the deferral recorded here rather than a passing claim
/// attached to it. Re-run it when `SettingsScreen` lands and the page it is
/// demoted into actually imports the widget.
///
/// Four of the six watch-list entries are in this phase — `SettingsGroup`,
/// `EvaSectionHeader`, `TextLink`, `ProgressBeads` — and all four say the same
/// thing here. `AvatarBadge` shipped in Phase 2 with the same note.
class EvaSectionHeader extends StatelessWidget {
  /// A header labelled [label], optionally with [trailing] on the right.
  const EvaSectionHeader({
    required this.label,
    this.size = EvaSectionHeaderSize.section,
    this.trailing,
    super.key,
  });

  /// The header's text.
  final String label;

  /// Which of the two prototype labels this is.
  final EvaSectionHeaderSize size;

  /// A control on the right — the prototype's screen headers put a "See all"-style
  /// affordance there. `null` for the Settings group labels.
  final Widget? trailing;

  /// `SettingsScreen.tsx:29` — `marginBottom: 10`, which is
  /// [EvaSpacing.md] + [EvaSpacing.xs].
  static const double bottomGap = EvaSpacing.md + EvaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    final Text header = Text(
      // `SettingsScreen.tsx:29` — `textTransform: 'uppercase'`. Flutter's `Text`
      // has no `textTransform`, so the transform is applied to the string. It is
      // applied **here** rather than inside the style switch because it changes
      // the glyphs, not the style, and a header that measured differently per
      // variant would be a layout surprise.
      size == EvaSectionHeaderSize.section ? label.toUpperCase() : label,
      // ## `arabicAware` WRAPS **BOTH** ARMS, AND ONLY NOW DOES IT MATTER
      //
      // The Arabic typography gate reads the *painted* family of every Arabic run, and
      // for six phases this widget was only ever pumped with Latin text: `SettingsGroup`
      // is the sole caller and `/settings` was a stub. Phase 9 wrote the screen, and the
      // gate immediately reported `SpaceMono المظهر` — a section header painting Arabic
      // in the mono-caps family, because `monoCaps` names SpaceMono and nothing asked
      // for Amiri.
      //
      // The swap belongs **here** rather than at the call site for the same reason
      // `reading_text_scale.dart` had to be deleted rather than composed at the call
      // site: this widget owns the text, so it owns the family that renders it. A
      // caller that remembered to wrap would be a per-call-site tax on a rule that is
      // not the caller's to remember.
      style: arabicAware(switch (size) {
        // `SettingsScreen.tsx:29` — `F.mono, 9, 700, letterSpacing 0.14em,
        // textTransform: uppercase, color: T.ink3`.
        EvaSectionHeaderSize.section => EvaTypography.monoCaps(
          colors,
        ).copyWith(color: colors.ink3, fontWeight: FontWeight.w700),
        // `ProfileScreen.tsx:53` — `F.ui, 16, 700, color: T.ink`. `titleMedium`
        // is Material 3's 16sp slot, so the prototype's 16 lands exactly.
        EvaSectionHeaderSize.title =>
          Theme.of(context).textTheme.titleMedium!
              .copyWith(color: colors.ink, fontWeight: FontWeight.w700),
      }, Directionality.of(context)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final Widget? control = trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: control == null
          ? header
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: header),
                const SizedBox(width: EvaSpacing.sm),
                // `Flexible`, not a bare child. `RenderFlex` hands an **inflexible**
                // child unbounded width when the row has a flex child, so a
                // `trailing` widget laid out at its intrinsic width came out
                // 336 wide on a 320 screen and overflowed by 24px. Found by
                // `surfaces_test.dart`, not by reading the code.
                Flexible(child: control),
              ],
            ),
    );
  }
}
