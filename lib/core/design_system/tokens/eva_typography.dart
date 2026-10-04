import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// The Eva type system — five families mapped onto Material's `TextTheme`, plus
/// the scripture styles Material has no slot for and the Settings font-size
/// scaler.
///
/// `docs/plans/03-design-system.md` §5.2:
///
/// | Role | Family | Source |
/// | --- | --- | --- |
/// | `display` | Cormorant Garamond 400/500/600/700 + italics | `F.display` |
/// | `scripture` | EB Garamond 400/500 + italic | `F.scripture` |
/// | `arabic` | Amiri 400/700 + italic | `F.arabic` |
/// | `ui` | DM Sans 300–800 + italics | `F.ui` |
/// | `mono` | Space Mono 400/700 + italic | `F.mono` |
///
/// ## NO `google_fonts`
///
/// §5.2 says "Wire via `google_fonts` … with fonts bundled at build time so
/// first paint is not blocked on a network fetch." The second half is the
/// requirement and it is already met: the twenty `.ttf` files under
/// `assets/fonts/` are declared in `pubspec.yaml` as five asset families, so a
/// `TextStyle(fontFamily: …)` resolves them offline. Adding `google_fonts` on top
/// would reintroduce the HTTP fetch `09-quality-gates.md` §11 names as the cause
/// of flaky goldens, and this phase may not add dependencies. So the families
/// are named directly and the `google_fonts` sentence is treated as superseded by
/// the bundling that followed it.
///
/// ## WHICH SLOTS GET WHICH FAMILY
///
/// §5.2 gives five *roles*, not fifteen slot assignments. The mapping used here
/// is the only reading consistent with the roles' names and with Material's
/// scale, and it is recorded here so it can be reviewed:
///
/// - `display{Large,Medium,Small}` and `headline{Large,Medium,Small}` → the
///   display serif. These are the slots the prototype's `F.display` occupied:
///   page titles, section headers, the greeting.
/// - `title*`, `body*` and `label*` → the UI sans, the slots `F.ui` occupied.
/// - `mono`, `scripture` and `arabic` have no slot at all — see [monoCaps],
///   [scriptureLatin] and [scriptureArabic].
///
/// ## SIZES ARE NOT INVENTED HERE
///
/// §5.2 specifies no font size, weight or line height. So the geometry comes
/// unchanged from the SDK's own Material 3 type scale
/// (`Typography.material2021().englishLike` — the same source `ThemeData` reads
/// when it localises a theme), and this file's job is exactly the decision §5.2
/// *does* make: which family renders each slot, and in which ink. A token table
/// that also restated the sizes would be a second copy of the framework's scale,
/// free to drift from it.
///
/// [englishLike] specifically, not `.white`/`.black`: those carry colour only
/// (`ThemeData.localize` layers the geometry over them at runtime), so reading a
/// size off them yields `null` — which is how this file's first draft produced a
/// `TextStyle` with no size at all.
///
/// The platform is left at `Typography.material2021()`'s own default rather than
/// `defaultTargetPlatform`. That is deliberate: the per-platform variants differ
/// only in their `fontFamilyFallback` lists, which this file replaces wholesale,
/// and pinning it keeps a golden captured on one host byte-identical on another.
abstract final class EvaTypography {
  // --- Families ------------------------------------------------------------
  //
  // Spelled exactly as the `family:` keys in `pubspec.yaml`. The engine matches
  // `TextStyle.fontFamily` against that string exactly, and a name that merely
  // looks right resolves to the fallback font with no error at all.

  /// `Cormorant Garamond` — the display serif. `pubspec.yaml` family
  /// `CormorantGaramond`.
  static const String displayFamily = 'CormorantGaramond';

  /// `EB Garamond` — latin scripture. `pubspec.yaml` family `EBGaramond`.
  static const String scriptureFamily = 'EBGaramond';

  /// `Amiri` — arabic scripture. `pubspec.yaml` family `Amiri`.
  static const String arabicFamily = 'Amiri';

  /// `DM Sans` — UI text. `pubspec.yaml` family `DMSans`, without the space.
  static const String uiFamily = 'DMSans';

  /// `Space Mono` — mono-caps labels. `pubspec.yaml` family `SpaceMono`.
  static const String monoFamily = 'SpaceMono';

  /// The shared, colour-free geometry source for everything below.
  ///
  /// Hoisted so the `TextTheme` and the three slot-less styles cannot disagree
  /// about the platform scale.
  static final TextTheme _geometry = Typography.material2021().englishLike;

  // --- The TextTheme -------------------------------------------------------

  /// The Eva [TextTheme] for [colors].
  ///
  /// A function rather than a constant because the ink comes from the palette: a
  /// single `TextTheme` would have to hard-code one brightness's colours, and the
  /// other theme would then render near-black ink on a near-white canvas only by
  /// accident of Material's defaults.
  ///
  /// `apply(displayColor:, bodyColor:)` is Material's own classification of which
  /// slots are "display" (display, headline, title) and which are "body" (body,
  /// label), so the ink lands in the right places without a hand-written table.
  static TextTheme textTheme(EvaColors colors) {
    final TextTheme base = _geometry.apply(
      displayColor: colors.ink,
      bodyColor: colors.ink,
    );

    TextStyle? serif(TextStyle? style) =>
        style?.copyWith(fontFamily: displayFamily);
    TextStyle? ui(TextStyle? style) => style?.copyWith(fontFamily: uiFamily);

    return base.copyWith(
      // Display and headline take the serif.
      displayLarge: serif(base.displayLarge),
      displayMedium: serif(base.displayMedium),
      displaySmall: serif(base.displaySmall),
      headlineLarge: serif(base.headlineLarge),
      headlineMedium: serif(base.headlineMedium),
      headlineSmall: serif(base.headlineSmall),
      // Everything else takes the UI sans.
      titleLarge: ui(base.titleLarge),
      titleMedium: ui(base.titleMedium),
      titleSmall: ui(base.titleSmall),
      bodyLarge: ui(base.bodyLarge),
      bodyMedium: ui(base.bodyMedium),
      bodySmall: ui(base.bodySmall),
      labelLarge: ui(base.labelLarge),
      labelMedium: ui(base.labelMedium),
      labelSmall: ui(base.labelSmall),
    );
  }

  // --- Styles with no Material slot ---------------------------------------

  /// Latin scripture for [colors] — the NKJV text in the reading sanctuary.
  ///
  /// §5.2: "scripture has no Material slot", so this style cannot live in the
  /// `TextTheme`; a widget reads it and layers it under whatever `Text` it is
  /// building. The geometry is `bodyLarge`'s — long-form reading is body copy —
  /// and the family is the one thing that differs. Derived rather than declared,
  /// because §5.2 fixes no size and a literal here would be an invented token.
  static TextStyle scriptureLatin(EvaColors colors) =>
      textTheme(colors).bodyLarge!.copyWith(fontFamily: scriptureFamily);

  /// Arabic scripture for [colors] — the Smith & Van Dyck Arabic.
  ///
  /// Deliberately identical geometry to [scriptureLatin]. A bilingual reader
  /// alternates between the two arms of every verse; a size difference would
  /// change the line height of the paragraph on each switch, which is a visible
  /// jump rather than a rendering detail.
  static TextStyle scriptureArabic(EvaColors colors) =>
      textTheme(colors).bodyLarge!.copyWith(fontFamily: arabicFamily);

  /// Mono-caps labels for [colors] — the theme toggle, the route chips, the FAB
  /// dock items.
  ///
  /// `labelMedium`'s geometry with the mono family. §5.2 gives `mono` neither a
  /// slot nor a size, and deliberately no letter-spacing: inventing a tracking
  /// value would be inventing a token, and the bundled Space Mono is already a
  /// wide face.
  static TextStyle monoCaps(EvaColors colors) =>
      textTheme(colors).labelMedium!.copyWith(fontFamily: monoFamily);
}

/// The family that renders a run of text whose script follows [direction], given
/// the family [latin] that renders it otherwise.
///
/// Identity under [TextDirection.ltr], and **exactly** identity: no size, weight,
/// tracking or ink is touched, because the only thing wrong with a Latin face on the
/// Arabic arm is that it carries no Arabic glyph.
///
/// ## WHY THE DIRECTION AND NOT THE LOCALE
///
/// Phase 6 established that direction comes from the **locale through
/// `MaterialApp`**, and recorded decision 61 that there is **no `Directionality`
/// anywhere under `lib/`** and no `startsWith('ar')` guess on a language field.
/// This function keeps that: it takes the direction the engine already resolved, so
/// a caller passes `Directionality.of(context)` and nothing else, and there is no
/// second locale→script decision in the app to disagree with the first.
///
/// **RTL implies Arabic here because the app ships two locales.** `app.dart`
/// declares `supportedLocales: [Locale('en'), Locale('ar')]`, and of those only
/// `ar` resolves to RTL — so today the two questions have the same answer. A third,
/// non-Arabic RTL locale (Hebrew, for instance) would make it false, and the failure
/// would be loud rather than silent: `test/support/arabic_typography_gate.dart`
/// asserts every rendered Arabic run is in Amiri **and** that Amiri carries every
/// character on screen, so a Hebrew run in Amiri fails the second assertion on the
/// first frame it is painted. That is the shape of answer worth having — a gate that
/// reports the wrong family, rather than a font swap that looks fine.
///
/// ## AND WHY IT IS NOT A `TextTheme`
///
/// The obvious alternative is a `TextTheme` whose Arabic slots resolve to Amiri,
/// applied under the Arabic arm. **It is not available.** `MaterialApp` takes one
/// `theme:` and one `darkTheme:` and has **no per-locale theme hook**, so there is
/// nowhere to put a second text theme that the engine would choose between. Recorded
/// because "why not just localise the theme" is the first question a reader asks of
/// this rule and the answer is a framework fact rather than a preference.
String arabicAwareFamily(TextDirection direction, String latin) =>
    direction == TextDirection.rtl ? EvaTypography.arabicFamily : latin;

/// [style] with its family resolved for [direction].
///
/// The same rule as [arabicAwareFamily] for the two design-system parameters that
/// are a family **name** rather than a style, which is why those two functions exist
/// rather than one: `EvaButton.labelFamily` and `IconActionButton.tooltipFamily` are
/// `String`, and forcing them to `String` callers would mean a `TextStyle` built and
/// immediately unwrapped at four call sites.
///
/// ## WHY A HELPER RATHER THAN A PARAMETER ON EVERY RUN SITE
///
/// The alternative is threading a per-arm family into every widget that renders a
/// caller-supplied string — `TextLink`, `SocialAuthButton`, `HairlineDivider`,
/// `EvaTextField`, `ErrorView`, `FontSizeStepper` — which is a required constructor
/// argument on six design-system widgets plus every feature widget that builds a
/// `TextStyle`, and a new argument at every one of their call sites. Recorded
/// decision 73's reviewer already called the parameter version "a screen rewrite
/// wearing a parameter's clothes"; this is the same rewrite with a constructor on
/// each end of it.
///
/// The parameter version also has a second cost that the helper does not: the caller
/// has to *know* the arm. For a run whose text is the app's own strings the ambient
/// direction is the whole of what the caller knows — `TextLink(label:
/// strings.createAccount)` has no payload to read an arm from, which is why
/// `TextLink` never grew a family parameter while `EvaButton` did (`EvaButton`'s
/// callers *do* have `TodayReading.language` in hand, and that is what
/// `TodayReadingPanel.continueFamilyFor` reads).
///
/// ## WHAT THIS DOES NOT REPLACE
///
/// The per-arm **`*FamilyFor` switches stay**, and so do `EvaButton.labelFamily`
/// and `IconActionButton.tooltipFamily`. Those are keyed on the **payload's** arm —
/// `TodayReading.language`, `ReadingLanguage` — which is a different fact from the
/// ambient locale and survives the two disagreeing. This rule is for runs that render
/// the app's own chrome, where the ambient direction is the only arm there is.
///
/// ## AND IT CANNOT FAIL SILENTLY
///
/// A helper that took a `Locale` and compared `languageCode == 'ar'` would resolve to
/// nothing for a third language and hand back the Latin face — no error, tofu on
/// screen. This one takes the direction the engine already decided, so there is no
/// string to be wrong about and no default to fall through; and its output is read
/// back off the rendered tree by `test/support/arabic_typography_gate.dart`, which is
/// what turns "the call site called it" into "the engine received it".
TextStyle arabicAware(TextStyle style, TextDirection direction) =>
    direction == TextDirection.rtl
    ? style.copyWith(fontFamily: EvaTypography.arabicFamily)
    : style;

/// The [TextScaler] for font-size step [step], from the Settings slider.///
/// `docs/plans/03-design-system.md` §5.2 gives the table verbatim, and the shape
/// with it: 1 → 0.90, 2 → 0.95, 3 → 1.00, 4 → 1.10, and everything else → 1.22.
/// The executable form is the one immediately below.
///
/// ## THE TABLE IS NOT QUOTED IN PROSE, AND THAT IS DELIBERATE
///
/// An earlier version of this comment reproduced the switch as a fenced `dart`
/// block, and `eva_typography_test.dart` pinned the two copies against each other
/// with a regular expression. That was a mistake, and a mutation audit showed
/// which kind: it caught a divergence nobody could ship — someone typing
/// `0.90` as `0.9` — and false-failed two changes that are perfectly legitimate,
/// namely reformatting the quoted snippet and dropping `const` from it. Worse, the
/// character class was `[1-5_]`, so a sixth arm would have been invisible to it
/// anyway.
///
/// Pinning prose with a regex creates the incentive AGENT_CONTEXT §6 warns about:
/// the cheapest way to make the test green becomes editing the test's expectations
/// rather than the behaviour, and a doc comment nobody can change freely is a doc
/// comment nobody keeps current. The code three lines below IS the table, so it is
/// quoted here as prose — which cannot drift silently, because prose is not
/// executable — and the behavioural assertions in `eva_typography_test.dart` check
/// the function.
///
/// Step 3 is the identity, so the default install renders at the platform's own
/// size. The `_` arm covers both step 5 and any out-of-range value, which is why
/// a corrupted preference reads as "largest" rather than silently resetting the
/// reader's chosen size.
///
/// `09-quality-gates.md` §14 requires the app to survive 1.22× without overflow at
/// 320px width; 1.22 is the top of that requirement, not a round number chosen
/// after it.
///
/// NOT APPLIED BY THE THEME, AND NOT INSTALLED ANYWHERE YET.
///
/// An earlier version of this comment said "`MaterialApp.builder` installs this
/// scaler in Phase 5, once the setting is readable". Phase 5 is complete and the
/// scaler is **not** installed, so that sentence is removed rather than left to rot.
///
/// The reason is ordering, not oversight: the `step` argument comes from
/// `settings_repository`, which does not exist until Phase 9. `MaterialApp.builder`
/// receives an `AsyncSnapshot` and rebuilds when the future resolves, so the
/// installation is a one-liner whenever that repository lands — but installing it
/// now with a hard-coded `3` would ship a preference the reader cannot change and
/// cannot change back, which is worse than not shipping it.
///
/// Neither placement is acceptable for the same reason, so the two options that
/// were ruled out stay ruled out: baking it into `ThemeData` would make the
/// preference untestable, and wrapping the platform's scaler in a way that ignores
/// it would silently override a user who has raised the OS font size.
///
/// ## WHAT §14 IS ACTUALLY SATISFIED BY, THEN
///
/// The requirement is that the app survives 1.22× at 320px width. That is now tested
/// against the **platform** scaler in `login_text_scale_test.dart` — which is the
/// stronger form, because it proves the layouts survive the *maximum of the two
/// inputs* rather than one of them. So the §14 gate does not wait on Phase 9; only
/// the reader-facing stepper does. The distinction matters: the layout work is done
/// and verified, and the remaining Phase 9 work is the control, not the constraint.
///
/// The function stays exported, and `eva_typography_test.dart` checks all five arms
/// so it cannot rot in the meantime.
TextScaler evaScalerFor(int step) => switch (step) {
  1 => const TextScaler.linear(0.90),
  2 => const TextScaler.linear(0.95),
  3 => const TextScaler.linear(1.00),
  4 => const TextScaler.linear(1.10),
  _ => const TextScaler.linear(1.22),
};
