import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three enums Task 5.7 put in `core/domain/`, and their `fromStored`.
///
/// ## WHY THEY ARE IN `core/domain/` AT ALL
///
/// `UserSettings` holds all three, and `UserSettings` is in `core/domain/` — which
/// **Gate 1 holds Flutter-free**. An enum declared beside a Flutter widget could not
/// be named from `core/domain/entities/user_settings.dart` at all. That is §3's
/// placement test with two consumers on both sides of the boundary: the design
/// system draws the curtain and the stars, and the domain holds the preferences.
///
/// ## AND `fromStored` ANSWERS `null` FOR AN UNKNOWN VALUE, **NEVER** A GUESS
///
/// `AppThemeMode.fromStored` is the precedent and the argument is in its own words:
/// a wrong answer is worse than no answer, because the caller can tell `null` from
/// a default and choose. A reader who chose `shafts` and whose preference was
/// mangled must not be shown a different curtain with nothing saying the
/// preference was not read. `SettingsLocalDataSource` turns the `null` into the
/// field's own default and no more, so the failure is visible exactly once — in
/// the state, as a preference that came back at its default.
///
/// ## PURE DART, AND THE TEST IS IN `test/core/domain/entities/` BECAUSE OF IT
///
/// The enums are the shared kernel's, and `core/domain/entities/` is where the
/// kernel's tests live.
void main() {
  group('`CurtainShape`', () {
    test('is exactly the prototype\'s four, in its order', () {
      // `eva/redesign.html:655` — `data-s="0"`…`data-s="3"`, and the same four
      // written as an array at `:1463` — `['top','bottom','sides','shafts'][s]`.
      // Asserted as a list and not as a set because the ORDER is what the
      // segmented control paints in.
      expect(CurtainShape.values, <CurtainShape>[
        CurtainShape.top,
        CurtainShape.bottom,
        CurtainShape.sides,
        CurtainShape.shafts,
      ]);
    });

    test('each member round-trips through its stored value', () {
      for (final CurtainShape shape in CurtainShape.values) {
        expect(CurtainShape.fromStored(shape.storedValue), shape);
      }
    });

    test('and the stored values are the ones `shared_preferences` holds', () {
      // Asserted against **literals**, not against `.name`. §4 forbids
      // `describeEnum` precisely because `.name` is a derived spelling a rename
      // would silently change — and a stored preference written by an older build
      // would then be unreadable. The doc says "spelled out rather than derived
      // from the member name"; this is the test that holds it to that.
      expect(CurtainShape.top.storedValue, 'top');
      expect(CurtainShape.bottom.storedValue, 'bottom');
      expect(CurtainShape.sides.storedValue, 'sides');
      expect(CurtainShape.shafts.storedValue, 'shafts');
    });

    test('and an unknown stored value is `null`, never a guess', () {
      expect(CurtainShape.fromStored('TOP'), isNull, reason: 'case-sensitive');
      expect(CurtainShape.fromStored(''), isNull);
      expect(CurtainShape.fromStored(' top'), isNull);
      expect(
        CurtainShape.fromStored('0'),
        isNull,
        reason: 'the index is not the name',
      );
      expect(CurtainShape.fromStored('gem'), isNull);
    });

    test('and the stored values and the member names agree', () {
      // **A coincidence, asserted because it is one.** For `CurtainShape` the
      // stored value happens to equal the member name. A member added later whose
      // name differs (`shafts` → `hangingShafts`) is where that stops being true,
      // and this is the line that makes it a decision rather than an accident.
      for (final CurtainShape shape in CurtainShape.values) {
        expect(shape.name, shape.storedValue);
      }
    });
  });

  group('`SkyStarShape`', () {
    test('is exactly the prototype\'s four, in its order', () {
      // `eva/redesign.html:673` — `s-dot` / `s-star` / `s-cross` / `s-diamond`.
      expect(SkyStarShape.values, <SkyStarShape>[
        SkyStarShape.dot,
        SkyStarShape.star,
        SkyStarShape.cross,
        SkyStarShape.diamond,
      ]);
    });

    test('each member round-trips through its stored value', () {
      for (final SkyStarShape shape in SkyStarShape.values) {
        expect(SkyStarShape.fromStored(shape.storedValue), shape);
      }
    });

    test('and the stored values are the PROTOTYPE\'S class names', () {
      // **Not the member names.** The class name is the one that reaches the
      // geometry (`eva/redesign.html:120-123`), and the label is the settings
      // row's — the prototype's own untranslated English, *dot* / *star* /
      // *cross* / **gem**. A stored value that names the class is a value that can
      // be checked against the prototype's markup by eye.
      expect(SkyStarShape.dot.storedValue, 's-dot');
      expect(SkyStarShape.star.storedValue, 's-star');
      expect(SkyStarShape.cross.storedValue, 's-cross');
      expect(SkyStarShape.diamond.storedValue, 's-diamond');
    });

    test('and the stored values do NOT agree with the member names', () {
      // **The opposite of `CurtainShape`'s coincidence, and asserted for the same
      // reason.** Here they differ on purpose: `dot` is the word the reader sees
      // and `s-dot` is the class the geometry is written against.
      expect(SkyStarShape.dot.name, isNot(SkyStarShape.dot.storedValue));
      expect(SkyStarShape.diamond.name, 'diamond');
      expect(SkyStarShape.diamond.storedValue, 's-diamond');
    });

    test('and an unknown stored value is `null`, never a guess', () {
      expect(
        SkyStarShape.fromStored('dot'),
        isNull,
        reason: 'not the class name',
      );
      expect(SkyStarShape.fromStored('s-gem'), isNull, reason: 'not the label');
      expect(SkyStarShape.fromStored(''), isNull);
      expect(
        SkyStarShape.fromStored('S-DOT'),
        isNull,
        reason: 'case-sensitive',
      );
    });
  });

  group('`SkyStarField`', () {
    test('is exactly the prototype\'s three, in its order', () {
      // `eva/redesign.html:678` — `crown` / `high` / `full`, which are also the
      // keys of `POSRANGE` (`:1133`).
      expect(SkyStarField.values, <SkyStarField>[
        SkyStarField.crown,
        SkyStarField.high,
        SkyStarField.full,
      ]);
    });

    test('each member round-trips through its stored value', () {
      for (final SkyStarField field in SkyStarField.values) {
        expect(SkyStarField.fromStored(field.storedValue), field);
      }
    });

    test('and the stored values are the ones `shared_preferences` holds', () {
      expect(SkyStarField.crown.storedValue, 'crown');
      expect(SkyStarField.high.storedValue, 'high');
      expect(SkyStarField.full.storedValue, 'full');
    });

    test('and an unknown stored value is `null`, never a guess', () {
      expect(
        SkyStarField.fromStored('CROWN'),
        isNull,
        reason: 'case-sensitive',
      );
      expect(SkyStarField.fromStored(''), isNull);
      expect(SkyStarField.fromStored('wide'), isNull);
    });

    test('and the stored values and the member names agree', () {
      // The same coincidence as `CurtainShape`, asserted for the same reason.
      for (final SkyStarField field in SkyStarField.values) {
        expect(field.name, field.storedValue);
      }
    });
  });
}
