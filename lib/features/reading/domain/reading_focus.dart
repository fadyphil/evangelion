/// The reader's verse list: when a verse is revealed, when it counts as read,
/// and which of the three paint states it is in.
///
/// AGENT_CONTEXT §6: "if a widget needs a conditional or calculation, extract it
/// to a cubit or a pure function and TDD that." `/reading` has two such
/// calculations and both came out of the prototype as *timed* or *indexed*
/// functions rather than as styles, which is why neither is expressible as a
/// `build` method. They live here.
///
/// ## THE ENTRANCE IS A TIMED STAGGER AND NOT A SCROLL TEST
///
/// This is the single fact most easily transcribed backwards, because the four
/// lines after the stagger are a scroll observer and the two read like one
/// mechanism. They are two. `eva/redesign.html:1377-1384`, `enterReader`:
///
/// ```js
/// // :1382-1383, verbatim
/// if(CALM||reduceMotion){ [...el('verseBox').children].forEach(v=>v.classList.add('in')); finish(); return; }
/// [...el('verseBox').children].forEach((v,i)=>setTimeout(()=>v.classList.add('in'),80+i*25));
/// ```
///
/// Base **80 ms**, step **25 ms**, keyed on the child index — so verse *n*
/// (0-based) is `.in` at `80 + 25n` ms, verse 0 at 80 ms and verse 5 at 205 ms.
/// It applies to **every** verse regardless of scroll position: verse 40 is
/// `.in` at 1080 ms whether or not it has ever been near the fold. A
/// scroll-derived entrance is a *different screen* — under it the passage below
/// the fold is a wall of `opacity:0`, and nothing below the fold ever appears
/// until it is scrolled to.
///
/// `.in` is **never removed** anywhere in the prototype. `renderVerses()`
/// (`:1358`) wipes `box.innerHTML=''`, so the class survives only until the next
/// `enterReader()`. There is no "fade out on scroll past" and no re-entrance.
///
/// ## THE SCROLL OBSERVER DECIDES SOMETHING ELSE ENTIRELY
///
/// `observeVerses()` (`:1209-1221`) is a `new IntersectionObserver(…,
/// {threshold:.6})` — the **only** `IntersectionObserver` and the **only**
/// `threshold` in the file. Its root is not specified, so it is the window
/// viewport, and `rootMargin` is not specified either, so it is `"0px 0px 0px
/// 0px"`. Its callback (`:1212`, `if(!e.isIntersecting) return;`) advances
/// `lastVerse`/`lastRead`, emits **one** star via `addStar(false)`, and then
/// `vObs.unobserve(p)` — one-shot per verse, keyed by `dataset.star`. So its
/// whole job is *bookkeeping*: how far the reader got, and how many stars the
/// sky holds. It never touches a paint property.
///
/// The ratio it tests is the fraction of the **verse's own height** inside the
/// viewport. `intersectionRatio` is the product of the two overlap fractions,
/// and the verses are full-width in a single column (`:159`, `.versebox` is
/// `flex:1;overflow-y:auto`), so the horizontal fraction is always 1.0 and the
/// ratio collapses to the vertical one.
///
/// ## THERE IS NO `.out` CLASS ANYWHERE, AND `.hot` IS THE READER'S
///
/// Measured over the whole file, `classList.(add|remove|toggle)('out')` returns
/// nothing and there is no `.vline.out` rule. The prototype has **no**
/// out-of-view paint state; out-of-view is the *absence* of `.in`, which leaves
/// `:162`'s `opacity:0; transform:translateY(10px); filter:blur(10px)`. That is
/// the state [VersePaint.out] names, and it is why [VerseVisibility] and
/// [VersePaint] are separate types: the prototype computes visibility and never
/// paints from it, so the second is this client's decision and not a
/// transcription.
///
/// `.hot` is the third state and is orthogonal to both: `:165` gives
/// `.vline.hot` a colour, a weight and a glow and **no** opacity, `:1385-1386`
/// removes `hot` from every verse and adds it to the tapped one, and `:1443`
/// adds it to a verse without touching `in`. It is reader-selected, which is
/// exactly why [versePaintFor] takes it as an independent flag instead of
/// deriving it from a scroll position.
///
/// ## AND WHAT THIS FILE OWES FOCUS MODE
///
/// `docs/superpowers/plans/2026-10-13-lumen-redesign.md` (Phase 2 Task 2.2 Step
/// 3, deferred to Task 5.3) requires that focus mode "preserve a ≥3:1
/// distinction between in-view and out-of-view verses, never flatten to a single
/// `#d9dfef`". `eva/redesign.html:177` is that flattening:
///
/// ```css
/// .screen.focus .vline.in{color:#d9dfef}
/// ```
///
/// `focus` is toggled onto `#screen` itself (`:497` puts `.screen` and `id=screen`
/// on one element; `:1290` and `:1292` add and remove `focus` on `el('screen')`),
/// so `.screen.focus` matches and the rule is live at **`(0,4,0)`** — four
/// classes — against `.vline.hot`'s `(0,2,0)` at `:165`. It therefore overrides
/// `.hot`'s colour: a hot verse and a cold one both paint `#d9dfef` while in
/// focus, a measured in-focus distinction of **1.000:1**. The light-mode override
/// that was meant to pair with it (`:80`,
/// `.screen[data-mode=light] .focus .vline.in`) is **dead CSS**: it asks for
/// `.focus` as a *descendant* of `.screen[data-mode=light]`, and `focus` sits on
/// that same element, so it never matches anything.
///
/// This file owes exactly one half of that obligation: that `out`, `in` and
/// `hot` are three states and the paint function never answers `in` for a verse
/// that is not in view. The **colour maths** and the ≥3:1 assertion belong to
/// the widget's test, which already has a contrast-ratio implementation in
/// `test/core/design_system/tokens/text_contrast_gate_test.dart`. A second
/// contrast helper here would be a second implementation of one number, which is
/// the drift this repository rejects wherever it finds one.
///
/// ## AND WHY THERE IS NOT EVEN A `dart:math` IMPORT
///
/// `min` and `max` would read better here, and the purity gate
/// (`tool/verify_purity.sh`, Gate 1) would pass either way. The ternaries are
/// chosen so that "this file imports nothing" is checkable by eye in one pass,
/// which is a stronger property than a gate that has to be re-run to confirm it.
library;

/// The base delay before the **first** verse is revealed. `eva/redesign.html:1383`
/// — `setTimeout(…, 80+i*25)`.
const int _verseEntranceBaseMs = 80;

/// The per-verse step. `eva/redesign.html:1383` — `i*25`, keyed on the child
/// index of `#verseBox`, so verse *n* enters `25n` ms after verse `n-1`.
const int _verseEntranceStepMs = 25;

/// When verse [index] is revealed, counted from `enterReader()`.
///
/// **A timed stagger, not a scroll test** — see the library doc for why that is
/// the fact this file exists to keep straight. This function takes an **index
/// and nothing else**: there is deliberately no position, offset or height
/// parameter, because `:1383` has none. Adding one would be the moment the
/// entrance stops being the prototype's.
///
/// Throws [ArgumentError] on a negative [index]. An ordinal cannot be negative,
/// and the failure this guards against is silent rather than loud: `80 + 25*(-1)`
/// is 55 ms, a *shorter* delay than verse 0's, so a leaked negative index would
/// animate a verse before the passage had begun instead of crashing. Same
/// reasoning as `isValidUserId` (AGENT_CONTEXT recorded decision 15) — a
/// malformed argument is a programmer error and is named at the boundary rather
/// than absorbed into a plausible number.
///
/// This is **not** the login stagger. `eva/redesign.html:1301` uses `i*40` for
/// the wordmark's letters, with no base, and answers reduced motion by zeroing
/// the delay (`reduceMotion?0:i*40`). The reader's is `80+i*25` and answers it
/// by adding `.in` to every verse synchronously instead (`:1382`). Two different
/// mechanisms answering the same accessibility need, so the two constants must
/// not be merged or one of them will start moving.
Duration verseEntranceDelay(int index) {
  if (index < 0) {
    throw ArgumentError.value(
      index,
      'index',
      'a verse index is an ordinal, so it cannot be negative',
    );
  }
  return Duration(
    milliseconds: _verseEntranceBaseMs + _verseEntranceStepMs * index,
  );
}

/// The reveal delay for each of [count] verses, in order.
///
/// The immediate branch is `:1382` transcribed:
///
/// ```js
/// if(CALM||reduceMotion){ [...el('verseBox').children].forEach(v=>v.classList.add('in')); finish(); return; }
/// ```
///
/// — one synchronous pass over every child, then the reader is already looking at
/// the passage. `CALM` (`:913`, toggled at `:1497`) and `reduceMotion` (`:882`,
/// set at `:1490`, auto-set from `prefers-reduced-motion` at `:1530-1532`) both
/// take it. So [immediate] answers every entry with [Duration.zero], and it is
/// the **only** thing that separates the two branches: a screen that honours
/// reduced motion by animating anyway is the defect `:1382` exists to prevent,
/// and it is invisible to a reader who never toggles the setting.
///
/// The count is checked **before** the immediate branch, so a negative [count]
/// fails loudly in both. Short-circuiting first would answer an empty schedule
/// for a count no caller can supply, and `schedule.length == count` would then be
/// a claim nothing could check. [ArgumentError] rather than the `RangeError`
/// `List.generate(-1, …)` throws on its own (measured on Dart 3.13.3) because
/// that message reads like a list bug and never names the parameter.
List<Duration> verseEntranceSchedule({
  required int count,
  required bool immediate,
}) {
  if (count < 0) {
    throw ArgumentError.value(
      count,
      'count',
      'a verse count cannot be negative',
    );
  }
  if (immediate) {
    return List<Duration>.filled(count, Duration.zero);
  }
  return List<Duration>.generate(count, verseEntranceDelay);
}

/// How much of a verse is inside the reader's viewport, and therefore whether
/// it has been read far enough to count.
///
/// `eva/redesign.html:1211-1219`, the observer's own test, reduced to pure
/// arithmetic so a scroll callback does not have to carry it.
///
/// Two boundaries in the prototype are worth stating because neither is
/// obvious. The observer is created with **no `root`**, so its root is the
/// **window** viewport rather than the scrolling `#verseBox` — a verse scrolled
/// above the reader is out of view, not merely past. And it is created with no
/// `rootMargin`, so the inset is `"0px 0px 0px 0px"`, which is why this function
/// takes the viewport edges the caller measured and adds nothing to them.
enum VerseVisibility {
  /// At least [kVerseVisibilityThreshold] of the verse's height is inside the
  /// viewport. `redesign.html:1219` — `threshold:.6`.
  inView,

  /// Less than [kVerseVisibilityThreshold] of it is. Either direction: above the
  /// reader, below the reader, or only a sliver showing.
  outOfView,
}

/// The fraction of a verse's own height that must be inside the viewport.
///
/// `eva/redesign.html:1219` — `{threshold:.6}`. `.6` and not `0.6` in the source;
/// the value is the same and the test pins the decimal this client ships.
///
/// **The threshold is inclusive**, and that is the prototype's side of the line
/// as well as the chosen one. An `IntersectionObserver`'s threshold list is
/// tested with `ratio >= threshold`, so the callback at `:1212` fires *at* .6
/// rather than above it. The independent reason to prefer it is direction: it
/// credits the reader, so a fraction of a pixel of rounding can withhold the star
/// at `:1217` but cannot award it early.
const double kVerseVisibilityThreshold = 0.6;

/// Whether [verseTop]…[verseBottom] is read far enough to count, against the
/// viewport [viewportTop]…[viewportBottom].
///
/// The overlap is `min(verseBottom, viewportBottom) - max(verseTop, viewportTop)`,
/// taken over the verse's own height, because that is what `intersectionRatio`
/// measures for a full-width verse in a single column (see the library doc). The
/// subtraction is clamped at zero so a "visible height" is never a negative
/// number carried into a division.
///
/// **A verse height of zero or less answers [VerseVisibility.outOfView], and this
/// is a decision rather than an accident.** `RenderBox.size` is `Size.zero`
/// before the first layout, so a post-frame measurement really can be asked
/// this. Answering `outOfView` keeps the function **total** — no input makes it
/// throw or return an undefined answer — which matters because it runs inside a
/// scroll callback where an exception is a red screen. The guard is also what
/// stops an inverted rect (`verseBottom < verseTop`, which no laid-out box
/// produces) from reading as the *most* visible thing on the screen: `visible /
/// height` is `1.0` there, because both terms are negative.
VerseVisibility verseVisibilityFor({
  required double verseTop,
  required double verseBottom,
  required double viewportTop,
  required double viewportBottom,
}) {
  final double height = verseBottom - verseTop;
  if (height <= 0) {
    return VerseVisibility.outOfView;
  }
  final double overlapTop = verseTop > viewportTop ? verseTop : viewportTop;
  final double overlapBottom = verseBottom < viewportBottom
      ? verseBottom
      : viewportBottom;
  final double visible = overlapBottom > overlapTop
      ? overlapBottom - overlapTop
      : 0.0;
  return visible / height >= kVerseVisibilityThreshold
      ? VerseVisibility.inView
      : VerseVisibility.outOfView;
}

/// The three ways a verse is drawn, declared in the prototype's own order.
///
/// Not two booleans because the interesting case is the pair that is *not*
/// orthogonal, and two independent flags cannot say "three states" — they can
/// only say "two flags and a bug". See [versePaintFor].
///
/// **`inView` and not `in`: `in` is a reserved word.** `enum VersePaint { in }`
/// does not compile — `Error: 'in' can't be used as an identifier because it's a
/// keyword` — so the member that `:164`'s `.vline.in` describes is spelled
/// [inView]. The name is not arbitrary: it is the same name as the
/// [VerseVisibility] value that produces it, so a mismatched pair is visible in
/// review rather than only in a screenshot, and it keeps the prototype's `in` /
/// `out` vocabulary (`:164`, `:177`) that the plan's focus-mode obligation is
/// itself written in.
enum VersePaint {
  /// The verse is not drawn as revealed: no `.in` (`:161-162`'s `opacity:0;
  /// translateY(10px); blur(10px)`), and outside the viewport.
  ///
  /// **Both** conditions map here, and that is the only place this file exceeds
  /// the prototype: `:162`'s opacity-0 state is the *absence* of a class the
  /// prototype never applies out of view, so "not yet revealed" and "not on
  /// screen" are one visual state but two different facts, and the entrance
  /// clock is the one the prototype actually has.
  out,

  /// `.in` (`:164`) and inside the viewport — the reader can read it now.
  inView,

  /// `.hot` (`:165`): the reader tapped this verse, so it carries the brighter
  /// ink, the heavier weight and the glow. Independent of both above.
  hot,
}

/// The paint state for a verse, from its visibility, whether the reader selected
/// it, and whether its entrance has finished.
///
/// Three decisions, in this order, and the order is the prototype's.
///
/// 1. **[hot] wins outright.** `:1385-1386` — `openSheet` removes `hot` from
///    every `.vline` and adds it to the tapped one — and `:1443` adds `hot` to a
///    verse on its own 460 ms timer without touching `in` at all. `:165`'s rule
///    sets `color`, `font-weight` and `text-shadow` and **no opacity**, so
///    `hot` is a choice about ink and is independent of the reveal. Answering
///    [VersePaint.out] here instead would invent an ordering the prototype does
///    not have.
/// 2. **An unfinished entrance is [VersePaint.out]**, whatever the scroll
///    position says. `:1383` is a timer, and until it fires the verse is still
///    at `:162`'s `opacity:0` even if it is the only verse on screen.
/// 3. **[VerseVisibility] decides between [VersePaint.inView] and
///    [VersePaint.out].** This is the redesign's contribution and not the
///    prototype's, which never paints from visibility at all (see the library
///    doc) — and it is the whole of the focus-mode obligation owed here: a
///    revealed verse that is out of view must be able to look different from one
///    that is in view, because `:177` painted both `#d9dfef` and measured
///    **1.000:1**.
///
/// The three states are load-bearing. If `hot` were mapped onto `inView` the
/// distinction the plan requires would have nothing to be measured against, which
/// is the flattening the redesign is fixing reproduced in a different place.
VersePaint versePaintFor({
  required VerseVisibility visibility,
  required bool hot,
  required bool entranceComplete,
}) {
  if (hot) {
    return VersePaint.hot;
  }
  if (!entranceComplete) {
    return VersePaint.out;
  }
  return switch (visibility) {
    VerseVisibility.inView => VersePaint.inView,
    VerseVisibility.outOfView => VersePaint.out,
  };
}
