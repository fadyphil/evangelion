import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

      await pumpLogin(tester, bloc: bloc, textScale: kEvaRequiredTextScale);
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
      await pumpLogin(tester, bloc: bloc, textScale: kEvaRequiredTextScale);

      // The worst realistic case: both fields in error, so the form grows by two
      // error rows, at the largest text scale, on the narrowest phone. An error
      // message is the longest string on this screen by a wide margin, and it is
      // the one that appears *after* the reader has already typed.
      await tester.enterText(find.byType(TextField).at(0), 'david@');
      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tester.pump();
      bloc.add(const AuthSubmitted());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
    });

    testWidgets('and everything is on screen, scroll or no scroll', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, textScale: kEvaRequiredTextScale);

      // "No overflow" and "reachable" are different claims. The old screen was
      // taller than the viewport at this scale and proved it *scrolled*; the
      // redesign's login is compact enough that at 1.22× on the narrowest phone
      // it measures `maxScrollExtent == 0` — everything is already on screen.
      // The assertion is therefore: the ghosts are inside the viewport's bounds
      // (not clipped, not scrolled off), and the centre-or-scroll wrapper is
      // there for the day the content grows again.
      tester.state<ScrollableState>(find.byType(Scrollable).first);

      final Size surface =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final Rect viewport = Offset.zero & surface;
      for (final String ghost in <String>[
        LoginPage.kGhostGoogle,
        LoginPage.kGhostApple,
      ]) {
        final Rect rect = tester.getRect(find.text(ghost));
        expect(
          viewport.contains(rect.topLeft) &&
              viewport.contains(rect.bottomRight),
          isTrue,
          reason: '$ghost is on screen at 1.22×, not clipped below the fold',
        );
      }

      expect(tester.takeException(), isNull);
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
      await tester.enterText(find.byType(TextField).at(1), 'abc');
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
      expect(find.byType(EvaButton), findsNWidgets(3));
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
        await tester.enterText(find.byType(TextField).at(1), 'abc');
        await tester.pump();
        bloc.add(const AuthSubmitted());
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'the Arabic arm is longer for several of these strings',
        );
        // Sanity: the CTA's label is the redesign's translated control, so this
        // is not passing on an English tree.
        expect(find.text('ادخل الكلمة'), findsOneWidget);
      });
    }
  });

  group('the CTA label FITS, which is not the same claim as "no overflow"', () {
    // ## WHY THIS GROUP EXISTS, AND IT IS NOT REDUNDANT WITH THE ONE ABOVE
    //
    // Every test above asserts `tester.takeException()` is `null`, and every one of
    // them was satisfiable by a button whose label read **"enter the wo…"**.
    //
    // The mechanism: `EvaButton` renders its label with `maxLines: 2` and
    // `TextOverflow.ellipsis`, so an over-wide label clips its own **string**.
    // `RenderFlex` never overflows, so no `FlutterError` is raised, so
    // `takeException()` is `null`. §14's row — "text scales to 1.22× without
    // overflow at 320px width" — was being satisfiable by deleting the reader's
    // words, and the negative control at the bottom of this file proves the suite
    // detects overflow and that nothing else detected truncation. The CTA is the
    // screen's longest button label in both arms (`redesign.html:508`), so it is
    // the one this assertion holds.

    /// The widest the label may be: the button's own width.
    double availableWidth(WidgetTester tester) =>
        tester.getSize(find.byType(EvaButton).first).width;

    for (final (String name, Locale locale, String longest)
        in <(String, Locale, String)>[
          ('English', const Locale('en'), 'enter the word'),
          ('Arabic', const Locale('ar'), 'ادخل الكلمة'),
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
          textScale: kEvaRequiredTextScale,
        );

        final Finder ctaButton = find.ancestor(
          of: find.text(longest),
          matching: find.byType(EvaButton),
        );
        final Finder label = find.text(longest);
        final Text widget = tester.widget<Text>(label);
        expect(
          widget.data,
          longest,
          reason: 'the fixture is wrong if this is not the longest label',
        );
        expect(ctaButton, findsOneWidget);

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

  group('the role picker\'s labels FIT, in both arms', () {
    // ## WHY THIS GROUP EXISTS, AND IT IS THE SAME REASON AS THE CTA'S
    //
    // A `SegmentedControl` segment clips its own label: `maxLines: 1` plus
    // `TextOverflow.ellipsis`, so an over-wide label is **silently shortened**
    // and `RenderFlex` never overflows — `takeException()` stays `null` and
    // every "no overflow" test above stays green while the reader reads
    // "SERVAN…".
    //
    // The role picker's labels are the **widest** thing on this screen that is
    // not the CTA, and the default geometry of `SegmentedControl` **does**
    // ellipsise "SERVANT" at 320px and 1.22× — measured, not reasoned, and
    // the reason the picker uses the wide geometry. This group is what keeps
    // that from regressing, and it measures the **scaled** text: a `TextPainter`
    // over the unscaled style would compare a 12sp word against a 1.22× box and
    // call it a fit.

    for (final (String name, Locale locale, List<String> labels)
        in <(String, Locale, List<String>)>[
          ('English', const Locale('en'), <String>['KID', 'SERVANT', 'ADMIN']),
          ('Arabic', const Locale('ar'), <String>['طفل', 'خادم', 'مُشرف']),
        ]) {
      testWidgets('the $name labels are not ellipsised', (
        WidgetTester tester,
      ) async {
        final AuthBloc bloc = buildTestBloc();
        addTearDown(bloc.close);
        await pumpLogin(
          tester,
          bloc: bloc,
          locale: locale,
          textScale: kEvaRequiredTextScale,
        );
        await tester.pump(const Duration(milliseconds: 1200));

        for (final String label in labels) {
          final Finder finder = find.text(label);
          expect(
            finder,
            findsOneWidget,
            reason: 'the "$label" segment is drawn',
          );

          // The **effective** style, not `Text.style` — the `Text` inside a
          // segment declares none, so its own `style` is `null` and a painter
          // built from it would measure the *default* font at the *default*
          // size, which is the test runner's square font and about twice as
          // wide. The rendered paragraph carries the merged style.
          final RenderParagraph paragraph = tester
              .renderObject<RenderParagraph>(finder);
          final TextStyle style =
              paragraph.text.style ?? const TextStyle(fontSize: 12);
          final TextPainter painter = TextPainter(
            text: TextSpan(
              text: paragraph.text.toPlainText(),
              // **The scale applied**, because the box it is measured against is
              // a 1.22× box.
              style: style.copyWith(
                fontSize: style.fontSize! * kEvaRequiredTextScale,
              ),
            ),
            textDirection: Directionality.of(tester.element(finder)),
            maxLines: 1,
          )..layout();

          final double rendered = tester.getSize(finder).width;
          expect(
            rendered,
            greaterThanOrEqualTo(painter.width),
            reason:
                '"$label" wants ${painter.width}px and the box offers '
                '${rendered}px. An ellipsis keeps this file\'s other tests green '
                'while deleting the reader\'s words',
          );
        }
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
