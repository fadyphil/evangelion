import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One child on the cohort's roster.
///
/// ## THE PROGRESS STRING IS **VERBATIM**
///
/// [RosterStudent.questionsProgress] is the server's own `3/5` — a **string**,
/// not two numbers (`admin.routes.ts:412` writes `` `${answeredQ}/${totalQ}` ``).
/// It is drawn exactly as it arrived, and the two numbers beside it are drawn
/// through [AppLocalizationsArm.digits] so the Arabic arm shows Arabic-Indic
/// numerals.
///
/// **The asymmetry is deliberate and it is the server's.** The points and the
/// streak are counts this client owns the rendering of; the progress is the
/// server's own token, and a client that re-parsed it would own a second
/// formatting rule the server would have to be kept in step with. The
/// entity's own doc gives the same argument from the domain's side.
///
/// ## AND THE NAME IS **THE SERVER'S** TOO
///
/// [RosterStudent.fullName] is drawn as it arrived. The roster is a list of
/// children, and a client that prettified a child's name would be editing the
/// server's data.
class RosterRow extends StatelessWidget {
  /// A row for [student].
  const RosterRow({required this.student, super.key});

  /// The child the row is about.
  final RosterStudent student;

  /// The gap between the name and the three figures.
  static const double nameGap = EvaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EvaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            student.fullName,
            style: arabicAware(
              Theme.of(context).textTheme.titleMedium!,
              direction,
            ).copyWith(color: colors.ink),
          ),
          const SizedBox(height: nameGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _Figure(
                  label: strings.servantReportPoints,
                  value: strings.digits(student.totalPoints),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: strings.servantReportStreak,
                  value: strings.digits(student.currentStreak),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: strings.servantReportProgress,
                  // **The server's own token**, and not a re-formatting of it.
                  value: student.questionsProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One number and its caption.
///
/// ## WHY IT IS **NOT** A `StatTile`
///
/// Because `StatTile` is a panel — a `GlassSurface` with a radius and its own
/// padding — and a roster row with three of them would be three panels per
/// child, which is a different screen. The two share the **type** (a caption
/// over a figure) and not the surface, and this is the smaller of the two.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  /// The caption.
  final String label;

  /// The figure.
  final String value;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: arabicAware(
            Theme.of(context).textTheme.labelSmall!,
            direction,
          ).copyWith(color: colors.ink3),
        ),
        const SizedBox(height: EvaSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: arabicAware(EvaTypography.monoCaps(colors), direction)
              .copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: colors.ink,
                fontWeight: FontWeight.w400,
              ),
        ),
      ],
    );
  }
}
