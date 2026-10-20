import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The four account rows — `eva/redesign.html:605-608`.
///
/// ```html
/// <button class="srow" id="rowBoard"><span data-i18n="rowBoard">The Communion</span> <span class="ar">›</span></button>
/// <button class="srow" id="rowSettings"><span data-i18n="rowSet">Settings</span> <span class="ar">›</span></button>
/// <button class="srow"><span data-i18n="rowShare">Share progress</span> <span class="ar">›</span></button>
/// <button class="srow"><span data-i18n="rowPlans">Reading plans</span> <span class="ar">›</span></button>
/// ```
///
/// ## THE ROW IS [SettingsTile], BECAUSE [SettingsTile] **IS** THE PROTOTYPE'S ROW
///
/// `:419-421`'s `.srow` is `padding:15px 4px`, a 14.5px title, a 1px
/// `rgba(255,255,255,.06)` bottom hairline, and a hover that slides the row
/// 4px. `SettingsTile`'s own constants are **measured off that same block** —
/// `minHeight` 56, `verticalPadding` 15, `horizontalPadding` 4,
/// `hairlineAlpha` 0.06, `hoverShift` 4 — so drawing a second row here would be
/// a second implementation of a row the design system already owns.
///
/// ## TWO LIVE, TWO DEAD, AND THE DEAD ONES SAY WHY
///
/// `:605` and `:606` have handlers (`:1284` and `:1453`). **`:607` and `:608`
/// have none**: `el('rowShare')` and `el('rowPlans')` appear **nowhere** in the
/// prototype's script, and the backend's fourteen routes include no endpoint
/// for either. So they are rendered and disabled, and §14's rule applies — a
/// reader has to be told **why** a control cannot be pressed, not only that it
/// cannot. The reason is in the accessible name, and the painted title is the
/// prototype's own.
///
/// The dimming is the house's disabled treatment — `kEvaButtonDisabledOpacity`
/// (0.45) — and **the redesign has no disabled row to copy**: its only
/// `:disabled` rule is `eva/redesign.html:347`'s `cursor:default`, which changes
/// no opacity. So 0.45 is the value the superseded prototype's disabled button
/// carried, and this is a recorded divergence rather than a transcription.
class JourneyAccountRows extends StatelessWidget {
  /// The four rows, with the two live ones wired.
  const JourneyAccountRows({
    required this.onOpenBoard,
    required this.onOpenSettings,
    super.key,
  });

  /// Invoked when "The Communion" is pressed.
  final VoidCallback onOpenBoard;

  /// Invoked when "Settings" is pressed.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AccountRow(title: strings.journeyRowBoard, onTap: onOpenBoard),
        _AccountRow(title: strings.journeyRowSettings, onTap: onOpenSettings),
        // `:607` — no handler in the prototype, no endpoint in the backend.
        _AccountRow(title: strings.journeyRowShare, dead: true),
        // `:608` — the same.
        _AccountRow(title: strings.journeyRowPlans, dead: true),
      ],
    );
  }
}

/// One account row — a [SettingsTile] with the prototype's `›` on its right.
///
/// The **trailing chevron** is `:421`'s `.srow .ar` — mono 11px, `--ink-1` —
/// and it is **U+203A**, which is in all five bundled families (measured, and
/// asserted by `test/features/journey/journey_glyph_test.dart`).
///
/// ## THE CHEVRON MIRRORS UNDER RTL, AND **THE ENGINE DOES IT**
///
/// `:138` is `[dir=rtl] .srow .ar{display:inline-block;transform:scaleX(-1)}` —
/// the prototype flips the box. **U+203A is a `Bidi_Mirrored` character**, so
/// the text engine already renders it as `‹` in a right-to-left paragraph, and
/// an explicit `scaleX(-1)` on top of that would flip it **back**.
///
/// So this row does not transform it, and the mirroring is asserted on the
/// **painted pixels** — the chevron's ink sits on the left of its box under
/// RTL and on the right under LTR — by
/// `test/features/journey/journey_widgets_test.dart`.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.title, this.onTap, this.dead = false});

  /// The row's title.
  final String title;

  /// What to run when the row is pressed. `null` for a dead row.
  final VoidCallback? onTap;

  /// Whether the row is one of the two the prototype never wired.
  final bool dead;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;

    final bool enabled = onTap != null;

    final Widget row = SettingsTile(
      title: title,
      trailing: ExcludeSemantics(
        child: Text(
          '›',
          style: TextStyle(
            // **Pinned to the mono face on both arms.** `›` is not Arabic
            // content, and the mono face is the one that carries it.
            fontFamily: EvaTypography.monoFamily,
            fontSize: 11,
            color: colors.ink2,
          ),
        ),
      ),
      onTap: onTap,
    );

    if (enabled) return row;

    // A dead row: the accessible name carries the reason, and the node has
    // **no tap action** — a control announced as disabled and answering a tap
    // has told the reader a lie.
    return Semantics(
      button: true,
      enabled: false,
      label: '$title — ${strings.journeyUnavailableSuffix}',
      excludeSemantics: true,
      child: Opacity(opacity: kEvaButtonDisabledOpacity, child: row),
    );
  }
}
