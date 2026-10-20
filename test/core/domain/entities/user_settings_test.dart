// **The design system's own `CurtainShape` is HIDDEN**: see the note in
// `settings_cubit.dart`'s import block. The design system declares a
// `CurtainShape` for the **scrim** and the domain declares one for the **aurora
// curtain**, and a file that imports both gets an ambiguous-name error.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// `UserSettings` and `AppThemeMode` — the shared kernel's preferences record and
/// the three-value palette preference.
///
/// Red-first per `AGENT_CONTEXT` §6 ("domain logic"), and the properties that make
/// this file more than a field list are all about **what the null and the fallback
/// mean**, because those are the two places a preference is wrong in a way a reader
/// sees.
///
/// The record is no longer six fields: Task 5.5 added the two `/communion` ones and
/// Task 5.7 added twenty-three more, and the twenty-three are asserted here
/// against the **prototype's** literals.
void main() {
  group('AppThemeMode', () {
    test('is exactly the prototype\'s three options, in its order', () {
      // The superseded prototype's own three options —
      // `useState<'Light' | 'Dark' | 'System'>('Dark')` — and **the redesign has
      // no counterpart for them**: its theme group holds exactly one control, the
      // Daylight toggle (`redesign.html:650`). Asserted as a list
      // rather than a set because the ORDER is what `SegmentedControl` paints in, and a
      // set cannot tell a transposed pair from the right one.
      expect(AppThemeMode.values, <AppThemeMode>[
        AppThemeMode.light,
        AppThemeMode.dark,
        AppThemeMode.system,
      ]);
    });

    test('each member round-trips through its stored value', () {
      for (final AppThemeMode mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStored(mode.storedValue), mode);
      }
    });

    test('and the stored values are the ones `shared_preferences` holds', () {
      // Asserted against **literals**, not against `.name`. §4 forbids `describeEnum`
      // precisely because `.name` is a derived spelling that a rename would silently
      // change — and a stored preference written by an older build would then be
      // unreadable. The doc says "spelled out rather than derived from the member
      // name"; this is the test that holds it to that.
      expect(AppThemeMode.light.storedValue, 'light');
      expect(AppThemeMode.dark.storedValue, 'dark');
      expect(AppThemeMode.system.storedValue, 'system');
    });

    test('an unknown stored value is `null`, never a guess', () {
      // The preference-side twin of `ReadingLanguage.fromCode`'s null arm, and the
      // reason is the same: a wrong answer is worse than no answer, because the caller
      // can tell `null` from `dark` and choose.
      expect(AppThemeMode.fromStored('DARK'), isNull, reason: 'case-sensitive');
      expect(AppThemeMode.fromStored('solarized'), isNull);
      expect(AppThemeMode.fromStored(''), isNull);
      expect(AppThemeMode.fromStored(' light'), isNull);
    });

    test(
      'the stored values and the member names agree, which is a coincidence',
      () {
        // Asserted **because** it is a coincidence: `.name` happens to equal
        // `storedValue` for all three. If someone adds a member whose name differs from
        // its stored value — `system` vs `followSystem` — this is where it becomes a
        // deliberate decision rather than an accident.
        for (final AppThemeMode mode in AppThemeMode.values) {
          expect(mode.name, mode.storedValue);
        }
      },
    );
  });

  group('the default is the design system identity, and it is asserted', () {
    test('the default step is 3 and renders at 1.00x', () {
      expect(kDefaultFontStep, 3);
      expect(evaScalerFor(kDefaultFontStep).scale(1), 1.0);
      expect(
        kDefaultFontStep,
        isNot(kFontStepMin),
        reason:
            'a default at the bottom would open the app at 0.90x for everyone',
      );
      expect(kDefaultFontStep, isNot(kFontStepMax));
    });

    test('`UserSettings()` IS the default install', () {
      // WHY THIS ASSERTS FIELDS RATHER THAN COMPARING TWO CONSTRUCTORS. It
      // used to read `expect(const UserSettings(), const UserSettings(
      // themeMode: AppThemeMode.dark, fontStep: kDefaultFontStep,
      // reducedMotion: false))` — but the declared defaults ARE those
      // literals, so the two sides could never differ and the test could not
      // fail. `avoid_redundant_argument_values` named the redundancy; the
      // fix is to assert what the name promises. These are the four fields a
      // reader who has chosen nothing gets, and each one fails if its default
      // moves.
      const UserSettings settings = UserSettings();

      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.fontStep, kDefaultFontStep);
      expect(settings.language, isNull);
      expect(settings.reducedMotion, false);
    });
  });

  group('`UserSettings` is a freezed record, so equality is structural', () {
    test('two identical records are equal and are two objects', () {
      // `identical(…, isFalse)` first, because two identically-written constant
      // expressions are **canonicalised by Dart into one instance** and `expect(a, b)`
      // would then be `expect(identical(a, a), true)` — which passes against any `==`
      // including a broken one. `freezed_structural_equality_test.dart` makes the same
      // point for the whole converted set; this is the local restatement.
      // **Built through [step], not from a literal.** A literal would make both
      // constructions constant expressions, Dart canonicalises them into ONE instance,
      // `identical(a, b)` is `true`, and the whole case fails — or, worse, the guard
      // below would be a permanent red that somebody "fixes" by deleting it. This is
      // `freezed_structural_equality_test.dart`'s `_int`/`_text`/`_bool` trio for the
      // same reason, and one copy of the fixture is why it lives in the shared
      // `freezed_types.dart` support file rather than here.
      final UserSettings a = UserSettings(fontStep: step(4));
      final UserSettings b = UserSettings(fontStep: step(4));
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('and `copyWith()` with no argument is identity', () {
      final UserSettings base = UserSettings(fontStep: step(4));
      expect(base.copyWith(), base);
    });
  });

  group('`language` is nullable and `null` MEANS "FOLLOW THE PLATFORM"', () {
    // ## THE THIRD ANSWER, AND WHY A NON-NULLABLE FIELD WOULD BE A REGRESSION
    //
    // `MaterialApp.locale` is `null` for "follow the platform". If `language` were a
    // `ReadingLanguage` defaulting to `english`, then a fresh install on an Arabic
    // device would open **English** — a regression against eight phases of
    // `app.dart`, whose `locale` was `null` and therefore did follow the platform.
    //
    // So the table is a claim about the field's three states, and it is asserted rather
    // than described.
    const UserSettings unchosen = UserSettings();
    const UserSettings chosenEnglish = UserSettings(
      language: ReadingLanguage.english,
    );
    const UserSettings chosenArabic = UserSettings(
      language: ReadingLanguage.arabic,
    );

    test('unchosen is `null`, and differs from a chosen English', () {
      expect(unchosen.language, isNull);
      expect(
        unchosen,
        isNot(chosenEnglish),
        reason:
            'the two must be distinguishable, or "never chose" and "chose English" are '
            'the same stored value and a reader cannot go back to following the device',
      );
    });

    test(
      'and a stored language survives a copy that touches another field',
      () {
        final UserSettings picked = unchosen.copyWith(
          language: ReadingLanguage.arabic,
        );
        expect(picked.language, ReadingLanguage.arabic);
        expect(
          picked.copyWith(fontStep: 5).language,
          ReadingLanguage.arabic,
          reason: 'the generated `copyWith` carries the nullable field, unlike the hand-written one',
        );
      },
    );

    test(
      'and a chosen language is CLEARABLE back to "follow the platform"',
      () {
        // **The half a hand-written `copyWith` could not express.** `QuizSession`'s
        // `copyWith` hazard is recorded on `ReadingState`: `x ?? this.x` means `null` can
        // never clear a field, so once a reader has chosen a language there would be no
        // way back. freezed's sentinel default makes this reachable, and this is the
        // assertion that it stays reachable.
        expect(chosenArabic.copyWith(language: null), unchosen);
        expect(chosenArabic.copyWith(language: null).language, isNull);
      },
    );
  });

  group('`reducedMotion` is ADDITIONAL, never a replacement', () {
    // The rule is on the field's doc: a reader who has asked the **OS** for reduced
    // motion gets it whatever this says, because `app.dart` combines the two signals.
    test('so it defaults to `false` — the app does not start still', () {
      expect(const UserSettings().reducedMotion, isFalse);
    });

    test('and it is an ordinary independent field', () {
      final UserSettings still = const UserSettings().copyWith(
        reducedMotion: true,
      );
      expect(still.reducedMotion, isTrue);
      expect(still.themeMode, const UserSettings().themeMode);
      expect(still.fontStep, const UserSettings().fontStep);
    });
  });

  group('the TWENTY-THREE new fields default to the PROTOTYPE\'S literals', () {
    // ## WHY THESE ARE ASSERTED AND NOT INHERITED
    //
    // `UserSettings()` is the app's "a reader who has chosen nothing" record, and
    // its defaults are the **prototype's** literals — `eva/redesign.html` is the
    // design source of truth, and a default that was invented would be a design
    // decision made by a data file. Every one below is therefore a claim about a
    // specific line of the prototype, and a claim about a number has to be
    // checkable.
    //
    // ## AND THE COUNT IS ASSERTED, because it is a CLAIM ABOUT THE TASK
    //
    // The task's brief counts twenty-three new fields, and the research report's
    // "twenty-five" is stale (Task 5.5 had already landed `veilWitnesses` and
    // `showPodium`). A twenty-fourth field added here is a change the task did not
    // make, and this assertion is where it shows.
    test('the shader group, and its ten', () {
      const UserSettings settings = UserSettings();
      expect(settings.shaderEnabled, isTrue, reason: 'eva/redesign.html:652');
      expect(
        settings.curtainShape,
        CurtainShape.top,
        reason: 'eva/redesign.html:654-655 — data-s="0"',
      );
      expect(settings.reach, 42, reason: 'eva/redesign.html:658 — value="42"');
      expect(settings.glow, 100, reason: 'eva/redesign.html:659 — value="100"');
      expect(
        settings.touchGlow,
        55,
        reason: 'eva/redesign.html:660 — value="55"',
      );
      expect(settings.hue, 312, reason: 'eva/redesign.html:661 — value="312"');
      expect(
        settings.multichromeMelt,
        isFalse,
        reason: 'eva/redesign.html:662',
      );
      expect(settings.rayCombing, isTrue, reason: 'eva/redesign.html:663');
      expect(settings.whiteCores, isTrue, reason: 'eva/redesign.html:664');
      expect(settings.dotVeil, isFalse, reason: 'eva/redesign.html:665');
    });

    test('the sky group, and its seven', () {
      const UserSettings settings = UserSettings();
      expect(settings.starsOn, isTrue, reason: 'eva/redesign.html:667');
      expect(
        settings.constellationsOn,
        isTrue,
        reason: 'eva/redesign.html:668',
      );
      expect(
        settings.starCount,
        44,
        reason: 'eva/redesign.html:669 — value="44"',
      );
      expect(
        settings.starBrightness,
        100,
        reason: 'eva/redesign.html:670 — value="100"',
      );
      expect(
        settings.starShape,
        SkyStarShape.dot,
        reason: 'eva/redesign.html:672-673 — data-v="s-dot"',
      );
      expect(
        settings.starField,
        SkyStarField.crown,
        reason: 'eva/redesign.html:677-678 — data-v="crown"',
      );
      expect(settings.twinkle, isTrue, reason: 'eva/redesign.html:681');
    });

    test('the ritual group, and its six', () {
      const UserSettings settings = UserSettings();
      expect(
        settings.focusDelaySec,
        4,
        reason: 'eva/redesign.html:683 — value="4"',
      );
      expect(
        settings.selahLengthSec,
        60,
        reason: 'eva/redesign.html:684 — value="60"',
      );
      expect(settings.breathGuide, isTrue, reason: 'eva/redesign.html:685');
      expect(settings.vespersAutoDim, isTrue, reason: 'eva/redesign.html:686');
      expect(settings.calmMotion, isFalse, reason: 'eva/redesign.html:688');
      expect(settings.haptics, isTrue, reason: 'eva/redesign.html:689');
    });

    test('and there are exactly twenty-three of them', () {
      // The task's own count, asserted so a twenty-fourth field is a visible
      // change rather than a silent one. The two `/communion` fields are **not**
      // counted here: they were Task 5.5's, and the research report's "twenty-five"
      // counted them as new — which is why the number is twenty-three.
      const UserSettings settings = UserSettings();
      final List<Object> newFields = <Object>[
        settings.shaderEnabled,
        settings.curtainShape,
        settings.reach,
        settings.glow,
        settings.touchGlow,
        settings.hue,
        settings.multichromeMelt,
        settings.rayCombing,
        settings.whiteCores,
        settings.dotVeil,
        settings.starsOn,
        settings.constellationsOn,
        settings.starCount,
        settings.starBrightness,
        settings.starShape,
        settings.starField,
        settings.twinkle,
        settings.focusDelaySec,
        settings.selahLengthSec,
        settings.breathGuide,
        settings.vespersAutoDim,
        settings.calmMotion,
        settings.haptics,
      ];
      expect(newFields, hasLength(23));
    });

    test('and the HUE default is 312, NOT the prototype\'s boot state', () {
      // The prototype's slider attribute says `312` (`:661`) and its boot state
      // says `autoH=258` (`:882`). The **declared control default** is 312 — it is
      // what the control shows a reader and what the reset returns to — and the
      // divergence is recorded at the field rather than resolved silently.
      expect(const UserSettings().hue, 312);
      expect(const UserSettings().hue, isNot(258));
    });

    test('and the STAR COUNT default is the sky\'s own cap', () {
      // The prototype's cap is `starCap=44` (`eva/redesign.html:1131`) and the
      // slider's default is `value="44"` (`:669`). The client's cap constant lives
      // in `features/sky/domain/sky_star_cap.dart` — a different feature, and
      // `features/sky/domain/` may not be imported from here without breaking Gate
      // 2 — so the number is asserted here against the prototype's literal.
      expect(const UserSettings().starCount, 44);
    });
  });
}

/// An [int] reached through a call, so a record built from it is not a constant
/// expression and cannot be canonicalised against another.
///
/// The same trick `freezed_structural_equality_test.dart` uses for its
/// `_int`/`_text`/`_bool` trio, and the same reason: `prefer_const_constructors` pushes
/// a test towards `const`, and `const` is exactly what makes `expect(a, b)` vacuous.
int step(int value) => value;
