import 'package:evangelion/core/domain/entities/vespers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVespersHour', () {
    test('the evening is vespers from 21:00', () {
      // `eva/redesign.html:886` — `return h>=21||h<5;`.
      expect(isVespersHour(21), isTrue);
      expect(isVespersHour(22), isTrue);
      expect(isVespersHour(23), isTrue);
    });

    test('the small hours are vespers until 05:00', () {
      expect(isVespersHour(0), isTrue);
      expect(isVespersHour(4), isTrue);
    });

    test('the day is not vespers', () {
      expect(isVespersHour(5), isFalse);
      expect(isVespersHour(12), isFalse);
      expect(isVespersHour(20), isFalse);
    });

    test('the two boundaries are exclusive and inclusive as the prototype has them', () {
      // `h>=21` includes 21 and `h<5` excludes 5, so 21:00 is vespers and
      // 05:00 is not. A version that read `h>21` or `h<=5` would move the
      // window by an hour at each end.
      expect(isVespersHour(21), isTrue);
      expect(isVespersHour(5), isFalse);
    });
  });

  group('vespersFactor', () {
    test('it dims by 0.78 when vespers is on and it is vespers', () {
      // `eva/redesign.html:890` — `const vesp=vespersOn&&isNight()?0.78:1;`.
      expect(vespersFactor(enabled: true, hour: 22), closeTo(0.78, 1e-9));
    });

    test('it does not dim outside the window', () {
      expect(vespersFactor(enabled: true, hour: 12), closeTo(1, 1e-9));
    });

    test('it does not dim when the reader has turned it off', () {
      expect(vespersFactor(enabled: false, hour: 22), closeTo(1, 1e-9));
      expect(vespersFactor(enabled: false, hour: 3), closeTo(1, 1e-9));
    });

    test('the factor is the prototype\'s own 0.78', () {
      expect(kVespersDimFactor, closeTo(0.78, 1e-9));
    });
  });
}
