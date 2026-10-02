/// The Eva spacing scale — a 4px base with eight named steps.
///
/// `docs/plans/03-design-system.md` §5.3: "Spacing (4px base): `4 · 8 · 12 · 16
/// · 20 · 24 · 32 · 40` → `xs/sm/md/lg/xl/xxl/xxxl/huge`."
///
/// Bare doubles, not `EdgeInsets`. A token table whose values are already
/// positioned would force a caller to either accept a fixed side set or reach for
/// `copyWith` on every asymmetric use, and the horizontal gutter here is applied
/// symmetrically while vertical rhythm is applied per edge. Widgets compose: the
/// token is the number, the `EdgeInsets` is the widget's business.
abstract final class EvaSpacing {
  /// The base unit. Every step is a whole multiple of this, so a new step is a
  /// multiplication and nothing has to be re-derived.
  static const double base = 4.0;

  /// `4` — the tightest gap that still reads as a gap. Between a chip's dot and
  /// its label.
  static const double xs = 4.0;

  /// `8` — between tightly-coupled siblings, e.g. a stat tile's value and unit.
  static const double sm = 8.0;

  /// `12` — between related blocks, e.g. the rows inside one settings group.
  static const double md = 12.0;

  /// `16` — the default gap between siblings.
  static const double lg = 16.0;

  /// `20` — screen gutter and card padding. See [screenHorizontal] and [card].
  static const double xl = 20.0;

  /// `24` — between sibling cards.
  static const double xxl = 24.0;

  /// `32` — between a section header and its content.
  static const double xxxl = 32.0;

  /// `40` — above a page's first element, and between major sections.
  static const double huge = 40.0;

  /// Horizontal padding for a screen's content.
  ///
  /// §5.3: "Screen horizontal padding = 20". Aliased to [xl] rather than
  /// repeated, so the gutter and the step cannot drift apart.
  static const double screenHorizontal = xl;

  /// Padding inside a card. §5.3: "card padding = 20".
  static const double card = xl;
}
