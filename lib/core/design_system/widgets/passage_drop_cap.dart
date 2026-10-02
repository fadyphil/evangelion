import 'dart:math' as math;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The oversized opening letter of a passage.
///
/// ## D6 — THERE IS NO PROTOTYPE FOR THIS WIDGET
///
/// `04-widget-inventory.md:32` claims it is "reached through
/// `ScriptureVerse.dropCap`" in `ReadingEnScreen`. **Neither exists.** A search
/// of `eva/src/` for a drop cap returns nothing — the only hits are a pasted-text
/// attachment describing a *different*, discarded design (an oversized Cormorant
/// "I" opening "In the beginning…" in a Home hero that was cut with the library).
/// And `05-domain-model.md` §9.1's `Verse` has no `dropCap` member, so the field
/// the inventory names was invented alongside the widget.
///
/// So there is nothing to be faithful to. What is implemented is the signature
/// the inventory gives, plus the one requirement that is not negotiable:
/// **it must work in both reading directions.** The values below are the
/// prototype's *type scale* — scripture 19px on a 1.8 line height
/// (`03-design-system.md` §5.2 and the pasted-text note) — and the geometry is
/// derived from those.
///
/// Recorded so Phase 7 does not go looking for a prototype that was never built,
/// and so `ScriptureVerse.dropCap` is treated as new work rather than a
/// transcription.
class PassageDropCap extends StatelessWidget {
  /// A drop cap for the first [letter] of a passage.
  const PassageDropCap({
    required this.letter,
    this.direction = TextDirection.ltr,
    this.lines = 3,
    this.color,
    super.key,
  });

  /// The glyph to enlarge. One character; the inventory says `letter`.
  final String letter;

  /// The reading direction of the paragraph this cap opens.
  ///
  /// **A [TextDirection], not the `ScriptureLanguage` the inventory names.** That
  /// enum does not exist yet — it is Phase 7's, in `core/domain/entities/`, and a
  /// design-system widget taking a domain enum would put `core/domain` in the
  /// design system's public surface for one switch. What the widget actually
  /// needs is the direction, and Phase 7 maps `ScriptureLanguage.ar →
  /// TextDirection.rtl` at the call site where the entity is already in hand.
  ///
  /// Defaults to [TextDirection.ltr], which is the inventory's
  /// `language = ScriptureLanguage.en`.
  final TextDirection direction;

  /// How many body lines the cap spans. `3` is the inventory's default and the
  /// pasted-text note's "3-line Cormorant ember drop-cap".
  final int lines;

  /// The cap's ink. Null resolves to [EvaColors.ember] at the call site through
  /// `context.colors`, which is what the note calls it ("ember drop-cap").
  final Color? color;

  /// One body line's height, `19px × 1.8` from the pasted-text note.
  static const double lineHeight = 1.8;

  /// The multiplier from one line's height to the cap's cap-height.
  ///
  /// A serif cap-height is about `0.7` of its em size, and a `lines`-line drop cap
  /// spans `lines × lineHeight × fontSize` of em boxes. So the glyph's em size is
  /// `lines * 1.8 * fontSize / 0.7` of one line — `7.71` lines for a 3-line cap.
  /// Every number in that sentence is a declared constant, so the arithmetic is
  /// checkable rather than folklore.
  static const double capHeightRatio = 0.7;

  /// The glyph's font size for a body style of [bodyFontSize].
  double fontSizeFor(double bodyFontSize) =>
      lines * lineHeight * bodyFontSize / capHeightRatio;

  /// The style the glyph renders in.
  TextStyle capStyle(TextStyle bodyStyle) => bodyStyle.copyWith(
    fontFamily: EvaTypography.scriptureFamily,
    fontSize: fontSizeFor(bodyStyle.fontSize ?? 16),
    fontWeight: FontWeight.w400,
    color: color,
    height: 1,
  );

  /// The inline span to place at the head of a [RichText]'s children.
  ///
  /// ## WHY A `WidgetSpan` AND NOT A BIGGER `Text`
  ///
  /// A drop cap hangs from the first baseline and occupies the first [lines]
  /// lines *of the same paragraph*. There is no way to express that with text
  /// spans: the cap is not a run of text, it is a box whose top aligns with the
  /// paragraph's first line and whose baseline is the paragraph's first
  /// baseline. [WidgetSpan] with [PlaceholderAlignment.baseline] is exactly that,
  /// and `baseline` is mandatory alongside `alignment` — [WidgetSpan] asserts on
  /// the two alone.
  ///
  /// ## THE RTL PART, AND WHICH HALF ACTUALLY DOES THE WORK
  ///
  /// Arabic is right-to-left, so the cap has to sit on the **right** of the
  /// paragraph. Two places carry a direction, and **only one of them is
  /// observable**:
  ///
  /// 1. [paragraph]'s `textDirection` — **this is the half that matters.** A
  ///    `WidgetSpan` placeholder is laid out by the **paragraph's** direction;
  ///    `WidgetSpan` has no direction of its own in this SDK. Drop it and the
  ///    reader gets an LTR paragraph with an RTL-styled cap sitting inside the
  ///    first word.
  /// 2. `Text.textDirection` on the glyph below — **defensive and unobservable.**
  ///    A one-character `Text` lays out identically under either direction, so
  ///    removing this line changes no pixel in any golden. It is kept because an
  ///    implicit `Directionality` lookup from the glyph's own position in the
  ///    tree is a worse dependency than being told, and because
  ///    `TextStyle.direction` cannot be set through `copyWith` in this SDK, so
  ///    `Text` is the only place it can be expressed at all. It is **not** one of
  ///    the two things that "carry" RTL and nothing should be built on it: the
  ///    test that reads it back is a wiring assertion, not a behavioural one.
  ///    [build] is unobservable for the same reason, and says so.
  ///
  /// Getting it wrong silently puts the opening letter of every Arabic passage on
  /// the wrong side of the screen, and nothing throws.
  InlineSpan span(TextStyle bodyStyle) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Text(
      letter,
      style: capStyle(bodyStyle),
      // `Text.textDirection`, not `TextStyle.direction`: `TextStyle` *has* a
      // direction field and `copyWith` does **not** accept it in this SDK, so
      // the only way to set a direction on a run of text is to hand it to the
      // `Text` itself. Defensive — see the class doc's second bullet, which says
      // plainly that this half cannot move a pixel and `paragraph` is what does.
      textDirection: direction,
    ),
  );

  /// The opening paragraph: this cap followed by [rest].
  ///
  /// The call site Phase 7 wants. Handing back a bare [span] would leave the
  /// paragraph's direction to every caller, which is exactly the mistake the
  /// second half of the [span] doc describes; returning the whole paragraph makes
  /// the correct thing the easy thing.
  ///
  /// [textScaler] is passed through rather than read, so the paragraph composes
  /// with the reader's `evaScalerFor` preference instead of silently resetting
  /// it — §14 requires the app to scale to 1.22x without overflowing, and a
  /// drop cap is the first thing that would overflow.
  RichText paragraph({
    required String rest,
    required TextStyle bodyStyle,
    TextScaler textScaler = TextScaler.noScaling,
    TextAlign textAlign = TextAlign.start,
  }) => RichText(
    text: TextSpan(
      children: <InlineSpan>[
        span(bodyStyle),
        TextSpan(text: rest, style: bodyStyle),
      ],
    ),
    textDirection: direction,
    textScaler: textScaler,
    textAlign: textAlign,
  );

  /// The cap on its own, for a golden and for measuring it.
  ///
  /// The real use is [span] and [paragraph]; this is the same glyph in the same
  /// geometry with nothing after it.
  ///
  /// ## AND WHY [direction] IS *ALSO* UNOBSERVABLE HERE
  ///
  /// `textDirection` is passed down because it is the correct thing to pass, and
  /// because a `RichText` that had to fall back to the ambient `Directionality`
  /// would be at the mercy of wherever it happened to be mounted. It is **not**
  /// doing visible work in this method, and that is measured rather than
  /// assumed:
  ///
  /// a `RichText` sizes itself to its content, and here the content is a single
  /// glyph — so the render box and the glyph occupy the *same* rect, and a box
  /// with nothing beside it has no leading or trailing edge to align against.
  /// With `letter: 'ا'` both directions produce
  /// `Rect.fromLTRB(363.4, 226.5, 436.6, 373.5)` in the test harness, and
  /// hard-wiring this to `ltr` leaves every golden green.
  ///
  /// So the observable RTL guarantee lives entirely in [paragraph] — which
  /// `passage_drop_cap_test.dart`'s "the cap opens the paragraph on the leading
  /// side" covers — and nothing here should be built on the assumption that the
  /// bare cap moves. The value stays because it becomes observable the moment
  /// anything is placed after the cap.
  @override
  Widget build(BuildContext context) {
    final TextStyle bodyStyle = DefaultTextStyle.of(context).style;
    return RichText(
      text: TextSpan(children: <InlineSpan>[span(bodyStyle)]),
      textDirection: direction,
    );
  }

  /// The width the cap's box occupies, in logical px.
  ///
  /// Published because a caller laying out a paragraph beside the cap needs it,
  /// and because "how wide is a drop cap" is otherwise a thing every caller
  /// re-derives from the font.
  double widthFor(double bodyFontSize) =>
      fontSizeFor(bodyFontSize) * 0.5 * math.max(1, letter.length);
}
