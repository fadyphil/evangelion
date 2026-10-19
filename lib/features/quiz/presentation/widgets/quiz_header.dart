import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The quiz's chrome above the question body — `eva/redesign.html:563-568`.
///
/// Two rows, in the prototype's own order: the `.appbar` (a `.chev` back control,
/// the centred `.ttl` crumb and the `.mono` gold score, `:563-566`) and the `.dots`
/// row beneath it (`:568`).
///
/// ## WHAT REPLACED THE OLD ROW, AND WHY THE WIDGET SURVIVED
///
/// This widget used to be `IconActionButton(close)` + `ProgressBeads` + a 44px
/// spacer — the old prototype's top row. The redesign's quiz chrome is a different
/// three-part row and the beads move **below** it, but the widget's job (the
/// screen's fixed chrome) and its only consumer (`QuizPage`) are unchanged, so it
/// is rebuilt in place rather than replaced.
///
/// **`ProgressBeads` is re-homed, not rebuilt.** It was re-rolled to the `.dot`
/// vocabulary (`redesign.html:328-332`) in the Phase 4/5 widget pass — 8px dots,
/// the 26px current lozenge, done at 45% gold — and its doc records the arithmetic.
/// What changes here is only where it sits: `:568` puts `.dots` under the appbar,
/// centred, with the row's own `padding: 8px 0 4px` (`:328`), and its count is the
/// **full session** — the prototype's `Math.min(3, …)` cap (`:1353`) is a fiction
/// of its local fixture, and this client renders the server's `questions[]` (the
/// recorded decision 89 chain).
class QuizHeader extends StatelessWidget {
  /// The chrome: back, crumb, score, and the session's bead row.
  const QuizHeader({
    required this.crumb,
    required this.score,
    required this.total,
    required this.completed,
    required this.current,
    required this.language,
    required this.strings,
    this.onExit,
    super.key,
  });

  /// The crumb's second half, already composed — `quiz_l10n.dart`'s
  /// `quizCrumb(reference)`. The widget renders it verbatim and never rebuilds it,
  /// because the composition is a string decision with one home.
  final String crumb;

  /// The number after the star — `QuizSession.runningScore`.
  final int score;

  /// `ProgressBeads.total` — the session's `questionCount`.
  final int total;

  /// `ProgressBeads.completed` — the session's `answeredCount`.
  ///
  /// **`answeredCount` and not "checked in this session"**, because
  /// `QuizSession.answeredCount` counts a question the wire already answered. A
  /// reader arriving on a session whose question is flagged must see a filled bead,
  /// because that is the truth about their day; a row of empty beads beside a
  /// disabled card would say the opposite.
  final int completed;

  /// `ProgressBeads.current` — `QuizState.currentIndex`.
  final int current;

  /// Which arm of the corpus — the payload arm, for the same reason
  /// `QuizOptionCard.language` is: the crumb's second half is server text in the
  /// session's language, and the chrome is drawn over it.
  final ReadingLanguage language;

  /// The bilingual strings.
  final AppLocalizations strings;

  /// What the back control runs. `null` renders it disabled, as [SocialAuthButton]
  /// does.
  final VoidCallback? onExit;

  /// The appbar's own box: `eva/redesign.html:142` — `padding: 46px 18px 4px`.
  static const EdgeInsets appbarPadding = EdgeInsets.fromLTRB(18, 46, 18, 4);

  /// The crumb's cap. `eva/redesign.html:144` — `max-width: 52%`.
  static const double crumbMaxWidthFactor = 0.52;

  /// The row's floor. `eva/redesign.html:143` — `min-height: 34px`.
  static const double rowMinHeight = 34;

  /// The chevron glyph. `eva/redesign.html:564` — a literal `‹` (U+2039) at 16px.
  ///
  /// ## A TEXT GLYPH AND NOT AN ICON, MEASURED
  ///
  /// U+2039 is carried by **all five** bundled families — measured against every
  /// TTF's `cmap`, the same instrument as `font_coverage.dart` — so the prototype's
  /// own character is the faithful transcription and `Icons.chevron_left` would be
  /// a Material shape the prototype never drew.
  static const String chevGlyph = '‹';

  /// `eva/redesign.html:149` — `font-size: 16px` on `.chev`.
  static const double chevFontSize = 16;

  /// The back control's tap box.
  ///
  /// ## 44, AND THE ROW IS TALLER THAN THE PROTOTYPE'S 34 — RECORDED
  ///
  /// `eva/redesign.html:149` gives the chevron only `padding: 4px 6px`, a ~28px
  /// box. This client's floor for a touch target is 44 (`IconActionButton`'s
  /// default and `iOSTapTargetGuideline`'s minimum), so the chevron is painted at
  /// the prototype's size inside a 44×44 box — recorded decision 31's exact shape
  /// for the avatar. **The cost is the same one that decision states**: a row is as
  /// tall as its tallest child, so the `.abrow` renders 44 tall where `:143` wrote
  /// `min-height: 34`.
  static const double chevTapSize = 44;

  /// The score's star. `eva/redesign.html:566` — `✦ 0` inside `.mono`, whose
  /// `font-size` is 10.5px (`:30`), and a painted star's box is the glyph's em box
  /// (`FourPointedStar`'s doc carries the rule).
  static const double scoreStarSize = 10.5;

  /// The gap between the painted star and its number. `:566` renders one space
  /// character at `.mono`'s 10.5px; the space glyph's advance in JetBrains Mono is
  /// ≈ 4.2px, so the gap is the box that character would have occupied.
  static const double scoreStarGap = 4;

  /// `.mono`'s size. `eva/redesign.html:30` — `10.5px`.
  static const double scoreFontSize = 10.5;

  /// `.mono`'s tracking. `eva/redesign.html:30` — `letter-spacing: .16em`,
  /// resolved against the element's own 10.5px for the recorded CSS-em rule
  /// (`questionLabelLetterSpacing`'s doc carried the same arithmetic).
  static const double scoreLetterSpacing = 0.16 * scoreFontSize;

  /// The dots row's own box: `eva/redesign.html:328` — `padding: 8px 0 4px`.
  static const EdgeInsets dotsPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);

  /// The score's [TextStyle] for the arm [language].
  ///
  /// ## THE INK IS `emberInk`, AND THAT IS A SUBSTITUTION RECORDED TWICE
  ///
  /// `eva/redesign.html:566` overrides `.mono`'s colour with `var(--gold)` inline —
  /// the prototype's gold, which is **not a token** in this design system, and the
  /// orchestrator's locked decision is that no new gold token is created. Text
  /// takes the approved accent ink: `emberInk` (decision 153's split), whose light
  /// value clears 4.5:1 where the prototype's own light gold ink does not
  /// (`eva_colors.dart` carries the table). In dark the two palettes' values agree
  /// with the prototype's to within a shade.
  ///
  /// ## AND THE FAMILY IS **NOT** MONO ON THE ARABIC ARM
  ///
  /// The score's digits are this arm's numerals — Arabic-Indic under RTL, by
  /// [AppLocalizationsArm.digits] — and U+0660–U+0669 are Arabic-block codepoints
  /// that are tofu in a mono face. The same reason `quiz_l10n.dart`'s old
  /// `questionProgress` switched families: the digits follow the arm, so the family
  /// does too.
  static TextStyle scoreStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) => Theme.of(context).textTheme.labelMedium!.copyWith(
    fontSize: scoreFontSize,
    letterSpacing: scoreLetterSpacing,
    fontFamily: switch (language) {
      ReadingLanguage.english => EvaTypography.monoFamily,
      ReadingLanguage.arabic => EvaTypography.arabicFamily,
    },
    color: context.colors.emberInk,
  );

  /// The crumb's [TextStyle] for the arm [language].
  ///
  /// `eva/redesign.html:144-145` — weight 600, 15px, `letter-spacing: -.01em`,
  /// `--ink-0`, nowrap + ellipsis, absolutely centred. The family is `.route`'s —
  /// the UI face under LTR and the Arabic UI face under RTL (`:134`) — and the
  /// crumb is **chrome**, so the ambient rule is the one that applies; the
  /// reference inside it is carried whole, including its own digits.
  static TextStyle crumbStyleFor(
    BuildContext context,
    ReadingLanguage language,
  ) {
    final TextStyle base = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01 * 15,
      color: context.colors.ink,
      // The `.ttl`'s own overflow rule (`:145`) — one line, ellipsised.
      overflow: TextOverflow.ellipsis,
    );
    return base.copyWith(
      fontFamily: switch (language) {
        ReadingLanguage.english => EvaTypography.uiFamily,
        ReadingLanguage.arabic => EvaTypography.arabicFamily,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);

    final Widget back = Semantics(
      button: true,
      enabled: onExit != null,
      label: strings.quizExit,
      // **The action has to live on the node that carries the name.** The
      // `excludeSemantics: true` above drops `EvaInk`'s own tap node, so a wrapper
      // without `onTap` would announce a named button that a screen reader cannot
      // activate — measured by `quiz_accessibility_test.dart`'s graded sweep, which
      // saw zero tappable nodes once every option was disabled and only this control
      // and the CTA remained.
      onTap: onExit,
      excludeSemantics: true,
      child: EvaFocusRing(
        enabled: onExit != null,
        child: EvaInk(
          onPressed: onExit,
          child: SizedBox(
            width: chevTapSize,
            height: chevTapSize,
            child: Center(
              child: Text(
                // `[dir=rtl] .chev{transform:scaleX(-1)}` (`eva/redesign.html:139`)
                // — the chevron points the way back, and back is the other way
                // under RTL.
                chevGlyph,
                textDirection: direction,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: chevFontSize,
                  color: context.colors.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Widget scoreRow = Semantics(
      // The painted star is decorative (`FourPointedStar`'s doc carries the
      // reasoning), so what this node announces is the number — which is also what
      // a sighted reader reads after the shape.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FourPointedStar(size: scoreStarSize, color: context.colors.emberInk),
          const SizedBox(width: scoreStarGap),
          Text(strings.digits(score), style: scoreStyleFor(context, language)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: appbarPadding,
          child: SizedBox(
            height: chevTapSize,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Stack(
                    alignment: AlignmentDirectional.center,
                    children: <Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: back,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: scoreRow,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * crumbMaxWidthFactor,
                        ),
                        child: Text(
                          // `eva/redesign.html:145` — `white-space: nowrap;
                          // overflow: hidden; text-overflow: ellipsis`, and the
                          // style above carries the same rule.
                          crumb,
                          maxLines: 1,
                          style: crumbStyleFor(context, language),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
        // `eva/redesign.html:568` — `<div class="dots">` as a sibling under the
        // appbar, and `:328` gives the row its own `padding: 8px 0 4px` and
        // centring. The widget itself publishes no padding, so the chrome owns it.
        Padding(
          padding: dotsPadding,
          child: Center(
            child: ProgressBeads(
              total: total,
              completed: completed,
              current: current,
              // **The caller's prefix, not the default.** `ProgressBeads`'s
              // `semanticLabel` defaults to the English `'Progress'`, which would
              // put an English word in the Arabic arm's semantics tree — the same
              // half-translated string decision 78 removed from `FontSizeStepper`.
              semanticLabel: strings.quizProgress,
            ),
          ),
        ),
      ],
    );
  }
}
