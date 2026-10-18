import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/card_washes.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Where the reader's light last was — a pointer, not a preview.
///
/// `redesign.html:524-528`. One `GlassSurface`, the eyebrow, and the hint line.
///
/// ## THE CARD HAS NO VERSE TEXT, AND THAT IS THE ADAPTATION
///
/// The prototype's card shows a 64-character excerpt of the last verse the reader
/// scrolled past (`redesign.html:1203`, `t.slice(0,64)+'…'`), because `BOOKS`
/// (`:1004-1031`) holds the whole demo Bible. `ADR-0022` maps this card to
/// `GET /streak`'s `history[0]` — a row with a reference, a book name and four
/// counters — and there is **no endpoint that returns the passage of a row**:
/// `GET /readings/:id` does not exist (AGENT_CONTEXT §2) and `GET /streak` carries
/// no verse body.
///
/// So the card draws the pointer and the resume hint, and the `.tv small` line is
/// drawn **only in the empty arm**. The alternative — a fabricated sentence, or a
/// second request the redesign never asked for — is the two things ADR-0022's
/// fiction table exists to prevent.
///
/// ## AND WHY IT IS `bloom` WITHOUT A SEAM
///
/// `.hcard` (`:249`) gives every card a `.hor`, and only `#votdCard` (`:520`) has
/// one in its markup: this card's children are a `.bloom`, the eyebrow, the text and
/// the hint (`:525-528`). `GlassSurface.seam: false` is the parameter that says so,
/// and `glass_surface.dart`'s doc gives why it is a parameter and not a fifth tier.
///
/// ## THE EMPTY ARM IS THE PROTOTYPE'S, WORD FOR WORD
///
/// `redesign.html:1192-1197`: no `lastRead` → `lastRef` becomes `—`, the body reads
/// `noLight`, the hint's `display` is `none` and the cursor goes to `default` — so
/// the card is not a button and the hint is gone. An em-dash is the prototype's
/// character and not a substituted one; `AppLocalizations.homeNoLightRef` carries it
/// so the string is translatable like every other.
class LastLightCard extends StatelessWidget {
  /// The pointer card, for [entry] or for the empty arm.
  const LastLightCard({
    required this.entry,
    required this.failureMessage,
    required this.retryLabel,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  /// The most recent scheduled day, or `null` while loading, after a failure, or
  /// because the cohort has no scheduled reading on file.
  ///
  /// **Three different `null`s and one value**, which is the card's whole state
  /// machine. [failureMessage] separates the first two and this field cannot: the
  /// bloc's `lastLightStatus` is what says which, and the widget is given the
  /// message rather than the enum so that it cannot draw a state the bloc has not
  /// reached.
  final StreakHistoryEntry? entry;

  /// Why it could not be read, or `null`.
  final String? failureMessage;

  /// The retry's label.
  final String retryLabel;

  /// What to run when the reader asks to try again.
  final VoidCallback? onRetry;

  /// What to run when the reader resumes from where the light left them.
  ///
  /// Null when there is nothing to resume from, for `:1197`'s `cursor: default`.
  final VoidCallback? onOpen;

  /// The card's corner rounding. `redesign.html:249` — 24, as on the card above.
  static const double radius = EvaRadii.heroPanel;

  /// The card's padding. `redesign.html:250` — `22px 20px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.xl,
    vertical: 22,
  );

  /// The wash. `redesign.html:524` — `--bh: rgba(232,176,75,.35)`, gold at `.35`.
  ///
  /// The same hue [EvaColors.ember] publishes for `--gold`, at this card's own
  /// alpha. `0x59` is `.35 × 255` rounded (`.35 → 89.25 → 89`). The value lives
  /// in `card_washes.dart`, beside the day's card's, and this constant is the
  /// name the widget reads it by.
  static const int washArgb = homeLastLightWashArgb;

  /// The gap above the hint. `redesign.html:528` — `margin-top: 8px`, inline on
  /// the hint itself rather than as a margin on the line above.
  static const double hintGap = 8;

  /// The empty arm's body size. `redesign.html:260` — `.tv.small{font-size:17px}`.
  static const double emptySize = 17;

  /// The empty arm's body size on the Arabic arm. `redesign.html:259` overrides
  /// `.hcard .tv` — which `.tv.small` inherits — to 20px and 1.9.
  static const double emptySizeArabic = 20;

  /// The empty arm's line height under LTR. `redesign.html:258` — 1.6.
  static const double emptyHeight = 1.6;

  /// The empty arm's line height on the Arabic arm. `redesign.html:259` — 1.9.
  static const double emptyHeightArabic = 1.9;

  /// The reference this arm shows, in the app's own numerals' locale.
  ///
  /// **The payload's own strings, chosen by the ambient arm** —
  /// `redesign.html:1202` makes exactly this pick in JS (`lang === 'ar' ?
  /// \`${b.arName} …\` : …`). `StreakHistoryEntry` carries both because
  /// `GET /streak` has no `?lang=`, and the reference's two forms differ in more
  /// than letters: `streak.service.ts:120-124` puts a space after the chapter's
  /// colon in Arabic (`٢٣: ١-٦`) and none in English (`23:1-6`).
  static String referenceFor(
    StreakHistoryEntry entry,
    TextDirection direction,
  ) => direction == TextDirection.rtl ? entry.referenceAr : entry.referenceEn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final StreakHistoryEntry? last = entry;
    final String? failure = failureMessage;

    return GlassSurface(
      // `bloom`, not `blur`: §13.4's one backdrop filter is spent on the day's own
      // card, and `glass_blur_budget_test.dart` fails at two.
      tier: GlassTier.bloom,
      radius: radius,
      padding: padding,
      bloomColor: homeCardWash(washArgb),
      seam: false,
      onTap: last == null ? null : onOpen,
      // The empty arm is not a button, so it is not announced as one — and a
      // failure is not a button either.
      //
      // **`''` and not the eyebrow's words**, for `VerseOfTheDayCard`'s reason and
      // the measurement beside it: `:525-528` is an eyebrow, a reference and the
      // hint, and a named surface would repeat the eyebrow inside its own merged
      // label.
      semanticLabel: last == null ? null : '',
      child: switch ((failure, last)) {
        (final String message, _) => ErrorView(
          message: message,
          retryLabel: retryLabel,
          retryFamily: strings.retryLabelFamily,
          onRetry: onRetry,
        ),
        (null, null) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _eyebrow(
              context,
              colors,
              monoCapsText(strings.homeLastLight, direction),
              monoCapsText(strings.homeNoLightRef, direction),
            ),
            const SizedBox(height: verseOfTheDayGap),
            Text(
              strings.homeNoLight,
              style: arabicAware(
                EvaTypography.scriptureLatin(colors).copyWith(
                  fontSize: direction == TextDirection.rtl
                      ? emptySizeArabic
                      : emptySize,
                  height: direction == TextDirection.rtl
                      ? emptyHeightArabic
                      : emptyHeight,
                  // `.tv.small{color: var(--ink-1)}` — `:260`, which is `ink2`.
                  color: colors.ink2,
                ),
                direction,
              ),
            ),
          ],
        ),
        (null, final StreakHistoryEntry value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _eyebrow(
              context,
              colors,
              monoCapsText(strings.homeLastLight, direction),
              monoCapsText(referenceFor(value, direction), direction),
            ),
            const SizedBox(height: hintGap),
            Text(
              monoCapsText(strings.homeResumeHint, direction),
              style: arabicAware(
                EvaTypography.monoCaps(colors).copyWith(
                  letterSpacing: direction == TextDirection.rtl ? 0 : 0.16,
                  // `redesign.html:528` overrides `.mono`'s `--ink-2` with an
                  // inline `color: var(--ink-1)` — which is `ink2` here, so this is
                  // the same value `.mono` would have given and is written out
                  // because the prototype wrote it out.
                  color: colors.ink2,
                ),
                direction,
              ),
            ),
          ],
        ),
      },
    );
  }

  /// The gap between the eyebrow and the line below it in the **empty** arm.
  ///
  /// The populated arm uses the prototype's inline `margin-top: 8px` on the hint
  /// ([hintGap]) and this arm uses `.tv`'s own `margin: 10px 0 0` (`:258`), which
  /// is `VerseOfTheDayCard.verseGap`. It is written as a literal here rather than
  /// imported across features: `features/home` may not import another feature, and
  /// `features/home` importing `features/home` widgets is allowed but a *card*'s
  /// gap is not a shared constant — it is the prototype's number twice, and
  /// `home_geometry_test.dart` pins each site separately.
  static const double verseOfTheDayGap = 10;

  /// The mono eyebrow, shared by both arms: a label, ` · `, and the value in gold.
  ///
  /// `redesign.html:525-526`.
  Widget _eyebrow(
    BuildContext context,
    EvaColors colors,
    String label,
    String value,
  ) {
    final TextDirection direction = Directionality.of(context);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label · ',
            style: TextStyle(color: colors.ink2),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: colors.ember, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: arabicAware(
        EvaTypography.monoCaps(colors).copyWith(color: colors.ink2),
        direction,
      ).copyWith(letterSpacing: direction == TextDirection.rtl ? 0 : 0.16),
    );
  }
}
