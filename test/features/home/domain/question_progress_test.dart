import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/domain/question_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// [firstUnansweredQuestionIndex] — red-first (AGENT_CONTEXT §6: domain logic is
/// extracted from a widget and TDD'd, never buried in a `build`).
///
/// ## WHAT THE PROTOTYPE CLAIMED, AND WHAT THE API SAYS
///
/// `HomeScreen.tsx:65` is `<ProgressBeads total={5} completed={2} current={2} />`.
/// That is **passage** progress across a four-card library grid — and the library
/// was cut (AGENT_CONTEXT §2, decision 1). There is no passage grid, and no
/// passage has five steps. What the live reading carries is **one** reflection
/// question.
///
/// So the row counts questions, and the three numbers come from two integers:
///
/// * `total` ← `TodayReading.questionCount`
/// * `completed` ← `TodayReading.answeredQuestionCount`
/// * `current` ← this function
void main() {
  group('with questions still to answer', () {
    test('the first open question is current', () {
      expect(
        firstUnansweredQuestionIndex(answered: 0, total: 3),
        0,
        reason: 'nothing answered, so bead 0 is the one to do',
      );
    });

    test('and it advances with the answered prefix', () {
      // The bead row is a **prefix** — `done = i < completed` — so the first open
      // index is the answered count, and nothing about *which* questions were
      // answered can move it.
      for (int answered = 0; answered < 3; answered++) {
        expect(
          firstUnansweredQuestionIndex(answered: answered, total: 3),
          answered,
          reason: '$answered of 3 answered',
        );
      }
    });

    test('and the live payload — one question, answered — is bead 0', () {
      expect(firstUnansweredQuestionIndex(answered: 1, total: 1), 0);
    });
  });

  group('with nothing left to answer', () {
    test('the last bead is the index, and it is inside the row', () {
      // Not `total`. See the file's doc for why the clamp is here at all.
      expect(firstUnansweredQuestionIndex(answered: 3, total: 3), 2);
    });

    test('and every value stays within `0 … total - 1` for a positive total', () {
      // The property that is worth stating, swept rather than sampled: whatever
      // the two counts say, the index names a bead that exists.
      for (int total = 1; total <= 8; total++) {
        for (int answered = -3; answered <= total + 3; answered++) {
          final int index = firstUnansweredQuestionIndex(
            answered: answered,
            total: total,
          );
          expect(
            index,
            inInclusiveRange(0, total - 1),
            reason: 'answered=$answered total=$total gave index=$index',
          );
        }
      }
    });
  });

  group('degenerate totals', () {
    test('zero questions has no index at all', () {
      // `-1` rather than `0`: `ProgressBeads` renders `SizedBox.shrink()` for a
      // `total` of `0` and never calls `beadStateAt`, so the value is unobserved
      // today — and `-1` is the one index that cannot match any bead if a future
      // widget starts drawing them. **The rendering of `0 / 0` is a panel
      // decision**, documented in `today_reading_panel.dart` and asserted in
      // `home_page_test.dart`; it is not this function's.
      expect(firstUnansweredQuestionIndex(answered: 0, total: 0), -1);
      expect(firstUnansweredQuestionIndex(answered: 3, total: 0), -1);
    });

    test(
      'a negative total is treated as zero, not as an index into nothing',
      () {
        expect(firstUnansweredQuestionIndex(answered: 0, total: -4), -1);
      },
    );

    test('an answered count past the total is clamped, not trusted', () {
      // Reachable only from a hand-built entity — the mapper counts flags, so it
      // cannot exceed the array's length. Clamping anyway means a future
      // server-sent count cannot index past the end of the row.
      expect(firstUnansweredQuestionIndex(answered: 9, total: 3), 2);
    });

    test('a negative answered count is treated as none', () {
      expect(firstUnansweredQuestionIndex(answered: -2, total: 3), 0);
    });
  });

  group('against the real widget, not a re-derivation', () {
    // The half that catches a function which is right in isolation and wrong in
    // composition. `beadStates` is `ProgressBeads`' own, so the row these numbers
    // parameterise is the row that renders.

    test('1 of 3 answered shades a prefix and rings the next bead', () {
      expect(
        beadStates(
          total: 3,
          completed: 1,
          current: firstUnansweredQuestionIndex(answered: 1, total: 3),
        ),
        <ProgressBeadState>[
          ProgressBeadState.done,
          ProgressBeadState.current,
          ProgressBeadState.upcoming,
        ],
      );
    });

    test('0 of 3 answered rings bead 0 and leaves the rest open', () {
      expect(
        beadStates(
          total: 3,
          completed: 0,
          current: firstUnansweredQuestionIndex(answered: 0, total: 3),
        ),
        <ProgressBeadState>[
          ProgressBeadState.current,
          ProgressBeadState.upcoming,
          ProgressBeadState.upcoming,
        ],
      );
    });

    test(
      'a finished row has no current bead — and that is what `done` means',
      () {
        // `beadStateAt` takes `i < completed` **first**, so a bead that is done
        // never un-finishes however `current` is set. The prototype's rule
        // (`ds.tsx:357-358`) says the same thing in a comment nobody read:
        // `const curr = i === current && !done`.
        expect(
          beadStates(
            total: 3,
            completed: 3,
            current: firstUnansweredQuestionIndex(answered: 3, total: 3),
          ),
          <ProgressBeadState>[
            ProgressBeadState.done,
            ProgressBeadState.done,
            ProgressBeadState.done,
          ],
        );
      },
    );

    test(
      'and the clamp changes no rendered state today — measured, not assumed',
      () {
        // The file's doc used to claim the clamp keeps a bead reading as "current"
        // when everything is answered. It does not, and this is the measurement
        // that killed the claim: both candidates render three `done` beads.
        expect(
          beadStates(total: 3, completed: 3, current: 2),
          beadStates(total: 3, completed: 3, current: 3),
          reason:
              'if these ever differ, the clamp has become observable and the '
              "file's doc claim is no longer describing today's behaviour",
        );
      },
    );

    test(
      'and a zero-question row renders nothing, which is not this function',
      () {
        expect(
          beadStates(
            total: 0,
            completed: 0,
            current: firstUnansweredQuestionIndex(answered: 0, total: 0),
          ),
          isEmpty,
        );
      },
    );
  });
}
