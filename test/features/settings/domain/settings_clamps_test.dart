import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/settings_clamps.dart';
import 'package:flutter_test/flutter_test.dart';

/// The **seven** Workshop clamps — the ranges `eva/redesign.html` declares and the
/// functions that keep a value inside them.
///
/// **AND THE EIGHTH — THE STAR COUNT'S — IS NOT HERE.** Its range and its clamp
/// live in `core/domain/entities/user_settings.dart`, because the sky feature
/// clamps the same number where it becomes a cap and a feature may not import
/// another feature (Gate 2). §3's placement test puts a two-consumer fact in the
/// shared kernel, and the star count's range is a two-consumer fact.
///
/// ## WHY THIS FILE IS **PURE DART** AND WHY IT LIVES HERE
///
/// AGENT_CONTEXT §6: "domain logic must not be buried in a widget". A slider that
/// clamps its own value is a widget computing a table, and the table is then
/// unreachable from the cubit that has to apply it. So the clamps are top-level
/// functions in `features/settings/domain/`, which Gate 1 holds Flutter-free.
///
/// `features/sky/domain/sky_star_cap.dart` is the precedent for a pure-Dart table
/// in a feature's own domain that is not a use case.
///
/// ## WHAT IS ASSERTED, AND WHY EACH ASSERTION IS A **CLAIM ABOUT A SPECIFIC THING**
///
/// * each range's two numbers are the **prototype's own literals**, asserted
///   against the numbers `eva/redesign.html` carries — so a range that drifted
///   fails here rather than being discovered in a slider;
/// * each clamp **holds** a value inside its range, **pulls up** one below it and
///   **pulls down** one above it;
/// * the one **stepped** range lands only on multiples of five, and on the
///   **nearest** one.
void main() {
  const List<_Range> ranges = <_Range>[
    _Range('reach', kReachMin, kReachMax, 1, clampReach),
    _Range('glow', kGlowMin, kGlowMax, 1, clampGlow),
    _Range('touchGlow', kTouchGlowMin, kTouchGlowMax, 1, clampTouchGlow),
    _Range('hue', kHueMin, kHueMax, 1, clampHue),
    _Range('starCount', kStarCountMin, kStarCountMax, 1, clampStarCount),
    _Range(
      'starBrightness',
      kStarBrightnessMin,
      kStarBrightnessMax,
      1,
      clampStarBrightness,
    ),
    _Range(
      'focusDelaySec',
      kFocusDelaySecMin,
      kFocusDelaySecMax,
      1,
      clampFocusDelaySec,
    ),
    _Range(
      'selahLengthSec',
      kSelahLengthSecMin,
      kSelahLengthSecMax,
      kSelahLengthSecStep,
      clampSelahLengthSec,
    ),
  ];

  group('the eight ranges are the PROTOTYPE\'S, and the constants say so', () {
    // Asserted against **literals**, and not against each other: the literals are
    // what `eva/redesign.html` carries, and a table that is only self-consistent
    // proves nothing about the prototype.
    test('the shader group', () {
      expect(kReachMin, 18, reason: 'eva/redesign.html:658 min="18"');
      expect(kReachMax, 110, reason: 'eva/redesign.html:658 max="110"');
      expect(kGlowMin, 40, reason: 'eva/redesign.html:659 min="40"');
      expect(kGlowMax, 130, reason: 'eva/redesign.html:659 max="130"');
      expect(kTouchGlowMin, 0, reason: 'eva/redesign.html:660 min="0"');
      expect(kTouchGlowMax, 100, reason: 'eva/redesign.html:660 max="100"');
      expect(kHueMin, 0, reason: 'eva/redesign.html:661 min="0"');
      expect(kHueMax, 360, reason: 'eva/redesign.html:661 max="360"');
    });

    test('the sky group', () {
      expect(kStarCountMin, 0, reason: 'eva/redesign.html:669 min="0"');
      expect(kStarCountMax, 60, reason: 'eva/redesign.html:669 max="60"');
      expect(kStarBrightnessMin, 30, reason: 'eva/redesign.html:670 min="30"');
      expect(
        kStarBrightnessMax,
        150,
        reason: 'eva/redesign.html:670 max="150"',
      );
    });

    test('the ritual group', () {
      expect(kFocusDelaySecMin, 2, reason: 'eva/redesign.html:683 min="2"');
      expect(kFocusDelaySecMax, 15, reason: 'eva/redesign.html:683 max="15"');
      expect(kSelahLengthSecMin, 15, reason: 'eva/redesign.html:684 min="15"');
      expect(
        kSelahLengthSecMax,
        120,
        reason: 'eva/redesign.html:684 max="120"',
      );
      expect(
        kSelahLengthSecStep,
        5,
        reason: 'eva/redesign.html:684 step="5" — the prototype\'s only step',
      );
    });

    test('and there are exactly eight of them', () {
      // The number is a claim about the task's scope (the brief's D2.3 table), so it
      // is asserted rather than implied by the table's length: a ninth range added
      // here is a change the task did not make.
      expect(ranges, hasLength(8));
    });
  });

  for (final _Range range in ranges) {
    group('the ${range.name} clamp', () {
      test('HOLDS every value inside its range', () {
        // **On the step**, and not on every integer: `selahLengthSec` is the
        // prototype's one stepped slider (`eva/redesign.html:684`, `step="5"`), so
        // 16 is inside its range and is still not a value it may hold. The range's
        // own step is in the fixture, so this assertion is about the clamp and not
        // about which ranges happen to be stepped.
        for (int value = range.min; value <= range.max; value += range.step) {
          expect(
            range.clamp(value),
            value,
            reason: '$value is inside ${range.name}\'s range',
          );
        }
      });

      test('PULLS UP a value below its minimum', () {
        expect(range.clamp(range.min - 1), range.min);
        expect(range.clamp(range.min - 1000), range.min);
      });

      test('PULLS DOWN a value above its maximum', () {
        expect(range.clamp(range.max + 1), range.max);
        expect(range.clamp(range.max + 1000), range.max);
      });
    });
  }

  group('and only ONE range is stepped', () {
    test('the selah steps by five and the other seven step by one', () {
      expect(
        ranges
            .where((_Range range) => range.step != 1)
            .map((_Range range) => range.name),
        <String>['selahLengthSec'],
        reason:
            '`eva/redesign.html` declares `step="5"` on exactly one slider, at :684. '
            'A second stepped range would be a range the prototype does not have.',
      );
    });
  });

  group('selahLengthSec is the only STEPPED range', () {
    test('and every reachable value is a multiple of five', () {
      // Swept across and beyond the range, because the clamp has to be total: a
      // hand-edited preference of any value must still land on the step.
      for (int value = -50; value <= 200; value++) {
        final int clamped = clampSelahLengthSec(value);
        expect(
          clamped % kSelahLengthSecStep,
          0,
          reason: '$value clamped to $clamped, which is not a multiple of five',
        );
        expect(
          clamped,
          inInclusiveRange(kSelahLengthSecMin, kSelahLengthSecMax),
          reason: '$value clamped to $clamped, which is out of range',
        );
      }
    });

    test('and every multiple of five IN the range is reachable', () {
      for (
        int value = kSelahLengthSecMin;
        value <= kSelahLengthSecMax;
        value += kSelahLengthSecStep
      ) {
        expect(clampSelahLengthSec(value), value);
      }
    });

    test('and it snaps to the NEAREST multiple', () {
      expect(clampSelahLengthSec(63), 65, reason: '63 is nearer 65 than 60');
      expect(clampSelahLengthSec(62), 60, reason: '62 is nearer 60 than 65');
      expect(clampSelahLengthSec(17), 15, reason: '17 is nearer 15 than 20');
      expect(clampSelahLengthSec(18), 20, reason: '18 is nearer 20 than 15');
    });

    test('and the step is five, which the prototype declares', () {
      expect(kSelahLengthSecStep, 5);
    });
  });
}

/// One range and the clamp that owns it.
///
/// **A top-level class and not a local one**, because Dart has no local classes —
/// and a test file that declares its fixture inside `main` does not compile, which
/// is the "a test that fails to compile is not a red" trap this repository's TDD
/// protocol names.
final class _Range {
  const _Range(this.name, this.min, this.max, this.step, this.clamp);

  /// The field's own name, for the failure message.
  final String name;

  /// The prototype's `min`.
  final int min;

  /// The prototype's `max`.
  final int max;

  /// The prototype's `step` — `1` for seven of the eight, and `5` for the selah.
  final int step;

  /// The clamp under test.
  final int Function(int) clamp;
}
