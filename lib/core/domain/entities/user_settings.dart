import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
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

/// Everything the reader has chosen about how this app looks and behaves.
///
/// ## WHY IT IS IN `core/domain/` AND NOT IN `features/settings/`
///
/// Three consumers, which is §3's placement test. `app` installs three of these four
/// fields app-wide (`app.dart`: theme mode, language, font step), `/settings` writes
/// all four, and `/reading` **reads and writes** [fontStep] for its `Aa` control. A
/// copy inside `features/settings/` would make `app` and `reading` import `settings`,
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
}
