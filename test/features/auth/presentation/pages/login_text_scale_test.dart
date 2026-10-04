import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/login_harness.dart';

/// §14's other requirement on this screen: **"text scales to 1.22× without overflow
/// at 320px width"** — in **both** orientations.
///
/// ## BOTH NUMBERS AND BOTH ORIENTATIONS ARE §14'S, NOT NEGOTIATED
///
/// * `1.22` is [evaScalerFor]'s **largest** step, so this is the top of the range a
///   reader can choose in Settings and not an average.
/// * `320` is the narrowest phone still supported. The *landscape* surface is
///   **not** 320-wide — a 320×568 device turned sideways is 568×320, which is wide
///   and short — so the landscape case is a different problem, not the same one
///   sideways: a vertical stack that fits by scrolling on a tall screen has to fit
///   on a 320-tall one.
///
/// ## LANDSCAPE IS NEW SURFACE WITH NO PHASE-3 PRECEDENT
///
/// `NeuralScaffold` has no landscape layout, `NeuralScaffoldTest` has no landscape
/// golden, and no design document in `docs/plans/` says what `/login` looks like
/// turned sideways. So the claim here is deliberately modest and mechanical: **it
/// does not overflow, and it stays scrollable.** What it looks like is not claimed,
/// because nothing in this repository specifies it.
///
/// ## HOW AN OVERFLOW IS DETECTED
///
/// `RenderFlex` and `RenderParagraph` raise a `FlutterError` through
/// `FlutterError.onError`, which `tester.takeException()` returns. There is no
/// "did it overflow" property, so this is also the only mechanism a reader can
/// trust — and `primitives_text_scale_test.dart` records why the scale must not be
/// tuned to hide a failure.
///
/// ## AND THE NEGATIVE CONTROL
///
/// The last test pumps a column that provably overflows at this scale and asserts
/// [tester.takeException] is non-null. Without it, "no overflow anywhere above" is
/// indistinguishable from "this file detects nothing" — the failure §7 calls "a gate
/// that cannot fail".
void main() {
  AuthBloc buildTestBloc() {
    final FakeAuthRepository repository = FakeAuthRepository(
      AuthLocalDataSource(),
    );
    return AuthBloc(
      signIn: SignIn(repository),
      getCurrentSession: GetCurrentSession(repository),
      signOut: SignOut(repository),
    );
  }

  group('§14 — 1.22× text at 320px, portrait', () {
    testWidgets('the screen does not overflow', (WidgetTester tester) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);

      await pumpLogin(
        tester,
        bloc: bloc,
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );
      // The whole form, not just what is on screen: the content is taller than
      // 568 at this scale, which is why `NeuralScaffold.scrollable` is true and why
      // an overflow inside a `SingleChildScrollView` is a real layout failure rather
      // than a scrolled-off card.
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('nor does it once every field carries its longest error', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(
        tester,
        bloc: bloc,
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );

      // The worst realistic case: both fields in error, so the form grows by two
      // error rows, at the largest text scale, on the narrowest phone. An error
      // message is the longest string on this screen by a wide margin, and it is
      // the one that appears *after* the reader has already typed.
      await tester.enterText(find.byType(TextField).at(0), 'david@');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.pump();
      bloc.add(const AuthSubmitted());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
    });

    testWidgets('and it stays scrollable rather than clipped', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(
        tester,
        bloc: bloc,
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );

      // "No overflow" and "reachable" are different claims. At 1.22× the social
      // buttons are below the fold, so a screen that merely avoids an overflow by
      // clipping them would pass every assertion above and be unusable.
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SocialAuthButton), findsNWidgets(2));
    });
  });

  group('§14 — 1.22× text at 320px, landscape', () {
    // A 320×568 device turned sideways. Wide and **short**, which is the whole
    // difficulty: the vertical stack that scrolls on a tall screen has to fit, or
    // scroll, on 320 logical pixels of height with a keyboard-sized inset above it.
    const Size landscape = Size(568, 320);

    testWidgets('the screen does not overflow', (WidgetTester tester) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);

      await pumpLogin(
        tester,
        bloc: bloc,
        size: landscape,
        textScale: kEvaRequiredTextScale,
        textDirection: TextDirection.rtl,
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'landscape is a different box, not the same one sideways',
      );
    });

    testWidgets('nor does the worst case, and it stays scrollable', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(
        tester,
        bloc: bloc,
        size: landscape,
        textScale: kEvaRequiredTextScale,
        textDirection: TextDirection.rtl,
      );

      await tester.enterText(find.byType(TextField).at(0), 'david@');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.pump();
      bloc.add(const AuthSubmitted());
      await tester.pump();

      expect(tester.takeException(), isNull);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SocialAuthButton), findsNWidgets(2));
    });
  });

  group('the same scale, in the Arabic arm', () {
    // Arabic is longer than English for several of these strings — "المتابعة عبر
    // Apple" is wider than "Continue with Apple" — and §14's row is about *text*,
    // not about one language's text.
    const List<(String, Size)> surfaces = <(String, Size)>[
      ('portrait', kNarrowSurface),
      ('landscape', Size(568, 320)),
    ];

    for (final (String name, Size size) in surfaces) {
      testWidgets('no overflow at 1.22× — $name', (WidgetTester tester) async {
        final AuthBloc bloc = buildTestBloc();
        addTearDown(bloc.close);
        await pumpLogin(
          tester,
          bloc: bloc,
          locale: const Locale('ar'),
          size: size,
          textScale: kEvaRequiredTextScale,
        );

        await tester.enterText(find.byType(TextField).at(0), 'david@');
        await tester.enterText(find.byType(TextField).at(1), 'short');
        await tester.pump();
        bloc.add(const AuthSubmitted());
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'the Arabic arm is longer for several of these strings',
        );
        // Sanity: the toggle's own label is Arabic here, so this is not passing on
        // an English tree.
        expect(find.text('تسجيل الدخول'), findsOneWidget);
      });
    }
  });

  group('the social labels FIT, which is not the same claim as "no overflow"', () {
    // ## WHY THIS GROUP EXISTS, AND IT IS NOT REDUNDANT WITH THE ONE ABOVE
    //
    // Every test above asserts `tester.takeException()` is `null`, and every one of
    // them was satisfiable by a button whose label read **"Continue with Go…"**.
    //
    // The mechanism: `SocialAuthButton` renders `maxLines: 1` with
    // `TextOverflow.ellipsis`, so an over-wide label clips its own **string**.
    // `RenderFlex` never overflows, so no `FlutterError` is raised, so
    // `takeException()` is `null`. §14's row — "text scales to 1.22× without
    // overflow at 320px width" — was being satisfied by deleting the reader's
    // words, and the negative control at the bottom of this file proves the suite
    // detects overflow and that **nothing here detected truncation**.
    //
    // Measured at this surface before the fix, with the real `pumpLogin` and a
    // `TextPainter` over the real style:
    //
    // ```
    // available inner width                 192.0
    // "Continue with Google"  @ titleMedium (16sp)  201.63  -> clipped by  9.63
    // "المتابعة عبر Google"  @ titleMedium (16sp)  193.34  -> clipped by  1.34
    // ```
    //
    // The English label truncated *more* than the Arabic, which is the opposite of
    // this file's own stated intuition ("Arabic is longer than English for several
    // of these strings"). `SocialAuthButton` moved to `bodyMedium` (14sp) as a
    // result; these assertions hold it there.

    /// The widest the label may be: the button's own width less the horizontal
    /// inset `SocialAuthButton` applies on each side.
    double availableWidth(WidgetTester tester) =>
        tester.getSize(find.byType(SocialAuthButton).first).width -
        2 * EvaSpacing.lg;

    for (final (String name, Locale locale, String longest)
        in <(String, Locale, String)>[
          ('English', const Locale('en'), 'Continue with Google'),
          ('Arabic', const Locale('ar'), 'المتابعة عبر Google'),
        ]) {
      testWidgets('the $name label is not ellipsised', (
        WidgetTester tester,
      ) async {
        final AuthBloc bloc = buildTestBloc();
        addTearDown(bloc.close);
        await pumpLogin(
          tester,
          bloc: bloc,
          locale: locale,
          size: kNarrowSurface,
          textScale: kEvaRequiredTextScale,
        );

        final Finder label = find.descendant(
          of: find.byType(SocialAuthButton).first,
          matching: find.byType(Text),
        );
        final Text widget = tester.widget<Text>(label);
        expect(
          widget.data,
          longest,
          reason: 'the fixture is wrong if this is not the longest label',
        );

        // The **rendered** width, not a `TextPainter`'s: a `TextPainter` over the
        // style would measure the text the widget *would* draw, and the claim under
        // test is about the width the widget actually gave it. `maxLines: 1` plus an
        // ellipsis means the rendered box is capped at the constraint and says
        // nothing about whether anything was dropped — so the style is measured
        // directly and compared against the box.
        final double rendered = tester.getSize(label).width;
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.data, style: widget.style),
          textDirection: Directionality.of(tester.element(label)),
          maxLines: 1,
        )..layout();
        final double intrinsic = painter.width;

        expect(
          intrinsic,
          lessThanOrEqualTo(availableWidth(tester)),
          reason:
              '"${widget.data}" wants $intrinsic and the box offers '
              '${availableWidth(tester)}. An ellipsis keeps this test\'s siblings '
              'green while deleting the reader\'s words',
        );
        expect(
          rendered,
          greaterThanOrEqualTo(intrinsic),
          reason:
              'the painted box is narrower than the words need, so the label was '
              'clipped — the `maxLines: 1` case the assertion above rules out',
        );
      });
    }
  });

  group('the negative control, so the gate is known to bite', () {
    testWidgets('a column that provably overflows is detected', (
      WidgetTester tester,
    ) async {
      await pumpLogin(
        tester,
        bloc: buildTestBloc(),
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
        child: const Column(
          children: <Widget>[SizedBox(height: 600), SizedBox(height: 600)],
        ),
      );
      addTearDown(tester.takeException);

      expect(
        tester.takeException(),
        isNotNull,
        reason:
            'without this, every "no overflow" above is indistinguishable from a '
            'file that detects nothing',
      );
    });
  });
}
