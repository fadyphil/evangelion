import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One answer option: its letter, its Arabic text and its English text.
///
/// ## AND IT OWNS ITS **TWO CONTROLLERS**
///
/// `EvaTextField`'s contract is that "the controller is the caller's", and this
/// widget **is** the caller — it hands two controllers to two fields and it
/// reports what they say. The page owns the *question*; the option owns its
/// own *two lines*.
///
/// The reason is the option's own shape: an option is a **pair** — the commit
/// schema types it as `{ar, en}` (`admin.routes.ts:41-44`) — and a pair of
/// fields that live in different places would need the page to hold two
/// controllers per option and to know which letter each pair belongs to. One
/// widget per option keeps that knowledge in one place.
///
/// ## AND THE SYNC IS **ONE-SIDED**
///
/// [didUpdateWidget] writes the incoming text into the controllers **only when
/// it differs from what they already hold**. That single rule is what makes
/// the two directions safe:
///
/// * the admin types, the controller changes, the widget reports it, and the
///   question on screen changes — and the next rebuild finds the controller
///   already holding that text, so it writes nothing and the caret does not
///   move;
/// * the server's draft arrives, the incoming text differs from the empty
///   controller, and the field is filled.
class QuestionOptionEditor extends StatefulWidget {
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
  State<QuestionOptionEditor> createState() => _QuestionOptionEditorState();
}

class _QuestionOptionEditorState extends State<QuestionOptionEditor> {
  final TextEditingController _arabic = TextEditingController();
  final TextEditingController _english = TextEditingController();

  @override
  void initState() {
    super.initState();
    _arabic.text = widget.arabicText;
    _english.text = widget.englishText;
    _arabic.addListener(_onArabicChanged);
    _english.addListener(_onEnglishChanged);
  }

  @override
  void didUpdateWidget(QuestionOptionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **The one-sided sync.** The controller is written only when the
    // incoming text differs from what it already holds, so a rebuild never
    // moves the caret and the server's draft never fights the admin.
    if (widget.arabicText != _arabic.text) {
      _arabic.text = widget.arabicText;
    }
    if (widget.englishText != _english.text) {
      _english.text = widget.englishText;
    }
  }

  @override
  void dispose() {
    _arabic
      ..removeListener(_onArabicChanged)
      ..dispose();
    _english
      ..removeListener(_onEnglishChanged)
      ..dispose();
    super.dispose();
  }

  void _onArabicChanged() => widget.onChanged(arabic: true, text: _arabic.text);

  void _onEnglishChanged() =>
      widget.onChanged(arabic: false, text: _english.text);

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
              widget.letter,
              style: EvaTypography.monoCaps(colors).copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: colors.emberInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (widget.onRemove case final VoidCallback remove)
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
        EvaTextField(
          label: strings.servantQuestionsOptionArLabel,
          controller: _arabic,
        ),
        EvaTextField(
          label: strings.servantQuestionsOptionEnLabel,
          controller: _english,
        ),
      ],
    );
  }
}
