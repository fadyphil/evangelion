/// The Eva corner-rounding tokens.
///
/// `docs/plans/03-design-system.md` §5.3: "Radii: buttons `14` · inputs `14` ·
/// cards `18` · quiz options `18` · chips `999` (`Radius.circular(999)`) · hero
/// panel `24` · glass form `28`".
///
/// Bare doubles again, for the same reason as [EvaSpacing]: the token is a
/// magnitude, and whether it becomes a `BorderRadius`, a `CircleBorder` or one
/// side's `Radius` is the widget's decision. Every consumer wraps with
/// `BorderRadius.circular(...)`.
abstract final class EvaRadii {
  /// `14` — buttons. Also inputs (§5.3 gives both 14): a text field and the
  /// button next to it share an edge, so their corners have to agree.
  static const double button = 14.0;

  /// `14` — inputs.
  static const double input = 14.0;

  /// `18` — cards.
  static const double card = 18.0;

  /// `18` — a quiz option. Same value as [card] because a quiz option IS a
  /// card in this system: a tappable surface with a border and a fill.
  static const double quizOption = 18.0;

  /// `999` — chips. Not "very round" but "rounder than the longest side", which
  /// is how `BorderRadius.circular` is asked to mean a pill. The value is fixed
  /// rather than derived from the widget's width because a chip's width is a
  /// function of its label and is not known at token time.
  static const double chip = 999.0;

  /// `24` — the hero panel (Home's today's-reading panel).
  static const double heroPanel = 24.0;

  /// `28` — the glass form on the login screen, the outermost container on a
  /// screen and so the roundest of the rounded surfaces.
  static const double glassForm = 28.0;
}
