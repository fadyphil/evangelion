import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:flutter/material.dart';

/// The reading screen's top row, and the panel the `Aa` control discloses.
///
/// ## THE ROW'S TWO PER-ARM NUMBERS
///
/// | | EN | AR | |
/// | --- | --- | --- | --- |
/// | padding | `20px 20px 0` | `16px 20px 0` | [paddingFor] |
/// | horizontal | 20 | 20 | [paddingFor] |
/// | `Aa` ↔ bookmark gap | 16 | 16 | [gap] |
///
/// `ReadingEnScreen.tsx:13` and `ReadingArScreen.tsx:19`. **Both are transcribed and
/// neither is shared**, which is the `home_geometry_test.dart` lesson applied before
/// the mistake rather than after it.
///
/// ## DIRECTION COMES FROM THE **LOCALE**, AND THE PROXY'S CHILD ORDER IS **NOT**
/// ## REPRODUCED — A RECORDED DIVERGENCE
///
/// There is no `startsWith('ar')` anywhere in `lib/` and no `Directionality` this
/// file installs: `MaterialApp` derives the direction from the locale, which is
/// Phase 6's established mechanism.
///
/// **What the prototype does, and why this client does not do it.**
/// `ReadingArScreen.tsx:19-29` writes its children as `[group, back]` **under**
/// `direction: 'rtl'`. That places the back button on the **left** — the same side
/// as the English arm, whose children are `[back, group]` under LTR — while
/// `:27` mirrors the chevron to point **right**. So the prototype's Arabic row is a
/// **right-pointing back arrow on the left side of the screen**.
///
/// One child order here plus the ambient direction gives a **true mirror**: back on
/// the right, chevron pointing right, `Aa` and bookmark on the left. That is what the
/// prototype's own comment on `:18` says it wanted (`Top controls — RTL mirrored`),
/// the child order defeats it, and it is also the arrangement Android's and iOS's
/// own back affordances agree with.
///
/// **Rejected: transcribing the inconsistency literally.** It would need an
/// `if (language == arabic)` that reorders children, which is a second source of
/// truth for a fact the direction already decides — and the defect it fixes is the
/// same class as recorded decision 29's (a Latin layout assumption in the Arabic
/// arm). `reading_page_test.dart` asserts the **rendered positions**, so a future
/// reordering is red.
///
/// **The chevron mirrors itself**, for free: `Icons.arrow_back` is declared
/// `matchTextDirection: true` in the SDK, so the ambient RTL flips it and no second
/// icon has to be chosen.
class ReadingControls extends StatelessWidget {
  /// The top row, plus [panel]'s contents when [panelOpen].
  const ReadingControls({
    required this.language,
    required this.strings,
    required this.onBack,
    required this.panelOpen,
    required this.onPanelToggled,
    required this.fontStep,
    required this.onFontStepChanged,
    super.key,
  });

  /// Which arm of the corpus this is — it selects [paddingFor] and nothing else.
  ///
  /// **A parameter and not a locale read**, because the page has already resolved
  /// the language it loaded and this widget has no other use for one. Reading
  /// `Localizations` again here would be a second read of a fact the caller is
  /// holding, and `NeuralScaffold`'s D2 note is explicit that the language is not to
  /// be re-derived from anything but the thing that already knows it.
  final ReadingLanguage language;

  /// The bilingual strings — every control's accessible name comes from here.
  final ReadingStrings strings;

  /// What the back control runs.
  final VoidCallback onBack;

  /// Whether the text-size panel is showing.
  final bool panelOpen;

  /// Opens or closes the panel. Wired to the `Aa` control only: a disclosure is not
  /// a modal, so tapping the scripture does **not** dismiss it, and nothing else on
  /// the screen closes it.
  final VoidCallback onPanelToggled;

  /// The reader's font step, for the panel's stepper.
  final int fontStep;

  /// Reports a new step. Goes to `ReadingCubit.setFontStep`, which clamps it.
  final ValueChanged<int> onFontStepChanged;

  /// The row's padding. `ReadingEnScreen.tsx:13` — `'20px 20px 0'`;
  /// `ReadingArScreen.tsx:19` — `'16px 20px 0'`.
  ///
  /// **Per arm and not one number**, because the top padding differs (20 against 16)
  /// while the horizontal happens to agree. `reading_geometry_test.dart` pins both.
  static EdgeInsets paddingFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => const EdgeInsets.only(
      top: EvaSpacing.xl,
      left: EvaSpacing.xl,
      right: EvaSpacing.xl,
    ),
    ReadingLanguage.arabic => const EdgeInsets.only(
      top: EvaSpacing.lg,
      left: EvaSpacing.xl,
      right: EvaSpacing.xl,
    ),
  };

  /// The gap between the `Aa` control and the bookmark. `ReadingEnScreen.tsx:17` and
  /// `ReadingArScreen.tsx:20` both write `gap: 16`.
  static const double gap = EvaSpacing.lg;

  /// The family the three controls' **tooltips** render in, for [language].
  ///
  /// ## DEFECT #2's FOURTH, FIFTH AND SIXTH ARABIC SITES — AND THEY HAVE NO
  /// ## PROTOTYPE LINE AT ALL
  ///
  /// `ReadingEnScreen.tsx:14-16` and `ReadingArScreen.tsx:21-29` draw four bare
  /// `<button>`s with an inline `<svg>` and **no label**, so §14's requirement for an
  /// accessible name forced three Arabic strings into this widget that the
  /// prototype never wrote. They are the strings a reader sees when they hold a
  /// control, and they render through `IconActionButton`'s `Tooltip`.
  ///
  /// `Tooltip(message: tooltip)` carried **no `textStyle`**, so Flutter resolved
  /// `null` to `ThemeData.textTheme.bodyMedium` — measured **DMSans** on both
  /// themes, which has no Arabic glyphs at all. Measured on the shipped
  /// `ReadingPage` at `Locale('ar')` with the long press held open: four tofu boxes,
  /// seven, and nineteen codepoints.
  ///
  /// **The Arabic arm of the whole screen was Amiri except these three**, which is
  /// why the prototype's nine sites were the floor rather than the ceiling.
  /// `reading_glyph_test.dart` now paints each tooltip before it enumerates, and
  /// its site table, which is **nine** rows and **eight** tofu sites.
  ///
  /// **`uiFamily` on the English arm and not `null`**, for the same reason
  /// `IconActionButton.tooltipFamily` is required: `uiFamily` **is**
  /// `bodyMedium`'s family, so this is the same rendering stated rather than
  /// inherited, and the English arm cannot drift into a sixth family by accident.
  static String tooltipFamilyFor(ReadingLanguage language) =>
      switch (language) {
        ReadingLanguage.english => EvaTypography.uiFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      };

  @override
  Widget build(BuildContext context) {
    // One read for three call sites, so the three cannot disagree.
    final String tooltipFamily = tooltipFamilyFor(language);

    return Padding(
      padding: paddingFor(language),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconActionButton(
                icon: Icons.arrow_back,
                tooltip: strings.back,
                // See [tooltipFamilyFor] — defect #2's fourth Arabic site.
                tooltipFamily: tooltipFamily,
                onPressed: onBack,
              ),
              Row(
                children: <Widget>[
                  // §14's first row lists `Aa` among the icon-only buttons with no
                  // accessible name, and `IconActionButton`'s own doc names it as
                  // one of "the `Aa` and bookmark controls Phase 7 composes". So it
                  // is **that widget** with a `Text size` tooltip rather than a text
                  // button labelled `Aa` — a name that is the glyph is not a name.
                  IconActionButton(
                    icon: Icons.format_size,
                    tooltip: strings.textSize,
                    // Defect #2's fifth Arabic site.
                    tooltipFamily: tooltipFamily,
                    onPressed: onPanelToggled,
                  ),
                  const SizedBox(width: gap),
                  // **RENDERED AND INERT, with the reason in its name.** Phase 6's
                  // precedent for the avatar, for the same reason: `ReadingEnScreen
                  // .tsx:19-21` draws a bookmark `<button>` with no handler and the
                  // backend has **no** endpoint and **no** port for one, so there
                  // is nothing to call. `onPressed: null` means `IconActionButton`
                  // publishes `Semantics(enabled: false)` and no tap action — the
                  // control is not announced as an enabled button — and the name
                  // carries why.
                  IconActionButton(
                    icon: Icons.bookmark_border,
                    tooltip:
                        '${strings.bookmark} — ${strings.unavailableSuffix}',
                    // Defect #2's sixth Arabic site, and the longest string on the
                    // screen: 19 codepoints including an em dash.
                    tooltipFamily: tooltipFamily,
                    onPressed: null,
                  ),
                ],
              ),
            ],
          ),
          // The disclosure. **A `Column` under the row and nothing else** — no
          // sheet, no scrim, no tap-outside. The prototype defines no target UI for
          // `Aa` at all (`ReadingEnScreen.tsx:18` is a bare `<button>Aa</button>`
          // with no sheet, no menu and nothing), so the only honest options were the
          // smallest control that exists or an invented menu. An inline disclosure is
          // the smallest of those.
          if (panelOpen) ...<Widget>[
            const SizedBox(height: EvaSpacing.lg),
            const HairlineDivider(),
            const SizedBox(height: EvaSpacing.md),
            // §14: the stepper's own track is a slider node with increase/decrease
            // actions and its two buttons are real tab stops, so the reader can both
            // drag and press, and both are named by `FontSizeStepper` itself.
            //
            // **The labels come from [strings], not from the design system.** They
            // were `'Decrease font size'` / `'Increase font size'` / `'Font size'`
            // hard-coded in `FontSizeStepper`, so this panel told an Arabic reader in
            // English what its two buttons did.
            FontSizeStepper(
              step: fontStep,
              onChanged: onFontStepChanged,
              labels: FontSizeStepperLabels(
                decrease: strings.decreaseFontSize,
                increase: strings.increaseFontSize,
                track: strings.fontSize,
              ),
            ),
            const SizedBox(height: EvaSpacing.lg),
          ],
        ],
      ),
    );
  }
}
