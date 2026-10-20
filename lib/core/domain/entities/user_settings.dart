import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';

/// The step a reader who has never touched the `Aa` control gets.
///
/// ## WHY IT IS HERE AND NOT IN `font_size_stepper.dart`
///
/// `kFontStepMin` and `kFontStepMax` live beside the widget that draws the track,
/// because a widget that knows its own range is the thing that can be wrong about it.
/// This **default** is a different kind of number: it is a *product* decision — "the
/// app opens at the reader's own size" — and it is the one number here that a pure
/// Dart file has to be able to state without reaching for Flutter.
///
/// So the boundary is split by who owns each question: `kFontStepMin`/`kFontStepMax`
/// are the **design system's** range and stay in `core/design_system`; the default
/// is **this entity's** and lives here, where `UserSettings` can use it as a
/// `@Default`.
///
/// ## 3, AND ASSERTED RATHER THAN ASSUMED
///
/// `03-design-system.md` §5.2 maps `3 → 1.00`, so the default is the identity: a
/// fresh install renders at 100% and the `Aa` control moves away from that in both
/// directions. A default of `1` would mean the whole app — every screen, not only
/// `/reading` — opens at `0.90×` for everybody.
///
/// The value was `ReadingCubit.defaultFontStep` and moving it here is what lets
/// `ReadingCubit` stop owning it: `reading_cubit.dart`'s doc records that the step was
/// cubit state only "for the life of the cubit", and this is the phase that gives it
/// somewhere durable to live.
const int kDefaultFontStep = 3;

/// The fewest stars the witness sky may hold. `eva/redesign.html:669` —
/// `<input type="range" id="setStarCount" min="0" max="60" value="44">`.
///
/// ## WHY **THIS** RANGE LIVES IN THE SHARED KERNEL AND NOT IN A FEATURE
///
/// The other seven Workshop ranges are used by **one** feature — `settings` —
/// and §3's placement test puts those in `features/settings/domain/`. **This
/// one is used by two**: the settings feature clamps the value on the way in
/// and out, and the **sky** feature clamps the same number where it becomes a
/// cap (the two writers that enforce the cap may not import each other — one is
/// data and one is presentation, and the dependency direction is strictly
/// inward).
///
/// A feature may not import another feature (Gate 2) and `core/domain/` may
/// not name a feature, so the only home both may reach is **here** — and the
/// field the range belongs to is here too. **Two spellings of `0` and `60` in
/// two features is the "two implementations of one number" drift this
/// repository rejects wherever it finds it.**
const int kStarCountMin = 0;

/// The most stars the witness sky may hold. `eva/redesign.html:669` — the same
/// input's `max="60"`.
const int kStarCountMax = 60;

/// Clamps [count] into `kStarCountMin…kStarCountMax`.
///
/// `eva/redesign.html:669` is the prototype's own `min`/`max`.
///
/// **The one clamp for this range, and the sky feature uses THIS one.** The
/// sky's two writers each hold a cap reader and must clamp whatever they are
/// told before it becomes a cap; a second clamp for the same range would be
/// two functions that could disagree about where the range ends.
int clampStarCount(int count) => count.clamp(kStarCountMin, kStarCountMax);

/// Everything the reader has chosen about how this app looks and behaves.
///
/// ## WHY IT IS IN `core/domain/` AND NOT IN `features/settings/`
///
/// Three consumers, which is §3's placement test. `app` installs three of these
/// fields app-wide (`app.dart`: theme mode, language, font step), `/settings` writes
/// all of them, and `/reading` **reads and writes** [fontStep] for its `Aa` control.
/// `/communion` reads [veilWitnesses] and [showPodium] from the same record, which is
/// why those two live here rather than in a board-local cubit: the veil button and the
/// future settings controls must write the one value both surfaces read.
///
/// A copy inside `features/settings/` would make `app` and `reading` import `settings`,
/// which §3 forbids with no exceptions and `tool/verify_purity.sh` Gate 2 fails on the
/// line.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// `ThemeMode`, no `Locale` and no `TextScaler`. Each of those is converted at the one
/// edge where it exists, and each conversion is a named function rather than an
/// `if`:
///
/// | field | converted at |
/// | --- | --- |
/// | [themeMode] | `lib/app/app.dart`, an exhaustive `switch` onto `ThemeMode` |
/// | [language] | `lib/app/app.dart` and each screen's `ReadingLanguage.forLocale` |
/// | [fontStep] | `evaScalerFor(step)` at `MaterialApp.builder` |
///
/// ## EQUALITY IS GENERATED, AND THE GENERATED [copyWith] IS THE WRITER
///
/// `freezed` (AGENT_CONTEXT §2.1 decision 8a) gives `==` from the constructor and a
/// `copyWith` that can clear every nullable field. That is the only writer here and
/// it is reached exclusively through `SettingsCubit`, which clamps and validates
/// before it persists — so the generated `copyWith` is never a raw gate onto stored
/// state.
///
/// ## AND [language] IS NULLABLE, WHICH MEANS "**NO CHOICE MADE**"
///
/// This is the one field whose null is not "absent" but a **third** answer, and the
/// distinction matters because it is the difference between following the reader's
/// device and forcing English on it.
///
/// `MaterialApp.locale` is `null` for "follow the platform" and a `Locale` to pin the
/// app. If [language] were `ReadingLanguage` with `english` as its default, then a
/// fresh install on an Arabic device would open **English** — a regression against
/// eight phases of `app.dart`, whose `locale` is `null` today and therefore does
/// follow the platform. So [language] is `null` until the reader chooses, and the
/// choice is persisted.
///
/// `reading_language.dart` gives the precedent for the nullable direction being the
/// *wire* one; here it is the *preference* one, and `SettingsPage` resolves the
/// unchosen case with `ReadingLanguage.forLocale` for the control's own selected
/// value. That keeps "what is on screen" and "what is stored" two different facts,
/// which is the only way a reader on an Arabic device sees Arabic selected before
/// they have touched anything.
///
/// ## THE **NON-REDIRECTING** CONSTRUCTOR FORM, AND WHY IT IS NOT A TASTE CALL
///
/// Written first as `const factory UserSettings({...}) = _UserSettings;` with the
/// fields declared below it, which is freezed's other documented shape. It does not
/// generate here, and the failure is worth recording because it is silent in the
/// worst way: `dart run build_runner build` **succeeds**, and the emitted
/// `user_settings.freezed.dart` has a `mixin _$UserSettings` with **no getters** and a
/// `_UserSettings` with **no fields**. `dart analyze` then reports four
/// `final_not_initialized` errors and two on the generated file — so it is caught, but
/// by the analyzer and not by the build, and the first thing one sees is six errors
/// pointing at generated code.
///
/// Every other `@freezed` class in this repository is the non-redirecting form with
/// its fields declared and documented in place (`ReadingState`, `QuizAnswer`,
/// `AuthState`), so this file matches them and the field doc comments below stay where
/// a reader looks for them.
@freezed
final class UserSettings with _$UserSettings {
  /// A reader who has chosen nothing.
  const UserSettings({
    this.themeMode = AppThemeMode.dark,
    this.fontStep = kDefaultFontStep,
    this.language,
    this.reducedMotion = false,
    this.veilWitnesses = false,
    this.showPodium = true,
    this.shaderEnabled = true,
    this.curtainShape = CurtainShape.top,
    this.reach = 42,
    this.glow = 100,
    this.touchGlow = 55,
    this.hue = 312,
    this.multichromeMelt = false,
    this.rayCombing = true,
    this.whiteCores = true,
    this.dotVeil = false,
    this.starsOn = true,
    this.constellationsOn = true,
    this.starCount = 44,
    this.starBrightness = 100,
    this.starShape = SkyStarShape.dot,
    this.starField = SkyStarField.crown,
    this.twinkle = true,
    this.focusDelaySec = 4,
    this.selahLengthSec = 60,
    this.breathGuide = true,
    this.vespersAutoDim = true,
    this.calmMotion = false,
    this.haptics = true,
  });

  /// Which palette the app renders in.
  final AppThemeMode themeMode;

  /// The reader's font size, `1`…`5`, as a step in `03-design-system.md` §5.2's
  /// table rather than as a factor.
  ///
  /// ## A **STEP** AND NOT A SCALE FACTOR, AND WHY THAT IS THE SAME ARGUMENT AS
  /// ## [ReadingLanguage]'s ENUM
  ///
  /// The number stored is the number the **stepper** shows, so the knob and the
  /// rendered size cannot disagree — `font_size_stepper.dart`'s `clampFontStep` says
  /// exactly that about a value read out of storage: "a corrupt or hand-edited value
  /// must not be able to reach `evaScalerFor` as something outside the table — where
  /// its `_` arm sends it to 1.22× while the stepper shows a knob at a position no
  /// step owns".
  ///
  /// The factor itself is **derived** at the app root by `evaScalerFor`, which is the
  /// design system's table and is not restated here. Storing `1.10` would be a second
  /// copy of that table in a pure-Dart file with no way to check it against the other.
  ///
  /// **Not clamped here.** This file is pure Dart and `clampFontStep` is a widget-layer
  /// function in `core/design_system`; a stored value is clamped once, by
  /// `SettingsCubit`, on the way in and on the way out — see its doc for why the
  /// boundary there and not here.
  final int fontStep;

  /// The language the app renders in, or `null` for "follow the platform".
  ///
  /// See the class doc's section on why this is nullable.
  final ReadingLanguage? language;

  /// Whether this app's own animations are held still.
  ///
  /// ## IT IS **NOT** `MediaQuery.disableAnimationsOf`, AND IT DOES NOT REPLACE IT
  ///
  /// §14's requirement is that every animation checks the **platform's**
  /// reduce-motion signal, and `NeuralMotionScope` reads it from
  /// `WidgetsBinding.instance.platformDispatcher` today because it sits above
  /// `MaterialApp` where no `MediaQuery` exists. This field is an **additional**
  /// reader-controlled off switch, combined with that signal and never instead of it:
  /// `app.dart` passes `animationsEnabled: !settings.reducedMotion && <platform>`,
  /// so a reader who has asked the OS for reduced motion gets it whatever this says,
  /// and a reader who has not can still ask for it from inside the app.
  ///
  /// **Rejected: replacing the platform signal.** It would make this app's one
  /// in-app control a *master* switch a reader cannot escape — turning it off would
  /// also ignore the OS setting they had deliberately raised, which is the
  /// accessibility failure `reading_text_scale.dart` spent a hundred lines arguing
  /// against from the other direction.
  final bool reducedMotion;

  /// Whether `/communion` veils every witness who is not the reader.
  ///
  /// ## IT IS A RENDERING CHOICE OVER ROWS THAT ALREADY ARRIVED
  ///
  /// The board's names are on the wire (`leaderboard.routes.ts` sends `full_name`), and
  /// ADR-0022 `:243-245` records that the prototype's veil (`eva/redesign.html:1070`)
  /// therefore needs **no endpoint** — the rows are the same rows either way. Turning
  /// this on replaces each non-reader's name with `{witness} {position}` and their
  /// monogram with a painted hollow star (`:1072`); the reader keeps their own name and
  /// monogram, because a reader hiding from themselves is not a privacy control.
  ///
  /// **Default `false`**, because the prototype's `veilOn` starts false
  /// (`:1065`) and the header button is opt-in. The accessible name follows the
  /// rendered one — a voice-over reader must not hear a name the screen is forbidden to
  /// show.
  ///
  /// **Added by Task 5.5 for the board to read; the `/settings` control is 5.7's.**
  final bool veilWitnesses;

  /// Whether `/communion` draws the top-three podium.
  ///
  /// The prototype's `showPodium` is `true` at start (`eva/redesign.html:1065`), and
  /// `:1084` hides the `.podium` element when it is off. **The list is still
  /// `slice(3)`** (`:1110`), so positions one to three are absent from the list whether
  /// or not the podium is visible — a prototype oddity recorded and followed rather
  /// than repaired.
  ///
  /// **Added by Task 5.5 for the board to read; the `/settings` control is 5.7's.**
  final bool showPodium;

  // ---------------------------------------------------------------------------
  // Task 5.7 — the Workshop's twenty-three new fields.
  //
  // ## WHY THEY ARE HERE AND NOT IN `features/settings/`
  //
  // The seven sky fields are read by `/reading` (`WitnessSky`) and the seven
  // ritual and ten shader fields are written by `/settings` — and the sky ones
  // are **two-consumer** types under §3's placement test: the settings screen
  // writes them and the reading screen reads them. A copy inside
  // `features/settings/` would make `features/reading` import `features/settings`,
  // which Gate 2 fails on the line.
  //
  // ## EVERY DEFAULT IS THE **PROTOTYPE'S LITERAL**, CITED
  //
  // `eva/redesign.html:638-700` is the design source of truth, and every
  // default below is the value the prototype's own markup carries. A default
  // that was invented would be a design decision made by a data file, and a
  // reader who reset their settings would get it.
  //
  // ## AND EVERY ONE OF THEM IS **NOT CLAMPED HERE**
  //
  // This file is pure Dart and the clamps live in `SettingsCubit`, which is
  // the app's only boundary — the same reason [fontStep] is not clamped here
  // and the same argument `font_size_stepper.dart` makes.
  // ---------------------------------------------------------------------------

  /// Whether the aurora shader is on. `eva/redesign.html:652` — the Aurora
  /// engine switch, `checked`.
  ///
  /// **The shader is mounted.** Task 5.8 put `LumenCanvas` in the screen
  /// root, and this switch is the reader's half of it: the prototype's
  /// `cvs.style.display='none'` (`eva/redesign.html:1468`), which is the
  /// canvas hidden and the ambient's fallback in its place.
  ///
  /// The other nine `eva.shader.*` preferences are read by the same mount —
  /// see `LumenPreferences.fromSettings`, which is the projection of these
  /// ten fields onto the shader's uniforms.
  final bool shaderEnabled;

  /// The shape the aurora curtain takes. `eva/redesign.html:654-655` — the
  /// Curtain shape segment, `data-s="0"`.
  final CurtainShape curtainShape;

  /// How far the aurora band reaches. `eva/redesign.html:658` — `value="42"`,
  /// and the range is 18-110.
  final int reach;

  /// The aurora's brightness. `eva/redesign.html:659` — `value="100"`, and the
  /// range is 40-130.
  ///
  /// **Not a uniform.** The prototype folds it into the ambient target
  /// (`eva/redesign.html:891`) and never sends it to the GPU;
  /// `lumen_uniforms.dart`'s `brightnessFromGlow` says so in those words.
  final int glow;

  /// How brightly the aurora answers a touch. `eva/redesign.html:660` —
  /// `value="55"`, and the range is 0-100.
  final int touchGlow;

  /// The aurora's hue, in degrees. `eva/redesign.html:661` — `value="312"`,
  /// and the range is 0-360.
  ///
  /// ## THE DEFAULT IS **312** AND NOT THE PROTOTYPE'S BOOT STATE
  ///
  /// The prototype's slider attribute says `312` (`eva/redesign.html:661`) and
  /// its boot state says `autoH=258` (`eva/redesign.html:882`). **The declared
  /// control default is 312** — it is what the control shows a reader, and the
  /// value the reset returns to — and the divergence from the boot state is
  /// recorded here rather than resolved silently.
  ///
  /// The prototype's *reset* does not restore 312 either: it restores the
  /// **current book's** hue (`eva/redesign.html:1523`). This client has no
  /// per-book hue, so the declared literal is the honest substitute, and the
  /// substitution is recorded at the reset as well as here.
  final int hue;

  /// Whether the aurora's colours drift apart over time.
  /// `eva/redesign.html:662` — the Multichrome melt switch, unchecked.
  final bool multichromeMelt;

  /// Whether the aurora's bands are combed into rays. `eva/redesign.html:663`
  /// — the Ray combing switch, `checked`.
  final bool rayCombing;

  /// Whether the aurora's cores are white. `eva/redesign.html:664` — the
  /// White cores switch, `checked`.
  final bool whiteCores;

  /// Whether a veil of dots lies over the aurora. `eva/redesign.html:665` —
  /// the Dot veil switch, unchecked.
  final bool dotVeil;

  /// Whether the witness sky is drawn at all. `eva/redesign.html:667` — the
  /// Stars switch, `checked`.
  ///
  /// **This hides the sky; it does not delete it.** The prototype's Stars-off
  /// calls `clearStars()` (`eva/redesign.html:1483`), but the prototype has no
  /// persistence — its stars are DOM elements — while this client's sky is a
  /// reader's own record of what they have read. The divergence is recorded
  /// at the control.
  final bool starsOn;

  /// Whether the constellation is drawn. `eva/redesign.html:668` — the
  /// Constellations switch, `checked`.
  final bool constellationsOn;

  /// How many stars the witness sky holds. `eva/redesign.html:669` —
  /// `value="44"`, and the range is 0-60.
  ///
  /// The prototype's cap is `starCap=44` (`eva/redesign.html:1131`) and this
  /// field is the client's version of it. `sky_star_cap.dart` holds the
  /// default; the wiring that feeds the cap is Task 5.7's.
  final int starCount;

  /// How bright the stars are. `eva/redesign.html:670` — `value="100"`, and
  /// the range is 30-150.
  ///
  /// The prototype writes `--starB = v/100` (`eva/redesign.html:1488`) and
  /// `WitnessSky.brightness` takes 0.3-1.5, so the conversion is `/100`.
  final int starBrightness;

  /// The silhouette every star is drawn in. `eva/redesign.html:672-673` —
  /// the Star shape segment, `data-v="s-dot"`.
  final SkyStarShape starShape;

  /// The vertical band the stars sit in. `eva/redesign.html:677-678` — the
  /// Star field segment, `data-v="crown"`.
  final SkyStarField starField;

  /// Whether the stars twinkle. `eva/redesign.html:681` — the Twinkle switch,
  /// `checked`.
  ///
  /// **Combined with the platform's and the reader's reduce-motion signal,
  /// never instead of it** — the same rule the prototype's handler applies
  /// (`eva/redesign.html:1489` sets `notwinkle` when the switch is off **or**
  /// reduce motion is on).
  final bool twinkle;

  /// How long the reader must be idle before the screen dims.
  /// `eva/redesign.html:683` — `value="4"`, and the range is 2-15. The unit
  /// is seconds.
  final int focusDelaySec;

  /// How long the selah lasts. `eva/redesign.html:684` — `value="60"`, and the
  /// range is 15-120 **in steps of 5** — the prototype's only stepped slider.
  /// The unit is seconds.
  final int selahLengthSec;

  /// Whether the reading screen draws a breath guide. `eva/redesign.html:685`
  /// — the Breath guide switch, `checked`.
  final bool breathGuide;

  /// Whether the screen dims by itself between 21:00 and 05:00.
  /// `eva/redesign.html:686` — the Vespers auto-dim switch, `checked`.
  final bool vespersAutoDim;

  /// Whether the animations collapse to their end states.
  /// `eva/redesign.html:688` — the Calm motion switch, unchecked.
  final bool calmMotion;

  /// Whether the app answers with a haptic. `eva/redesign.html:689` — the
  /// Haptics switch, `checked`.
  ///
  /// **Persisted AND answered — and the second half arrived in Phase 7, which
  /// is why this doc used to say "not yet answered".**
  ///
  /// The client had no haptics until the Lumen redesign's Phase 7, so the
  /// Workshop was mute against the prototype, which answers every toggle with
  /// a haptic (`eva/redesign.html:1482`, `:1498`). The vocabulary is
  /// `core/domain/entities/ritual_haptic.dart`'s and the platform call is
  /// `core/design_system/effects/ritual_haptics.dart`'s — the only file that
  /// calls `HapticFeedback`, because `core/domain/` is Flutter-free.
  ///
  /// **And the switch is answered by the switch itself**, which is the one
  /// moment a reader most wants to know it worked: the tap that turns haptics
  /// **on** fires `RitualHaptic.hapticsEnabled` with `enabled: on` — the
  /// *new* value, not the old one. A client that read the stored value would
  /// stay silent on that very tap, because the stored value is `false`, and
  /// the reader would be left not knowing whether the switch did anything.
  final bool haptics;
}
