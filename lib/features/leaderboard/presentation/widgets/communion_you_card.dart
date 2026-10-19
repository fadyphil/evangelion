import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The gold you-card in `/communion` (`eva/redesign.html:629-633`, `:1099-1107`, D9, D14).
///
/// ## WHAT THE CARD KNOWS, AND THE THREE ARMS IT HAS
///
/// The card answers two questions — *where is the reader* and *what have they
/// got* — and the answer depends on **two** facts, not one:
///
/// 1. is the reader's own row on the page the payload carried?
/// 2. does the server's standing rank the reader at all?
///
/// The second fact is the one this card used to ignore, and ignoring it is
/// what made the card state a falsehood. `my_standing` carries `{rank, score}`
/// and the endpoint's `limit` is 50, so a cohort with more than fifty scored
/// children **drops the reader's own row** from `leaderboard[]` while
/// `my_standing` still says `rank: 51`. Reading "the row is absent" as "the
/// reader is unranked" tells a reader who is 51st that they are not ranked at
/// all.
///
/// So the arms are:
///
/// | the reader's row | the standing | the card prints |
/// | --- | --- | --- |
/// | on the page | — | the **display position** and the **metric's value** |
/// | not on the page | no rank | "Not ranked yet", and **no number** |
/// | not on the page | a rank, on the **light** board | the server's **rank** and the server's **score** |
/// | not on the page | a rank, on the **streak** board | "unranked on this board", and **no number** |
///
/// The third arm is the one the old card could not say. Under `light` the
/// server's rank **is** the reader's place on the board the client is showing
/// — the client does not re-sort under `light`, so the display order is the
/// server's order (see `leaderboard_ranking.dart`'s `leaderboardOrder`) — and
/// the standing's `score` **is** the light metric's own number. Both are real
/// numbers the server sent, and printing the server's rank is printing the
/// truth about a reader who is simply further down than the page reaches.
///
/// The fourth arm is the one the client genuinely **cannot** answer. The
/// standing carries no streak, so the client cannot place the reader on a
/// **streak** board: their streak is not on the page, and their standing rank
/// is the *light* rank, which is not a place on the streak board at all. So
/// the card says the reader is not ranked **on this board** and prints no
/// number — a streak it cannot compute is not a streak it may print, and
/// "never fabricate rank/value" is the rule (D9).
///
/// ## AND THE "UNRANKED ON THIS BOARD" HALF IS **COMPOSED**
///
/// The string table has no "unranked on this board" key, and the ARB is not
/// this change's to edit. So the phrase is the app's own unranked wording
/// (`leaderboardUnranked`) with the **metric's own name** after it, separated
/// by the ' · ' this card already uses for the name's suffix and for the gap
/// line. The metric's name is what scopes the claim: "not ranked" on the
/// streak board is a statement about **this board**, not about the reader's
/// ranking in general, and the reader *is* ranked on the light board.
///
/// ## THE GAP LINE SAYS "LIGHT" EVEN UNDER THE `streaks` METRIC
///
/// The prototype's `gapLine` is one fixed string — `"{name} holds {n} more light"`
/// (`eva/redesign.html:943`) — and it is composed at `:1105-1106` for **both**
/// metrics, so under `streaks` the prototype reads "…holds 12 more light" about a
/// streak gap. That is the prototype's own wording, and this card keeps it
/// verbatim rather than inventing a second string for the other metric.
///
/// The **half** that is not the prototype's is the `passHint`: this card renders
/// it on the `light` metric only (D14), because the ÷15 constant is the light
/// economy (`:755`) and a streak gap is not a number of verses.
///
/// ## AND THE GAP LINE NEEDS A ROW **ON** THE BOARD
///
/// The gap names "the witness one display position above" **by name**, and a
/// reader the page does not carry has no such witness here: the row above
/// them on the full board is not on this page, and the last row on this page
/// is not the row above them. So the gap line is drawn only in the first arm,
/// where the reader's own row is on the board and the witness above them is
/// too.
///
/// ## DIVERGENCES FROM `.youcard` (`:305-312`, `:629-633`), RECORDED HERE
///
/// * **The position is a small mono label under the name, and not the
///   prototype's `.yr` at the leading edge.** The prototype puts the rank in a
///   **24px gold script number in a 36px column** (`:307`'s
///   `font-family:var(--scr);font-size:24px;min-width:36px;text-align:center`),
///   beside the name. This card renders the position as an 11px mono label
///   under the name, in `emberInk` — the same treatment the **row** gives its
///   own position, so the reader's place is written the same way on the card
///   and on the board.
/// * **The gap line runs under the whole card, and not under the name.** The
///   prototype's `.yg` sits inside the name's column (`:631`'s `<span
///   class="yt">…<span class="yg">`), and this card's gap sentence is a line
///   of its own below the row, so it can carry the card's full width.
/// * **The name carries the " · you" suffix, and the prototype's card does
///   not.** `:1103` writes the reader's name into `.yn` **bare**
///   (`el('youName').textContent = lang==='ar'?you.ar:you.en`), and the
///   prototype's suffix is a **list** thing (`:1116`). This card's name is
///   `'{name} · you'`, which is the row's wording — so on this screen the
///   reader is named "you" twice, once on the card and once on their row.
/// * **The card draws a monogram orb, and the prototype's card does not.**
///   `:629-633` is `yr | yt | yv` — a rank, a name and a value, and nothing
///   else. The orb is the row's shape (`LeaderboardRowTile`'s), carried over
///   so the reader has the same monogram here as on their row; without it the
///   card's leading edge would be the position and the position is not there.
/// * **The radius is 16, not 18.** `:305` declares `border-radius:18px`.
/// * **The border and the fill are stronger than the prototype's.** `:305-306`
///   declare `border:1px solid rgba(232,176,75,.4)` and `background:rgba(232,176,75,.06)`;
///   this card draws a 1px `emberInk` border at **50%** over an `ember` fill
///   at **10%**.
/// * **The margin is 8px all round, not the prototype's `16px 18px 6px`.**
///   `:305` declares `margin:16px 18px 6px`; this card uses
///   `EdgeInsets.symmetric(vertical: 8)`. The **padding** is the prototype's
///   (`12px 16px`, `:306`), and the gap between the orb and the name is its
///   `gap:12px`; the gap between the name and the value is 8px
///   (`EvaSpacing.sm`) rather than 12.
class CommunionYouCard extends StatelessWidget {
  /// Creates the you-card.
  const CommunionYouCard({
    required this.readerRow,
    required this.sortedRows,
    required this.metric,
    required this.isVeiled,
    this.standing,
    this.fallbackName,
    super.key,
  });

  /// The reader's own row, or `null` if the page does not carry it.
  final LeaderboardRow? readerRow;

  /// The rows in active display order.
  final List<LeaderboardRow> sortedRows;

  /// The active metric.
  final LeaderboardMetric metric;

  /// Whether the communal veil is on.
  final bool isVeiled;

  /// The server's standing for the reader, or `null` when the response carried
  /// none.
  ///
  /// **This is what lets the card be honest about a reader the page does not
  /// carry.** `my_standing` is `{rank, score}` and the endpoint's `limit` is
  /// 50, so a cohort of more than fifty scored children drops the reader's
  /// own row from the payload while the standing still says `rank: 51`. A
  /// card that reads only the row answers "not ranked" about a reader the
  /// server ranks.
  final LeaderboardStanding? standing;

  /// Fallback reader display name from AuthSession when [readerRow] is null.
  final String? fallbackName;

  /// The monogram for [name]: the **first and last** token's initials.
  ///
  /// ## THIS IS THE MAPPER'S RULE, AND THE RULE LIVES IN TWO PLACES
  ///
  /// `LeaderboardMapper.initialsOf`
  /// (`lib/features/leaderboard/data/mappers/leaderboard_mapper.dart`) is the
  /// authority for a monogram in this feature: it takes the **first and the
  /// last** token, so `'Ana Maria Silva'` reads `AS` and not `AM` — the family
  /// name is the one that tells two children apart, and it is the convention
  /// for a badge. This fallback has to agree with it: the reader's monogram
  /// on this card and the same reader's monogram on their row are the same
  /// two letters, and two rules would make the card and the row disagree
  /// about one person.
  ///
  /// It cannot simply **import** the mapper. The mapper lives in
  /// `features/leaderboard/data/` and this widget lives in
  /// `features/leaderboard/presentation/`, and the dependency direction is
  /// `presentation → domain ← data` (AGENT_CONTEXT §3): a presentation file
  /// may not reach into the data layer, and `tool/verify_purity.sh`'s Gate 2
  /// is the tool that enforces the cross-feature half of that rule. So the
  /// rule is **written down twice**, and this is the second copy — which is
  /// why the copy says whose rule it is.
  ///
  /// ## AND THE ANNOTATION STRIPPING IS **NOT** NEEDED HERE
  ///
  /// The mapper strips a parenthetical grade annotation — `'David Mina (Grade
  /// 5)'` is `DM` and not `D(` — because a row's `full_name` carries one. The
  /// name this fallback runs on is the **session's display name**, and the
  /// two are different strings about the same child: the seeded session is
  /// `'David Mina'` (`auth_local_data_source.dart`'s `kSeedDisplayName`) while
  /// the board's row for that child is `'David Mina (Grade 5)'` (the server's
  /// `users.full_name`). The annotation belongs to the board's name, so the
  /// stripping half of the mapper's rule has nothing to strip here.
  ///
  /// ## AND THE ONE NAMED DIFFERENCE: AN EMPTY NAME
  ///
  /// The mapper answers `?` (its `unknownInitials`) for a name with no letters
  /// in it. This one answers `ME`, because the monogram in question is the
  /// **reader's own** on a card that is about them, and a question mark where
  /// the reader's own initials belong reads as a fault in the app.
  ///
  /// **`runes` and not `[0]`**, for the reason `LeaderboardMapper.initialsOf`'s
  /// own doc gives: `[0]` is a UTF-16 code unit, so it splits a character
  /// outside the Basic Multilingual Plane and yields a lone surrogate.
  static String _initialsOf(String name) {
    final List<String> tokens = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();

    // **`?` and not a Latin `ME`.** The mapper's own unknown-initials
    // placeholder is `?` (`leaderboard_mapper.dart`'s `unknownInitials`), and it
    // is **script-neutral**: a Latin `ME` on the Arabic arm is two Latin letters
    // in a screen where every other glyph is Arabic, and the Arabic
    // typography gate would read it as English in the middle of Arabic.
    if (tokens.isEmpty) return '?';
    if (tokens.length == 1) return _initialOf(tokens.first);
    return '${_initialOf(tokens.first)}${_initialOf(tokens.last)}';
  }

  /// The upper-cased first code point of [token].
  ///
  /// The empty-token branch cannot be reached — the split above drops the
  /// empty tokens — and it is here only to keep the function total, so that a
  /// name with no code points at all cannot throw out of a widget's build.
  static String _initialOf(String token) => token.runes.isEmpty
      ? '?'
      : String.fromCharCode(token.runes.first).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final TextDirection direction = Directionality.of(context);

    final LeaderboardRow? row = readerRow;

    // The reader's place on **this** board, or `0` when their row is not on it.
    final int position = row == null
        ? 0
        : leaderboardPositionOf(sortedRows, row);

    final String name = row?.fullName ?? fallbackName ?? strings.leaderboardYou;
    final String initials = row?.initials ?? _initialsOf(name);

    // ## THE LABEL AND THE VALUE, AND WHICH ARM THEY COME FROM
    //
    // The label is the line under the name — the position in the first arm and
    // a sentence in the others — and the value is the number beside the star.
    final String label;
    final String? valueText;
    if (position > 0 && row != null) {
      // The reader's row is on the board: the **display** position (the
      // metric-dependent one) and the metric's own value.
      //
      // The prototype prints the position through its `N()` digit transform
      // (`eva/redesign.html:1102`), so the Arabic arm reads `٢` and not `2`.
      label = strings.digits(position);
      valueText = strings.digits(leaderboardValueOf(row, metric));
    } else if (standing case LeaderboardStanding(
      rank: final int rank,
      score: final int score,
    )) {
      // The server ranks the reader, and the page does not carry their row.
      if (metric == LeaderboardMetric.light) {
        // The light board: the server's rank **is** the reader's place on the
        // board the client is showing, and the server's score **is** the light
        // metric's own number.
        label = strings.digits(rank);
        valueText = strings.digits(score);
      } else {
        // The streak board: the standing carries no streak, so the client
        // cannot place the reader here and prints **no number**. The metric's
        // name is what scopes the claim to this board.
        label =
            '${strings.leaderboardUnranked} · ${strings.leaderboardMetricStreaks}';
        valueText = null;
      }
    } else {
      // The server does not rank the reader: they are unranked, and the card
      // says so and prints no number at all.
      //
      // **No number is not an omission.** A reader the payload does not rank
      // has no metric value this card could print: the standing's score is
      // the `light` metric's number and not the `streaks` one, and the
      // reader's streak is only on their row. Printing `0` would be a
      // **fabricated** value — a reader with 940 points who is not on this
      // page would be told they have none — and "never fabricate rank/value"
      // is the rule (D9).
      //
      // The prototype cannot express this case: its `READERS` array always
      // contains the reader (`:1059`), so `you` is always found and always
      // has a value.
      label = strings.leaderboardUnranked;
      valueText = null;
    }

    // Gap line derivation (D14)
    String? gapSentence;
    final LeaderboardGap? gapInfo = position > 0
        ? leaderboardGapFor(
            ordered: sortedRows,
            readerPosition: position,
            metric: metric,
          )
        : null;

    if (gapInfo != null) {
      final String aboveName = isVeiled
          ? strings.leaderboardWitness(strings.digits(gapInfo.abovePosition))
          : gapInfo.aboveName;

      final String gapBase = strings.leaderboardGapLine(
        aboveName,
        strings.digits(gapInfo.gap),
      );

      if (gapInfo.verses != null) {
        final String passText = strings.leaderboardPassHint(
          strings.digits(gapInfo.verses!),
        );
        gapSentence = '$gapBase · $passText';
      } else {
        gapSentence = gapBase;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.ember.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.emberInk.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Monogram orb
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.ember.withValues(alpha: 0.25),
                  border: Border.all(color: colors.emberInk, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.emberInk,
                  ),
                ),
              ),
              const SizedBox(width: EvaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$name · ${strings.leaderboardYou}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: arabicAware(
                        text.bodyMedium!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                        direction,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      // **Two lines, because the label can now be a sentence.**
                      // The fourth arm's label carries the metric's name with
                      // the unranked phrase, and §14's text scaling (1.22× at
                      // 320px) makes it the longest run the card prints — so
                      // it wraps rather than overflows, and it ellipsizes
                      // rather than overflows at all.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: arabicAware(
                        EvaTypography.monoCaps(colors).copyWith(
                          fontSize: 11,
                          color: colors.emberInk,
                          fontWeight: FontWeight.w600,
                        ),
                        direction,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EvaSpacing.sm),
              // Value with painted star — **only when there is a value to print.**
              if (valueText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FourPointedStar(size: 11, color: colors.emberInk),
                    const SizedBox(width: 4),
                    Text(
                      valueText,
                      style: arabicAware(
                        EvaTypography.monoCaps(colors).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.emberInk,
                        ),
                        direction,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (gapSentence != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              gapSentence,
              style: arabicAware(
                EvaTypography.monoCaps(colors)
                    .copyWith(fontSize: 11, color: colors.ink2),
                direction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
