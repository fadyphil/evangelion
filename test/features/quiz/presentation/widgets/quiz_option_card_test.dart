import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    VoidCallback? onTap,
    ReadingLanguage language = ReadingLanguage.english,
    String? semanticLabel,
    double width = 320,
  }) async {
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
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
              onTap: onTap,
              semanticLabel:
                  semanticLabel ??
                  strings.optionLabel(letter: letter, text: text),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Advances the clock past the `Animate` widget's own zero-delay timer.
  ///
  /// ## WHY THE PUMP IS **1ms** AND NOT `pump()`
  ///
  /// `flutter_animate`'s `Animate.initState` ends in
  /// `Future.delayed(widget.delay, …)` — and `Future.delayed` creates a real
  /// `Timer` even for `Duration.zero`. One therefore hangs off **every**
  /// `Animate` in the tree until a frame turns past it, and a test body that
  /// ends first fails with *"A Timer is still pending even after the widget
  /// tree was disposed"*. The failure surfaces against whichever test ran
  /// next, which is how a real problem gets misfiled as flakiness.
  ///
  /// A bare `await tester.pump()` does **not** drain it, because a zero-length
  /// pump does not advance the fake clock and the timer is already due *at*
  /// the current time. `pump(const Duration(milliseconds: 1))` advances past
  /// it. `eva_animate_test.dart`'s `pumpEva` records the same measurement.
  Future<void> pumpPastTheTimer(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1));

  group('the four states', () {
    testWidgets('each has its own accent, and `idle` has none', (
      WidgetTester tester,
    ) async {
      final EvaColors colors = EvaThemeDark.theme.extension<EvaColors>()!;
      expect(
        QuizOptionCard.accentFor(QuizOptionState.idle, colors),
        isNull,
        reason:
            '`eva/redesign.html:338` — the resting card is a `--glass-fill` tint '
            'with no accent at all',
      );
      // `selected` has no prototype line (the redesign grades on tap) and keeps
      // the app's accent — see the enum's doc.
      expect(
        QuizOptionCard.accentFor(QuizOptionState.selected, colors),
        colors.ember,
      );
      // The redesign's verdict hues are gold and ember (`:350`/`:358`); this design
      // system's quiz/feedback pair is `ok`/`err` (§5.1's own words) and the gold
      // is substituted, not added — see `QuizOptionState.correct`'s doc.
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

    testWidgets('the border and the fill follow the accent, at the redesign\'s '
        'alphas', (WidgetTester tester) async {
      // `eva/redesign.html:350` — the correct card is the accent at .75 on the rim
      // and .10 in the fill; `:358` — the wrong one at .6 and .07. The gold is
      // `ok`'s hue here (see the accent test above), and the wrong card's ember IS
      // `err`'s.
      final EvaColors colors = EvaThemeDark.theme.extension<EvaColors>()!;
      await pumpCard(tester, state: QuizOptionState.correct);
      final BoxDecoration correct = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox b) => b.decoration as BoxDecoration)
          .firstWhere((BoxDecoration d) => d.border != null);
      expect(correct.border!.top.color, colors.ok.withValues(alpha: 0.75));
      expect(correct.color, colors.ok.withValues(alpha: 0.10));

      await pumpCard(tester, state: QuizOptionState.incorrect);
      final BoxDecoration wrong = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox b) => b.decoration as BoxDecoration)
          .firstWhere((BoxDecoration d) => d.border != null);
      expect(wrong.border!.top.color, colors.err.withValues(alpha: 0.6));
      expect(wrong.color, colors.err.withValues(alpha: 0.07));
    });

    testWidgets('and the WRONG card dims to 62%, which is the redesign\'s own '
        'opacity', (WidgetTester tester) async {
      // `eva/redesign.html:358` — `opacity: .62` on `.opt.wrong`, the whole card.
      // The old card's separate `dimmed` flag died with the prototype that wrote
      // it: the redesign dims nothing but the wrong card itself.
      await pumpCard(tester, state: QuizOptionState.idle);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

      await pumpCard(tester, state: QuizOptionState.incorrect);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        QuizOptionCard.wrongOpacity,
      );
    });

    testWidgets('the badge fills ONLY on the correct card', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:352` fills the correct badge with the accent;
      // `:359` gives the wrong badge an accent RIM and INK and no fill — the two
      // verdicts are shaped differently as well as coloured differently, which is
      // the colour-blind reader's second signal.
      for (final (QuizOptionState, bool) row in <(QuizOptionState, bool)>[
        (QuizOptionState.idle, false),
        (QuizOptionState.selected, false),
        (QuizOptionState.correct, true),
        (QuizOptionState.incorrect, false),
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

    testWidgets('the letter is drawn in mono at 10, on the card\'s own weight', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:342` — `font-family: var(--mono); font-size: 10px`,
      // with no weight of its own — and `:341` declares `font-weight: 500` on the
      // card the badge sits in, so the badge **inherits** it. The old
      // transcription drew 12px at 700 from the superseded prototype.
      await pumpCard(tester, state: QuizOptionState.idle, letter: 'C');
      // `find.text`, not `widgetWithText` — the latter needs an ancestor `Widget`
      // argument and the badge is private.
      final Text letter = tester.widget<Text>(find.text('C'));
      expect(letter.style?.fontFamily, EvaTypography.monoFamily);
      expect(letter.style?.fontSize, QuizOptionCard.badgeFontSize);
      expect(letter.style?.fontWeight, QuizOptionCard.labelWeight);
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

  group('the four flecks, and where they sit', () {
    // ## THE DERIVATION, AND WHY IT IS NOT FOUR LITERALS
    //
    // The prototype places them at `x: -10, -15, 356, 362`
    // (`eva/src/screens/QuizScreen.tsx:92-95`) **relative to the option card's
    // own box** — the wrapper `<div style={{position:'relative'}}>` at `:88`.
    //
    // Two of those are already card-relative (they are negative: outside the
    // card's left edge). The other two are **screen pixels on a 390px frame**
    // (`eva/src/App.tsx:89` — `width: 390`), and the card's box is not 390 wide:
    // the quiz screen's own padding is `20px 20px 28px` (`QuizScreen.tsx:41`),
    // so the card is `390 - 20 - 20 = 350` wide, and `356` and `362` are
    // therefore **6 and 12 pixels past the card's right edge**.
    //
    // The card's width is variable here — the redesign's `.opt` is `width:100%`
    // (`eva/redesign.html:337`) inside a body padded `0 26px` (`:333`) — so the
    // right-hand pair has to be derived from the card's own size or it lands in
    // the wrong place on every screen but a 390px one.
    test('the offsets are derived from the card\'s own width', () {
      // At the prototype's own 350px card, the derived offsets are the
      // prototype's literals — which is the check that the derivation is right
      // and not merely plausible.
      expect(QuizOptionCard.goldFleckOffsetsFor(350), <Offset>[
        const Offset(-10, 12),
        const Offset(-15, 36),
        const Offset(356, 8),
        const Offset(362, 30),
      ]);

      // And the right-hand pair tracks the width, while the left-hand pair —
      // already relative to the card's left edge — does not move at all.
      expect(QuizOptionCard.goldFleckOffsetsFor(300), <Offset>[
        const Offset(-10, 12),
        const Offset(-15, 36),
        const Offset(306, 8),
        const Offset(312, 30),
      ]);
    });

    testWidgets('the CORRECT card carries them, and the other three do not', (
      WidgetTester tester,
    ) async {
      // The brief's own rule — "tiny gold flecks floating near the correct
      // option — sparse, 3–4 max"
      // (`eva/src/imports/pasted_text/pasted-attachment.txt:97`, and `:114` for
      // the "gold flecks fade in with 150ms delay" line) — and the superseded
      // prototype that drew them (`QuizScreen.tsx:90-97`: the flecks are
      // rendered only `when (checked && opt.letter === CORRECT)`).
      //
      // **The redesign's `.opt` (`:337-362`) does not draw them**, and this
      // client's suite used to assert their absence. The brief's rule is the
      // authority for the ornament, and the placement is what decision 144 is
      // about: a component that is built, tested and never placed is invisible
      // to every assertion that does not look for it on the screen.
      for (final (QuizOptionState, bool) row in <(QuizOptionState, bool)>[
        (QuizOptionState.idle, false),
        (QuizOptionState.selected, false),
        (QuizOptionState.correct, true),
        (QuizOptionState.incorrect, false),
      ]) {
        await pumpCard(tester, state: row.$1);
        expect(
          find.byType(GoldFlecks),
          row.$2 ? findsOneWidget : findsNothing,
          reason: '`${row.$1.name}`',
        );
      }
    });

    testWidgets('and the offsets it is given are the derived ones', (
      WidgetTester tester,
    ) async {
      // The harness's card is 320px wide, so the right-hand pair is 6 and 12
      // pixels past that, not the prototype's 356 and 362.
      await pumpCard(tester, state: QuizOptionState.correct);
      final GoldFlecks flecks = tester.widget<GoldFlecks>(
        find.byType(GoldFlecks),
      );
      expect(flecks.offsets, QuizOptionCard.goldFleckOffsetsFor(320));
      expect(flecks.offsets[2], const Offset(326, 8));
      expect(flecks.offsets[3], const Offset(332, 30));
    });

    testWidgets('and they change NEITHER the card\'s size NOR the option\'s '
        'layout', (WidgetTester tester) async {
      // The flecks are an **overlay**: `Positioned.fill` inside a `Stack` whose
      // only non-positioned child is the card itself, so they contribute
      // nothing to the layout. The prototype's own flecks are `position:
      // absolute` (`QuizScreen.tsx:15`) inside the same relative wrapper.
      //
      // The idle card and the correct card carry the same one-line label, and
      // the correct card's extra verdict glyph sits at the row's far end, so
      // the two agree on both the card's height and where the option text
      // starts. If the overlay had joined the flow, both would move.
      await pumpCard(tester, state: QuizOptionState.idle);
      final Size idleSize = tester.getSize(find.byType(QuizOptionCard));
      final double idleTextLeft = tester.getTopLeft(find.text('Nicodemus')).dx;

      await pumpCard(tester, state: QuizOptionState.correct);
      final Size correctSize = tester.getSize(find.byType(QuizOptionCard));
      final double correctTextLeft = tester
          .getTopLeft(find.text('Nicodemus'))
          .dx;

      expect(correctSize.height, idleSize.height);
      expect(correctTextLeft, moreOrLessEquals(idleTextLeft, epsilon: 0.01));
    });
  });

  group('the card\'s ARRIVAL', () {
    /// The controller the built `Animate` is reading.
    ///
    /// The same reach as `eva_animate_test.dart`'s `controllerOf`: state, not
    /// appearance, so the claim is about the animation rather than about a
    /// pixel.
    AnimationController controllerOf(WidgetTester tester) =>
        tester.widget<Animate>(find.byType(Animate)).controller!;

    testWidgets('the card is DRAWN HIDDEN on the frame that creates it', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:340` — `.opt` opens with `opacity:0` — and the
      // hazard this asserts: `EvaAnimate` sets its controller to `0.0` and
      // calls `_play()` from a **post-frame callback**, so the frame that
      // creates the animated subtree draws it at opacity 0.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: const Center(
            child: SizedBox(
              width: 320,
              child: QuizOptionCard(
                letter: 'A',
                text: 'Nicodemus',
                state: QuizOptionState.idle,
                language: ReadingLanguage.english,
                semanticLabel: 'A. Nicodemus',
              ),
            ),
          ),
        ),
      );
      expect(
        controllerOf(tester).value,
        0.0,
        reason:
            'the card must not be painted at full strength on its first '
            'frame — that is what makes the entrance an entrance',
      );
      // The clock is advanced **after** the assertion, and only to drain the
      // `Animate` widget's own zero-delay timer — see `pumpPastTheTimer`.
      await pumpPastTheTimer(tester);
    });

    testWidgets('and it FINISHES', (WidgetTester tester) async {
      // A **bounded loop** rather than a magic pump count, and the bound is
      // the claim: "the entrance finishes". A hand-counted sequence passes for
      // the wrong reason on a different frame budget — the lesson decision 155
      // records for the dock's pills.
      //
      // `pumpAndSettle` is not the answer either: `NeuralScaffold` paints orbs
      // on the shared float clock, so it times out with a message about the
      // background rather than about the card.
      await pumpCard(tester, state: QuizOptionState.idle);
      bool settled = false;
      for (int frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (controllerOf(tester).value >= 1.0) {
          settled = true;
          break;
        }
      }
      expect(
        settled,
        isTrue,
        reason:
            'the entrance finishes — 120 frames is nearly two seconds '
            'against a 344ms moment',
      );
    });

    testWidgets('and the card\'s accessible name SURVIVES it', (
      WidgetTester tester,
    ) async {
      // ## §14'S ROW, AND THE ORDERING THAT SATISFIES IT
      //
      // `RenderAnimatedOpacity` **drops the semantics of a fully transparent
      // subtree** — `RenderAnimatedOpacityMixin.visitChildrenForSemantics`
      // skips the child while the alpha is 0 — so a fade that enclosed the
      // card's `Semantics` would leave an interactive control with no
      // accessible name for the length of the entrance. The `Semantics` is
      // **above** the animation, so the card's node survives it.
      //
      // The assertion is made while the card is **still transparent**, which
      // is the only frame in which the claim has any teeth.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCard(tester, state: QuizOptionState.idle, onTap: () {});
      expect(
        controllerOf(tester).value,
        lessThan(1.0),
        reason: 'the card is still arriving — that is the frame under test',
      );
      expect(
        find.bySemanticsLabel('A. Nicodemus'),
        findsOneWidget,
        reason:
            'an interactive node needs an accessible name (§14), and a '
            'transparent card is not a reason to lose it',
      );
      final Semantics node = _nodeLabelled(tester, 'A. Nicodemus');
      expect(node.properties.onTap, isNotNull);
      handle.dispose();
    });

    testWidgets('and under reduced motion it is simply THERE', (
      WidgetTester tester,
    ) async {
      // §14: "when disabled, jump straight to the end state". `EvaAnimate`
      // sets its controller to `1.0` rather than dropping the subtree, so the
      // card's shape is the same either way.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          disableAnimations: true,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: const Center(
            child: SizedBox(
              width: 320,
              child: QuizOptionCard(
                letter: 'A',
                text: 'Nicodemus',
                state: QuizOptionState.idle,
                language: ReadingLanguage.english,
                semanticLabel: 'A. Nicodemus',
              ),
            ),
          ),
        ),
      );
      await pumpPastTheTimer(tester);
      expect(controllerOf(tester).value, 1.0);
      expect(controllerOf(tester).isAnimating, isFalse);
    });

    testWidgets('and it does NOT replay when the card is GRADED', (
      WidgetTester tester,
    ) async {
      // The trigger is the option's **text**, so grading — which changes the
      // card's `state` and its accessible name but not its text — leaves the
      // entrance alone. An entrance that replayed on grading would throw the
      // reader's own answer away.
      await pumpCard(tester, state: QuizOptionState.idle);
      for (int frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (controllerOf(tester).value >= 1.0) break;
      }
      expect(controllerOf(tester).value, 1.0);

      await pumpCard(tester, state: QuizOptionState.correct);
      expect(
        controllerOf(tester).value,
        1.0,
        reason: 'the verdict arrived; the card must not start arriving again',
      );
    });
  });

  group('§14\'s surface', () {
    /// A one-line card's rendered height, measured first — the baseline the
    /// long-label test grows beyond.
    double singleLineHeight = 0;

    testWidgets('measure the one-line baseline', (WidgetTester tester) async {
      await pumpCard(tester, state: QuizOptionState.idle);
      singleLineHeight = tester.getSize(find.byType(QuizOptionCard)).height;
      expect(singleLineHeight, greaterThan(0));
    });

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
        );
        expect(tester.takeException(), isNull, reason: arm.$1.name);
      }
    });

    testWidgets('a LONG Arabic label grows the card rather than overflowing it', (
      WidgetTester tester,
    ) async {
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
      await pumpPastTheTimer(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(QuizOptionCard)).height,
        greaterThan(singleLineHeight),
        reason:
            'the label runs to five lines at 1.22×, so the card must be **taller** '
            'than the one-line card above it. The redesign\'s `.opt` carries no '
            'min-height (the old 64px was the superseded prototype\'s), so the '
            'assertion is growth, not a floor — and a fixed-height transcription '
            'would fail here on the first long label.',
      );
    });
  });

  group('`QuizHeader`, and the chrome the redesign drew', () {
    testWidgets('the back control is a 44 box around the chevron, and it is '
        'named', (WidgetTester tester) async {
      // `eva/redesign.html:564` is a bare `‹` with no label at all (§14's first
      // row), and `:149` gives it a ~28px box. The client paints the glyph at the
      // prototype's size inside a 44×44 tap box — recorded decision 31's shape —
      // and the row is 44 tall because a row is as tall as its tallest child.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              crumb: strings.quizCrumb('John 3:1-5'),
              score: 0,
              total: 3,
              completed: 1,
              current: 1,
              language: ReadingLanguage.english,
              strings: strings,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final SemanticsNode back = tester.getSemantics(
        find.bySemanticsLabel(strings.quizExit),
      );
      expect(back.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
      final Rect backRect = tester.getRect(
        find.bySemanticsLabel(strings.quizExit),
      );
      expect(
        backRect.width,
        moreOrLessEquals(QuizHeader.chevTapSize, epsilon: 0.5),
      );
      expect(
        backRect.height,
        moreOrLessEquals(QuizHeader.chevTapSize, epsilon: 0.5),
      );
      handle.dispose();
    });

    testWidgets('the crumb renders the composed string, centred and capped', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:565` — the `.ttl` slot, `max-width: 52%` of the row,
      // one line with an ellipsis (`:145`).
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              crumb: strings.quizCrumb('John 3:1-5'),
              score: 0,
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

      final Rect headerRect = tester.getRect(find.byType(QuizHeader));
      final Rect crumbRect = tester.getRect(
        find.text(strings.quizCrumb('John 3:1-5')),
      );
      expect(
        crumbRect.width,
        lessThanOrEqualTo(headerRect.width * QuizHeader.crumbMaxWidthFactor),
        reason: '`max-width: 52%` on the `.ttl` (`eva/redesign.html:144`)',
      );
      // Centred in the row, not left-aligned behind the chevron.
      expect(
        crumbRect.center.dx,
        moreOrLessEquals(headerRect.center.dx, epsilon: 1),
      );
    });

    testWidgets('the score is the painted star and the arm\'s digits', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:566` — `✦ 0` in `.mono` with an inline gold override.
      // The star is `FourPointedStar` (U+2726 is in no bundled family) and the
      // ink is `emberInk` — the recorded substitution for the gold. The digits
      // follow the arm, which is why the style is a per-arm function.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              crumb: strings.quizCrumb('John 3:1-5'),
              score: 40,
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

      expect(find.text('40'), findsOneWidget);
      final Text digits = tester.widget<Text>(find.text('40'));
      expect(digits.style?.fontFamily, EvaTypography.monoFamily);
      expect(digits.style?.fontSize, QuizHeader.scoreFontSize);
      expect(
        digits.style?.color,
        EvaThemeDark.theme.extension<EvaColors>()!.emberInk,
      );
      // The star, painted: the widget's own box is the glyph's em box
      // (`FourPointedStar`'s rule), read off the widget rather than a `CustomPaint`
      // find that could match the focus ring's or the ink's painter first.
      final FourPointedStar star = tester.widget<FourPointedStar>(
        find.byType(FourPointedStar),
      );
      expect(star.size, QuizHeader.scoreStarSize);
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
              crumb: AppLocalizationsAr().quizCrumb('يوحنا 3: 1-5'),
              score: 0,
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

    testWidgets('and the back control\'s name is the caller\'s too, in the '
        'right family', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: Scaffold(
            body: QuizHeader(
              crumb: AppLocalizationsAr().quizCrumb('يوحنا 3: 1-5'),
              score: 0,
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

      expect(
        find.bySemanticsLabel(AppLocalizationsAr().quizExit),
        findsOneWidget,
      );
      // The crumb's Arabic run is chrome — the payload's reference rides whole —
      // and the family is the Arabic one under RTL.
      final Text crumb = tester.widget<Text>(
        find.text(AppLocalizationsAr().quizCrumb('يوحنا 3: 1-5')),
      );
      expect(crumb.style?.fontFamily, EvaTypography.arabicFamily);
      handle.dispose();
    });
  });
}
