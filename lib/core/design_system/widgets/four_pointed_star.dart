import 'package:flutter/material.dart';

/// `✦` U+2726 BLACK FOUR POINTED STAR, painted rather than typed.
///
/// ## WHAT IT IS FOR
///
/// The prototype writes the four-pointed star as a **character** in two places —
/// `eva/redesign.html:531`'s `<button class="breathing" …>✦</button>` and
/// `eva/redesign.html:544`'s `<button class="iconbtn" id="bmBtn"
/// title="bookmark">✦</button>` — and a browser renders it, because a browser has
/// the whole system font library to draw it with.
///
/// **This client does not.** `IconData` is a codepoint plus a `fontPackage`, so
/// `const IconData(0x2726, fontFamily: …)` would be the same glyph *request* and
/// the same missing-glyph outcome as typing it, expressed as an icon. There is no
/// icon font entry for it either — Material has no `Icons.star_four_points`. So
/// the only way to draw what the prototype drew is to **paint** it, and this is
/// that paint.
///
/// It used to be private to `features/home`'s selah card, which meant `/reading`
/// could not reach the shape the prototype puts in its own bookmark button at
/// `:544`. §3's placement test puts a type consumed by two features in the
/// shared kernel — for design-system UI that is `core/design_system/`, which is
/// where every other widget both screens share already lives.
///
/// ## THE MEASUREMENT THAT MADE IT NECESSARY, AND HOW TO REPEAT IT
///
/// **U+2726 is in no bundled family.** Not "the mono face lacks it", not "the
/// prototype's own CSS picks a face that has it" — *no* face this app ships
/// carries the codepoint, so the character renders as a tofu box in every
/// bundled family and in whatever the engine falls back to.
///
/// How it was measured: every `.ttf` under `assets/fonts/` has a `cmap` table
/// mapping Unicode codepoints to glyphs, and reading those tables answers the
/// question exactly. `test/support/font_coverage.dart` is the reader (formats 4
/// and 12, all subtables unioned — it refuses rather than returning an empty set,
/// because a silent empty set makes every coverage assertion vacuously true,
/// which is §7's "a gate that cannot fail is worse than no gate"), and the
/// shipped count is **nineteen files across five families**: `Amiri`,
/// `EBGaramond`, `IBMPlexSansArabic`, `Inter`, `JetBrainsMono`. Asking
/// `codepointsForFamily` about `0x2726` for each of the five returns **empty**,
/// every time.
///
/// **Nineteen, not twenty.** `AGENTS.md`, `font_coverage.dart`'s own header and
/// `selah_card.dart`'s copy of this claim all say twenty `.ttf`s; the directory
/// holds nineteen and `pubspec.yaml` declares the same nineteen. Those three are
/// not edited here — `AGENTS.md` and the design-system harness are not this
/// file's to correct — so the number is measured here rather than copied, and the
/// count is published as a constant below so the claim is checkable.
///
/// **The gate that caught it is a name, not a description.**
/// `test/arabic_typography_test.dart`'s `expectNoTofuInAnyRun` runs over every
/// rendered run on `/`, `/login`, `/reading` and `/settings`, and the first build
/// of the selah circle typed the character. It failed with
///
/// ```text
/// `✦` is rendered in `JetBrainsMono`, which has no glyph for U+2726 — these
/// would be tofu boxes on /.
///   Actual: [10022]
/// ```
///
/// `10022` is `0x2726` in decimal, and it is the whole finding: a painted shape
/// is what replaced it.
///
/// ## WHY PAINTING IS THE ANSWER AND NOT A SUBSTITUTION
///
/// A browser falls back **per character**: the engine walks the family list for
/// each codepoint it is handed, and `✦` finds a glyph in some system font. The
/// rendered result is invisible as a substitution — it looks like a star, which
/// is exactly why the defect survived into a design that was written down.
///
/// `TextStyle.fontFamilyFallback` is the same mechanism, and it has **nothing to
/// fall back to**: the glyph is not in the requested family, it is not in any of
/// the five bundled ones, and it is not in a family this app may add (§8.4 fixes
/// the dependency set). So `fontFamilyFallback` would only be a longer list of
/// misses.
///
/// **Rejected: swapping in a nearby glyph a bundled family does carry.**
/// Measured: **U+2605 BLACK STAR** *is* in `Inter`, all five weights of it. It is
/// a five-pointed star. The prototype's mark is four-pointed, and at the 11px the
/// selah circle draws it the difference between ✦ and ★ is the whole silhouette.
/// Shipping ★ under a doc comment that says ✦ is the decision-144 shape — the
/// suite is green and the reader is handed something nobody chose.
///
/// **Rejected: an SVG or a bundled asset.** `flutter_svg` is not a dependency
/// (§8.4) and §8.4's list does not grow for one glyph; and a 4-segment path is
/// not an asset, it is the whole content of this file.
///
/// ## WHICH SURFACES USE IT, AND WHICH ARE COMING
///
/// | surface | prototype | status |
/// | --- | --- | --- |
/// | `/`, the selah circle's centre | `:269` `.breathing{… font-size:11px}` | **shipped** — `SelahCard` passes `11`, which is the CSS's `font-size` |
/// | `/reading`, the bookmark button | `:544` `#bmBtn` | **incoming** — Task 5.3's rebuild of `/reading` |
///
/// **The size is the glyph's `font-size`, not a box invented here.** `:269` sizes
/// the circle 44×44 with `font-size: 11px`, and a text glyph's box matches its
/// font size, so [size] is the em box the character would have occupied. That is
/// the rule a caller follows: read the prototype's `font-size` and pass it.
///
/// `:544`'s `✦` is sized by whatever `.iconbtn` inherits, and the size that
/// bookmark button needs is **Task 5.3's measurement, not this file's** — which
/// is why the widget takes a `size` and publishes no default for it. A default
/// would be a second answer to a question the caller has already answered, and
/// `PassageDropCap`'s doc records that reasoning for the same choice.
///
/// ## IT IS DECORATIVE, AND THAT IS A CLAIM WITH A WITNESS
///
/// The shape carries **no accessible name of its own**, on purpose. Both call
/// sites put it inside a control that already names itself — the selah circle's
/// `Semantics(button: true, enabled: false, label: '$label — $reason',
/// excludeSemantics: true)` — so a name here would be a second, competing
/// announcement for a decoration.
///
/// `four_pointed_star_test.dart` asserts the negative half (mounted alone the
/// widget publishes **no** semantics node carrying a label, and offers no action),
/// and `home_page_test.dart`'s `'the circle announces that it cannot be pressed,
/// and why'` asserts the positive half at a real call site. Neither alone would
/// be the claim.
///
/// The consequence, which is the cost of the choice: a reader who wants the star
/// as an option cannot be given one, because there is nothing to name. That is
/// the right trade for a glyph that is standing in for a character's *shape* —
/// the meaning lives on the button, not on the ornament.
class FourPointedStar extends StatelessWidget {
  /// A four-pointed star drawn in a [size] × [size] box, in [color].
  const FourPointedStar({required this.size, required this.color, super.key});

  /// The box the shape is drawn in, and its whole geometry — the em box the
  /// `✦` would have occupied at the prototype's `font-size`.
  ///
  /// **The path touches all four edges of it.** See [_StarPainter]: the star's
  /// points are at the midpoints of the four sides, so the painted ink's bounds
  /// *are* this box, and the widget's own test measures that rather than
  /// asserting it — a rendered shape whose geometry is a claim, not a constant.
  final double size;

  /// The shape's ink.
  ///
  /// **A parameter and not `context.colors.ember`,** which is what the private
  /// widget read before this one existed. The selah circle's ink is `ember` and
  /// `/reading`'s bookmark button is a different surface with its own
  /// de-emphasised treatment, so a token baked in here would be a second answer
  /// to a question the call site has already answered. `PassageDropCap`'s doc
  /// makes the same argument for its own `color`.
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StarPainter(color: color),
  );
}

/// The four-pointed star's path, inked in one colour.
///
/// **Private, deliberately.** `CustomPaint` needs a `CustomPainter` and nothing
/// else does, and publishing it would put a second spelling of the shape in the
/// design system's public surface — one a caller could use with a different
/// `waist`, which is the one number this file says is the character at this
/// scale rather than a rotated square.
class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color});

  final Color color;

  /// How far the four concave arcs bow toward the centre, as a fraction of the
  /// box.
  ///
  /// A quarter puts the arc's widest point at the middle of each edge, which is
  /// the proportion the character has: a `✦` is notably slimmer than a rotated
  /// square, and a half would have drawn exactly that.
  static const double waist = 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Every coordinate below is inside `[0, w] × [0, h]` **and** inside the
    // convex hull of the three points each `conicTo` interpolates, so the painted
    // path cannot leave the box however large `size` is. That is a property of
    // the construction rather than of the numbers, which is why the widget's test
    // can assert containment on the rasterised ink and mean it.
    final Path path = Path()
      ..moveTo(w / 2, 0)
      // `conicTo` takes the control point, the end point and a weight; the
      // default weight of 1 gives the gentle concavity the character has, and a
      // heavier one would pull the arcs into a diamond's straight edges.
      ..conicTo(w * (0.5 + waist), h * (0.5 - waist), w, h / 2, 1)
      ..conicTo(w * (0.5 + waist), h * (0.5 + waist), w / 2, h, 1)
      ..conicTo(w * (0.5 - waist), h * (0.5 + waist), 0, h / 2, 1)
      ..conicTo(w * (0.5 - waist), h * (0.5 - waist), w / 2, 0, 1)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Repaint only on a **different ink**.
  ///
  /// The size is not consulted because it is not stored: it arrives as the
  /// `Size` argument to [paint], and a change to it resizes the render box,
  /// which repaints whether this says so or not. So the one thing that can make
  /// this painter's *output* different — the colour — is the one thing that
  /// returns true, and a rebuild with the colour unchanged repaints nothing.
  ///
  /// `oldDelegate.color != color` rather than `!identical(...)`: `build` creates
  /// a fresh `_StarPainter` on every call, so identity is always false and
  /// asserting on it would repaint on every frame of every ambient animation.
  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}
