import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Renders the approximate reset countdown line under the header
/// (`eva/redesign.html:618`, JS `:1073-1082`, D10).
class CommunionCountdownLine extends StatelessWidget {
  /// Creates the countdown line for [window].
  const CommunionCountdownLine({required this.window, this.now, super.key});

  /// The active window.
  final LeaderboardWindow window;

  /// Optional injected instant for deterministic testing.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    final Duration? left = resetLeftFor(window, now ?? DateTime.now());
    final String lineText;

    if (left == null) {
      lineText = strings.leaderboardNoReset;
    } else {
      final int days = left.inDays;
      final int hours = left.inHours % 24;
      lineText = strings.leaderboardResetsIn(
        strings.digits(days),
        strings.digits(hours),
        // **The unit letters are ARB values**, and the prototype's own `dU` /
        // `hU` rows (`eva/redesign.html:946`): `d`/`h` in English, `ي`/`س` in
        // Arabic. They were a `languageCode == 'ar'` fork in this widget, which
        // is a second copy of a rule the ARB already owns — and a third locale
        // would have silently got the English letter, with no string to change.
        strings.leaderboardDayUnit,
        strings.leaderboardHourUnit,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        lineText,
        textAlign: TextAlign.center,
        // **`arabicAware` and not a bare `monoCaps`.** The line carries the
        // locale's own unit letters (`ي`/`س`, `:946`) and, through `digits()`, its
        // own numerals — and **JetBrainsMono carries neither**: it has no Arabic
        // glyphs and no Arabic-Indic digit (measured against the five bundled
        // families' `cmap`s). Under RTL the family is Amiri, which carries all
        // three. The line's `≈` is in the **English** string only: Amiri has no
        // U+2248, so the Arabic string says `نحو` instead
        // (`app_ar.arb`'s `leaderboardResetsIn`).
        style: arabicAware(
          EvaTypography.monoCaps(colors)
              .copyWith(fontSize: 11, color: colors.ink2),
          direction,
        ),
      ),
    );
  }
}
