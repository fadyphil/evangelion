import 'package:evangelion/core/design_system/effects/neural_background.dart';
import 'package:evangelion/core/design_system/effects/neural_orbs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The eight accent colours of `ORB_CONFIGS`, by name.
///
/// `eva/src/components/ds.tsx:68-114`. These are NOT design-system tokens —
/// `03-design-system.md` §5.1 publishes fourteen colour tokens and none of them
/// is an orb accent, and the sticker palette is a different seven-colour
/// vocabulary. So the values live here, once, as a transcription of the
/// prototype, and the test asserts the transcription rather than the intent.
const Map<String, Color> _prototypeOrbColours = <String, Color>{
  '6C3FE8': Color(0xFF6C3FE8),
  '3B5BDB': Color(0xFF3B5BDB),
  'C026D3': Color(0xFFC026D3),
  '14B8A6': Color(0xFF14B8A6),
  '06B6D4': Color(0xFF06B6D4),
  'F59E0B': Color(0xFFF59E0B),
  'F43F5E': Color(0xFFF43F5E),
};

/// `NeuralVariant` → the prototype's own name for that screen's orb group.
///
/// Spelled out rather than derived from `variant.index`. See the D2 note on
/// [orbGroupFor] for why index arithmetic would be wrong.
const Map<NeuralVariant, OrbGroup> _expected = <NeuralVariant, OrbGroup>{
  NeuralVariant.login: OrbGroup.login,
  NeuralVariant.home: OrbGroup.home,
  NeuralVariant.readingEn: OrbGroup.readingEn,
  NeuralVariant.readingAr: OrbGroup.readingAr,
  NeuralVariant.quiz: OrbGroup.quiz,
  NeuralVariant.result: OrbGroup.result,
  NeuralVariant.settings: OrbGroup.settings,
};

/// Every orb of every group, flattened in `OrbGroup.values` order.
///
/// The reason the field-by-field tables below read as one flat list per field:
/// a per-group nested literal would silently accept a group that gained or lost
/// an orb, because the assertion would be comparing one group against itself.
/// ['the table still holds twenty-one orbs'] is what closes that.
List<OrbSpec> get _allOrbSpecs => <OrbSpec>[
  for (final OrbGroup group in OrbGroup.values) ...orbGroups[group]!,
];

/// [read] applied to every orb, in group order.
List<T> _allOrbs<T>(T Function(OrbSpec orb) read) => <T>[
  for (final OrbSpec orb in _allOrbSpecs) read(orb),
];

/// The hex of [color], uppercase, without a leading `#`.
///
/// Matches the spelling `ORB_CONFIGS` uses (`'#6C3FE8'`), so a transcribed value
/// can be compared against the prototype as it is written rather than as a
/// packed `int` — which is the whole point of the table.
String _hexOf(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .toUpperCase()
    .padLeft(6, '0');

void main() {
  group('the orb table is a verbatim transcription of ORB_CONFIGS', () {
    test('every one of the eight prototype groups exists', () {
      // Including `profile`. The Profile screen was cut (AGENT_CONTEXT §2,
      // decision 1) but its group is kept so the table stays index-aligned with
      // `ds.tsx` and a future revival is a data change, not a re-index.
      expect(OrbGroup.values, hasLength(8));
      expect(orbGroups.keys, containsAll(OrbGroup.values));
    });

    test('group sizes match the prototype', () {
      // ds.tsx: 3, 4, 2, 2, 3, 3, 2, 2.
      expect(orbGroups[OrbGroup.login], hasLength(3));
      expect(orbGroups[OrbGroup.home], hasLength(4));
      expect(orbGroups[OrbGroup.readingEn], hasLength(2));
      expect(orbGroups[OrbGroup.readingAr], hasLength(2));
      expect(orbGroups[OrbGroup.quiz], hasLength(3));
      expect(orbGroups[OrbGroup.result], hasLength(3));
      expect(orbGroups[OrbGroup.profile], hasLength(2));
      expect(orbGroups[OrbGroup.settings], hasLength(2));
    });

    test('the profile group is still the profile group', () {
      // The cut must not quietly become a hole: if `profile` were dropped from
      // the map, `settings` would be the next index up and every future reader
      // of the table would have to re-derive the off-by-one from scratch.
      expect(orbGroups[OrbGroup.profile]!.map((OrbSpec o) => o.color), <Color>[
        _prototypeOrbColours['14B8A6']!,
        _prototypeOrbColours['3B5BDB']!,
      ]);
    });

    test('the table still holds twenty-one orbs', () {
      // The guard the flat per-field tables below depend on. They read one list
      // per field across every group, which is what makes a field edit in any
      // group fail — but a group that *gained* an orb would push every later
      // field's list out of alignment and only surface as a confusing diff. This
      // names the total so that failure is impossible to misread.
      //
      // ds.tsx: 3 + 4 + 2 + 2 + 3 + 3 + 2 + 2.
      expect(_allOrbSpecs, hasLength(21));
    });
  });

  group('D2 — every variant resolves through an explicit table', () {
    test('the mapping is total and names the group, not an index', () {
      for (final MapEntry<NeuralVariant, OrbGroup> entry in _expected.entries) {
        expect(
          orbGroupFor(entry.key),
          entry.value,
          reason: '${entry.key.name} must resolve to ${entry.value.name}',
        );
      }
    });

    test('settings gets the Settings orbs, NOT the Profile orbs', () {
      // THE DEFECT. `ORB_CONFIGS` has eight entries and `NeuralVariant` has
      // seven values, because index 6 is the Profile screen and it was cut
      // (AGENT_CONTEXT §2, decision 1). `variant.index` therefore hands
      // `settings` — the last enum value, index 6 — the *Profile* pair
      // `#14B8A6 / #3B5BDB` instead of the Settings pair `#6C3FE8 / #06B6D4`.
      // Nothing about that is visible to the eye; it is only wrong on paper,
      // which is exactly why it has to be a test rather than a code review.
      expect(
        orbsFor(NeuralVariant.settings).map((OrbSpec o) => o.color),
        <Color>[
          _prototypeOrbColours['6C3FE8']!,
          _prototypeOrbColours['06B6D4']!,
        ],
      );
    });

    test('no two variants silently share an orb group', () {
      final Set<List<Color>> signatures = <List<Color>>{
        for (final NeuralVariant variant in NeuralVariant.values)
          orbsFor(variant).map((OrbSpec o) => o.color).toList(),
      };
      expect(
        signatures,
        hasLength(NeuralVariant.values.length),
        reason:
            'readingAr and quiz both open with a violet orb but the whole '
            'sequence must still differ, or one screen\'s background is '
            'another\'s by accident',
      );
    });

    test(
      'readingEn and readingAr are different screens with different orbs',
      () {
        expect(
          orbsFor(NeuralVariant.readingEn).map((OrbSpec o) => o.color),
          isNot(orbsFor(NeuralVariant.readingAr).map((OrbSpec o) => o.color)),
        );
      },
    );

    test('every orb colour is one of the seven prototype accents', () {
      final Set<Color> known = _prototypeOrbColours.values.toSet();
      for (final NeuralVariant variant in NeuralVariant.values) {
        for (final OrbSpec orb in orbsFor(variant)) {
          expect(
            known,
            contains(orb.color),
            reason:
                '${variant.name} carries a colour ORB_CONFIGS does not '
                'contain: ${orb.color.toARGB32().toRadixString(16)}',
          );
        }
      }
    });

    test('every variant ships at least one orb', () {
      // `NeuralTier.low` is the only thing allowed to render zero orbs, and it
      // does so by skipping the table rather than by emptying it.
      for (final NeuralVariant variant in NeuralVariant.values) {
        expect(orbsFor(variant), isNotEmpty, reason: variant.name);
      }
    });

    test('the home variant has four orbs and the login variant three', () {
      // The prototype's only two screens with more than two orbs.
      expect(orbsFor(NeuralVariant.home), hasLength(4));
      expect(orbsFor(NeuralVariant.login), hasLength(3));
    });
  });

  group('D3 — per-orb floats', () {
    test('a float path starts and ends at rest, unscaled', () {
      // All three keyframe sets in index.css:49-65 close the loop on
      // `translate(0,0) scale(1)`. If the painter did not return to rest the
      // orb would jump once per cycle.
      for (final OrbFloatPath path in OrbFloatPath.values) {
        expect(orbFloatOffset(path, 0), const Offset(0, 0), reason: path.name);
        expect(orbFloatOffset(path, 1), const Offset(0, 0), reason: path.name);
        expect(orbFloatScale(path, 0), 1.0, reason: path.name);
        expect(orbFloatScale(path, 1), 1.0, reason: path.name);
      }
    });

    test('orb-float-a hits its documented keyframes', () {
      // index.css:50-53 — 30% => (28,-22) 1.07 · 60% => (-18,30) 0.94.
      expect(orbFloatOffset(OrbFloatPath.a, 0.3), const Offset(28, -22));
      expect(orbFloatOffset(OrbFloatPath.a, 0.6), const Offset(-18, 30));
      expect(orbFloatScale(OrbFloatPath.a, 0.3), 1.07);
      expect(orbFloatScale(OrbFloatPath.a, 0.6), 0.94);
    });

    test('orb-float-b hits its documented keyframes', () {
      // index.css:56-59 — 40% => (-30,18) 1.05 · 75% => (22,-28) 0.92.
      expect(orbFloatOffset(OrbFloatPath.b, 0.4), const Offset(-30, 18));
      expect(orbFloatOffset(OrbFloatPath.b, 0.75), const Offset(22, -28));
      expect(orbFloatScale(OrbFloatPath.b, 0.4), 1.05);
      expect(orbFloatScale(OrbFloatPath.b, 0.75), 0.92);
    });

    test('orb-float-c hits its documented keyframe', () {
      // index.css:62-64 — 50% => (12,36) 1.1.
      expect(orbFloatOffset(OrbFloatPath.c, 0.5), const Offset(12, 36));
      expect(orbFloatScale(OrbFloatPath.c, 0.5), 1.1);
    });

    test('a float path is a closed loop — phase 0 and phase 1 agree', () {
      for (final OrbFloatPath path in OrbFloatPath.values) {
        for (final double phase in <double>[0, 0.17, 0.41, 0.83]) {
          expect(
            orbFloatOffset(path, (phase + 1) % 1.0).distance,
            closeTo(orbFloatOffset(path, phase).distance, 1e-9),
            reason: '$path at $phase',
          );
        }
      }
    });

    test('every phase stays inside the prototype\'s translation envelope', () {
      // The largest excursion any keyframe declares is 30px horizontally and
      // 36px vertically (orb-float-c). A phase that escaped that envelope would
      // be a lerp implemented with the wrong endpoints.
      for (final OrbFloatPath path in OrbFloatPath.values) {
        for (int step = 0; step <= 100; step++) {
          final Offset offset = orbFloatOffset(path, step / 100);
          expect(offset.dx.abs(), lessThanOrEqualTo(30.000001));
          expect(offset.dy.abs(), lessThanOrEqualTo(36.000001));
          expect(orbFloatScale(path, step / 100), inInclusiveRange(0.92, 1.1));
        }
      }
    });

    test('no two float paths are identical', () {
      final Set<String> signatures = <String>{
        for (final OrbFloatPath path in OrbFloatPath.values)
          <String>[
            for (int step = 0; step <= 20; step++)
              orbFloatOffset(path, step / 20).toString(),
          ].join('|'),
      };
      expect(signatures, hasLength(3));
    });

    test('the float phase stride is derived, not stored per orb', () {
      // §13.2 mitigation 2: 64 controllers become 3, and per-orb phase comes
      // from `i / orbCount`. The prototype's own float *durations* cannot survive
      // that, and the durations are recorded in the table for audit while the
      // phase is what actually drives the painter.
      for (final OrbSpec orb in orbsFor(NeuralVariant.home)) {
        expect(orb.floatSeconds, inInclusiveRange(14, 28));
        expect(orb.hueSeconds, inInclusiveRange(7, 14));
      }
    });
  });

  group('D3 — hue direction, delay and phase', () {
    test('the two hue directions are opposite signs', () {
      expect(hueDirectionSign(OrbHueDirection.forward), 1);
      expect(hueDirectionSign(OrbHueDirection.reverse), -1);
    });

    test('the home group keeps the prototype\'s a / b / a / b alternation', () {
      // ds.tsx:77-80 — float a, b, c, a; hue-cycle, hue-cycle-rev,
      // hue-cycle, hue-cycle-rev.
      expect(
        orbsFor(NeuralVariant.home).map((OrbSpec o) => o.hueDirection),
        <OrbHueDirection>[
          OrbHueDirection.forward,
          OrbHueDirection.reverse,
          OrbHueDirection.forward,
          OrbHueDirection.reverse,
        ],
      );
    });

    test('the home group keeps float paths a, b, c, a', () {
      expect(
        orbsFor(NeuralVariant.home).map((OrbSpec o) => o.floatPath),
        <OrbFloatPath>[
          OrbFloatPath.a,
          OrbFloatPath.b,
          OrbFloatPath.c,
          OrbFloatPath.a,
        ],
      );
    });

    test('the reading EN group is 2 orbs, forward then reverse', () {
      // ds.tsx:84-85.
      expect(
        orbsFor(NeuralVariant.readingEn).map((OrbSpec o) => o.hueDirection),
        <OrbHueDirection>[OrbHueDirection.forward, OrbHueDirection.reverse],
      );
    });

    test('the profile group is the only one that opens with a reverse cycle', () {
      // ds.tsx:106 — Profile's first orb is `hue-cycle-rev` where every other
      // group's first orb is `hue-cycle`. It is the cut screen, so this is the
      // one place the odd one out is still provable.
      expect(
        orbGroups[OrbGroup.profile]!.first.hueDirection,
        OrbHueDirection.reverse,
      );
      for (final NeuralVariant variant in NeuralVariant.values) {
        expect(
          orbsFor(variant).first.hueDirection,
          OrbHueDirection.forward,
          reason: '${variant.name} opens forward in the prototype',
        );
      }
    });

    test('hueDelay is preserved as a phase offset, not as a timer', () {
      // The prototype animates `hue-cycle <hueDur>s linear <hueDelay>s`, so a
      // negative delay starts the orb part-way through its cycle. A negative
      // `animation-delay` on a positive-duration infinite animation is exactly
      // a phase advance, so the same thing is expressed as a fraction.
      expect(
        huePhaseFor(clock: 0, phaseOffset: hueDelayPhase(-3, 8)),
        closeTo(0.375, 1e-12),
        reason: '-3s into an 8s cycle is 3/8 of the way round',
      );
      expect(huePhaseFor(clock: 0, phaseOffset: hueDelayPhase(0, 11)), 0.0);
    });

    test('huePhaseFor wraps into [0, 1) and is periodic in the clock', () {
      for (final double offset in <double>[0, 0.11, 0.375, 0.9]) {
        for (final double clock in <double>[0, 0.2, 0.5, 0.83, 1.7]) {
          final double phase = huePhaseFor(clock: clock, phaseOffset: offset);
          expect(phase, inInclusiveRange(0.0, 0.9999999999));
          expect(
            huePhaseFor(clock: clock + 1, phaseOffset: offset),
            closeTo(phase, 1e-12),
            reason: 'one full clock turn must be a no-op',
          );
        }
      }
    });

    test('a negative animation-delay advances, never wraps backwards', () {
      // -0.375 and +0.625 are the same phase; the prototype's delays are all
      // <= 0, so every orb starts ahead of the shared clock, never behind.
      expect(huePhaseFor(clock: 0, phaseOffset: -0.375), 0.625);
    });
  });

  group('parallax', () {
    test('the pointer offset spans the prototype\'s 32 x 24 range', () {
      // ds.tsx:126-129 — `((clientX / innerWidth - 0.5) * 32, (clientY /
      // innerHeight - 0.5) * 24)`.
      expect(
        pointerOffsetFor(size: const Size(400, 800), local: const Offset(0, 0)),
        const Offset(-16, -12),
      );
      expect(
        pointerOffsetFor(
          size: const Size(400, 800),
          local: const Offset(400, 800),
        ),
        const Offset(16, 12),
      );
      expect(
        pointerOffsetFor(
          size: const Size(400, 800),
          local: const Offset(200, 400),
        ),
        Offset.zero,
      );
    });

    test('parallaxScale is the prototype\'s own `parallax / 14`', () {
      expect(kMaxParallax, 14.0, reason: 'ds.tsx:71 — the largest parallax');
      for (final OrbSpec orb in orbsFor(NeuralVariant.login)) {
        expect(orb.parallaxScale, closeTo(orb.parallax / 14, 1e-12));
      }
    });

    test('a full-parallax orb moves exactly as far as the pointer offset', () {
      final OrbSpec strongest = orbsFor(NeuralVariant.login).first;
      expect(strongest.parallax, 14.0);
      expect(strongest.parallaxScale, 1.0);
      const Offset pointer = Offset(16, 12);
      expect(
        Offset(
          pointer.dx * strongest.parallaxScale,
          pointer.dy * strongest.parallaxScale,
        ),
        pointer,
      );
    });

    test('a zero-parallax orb does not move at all', () {
      // Nothing in the prototype is 0, but the arithmetic has to survive an
      // orb that opts out rather than dividing into a NaN.
      expect(const OrbSpec.flat().parallaxScale, 0.0);
    });

    test('every declared parallax is the prototype\'s, none invented', () {
      const List<double> all = <double>[
        14, 9, 6, // login
        12, 8, 5, 3, // home
        10, 6, // reading en
        11, 7, // reading ar
        13, 9, 5, // quiz
        12, 8, 4, // result
        10, 6, // profile
        11, 6, // settings
      ];
      final List<double> read = <double>[
        for (final OrbGroup group in OrbGroup.values)
          for (final OrbSpec orb in orbGroups[group]!) orb.parallax,
      ];
      expect(read, all);
    });
  });

  group('orb geometry is transcribed verbatim', () {
    test('the login orbs are 420/360/280 at their prototype offsets', () {
      final List<OrbSpec> orbs = orbsFor(NeuralVariant.login);
      expect(orbs.map((OrbSpec o) => Offset(o.x, o.y)), <Offset>[
        const Offset(-100, -80),
        const Offset(180, 260),
        const Offset(60, 540),
      ]);
      expect(orbs.map((OrbSpec o) => o.size), <double>[420, 360, 280]);
    });

    test(
      'the reading AR orbs use the cyan accent the EN arm does not have',
      () {
        expect(
          orbsFor(NeuralVariant.readingAr).map((OrbSpec o) => o.color),
          <Color>[
            _prototypeOrbColours['6C3FE8']!,
            _prototypeOrbColours['06B6D4']!,
          ],
        );
        expect(
          orbsFor(NeuralVariant.readingEn).map((OrbSpec o) => o.color),
          isNot(contains(_prototypeOrbColours['06B6D4'])),
        );
      },
    );

    test('the result group is the warm one — amber, rose, violet', () {
      expect(orbsFor(NeuralVariant.result).map((OrbSpec o) => o.color), <Color>[
        _prototypeOrbColours['F59E0B']!,
        _prototypeOrbColours['F43F5E']!,
        _prototypeOrbColours['6C3FE8']!,
      ]);
    });

    // THE SEVEN, BY NAME. Five of the seven colour sequences were asserted
    // (profile, settings, readingAr, readingEn's cyan-absence, result) and login,
    // home and quiz were not — so swapping login's first orb for the teal accent,
    // home's fourth for the rose accent or quiz's first for the indigo one left
    // the unit suite green and only the goldens noticed.
    //
    // `neural_background.dart`'s D2 doc claimed all seven; these three are what
    // makes that true, and the doc now says what is asserted rather than what is
    // hoped for.
    test('login is violet, indigo, magenta — in that order', () {
      // ds.tsx:71-73.
      expect(orbsFor(NeuralVariant.login).map((OrbSpec o) => o.color), <Color>[
        _prototypeOrbColours['6C3FE8']!,
        _prototypeOrbColours['3B5BDB']!,
        _prototypeOrbColours['C026D3']!,
      ]);
    });

    test('home is indigo, teal, violet, amber — the only four-orb group', () {
      // ds.tsx:77-80.
      expect(orbsFor(NeuralVariant.home).map((OrbSpec o) => o.color), <Color>[
        _prototypeOrbColours['3B5BDB']!,
        _prototypeOrbColours['14B8A6']!,
        _prototypeOrbColours['6C3FE8']!,
        _prototypeOrbColours['F59E0B']!,
      ]);
    });

    test('quiz is magenta, indigo, teal', () {
      // ds.tsx:94-96.
      expect(orbsFor(NeuralVariant.quiz).map((OrbSpec o) => o.color), <Color>[
        _prototypeOrbColours['C026D3']!,
        _prototypeOrbColours['3B5BDB']!,
        _prototypeOrbColours['14B8A6']!,
      ]);
    });

    test('and all seven sequences are named here, so none can be dropped', () {
      // The count, not the values: a sixth assertion added and a seventh deleted
      // would leave every other test in this file green. `length` on the map of
      // variant → group is the machine-checkable form of "all seven".
      const Map<NeuralVariant, List<String>> named =
          <NeuralVariant, List<String>>{
            NeuralVariant.login: <String>['6C3FE8', '3B5BDB', 'C026D3'],
            NeuralVariant.home: <String>[
              '3B5BDB',
              '14B8A6',
              '6C3FE8',
              'F59E0B',
            ],
            NeuralVariant.readingEn: <String>['3B5BDB', '14B8A6'],
            NeuralVariant.readingAr: <String>['6C3FE8', '06B6D4'],
            NeuralVariant.quiz: <String>['C026D3', '3B5BDB', '14B8A6'],
            NeuralVariant.result: <String>['F59E0B', 'F43F5E', '6C3FE8'],
            NeuralVariant.settings: <String>['6C3FE8', '06B6D4'],
          };
      expect(named, hasLength(NeuralVariant.values.length));
      for (final MapEntry<NeuralVariant, List<String>> entry in named.entries) {
        expect(
          orbsFor(entry.key).map((OrbSpec o) => _hexOf(o.color)),
          entry.value,
          reason: entry.key.name,
        );
      }
    });

    test('every orb size is the prototype\'s, and none is zero', () {
      for (final OrbGroup group in OrbGroup.values) {
        for (final OrbSpec orb in orbGroups[group]!) {
          expect(orb.size, greaterThan(0), reason: group.name);
          expect(orb.size, inInclusiveRange(200, 500));
        }
      }
    });

    // ─────────────────────────────────────────────────────────────────────
    // THE WHOLE TABLE, FIELD BY FIELD.
    //
    // `every declared parallax is the prototype's` above pins one field across
    // all twenty-one orbs. These six do the same for the fields that had **no**
    // exact assertion anywhere, which is why four single-field mutations
    // (`y: 640 → 460`, `hueSeconds: 11 → 13`, `hueDelaySeconds: -5 → -7`,
    // `floatPath: b → c`) and every within-range `size` swap left the unit suite
    // green and were caught only by the fourteen goldens. One table per field,
    // in group order, exactly like the parallax list.
    // ─────────────────────────────────────────────────────────────────────

    test('every declared x offset is the prototype\'s', () {
      const List<double> all = <double>[
        -100, 180, 60, // login
        -160, 200, -70, 250, // home
        -110, 160, // reading en
        40, -80, // reading ar
        110, -110, 180, // quiz
        -70, 150, -50, // result
        -110, 190, // profile
        70, -70, // settings
      ];
      expect(_allOrbs((OrbSpec o) => o.x), all);
    });

    test('every declared y offset is the prototype\'s', () {
      const List<double> all = <double>[
        -80, 260, 540, // login
        -120, 200, 520, 640, // home
        40, 380, // reading en
        -90, 360, // reading ar
        -130, 280, 580, // quiz
        -90, 240, 560, // result
        -80, 380, // profile
        -110, 440, // settings
      ];
      expect(_allOrbs((OrbSpec o) => o.y), all);
    });

    test('every declared size is the prototype\'s, not merely in range', () {
      // The range check above admits any value in 200…500, so a within-range
      // swap — home's 500 and 320 exchanging places, say — was invisible to it.
      const List<double> all = <double>[
        420, 360, 280, // login
        500, 320, 260, 200, // home
        380, 300, // reading en
        420, 300, // reading ar
        380, 320, 220, // quiz
        380, 300, 250, // result
        440, 280, // profile
        400, 260, // settings
      ];
      expect(_allOrbs((OrbSpec o) => o.size), all);
    });

    test('every declared float path is the prototype\'s, per group', () {
      // Previously asserted for `home` alone, so the other twenty orbs could be
      // on the wrong keyframe set — three *shapes* rather than three durations,
      // and the shape is what makes the orbs look like different orbs.
      const Map<OrbGroup, List<OrbFloatPath>> all =
          <OrbGroup, List<OrbFloatPath>>{
            OrbGroup.login: <OrbFloatPath>[
              OrbFloatPath.a,
              OrbFloatPath.b,
              OrbFloatPath.c,
            ],
            OrbGroup.home: <OrbFloatPath>[
              OrbFloatPath.a,
              OrbFloatPath.b,
              OrbFloatPath.c,
              OrbFloatPath.a,
            ],
            OrbGroup.readingEn: <OrbFloatPath>[OrbFloatPath.a, OrbFloatPath.b],
            OrbGroup.readingAr: <OrbFloatPath>[OrbFloatPath.b, OrbFloatPath.c],
            OrbGroup.quiz: <OrbFloatPath>[
              OrbFloatPath.a,
              OrbFloatPath.b,
              OrbFloatPath.c,
            ],
            OrbGroup.result: <OrbFloatPath>[
              OrbFloatPath.a,
              OrbFloatPath.b,
              OrbFloatPath.c,
            ],
            OrbGroup.profile: <OrbFloatPath>[OrbFloatPath.a, OrbFloatPath.b],
            OrbGroup.settings: <OrbFloatPath>[OrbFloatPath.b, OrbFloatPath.a],
          };
      for (final OrbGroup group in OrbGroup.values) {
        expect(
          orbGroups[group]!.map((OrbSpec o) => o.floatPath),
          all[group],
          reason: group.name,
        );
      }
    });

    test('every declared hueSeconds is the prototype\'s, per group', () {
      // The denominator of `hueDelayPhase`, so it is the field that decides
      // where in the wheel each orb starts. A range check existed for `home`
      // only; `11 → 13` on any orb was green.
      const Map<OrbGroup, List<double>> all = <OrbGroup, List<double>>{
        OrbGroup.login: <double>[8, 11, 9],
        OrbGroup.home: <double>[10, 7, 12, 9],
        OrbGroup.readingEn: <double>[14, 10],
        OrbGroup.readingAr: <double>[9, 13],
        OrbGroup.quiz: <double>[7, 10, 13],
        OrbGroup.result: <double>[8, 11, 9],
        OrbGroup.profile: <double>[11, 8],
        OrbGroup.settings: <double>[9, 12],
      };
      for (final OrbGroup group in OrbGroup.values) {
        expect(
          orbGroups[group]!.map((OrbSpec o) => o.hueSeconds),
          all[group],
          reason: group.name,
        );
      }
    });

    test('every declared hueDelaySeconds is the prototype\'s, per group', () {
      // CSS animation delays are negative here, which on an infinite positive
      // animation is a phase *advance*. `-5 → -7` moves every orb further round
      // the wheel and was green.
      const Map<OrbGroup, List<double>> all = <OrbGroup, List<double>>{
        OrbGroup.login: <double>[0, -3, -5],
        OrbGroup.home: <double>[0, -2, -4, -6],
        OrbGroup.readingEn: <double>[0, -4],
        OrbGroup.readingAr: <double>[0, -5],
        OrbGroup.quiz: <double>[0, -2, -5],
        OrbGroup.result: <double>[0, -3, -6],
        OrbGroup.profile: <double>[0, -4],
        OrbGroup.settings: <double>[0, -3],
      };
      for (final OrbGroup group in OrbGroup.values) {
        expect(
          orbGroups[group]!.map((OrbSpec o) => o.hueDelaySeconds),
          all[group],
          reason: group.name,
        );
      }
    });

    test(
      'every group opens with hueDelay 0, as every group does in the prototype',
      () {
        // The prototype's first orb in every one of the eight groups is the one
        // with no delay; the rest are the staggered ones. Cheap, and it is the one
        // invariant across the whole table that a single-field edit breaks loudly.
        for (final OrbGroup group in OrbGroup.values) {
          expect(
            orbGroups[group]!.first.hueDelaySeconds,
            0.0,
            reason: '${group.name} opens on the shared clock',
          );
        }
      },
    );

    test('the radial gradient centre is the prototype\'s 38% 38%', () {
      // ds.tsx:202 — `radial-gradient(circle at 38% 38%, color, transparent 68%)`.
      // CSS measures the centre from the top-left, and Flutter's `Alignment`
      // measures *both* axes from the top — `Alignment(-1, -1)` is `topLeft` — so
      // the conversion is fraction-from-the-top = `(v + 1) / 2` and `0.38` gives
      // `-0.24`. This comment used to say `y` was measured "from the bottom",
      // which contradicts the `-0.24` below it; the measured assertion under this
      // one is what makes the value, rather than the prose, the authority.
      expect(kOrbGradientCentre, 0.38);
      expect(kOrbGradientCenter, const Alignment(-0.24, -0.24));
    });

    test('and the measured offset really is 38% from the top-left', () {
      // The prose above, executed. `Alignment(-1, -1)` is `topLeft`, so a
      // negative `y` is *up*, and `withinRect` is the framework's own conversion.
      // A reader who trusts `Alignment`'s docs over ours gets this for free.
      const Rect box = Rect.fromLTWH(0, 0, 100, 100);
      expect(kOrbGradientCenter.withinRect(box), const Offset(38.0, 38.0));
      expect(
        kOrbGradientCenter.withinRect(box).dy / box.height,
        closeTo(kOrbGradientCentre, 1e-9),
        reason: 'fraction from the TOP, not the bottom',
      );
      expect(
        const Alignment(-1, -1).withinRect(box),
        box.topLeft,
        reason: 'the sign convention this arithmetic rests on',
      );
    });

    test('the outer stop is converted out of CSS\'s units, not copied', () {
      // A CSS radial-gradient stop is a fraction of the gradient RAY, which with
      // `farthest-corner` runs from the 38%/38% centre to the (100%,100%) corner:
      // `0.62 * sqrt(2) = 0.877` orb-widths. Flutter's radius is a fraction of the
      // SHORTEST SIDE. Copying `0.68` across stops the fade at 0.68 orb-widths,
      // past the ray, so the orb's corners stay tinted and it renders as a
      // hard-edged rectangle.
      expect(kOrbGradientStop, 0.68);
      expect(
        kOrbGradientRadius,
        closeTo(0.68 * 0.62 * 1.4142135623730951, 1e-12),
      );
      expect(
        kOrbGradientRadius,
        lessThan(0.68),
        reason: 'the converted radius is the one that matters',
      );
    });

    test('the fade finishes inside the orb box so no corner is tinted', () {
      // The farthest corner is 0.877 orb-widths from the gradient centre; the
      // stop must land before it, or the corners are never fully transparent.
      final double ray = (1 - kOrbGradientCentre) * 1.4142135623730951;
      expect(kOrbGradientRadius, lessThan(ray));
    });
  });
}
