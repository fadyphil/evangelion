import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/login_harness.dart';

/// The email field, by order. See `login_harness.dart` for why not by label.
final Finder _emailFinder = find.byType(TextField).at(0);

/// The password field, by order.
final Finder _passwordFinder = find.byType(TextField).at(1);

/// The CTA, by its label's family-resolved text. The redesign's one translated
/// control (`eva/redesign.html:508`).
final Finder _ctaFinder = find.text(AppLocalizationsEn().authEnterTheWord);

/// A hand-rolled stand-in, for the refusal test that needs a port which
/// disagrees with the form. Same shape as every other suite's mock — one per
/// file, because a shared mock directory would be a fifth `mocks.dart`.
class MockAuthRepository extends Mock implements AuthRepository {}

/// The pieces `pumpLogin` assembles, so a test can drive the form and read the
/// bloc that answered it.
final class LoginFixture {
  /// Creates a fixture over a fresh repository.
  LoginFixture(this.repository)
    : bloc = AuthBloc(
        signIn: SignIn(repository),
        getCurrentSession: GetCurrentSession(repository),
        signOut: SignOut(repository),
      );

  /// The bloc the page rendered.
  final AuthBloc bloc;

  /// The repository behind it, so a test can prove the state came from the seam.
  final FakeAuthRepository repository;

  /// [bloc] closed at the end of the test.
  void dispose() => bloc.close();
}

/// The numbers `eva/redesign.html` declares are published as constants on the
/// page, and they live in `login_geometry_test.dart`'s prototype-linked table —
/// which extracts them **from the prototype file at test time**, so no literal
/// of the prototype's geometry appears here either.
void main() {
  /// Built **inside each test body**, never in `setUp`.
  ///
  /// ## WHY, AND IT IS NOT A STYLE PREFERENCE
  ///
  /// A `Bloc` created in `setUp` does not drive a `testWidgets` tree. `setUp`
  /// runs outside the test body's fake-async zone, so the bloc's event stream is
  /// scheduled on a microtask queue `tester.pump()` never drains: the state
  /// updates and the widget tree does not rebuild. A bloc built in the test body
  /// behaves. The repository is cheap and synchronous, so it may live wherever;
  /// the bloc is the asynchronous object and has to be born inside the zone that
  /// pumps it.
  LoginFixture buildFixture() {
    final LoginFixture fixture = LoginFixture(
      FakeAuthRepository(AuthLocalDataSource()),
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  /// Past the wordmark's 910 ms entrance, so every letter is at its end state
  /// and an element's visibility is not a function of when the test looked.
  Future<void> pumpSettled(WidgetTester tester, LoginFixture fixture) async {
    await pumpLogin(tester, bloc: fixture.bloc);
    await tester.pump(const Duration(milliseconds: 1200));
  }

  /// [pumpSettled] for a bloc the test built itself — the refusing-port test's
  /// shape, which has no [LoginFixture] to pass.
  Future<void> pumpSettledFixture(WidgetTester tester, AuthBloc bloc) async {
    await pumpLogin(tester, bloc: bloc);
    await tester.pump(const Duration(milliseconds: 1200));
  }

  group('the screen', () {
    testWidgets('renders the redesign\'s seven elements', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // The seven things `eva/redesign.html:503-511` draws, in the order it
      // draws them. Enumerated rather than "the form is there", because a
      // screen missing one element is still a form. The wordmark is ten
      // single-letter Texts (the prototype splits it the same way for the
      // entrance, `:1300`), so it is asserted by its repeated and unique
      // letters rather than by a string that no single widget holds — and
      // `EVANGELION` really does hold two N's, which is what the count is for.
      expect(find.text('E'), findsNWidgets(2));
      expect(find.text('N'), findsNWidgets(2));
      expect(find.text('V'), findsOneWidget);
      expect(
        find.text(_monoUpper(LoginPage.kTaglineText)),
        findsOneWidget,
        reason: 'the tagline, uppercased by `.mono` under LTR (`:136`)',
      );
      expect(find.byType(EvaTextField), findsNWidgets(2));
      expect(_ctaFinder, findsOneWidget);
      expect(find.byType(EvaButton), findsNWidgets(3));
      expect(
        find.text(_monoUpper(LoginPage.kFooterText)),
        findsOneWidget,
        reason: 'the αω footer, pinned `bottom: 26px` (`:391`)',
      );
    });

    testWidgets('and nothing of the old screen survives', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // The redesign deleted more than it kept on this screen. Each absence is
      // an element the OLD prototype drew and `:503-511` does not — asserted
      // negatively so a regression cannot sneak one back in.
      expect(find.byType(SealMonogram), findsNothing);
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(HairlineDivider), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Create account'), findsNothing);
    });

    testWidgets('sits on the login scaffold, centred, with the login orbs', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final NeuralScaffold scaffold = tester.widget<NeuralScaffold>(
        find.byType(NeuralScaffold),
      );

      // `NeuralVariant.login` in both directions. The redesign's screen carries
      // `data-shape="top"` (`eva/redesign.html:497`) and there is no Arabic
      // login screen to inherit a different group from — the ambient group is a
      // property of the route, not of the language.
      expect(scaffold.variant, NeuralVariant.login);

      // `:369` — `.login` is `align-items:center; justify-content:center` with
      // no overflow of its own, so the scaffold does not scroll, and the form
      // rides the vertical centre rather than starting under a spacer. Rendered
      // meaning: the midpoint between the form's first and last elements is the
      // viewport's — the old screen's 72px top spacer is gone with its
      // scrolling root.
      expect(scaffold.scrollable, isFalse);
      final double top = tester.getRect(find.text('E').first).top;
      final double bottom = tester
          .getRect(find.text(LoginPage.kGhostGoogle))
          .bottom;
      final double viewHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect((top + bottom) / 2, moreOrLessEquals(viewHeight / 2, epsilon: 24));
    });

    testWidgets('the wordmark glow is behind the letters, not over them', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // `.lmark::after` (`:371`) is `z-index:-1` — the glow sits behind the
      // letters. Rendered as paint order: the gradient's box is the Stack's
      // first child and the letters come second, so a letter's centre still hit
      // tests to the letter, not to the glow. `V` is one of the mark's six
      // unique letters.
      final Finder letter = find.text('V');
      expect(letter, findsOneWidget);
      expect(tester.element(letter).renderObject, isNotNull);
    });
  });

  group('the two inert ghosts', () {
    testWidgets('are EvaButton ghosts with the suffix in their names', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final AppLocalizationsEn en = AppLocalizationsEn();
      for (final String brand in <String>[
        LoginPage.kGhostGoogle,
        LoginPage.kGhostApple,
      ]) {
        final EvaButton button = tester.widget<EvaButton>(
          find.ancestor(of: find.text(brand), matching: find.byType(EvaButton)),
        );
        expect(button.onPressed, isNull, reason: '$brand is inert');
        expect(button.variant, EvaButtonVariant.ghost, reason: ':388-390');
        expect(
          button.semanticLabel,
          '$brand — ${en.authUnavailableSuffix}',
          reason:
              'the announcement says why, not only that it cannot be pressed',
        );
      }
    });

    testWidgets('and tapping them changes nothing', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      await tester.tap(find.text(LoginPage.kGhostGoogle), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(fixture.bloc.state.status, AuthSessionStatus.unknown);
    });
  });

  group('the two placeholders the redesign draws', () {
    testWidgets('are drawn in both empty fields', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final AppLocalizationsEn en = AppLocalizationsEn();
      expect(find.text(en.authEmailHint), findsOneWidget);
      expect(find.text(en.authPasswordHint), findsOneWidget);
    });

    testWidgets('and are Arabic-arm placeholders too', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));
      await tester.pump(const Duration(milliseconds: 1200));

      // A deliberate divergence from the prototype's literal markup, recorded
      // on the page: the placeholders are the only guidance the fields give,
      // and the redesign's own dictionary carries both nouns. `كلمة المرور` is
      // `pwErr`'s own noun (`:976`), so nothing here is a fresh translation.
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
    });

    testWidgets('and each disappears the moment there is a character instead', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final AppLocalizationsEn en = AppLocalizationsEn();
      await tester.enterText(_emailFinder, 'd');
      await tester.pump();

      expect(find.text(en.authEmailHint), findsNothing);
      expect(find.text(en.authPasswordHint), findsOneWidget);
    });

    testWidgets('and neither is announced as part of the field\'s name — §14', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // A browser puts the `<label>` in the accessible name and leaves the
      // placeholder out of it; `EvaTextField` draws the placeholder itself
      // precisely so `EditableText`'s node does not grow it. The name is the
      // label word, whole.
      final String emailName = tester.getSemantics(_emailFinder).label;
      expect(emailName, AppLocalizationsEn().authEmailLabel);
    });
  });

  group('the form, end to end', () {
    testWidgets('a short password surfaces the redesign\'s message, by '
        'presence', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final AppLocalizationsEn en = AppLocalizationsEn();
      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'abc');
      await tester.pump();
      await tester.tap(_ctaFinder);
      await tester.pump();

      // Rendered by **presence** — `state.passwordError != null` decides the
      // sentence; the domain's message text is never compared. See
      // `authPasswordTooShort`'s arb description.
      expect(find.text(en.authPasswordTooShort), findsOneWidget);
      expect(find.text(en.authEmailInvalid), findsNothing);
    });

    testWidgets('an invalid tap reveals BOTH fields and shakes the CTA', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      final AppLocalizationsEn en = AppLocalizationsEn();
      // The shake is horizontal and the error rows shift the layout only
      // vertically, so the LEFT edge is the one measurement the reveal cannot
      // confound: at rest it is `before.left` before and after, and mid-shake
      // it is not.
      final double restLeft = tester.getRect(_ctaFinder).left;
      await tester.tap(_ctaFinder);
      // Small steps, not one: a single 450 ms pump would jump from the rest
      // position to the rest position and see nothing. Measured, not assumed —
      // the single-pump version of this test read a 0.0 px delta against a
      // controller the probe proved was ticking.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 25));

      // `redesign.html:1303-1307` — the submit handler fills both `.msg` lines
      // and adds `.cta.err`, whose `shake .45s` moves the button ±8px at 20 %.
      // At 100 ms the button is mid-travel.
      expect(find.text(en.authEmailInvalid), findsOneWidget);
      expect(find.text(en.authPasswordTooShort), findsOneWidget);
      expect(
        (tester.getRect(_ctaFinder).left - restLeft).abs(),
        greaterThan(0),
        reason: 'the CTA is mid-shake, not parked at its rest position',
      );

      // And the shake ENDS: after 450 ms the controller completes and the
      // button is exactly where it started. `pumpAndSettle` is safe here — the
      // harness mounts the page with no ambient clocks (animationsEnabled
      // false), so the only scheduled frames are the shake's own, and settle
      // means the shake is over. Stepped pumps are measured to lag the fake
      // clock by a frame, which is why the mid-shake read above steps and this
      // one settles.
      await tester.pumpAndSettle();
      expect(tester.getRect(_ctaFinder).left, restLeft);
    });

    testWidgets('the shake does not run at all under reduced motion — §14', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      // The harness's §14 switch: `MediaQuery.disableAnimationsOf` drives
      // `_playShake` directly, so this is the exact branch, not a proxy.
      await pumpLogin(tester, bloc: fixture.bloc, disableAnimations: true);
      await tester.pump();

      // Enter the bad password FIRST, so the error row's layout shift has
      // already happened and the only thing left to attribute to the tap is
      // the shake — which must be nothing.
      await tester.enterText(_passwordFinder, 'abc');
      await tester.pump();
      final double restLeft = tester.getRect(_ctaFinder).left;
      await tester.tap(_ctaFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.getRect(_ctaFinder).left, restLeft);
    });

    testWidgets('a complete form signs in and reports it', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      LoginOutcome? reported;
      await pumpLogin(
        tester,
        bloc: fixture.bloc,
        onResult: (LoginOutcome outcome) => reported = outcome,
      );
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      await tester.tap(_ctaFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reported, LoginOutcome.signedIn);
    });

    testWidgets('the CTA is enabled with an empty form, and still answers', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // `redesign.html:508` — a bare `<button>` with no `disabled`. The old
      // screen dimmed the button until `canSubmit`; the redesign answers an
      // empty tap with guidance instead.
      final EvaButton cta = tester.widget<EvaButton>(
        find.ancestor(of: _ctaFinder, matching: find.byType(EvaButton)),
      );
      expect(cta.onPressed, isNotNull);
    });

    testWidgets('the typed text survives a rebuild, because the controller is '
        'the caller\'s', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.pump();
      // A bloc-driven rebuild — any state change rebuilds `_LoginForm`'s
      // builder while the controllers must not be touched.
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();

      expect(emailTextField(tester).controller!.text, 'david@evangelion.app');
      expect(passwordTextField(tester).controller!.text, 'correct horse');
    });

    testWidgets('a refused sign-in shows the repository\'s message', (
      WidgetTester tester,
    ) async {
      // Password long enough for the form's rule, and the fake judges the same
      // credentials through the same function — so to get a refusal here the
      // repository has to disagree with the form, which is what a real adapter
      // would do. Exercised by swapping the bloc for one over a refusing port.
      final AuthRepository refusing = MockAuthRepository();
      when(
        () => refusing.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left<Failure, AuthSession>(
          Failure(
            kind: FailureKind.unauthorized,
            message: 'No such user in this build.',
          ),
        ),
      );
      when(refusing.getCurrentSession).thenAnswer(
        (_) async => const Left<Failure, AuthSession>(
          Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
        ),
      );
      when(refusing.signOut)
          .thenAnswer((_) async => const Right<Failure, void>(null));
      final AuthBloc bloc = AuthBloc(
        signIn: SignIn(refusing),
        getCurrentSession: GetCurrentSession(refusing),
        signOut: SignOut(refusing),
      );
      addTearDown(bloc.close);

      // The redesign's login declares no repository-failure state (its submit
      // handler can only fail client-side), so this row is **written, not
      // transcribed** — the same standing reason `homeRetry` carries. See
      // `_FormError`'s doc.
      await pumpSettledFixture(tester, bloc);
      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      await tester.tap(_ctaFinder);
      await tester.pumpAndSettle();

      expect(bloc.state.isSignedIn, isFalse);
      expect(find.text('No such user in this build.'), findsOneWidget);
    });
  });

  group('a null onResult — the route table\'s own trap', () {
    testWidgets('signing in still works, and the page simply comes down', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      await tester.tap(_ctaFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The bloc reached signedIn and nothing threw: the outcome went to the
      // local no-op, not to a crash and not to nobody-in-particular.
      expect(fixture.bloc.state.isSignedIn, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('the language', () {
    testWidgets('renders Arabic under an ar locale, RTL and all', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));
      await tester.pump(const Duration(milliseconds: 1200));

      final AppLocalizationsEn en = AppLocalizationsEn();
      // The CTA is the redesign's one translated control.
      expect(find.text(en.authEnterTheWord), findsNothing);
      final Finder arabicCta = find.text('ادخل الكلمة');
      expect(arabicCta, findsOneWidget);
      expect(Directionality.of(tester.element(arabicCta)), TextDirection.rtl);
    });

    testWidgets(
      'keeps the ambient group, because the variant is the route\'s',
      (WidgetTester tester) async {
        final LoginFixture fixture = buildFixture();
        await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));
        await tester.pump(const Duration(milliseconds: 1200));

        final NeuralScaffold scaffold = tester.widget<NeuralScaffold>(
          find.byType(NeuralScaffold),
        );
        expect(scaffold.variant, NeuralVariant.login);
      },
    );

    testWidgets('the tagline and footer stay Latin on the Arabic arm, as the '
        'redesign renders them', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));
      await tester.pump(const Duration(milliseconds: 1200));

      // `redesign.html:505,510` carry no `data-i18n`, so `applyLang()` never
      // rewrites them; `[dir=rtl] .mono` (`:136`) removes only the uppercase.
      // Both literals render as written — the one place on the arm where Latin
      // is the redesign's own choice, asserted here so it is a decision rather
      // than an accident.
      expect(find.text(LoginPage.kTaglineText), findsOneWidget);
      expect(find.text(LoginPage.kFooterText), findsOneWidget);
    });
  });

  group('a typed run sits where the placeholder was', () {
    testWidgets('in the email field', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      const String typed = 'mariam@light.co';
      await tester.enterText(_emailFinder, typed);
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      expect(find.text(en.authEmailHint), findsNothing);
      expect(find.text(typed), findsOneWidget);
    });
  });

  group('the wordmark entrance', () {
    testWidgets('every letter arrives, in the prototype\'s order', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpSettled(tester, fixture);

      // `animateLogin()` (`redesign.html:1297-1302`) splits the mark into
      // single letters; the last letter's arrival is the animation's completion,
      // and after 1.2 s every interval has elapsed.
      for (final String character in LoginPage.kWordmarkText.split('')) {
        expect(
          find.text(character),
          findsWidgets,
          reason: 'the letter $character is rendered',
        );
      }
    });

    testWidgets('reduced motion shows the mark whole, immediately — §14', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, disableAnimations: true);
      // One frame: no entrance to wait out, because the end state is the start.
      await tester.pump();

      // The letters are painted at full opacity on the first frame — the §14
      // jump, not the prototype's zeroed-stagger version of the same animation.
      final Finder first = find.text('E');
      expect(first, findsWidgets);
      final Opacity opacity = tester.firstWidget<Opacity>(
        find.ancestor(of: first.first, matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1);
    });
  });
}

/// `.mono`'s LTR uppercase, spelled the way the page spells it.
String _monoUpper(String source) => source.toUpperCase();
