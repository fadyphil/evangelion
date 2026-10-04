/// The bilingual-typography gate, shared by all six screens.
///
/// ## WHY THIS IS A HARNESS AND NOT SIX COPIES
///
/// `01-source-analysis.md` defect **#2** is "Arabic rendered in Space Mono — Space
/// Mono has no Arabic glyphs". Phase 7 built the instrument for it in
/// `test/features/reading/presentation/pages/reading_glyph_test.dart` and applied it
/// to **one** screen, and recorded in its own table that "the prototype's nine
/// Arabic sites were the **floor, not the ceiling**". Its reviewer then measured the
/// two other shipped screens and found their Arabic arms **mostly tofu** — and the
/// suite was green on both, because `home_page_test.dart` asserted the family on the
/// **preview only**.
///
/// That is the same defect class one screen over, so the fix is not "fix `/login`
/// and `/`". It is **generalise the instrument**, so the next screen Phase 8 or
/// Phase 9 writes is gated on its first commit rather than on its third review.
///
/// One copy, therefore. A gate with six copies is six gates, and they drift — which
/// is what happened before this file existed.
///
/// ## WHAT THE GATE ASSERTS, AND WHY "NOT SPACE MONO" IS NOT IT
///
/// Measured over the twenty bundled `.ttf` files: **Amiri is the only bundled family
/// with any Arabic glyph at all** (1700 codepoints, 255 in U+0600–U+06FF), and
/// Cormorant Garamond, DM Sans, EB Garamond and Space Mono have **zero**. So "no run
/// uses Space Mono" would be satisfied by three other families that render one tofu
/// box per character. All of these are asserted:
///
/// 1. no rendered run in the Arabic tree uses a family the assets cannot render
///    Arabic in;
/// 2. every rendered Arabic run uses `EvaTypography.arabicFamily` — the **token**
///    and, separately, the **literal string** the engine receives;
/// 3. every character actually on screen is carried by the family that renders it.
///
/// ## AND IT IS READ OFF THE **RENDERED** TREE
///
/// `today_reading_panel.dart` cited defect #2 as the reason it branched on language
/// and then built one `TextStyle` for both arms — the Arabic preview rendered in
/// `EBGaramond` and 1520 tests stayed green, because nothing read a `fontFamily` off
/// the tree. Reading the rendered style is the whole of the fix.
///
/// ## FOUR THINGS THE FIRST VERSION GOT WRONG, ALL OF THEM THE SAME FAMILY
///
/// Each was found **because a correct fix was reported as wrong**, so each is
/// preserved deliberately and each has a mutation in
/// `test/support/arabic_typography_gate_test.dart`.
///
/// 1. **A `Tooltip` paints nothing until a gesture.** `renderedRuns` walked the
///    already-painted tree and found **zero** tooltip `Text` widgets, so three
///    Arabic sites on `/reading` were invisible to the gate that existed to find
///    them. The walk is `Future`-returning: paint everything, then hold each
///    `Tooltip` open past `kLongPressTimeout` and paint again, deduplicated.
/// 2. **`_isArabic` sampled four codepoints.** `[0x0628 ب, 0x0644 ل, 0x064Eَ,
///    0x0665 ٥]` — and `رجوع` is `U+0631,062C,0648,0639`, **none of the four**. So
///    even once painted, two of the three would have been skipped. It is now a
///    **range** over the four Unicode blocks Arabic script occupies, which is also
///    the question a reader can check.
/// 3. **A `TextSpan` inherits its parent's style.** Flutter builds `Tooltip` content
///    as `TextSpan(style: effective, children: [TextSpan(text: message)])` — the
///    **root** carries the family and the **child** carries the text. Reading the
///    child's `fontFamily` saw `null`, substituted `bodyMedium`, and reported
///    **`DMSans`** for a tooltip the app had already rendered in **`Amiri`**: a
///    correct fix reported wrong, in the one family this file exists to catch.
/// 4. **A `TextSpan` with children and no text of its own paints nothing.** Counting
///    it added a duplicate run for every verse paragraph and a second `رجوع`.
///
/// ## ANTI-VACUITY, AND WHAT "VACUOUS" COSTS
///
/// Three of the six screens are **stubs** (§2's route table is not the same thing as
/// six built screens): `/quiz`, `/result` and `/settings` render
/// `Placeholder for /quiz` and nothing else. They carry **zero** Arabic runs, so an
/// "every Arabic run is Amiri" assertion over them is **vacuously true** today.
///
/// The gate does not paper over that. [expectArabicTypography] takes a **declared**
/// run count, and a screen whose count is `0` must pass a `vacuousBecause` saying
/// why — so the number is a claim in the test rather than an accident in the
/// fixture, and a stub that grows its first Arabic run goes red instead of green.
/// §7's rule: "A gate whose target directory does not exist yet reports **vacuous**
/// and says so — report that honestly rather than calling it a pass."
///
/// Each stub's capability is proved by planting a wrong-family Arabic run on it, per
/// screen, rather than by asserting the harness is capable in the abstract.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_coverage.dart';

/// One rendered run of text: what it says, and the family it renders in.
typedef RenderedRun = ({String label, String family});

/// Whether [rune] is in one of the four Unicode blocks Arabic script occupies.
///
/// **The blocks, and not four hand-picked codepoints.** The first version sampled
/// `[0x0628 ب, 0x0644 ل, 0x064Eَ, 0x0665 ٥]`, and the back control's label `رجوع`
/// is `U+0631,062C,0648,0639` — **none of the four** — so a painted Arabic tooltip
/// would have been skipped by every other assertion in this file and the tofu would
/// have shipped behind a green gate.
///
/// A range is also the answer a reader can check: "is any character on this screen
/// from the Arabic block" is one question with one answer, and four samples is a
/// question about four characters that happen to be in the app today.
bool isArabicRune(int rune) =>
    // Arabic
    (rune >= 0x0600 && rune <= 0x06FF) ||
    // Arabic Supplement
    (rune >= 0x0750 && rune <= 0x077F) ||
    // Arabic Presentation Forms-A
    (rune >= 0xFB50 && rune <= 0xFDFF) ||
    // Arabic Presentation Forms-B
    (rune >= 0xFE70 && rune <= 0xFEFF);

/// Whether any character of [text] is in the Arabic blocks.
///
/// Public because a gate that cannot see a string cannot gate it: each per-screen
/// suite asserts its own expected strings through this, so a string that stopped
/// being Arabic — or a string this predicate cannot recognise — is a failure naming
/// the string rather than a run silently excluded from the count.
bool containsArabic(String text) => text.runes.any(isArabicRune);

/// The families a run may name that this project does **not** bundle.
///
/// **Exactly one, and it is not optional.** `Icon` builds a `RichText` in the
/// framework's own `MaterialIcons` font, the icons carry no text, and
/// `codepointsForFamily` throws for a family `pubspec.yaml` does not declare — so
/// the coverage check cannot ask about it.
///
/// Asserting the allowlist rather than skipping anything undeclared is what stops the
/// skip from becoming a hole; see [expectNoTofuInAnyRun] for the measurement that
/// found it.
const Set<String> kFrameworkFamilies = <String>{'MaterialIcons'};

/// Characters no bundled family carries and no screen legitimately renders.
///
/// **Space** is here because none of the five `.ttf` files declares U+0020 in its
/// `cmap` — a TrueType space is drawn by the layout engine, not by a glyph — and the
/// zero-width joiner and bidi marks are the same story.
bool isIgnorableCodeUnit(int unit) =>
    unit == 0x20 ||
    unit == 0x200C ||
    unit == 0x200D ||
    unit == 0x200E ||
    unit == 0x200F ||
    unit == 0x061C;

/// The family of the **outermost** `DefaultTextStyle` on this screen.
///
/// ## WHAT THIS IS, AND WHAT IT IS **NOT**
///
/// Measured on every screen in this suite: **`monospace`**, every time. That is
/// `MaterialApp`'s own `_errorTextStyle` (`material/app.dart`), whose `debugLabel` is
/// *"fallback style; consider putting your text in a Material"* and whose family is
/// a name `pubspec.yaml` does not declare — so the engine's default font renders it.
///
/// It is **not** what a style-less run renders in, and the two are easy to confuse. A
/// `Tooltip` with no `textStyle` — the defect recorded decision 71 is about —
/// resolves to **`DMSans`**, because the tooltip's content is built inside the
/// `Material` and `Material` installs `bodyMedium`. The version of this walk that
/// this replaces read `Theme.of(…).textTheme.bodyMedium.fontFamily` and its doc
/// claimed `DMSans`; that claim is **correct and measured**, and it is why Phase 7
/// could state the defect's mechanism at all. It is recorded here so the next reader
/// does not "correct" it a second time in the other direction.
///
/// So this function answers a narrower question than the probe it replaces: *what
/// would a run render in if it named no family and sat above every `Material`?* Still
/// worth answering, because the answer is an **undeclared** family — and
/// [expectNoTofuInAnyRun] now treats an undeclared family as a **finding** rather
/// than skipping it, which is why this value matters at all.
///
/// ## WHY IT SCANS, AND WHY IT DOES NOT NAME A WIDGET
///
/// The probe it replaces read
/// `Theme.of(tester.element(find.byType(ScriptureBlock).first))` — a
/// **reading-screen** type. Promoting the walk to all six screens meant the probe
/// named a widget three of them do not contain, and its own doc records that reading
/// `Theme.of` from inside the walk "throws on a tree with no `Text` in it".
///
/// The scan is *total*, which is why it asks
/// `dependOnInheritedWidgetOfExactType` rather than `DefaultTextStyle.of`: the latter
/// returns `DefaultTextStyle.fallback()` instead of throwing, and that fallback's
/// family is `null`, so it cannot report "no provider" — and a silent `null` from the
/// root element would be mistaken for the ambient answer.
///
/// Depth-first over [WidgetTester.allElements] takes the **outermost** provider,
/// which is the ambient default rather than some nested override.
String materialAppDefaultFamily(WidgetTester tester) {
  for (final Element element in tester.allElements) {
    final DefaultTextStyle? provider = element
        .dependOnInheritedWidgetOfExactType<DefaultTextStyle>();
    if (provider != null) return provider.style.fontFamily ?? '';
  }
  return '';
}

/// Every run of text the tree actually renders, with the family it renders in —
/// **including every tooltip, painted one at a time**.
///
/// ## WHY THIS IS `Future` AND NOT A PLAIN FUNCTION
///
/// A `Tooltip` paints nothing until a gesture: its message lives in an overlay that
/// is not built at all until a long press is held past `kLongPressTimeout`. The
/// first version of this walk was synchronous, so the probe found **zero** tooltip
/// runs and the gate was blind to three Arabic sites — thirty tofu boxes.
///
/// So the walk is: everything painted now, then each `Tooltip` in turn held open and
/// everything painted then. The result is **deduplicated**, because four snapshots of
/// the same screen would otherwise list every other run four times.
///
/// ## AND WHY A WALK AND NOT `find.byType(Text)`
///
/// `Text` is a `StatelessWidget` that builds a `RichText`, and `RichText` is also
/// what `Text.rich`, the scripture paragraphs **and** `Tooltip`'s own content are —
/// so the tree has all three. A `Text`-only walk misses the verse markers entirely,
/// which is one of the nine sites the gate was built for.
Future<List<RenderedRun>> renderedRuns(WidgetTester tester) async {
  final String fallback = materialAppDefaultFamily(tester);

  return <RenderedRun>{
    ..._paintedRuns(tester, fallback),
    for (final ({String message, RenderedRun run}) tooltip
        in await _tooltipRuns(tester, fallback))
      tooltip.run,
  }.toList();
}

/// The Arabic runs on screen, in walk order.
Future<List<RenderedRun>> arabicRuns(WidgetTester tester) async =>
    <RenderedRun>[
      for (final RenderedRun run in await renderedRuns(tester))
        if (containsArabic(run.label)) run,
    ];

/// What each `Tooltip` on screen **paints**, and in what family.
///
/// One entry per tooltip per painted run, so a tooltip whose message arrives as two
/// spans is two entries rather than one lossy join.
Future<List<({String message, RenderedRun run})>> paintedTooltips(
  WidgetTester tester,
) => _tooltipRuns(tester, materialAppDefaultFamily(tester));

/// The family [text] is rendered in, or `null` when it is not on screen.
///
/// **`null` and `''` mean different things**, which is why this is not
/// `String?` for the sake of symmetry: `null` is "no widget renders this string"
/// and `''` is "one does, and it named no family" — which is itself a defect,
/// because the engine then falls back to a font this file exists to check. A
/// defaulting API would report both as the same thing and a run that quietly
/// stopped naming its family would pass.
String? familyOfText(WidgetTester tester, String text) {
  for (final Text widget in tester.widgetList<Text>(find.byType(Text))) {
    if (widget.data != text) continue;
    return widget.style?.fontFamily ?? '';
  }
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    if (rich.text.toPlainText() != text) continue;
    final InlineSpan span = rich.text;
    return span is TextSpan ? span.style?.fontFamily ?? '' : '';
  }
  return null;
}

/// Every rendered run of Arabic is in Amiri, and the set of runs is exactly
/// [expectedArabic].
///
/// ## WHY THE **SET** AND NOT A COUNT
///
/// Set equality catches two failures a count cannot, and each of them is how this
/// gate could have gone on being green while the screen was broken:
///
/// * **a run silently vanishing** — "every Arabic run is Amiri" over an empty set is
///   **vacuously true**. §7's "a gate that cannot fail is worse than no gate" wearing
///   the most innocent possible costume. A count catches this only if somebody
///   remembers to update it; a declared list of the runs that *should* be there
///   cannot be satisfied by their absence.
/// * **a run silently appearing** — a new Arabic string lands and nobody looked at
///   its family. The failure names the string.
///
/// ## AND DECLARING THE STRINGS IS THE EVIDENCE
///
/// This is the artefact the gate exists to produce. Phase 7's reviewer was told "the
/// Arabic arm is Amiri" and had to take it on trust, because the measurement that
/// said otherwise was in a review report. Here it is a list in a test, it names
/// every run on every screen, and it is compared on **every** run of the suite.
///
/// ## AND [vacuousBecause] IS REQUIRED EXACTLY WHEN THE LIST IS EMPTY
///
/// Three of the six screens render no Arabic at all. Saying so in the test, with a
/// reason, is the difference between a gate that is *installed and honest* and one
/// that is silently doing nothing.
Future<void> expectArabicTypography(
  WidgetTester tester, {
  required String screen,
  required List<String> expectedArabic,
  String? vacuousBecause,
}) async {
  final List<RenderedRun> runs = await renderedRuns(tester);

  expect(
    runs,
    isNotEmpty,
    reason:
        '$screen rendered no text at all, so every assertion below would be '
        'vacuously true.',
  );

  final List<RenderedRun> arabic = <RenderedRun>[
    for (final RenderedRun run in runs)
      if (containsArabic(run.label)) run,
  ];

  if (expectedArabic.isEmpty) {
    expect(
      vacuousBecause,
      isNotNull,
      reason:
          '$screen declares no Arabic runs, so its Arabic gate asserts nothing. '
          '§7 requires that to be stated: pass `vacuousBecause` saying why the '
          'screen has none, so the empty list is a claim rather than an accident.',
    );
    expect(
      arabic,
      isEmpty,
      reason:
          '$screen was declared to render no Arabic, and now renders '
          '${arabic.map((RenderedRun r) => "`${r.label}`").join(", ")}. The new '
          'run needs its family checked and added to `expectedArabic`.',
    );
    return;
  }

  expect(
    vacuousBecause,
    isNull,
    reason:
        '$screen has ${expectedArabic.length} Arabic runs, so '
        '`vacuousBecause` must be null — the gate is not vacuous.',
  );

  expect(
    <String>{for (final RenderedRun run in arabic) run.label}
        .difference(expectedArabic.toSet()),
    isEmpty,
    reason:
        '$screen renders Arabic that `expectedArabic` does not declare.\n'
        'Declared but NOT rendered: '
        '${expectedArabic.toSet().difference(<String>{for (final RenderedRun r in arabic) r.label})}\n'
        'Rendered:\n${describeArabicRuns(arabic)}',
  );
  expect(
    expectedArabic.toSet().difference(<String>{
      for (final RenderedRun r in arabic) r.label,
    }),
    isEmpty,
    reason:
        '$screen no longer renders Arabic that `expectedArabic` declares. Either a '
        'run was removed — which is a defect in its own right, since the list is the '
        'evidence of what a reader sees — or the list is stale.\n'
        'Rendered:\n${describeArabicRuns(arabic)}',
  );

  for (final RenderedRun run in arabic) {
    // **Every Arabic run must name one of the app's own five faces.** `Icon` also
    // builds a `RichText` — in the framework's `MaterialIcons` font — and
    // `codepointsForFamily` *throws* for a family `pubspec.yaml` does not declare,
    // which is the behaviour the parser wants and the wrong thing to ask here. So
    // the answer to "is this one of ours?" is its own assertion.
    expect(
      kBundledFontFamilies,
      contains(run.family),
      reason:
          '`${run.label}` renders Arabic in `${run.family}`, which is not one of '
          'the five bundled faces. `pubspec.yaml` declares those, and a name '
          'outside them resolves to the fallback font with no error.',
    );
    expect(
      familyCovers(run.family, <int>[0x0628, 0x0644]),
      isTrue,
      reason:
          '`${run.label}` renders Arabic in `${run.family}`, which carries no '
          'Arabic glyph at all. "Not Space Mono" would have passed this: '
          '`CormorantGaramond`, `DMSans` and `EBGaramond` are all equally tofu.',
    );
    expect(
      run.family,
      EvaTypography.arabicFamily,
      reason:
          '`${run.label}` should render in the Arabic face. This asserts the '
          '**token**; the literal string is asserted separately below.',
    );
  }

  expect(
    <String>{for (final RenderedRun run in arabic) run.family},
    <String>{EvaTypography.arabicFamily},
    reason:
        'one family for the whole Arabic arm, and it is the token the design '
        'system names.',
  );
  expect(
    EvaTypography.arabicFamily,
    'Amiri',
    reason:
        'the literal string as well as the token, because '
        '`eva_typography.dart` warns that "a name that merely looks right '
        'resolves to the fallback font with no error at all".',
  );
}

/// Every run on screen names a family this project ships, and every character on
/// screen is carried by that family.
///
/// **Language-agnostic on purpose.** It is the only assertion in this file that does
/// real work on the three stub screens, where the Arabic gate is vacuous: a stub that
/// grew a run in a family without the glyphs it needs is caught here.
///
/// ## AND AN **UNDECLARED** FAMILY IS A FINDING, NOT A SKIP
///
/// The version this replaces skipped every run whose family is not one of the five
/// bundled ones, with a comment saying `Icon` builds a `RichText` in `MaterialIcons`
/// and `codepointsForFamily` throws for a family `pubspec.yaml` does not declare.
/// The skip is right about `MaterialIcons` and **wrong about everything else**, and
/// the reason it is wrong is the same defect this whole file exists to catch: the
/// skipped run is exactly the run nobody has checked.
///
/// Measured, before the check existed: the walk reported `monospace` for
/// `_Greeting`'s two runs and for every `Text` on the three stub screens —
/// `MaterialApp`'s `_errorTextStyle` family, which **no `.ttf` here declares**, so the
/// engine's default font drew them. A silent skip reported that as "fine".
///
/// So the allowlist is one entry long and it is asserted rather than assumed. A new
/// undeclared family fails here, naming the run, instead of passing.
Future<void> expectNoTofuInAnyRun(
  WidgetTester tester, {
  required String screen,
}) async {
  for (final RenderedRun run in await renderedRuns(tester)) {
    expect(
      kFrameworkFamilies.contains(run.family) ||
          kBundledFontFamilies.contains(run.family),
      isTrue,
      reason:
          '`${run.label}` renders in `${run.family}`, which `pubspec.yaml` does not '
          'declare. A name outside the declared families resolves to the engine\'s '
          'default font with no error at all — and this gate skips the coverage check '
          'for an undeclared family, because `codepointsForFamily` throws rather '
          'than answering. The only families allowed here are the five bundled ones '
          'and $kFrameworkFamilies (which is `Icon`\'s own `MaterialIcons`). '
          '`MaterialApp`\'s own fallback, `monospace`, is a finding, not a skip.',
    );
    if (!kBundledFontFamilies.contains(run.family)) continue;
    final Set<int> available = codepointsForFamily(run.family);
    final List<int> missing = <int>{
      for (final int unit in run.label.codeUnits)
        if (!isIgnorableCodeUnit(unit) && !available.contains(unit)) unit,
    }.toList()..sort();
    expect(
      missing,
      isEmpty,
      reason:
          '`${run.label}` is rendered in `${run.family}`, which has no glyph for '
          '${missing.map((int u) => 'U+${u.toRadixString(16).toUpperCase()}').join(", ")} — '
          'these would be tofu boxes on $screen.',
    );
  }
}

/// The rendered Arabic runs as a readable table.
///
/// **In the failure reasons, deliberately.** A gate that reports "expected 14, got
/// 13" sends the reader to the source; a gate that prints the runs and their
/// families answers the question in the output, which is the difference between a
/// test that names a defect and one that confirms there is one.
String describeArabicRuns(List<RenderedRun> arabic) => arabic
    .map((RenderedRun run) => '  ${run.family.padRight(18)} ${run.label}')
    .join('\n');

/// The runs the tooltips on screen add to the tree, one at a time.
///
/// **Indexed rather than matched by widget instance**, because a `Tooltip` is
/// re-created on every rebuild of its parent and `find.byWidget` would then be
/// looking for a widget that is no longer in the tree — which reads as "the tooltip
/// did not paint" rather than as a stale finder.
Future<List<({String message, RenderedRun run})>> _tooltipRuns(
  WidgetTester tester,
  String fallback,
) async {
  // `Tooltip.message` is nullable because a tooltip may carry a `richMessage`
  // instead, and `IconActionButton` only ever passes the plain one — so `!` is
  // right here and `?? ''` would be a silent empty message.
  final List<String> messages = <String>[
    for (final Tooltip tip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
      tip.message!,
  ];
  final List<({String message, RenderedRun run})> painted =
      <({String message, RenderedRun run})>[];

  for (int index = 0; index < messages.length; index++) {
    final Finder target = find.byType(Tooltip).at(index);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(target),
      kind: PointerDeviceKind.touch,
    );
    // The tooltip's own `showDuration`/`enterDuration` are what this waits out. A
    // fixed 12 pumps was tried first and is a second number to get wrong.
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (_isPainted(tester, messages[index])) break;
    }
    for (final RenderedRun run in _paintedRuns(tester, fallback)) {
      if (run.label == messages[index]) {
        painted.add((message: messages[index], run: run));
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }
  return painted;
}

/// Whether [message] is on screen, which is how the loop above knows the tooltip
/// has actually painted rather than merely been told to.
bool _isPainted(WidgetTester tester, String message) => tester
    .widgetList<RichText>(find.byType(RichText))
    .any((RichText rich) => rich.text.toPlainText() == message);

/// Everything painted right now, one entry per run of text.
///
/// ## THREE THINGS THE FIRST VERSION GOT WRONG HERE, AND ALL THREE REPORTED A
/// ## CORRECT FIX AS WRONG
///
/// **1. A `TextSpan` with children and no text of its own paints nothing.** The
/// walk added a run for *every* span, using the whole span's plain text as the
/// label — so a verse paragraph was counted twice, once by its parent and once by
/// its children. Harmless for the verses, and for the **tooltip's** `RichText` it
/// produced a duplicate run labelled `رجوع`.
///
/// **2. A `TextSpan` with no style of its own inherits its parent's.** Flutter
/// builds `Tooltip` content as
/// `TextSpan(style: effective, children: [TextSpan(text: message)])` — the **root**
/// carries the family and the **child** carries the text — so reading the child's
/// `fontFamily` as `null` and substituting the theme's `bodyMedium` reported
/// **`DMSans`** for a tooltip the app had already rendered in **`Amiri`**, in the one
/// family this file exists to catch.
///
/// **3. And a `TextSpan` that styles only *some* fields inherits the rest.** This is
/// the one this promotion found, and it is a **`merge`, not a `??`**.
/// `TextSpan.build` pushes styles onto a `ui.ParagraphBuilder` and pops them, so a
/// child whose style carries only a colour **keeps its parent's family** — the
/// engine's resolution is `span.style.merge(parentEffective)`.
///
/// `??` gets that wrong for a span that styles *something*: `_Greeting`'s lead-in
/// span is `TextStyle(color: colors.ink)`, so `??` read its family as `null`,
/// substituted the ambient fallback, and reported **`monospace`** for a run that
/// renders in **Cormorant Garamond** — including the Arabic `صباح الخير، `. A gate
/// that reports a correct run as tofu trains its readers to ignore it, which is
/// worse than not having the gate.
///
/// A `WidgetSpan` is labelled with **its own** plain text (U+FFFC) rather than its
/// parent's — the drop cap's box is one character to the engine, not a second copy
/// of the paragraph it hangs in.
///
/// ## AND THERE IS **NO** `find.byType(Text)` PASS, WHICH USED TO BE HERE
///
/// Every `Text` builds a `RichText`, and `Text.build` puts the **merged** ambient
/// style on a root `TextSpan` with the widget's own span as a **child**
/// (`text.dart`, `TextSpan(style: effectiveTextStyle, text: data, children:
/// [textSpan])`). So the `RichText` pass above already reports every `Text`'s family
/// as the engine resolves it, and a second pass over `Text` could only report it
/// again — differently.
///
/// It did, and the difference was a measurement: a `Text` with `style == null` on a
/// stub screen rendered in `DMSans` through its `RichText` and in **`monospace`**
/// through the `Text` pass, because that pass used the harness-wide outermost
/// provider rather than the one at the `Text`'s own position. Two families for one
/// run, and the walk had no way to say which was the real one.
///
/// `familyOfText` still reads `Text` widgets directly, and that is fine: it is asked
/// "what family was *passed* to this widget", not "what family does the engine
/// resolve", and the two differ by exactly this merge.
List<RenderedRun> _paintedRuns(WidgetTester tester, String fallback) {
  final List<RenderedRun> runs = <RenderedRun>[];
  void collectSpan(InlineSpan span, String label, [TextStyle? inherited]) {
    if (span is! TextSpan) {
      runs.add((
        label: span.toPlainText(),
        family: inherited?.fontFamily ?? fallback,
      ));
      return;
    }
    // **A merge, and the base/other order is load-bearing.**
    //
    // `TextStyle.merge` reads "a copy of **this** where the non-null fields in
    // **other** have replaced the corresponding null fields in **this**" — so the
    // **parent is the base** and the **child is `other`**. Written the other way round
    // (`own.merge(fromParent)`) the parent wins every field, which the partially-styled
    // plant cannot see: a child carrying only a colour gets the parent's family either
    // way. It took the second plant — a child that names its **own** family under a
    // parent that names a different one — to see it, and that plant reported
    // Cormorant Garamond for a run that renders in Amiri.
    final TextStyle effective = switch ((span.style, inherited)) {
      (final TextStyle own, null) => own,
      (final TextStyle own, final TextStyle fromParent) => fromParent.merge(
        own,
      ),
      (null, final TextStyle fromParent) => fromParent,
      (null, null) => const TextStyle(),
    };
    if (span.text != null || span.children == null) {
      runs.add((
        label: span.text ?? label,
        family: effective.fontFamily ?? fallback,
      ));
    }
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      collectSpan(child, label, effective);
    }
  }

  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    collectSpan(rich.text, rich.text.toPlainText(), null);
  }
  return runs;
}
