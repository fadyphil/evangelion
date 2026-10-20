import 'dart:math' as math;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The oversized opening letter of a passage.
///
/// ## D6 — "NO PROTOTYPE", WHICH WAS TRUE OF `eva/src/` AND FALSE OF `redesign.html`
///
/// **This doc used to say there was not, and that was true of `eva/src/` and
/// false of the prototype this client is now built from.** `eva/src/` is the
/// React app the Phase-3 inventory describes, and a search of it for a drop cap
/// returns nothing — the only hits are a pasted-text attachment describing a
/// *different*, discarded design (an oversized Cormorant "I" opening "In the
/// beginning…" in a Home hero that was cut with the library), and
/// `05-domain-model.md` §9.1's `Verse` has no `dropCap` member, so the field the
/// inventory names was invented alongside the widget.
///
/// **`eva/redesign.html` has one.** `redesign.html:172` is the whole of it:
///
/// ```css
/// .vline.drop::first-letter{font-family:var(--scr);font-size:56px;float:left;
///   line-height:.82;padding:6px 10px 0 0;color:var(--gold);
///   text-shadow:0 0 26px rgba(232,176,75,.6)}
/// ```
///
/// and `redesign.html:141` is the other half of it —
/// `[dir=rtl] .vline.drop::first-letter{all:unset}` — the Arabic arm.
///
/// So the widget is no longer new work with a borrowed type scale. It is a
/// transcription of one CSS rule, and this file says which halves of that rule
/// shipped and which did not rather than leaving the reader to infer it from a
/// doc that claimed there was nothing to transcribe.
///
/// ## WHAT `:172` GAVE THIS WIDGET
///
/// | `:172` | here | |
/// | --- | --- | --- |
/// | `text-shadow: 0 0 26px rgba(232,176,75,.6)` | [capShadow] | **adopted** |
/// | `color: var(--gold)` | [color] | **adopted**, with Decision 153's split applied by the two call sites |
/// | `font-family: var(--scr)` | [EvaTypography.scriptureFamily] | already in place |
/// | `float: left` | [PlaceholderAlignment.baseline] + [paragraph]'s `textDirection` | already in place, and the reason it is [paragraph] and not a `Text` |
/// | `font-size: 56px` | derived from `19 × 3 × 1.8 / 0.7` | **not adopted** — see below |
/// | `line-height: .82` | [PassageDropCap.lineHeight] = `1.8`, the *body*'s | **not adopted** — the same reason |
/// | `padding: 6px 10px 0 0` | [widthFor]'s `0.5 ×` glyph-width estimate | not adopted |
///
/// ## THE SIZE IS **NOT** `:172`'s, AND THAT IS A PHASE 5.3 DECISION
///
/// `:172` wants 56px at `line-height: .82`, which is a cap spanning `56 × 0.82
/// ≈ 46px` of ink against a body whose own line box this client does not know.
/// This widget derives its size from its **body**: `lines × lineHeight ×
/// bodyFontSize / capHeightRatio`, so a 3-line cap over a 19px body on a 1.8 line
/// height is `146.57px`. That is a ratio (3 body lines), and a ratio is the right
/// thing for a widget that does not own the paragraph; 56 is an absolute
/// transcribed from one screen's one rule.
///
/// **Tuning the ratio means re-reading it on a screen.** `/reading` does not
/// exist in the redesign — there is no `.vline` anywhere in `redesign.html` — so
/// changing the multiplier here would be tuning against a screen that has not
/// been built and cannot be measured. Phase 5.3 owns it. `reading_page_test.dart`
/// prints `fontSizeFor(17)` into its own failure messages, so the number this
/// produces is visible wherever it matters.
///
/// ## RTL IS NOT REMOVED, AND THAT IS ALSO PHASE 5.3'S
///
/// `redesign.html:141` does not mirror the cap under `[dir=rtl]` — it **removes
/// it**, `all: unset`. This widget mirrors instead: [span] hands the glyph a
/// [TextDirection], [paragraph] hands the paragraph the same one, and a reader
/// gets an oversized opening letter on the right of an Arabic passage.
///
/// **Removing a capability is a behaviour change, and this batch is scoped to
/// paint.** Two arguments for keeping it, both load-bearing rather than
/// sentimental:
///
/// - The deleted `today_reading_panel.dart` reached [paragraph] only on the
///   **English** arm — the Arabic arm rendered its preview whole — so `:141`
///   described a screen that did not exist in this client even then, exactly
///   like `:172`'s font size. Phase 5.2 deleted the panel with the preview
///   (`docs/adr/0022…`: the redesigned `/` shows the day's first verse whole),
///   and the surviving scripture caller is the one `:141` was always written
///   against.
/// - Unsetting a drop cap in Arabic is not a restyle, it is a typographic
///   decision about a right-to-left scripture tradition that this widget does not
///   own and that no document here has taken.
///
/// So `:141` is recorded, cited, and not implemented. What the widget keeps is a
/// capability; what `:141` would take away is not a paint.
///
/// ## THE INK IS `emberInk`, NOT `ember`, AND THAT IS DECISION 153
///
/// `:172` writes `color: var(--gold)` — gold, one name, no split. **This client
/// has two names for that role**: `ember` **fills** and `emberInk` **writes**
/// (decision 153). A 56px letter is *text* at every size WCAG recognises, so it is
/// the writing half, and on the light palette the two differ by a factor of four
/// in luminance (`#845610` against `#D4891A`).
///
/// [color] stays a nullable pass-through rather than gaining a default, because
/// the widget is handed the ink by the call site that owns it —
/// `scripture_block.dart`, which already passes `colors.emberInk` — and a default
/// here would be a second answer to a question the caller has already answered.
/// (`today_reading_panel.dart` was the second; Phase 5.2 deleted it with the
/// preview, which is why "two call sites" reads as one.) `null` inherits the body style,
/// which is what the tests below pin.
class PassageDropCap extends StatelessWidget {
  /// A drop cap for the first [letter] of a passage.
  const PassageDropCap({
    required this.letter,
    this.direction = TextDirection.ltr,
    this.lines = 3,
    this.color,
    this.fontSize,
    super.key,
  });

  /// The glyph to enlarge. One character; the inventory says `letter`.
  final String letter;

  /// The reading direction of the paragraph this cap opens.
  ///
  /// **A [TextDirection], not the `ReadingLanguage` the inventory names.** The
  /// inventory's `ScriptureLanguage` was never built under that name: the entity
  /// that exists is `ReadingLanguage` (`core/domain/entities/reading_language.dart`),
  /// and it is **pure Dart** — a `Locale` would put `dart:ui` in the shared
  /// kernel. What the widget actually needs is the **direction**, and taking the
  /// entity instead would put `core/domain` in the design system's public
  /// surface for one switch.
  ///
  /// Defaults to [TextDirection.ltr], which is the inventory's
  /// `language = ScriptureLanguage.en`.
  final TextDirection direction;

  /// How many body lines the cap spans. `3` is the inventory's default and the
  /// pasted-text note's "3-line Cormorant ember drop-cap".
  final int lines;

  /// The cap's ink. Null inherits the body style's colour.
  ///
  /// **`:172` writes `color: var(--gold)`; both call sites pass
  /// `colors.emberInk`.** See the class doc's Decision 153 note: gold fills and
  /// `emberInk` writes, a 56px letter is text, and the light palette measures
  /// `#D4891A` at 2.0:1 against the pale surfaces around it.
  final Color? color;

  /// The glyph's own em size, when the prototype states one. `null` means the
  /// [lines]-line ratio of [fontSizeFor].
  ///
  /// ## WHY THE REDESIGN NEEDS IT, AND WHY IT IS NOT THE SAME THING AS `lines`
  ///
  /// `redesign.html:172` writes the cap as a CSS **first-letter**:
  /// `font-size: 56px; float: left; line-height: .82` — a fixed 56px letter
  /// floated at the head of the first paragraph. The ratio in [fontSizeFor] is
  /// the *other* shape: an N-line cap whose size follows the body. **No integer
  /// `lines` reaches 56 at this screen's 20px body**, and the two nearest
  /// answers are far enough apart that either one is a visible miss:
  ///
  /// | `lines` | `fontSizeFor(20)` | against the prototype's 56 |
  /// | --- | --- | --- |
  /// | 1 | **51.43** | −4.57 (−8 %) |
  /// | 2 | **102.86** | +46.86 (+84 %) |
  ///
  /// So a caller that transcribes the prototype passes `fontSize: 56` and the
  /// ratio does not run at all. The default stays the ratio: the callers that
  /// predate the redesign — `/`'s preview and the old `/reading` block — were
  /// built against a prototype whose cap was **82px against a 19px body**, which
  /// the ratio reaches at `lines: 3` to within a percent, and
  /// `passage_drop_cap_test.dart` pins that arithmetic. Both answers are right
  /// for their own prototype; this parameter is what lets one widget carry both.
  ///
  /// **What it does not fix**, and the reason the caption is transcribed rather
  /// than the layout: CSS's `float: left` wraps text around a box; a
  /// [WidgetSpan] hangs from the first baseline with no float. `height: 1` in
  /// [capStyle] means the span's box is one em tall — 56px against a 34px line
  /// (`20 × 1.7`, `:161`), so the cap covers the first line and about two thirds
  /// of the second, where the prototype's `.82` line box over a 56px font gives
  /// 45.92px, or one line and 35 % of the second. **The sizes are transcribed;
  /// the wrap is Flutter's**, and a reader comparing the two sees a cap of the
  /// right size sitting slightly lower than the browser's.
  final double? fontSize;

  /// `redesign.html:172`'s halo — `text-shadow: 0 0 26px rgba(232,176,75,.6)`.
  ///
  /// ## WHY [EvaColors.dark] AND NOT THE AMBIENT PALETTE
  ///
  /// `:172` writes `color: var(--gold)`, and `redesign.html:76` overrides
  /// **only the colour** in light mode —
  /// `.screen[data-mode=light] .vline.drop::first-letter{color:#9A7B19}`.
  /// **Nothing overrides the `text-shadow`.** So `rgba(232,176,75,.6)` is the
  /// same value on both, and `#E8B04B` is [EvaColors.dark]'s `ember`.
  ///
  /// That makes this one of the few places in the design system where reading a
  /// dark token is the faithful transcription rather than a shortcut: the halo is
  /// a constant the prototype never re-hued. Naming `EvaColors.dark()` says
  /// *that*; writing `colors.ember` would say *whatever this screen's palette
  /// is*, and in light mode it would silently be a different colour from the
  /// one the prototype draws. The shadow is light in both modes by design — a
  /// dark halo behind `#9A7B19` would read as a smudge, which is presumably why
  /// `:76` re-hued the letter and left this alone.
  ///
  /// A [Shadow] rather than a `BoxShadow`: the rule is a **text**-shadow, so it
  /// belongs to the run of text, scales with the glyph's em box and follows the
  /// glyph's own outline. A box shadow around the [Text] widget would be a
  /// rectangle's worth of blur on the wrong side of every stroke.
  ///
  /// `static final`, not `const`, because [Color.withValues] is not a const
  /// constructor in this SDK — the values are fixed, the *spelling* is not.
  static final List<Shadow> capShadow = <Shadow>[
    Shadow(
      color: const EvaColors.dark().ember.withValues(alpha: capShadowAlpha),
      blurRadius: capShadowBlur,
    ),
  ];

  /// One body line's height, `19px × 1.8` from the pasted-text note.
  ///
  /// **Not `:172`'s `line-height: .82`.** That is the *cap's* line height inside
  /// CSS's `float` box, and this constant is the **body's** — the one the cap has
  /// to divide. See the class doc.
  static const double lineHeight = 1.8;

  /// `redesign.html:172`'s `text-shadow` radius, `0 0 26px`.
  static const double capShadowBlur = 26;

  /// `redesign.html:172`'s shadow alpha, `rgba(232,176,75,.6)`.
  static const double capShadowAlpha = 0.6;

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
    // `fontSize` wins when the prototype states one — see its doc for why the
    // ratio cannot produce `:172`'s 56 at any integer `lines`.
    fontSize: fontSize ?? fontSizeFor(bodyStyle.fontSize ?? 16),
    fontWeight: FontWeight.w400,
    color: color,
    // `redesign.html:172` — the only thing this file takes from that rule. See
    // [capShadow] for why the halo is a constant of the rule rather than a
    // per-brightness colour.
    shadows: capShadow,
    // `height: 1` and not `:172`'s `line-height: .82`: the cap is a
    // [WidgetSpan] hung on the paragraph's first baseline, so it has no line box
    // of its own to lead with. See the class doc on the size.
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
