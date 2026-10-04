/// **Defect #2, in both directions, and the phase's own `08-build-phases.md` test.**
///
/// `01-source-analysis.md`'s row: "**Arabic rendered in Space Mono.** Space Mono has no
/// Arabic glyphs → tofu boxes in the metadata row and CTA caption.
/// `ReadingArScreen.tsx:35,86`. … `ScriptureLanguage.ar` maps to `EvaTypography.arabic`
/// everywhere; drop `mono` from the AR metadata row and CTA caption; **add a
/// glyph-coverage test**."
///
/// ## THE DEFECT TABLE NAMED **TWO** SITES. THERE ARE **NINE**.
///
/// | # | site | prototype | Arabic text it wraps |
/// | --- | --- | --- | --- |
/// | 1 | metadata row | `ReadingArScreen.tsx:35` | `التكوين · الإصحاح ١ · ٤ دقائق` |
/// | 2 | CTA caption | `ReadingArScreen.tsx:86` | `٥ أسئلة · دقيقة تقريبًا` |
/// | 3 | **every verse marker** | `ReadingArScreen.tsx:49,51,56,58,63,68,70` | `١`…`٧` in the **prototype**; this client renders `'${verse.number}'` — an `int`, so ASCII |
/// | 4 | **the citation** | `ReadingArScreen.tsx:41` | `البداية` |
/// | 5 | **the CTA label** | `ds.tsx:237` — `F.ui`, i.e. **DM Sans** | `ابدأ التأمل` |
/// | 6 | the scripture body | `ReadingArScreen.tsx:47` | — **already correct** (`F.arabic`) |
/// | 7 | **the back tooltip** | **not in the prototype at all** | `رجوع` |
/// | 8 | **the text-size tooltip** | **not in the prototype at all** | `حجم الخط` |
/// | 9 | **the bookmark tooltip** | **not in the prototype at all** | `إشارة مرجعية — غير متاح في هذه النسخة` |
///
/// Sites 3, 4 and 5 are **not in the table**. Site 5 is in a *shared component*, so it
/// would have hit `/quiz`'s Arabic arm too and this phase would never have seen it.
///
/// ## AND THE PROTOTYPE'S NINE WERE THE **FLOOR**, NOT THE CEILING
///
/// Sites 7–9 have **no prototype line**, because the prototype's four top controls
/// are bare `<button>`s with an inline `<svg>` and **no label of any kind**
/// (`ReadingEnScreen.tsx:14-16`, `ReadingArScreen.tsx:21-29`). §14 requires an
/// accessible name on an icon-only button, so this client had to invent three
/// strings — and an invented string inherits the *ambient* `TextTheme`, which is
/// `bodyMedium`, which is **DM Sans**.
///
/// So the correct count was never "`01-source-analysis.md`'s nine". It is
/// **everything the reader can see on the screen**, and three of those sites were
/// invisible to this gate for two independent reasons, both of which had to be fixed
/// before the count could be stated at all:
///
/// 1. `renderedRuns()` walked the **already-painted** tree, and a `Tooltip` paints
///    nothing until a gesture. The probe found **zero** tooltip `Text` widgets.
/// 2. `_isArabic` tested four hand-picked codepoints — `[0x0628 ب, 0x0644 ل,
///    0x064Eَ, 0x0665 ٥]`. `رجوع` is `U+0631,062C,0648,0639`: **none of the
///    four**. So even once painted, sites 7 and 8 would have been skipped by tests 1
///    and 2.
///
/// `01-source-analysis.md`'s defect row and `08-build-phases.md`'s Phase-7 note both
/// claimed this gate asserts "**every character on the screen**". It did not, and
/// the difference was 30 tofu boxes.
///
/// ## WHY "NOT SPACE MONO" IS NOT THE ASSERTION, AND WHAT IS
///
/// The brief for this phase names the weaker form and then says why it is wrong:
/// "assert **no** `Text` widget in the AR tree has a `Space Mono` font family … and
/// assert the *specific* family each AR run uses (`EvaTypography.arabic`), because
/// 'not Space Mono' alone passes for `DMSans`, which also has no Arabic glyphs."
///
/// `font_coverage_test.dart` measures that: **Amiri is the only bundled family with
/// any Arabic glyph at all.** So `not SpaceMono` would be satisfied by Cormorant, DM
/// Sans and EB Garamond — three families that render six tofu boxes each.
///
/// Both halves are therefore asserted, and a third one that is stronger than either:
///
/// 1. no rendered run in the AR tree uses a family the assets cannot render Arabic in;
/// 2. every rendered Arabic run uses `Amiri`, by name — the token **and** the literal
///    string the engine receives;
/// 3. every character actually on the AR screen is covered by the family that renders
///    it.
///
/// ## AND IT IS READ OFF THE **RENDERED** TREE, WHICH IS THE WHOLE OF PHASE 6'S
/// C1 LESSON
///
/// `today_reading_panel.dart` cited defect #2 as the reason it branched on language
/// and then built one `TextStyle` for both arms — the Arabic preview rendered in
/// `EBGaramond` and **1520 tests stayed green**, because nothing read a `fontFamily`
/// off the tree. `home_page_test.dart` fixed that by reading the rendered style; this
/// file walks the same ground on a screen where the Arabic arm is *entirely* Arabic.
library;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/domain/arabic_digits.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/reading/presentation/widgets/sticky_cta.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/font_coverage.dart';
import '../../../../support/reading_harness.dart';

/// One rendered run of text: where it is and what family it renders in.
typedef RenderedRun = ({String label, String family});

void main() {
  group('the ARABIC arm', () {
    testWidgets('no rendered run uses a family with no Arabic glyphs', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      final List<RenderedRun> runs = await renderedRuns(tester);
      expect(runs, isNotEmpty, reason: 'the screen rendered no text at all');

      for (final RenderedRun run in runs) {
        if (!_isArabic(run.label)) continue;
        // **Every Arabic run must name one of the app's own five faces**, and this is
        // where that is said rather than assumed. `Icon` also builds a `RichText` — in
        // the framework's `MaterialIcons` font — and `codepointsForFamily` *throws* for
        // a family `pubspec.yaml` does not declare, which is the behaviour the parser
        // wants and the wrong thing to ask here. So the answer to "is this one of
        // ours?" is its own assertion.
        expect(
          kBundledFontFamilies,
          contains(run.family),
          reason:
              '`${run.label}` renders Arabic in `${run.family}`, which is not '
              'one of the five bundled faces. `pubspec.yaml` declares those, and a '
              'name outside them resolves to the fallback font with no error.',
        );
        expect(
          familyCovers(run.family, <int>[0x0628, 0x0644]),
          isTrue,
          reason:
              '`${run.label}` renders Arabic in `${run.family}`, which carries no '
              'Arabic glyph at all. "Not Space Mono" would have passed this: '
              '`CormorantGaramond`, `DMSans` and `EBGaramond` are all equally tofu.',
        );
      }
    });

    testWidgets(
      'every Arabic run uses `Amiri` — the token AND the literal string',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness(
          scripture: const Result<ScriptureText>.success(liveArabicPassage),
        );
        await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

        final Set<String> arabicFamilies = <String>{
          for (final RenderedRun run in await renderedRuns(tester))
            if (_isArabic(run.label)) run.family,
        };
        expect(
          arabicFamilies,
          <String>{EvaTypography.arabicFamily},
          reason:
              'one family for the whole Arabic arm, and it is the token the design '
              'system names. The literal string is asserted as well as the token '
              'because `eva_typography.dart` warns that "a name that merely looks right '
              'resolves to the fallback font with no error at all"',
        );
        expect(EvaTypography.arabicFamily, 'Amiri');
      },
    );

    testWidgets('and the NINE sites are each named by what they render', (
      WidgetTester tester,
    ) async {
      // The eight that were tofu, one assertion each, so a regression says **which
      // element** lost its family rather than "something did".
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      // Site 1 — the metadata row.
      expect(
        familyOfText(tester, 'Smith & Van Dyck (فانديك)'),
        EvaTypography.arabicFamily,
        reason: 'defect #2 site 1 — `ReadingArScreen.tsx:35`',
      );
      // Site 2 — the CTA caption, with Arabic-Indic digits in it.
      expect(
        familyOfText(tester, '${arabicIndicDigits(1)} سؤال واحد'),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 2 — `ReadingArScreen.tsx:86`, and the numeral is '
            'U+0661, which Space Mono does not carry either',
      );
      // Site 3 — a verse marker, read off the *span*, because the marker is inside the
      // paragraph and `find.byType(Text)` cannot see it.
      final InlineSpan marker = _verseMarkerSpan(tester, 1);
      expect(
        (marker as TextSpan).style!.fontFamily,
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 3 — `ReadingArScreen.tsx:49`. **The reason string used '
            'to say the digits are U+0661…U+0667 and that Space Mono carries neither, '
            'which described the PROTOTYPE and not this client**: the marker is '
            'a TextSpan over `verse.number`, an `int`, so what is on screen is '
            'ASCII. The family is still Amiri — the correct family for a marker in the '
            'Arabic arm is the one that renders Arabic — and the assertion is worth '
            'making; the justification was simply about a string that does not ship.',
      );
      // …and the marker really is ASCII digits, asserted so the reason string above
      // cannot rot back into describing the prototype. The one Arabic-Indic run in
      // this client is site 2's caption, through `arabicIndicDigits`.
      expect(
        scriptureMarkerTexts(tester),
        <String>['1', '2', '3', '4', '5'],
        reason: '`Verse.number` is an int; nothing renders U+0661…U+0667 here',
      );
      // Site 4 — the citation.
      expect(
        familyOfText(tester, 'يوحنا 3: 1-5'),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 4 — `ReadingArScreen.tsx:41`, and NOT in the defect '
            'table: `F.display` is Cormorant Garamond, which has no Arabic block',
      );
      // Site 5 — the CTA label, through a *shared* component.
      expect(
        familyOfText(tester, 'ابدأ التأمل'),
        EvaTypography.arabicFamily,
        reason:
            'defect #2 site 5 — `ds.tsx:237` sets `F.ui` on every '
            '`ButtonPrimary`, and DM Sans has no Arabic glyphs. NOT in the defect '
            'table, and it is in `ds.tsx` rather than in a screen.',
      );
      // Sites 7, 8 and 9 — **the three control tooltips**, which have no prototype
      // line at all. Each is asserted against what it *paints*, so this is the
      // rendered family rather than the value a caller passed: `IconActionButton`'s
      // own `Tooltip(message: tooltip)` carried **no** `textStyle`, and Flutter
      // resolves a null one to `ThemeData.textTheme.bodyMedium` — measured `DMSans`
      // on **both** themes, which carries no Arabic glyph at all.
      //
      // The strings are looked up through the table rather than written out, and
      // each one is asserted to be **Arabic by the block test** below — because
      // `رجوع` contains none of the four codepoints the first version of `_isArabic`
      // sampled, and a gate that cannot see the string cannot gate it.
      final Map<String, RenderedRun> painted = <String, RenderedRun>{
        for (final ({String message, RenderedRun run}) tooltip
            in await paintedTooltips(tester))
          tooltip.message: tooltip.run,
      };
      expect(
        painted,
        hasLength(3),
        reason:
            'three icon-only controls, so three tooltips; the prototype has none, '
            'and §14 requires a name on each',
      );
      for (final (String site, String message) in <(String, String)>[
        ('7 — the back control', const ReadingStrings.ar().back),
        ('8 — the `Aa` control', const ReadingStrings.ar().textSize),
        (
          '9 — the bookmark control',
          '${const ReadingStrings.ar().bookmark} — '
              '${const ReadingStrings.ar().unavailableSuffix}',
        ),
      ]) {
        expect(
          _isArabic(message),
          isTrue,
          reason:
              'site $site: `"$message"` is what this gate has to recognise as '
              'Arabic, and the first version of this predicate sampled four '
              'codepoints this string contains none of',
        );
        expect(
          painted[message]?.family,
          EvaTypography.arabicFamily,
          reason:
              'defect #2 site $site — no prototype line, so `IconActionButton` '
              'inherited `bodyMedium`, which is DM Sans',
        );
      }
      // Site 6 — the scripture body, which the prototype already had right and which
      // is asserted so the eight fixes cannot have been made by breaking this one.
      expect(
        ScriptureBlock.familyFor(ReadingLanguage.arabic),
        EvaTypography.arabicFamily,
      );
    });

    testWidgets('EVERY character on the AR screen is covered by its own family', (
      WidgetTester tester,
    ) async {
      // The strongest form, and the one that does not care which widget a run belongs
      // to: take the rendered text and the rendered family **together** and ask the
      // font's own `cmap`.
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      for (final RenderedRun run in await renderedRuns(tester)) {
        final String family = run.family;
        // `Icon` builds a `RichText` in the framework's `MaterialIcons` font, and the
        // icons carry no text; the assertion above is the one that says every Arabic
        // run uses one of the five bundled faces.
        if (!kBundledFontFamilies.contains(family)) continue;
        final Set<int> available = codepointsForFamily(family);
        final List<int> missing = <int>{
          for (final int unit in run.label.codeUnits)
            if (!_isIgnorable(unit) && !available.contains(unit)) unit,
        }.toList()..sort();
        expect(
          missing,
          isEmpty,
          reason:
              '`${run.label}` is rendered in `$family`, which has no glyph for '
              '${missing.map((int u) => 'U+${u.toRadixString(16).toUpperCase()}').join(", ")} — '
              'these would be tofu boxes on the sanctuary.',
        );
      }
    });
  });

  group('the ENGLISH arm, which is the control', () {
    testWidgets(
      'uses Space Mono for the marker and the caption, and nothing Arabic',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);

        // The English marker KEEPS `monoFamily` — Space Mono carries U+0030…U+0039, so
        // an ASCII digit renders, and it is the prototype's own treatment
        // (`ReadingEnScreen.tsx:48`). The defect is not "mono is wrong", it is "mono
        // cannot draw these particular characters".
        expect(
          ScriptureBlock.markerFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        expect(
          StickyCta.captionFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        expect(
          ReadingHeader.metadataFamilyFor(ReadingLanguage.english),
          EvaTypography.monoFamily,
        );
        // …and the English citation keeps the display serif.
        expect(
          ReadingHeader.titleFamilyFor(ReadingLanguage.english),
          EvaTypography.displayFamily,
        );
        for (final RenderedRun run in await renderedRuns(tester)) {
          expect(
            _isArabic(run.label),
            isFalse,
            reason: 'the EN arm has no Arabic',
          );
        }
      },
    );

    test('and the per-arm families really are per-arm', () {
      // The reverse direction: every one of the five is a `switch`, and a `switch` with
      // one arm would pass every test above.
      expect(ReadingLanguage.english, isNot(ReadingLanguage.arabic));
      for (final (String label, String en, String ar)
          in <(String, String, String)>[
            (
              'the marker',
              ScriptureBlock.markerFamilyFor(ReadingLanguage.english),
              ScriptureBlock.markerFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the caption',
              StickyCta.captionFamilyFor(ReadingLanguage.english),
              StickyCta.captionFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the metadata row',
              ReadingHeader.metadataFamilyFor(ReadingLanguage.english),
              ReadingHeader.metadataFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the citation',
              ReadingHeader.titleFamilyFor(ReadingLanguage.english),
              ReadingHeader.titleFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the CTA label',
              StickyCta.ctaFamilyFor(ReadingLanguage.english),
              StickyCta.ctaFamilyFor(ReadingLanguage.arabic),
            ),
            (
              'the scripture body',
              ScriptureBlock.familyFor(ReadingLanguage.english),
              ScriptureBlock.familyFor(ReadingLanguage.arabic),
            ),
          ]) {
        expect(en, isNot(ar), reason: '$label is one family for both arms');
      }
    });
  });
}

/// Characters no bundled family carries and no screen legitimately renders.
///
/// **Space** is here because none of the five `.ttf` files declares U+0020 in its
/// `cmap` — a TrueType space is drawn by the layout engine, not by a glyph — and the
/// zero-width joiner and bidi marks are the same story.
bool _isIgnorable(int unit) =>
    unit == 0x20 ||
    unit == 0x200C ||
    unit == 0x200D ||
    unit == 0x200E ||
    unit == 0x200F ||
    unit == 0x061C;

/// Whether [rune] is in one of the four Unicode blocks Arabic script occupies.
///
/// **The blocks, and not four hand-picked codepoints.** The first version sampled
/// `[0x0628 ب, 0x0644 ل, 0x064Eَ, 0x0665 ٥]`, and H1 measured what that cost: the
/// back control's label `رجوع` is `U+0631,062C,0648,0639` — **none of the four** —
/// so a painted Arabic tooltip would have been skipped by tests 1 and 2, and the
/// 30 tofu boxes H1 found would still have shipped behind a green gate.
///
/// A range is also the answer a reader can check: "is any character on this screen
/// from the Arabic block" is one question with one answer, and four samples is a
/// question about four characters that happen to be in the app today.
bool _isArabicRune(int rune) =>
    // Arabic
    (rune >= 0x0600 && rune <= 0x06FF) ||
    // Arabic Supplement
    (rune >= 0x0750 && rune <= 0x077F) ||
    // Arabic Presentation Forms-A
    (rune >= 0xFB50 && rune <= 0xFDFF) ||
    // Arabic Presentation Forms-B
    (rune >= 0xFE70 && rune <= 0xFEFF);

bool _isArabic(String text) => text.runes.any(_isArabicRune);

/// The family [text] is rendered in, or `null` when it is not on screen.
///
/// `null` and not a default, so a string that has quietly stopped being rendered is a
/// **failure naming the string** rather than a pass with an empty family.
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

/// Every run of text the tree actually renders, with the family it renders in —
/// **including every tooltip, painted one at a time**.
///
/// ## WHY THIS IS `Future` AND NOT A PLAIN FUNCTION
///
/// A `Tooltip` paints nothing until a gesture: its message lives in an overlay that
/// is not built at all until a long press is held past `kLongPressTimeout`. The
/// first version of this walk was synchronous, so the probe found **zero** tooltip
/// runs and the gate was blind to three Arabic sites — H1's thirty tofu boxes.
///
/// So the walk is: everything painted now, then each `Tooltip` in turn held open and
/// everything painted then. The result is **deduplicated**, because four snapshots of
/// the same screen would otherwise list every other run four times.
///
/// ## AND WHY A WALK AND NOT `find.byType(Text)`
///
/// `Text` is a `StatelessWidget` that builds a `RichText`, and `RichText` is also
/// what `Text.rich`, the scripture paragraphs **and** `Tooltip`'s own content are —
/// so the tree has all three, and a `Text`-only walk misses the verse markers
/// entirely, which is three of the nine sites this file exists for.
///
/// The family fallback is the theme's `bodyMedium` **captured before the gesture
/// loop**. The first version read `Theme.of(tester.element(find.byType(Text).first))`
/// inside the walk, which throws on a tree with no `Text` in it — and it is also the
/// value `Tooltip` resolves a null `textStyle` to, which is exactly the H1 defect,
/// so it is named here rather than being an accident.
Future<List<RenderedRun>> renderedRuns(WidgetTester tester) async {
  final String fallback =
      Theme.of(tester.element(find.byType(ScriptureBlock).first))
          .textTheme
          .bodyMedium
          ?.fontFamily ??
      '';

  final Set<RenderedRun> runs = <RenderedRun>{
    ..._paintedRuns(tester, fallback),
    for (final ({String message, RenderedRun run}) tooltip
        in await _tooltipRuns(tester, fallback))
      tooltip.run,
  };
  return runs.toList();
}

/// What each `Tooltip` on screen **paints**, and in what family.
///
/// One entry per tooltip per painted run, so a tooltip whose message arrives as two
/// spans is two entries rather than one lossy join.
Future<List<({String message, RenderedRun run})>> paintedTooltips(
  WidgetTester tester,
) async {
  final String fallback =
      Theme.of(tester.element(find.byType(ScriptureBlock).first))
          .textTheme
          .bodyMedium
          ?.fontFamily ??
      '';
  return _tooltipRuns(tester, fallback);
}

/// The runs the three control tooltips add to the tree, one at a time.
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
/// ## TWO THINGS THE FIRST VERSION GOT WRONG, AND BOTH WERE **THE H1 FAMILY**
///
/// **1. A `TextSpan` with children and no text of its own paints nothing.** The
/// walk added a run for *every* span, using the whole span's plain text as the label
/// — so a verse paragraph was counted twice, once by its parent and once by its
/// children. Harmless for the verses (the parent carries `bodyStyle`), and for the
/// **tooltip's** `RichText` it produced a duplicate run labelled `رجوع`.
///
/// **2. And a `TextSpan` with no style of its own inherits its parent's.** This is
/// the one that mattered. Flutter's `Tooltip` builds its content as
/// `TextSpan(style: effective, children: [TextSpan(text: message)])` — the **root**
/// carries the family and the **child** carries the text — so the walk read the
/// child's `fontFamily` as `null` and substituted the theme's `bodyMedium`, which is
/// **`DMSans`**. The tooltip was already rendered in `Amiri` and the gate reported
/// `DMSans`, in the one family this file exists to catch: a correct fix looks wrong.
///
/// So the walk now threads the effective style down the way `TextSpan.build` does,
/// and a `WidgetSpan` is labelled with **its own** plain text (U+FFFC) rather than
/// its parent's — the drop cap's box is one character to the engine, not a second
/// copy of the paragraph.
List<RenderedRun> _paintedRuns(WidgetTester tester, String fallback) {
  final List<RenderedRun> runs = <RenderedRun>[];
  void collectSpan(InlineSpan span, String label, [TextStyle? inherited]) {
    if (span is! TextSpan) {
      // A `WidgetSpan` or a `PlaceholderSpan`: its OWN plain text, in the family it
      // inherits. The drop cap's box is one character to the engine (U+FFFC), not a
      // second copy of the paragraph it hangs in.
      runs.add((
        label: span.toPlainText(),
        family: inherited?.fontFamily ?? fallback,
      ));
      return;
    }
    // `TextSpan.build` resolves a null `style` against the parent's, so this walk
    // has to as well — that resolution *is* what the engine does.
    final TextStyle effective = span.style ?? inherited ?? const TextStyle();
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

  void collectRoot(InlineSpan span) =>
      collectSpan(span, span.toPlainText(), null);

  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    collectRoot(rich.text);
  }
  for (final Text widget in tester.widgetList<Text>(find.byType(Text))) {
    runs.add((
      label: widget.data ?? '',
      family: widget.style?.fontFamily ?? fallback,
    ));
  }
  return runs;
}

/// The plain text of every verse marker on screen, in order.
///
/// A separate walk because the marker is a `TextSpan` inside the paragraph and
/// `find.text` cannot see it — the same reason `_verseMarkerSpan` exists.
List<String> scriptureMarkerTexts(WidgetTester tester) => <String>[
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  ))
    if (rich.text is TextSpan)
      for (final InlineSpan child
          in (rich.text as TextSpan).children ?? const <InlineSpan>[])
        if (child is TextSpan &&
            child.children == null &&
            (child.style?.fontWeight ?? FontWeight.normal) ==
                ScriptureBlock.markerWeight)
          child.text ?? '',
];

/// The verse-number span of scripture paragraph [number].
InlineSpan _verseMarkerSpan(WidgetTester tester, int number) {
  final InlineSpan body = _scriptureRichTexts(tester)[number - 1].text;
  final List<InlineSpan> children = (body as TextSpan).children!;
  return children.first is WidgetSpan ? children[1] : children.first;
}

/// Whether [element] is a verse paragraph rather than a header label or the drop cap's
/// own `Text`.
///
/// The header is excluded by identity above; the drop cap by this, because a
/// `WidgetSpan` has **no `Element`** so nothing in the drop-cap `Text`'s ancestry
/// distinguishes it, and a verse paragraph is the only `RichText` on this screen whose
/// span has children.
bool _isVerseParagraph(Element element) {
  final Widget widget = element.widget;
  if (widget is! RichText) return false;
  final InlineSpan text = widget.text;
  return text is TextSpan && text.children != null;
}

/// The scripture paragraphs, excluding the header's.
///
/// See `reading_page_test.dart`'s copy of this walk for why a `RichText` whose span
/// has **no children** is the drop cap's own `Text` and not a verse.
List<RichText> _scriptureRichTexts(WidgetTester tester) {
  final Set<Element> header = <Element>{
    ...find
        .descendant(
          of: find.byType(ReadingHeader),
          matching: find.byType(RichText),
        )
        .evaluate(),
  };
  return <RichText>[
    for (final Element element
        in find
            .descendant(
              of: find.byType(ScriptureBlock),
              matching: find.byType(RichText),
            )
            .evaluate())
      if (!header.contains(element) && _isVerseParagraph(element))
        element.widget as RichText,
  ];
}
