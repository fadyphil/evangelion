import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The medals label and the count beside it — `eva/redesign.html:597`.
///
/// ```html
/// <div class="car-label" style="margin-top:24px"><span class="mono" data-i18n="medals">medals</span>
/// <span class="mono" data-i18n="medalsCount">4 / 12</span></div>
/// ```
///
/// ## THE COUNT IS **NOT** A TRANSLATED STRING
///
/// The prototype's "4 / 12" is an i18n row (`:936`), which is a transcription
/// of a fiction: the number of medals the reader has earned of the number
/// there are. **This client has no such fiction in a string table** — ADR-0022's
/// rule is that "no screen may render a hard-coded … medal …; the fiction lives
/// in data sources" — so the count is the medals port's `earned` and `total`,
/// and the two are composed here through [digits].
///
/// The separator is the prototype's own: a slash with a space on each side.
///
/// ## THE TOP MARGIN IS **24**, NOT THE `.car-label`'s 20
///
/// `:272` is `.car-label{margin:20px 18px 10px;…}` and `:597` overrides the
/// top with an inline `margin-top:24px`. The override is transcribed, because
/// the medals label is the first thing on the screen that follows a block of
/// content rather than a heading, and the prototype's own spacing says so.
///
/// ## AND THE LABEL'S TRACKING IS THE **`.mono` RULE'S**
///
/// `:597` and `:604` are `.car-label`s whose children are `<span class="mono">`
/// — so the caption carries `:30`'s `.16em` at `:30`'s 10.5px. See
/// [_CarLabel.tracking] for the resolved value and why it is not the `em`.
class JourneyMedalsLabel extends StatelessWidget {
  /// The label, with [earned] of [total] medals.
  const JourneyMedalsLabel({
    required this.earned,
    required this.total,
    super.key,
  });

  /// How many the reader has earned.
  final int earned;

  /// How many there are.
  final int total;

  /// The label's top margin — `eva/redesign.html:597`'s `margin-top:24px`.
  static const double gapAbove = 24;

  /// The label's bottom margin — `eva/redesign.html:272`'s `margin:20px 18px 10px`.
  static const double gapBelow = 10;

  /// The label's horizontal inset — `eva/redesign.html:272`'s `margin:… 18px …`.
  ///
  /// **18 and not the scroll's 14**, because the prototype's own `.car-label`
  /// is inset 18 inside a `.scroll` that is inset 14 (`:157`). The house's
  /// `library_carousel` owns the same inset for the same reason.
  static const double inset = 18;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    return _CarLabel(
      gapAbove: gapAbove,
      leading: strings.journeyMedals,
      trailing: '${strings.digits(earned)} / ${strings.digits(total)}',
    );
  }
}

/// The account label — `eva/redesign.html:604`.
///
/// ```html
/// <div class="car-label"><span class="mono" data-i18n="account">account</span></div>
/// ```
///
/// **The plain `.car-label`**, with no inline override, so its top margin is
/// the rule's own 20 rather than the medals label's 24.
class JourneyAccountLabel extends StatelessWidget {
  /// The label.
  const JourneyAccountLabel({super.key});

  /// The label's top margin — `eva/redesign.html:272`'s `margin:20px 18px 10px`.
  static const double gapAbove = 20;

  @override
  Widget build(BuildContext context) =>
      _CarLabel(gapAbove: gapAbove, leading: context.l10n.journeyAccount);
}

/// The prototype's `.car-label` — a two-ended mono row.
///
/// `eva/redesign.html:272` — `margin:20px 18px 10px; display:flex;
/// justify-content:space-between`, with two `.mono` children. The house's
/// `library_carousel` draws the same row for `/`; this is the same shape.
class _CarLabel extends StatelessWidget {
  const _CarLabel({
    required this.gapAbove,
    required this.leading,
    this.trailing,
  });

  /// The row's top margin.
  final double gapAbove;

  /// The left-hand text.
  final String leading;

  /// The right-hand text, or `null` for a row with only one end.
  final String? trailing;

  /// The caption's size — `eva/redesign.html:30`'s `font-size:10.5px`, the
  /// `.mono` rule's own size.
  static const double size = 10.5;

  /// The caption's Latin tracking — `eva/redesign.html:30`'s
  /// `letter-spacing:.16em`.
  ///
  /// **Transcribed as the resolved value and not as `em`.**
  /// `TextStyle.letterSpacing` is a **logical-pixel advance** and CSS's `em`
  /// is relative to the element's own font size, so `.16em` at [size] (10.5px)
  /// is **1.68**. The house's own twin of this rule — `EvaSectionHeader`'s
  /// section label, which draws the same `.mono` caption — premultiplies the
  /// same `.16em` by the same 10.5px and arrives at the same number.
  static const double tracking = 1.68;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    final TextStyle style = arabicAware(
      EvaTypography.monoCaps(colors).copyWith(
        fontSize: size,
        letterSpacing: direction == TextDirection.rtl ? 0 : tracking,
        color: colors.ink2,
      ),
      direction,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        JourneyMedalsLabel.inset,
        gapAbove,
        JourneyMedalsLabel.inset,
        JourneyMedalsLabel.gapBelow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              monoCapsText(leading, direction),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (trailing != null) ...<Widget>[
            // The prototype's `space-between` can put the two spans together,
            // and two mono labels that touch read as one string.
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                monoCapsText(trailing!, direction),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
