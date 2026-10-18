import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/card_washes.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The library: its label, then a horizontal strip of book cards.
///
/// `redesign.html:535-536` and the `.car-label` / `.carousel` / `.bcard` rules at
/// `:272-288`.
///
/// ## THE LABEL IS **COMPOSED**, AND THE PROTOTYPE'S TEXT IS TWO NUMBERS
///
/// `:930` writes `"6 scrolls · 4 open"` as a literal in the I18N table, and it is
/// `buildHome` (`:1311-1318`) that decides what the carousel holds. So the counts
/// are read off the list this widget was given and the ARB owns only the wording —
/// `homeScrollsOpen({scrolls}, {open})`. A hard-coded "6" would be the one number
/// on this screen that survives a catalogue change by being wrong.
///
/// The **sealed** flag is what makes the second number: open is
/// `books.where(not sealed)`. `LibraryCatalogueRepository.books`'s doc is why the
/// order may not be sorted, and this is the one claim about position the label
/// makes.
///
/// ## AND NOTHING HERE IS A BUTTON YET
///
/// `:1314` and `:1318` give every card an `onclick` — `openReader(id)` for an open
/// one and `openSealed(s)` for a sealed one. **Neither destination exists**: `/`
/// opens `/reading`, and `/reading` has no passage parameter and always renders
/// *today's* reading (AGENT_CONTEXT §2). Tapping "psalms" would open John, which is
/// a lie a reader can check.
///
/// So the cards are disabled buttons whose names say why, exactly like the login's
/// ghosts (`:509`) and the selah circle: `Semantics(button: true, enabled: false)`
/// with the unavailable sentence appended, no tap, no focus stop. The catalogue
/// itself is `ADR-0022`'s fiction and `LibraryBook`'s doc says so; the tap is a
/// Phase 5.3 question, because a reader that takes a passage is what the browse
/// library needs and `/reading` does not have one.
class LibraryCarousel extends StatelessWidget {
  /// The label row and the strip of [books].
  const LibraryCarousel({
    required this.books,
    required this.unavailableReason,
    required this.failureMessage,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  /// The catalogue, in the order the repository returned it.
  final List<LibraryBook> books;

  /// Appended to every card's accessible name, never to what is painted.
  final String unavailableReason;

  /// Why the catalogue could not be read, or `null`.
  ///
  /// **Unreachable while the adapter is a literal list** — `HomeState`'s doc says
  /// why the arm is written anyway, and this is where it would render if it ever
  /// did.
  final String? failureMessage;

  /// The retry's label.
  final String retryLabel;

  /// What to run when the reader asks to try again.
  final VoidCallback? onRetry;

  /// The label row's own horizontal inset. `redesign.html:272` — `margin: 20px 18px
  /// 10px`, and this widget sits inside the scroll's own `14px` (`:157`), so 18 is
  /// 4 more than the cards get.
  static const double labelInset = 18;

  /// The label row's top gap. `redesign.html:272` — `20px`.
  static const double labelGap = 20;

  /// The gap under the label row. `redesign.html:272` — `10px`.
  static const double labelBottomGap = 10;

  /// The gap between two cards. `redesign.html:273` — `gap: 12px`.
  static const double cardGap = 12;

  /// The strip's own horizontal inset. `redesign.html:273` — `.carousel`'s
  /// `padding: 4px 14px 12px`, read as top/right/bottom/left, so the **right** value
  /// is 14.
  ///
  /// **A local 14 and not `EvaSpacing.md`**, and that is a correction: the first
  /// version wrote `EdgeInsets.symmetric(horizontal: EvaSpacing.md)` — 12 — and put
  /// every book card 2px left of where the prototype puts it. `home_geometry_test.dart`
  /// is the row that found it, by comparing the label's inset with the strip's card's
  /// and reading 6 where the prototype's 4 is arithmetic.
  ///
  /// 14 is not in `EvaSpacing` (4 · 8 · 12 · 16 · 20 · 24 · 32 · 40), and the token's
  /// own doc says a spacing token is a magnitude the widget applies — not a value to
  /// borrow from the nearest one.
  static const double stripGutter = 14;

  /// The minimum gap between the two spans of the label row.
  ///
  /// **Written and not transcribed**, for the reason the ellipses above give: with
  /// two `Flexible` children, `space-between` distributes *zero* space when the row
  /// is full and the two strings would touch. 8 is the prototype's `.mono`
  /// tracking (`.16em` at 10.5px ≈ 1.7px) doubled and rounded up to something that
  /// reads as a gap — and `home_geometry_test.dart` cannot check it, because the CSS
  /// has no such declaration.
  static const double labelSeparation = 8;

  /// A card's width. `redesign.html:275` — `flex: 0 0 168px`.
  static const double cardWidth = 168;

  /// A card's height. `redesign.html:275` — `height: 132px`.
  static const double cardHeight = 132;

  /// A card's corner rounding. `redesign.html:275` — `border-radius: 20px`, the same
  /// 20 as the selah card and not `EvaRadii.card`'s 18.
  static const double cardRadius = 20;

  /// A card's padding. `redesign.html:276` — `padding: 16px`, which is
  /// `EvaSpacing.lg` and **not** `xl`: the first version of this constant said
  /// `xl`, which is 20, and the analyzer caught it by naming the argument
  /// redundant against `GlassSurface`'s own default (`EvaSpacing.card`, also 20).
  /// A transcription of a padding that agrees with the default is a transcription
  /// nobody reads twice.
  static const EdgeInsets cardPadding = EdgeInsets.all(EvaSpacing.lg);

  /// A card's title size. `redesign.html:280` — `.bn{font-size:19px}`.
  static const double titleSize = 19;

  /// A card's title size on the Arabic arm. `redesign.html:281` — 17px.
  static const double titleSizeArabic = 17;

  /// A card's caption size. `redesign.html:282` — `.bc{font-size:9px}`.
  static const double captionSize = 9;

  /// A card's caption size on the Arabic arm. `redesign.html:283` — 10px.
  static const double captionSizeArabic = 10;

  /// A card's caption tracking under LTR. `redesign.html:282` — `.16em`.
  static const double captionTracking = 0.16;

  /// The seal badge's inset from the card's top-right. `redesign.html:287` —
  /// `top: 12px; right: 12px`.
  static const double sealInset = 12;

  /// The seal badge's padding. `redesign.html:288` — `padding: 3px 8px`.
  static const EdgeInsets sealPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 3,
  );

  /// The seal badge's size. `redesign.html:288` — `font-size: 8.5px`.
  static const double sealSize = 8.5;

  /// The seal badge's tracking. `redesign.html:287` — `.14em`.
  static const double sealTracking = 0.14;

  /// The sealed book's wash multiplier. `redesign.html:285` —
  /// `.bcard.sealed .bloom{opacity:.35}`.
  ///
  /// **Caller state, not a token and not a tier** — `GlassTier.bloom`'s doc says why
  /// and this is the first of the two callers it was waiting for. It is a multiplier
  /// on the card's own colour rather than a second stored value, so the catalogue
  /// holds the prototype's `--bh` and this line is where `.35` is applied.
  static const double sealedWashFactor = 0.35;

  /// The sealed card's own multiplier. `redesign.html:284` — `.bcard.sealed
  /// {opacity:.8}`.
  ///
  /// **NOT ADOPTED, and this is the divergence to read.** The rule dims the whole
  /// card — rim, fill and text together. The three visible halves of it are
  /// adopted individually: this card's wash at [sealedWashFactor], the title in
  /// `--ink-2` (`:286`), and the seal badge. What is left is the rim and the fill at
  /// `.8`, and an `Opacity` over the whole card would be a `saveLayer` per frame —
  /// which is the one cost `GlassTier.bloom` exists to avoid, for a difference no
  /// reader can name. Recorded rather than done.
  static const double sealedCardOpacity = 0.8;

  /// The caption for [book] — the category, and the verse count when it has one.
  ///
  /// `redesign.html:1313` writes `${CATS[b.cat][li()]} · ${N(b.en.length)}
  /// ${tr('verses')}` for an open card and `:1317` writes the category alone for a
  /// sealed one, because `SEALED` holds no verse array. The separator is the
  /// prototype's ` · ` and it appears only when there is a count.
  static String captionFor(AppLocalizations strings, LibraryBook book) {
    final String category = book.category.label(strings);
    final int? count = book.verseCount;
    return count == null
        ? category
        : '$category · ${strings.verseCount(count)}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final String? failure = failureMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // `.car-label{margin: 20px 18px 10px; display:flex;
        // justify-content:space-between}` — `:272`. Both spans are `.mono`, so
        // `:30` gives them the same 10.5px / `.16em` / `--ink-2`.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            labelInset,
            labelGap,
            labelInset,
            labelBottomGap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // **Both spans are `Flexible` with a one-line ellipsis, and the CSS
              // has neither.** `.car-label` is `display: flex;
              // justify-content: space-between` with two `.mono` spans and nothing
              // else — and at 320px with §14's 1.22× step the pair is 273.1px wide
              // in a 270px box, which is a `RenderFlex` overflow of 3.1px measured
              // by `home_text_scale_test.dart` on the first run of this screen.
              //
              // The prototype's own surface is 430 wide where the pair is 226px, so
              // its row fits; §14's requirement is a narrower one and the ellipsis
              // is how this widget meets it. Recorded here rather than left for a
              // reader to find as a yellow stripe.
              Flexible(
                child: Text(
                  monoCapsText(strings.homeTheLibrary, direction),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoStyle(colors, direction),
                ),
              ),
              // The minimum separation the prototype's `space-between` cannot give
              // at 320: two `Flexible` children meeting would read as one string.
              const SizedBox(width: labelSeparation),
              Flexible(
                child: Text(
                  monoCapsText(
                    strings.scrollsOpen(
                      scrolls: books.length,
                      open: _openCount,
                    ),
                    direction,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // `space-between` puts this span at the row's end, so its own
                  // text is right-aligned on the Arabic arm and left on the Latin
                  // one — which is what the prototype's `space-between` produces and
                  // what a `TextAlign.start` would break.
                  textAlign: direction == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                  style: _monoStyle(colors, direction),
                ),
              ),
            ],
          ),
        ),
        if (failure case final String message)
          // **The error replaces the strip and not the label**, so a reader still
          // sees which section failed and where. The family is the label's, for
          // `ErrorView`'s assert — see `home_l10n.dart`'s `retryLabelFamily`.
          ErrorView(
            message: message,
            retryLabel: retryLabel,
            retryFamily: strings.retryLabelFamily,
            onRetry: onRetry,
          )
        else
          SizedBox(
            // The strip's height is the card's, and the strip is given **no**
            // vertical padding: `.carousel`'s `padding: 4px 14px 12px` (`:273`) is
            // the horizontal inset and a 4px top, which the page's own spacing
            // between the label row and the strip already carries as
            // `labelBottomGap`. The 12px under the strip is the page's bottom
            // clearance, not this widget's — see `HomePage`'s doc.
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // **No `Scrollbar`.** `:273-274` hides the bar (`scrollbar-width: none`
              // plus a `::-webkit-scrollbar` rule), and Flutter shows one only where
              // a `Scrollbar` is placed.
              padding: const EdgeInsets.symmetric(
                horizontal: LibraryCarousel.stripGutter,
              ),
              itemCount: books.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: cardGap),
              itemBuilder: (BuildContext context, int index) => _BookCard(
                book: books[index],
                strings: strings,
                unavailableReason: unavailableReason,
              ),
            ),
          ),
      ],
    );
  }

  TextStyle _monoStyle(EvaColors colors, TextDirection direction) =>
      arabicAware(
        EvaTypography.monoCaps(colors).copyWith(color: colors.ink2),
        direction,
      ).copyWith(
        letterSpacing: direction == TextDirection.rtl ? 0 : captionTracking,
      );

  /// How many of [books] are open. The label's second number.
  int get _openCount => books.where((LibraryBook b) => !b.sealed).length;
}

/// One book card: a wash, a name, a caption, and a seal badge on a locked one.
///
/// `redesign.html:275-288` with the content `:1312-1318` writes into it. Private, so
/// the strip is the only way to draw one and the sealed arms cannot be reached with
/// a half-specified card.
class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.strings,
    required this.unavailableReason,
  });

  final LibraryBook book;
  final AppLocalizations strings;
  final String unavailableReason;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      button: true,
      enabled: false,
      // The painted text and the reason, in one node — the card has three runs
      // (title, caption, badge) and a screen reader that announced them separately
      // would make the reader assemble the sentence themselves.
      label:
          '${book.nameFor(direction)} · '
          '${LibraryCarousel.captionFor(strings, book)} — '
          '$unavailableReason',
      excludeSemantics: true,
      child: SizedBox(
        width: LibraryCarousel.cardWidth,
        child: GlassSurface(
          tier: GlassTier.bloom,
          radius: LibraryCarousel.cardRadius,
          padding: LibraryCarousel.cardPadding,
          // `.bcard .bloom{left:6%;right:6%;bottom:-52%;height:88%}` (`:279`) is
          // not reproduced, for the substitution `GlassTier.bloom`'s doc records: a
          // percentage of what is really a composition-specific box has no meaning
          // once the box is one widget. One full-bleed wash, one fade stop.
          seam: false,
          bloomColor: homeCardWash(book.bloomArgb).withValues(
            // `.bcard.sealed .bloom{opacity:.35}` — `:285`, as caller state.
            alpha: book.sealed ? LibraryCarousel.sealedWashFactor : 1.0,
          ),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    book.nameFor(direction),
                    // `.bn{font-family:var(--scr); font-size:19px; font-weight:600}`
                    // — `:280`; `[dir=rtl] .bcard .bn` at `:281` swaps the family
                    // for `--ui-ar` and the size for 17px; `:286` dims a sealed
                    // title to `--ink-2`.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arabicAware(
                      EvaTypography.textTheme(colors).headlineSmall!.copyWith(
                        fontFamily: EvaTypography.scriptureFamily,
                        fontSize: direction == TextDirection.rtl
                            ? LibraryCarousel.titleSizeArabic
                            : LibraryCarousel.titleSize,
                        fontWeight: FontWeight.w600,
                        color: book.sealed ? colors.ink2 : colors.ink,
                      ),
                      direction,
                    ),
                  ),
                  Text(
                    // `.bc{font-family:var(--mono); font-size:9px;
                    // letter-spacing:.16em; text-transform:uppercase;
                    // color:var(--ink-1)}` — `:282`, and `:283` is the RTL swap.
                    // **`maxLines: 1` and an ellipsis, which the CSS does not have**:
                    // at 1.22× on a 320px screen "poetry · 6 verses" at 9px and
                    // `.16em` is wider than the card's 136px of content, and an
                    // unbounded `Text` in a fixed-height card overflows. The one
                    // divergence this card has, and `home_text_scale_test.dart` is
                    // what measured it.
                    monoCapsText(
                      LibraryCarousel.captionFor(strings, book),
                      direction,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arabicAware(
                      EvaTypography.monoCaps(colors).copyWith(
                        fontSize: direction == TextDirection.rtl
                            ? LibraryCarousel.captionSizeArabic
                            : LibraryCarousel.captionSize,
                        letterSpacing: direction == TextDirection.rtl
                            ? 0
                            : LibraryCarousel.captionTracking,
                        color: colors.ink2,
                      ),
                      direction,
                    ),
                  ),
                ],
              ),
              if (book.sealed)
                Positioned(
                  top: LibraryCarousel.sealInset,
                  right: LibraryCarousel.sealInset,
                  child: _SealBadge(label: strings.homeSealed),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `sealed` pill on a locked card. `redesign.html:287-288`.
class _SealBadge extends StatelessWidget {
  const _SealBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Container(
      padding: LibraryCarousel.sealPadding,
      decoration: BoxDecoration(
        color: colors.canvas.withValues(alpha: 0.25),
        borderRadius: const BorderRadius.all(Radius.circular(EvaRadii.chip)),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Text(
        monoCapsText(label, direction),
        style: arabicAware(
          EvaTypography.monoCaps(colors).copyWith(
            fontSize: LibraryCarousel.sealSize,
            letterSpacing: direction == TextDirection.rtl
                ? 0
                : LibraryCarousel.sealTracking,
            color: colors.ink2,
          ),
          direction,
        ),
      ),
    );
  }
}
