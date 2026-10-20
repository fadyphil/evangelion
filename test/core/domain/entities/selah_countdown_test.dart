import 'package:evangelion/core/domain/entities/selah_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelahCountdown.start', () {
    test('it begins at the full silence', () {
      final SelahCountdown countdown = SelahCountdown.start(60);
      expect(countdown.total, 60);
      expect(countdown.remaining, 60);
      expect(countdown.isRunning, isTrue);
      expect(countdown.isComplete, isFalse);
    });

    test('the default is the prototype\'s 60 seconds', () {
      // `eva/redesign.html:1324` — `let selahDur=60`.
      expect(kSelahDefaultSeconds, 60);
      expect(SelahCountdown.start(kSelahDefaultSeconds).total, 60);
    });

    test('a silence of no seconds is refused', () {
      // The Workshop's range is 15…120 (`eva/redesign.html:684`), so zero is a
      // programmer error and is named rather than absorbed into a countdown
      // that finishes before it begins.
      expect(() => SelahCountdown.start(0), throwsArgumentError);
      expect(() => SelahCountdown.start(-1), throwsArgumentError);
    });
  });

  group('SelahCountdown.tick', () {
    test('it counts down one second at a time', () {
      final SelahCountdown countdown = SelahCountdown.start(3);
      expect(countdown.tick().remaining, 2);
      expect(countdown.tick().tick().remaining, 1);
    });

    test('the count reaches zero exactly on the last tick', () {
      SelahCountdown countdown = SelahCountdown.start(3);
      countdown = countdown.tick();
      countdown = countdown.tick();
      countdown = countdown.tick();
      expect(countdown.remaining, 0);
      expect(countdown.isComplete, isTrue);
      expect(countdown.isRunning, isFalse);
    });

    test('the total is not changed by a tick', () {
      expect(SelahCountdown.start(60).tick().total, 60);
    });

    test('ticking a finished countdown keeps it at zero', () {
      // The prototype stops its interval at zero (`if(left<=0) selahStop(true)`),
      // so a tick past the end is unreachable — but a countdown that went
      // negative would draw a negative number, and the guard costs one
      // comparison.
      final SelahCountdown finished = SelahCountdown.start(1).tick();
      expect(finished.remaining, 0);
      expect(finished.tick().remaining, 0);
    });
  });

  group('equality', () {
    test('two countdowns with the same numbers are equal', () {
      expect(SelahCountdown.start(60), SelahCountdown.start(60));
      expect(
        SelahCountdown.start(60).tick(),
        const SelahCountdown(total: 60, remaining: 59),
      );
    });

    test('two countdowns with different numbers are not', () {
      expect(SelahCountdown.start(60), isNot(SelahCountdown.start(30)));
      expect(
        const SelahCountdown(total: 60, remaining: 59),
        isNot(const SelahCountdown(total: 60, remaining: 58)),
      );
    });

    test('and it names its own numbers', () {
      // Failure output: a countdown printed as `Instance of` would make a
      // failed `expect` useless.
      expect(
        SelahCountdown.start(60).toString(),
        'SelahCountdown(total: 60, remaining: 60)',
      );
    });

    test('the hash agrees with the equality', () {
      expect(
        SelahCountdown.start(60).hashCode,
        SelahCountdown.start(60).hashCode,
      );
    });
  });
}
