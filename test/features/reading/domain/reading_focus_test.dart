import 'package:evangelion/features/reading/domain/reading_focus.dart';
import 'package:flutter_test/flutter_test.dart';

/// [verseEntranceDelay], [verseEntranceSchedule], [verseVisibilityFor] and
/// [versePaintFor] — red-first, because AGENT_CONTEXT §6 says domain logic is
/// TDD'd rather than buried in a widget, and this is the reader's verse list's
/// logic: the entrance schedule and the in-view test.
///
/// ## WHAT THIS SUITE EXISTS TO STOP
///
/// **The entrance is a TIMED STAGGER and not a scroll test.** That is the one fact
/// most likely to be transcribed backwards, because the next four lines of the
/// prototype are a scroll observer and the two read like one mechanism. They are
/// not, and this file's first group is the claim that they are separate.
///
/// The obvious wrong implementation — "a verse fades in when it is 60 % in view"
/// — is not a variant of the prototype, it is a different screen: under it verse
/// 40 never fades in until the reader scrolls to it, and the passage below the
/// fold is a wall of `opacity:0`. `:1383` puts `.in` on **every** child of
/// `#verseBox` on a timer regardless of where it sits.
///
/// ## AND WHY THREE OF THE ASSERTIONS ARE COUNTER-INTUITIVE
///
/// * **`out` is not a class.** `grep` over `eva/redesign.html` for
///   `classList.(add|remove|toggle)('out')` returns nothing and there is no
///   `.vline.out` rule, so the prototype has no out-of-view paint at all. The
///   out-of-view appearance is the **absence** of `.in` (`:161-162`:
///   `opacity:0;transform:translateY(10px);filter:blur(10px)`). `VersePaint.out`
///   is this file's name for that absence, and the redesign's — see the focus
///   obligation below — is a *distinguishable* one.
/// * **`hot` is reader-selected, not scroll-derived.** `:1385-1386` removes `hot`
///   from every verse and adds it to the one that was tapped; `:1443` adds `hot`
///   to a verse without touching `in`. It is orthogonal to both other states, and
///   that is exactly why [versePaintFor] takes it as an independent flag rather
///   than deriving it from visibility.
/// * **The entrance survives its own scroll.** `.in` is never removed anywhere in
///   the prototype; `renderVerses()` (`:1358`) wipes `box.innerHTML=''`, so the
///   class survives only until the next `enterReader()`.
///
/// ## THE FOCUS-MODE OBLIGATION THIS FILE DOES **NOT** SETTLE
///
/// The plan (Phase 2 Task 2.2 Step 3, deferred to Task 5.3) requires focus mode to
/// "preserve a ≥3:1 distinction between in-view and out-of-view verses, never
/// flatten to a single `#d9dfef`". `redesign.html:177`
/// (`.screen.focus .vline.in{color:#d9dfef}`) is that flattening, at `(0,4,0)`
/// specificity, so it beats `.vline.hot`'s colour and paints a hot verse and a
/// cold one identically — a measured in-focus distinction of **1.000:1**.
///
/// This file owes exactly one half of that: that `out`, `in` and `hot` are three
/// states and the function never answers `in` for a verse that is not in view.
/// The **colour** maths and the ≥3:1 ratio belong to the widget's own test, which
/// already owns a contrast-ratio implementation in
/// `test/core/design_system/tokens/text_contrast_gate_test.dart`. A second
/// contrast helper here would be the two-implementations-of-one-number drift this
/// repository rejects wherever it finds one.
///
/// ## AND ONE MEMBER IS SPELLED `VersePaint.inView`, NOT `VersePaint.in`
///
/// `in` is a **Dart reserved word**. `enum VersePaint { out, in, hot }` does not
/// compile — `Error: 'in' can't be used as an identifier because it's a keyword`
/// — so the member standing for `redesign.html:164`'s `.vline.in` is
/// [VersePaint.inView]. This was found by writing the suite against the name the
/// brief specified and watching it fail to compile; it is a forced deviation, not
/// a preference. The substitute is the same word as the [VerseVisibility] value
/// that produces it, so a mismatched pair is visible in review. The two
/// enums' *other* members, and every other name in the API, are unchanged.
void main() {
  group('the entrance stagger — `:1383`, `80+i*25`', () {
    test('verse 0 enters at 80ms — the base delay, with nothing added', () {
      expect(verseEntranceDelay(0), const Duration(milliseconds: 80));
    });

    test('verse 1 is 25ms later, so 105ms', () {
      expect(verseEntranceDelay(1), const Duration(milliseconds: 105));
    });

    test('verse 5 is 205ms, which is the fifth step and not the fifth', () {
      // The distinction is the whole formula: `80 + 25n` gives 205 at n=5, while
      // `n*25` alone would give 125. A stagger transcribed as a plain multiple
      // silently drops the base, which moves the entire entrance 80ms earlier and
      // looks like nothing at all in a screenshot.
      expect(verseEntranceDelay(5), const Duration(milliseconds: 205));
    });

    test('and the schedule for six verses is that formula, verse by verse', () {
      // An explicit table rather than `expect(schedule, List.generate(...))`:
      // the latter is the implementation re-expressed, and would stay green if the
      // formula were wrong in both places at once.
      expect(
        verseEntranceSchedule(count: 6, immediate: false),
        const <Duration>[
          Duration(milliseconds: 80),
          Duration(milliseconds: 105),
          Duration(milliseconds: 130),
          Duration(milliseconds: 155),
          Duration(milliseconds: 180),
          Duration(milliseconds: 205),
        ],
      );
    });

    test('the schedule has exactly one entry per verse, at every count', () {
      // The schedule and `count` are two arguments to one call, so a length that
      // drifts from `count` is the failure mode a caller cannot see: the widget
      // indexes the list per verse and a short list reads past its end or shows no
      // animation for the tail.
      for (final int count in const <int>[0, 1, 2, 5, 6, 41, 120]) {
        expect(
          verseEntranceSchedule(count: count, immediate: false),
          hasLength(count),
          reason: 'a $count-verse passage must schedule $count entrances',
        );
        expect(
          verseEntranceSchedule(count: count, immediate: true),
          hasLength(count),
          reason:
              'the immediate branch short-circuits the reveal, not the count',
        );
      }
    });

    test('the last of forty-one verses enters at 1080ms — the stagger has no '
        'scroll term', () {
      // This row is the fact that separates the entrance from the observer. There
      // is no position argument on `verseEntranceDelay` and no position argument
      // on the schedule: verse 40 is `.in` at 1080ms whether it was below the
      // fold, off-screen, or never scrolled to at all, exactly as `:1383` adds
      // the class to every child of `#verseBox`.
      final List<Duration> schedule = verseEntranceSchedule(
        count: 41,
        immediate: false,
      );
      expect(schedule.last, const Duration(milliseconds: 1080));
      expect(schedule.last, isNot(equals(schedule.first)));
    });

    test('and it is strictly increasing, so no two verses enter together', () {
      final List<Duration> schedule = verseEntranceSchedule(
        count: 64,
        immediate: false,
      );
      for (int i = 1; i < schedule.length; i++) {
        expect(
          schedule[i],
          greaterThan(schedule[i - 1]),
          reason: 'verse $i must not share its entrance with verse ${i - 1}',
        );
      }
    });

    test('a negative index throws, naming the value it was given', () {
      // An ordinal is non-negative by definition, and the failure this prevents is
      // silent rather than loud: `80 + 25*(-1)` is 55ms, a *shorter* delay than
      // verse 0's, so a leaked negative index animates a verse before the passage
      // has begun instead of crashing. The same reasoning as
      // `isValidUserId` (AGENT_CONTEXT decision 15) — a malformed argument is a
      // programmer error and is named at the boundary rather than absorbed.
      expect(
        () => verseEntranceDelay(-1),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.toString(),
            'toString',
            allOf(contains('index'), contains('-1')),
          ),
        ),
      );
      expect(() => verseEntranceDelay(-1), throwsArgumentError);
    });
  });

  group('the immediate branch — `:1382`, calm motion and reduced motion', () {
    test('every entry is Duration.zero, so the reveal is synchronous', () {
      // `:1382` is `if(CALM||reduceMotion){ …forEach(v=>v.classList.add('in'));
      // finish(); return; }` — one synchronous pass, then the reader is already
      // looking at the passage. `CALM` (`:913`, toggled at `:1497`) and
      // `reduceMotion` (`:882`, set at `:1490`, auto-set from
      // `prefers-reduced-motion` at `:1530-1532`) both take it.
      final List<Duration> schedule = verseEntranceSchedule(
        count: 8,
        immediate: true,
      );
      expect(schedule, hasLength(8));
      expect(schedule, everyElement(equals(Duration.zero)));
    });

    test('and it is NOT the timed stagger wearing a zero label', () {
      // The branch that matters. A screen that honours reduced motion by animating
      // anyway is the defect `:1382` exists to prevent, and it is invisible to a
      // reader who never toggles the setting — so the claim is pinned by *contrast*
      // with the other branch, not by asserting `Duration.zero` alone (which a
      // schedule that is always zero would also satisfy).
      final List<Duration> immediate = verseEntranceSchedule(
        count: 8,
        immediate: true,
      );
      final List<Duration> timed = verseEntranceSchedule(
        count: 8,
        immediate: false,
      );
      expect(immediate, isNot(equals(timed)));
      expect(immediate.first, isNot(equals(verseEntranceDelay(0))));
      expect(immediate.first, isNot(equals(timed.first)));
    });

    test('the immediate branch zeroes even verse 0, which the stagger delays', () {
      // The one entry where the two branches could be confused: `i*25` is 0 at
      // `i=0`, so a stagger transcribed without its base would be *already
      // synchronous at verse 0* and this comparison would be vacuous. Here the
      // stagger says 80ms and the immediate branch says zero.
      expect(verseEntranceDelay(0), isNot(equals(Duration.zero)));
      expect(verseEntranceSchedule(count: 1, immediate: true), <Duration>[
        Duration.zero,
      ]);
    });

    test('zero verses schedules nothing, in either branch', () {
      expect(verseEntranceSchedule(count: 0, immediate: true), isEmpty);
      expect(verseEntranceSchedule(count: 0, immediate: false), isEmpty);
    });

    test('a negative count throws, naming `count`', () {
      // Loud, in BOTH branches. Had the immediate branch short-circuited before
      // touching the count it would answer an empty schedule for a negative count,
      // and `hasLength(count)` on a `count` no caller can supply would be a claim
      // nothing could check.
      expect(
        () => verseEntranceSchedule(count: -1, immediate: false),
        throwsArgumentError,
      );
      expect(
        () => verseEntranceSchedule(count: -1, immediate: true),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.toString(),
            'toString',
            allOf(contains('count'), contains('-1')),
          ),
        ),
      );
    });
  });

  group('the visibility arithmetic — `:1219`, `threshold:.6`', () {
    // The viewport is 0..100 for every row unless the row says otherwise, and the
    // ratio is the fraction of the **verse's own height** inside it — which is
    // what IntersectionObserver measures, because the verses are full-width and
    // laid out in a single column, so the horizontal overlap is always 1.0 and
    // the rect-intersection ratio collapses to the vertical fraction.
    test('the threshold is the prototype\'s .6, not a rounder neighbour', () {
      expect(kVerseVisibilityThreshold, 0.6);
    });

    test('a verse entirely inside is in view', () {
      expect(
        verseVisibilityFor(
          verseTop: 10,
          verseBottom: 50,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.inView,
      );
    });

    test('a verse entirely above the viewport is out of view', () {
      // Direction matters and is asserted separately because the prototype's root
      // is the **window** (`:1211` names neither `root` nor `rootMargin`, so both
      // default: the document viewport and `"0px 0px 0px 0px"`). A reader who
      // opens `/reading` scrolled down, or who scrolls up past the first verse,
      // has verses above the viewport, and a one-sided test would pass on an
      // implementation that only ever compares the bottom edge.
      expect(
        verseVisibilityFor(
          verseTop: -60,
          verseBottom: -10,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.outOfView,
      );
    });

    test('a verse entirely below the viewport is out of view', () {
      expect(
        verseVisibilityFor(
          verseTop: 200,
          verseBottom: 260,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.outOfView,
      );
    });

    test('a verse flush with the top edge is fully in view', () {
      // The boundary rows are the ones that decide whether the arithmetic uses `>`
      // or `>=`, and a clip is not out of view.
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 60,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.inView,
      );
    });

    test('a verse flush with the bottom edge is fully in view', () {
      expect(
        verseVisibilityFor(
          verseTop: 40,
          verseBottom: 100,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.inView,
      );
    });

    test('sixty per cent exactly is IN view — the threshold is inclusive', () {
      // 60 of a 100-tall verse inside a 0..60 viewport. Inclusive is the
      // prototype's side of the line and the deliberate one: an
      // IntersectionObserver's threshold list is tested with `ratio >=
      // threshold`, so the callback at `:1212` fires **at** .6 and not above it.
      // Two reasons that direction, only the first of which is about fidelity —
      // it is the side that **credits** the reader, so a rounding wobble of a
      // fraction of a pixel can withhold a star but cannot award one early.
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 100,
          viewportTop: 0,
          viewportBottom: 60,
        ),
        VerseVisibility.inView,
      );
    });

    test(
      'fifty-nine per cent is out of view, so the line is not "most of it"',
      () {
        expect(
          verseVisibilityFor(
            verseTop: 0,
            verseBottom: 100,
            viewportTop: 0,
            viewportBottom: 59,
          ),
          VerseVisibility.outOfView,
        );
      },
    );

    test('sixty-one per cent is in view, so the line is not "all of it"', () {
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 100,
          viewportTop: 0,
          viewportBottom: 61,
        ),
        VerseVisibility.inView,
      );
    });

    test('a third in view is out of view', () {
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 100,
          viewportTop: 0,
          viewportBottom: 30,
        ),
        VerseVisibility.outOfView,
      );
    });

    test('a verse straddling both edges at once is in view on the overlap', () {
      // Ten of it is above the viewport and ten below; the overlap is 90 of 100.
      // An implementation that short-circuits on either edge without taking the
      // intersection gets this wrong, and it is the common geometry when a verse
      // is longer than the fold.
      expect(
        verseVisibilityFor(
          verseTop: -10,
          verseBottom: 90,
          viewportTop: -10,
          viewportBottom: 90,
        ),
        VerseVisibility.inView,
      );
    });

    test('a verse TALLER than the viewport can never be in view', () {
      // The real state for a long verse on a short surface: a 1000-tall verse in
      // a 500-tall viewport peaks at 0.5 and no amount of scrolling reaches 0.6.
      // This is the row that says a verse can be permanently unreadable by the
      // observer, and the reason the one-shot star at `:1217` is a best-effort
      // affordance rather than a guarantee that every verse can be counted.
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 1000,
          viewportTop: 0,
          viewportBottom: 500,
        ),
        VerseVisibility.outOfView,
      );
      expect(
        verseVisibilityFor(
          verseTop: 0,
          verseBottom: 1000,
          viewportTop: 0,
          viewportBottom: 1000,
        ),
        VerseVisibility.inView,
      );
    });

    test(
      'a viewport taller than the verse decides nothing about the verse',
      () {
        // Same three numbers read through two viewports: the function answers about
        // the verse, not about the surface it happens to be on.
        expect(
          verseVisibilityFor(
            verseTop: 0,
            verseBottom: 20,
            viewportTop: 0,
            viewportBottom: 20,
          ),
          verseVisibilityFor(
            verseTop: 0,
            verseBottom: 20,
            viewportTop: 0,
            viewportBottom: 4000,
          ),
        );
      },
    );

    test('an inverted rect is out of view rather than a full pass', () {
      // `verseBottom < verseTop` cannot come from a laid-out `RenderBox`, but it
      // costs one comparison not to divide a negative height: `visible / height`
      // is 1.0 for an inverted rect (both terms negative), so without the guard
      // an unmeasurable verse reads as the most-visible thing on the screen.
      expect(
        verseVisibilityFor(
          verseTop: 100,
          verseBottom: 0,
          viewportTop: 0,
          viewportBottom: 200,
        ),
        VerseVisibility.outOfView,
      );
    });

    test('a zero-height verse is out of view, not an undefined ratio', () {
      // `RenderBox.size` is `Size.zero` before the first layout, so a post-frame
      // measurement taken on an early frame really can be asked this. Answering
      // `outOfView` keeps the function **total** — it has no input for which it
      // throws or returns something meaningless, which matters because it runs
      // inside a scroll callback where an exception is a red screen.
      expect(
        verseVisibilityFor(
          verseTop: 50,
          verseBottom: 50,
          viewportTop: 0,
          viewportBottom: 100,
        ),
        VerseVisibility.outOfView,
      );
    });

    test(
      'the two enum states are the only ones, so a `switch` stays exhaustive',
      () {
        expect(VerseVisibility.values, <VerseVisibility>[
          VerseVisibility.inView,
          VerseVisibility.outOfView,
        ]);
      },
    );
  });

  group('the paint decision', () {
    // The full input space, enumerated: two visibilities x hot x entrance. A table
    // rather than a handful of examples, because the failure this file exists to
    // prevent is a *wrong answer for a combination nobody thought to try*.
    test('every combination of the three inputs, and what it must answer', () {
      const List<(VerseVisibility, bool, bool, VersePaint)>
      table = <(VerseVisibility, bool, bool, VersePaint)>[
        // Not yet revealed: the entrance clock at `:1383` has not fired, so the
        // verse is still at `:161-162`'s `opacity:0; translateY(10px); blur(10px)`
        // whatever the scroll position says.
        (VerseVisibility.inView, false, false, VersePaint.out),
        (VerseVisibility.outOfView, false, false, VersePaint.out),
        // Revealed and in view.
        (VerseVisibility.inView, false, true, VersePaint.inView),
        // Revealed and out of view. **This row is the focus-mode obligation**:
        // `.screen.focus .vline.in` (`:177`) painted one `#d9dfef` for everything
        // revealed, which is the 1.000:1 flattening the plan forbids.
        (VerseVisibility.outOfView, false, true, VersePaint.out),
        // Hot wins over both, in view or not, entrance complete or not.
        (VerseVisibility.inView, true, false, VersePaint.hot),
        (VerseVisibility.inView, true, true, VersePaint.hot),
        (VerseVisibility.outOfView, true, false, VersePaint.hot),
        (VerseVisibility.outOfView, true, true, VersePaint.hot),
      ];

      expect(table, hasLength(8), reason: 'two visibilities x hot x entrance');

      for (final (VerseVisibility, bool, bool, VersePaint) row in table) {
        expect(
          versePaintFor(
            visibility: row.$1,
            hot: row.$2,
            entranceComplete: row.$3,
          ),
          row.$4,
          reason:
              'visibility=${row.$1.name}, hot=${row.$2}, '
              'entranceComplete=${row.$3}',
        );
      }
    });

    test('the input space reaches exactly three states', () {
      // The collapse this file exists to prevent: if `hot` were mapped onto `in`,
      // this set would collapse to two and the plan's ≥3:1 distinction would have
      // no second state to be measured against. The row above catches the wrong
      // answer; this one catches the enum being narrowed to match.
      final Set<VersePaint> reached = <VersePaint>{};
      for (final VerseVisibility visibility in VerseVisibility.values) {
        for (final bool hot in const <bool>[false, true]) {
          for (final bool entranceComplete in const <bool>[false, true]) {
            reached.add(
              versePaintFor(
                visibility: visibility,
                hot: hot,
                entranceComplete: entranceComplete,
              ),
            );
          }
        }
      }
      expect(reached, <VersePaint>{
        VersePaint.out,
        VersePaint.inView,
        VersePaint.hot,
      });
    });

    test('a revealed verse that is in view is never `out`', () {
      // Stated on its own because it is the property the focus-mode distinction
      // rests on: with the entrance finished and the verse in view, there is no
      // combination of arguments left that may answer `out`.
      expect(
        versePaintFor(
          visibility: VerseVisibility.inView,
          hot: false,
          entranceComplete: true,
        ),
        VersePaint.inView,
      );
      expect(
        VersePaint.inView,
        isNot(equals(VersePaint.out)),
        reason: '`in` and `out` are different values, not one flag',
      );
    });

    test('the entrance is the reveal, so an unfinished entrance outranks the '
        'scroll position', () {
      // `:1383` is a timer, and this is its domain shadow: until the timer fires
      // the verse is at `opacity:0` even when it is the only verse on screen.
      expect(
        versePaintFor(
          visibility: VerseVisibility.inView,
          hot: false,
          entranceComplete: false,
        ),
        VersePaint.out,
      );
    });

    test('`hot` is asked for by the reader, so it wins over `in`', () {
      // `:1385-1386`: `openSheet` removes `hot` from every `.vline` and adds it to
      // the tapped one. `:165` then sets `color:var(--ink-0); font-weight:500` and
      // a glow — and **not** the reveal, which is why the two are separate flags
      // here rather than one derived state.
      expect(
        versePaintFor(
          visibility: VerseVisibility.inView,
          hot: true,
          entranceComplete: true,
        ),
        VersePaint.hot,
      );
      expect(
        VersePaint.hot,
        isNot(equals(VersePaint.inView)),
        reason: 'a hot verse and a cold one must be able to paint differently',
      );
    });

    test('`hot` is the reader\'s and the clock\'s, so it outranks the entrance too', () {
      // `:1443` adds `hot` to a verse without touching `in` — `v.classList.add(
      // 'hot')` alone, after its own 460ms timer. So `hot` is applied
      // independently of the entrance in the prototype, and a function that
      // answered `out` here would be inventing an ordering the prototype does
      // not have.
      expect(
        versePaintFor(
          visibility: VerseVisibility.inView,
          hot: true,
          entranceComplete: false,
        ),
        VersePaint.hot,
      );
    });

    test('`hot` is unreachable unless the reader asked for it', () {
      // The other direction: `hot` must not be derivable from scroll position or
      // from the entrance clock, or "the verse the reader is looking at" would
      // silently become "the verse the reader tapped".
      for (final VerseVisibility visibility in VerseVisibility.values) {
        for (final bool entranceComplete in const <bool>[false, true]) {
          expect(
            versePaintFor(
              visibility: visibility,
              hot: false,
              entranceComplete: entranceComplete,
            ),
            isNot(equals(VersePaint.hot)),
            reason:
                'visibility=${visibility.name}, '
                'entranceComplete=$entranceComplete, hot=false',
          );
        }
      }
    });

    test('the three states are three distinct values, in this order', () {
      // Named in the prototype's own order — the absence of `.in` first, then
      // `.in`, then `.hot` — so the declaration reads as the paint ladder and a
      // fourth member is a compile error in every consumer. The middle value is
      // [VersePaint.inView] and not `in` only because `in` is a reserved word; see
      // this file's doc.
      expect(VersePaint.values, <VersePaint>[
        VersePaint.out,
        VersePaint.inView,
        VersePaint.hot,
      ]);
    });
  });
}
