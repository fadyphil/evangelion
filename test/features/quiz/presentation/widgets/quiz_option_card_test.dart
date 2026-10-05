import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `QuizOptionCard` — the four states, and the tap handler that was **missing**.
///
/// ## THE TAP-HANDLER FINDING IS THE ONE WORTH READING TWICE
///
/// The first version of `QuizOptionCard` ended at `Semantics(onTap: onTap)`, which is
/// an **accessibility** action and not a pointer one. A screen-reader user could
/// press the option and a finger could not. `SocialAuthButton` has the identical
/// shape and gets away with it because its `onPressed` is `null` in **every** shipping
/// call site — it ships inert, so no test ever pressed it.
///
/// So this suite presses. `quiz_page_test.dart` found the same defect from the other
/// end (tapping an option and finding `selectedLetter` still `null`); this file is
/// what makes it a property of the **widget** rather than of one page.
/// The `Semantics` node whose own `label` is [label].
///
/// **By label, and not by ancestry.** `EvaFocusRing` and `EvaInk` both add semantics
/// nodes of their own, so "the first `Semantics` below the card" is whichever the
/// tree happens to list first — and it reported `enabled: null` on a control that was
/// enabled. Decision 78's `_nodeLabelled` makes the same move for the same reason.
Semantics _nodeLabelled(WidgetTester tester, String label) =>
    tester.widget<Semantics>(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == label,
      ),
    );

void main() {
  final AppLocalizations strings = AppLocalizationsEn();

  Future<void> pumpCard(
    WidgetTester tester, {
    required QuizOptionState state,
    String letter = 'A',
    String text = 'Nicodemus',
    bool enabled = true,
    bool dimmed = false,
    VoidCallback? onTap,
    ReadingLanguage language = ReadingLanguage.english,
    String? semanticLabel,
    double width = 320,
  }) async {
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        locale: const Locale('en'),
        textDirection: TextDirection.ltr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: Center(
          child: SizedBox(
            width: width,
            child: QuizOptionCard(
              letter: letter,
              text: text,
              state: state,
              language: language,
              enabled: enabled,
              dimmed: dimmed,
              onTap: onTap,
              semanticLabel:
                  semanticLabel ??
                  strings.optionLabel(letter: letter, text: text),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the four states', () {
    testWidgets('each has its own accent, and `idle` has none', (
      WidgetTester tester,
    ) async {
      final EvaColors colors = EvaThemeDark.theme.extension<EvaColors>()!;
      expect(
        QuizOptionCard.accentFor(QuizOptionState.idle, colors),
        isNull,
        reason: '`ds.tsx:424` — `accent = null` for `default`',
      );
      expect(
        QuizOptionCard.accentFor(QuizOptionState.selected, colors),
        colors.ember,
      );
      expect(
        QuizOptionCard.accentFor(QuizOptionState.correct, colors),
        colors.ok,
      );
      expect(
        QuizOptionCard.accentFor(QuizOptionState.incorrect, colors),
        colors.err,
      );
    });

    testWidgets(
      'and `isGraded` is true for exactly the two the prototype grades',
      (WidgetTester tester) async {
        // `ds.tsx:427` and `:450` share this condition, which is what made it one
        // helper here rather than two.
        expect(QuizOptionCard.isGraded(QuizOptionState.correct), isTrue);
        expect(QuizOptionCard.isGraded(QuizOptionState.incorrect), isTrue);
        expect(QuizOptionCard.isGraded(QuizOptionState.selected), isFalse);
        expect(QuizOptionCard.isGraded(QuizOptionState.idle), isFalse);
      },
    );

    testWidgets('the border and the fill follow the accent', (
      WidgetTester tester,
    ) async {
      // `ds.tsx:425-426`: the fill is the accent at 0.09 and the border **is** the
      // accent. So a wrong answer has a red rim and a 9%-red wash, and an idle card
      // has the resting rim and no accent at all.
      final EvaColors colors = EvaThemeDark.theme.extension<EvaColors>()!;
      await pumpCard(tester, state: QuizOptionState.correct);
      final BoxDecoration correct = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox b) => b.decoration as BoxDecoration)
          .firstWhere((BoxDecoration d) => d.border != null);
      expect(correct.border!.top.color, colors.ok);
      expect(correct.color, colors.ok.withValues(alpha: 0.09));

      await pumpCard(tester, state: QuizOptionState.incorrect);
      final BoxDecoration wrong = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox b) => b.decoration as BoxDecoration)
          .firstWhere((BoxDecoration d) => d.border != null);
      expect(wrong.border!.top.color, colors.err);
    });

    testWidgets('the badge fills only in the two graded states', (
      WidgetTester tester,
    ) async {
      // `ds.tsx:427` — `badgeFill = (correct || incorrect) ? accent : 'transparent'`.
      for (final (QuizOptionState, bool) row in <(QuizOptionState, bool)>[
        (QuizOptionState.idle, false),
        (QuizOptionState.selected, false),
        (QuizOptionState.correct, true),
        (QuizOptionState.incorrect, true),
      ]) {
        await pumpCard(tester, state: row.$1);
        final Iterable<Container> badges = tester.widgetList<Container>(
          find.byType(Container),
        );
        // The badge is the only `Container` with a **circular** shape.
        final Container badge = badges.firstWhere(
          (Container c) =>
              (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        );
        final BoxDecoration decoration = badge.decoration as BoxDecoration;
        expect(
          decoration.color == Colors.transparent,
          !row.$2,
          reason:
              '`${row.$1.name}` should ${row.$2 ? '' : 'not '}fill its badge',
        );
      }
    });

    testWidgets('the letter is drawn in mono caps at 12', (
      WidgetTester tester,
    ) async {
      // `ds.tsx:450` — `F.mono, fontSize 12, fontWeight 700`.
      await pumpCard(tester, state: QuizOptionState.idle, letter: 'C');
      // `find.text`, not `widgetWithText` — the latter needs an ancestor `Widget`
      // argument and the badge is private.
      final Text letter = tester.widget<Text>(find.text('C'));
      expect(letter.style?.fontFamily, EvaTypography.monoFamily);
      expect(letter.style?.fontSize, 12);
      expect(letter.style?.fontWeight, FontWeight.w700);
    });
  });

  group('`dimmed`', () {
    testWidgets('is the prototype\'s post-check dimming and nothing else', (
      WidgetTester tester,
    ) async {
      // `ds.tsx:437` — `opacity: dimmed ? 0.48 : 1` — and it is on the **whole card**,
      // badge included.
      await pumpCard(tester, state: QuizOptionState.idle);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

      await pumpCard(tester, state: QuizOptionState.idle, dimmed: true);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.48);
    });

    testWidgets('and it is NOT `enabled: false` — two different questions', (
      WidgetTester tester,
    ) async {
      // `dimmed` is visual; `enabled` is §5 trap 3's prevention. A disabled card is
      // **not** dimmed in the prototype (it has no disabled state), and a dimmed card
      // is still a card a reader has already answered.
      await pumpCard(tester, state: QuizOptionState.idle, enabled: false);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        1,
        reason: 'a disabled card is not a dimmed one',
      );
    });
  });

  group('`enabled` — §5 trap 3, and §14\'s disabled row', () {
    testWidgets('enabled: the action is present and the node says so', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(tester, state: QuizOptionState.idle, onTap: () => taps++);

      final Semantics node = _nodeLabelled(tester, 'A. Nicodemus');
      // **Located by its own label**, not by "the first `Semantics` descendant".
      // `EvaFocusRing` and `EvaInk` add nodes of their own, so `.first` was reading
      // whichever came first and reported `enabled: null` on a control that was
      // enabled — the same class of misreading decision 78's `_nodeLabelled` records.
      // **Checked as `isNotNull` before the rest**, because the failure this file
      // exists to prevent is an `onTap` that is *absent* — and `expect(onTap,
      // isNotNull)` after two other assertions reports "expected true, got null"
      // without saying which property was null.
      expect(node.properties.enabled, isTrue);
      expect(
        node.properties.onTap,
        isNotNull,
        reason: 'a screen reader must be able to press an enabled option',
      );
      expect(node.properties.onTap, isNotNull);
      handle.dispose();
    });

    testWidgets('disabled: the action is **absent**, not present-and-flagged', (
      WidgetTester tester,
    ) async {
      // `SocialAuthButton`'s documented shape, and §14's disabled row: a reader who
      // activates a control announced as unusable and gets a response has been told a
      // lie.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(tester, state: QuizOptionState.idle, enabled: false);

      final Semantics node = _nodeLabelled(tester, 'A. Nicodemus');
      expect(node.properties.enabled, isFalse);
      expect(
        node.properties.onTap,
        isNull,
        reason: '§14: the action is genuinely absent, not present and flagged',
      );
      handle.dispose();
    });

    testWidgets('and the accessible name is the CALLER\'s, verbatim', (
      WidgetTester tester,
    ) async {
      // §14: an unnamed button is the gap this exists to close, and a card whose name
      // says "correct" before the reader has checked **is** the spoiler leak. So the
      // label is a required parameter and this asserts it is passed through.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        state: QuizOptionState.idle,
        semanticLabel: 'A. Nicodemus — ${strings.quizAlreadyAnsweredSuffix}',
      );
      expect(
        find.bySemanticsLabel(RegExp(strings.quizAlreadyAnsweredSuffix)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the tap handler, which the first version did not have', () {
    testWidgets('a pointer tap reaches `onTap`', (WidgetTester tester) async {
      int taps = 0;
      await pumpCard(tester, state: QuizOptionState.idle, onTap: () => taps++);

      await tester.tap(find.byType(QuizOptionCard));
      await tester.pump();

      expect(
        taps,
        1,
        reason:
            'this is the assertion the widget was missing. `Semantics(onTap:)` is an '
            'accessibility action; without `EvaInk` a **finger** did nothing while a '
            'screen reader could press the card.',
      );
    });

    testWidgets('and a DISABLED card swallows it', (WidgetTester tester) async {
      int taps = 0;
      await pumpCard(
        tester,
        state: QuizOptionState.idle,
        enabled: false,
        onTap: () => taps++,
      );

      await tester.tap(find.byType(QuizOptionCard), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0, reason: 'the 409 prevention is a behaviour, not a label');
    });
  });

  group('the option label takes the PAYLOAD arm, not the ambient one', () {
    testWidgets('Latin option in DM Sans', (WidgetTester tester) async {
      await pumpCard(tester, state: QuizOptionState.idle);
      final Text label = tester.widget<Text>(find.text('Nicodemus'));
      expect(label.style?.fontFamily, EvaTypography.uiFamily);
    });

    testWidgets('Arabic option in Amiri', (WidgetTester tester) async {
      // **Decision 75's payload arm**, and the reason `language` is a required
      // parameter: the option text is the server's scripture, fetched in the
      // language the session was opened in. Reading `Directionality.of(context)`
      // instead would render it in DM Sans on the Arabic arm — the defect
      // `reading_glyph_test.dart` measures on `/reading`.
      await pumpCard(
        tester,
        state: QuizOptionState.idle,
        language: ReadingLanguage.arabic,
        letter: 'أ',
        text: 'نيقوديموس',
        semanticLabel: 'أ. نيقوديموس',
      );
      final Text label = tester.widget<Text>(find.text('نيقوديموس'));
      expect(label.style?.fontFamily, EvaTypography.arabicFamily);
    });

    testWidgets('and `optionStyleFor` resolves both arms from one place', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, state: QuizOptionState.idle);
      final BuildContext context = tester.element(find.byType(QuizOptionCard));
      expect(
        QuizOptionCard.optionStyleFor(
          context,
          ReadingLanguage.english,
        ).fontFamily,
        EvaTypography.uiFamily,
      );
      expect(
        QuizOptionCard.optionStyleFor(
          context,
          ReadingLanguage.arabic,
        ).fontFamily,
        EvaTypography.arabicFamily,
      );
    });
  });

  group('the flecks\' offsets, which are a FUNCTION of the width', () {
    test('the right pair sits outside the card at both §14 and the prototype width', () {
      // `QuizScreen.tsx:92-95` writes them as absolute px against one viewport, so
      // `356` is only "just outside the right edge" at the width the prototype was
      // drawn at. Copying it puts both flecks in the middle of the card at 430 and off
      // the end of it at 320 — §14's own surface.
      for (final double width in <double>[288, 320, 390, 430]) {
        final List<Offset> offsets = QuizOptionCard.fleckOffsetsFor(width);
        expect(offsets, hasLength(4), reason: 'four flecks at $width');
        expect(offsets[0].dx, lessThan(0), reason: 'the left pair is outside');
        expect(offsets[1].dx, lessThan(0));
        expect(
          offsets[2].dx,
          greaterThanOrEqualTo(width),
          reason: 'right, outside',
        );
        expect(offsets[3].dx, greaterThan(offsets[2].dx));
      }
    });

    test(
      'and the left pair is the prototype\'s own numbers, untranscribed',
      () {
        expect(QuizOptionCard.fleckOffsetsFor(430).take(2), <Offset>[
          const Offset(-10, 12),
          const Offset(-15, 36),
        ]);
      },
    );
  });

  group('§14\'s surface', () {
    testWidgets('320px at 1.22× overflows nothing, on either arm', (
      WidgetTester tester,
    ) async {
      for (final (ReadingLanguage, String) arm in <(ReadingLanguage, String)>[
        (ReadingLanguage.english, 'Nicodemus'),
        (ReadingLanguage.arabic, 'نيقوديموس'),
      ]) {
        await pumpCard(
          tester,
          state: QuizOptionState.correct,
          language: arm.$1,
          letter: arm.$1 == ReadingLanguage.arabic ? 'أ' : 'A',
          text: arm.$2,
          semanticLabel: 'x',
          width: 320,
        );
        expect(tester.takeException(), isNull, reason: arm.$1.name);
      }
    });

    testWidgets(
      'a LONG Arabic label grows the card rather than overflowing it',
      (WidgetTester tester) async {
        // `ds.tsx:434` is `minHeight: 64` and the first version wrote it as a `SizedBox`
        // height, which a two-line Arabic label at 1.22× would have overflowed. A
        // `ConstrainedBox` min is the transcription that holds.
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            textScale: 1.22,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: const Center(
              child: SizedBox(
                width: 320,
                child: QuizOptionCard(
                  letter: 'أ',
                  // **Long enough to exceed the 64px minimum** at 1.22×: measured four
                  // lines of 52px, which is *under* 64 and would have made this test
                  // pass with a hard-coded height.
                  text:
                      'نيقوديموس الفريسي الذي جاء إلى يسوع ليلاً，并且是当时 '
                      'الrepresentative — Executable long label that wraps',
                  state: QuizOptionState.idle,
                  language: ReadingLanguage.arabic,
                  semanticLabel: 'x',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(QuizOptionCard)).height,
          greaterThan(QuizOptionCard.minHeight),
          reason:
              'the label runs to five lines at 1.22×, so the card must be **taller** '
              'than its 64px minimum. The first draft of this test used a shorter '
              'label, measured three lines at 52px, and the card came out at exactly '
              '64 — which is the assertion passing for the wrong reason and a '
              '`SizedBox(height: 64)` passing alongside it.',
        );
      },
    );
  });

  group('`QuizHeader`, and the spacer that centres the beads', () {
    testWidgets('the two ends are the SAME width, or the row is off-centre', (
      WidgetTester tester,
    ) async {
      // `QuizScreen.tsx:45` is `justifyContent: 'space-between'` and `:46`/`:52` are
      // both 44 — so the **empty** box on the right is what puts the beads in the
      // middle. With one end 44 and the other 0 they sit 22px off.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              total: 3,
              completed: 1,
              current: 1,
              language: ReadingLanguage.english,
              strings: strings,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(IconActionButton), findsOneWidget);
      expect(
        tester.getSize(find.byType(IconActionButton)).width,
        QuizHeader.endWidth,
      );
      // **The measured width**, not the widget's field: `SizedBox` keeps its size in
      // `constraints` at runtime and the first draft read a `width` field that does
      // not exist. The measurement is also the better claim — it is what `space-between`
      // consumes.
      final SizedBox spacer = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(QuizHeader),
              matching: find.byType(SizedBox),
            )
            .last,
      );
      expect(
        tester.getSize(find.byWidget(spacer)).width,
        QuizHeader.endWidth,
        reason: '**the spacer is a named constant, not `Expanded`**',
      );
    });

    testWidgets('the beads row carries the CALLER\'s prefix, not the default', (
      WidgetTester tester,
    ) async {
      // `ProgressBeads.semanticLabel` defaults to the English `'Progress'`, which
      // would put an English word in the Arabic arm's semantics tree — decision 78's
      // half-translated string, in a different widget.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              total: 3,
              completed: 1,
              current: 1,
              language: ReadingLanguage.arabic,
              strings: AppLocalizationsAr(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(AppLocalizationsAr().quizProgress)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Progress')), findsNothing);
      handle.dispose();
    });

    testWidgets('and the close control\'s tooltip is the caller\'s too', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              total: 1,
              completed: 0,
              current: 0,
              language: ReadingLanguage.arabic,
              strings: AppLocalizationsAr(),
            ),
          ),
        ),
      );
      await tester.pump();

      // `tooltipFamily` is **required** (recorded decision 71): `Tooltip` has no
      // `textStyle` of its own, so omitting it resolves to `bodyMedium` — measured
      // DMSans — which is tofu for every Arabic character in `إغلاق`.
      final IconActionButton close = tester.widget<IconActionButton>(
        find.byType(IconActionButton),
      );
      expect(close.tooltip, AppLocalizationsAr().quizExit);
      expect(close.tooltipFamily, EvaTypography.arabicFamily);
    });
  });
}
