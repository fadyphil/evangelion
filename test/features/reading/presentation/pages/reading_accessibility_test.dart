import 'dart:ui' show Tristate;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_header.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';

/// §14 over `/reading`: a semantics sweep, keyboard reachability, and the RTL
/// arrangement, in both arms.
///
/// `home_accessibility_test.dart` is the precedent and `login_accessibility_test.dart`
/// records the two traps this file is shaped around:
///
/// * **`ensureSemantics` must be disposed in the test BODY**, not in an
///   `addTearDown` — recorded decision 38 measured eight failures across two suites,
///   because `testWidgets` compares the live handle count against the count taken
///   *before* the framework took its own.
/// * **The walk is over the whole tree**, because `getSemantics(find.byType(…))`
///   returns the node *nearest* the finder and whether that is the widget's own node
///   depends on how the widget happens to be built — `IconActionButton` is wrapped in
///   a `Tooltip`, so `getSemantics(find.byType(IconActionButton))` reads a node above
///   it.
void main() {
  group('every interactive node is named and activatable', () {
    for (final (String label, Locale locale) in <(String, Locale)>[
      ('English', const Locale('en')),
      ('Arabic', const Locale('ar')),
    ]) {
      testWidgets('$label: no unnamed interactive node', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            locale.languageCode == 'ar'
                ? liveArabicPassage
                : liveEnglishPassage,
          ),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);

        final List<SemanticsData> tappable = nodesOffering(
          tester,
          SemanticsAction.tap,
        );
        expect(tappable, isNotEmpty, reason: 'the screen has live controls');

        for (final SemanticsData node in tappable) {
          expect(
            node.label.trim(),
            isNotEmpty,
            reason:
                "a tappable node with no accessible name is §14's first row",
          );
          expect(
            node.flagsCollection.isEnabled,
            Tristate.isTrue,
            reason:
                'an ENABLED control is announced as enabled, and this one is '
                'enabled',
          );
        }
        // **Disposed in the BODY**, never in an `addTearDown` — recorded decision 38
        // measured eight failures across two suites for exactly this mistake:
        // `testWidgets` compares the live `SemanticsHandle` count against the count
        // taken *before* the framework took its own, so a teardown that runs after that
        // check is a leak the harness reports as an unrelated-looking assertion.
        handle.dispose();
      });

      testWidgets('$label: the back, `Aa` and CTA controls are named', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final AppLocalizations strings = lookupAppLocalizations(locale);
        final ReadingHarness h = readingHarness(
          scripture: Result<ScriptureText>.success(
            locale.languageCode == 'ar'
                ? liveArabicPassage
                : liveEnglishPassage,
          ),
        );
        await pumpReading(tester, cubit: h.cubit, locale: locale);

        final Set<String> labels = <String>{
          for (final SemanticsData node in nodesOffering(
            tester,
            SemanticsAction.tap,
          ))
            node.label,
        };
        expect(labels, contains(strings.readingBack));
        expect(labels, contains(strings.readingTextSize));
        expect(labels, contains(strings.readingBeginReflection));
        // **Disposed in the BODY**, never in an `addTearDown` — recorded decision 38
        // measured eight failures across two suites for exactly this mistake:
        // `testWidgets` compares the live `SemanticsHandle` count against the count
        // taken *before* the framework took its own, so a teardown that runs after that
        // check is a leak the harness reports as an unrelated-looking assertion.
        handle.dispose();
      });
    }

    testWidgets('the bookmark is named, INERT, and says why', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final AppLocalizations strings = AppLocalizationsEn();
      final SemanticsData? bookmark = _nodeLabelled(
        tester,
        '${strings.readingBookmark} — ${strings.readingUnavailableSuffix}',
      );
      expect(
        bookmark,
        isNotNull,
        reason:
            "Phase 6's precedent, verbatim: an "
            'inert control ships with the reason in its name',
      );
      expect(bookmark!.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        bookmark.hasAction(SemanticsAction.tap),
        isFalse,
        reason:
            "§14's disabled row: the action must be genuinely ABSENT, not "
            'present and flagged. A reader who activates a control announced as '
            'disabled and gets a response has been told a lie.',
      );
      // **Disposed in the BODY**, never in an `addTearDown` — recorded decision 38
      // measured eight failures across two suites for exactly this mistake:
      // `testWidgets` compares the live `SemanticsHandle` count against the count
      // taken *before* the framework took its own, so a teardown that runs after that
      // check is a leak the harness reports as an unrelated-looking assertion.
      handle.dispose();
    });

    testWidgets('the `Aa` panel is announced as a slider with its value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);

      // **`AppLocalizationsEn().readingFontSize`, and it is a DIFFERENT string from
      // `textSize`.** `FontSizeStepper`'s slider label used to be the hard-coded
      // `'Font size'` — the language half of the defect this phase closed — so the
      // label now comes from the table.
      //
      // It is a separate field rather than `textSize` because an earlier version of
      // this change reused `textSize` for both, on the reasoning that they "name the
      // same control from two positions". They do not: one names the **button you
      // press** and the other the **slider it reveals**, and sharing a string put two
      // nodes on the screen with the identical label. `_nodeLabelled` then returned
      // the *button's* node — the `isSlider` flag was `false` — which is precisely
      // the discrimination this lookup exists to make.
      final SemanticsData? slider = _nodeLabelled(
        tester,
        AppLocalizationsEn().readingFontSize,
      );
      expect(
        slider,
        isNotNull,
        reason: 'the track\'s own name, not the button\'s',
      );
      expect(slider!.flagsCollection.isSlider, isTrue);
      expect(slider.value, '${ReadingCubit.defaultFontStep}');
      // Both directions are offered, so a reader who cannot drag can still press.
      expect(slider.hasAction(SemanticsAction.increase), isTrue);
      expect(slider.hasAction(SemanticsAction.decrease), isTrue);
      // **Disposed in the BODY**, never in an `addTearDown` — recorded decision 38
      // measured eight failures across two suites for exactly this mistake:
      // `testWidgets` compares the live `SemanticsHandle` count against the count
      // taken *before* the framework took its own, so a teardown that runs after that
      // check is a leak the harness reports as an unrelated-looking assertion.
      handle.dispose();
    });
  });

  group('keyboard', () {
    testWidgets('Tab reaches back, `Aa` and the CTA', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      await tabUntilFocused(
        tester,
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconActionButton),
        ),
      );
      expect(
        FocusManager.instance.primaryFocus,
        isNotNull,
        reason:
            'and the bookmark is the next stop but is NOT focusable, so it is '
            'the CTA that follows',
      );

      await tabUntilFocused(
        tester,
        find.ancestor(
          of: find.byIcon(Icons.format_size),
          matching: find.byType(IconActionButton),
        ),
      );
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tabUntilFocused(tester, find.byType(EvaButton));
      expect(FocusManager.instance.primaryFocus, isNotNull);
    });

    testWidgets('and the INERT bookmark is not a Tab stop', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final IconActionButton bookmark = tester.widget<IconActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.bookmark_border),
          matching: find.byType(IconActionButton),
        ),
      );
      expect(
        bookmark.onPressed,
        isNull,
        reason:
            '`EvaInk` and `EvaFocusRing` are both disabled by this, so Tab '
            'skips it — which is the point of a control that cannot be pressed',
      );
    });
  });

  group('each verse is a labelled region', () {
    testWidgets('so a reader can say "verse three"', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);

      final AppLocalizations strings = AppLocalizationsEn();
      // Read off the semantics **tree** rather than with `find.bySemanticsLabel`,
      // because `getSemantics`-style finders resolve the node *nearest* the finder and
      // a `RichText` inside a labelled `Semantics` is a node of its own — the same
      // reason `semanticsTree` exists in `design_system_harness.dart`.
      final Set<String> labels = <String>{
        for (final SemanticsData node in semanticsTree(tester)) node.label,
      };
      // `any` over the label rather than `contains`, because the `Semantics` **merges**
      // into the `RichText` node: the label and the verse arrive as one string, so
      // `startsWith` is the assertion that matches how it is actually built.
      for (final Verse verse in liveEnglishPassageVerses) {
        expect(
          labels.any(
            (String label) =>
                label.startsWith('${strings.readingVerse} ${verse.number}'),
          ),
          isTrue,
          reason:
              'so a reader moving node to node can be told which verse they are '
              'on, which one label for the whole passage would not allow',
        );
      }
      expect(
        labels.any((String label) => label.contains(strings.readingPassage)),
        isFalse,
        reason:
            'the block has no string of its own — each verse is named, '
            'which is more useful than naming the container once',
      );
      // **Disposed in the BODY**, never in an `addTearDown` — recorded decision 38
      // measured eight failures across two suites for exactly this mistake:
      // `testWidgets` compares the live `SemanticsHandle` count against the count
      // taken *before* the framework took its own, so a teardown that runs after that
      // check is a leak the harness reports as an unrelated-looking assertion.
      // ## AND THE LABEL MUST NOT **REPLACE** THE WORDS
      //
      // `Semantics(excludeSemantics: true)` on the verse wrapper would leave every
      // assertion above green — the node is still there, still named, still
      // `Verse <n>` — while a reader moving node to node heard "Verse 1" and nothing
      // else. So the verse's own text is asserted to be in the tree too, and this is
      // the loop that fails when the label swallows it.
      for (final Verse verse in liveEnglishPassageVerses) {
        expect(
          labels.any((String label) => label.contains(verse.text)),
          isTrue,
          reason:
              'the number alone is not the verse: a reader navigating by node has '
              'to hear the words. `Semantics` merges label and text into one string, '
              'so one assertion covers both halves.',
        );
      }
      handle.dispose();
    });
  });

  group('the ARABIC arm is a true mirror', () {
    testWidgets('and the ambient direction is what does it', (
      WidgetTester tester,
    ) async {
      final ReadingHarness en = readingHarness();
      await pumpReading(tester, cubit: en.cubit);
      expect(
        Directionality.of(tester.element(find.byType(NeuralScaffold))),
        TextDirection.ltr,
      );

      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));
      expect(
        Directionality.of(tester.element(find.byType(NeuralScaffold))),
        TextDirection.rtl,
        reason:
            'and this is `MaterialApp` deriving it from the locale — there is '
            'no `Directionality` anywhere under `lib/`',
      );
    });

    testWidgets('the scripture is right-aligned, not left-aligned', (
      WidgetTester tester,
    ) async {
      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(
        tester,
        cubit: ar.cubit,
        locale: const Locale('ar'),
        size: const Size(430, 2400),
      );

      // `ReadingArScreen.tsx:47` writes `textAlign: 'right'` and `ReadingEnScreen.tsx:45`
      // writes none — and `TextAlign.start` resolves to exactly those two under the
      // ambient direction, which is why this file spells neither.
      final RichText verse = _scriptureRichTexts(tester).first;
      expect(verse.textAlign, TextAlign.start);
      // `RichText.textDirection` is **null** here and that is correct: `null` means
      // "resolve from the ambient `Directionality`", which is `MaterialApp`'s and
      // which the previous group asserts is RTL. Asserting the field itself would be
      // asserting that the paragraph pins its direction, which is the thing this
      // screen deliberately does not do.
      expect(verse.textDirection, isNull);
      expect(
        Directionality.of(tester.element(find.byWidget(verse))),
        TextDirection.rtl,
      );
    });

    testWidgets('the AR citation is centred and the metadata row too', (
      WidgetTester tester,
    ) async {
      final ReadingHarness ar = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: ar.cubit, locale: const Locale('ar'));

      // `textAlign: 'center'` on both arms (`:33`, `:41`) — a row that does not mirror.
      expect(find.text('يوحنا 3: 1-5'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Smith & Van Dyck (فانديك)')).textAlign,
        TextAlign.center,
      );
    });
  });
}

/// The one semantics node labelled [label], or `null`.
SemanticsData? _nodeLabelled(WidgetTester tester, String label) {
  for (final SemanticsData node in semanticsTree(tester)) {
    if (node.label == label) return node;
  }
  return null;
}

/// The scripture paragraphs, excluding the header's.
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

bool _isVerseParagraph(Element element) {
  final Widget widget = element.widget;
  if (widget is! RichText) return false;
  final InlineSpan text = widget.text;
  return text is TextSpan && text.children != null;
}

// check is a leak the harness reports as an unrelated-looking assertion.
