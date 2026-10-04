import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:flutter/material.dart';

/// The sticky call to action, and the caption under it.
///
/// `ReadingEnScreen.tsx:79-91` and `ReadingArScreen.tsx:77-89`.
///
/// ## **THIS IS NOT A `GlassSurface`**, AND §13'S BLUR BUDGET IS UNTOUCHED
///
/// `04-widget-inventory.md:54` says so in its own words: "`StickyCta`
/// (`ReadingEnScreen.tsx:80-86`) and the Quiz feedback banner … look similar but use
/// a solid `linear-gradient` / flat `rgba(ok, 0.1)` fill with **no
/// `backdropFilter`**. They are separate composites, not `GlassSurface` instances."
///
/// A `BackdropFilter` is a `saveLayer` plus a full read-back of everything behind it,
/// per frame. The prototype's block is an opaque gradient for its bottom 40% and
/// transparent above it — there is nothing to read back — so wrapping it in
/// `GlassSurface` would spend §13 rule 4's budget on a surface the design explicitly
/// does not blur. `glass_blur_budget_test.dart`'s ceiling for `lib/features/` is
/// **1** (Home's panel) and this file is not a second: it paints no
/// `BackdropFilter`, and the budget gate counts them.
///
/// ## AND THE GRADIENT IS **`NeuralScaffold`'s**, NOT ONE OF THIS FILE'S
///
/// The prototype puts `linear-gradient(to bottom, transparent, rgba('#05081A', 0.95)
/// 40%)` on this block — dark — and `rgba('#F0EEFF', 0.96)` in light. Those are
/// `canvas` at 95% and 96%.
///
/// **This file draws no gradient at all.** `NeuralScaffold`'s `bottomFade` already
/// paints exactly that, in `colors.canvas` rather than a hard-coded hex, from a
/// token, and it is the only place in the tree allowed to know the viewport's
/// height (the scrim's extent is the content's `130px` reserve plus the CTA's own
/// height, so it cannot be a constant — see `kNeuralScaffoldFadeHeight`). Drawing it
/// here as well would be two scrims, and §13's rule 4 counts surfaces.
///
/// **And the 95%/96% difference is a **divergence**, deliberately.** The scaffold uses
/// `canvas.withValues(alpha: 0.95)` for both palettes; the prototype's light value is
/// `0.96`. `NeuralScaffold`'s own doc cites `:83` — the **dark** line — and not `:84`,
/// so 0.95 is the value this client transcribes and the light one is one point off.
/// Recorded rather than corrected, because `NeuralScaffold` is Phase 2's widget and
/// the alternative is a second gradient here.
///
/// ## AND THE PAGE PUTS THIS **ABOVE** THE SCAFFOLD, WHICH IS WHY THE FADE IS THE
/// ## SCAFFOLD'S
///
/// `NeuralScaffold`'s `child` sits **below** its `bottomFade` in the same `Stack`,
/// so a CTA placed inside the child would be painted over by a scrim that is solid
/// `canvas` at 95% from 40% of its own height down — and the prototype puts the CTA
/// at `zIndex: 2` **above** the content at `:1`. `ReadingPage` therefore returns a
/// `Stack` of its own with the scaffold `Positioned.fill` and this block `Positioned`
/// last. That is also why no parameter was added to `NeuralScaffold`: its
/// constructor's exact parameter set is pinned by `neural_scaffold_test.dart`, and a
/// screen that needs one arrangement is not a reason to widen the screen root's
/// interface for all six screens.
class StickyCta extends StatelessWidget {
  /// The CTA for [language], captioned for [questionCount] questions.
  const StickyCta({
    required this.language,
    required this.strings,
    required this.questionCount,
    required this.onPressed,
    super.key,
  });

  /// Which arm of the corpus this is — it selects the CTA's label family and the
  /// caption's tracking.
  final ReadingLanguage language;

  /// The bilingual strings.
  final ReadingStrings strings;

  /// `ScriptureText.questionCount`, which feeds [ReadingStrings.captionFor].
  ///
  /// **A count and not a caption string**, so the pluralisation lives in the string
  /// table — one implementation, one place — rather than at each call site.
  final int questionCount;

  /// What the CTA runs.
  final VoidCallback onPressed;

  /// The block's padding. `padding: '20px 24px 32px'` on both arms —
  /// `ReadingEnScreen.tsx:81`, `ReadingArScreen.tsx:79`.
  ///
  /// **Bottom 32 and not `EvaSpacing`'s `xxxl`=32 by accident** — they are the same
  /// number, which is worth saying because `nn`'s 40 is the prototype's *own* root
  /// `paddingBottom` and `xxxl` is its 32.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    EvaSpacing.xxl,
    EvaSpacing.xl,
    EvaSpacing.xxl,
    EvaSpacing.xxxl,
  );

  /// The caption's size. `fontSize: 9` on both arms.
  static const double captionFontSize = 9;

  /// The caption's weight. `fontWeight: 700` on both arms.
  static const FontWeight captionWeight = FontWeight.w700;

  /// The gap above the caption. `marginTop: 8` on both arms.
  static const double captionGap = EvaSpacing.sm;

  /// The caption's family. `ReadingEnScreen.tsx:88` — `F.mono`;
  /// `ReadingArScreen.tsx:86` — `F.mono` **over Arabic text and Arabic-Indic digits**.
  ///
  /// **The second of defect #2's two named sites.** Space Mono carries neither Arabic
  /// letters nor U+0660–U+0669, and the caption has both — `٥ أسئلة` is entirely
  /// Arabic script. `Amiri` it is.
  static String captionFamilyFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => EvaTypography.monoFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      };

  /// The caption's tracking. `ReadingEnScreen.tsx:88` — `letterSpacing: '0.12em'`;
  /// `ReadingArScreen.tsx:86` — `'0.10em'`.
  ///
  /// CSS `em` tracking is resolved against the caption's own `9px`, so the two are
  /// `1.08` and `0.9` logical px. The English value is **not** `0.12`: the prototype's
  /// unit is the em, and `ReadingHeader.metadataLetterSpacingFor` says why a
  /// hand-copied `0.12` would be a silent transcription error.
  static double captionLetterSpacingFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => 0.12 * captionFontSize,
        ReadingLanguage.arabic => 0.10 * captionFontSize,
      };

  /// The CTA label's family. `ds.tsx:237` — `fontFamily: F.ui`, i.e. **DM Sans**,
  /// on every `ButtonPrimary` in the prototype.
  ///
  /// **A FOURTH SITE OF DEFECT #2, in a shared component rather than a screen.**
  /// `01-source-analysis.md`'s table names two sites and neither is this one;
  /// `ابدأ التأمل` through DM Sans is tofu for the same reason the scripture is.
  /// `EvaButton.labelFamily`'s doc carries the argument, and the value comes from
  /// here so `reading_glyph_test.dart` can read it off the rendered `Text`.
  static String ctaFamilyFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => EvaTypography.uiFamily,
    ReadingLanguage.arabic => EvaTypography.arabicFamily,
  };

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EvaButton(
            label: strings.beginReflection,
            onPressed: onPressed,
            labelFamily: ctaFamilyFor(language),
          ),
          const SizedBox(height: captionGap),
          Text(
            strings.captionFor(questionCount),
            textAlign: TextAlign.center,
            style: EvaTypography.monoCaps(colors).copyWith(
              fontFamily: captionFamilyFor(language),
              fontSize: captionFontSize,
              fontWeight: captionWeight,
              letterSpacing: captionLetterSpacingFor(language),
              // `T.ink3` on both arms — `ReadingEnScreen.tsx:88`,
              // `ReadingArScreen.tsx:86`.
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
