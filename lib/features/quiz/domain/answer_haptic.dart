import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';

/// The haptic a graded answer asks for — and `null` when there is no verdict.
///
/// ## THE PROTOTYPE'S TWO HAPTICS
///
/// `eva/redesign.html:1428` — a **correct** answer: `haptic(30)`, and the line
/// also raises the aurora (`V.spike=1.0`) and lights a flare (`addStar(true)`).
/// `eva/redesign.html:1429` — a **wrong** one: `haptic([40,60,40])`.
///
/// The two are **not** the same event, and the mapping is not a matter of taste:
/// the prototype's own line says which is which, and the reader feels the
/// difference — a firm bump for a right answer and a buzz for a wrong one.
///
/// **The rhythm is lost and the strength survives**, and that loss is recorded
/// on `core/domain/entities/ritual_haptic.dart`: `HapticFeedback` has no pattern
/// API, so `[40,60,40]` becomes its strongest element, a heavy impact. This
/// function therefore names the **moment** — `answerCorrect` / `answerWrong` —
/// and lets the vocabulary decide what the platform can actually do with it.
///
/// ## WHY `null` IS A VALUE AND NOT AN ERROR
///
/// **The prototype grades on the tap** (`:1423`'s one-shot `pick`), so it always
/// has a verdict when it fires a haptic. This client grades on the **second**
/// press — the grade is a `POST` — so there is a whole interval in which the
/// reader has chosen a letter and nothing has been graded. A haptic fired then
/// would be announcing a verdict the server has not given, and the failure mode
/// is the exact one AGENT_CONTEXT §5's trap 10 is about: a client claiming a
/// result the server never sent.
///
/// So `null` means **"there is no verdict, so there is nothing to announce"**,
/// and the caller fires nothing. A failed submit lands in the same place: the
/// answer is still ungraded, so there is still nothing to announce.
///
/// ## PURE DART
///
/// Gate 1 holds `features/*/domain` Flutter-free, so this file names no
/// `HapticFeedback` and no `package:flutter`. The platform call is
/// `core/design_system/effects/ritual_haptics.dart`'s, which is the only file
/// that calls it.
RitualHaptic? answerHapticFor(QuizAnswer? answer) {
  if (answer == null || !answer.isChecked) return null;
  return answer.isCorrect == true
      ? RitualHaptic.answerCorrect
      : RitualHaptic.answerWrong;
}
