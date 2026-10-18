import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/card_washes.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The day's reading: a mono eyebrow, the reference in gold, and the verse.
///
/// `redesign.html:519-523`. One `GlassSurface`, and **the one blur site on `/`** —
/// see the class doc for why this card and not the last-light card below it.
///
/// ## WHAT THE CARD DROPPED, AND WHERE EACH THING WENT
///
/// The panel this replaces drew an eyebrow, a truncated preview, the reference, a
/// bead row, a status line and two buttons (`today_reading_panel.dart`, now
/// deleted). The redesign's card draws an eyebrow and the verse. So:
///
/// | the panel had | the card renders | why |
/// | --- | --- | --- |
/// | 56-character preview | **the whole first verse** | `:522` sets `votdText` and truncates nothing; the truncation was the panel's, from the React prototype |
/// | `continueReading` / `readingComplete` status line | nothing | `:519-523` has no status line; the redesign's day-status vocabulary is the journey's rings |
/// | bead row (`ProgressBeads`) | nothing | the redesign's dot row is the **quiz's** (`:328-332`, `:568`) and counts quiz questions |
/// | Continue / Start reflection buttons | the card's own tap | `:1318` — `el('votdCard').onclick=()=>openReader('psalms')`, so the whole card opens the reader |
///
/// The verse text is **not** truncated, which means `preview_text.dart` and its
/// 258-line suite left the app with the panel and `home_page_test.dart`'s
/// truncation claims with them. A long first verse makes the card taller and the
/// screen scrolls — which is what the prototype does.
///
/// ## AND THE SEAM, AND WHY THIS IS THE SURFACE THAT SPENDS §13.4'S BUDGET
///
/// `.hcard` (`:249-257`) is the only declaration in the redesign that carries a
/// backdrop filter, a `.bloom` and a `.hor` **together**, and `#votdCard` is the
/// card today's reading is drawn on. `GlassTier.blur`'s doc records why the tier
/// paints the wash and the seam as well as the filter; this is its only caller,
/// and `glass_blur_budget_test.dart`'s ceiling of one in `lib/features/` is spent
/// here.
///
/// The alternative was the last-light card, which is also a `.hcard` — and it would
/// have been the wrong one: the budget's own table says the one allowed site is
/// "Home's today's-reading panel" because it "sits directly over the animated
/// background and is expected to let it show through", and a card naming a reading
/// from three days ago is not what a reader came to look at.
class VerseOfTheDayCard extends StatelessWidget {
  /// The day's card: the verse when [reading] is here, an error when [failure] is.
  const VerseOfTheDayCard({
    required this.reading,
    required this.failureMessage,
    required this.retryLabel,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  /// Today's reading, or `null` while it is loading or failed.
  final TodayReading? reading;

  /// Why it could not be read, or `null`.
  ///
  /// **The repository's own sentence**, `ErrorView`'s rule: `failure.dart` requires
  /// the server's wording verbatim and this is one of the two places on `/` where
  /// a repository message reaches a reader.
  final String? failureMessage;

  /// The retry's label.
  final String retryLabel;

  /// What to run when the reader asks to try again.
  final VoidCallback? onRetry;

  /// What to run when the reader opens the day's reading.
  ///
  /// **Null while the card holds no reading**, and that is also why a failed card
  /// needs no accessible name: it is not a button.
  final VoidCallback? onOpen;

  /// The card's corner rounding. `redesign.html:249` — `border-radius: 24px`,
  /// which is [EvaRadii.heroPanel], the token §5.3 published for "Home's
  /// today's-reading panel" by name.
  static const double radius = EvaRadii.heroPanel;

  /// The card's padding. `redesign.html:250` — `padding: 22px 20px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.xl,
    vertical: 22,
  );

  /// The wash. `redesign.html:519` — `style="--bh:rgba(228,87,214,.55)"`, the
  /// magenta the prototype gives this card and the only `.hcard` that is not gold.
  ///
  /// **Not `EvaColors.bloom`**, whose value is the same colour — `#E457D6` at
  /// `.55` is `0x8CE457D6`, and `bloom` is exactly that. `EvaColors.bloom` is the
  /// `var(--bh, …)` *fallback* for a host that names none; this host names one, so
  /// the value lives where the prototype writes it —
  /// `card_washes.dart`, the transcription table the colour gate exempts — and
  /// this constant is the *name* the widget reads it by.
  static const int washArgb = homeVotdWashArgb;

  /// The gap between the eyebrow and the verse. `redesign.html:258` — `.hcard .tv`
  /// is `margin: 10px 0 0`.
  static const double verseGap = 10;

  /// The verse's size under LTR. `redesign.html:258` — `font-size: 19px`.
  static const double verseSize = 19;

  /// The verse's size on the Arabic arm. `redesign.html:259` — `[dir=rtl] .hcard
  /// .tv{font-size: 20px}`.
  static const double verseSizeArabic = 20;

  /// The verse's line height under LTR. `redesign.html:258` — `line-height: 1.6`.
  static const double verseHeight = 1.6;

  /// The verse's line height on the Arabic arm. `redesign.html:259` — 1.9, and
  /// Amiri's marks sit above the baseline by a line, so the Arabic figure is not
  /// decoration.
  static const double verseHeightArabic = 1.9;

  /// The verse's family, its size and its line height, for the **rendered** arm.
  ///
  /// ## WHY THE RENDERED ARM AND NOT THE PAYLOAD'S
  ///
  /// `ScriptureBlock` keys its family on `TodayReading.language` — the payload's own
  /// arm — because the two facts are independent there and a reader who switched
  /// locale mid-passage should keep the passage's script. **This card is keyed the
  /// other way, and the CSS is why:** `:258-259` is
  /// `[dir=rtl] .hcard .tv{font-family:var(--ar); font-size:20px; line-height:1.9}`,
  /// which hangs off the **document's** direction rather than the content's — so the
  /// Arabic page draws every verse at 20px in Amiri whatever the server sent.
  ///
  /// The two rules agree on a real screen, because `_HomeBody` fetches with the
  /// ambient arm (§3's rule, and the reason the events carry a `ReadingLanguage`),
  /// so the payload's language *is* the rendered direction. They disagree only in a
  /// **fixture** — an English payload under an `ar` locale — and there the CSS's
  /// direction wins, because that is what a browser would do with the same markup.
  ///
  /// Recorded because it reads like an oversight: the card's own doc says the family
  /// follows the payload's arm, and it does not. `arabic_typography_gate.dart` is the
  /// gate that settles it — it asserts every painted Arabic run renders in
  /// `EvaTypography.arabicFamily`, and a payload-keyed family would put an English
  /// fixture's verse in EB Garamond on the Arabic arm, which that gate forbids.

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TodayReading? today = reading;
    final String? failure = failureMessage;

    return GlassSurface(
      // §14's row: `el('votdCard').onclick` → `GlassSurface(onTap:)` →
      // `InkWell` inside a `Material`, keyboard-activatable. `GlassSurface` does
      // the rest.
      tier: GlassTier.blur,
      radius: radius,
      padding: padding,
      bloomColor: homeCardWash(washArgb),
      onTap: today == null ? null : onOpen,
      // **The empty string, and it is not a sentinel — it is the truth.** The
      // prototype's card has no name of its own: `:521-522` is an eyebrow, a
      // reference and the verse, and a screen reader should read all three. Naming
      // the surface separately makes `GlassSurface`'s merged label repeat the
      // eyebrow — measured, with the label passed as the eyebrow's own words:
      //
      // ```text
      // verse of the day              <- semanticLabel
      // VERSE OF THE DAY · JOHN 3:1-5 <- the eyebrow, merged
      // There was a man of the Pharisees, named Nicodemus…  <- the verse, merged
      // ```
      //
      // which is a card announced twice over. With `''` the same node reads
      // `VERSE OF THE DAY · JOHN 3:1-5` followed by the verse — measured, and the
      // reason. `GlassSurface.semanticLabel`'s doc records that the constructor
      // assert cannot see a child's contribution and that
      // `home_accessibility_test.dart`'s sweep is the gate that can.
      semanticLabel: today == null ? null : '',
      child: switch ((failure, today)) {
        // A failure is an `ErrorView` **inside the card**, not a replacement for
        // it: the shell — radius, wash, seam, padding — stays, so the four
        // sections around it do not move, and the reader is offered the retry §13's
        // per-section rule requires. `redesign.html` has no failure vocabulary at
        // all (its data layer cannot fail), which is `error_view.dart`'s own doc.
        (final String message, null) => ErrorView(
          message: message,
          retryLabel: retryLabel,
          retryFamily: strings.retryLabelFamily,
          onRetry: onRetry,
        ),
        // Loading: **the label and an empty line, not a placeholder verse and not a
        // shimmer.** The empty `Text` is `_StreakSubtitle`'s argument — measured at
        // 20.0 tall and 0.0 wide, one line exactly — so the card holds its height
        // between the three arms without a second copy of `fontSize × height` that
        // would not move when the reader's text scale does.
        (null, null) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _eyebrow(
              context,
              colors,
              monoCapsText(
                strings.homeVerseOfTheDay,
                Directionality.of(context),
              ),
              null,
            ),
            const SizedBox(height: verseGap),
            Text(
              '',
              style: arabicAware(
                EvaTypography.scriptureLatin(colors)
                    .copyWith(color: colors.ink),
                Directionality.of(context),
              ),
            ),
          ],
        ),
        // **Three arms for four states, and the fourth is not reachable.** A `Failure`
        // and a reading are the same section at the same time only if a writer
        // produced both, and `_emitReading` clears one when it writes the other —
        // so the reading wins and the wildcard pair says so rather than adding an
        // arm that no state machine can enter.
        (_, final TodayReading value) => _content(
          context,
          colors,
          strings,
          value,
        ),
      },
    );
  }

  /// The mono eyebrow: a label, ` · `, and the reference in gold.
  ///
  /// `redesign.html:521` — `<div class="mono"><span>votd</span> · <b id="votdRef">`.
  /// A null [reference] is the loading arm, which has the label and nothing to
  /// put after the separator.
  Widget _eyebrow(
    BuildContext context,
    EvaColors colors,
    String label,
    String? reference,
  ) {
    final TextDirection direction = Directionality.of(context);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          // **One `Text.rich`, not two widgets**, for the reason the old
          // `_Greeting` records: two widgets wrap independently and the reference
          // lands on its own line at 320px. And one style for both spans because
          // the family is the same — the reference is the **server's** string, so on
          // the Arabic arm it is `المزمور ٢٣: ١-٦` and `arabicAware` is what keeps
          // both runs off the mono face, which carries no Arabic at all.
          TextSpan(
            text: reference == null ? label : '$label · ',
            style: TextStyle(color: colors.ink2),
          ),
          if (reference != null)
            TextSpan(
              text: reference,
              // `.mono b{color: var(--gold); font-weight: 600}` — `:31`.
              style: TextStyle(
                color: colors.ember,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      style:
          arabicAware(
            EvaTypography.monoCaps(colors).copyWith(color: colors.ink2),
            direction,
          ).copyWith(
            // `[dir=rtl] .mono{letter-spacing:0}` (`:135`), and the LTR figure is
            // `.mono`'s own `.16em` (`:30`).
            letterSpacing: direction == TextDirection.rtl ? 0 : 0.16,
          ),
    );
  }

  Widget _content(
    BuildContext context,
    EvaColors colors,
    AppLocalizations strings,
    TodayReading today,
  ) {
    final TextDirection direction = Directionality.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _eyebrow(
          context,
          colors,
          monoCapsText(strings.homeVerseOfTheDay, direction),
          // **The reference is uppercased on the LTR arm**, and that is the
          // prototype rendering it: the value is a child of `.mono` (`:521`) and
          // `text-transform` is inherited, so `:30` uppercases it too. The
          // *server's* casing is preserved — `Decision 53` is about never parsing
          // the string, and no case of it is ever read back.
          monoCapsText(today.reference, direction),
        ),
        const SizedBox(height: verseGap),
        Text(
          today.firstVerseText,
          // **`arabicAware` alone, and it is the family *and* the arm.** The
          // prototype keys all three of size, family and line height off `[dir]`
          // (`:258-259`); `arabicAware` is this app's spelling of the family and the
          // two ternaries below are the spelling of the other two. See this class's
          // `verseFamilyFor`-turned-documentation above for why this is not keyed on
          // the payload.
          style: arabicAware(
            EvaTypography.scriptureLatin(colors).copyWith(
              fontSize: direction == TextDirection.rtl
                  ? verseSizeArabic
                  : verseSize,
              height: direction == TextDirection.rtl
                  ? verseHeightArabic
                  : verseHeight,
              color: colors.ink,
            ),
            direction,
          ),
        ),
      ],
    );
  }
}
