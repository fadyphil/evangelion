/// Well-formedness of a `String` as UTF-16, and the code units responsible.
///
/// ## WHY A HELPER AND NOT `runes.length == length`
///
/// The first version of these assertions used `value.runes.length == value.length`
/// as the well-formedness test, and it is **wrong in the exact case it was written
/// for**: `runes` yields an unpaired surrogate as a rune of its own, so a string
/// holding half an emoji satisfies it. Measured: `'\u{1F600}'.substring(0, 1)` has
/// `runes.length == 1` and `length == 1`, and `isRenderableText` says `false`.
///
/// **What this file originally claimed about the framework, and the correction.**
/// The doc here used to say `RenderParagraph` *throws* `ArgumentError: string is not
/// well-formed UTF-16` on such a string — which is correct and is recorded three
/// times in `AGENT_CONTEXT.md` (`:1757`, `:2156`, `:2226`). An intermediate draft
/// then "corrected" it to the opposite, on a re-measurement whose probe printed its
/// own verdict as a label beside the value it had not read. **The throw is real.**
///
/// Measured on the pinned toolchain (`Flutter 3.47.4`), for `Text`, `SelectableText`
/// and `Text.rich` alike: `tester.takeException()` is an `ArgumentError` reading
/// `Invalid argument(s): string is not well-formed UTF-16`, thrown from
/// `_NativeParagraphBuilder.addText` at `dart:ui/text.dart:3724` **during layout**.
/// The frame still paints, because the painting library catches a layout exception —
/// so a probe that checked "did a frame appear" concluded the opposite of the truth,
/// and a probe that never called `takeException()` fails the test outright.
///
/// So this helper is not a predictor of a crash; it is a predicate about the
/// **encoding**, which is what `renderable_text.dart`'s decision 95 rests on. The
/// cost of skipping the check is a caught `ArgumentError` per layout plus a tofu box
/// — not a silent nothing.
///
/// So this is the real check: walk the **code units**, and a high surrogate is only
/// legal when the unit after it is a low surrogate.
///
/// ## AND IT IS A **ONE-LINE DELEGATION** NOW, WHICH IS THE POINT OF DECISION 83
///
/// This function held a second copy of the walk for six phases, and Phase 8 moved the
/// rule into `lib/core/domain/entities/renderable_text.dart` so a **mapper** could ask
/// it — which is where decision 80 said the repair belonged. Leaving the copy here
/// would have been the situation decision 82 refuses for `arabic_digits.dart`: two
/// implementations that agree today and diverge the first time someone questions the
/// orphan-low-surrogate branch.
///
/// `isRenderableText` is a **strict superset** of the question this asks — it is the
/// same walk, and the same answer — so the delegation is not a behaviour change and
/// every Phase 7 test that used this helper is now testing the shipped rule.
///
/// The claim that this file delegates was written into `renderable_text.dart`'s doc
/// **before** the delegation existed, which is worth recording as a category of its
/// own: a doc comment asserting an invariant is not an enforcement of it, and the
/// only thing that noticed was reading both files side by side.
library;

import 'package:evangelion/core/domain/entities/renderable_text.dart';

/// Whether [text] is well-formed UTF-16: every surrogate is part of a pair.
///
/// The question `RenderParagraph` asks, asked here so a test can ask it before the
/// framework does — and now asked by `lib/`, so the tests and the mappers ask the
/// same function.
bool isWellFormedUtf16(String text) => isRenderableText(text);

/// Every unpaired surrogate code unit in [text], as `U+XXXX`, for a failure reason.
///
/// **This one stays here**, because `lib/` has no use for it: it exists to build a
/// *failure message*, and `renderable_text.dart` answers a question, not a
/// conversation. Deleting it would have meant the tests asserting a code unit by
/// recomputing it inline, which is how the copy above came to exist.
///
/// Named rather than inlined because a failure that says only "not well-formed"
/// makes the reader go and find which of the four candidates it was — and in every
/// case measured in this phase the answer was a lone U+D83D, which is the high half
/// of one specific emoji.
List<String> unpairedSurrogates(String text) {
  final List<int> units = text.codeUnits;
  final List<String> orphans = <String>[];
  for (int i = 0; i < units.length; i++) {
    final int unit = units[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 < units.length && _isLowSurrogate(units[i + 1])) {
        i++;
        continue;
      }
      orphans.add(_hex(unit));
    } else if (_isLowSurrogate(unit)) {
      orphans.add(_hex(unit));
    }
  }
  return orphans;
}

/// Whether [codeUnit] is a UTF-16 **high** surrogate, U+D800–U+DBFF.
bool isHighSurrogate(int codeUnit) => _isHighSurrogate(codeUnit);

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

String _hex(int unit) =>
    'U+${unit.toRadixString(16).toUpperCase().padLeft(4, '0')}';
