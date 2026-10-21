import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One answer option: its letter, its Arabic text and its English text.
///
/// ## AND IT OWNS **NO CONTROLLER**, AND THE REASON IS THE **PAIR**
///
/// The option is a **pair** — the commit schema types it as `{ar, en}`
/// (`admin.routes.ts:41-44`) — and a pair of fields that lived in different
/// places would need the page to hold two controllers per option and to know
/// which letter each pair belongs to. **One widget per option keeps that
/// knowledge in one place**, and the widget holds the two texts the page hands
/// it and reports the one that changed.
///
/// ## AND THE **TWO HALVES** ARE **TWO CONTROLLED FIELDS**
///
/// `EvaControlledField` is the **one** controlled field in this repository
/// (`core/design_system/widgets/eva_controlled_field.dart`), and decision
/// 188's rule is that a value mirrored into a control is mirrored by that one
/// field, in one direction, and a programmatic write is never reported as the
/// reader's.
///
/// **This widget used to hand-roll that**, with a `_writing` boolean and two
/// controllers of its own, and the hand-rolled version is what produced six
/// defects of one class. The boolean was a flag that had to be set and cleared
/// around every write, and the failure mode of a flag that is not set is
/// exactly the defect it was there to prevent.
///
/// **The controlled field compares instead**, and there is no flag here to get
/// wrong: the field's own write is the controlled value, and the field knows
/// that because it is the only thing that ever writes into its own controller.
///
/// ## AND THE SERVER'S DRAFT STILL **FILLS** THE TWO FIELDS
///
/// The draft arrives as a new pair of texts, the fields' values change, and
/// the controlled field mirrors them — **reporting nothing**, because the
/// mirror is the field's own write. So the draft fills the two fields and the
/// cubit behind the page is not told the admin typed them.
class QuestionOptionEditor extends StatelessWidget {
  /// An option under [letter], with its two texts.
  const QuestionOptionEditor({
    required this.letter,
    required this.arabicText,
    required this.englishText,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  /// The option's letter — `A`, `B`, and so on.
  ///
  /// **A letter and not an index**, because the letter is what the commit
  /// body carries: the schema types the options as a map keyed by the letter,
  /// and the correct answer is one of those keys.
  final String letter;

  /// The option's Arabic text.
  final String arabicText;

  /// The option's English text.
  final String englishText;

  /// Reports that one of the two texts changed.
  ///
  /// [arabic] says **which** of them, because the option holds a pair and a
  /// callback that took one string could not say which half it meant.
  final void Function({required bool arabic, required String text}) onChanged;

  /// Takes the option away, or `null` when it cannot be taken away.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // The letter, and it is the option's **key** — the commit body
            // carries the options as a map keyed by it.
            Text(
              letter,
              style: EvaTypography.monoCaps(colors).copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: colors.emberInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onRemove case final VoidCallback remove)
              TextButton(
                onPressed: remove,
                child: Text(
                  strings.servantQuestionsRemoveOption,
                  style: arabicAware(
                    Theme.of(context).textTheme.labelSmall!,
                    Directionality.of(context),
                  ).copyWith(color: colors.ink2),
                ),
              ),
          ],
        ),
        EvaControlledField(
          label: strings.servantQuestionsOptionArLabel,
          value: arabicText,
          onChanged: (String text) => onChanged(arabic: true, text: text),
        ),
        EvaControlledField(
          label: strings.servantQuestionsOptionEnLabel,
          value: englishText,
          onChanged: (String text) => onChanged(arabic: false, text: text),
        ),
      ],
    );
  }
}
