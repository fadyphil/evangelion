import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/datasources/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:evangelion/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/login_harness.dart';

/// The email field, by order. See `login_harness.dart` for why not by label.
final Finder _emailFinder = find.byType(TextField).at(0);

/// The password field, by order.
final Finder _passwordFinder = find.byType(TextField).at(1);

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

void main() {
  /// Built **inside each test body**, never in `setUp`.
  ///
  /// ## WHY, AND IT IS NOT A STYLE PREFERENCE
  ///
  /// A `Bloc` created in `setUp` does not drive a `testWidgets` tree. `setUp`
  /// runs outside the test body's fake-async zone, so the bloc's event stream is
  /// scheduled on a microtask queue `tester.pump()` never drains: the state
  /// updates and the widget tree does not rebuild. Measured here, and it looks
  /// exactly like a broken screen —
  ///
  /// ```
  /// bloc.state     → passwordError: That password's too short   ✓
  /// find.text(...) → 0 widgets                                  ✗
  /// ```
  ///
  /// A bloc built in the test body behaves. The repository is cheap and
  /// synchronous, so it may live wherever; the bloc is the asynchronous object
  /// and has to be born inside the zone that pumps it.
  LoginFixture buildFixture() {
    final LoginFixture fixture = LoginFixture(
      FakeAuthRepository(AuthLocalDataSource()),
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  group('the screen', () {
    testWidgets('renders the prototype\'s eight elements', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      // The eight things `LoginScreen.tsx:11-99` draws, in the order it draws
      // them. Enumerated rather than "the form is there", because a screen missing
      // one element is still a form.
      expect(find.byType(SealMonogram), findsOneWidget);
      expect(find.text('Evangelion'), findsOneWidget);
      expect(find.text('Read. Reflect. Remember.'), findsOneWidget);
      expect(find.byType(EvaTextField), findsNWidgets(2));
      expect(find.byType(EvaButton), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.byType(HairlineDivider), findsOneWidget);
      expect(find.byType(SocialAuthButton), findsNWidgets(2));
    });

    testWidgets('sits on the login scaffold, scrolled, with the login orbs', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      final NeuralScaffold scaffold = tester.widget<NeuralScaffold>(
        find.byType(NeuralScaffold),
      );

      // `NeuralVariant.login` in both directions. The prototype passes
      // `variant={0}` unconditionally (`LoginScreen.tsx:12`) and there is no
      // Arabic login screen to inherit a different group from — the orb group is a
      // property of the route, not of the language. `login_geometry_test.dart`
      // proves the orbs themselves render under `ar`.
      expect(scaffold.variant, NeuralVariant.login);
      // `LoginScreen.tsx:11` — `overflowY: 'auto'` on the **root**.
      expect(scaffold.scrollable, isTrue);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('carries the prototype\'s gutter, spacers and form metrics', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      // The numbers `LoginScreen.tsx` declares, named once on the page and read
      // from there rather than re-spelled. `login_geometry_test.dart` measures
      // what actually renders; this asserts the page publishes them.
      expect(LoginPage.kRootGutter, 24);
      expect(LoginPage.kTopSpacer, 72);
      expect(LoginPage.kBottomSpacer, 40);
      expect(LoginPage.kBrandGap, 14);
      expect(LoginPage.kBrandBottomGap, 48);
      expect(LoginPage.kWordmarkLineHeight, 1);
      expect(LoginPage.kTaglineTopGap, 6);
      expect(LoginPage.kFormGap, 16);
      expect(LoginPage.kFormPadding, const EdgeInsets.all(24));
      expect(LoginPage.kFormRadius, 28);
      expect(LoginPage.kSignUpRowGap, 6);
    });

    testWidgets('and imposes no height of its own — defect #9', (
      WidgetTester tester,
    ) async {
      // The prototype writes `minHeight: 844` at `LoginScreen.tsx:11`, and
      // `NeuralScaffold` already refuses to. What is left to check here is that
      // the page adds nothing of its own: a `SizedBox` with a big height anywhere in
      // the tree would be the same defect wearing a different name.
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      final List<double> tallBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((SizedBox box) => box.height ?? 0)
          .where((double height) => height > LoginPage.kTopSpacer)
          .toList();

      expect(tallBoxes, isEmpty, reason: 'the page declares no fixed height');
    });
  });

  group('the four inert controls (D3)', () {
    testWidgets(
      'Sign in is the only live control, and it is disabled while the '
      'form is empty',
      (WidgetTester tester) async {
        final LoginFixture fixture = buildFixture();
        await pumpLogin(tester, bloc: fixture.bloc);

        expect(
          tester.widget<EvaButton>(find.byType(EvaButton)).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      '"Forgot password?" and "Create account" have no tap action at all',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final LoginFixture fixture = buildFixture();
        await pumpLogin(tester, bloc: fixture.bloc);

        // §14's disabled row: a control announced as unusable whose action is still
        // present is a control that lies. `TextLink` drops `onTap` when `onPressed` is
        // null; this asserts the **rendered** result rather than the parameter.
        for (final String label in <String>[
          'Forgot password?',
          'Create account',
        ]) {
          final SemanticsData data = semanticsOf(
            tester,
            find.bySemanticsLabel(label),
          ).getSemanticsData();

          expect(data.hasAction(SemanticsAction.tap), isFalse, reason: label);
          expect(
            data.flagsCollection.isEnabled.toBoolOrNull(),
            isFalse,
            reason: label,
          );
        }

        handle.dispose();
      },
    );

    testWidgets('and the social buttons announce why they cannot be pressed', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      // The suffix is the difference between "you cannot press this" and "you
      // cannot press this because there is nothing behind it". Without it the four
      // inert controls are indistinguishable from four broken ones.
      expect(
        find.bySemanticsLabel(RegExp('Continue with Google.*unavailable')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Continue with Apple.*unavailable')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('and tapping them changes nothing', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      // A disabled `EvaTextField`-adjacent control has no handler, so there is
      // nothing to call — but a *gesture* on the coordinates still has to be inert.
      // `warnIfMissed: false` because the hit test is expected to find nothing.
      await tester.tap(find.text('Create account'), warnIfMissed: false);
      await tester.pump();

      expect(fixture.bloc.state.status, AuthSessionStatus.unknown);
      expect(tester.takeException(), isNull);
    });
  });

  group('the form, end to end', () {
    testWidgets('a short password surfaces the prototype\'s message as helper '
        'text — defect #10', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      await tester.enterText(_passwordFinder, 'short');
      await tester.pump();

      // The literal `LoginScreen.tsx:52` wrote into the widget tree is now
      // something the reader caused. This is the Phase-5 verification line.
      expect(find.text("That password's too short"), findsOneWidget);
      expect(fixture.bloc.state.passwordError, "That password's too short");
    });

    testWidgets('a complete form signs in and reports it', (
      WidgetTester tester,
    ) async {
      final List<LoginOutcome> reported = <LoginOutcome>[];
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, onResult: reported.add);

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      expect(fixture.bloc.state.canSubmit, isTrue);

      await tester.tap(find.byType(EvaButton));
      await tester.pumpAndSettle();

      expect(fixture.bloc.state.isSignedIn, isTrue);
      expect(fixture.bloc.state.session?.userId, kSeedUserId);
      expect(reported, <LoginOutcome>[LoginOutcome.signedIn]);
    });

    testWidgets('the password field masks until the toggle is pressed', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      expect(passwordTextField(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byType(PasswordVisibilityToggle));
      await tester.pump();

      expect(passwordTextField(tester).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('the typed text survives a rebuild, because the controller is '
        'the caller\'s', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      await tester.enterText(_emailFinder, 'david@evangelion');
      await tester.enterText(_passwordFinder, 'short');
      await tester.pump();

      // Every keystroke emitted a new state and rebuilt the form. A design-system
      // field that took its text from the bloc would have overwritten the
      // character being typed on each of them.
      expect(find.text('david@evangelion'), findsOneWidget);
      expect(find.text('short'), findsOneWidget);
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
        (_) async => const Result<AuthSession>.failure(
          Failure(
            kind: FailureKind.unauthorized,
            message: 'No such user in this build.',
          ),
        ),
      );
      when(refusing.getCurrentSession).thenAnswer(
        (_) async => const Result<AuthSession>.failure(
          Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
        ),
      );
      when(refusing.signOut)
          .thenAnswer((_) async => const Result<void>.success(null));
      final AuthBloc bloc = AuthBloc(
        signIn: SignIn(refusing),
        getCurrentSession: GetCurrentSession(refusing),
        signOut: SignOut(refusing),
      );
      addTearDown(bloc.close);

      await pumpLogin(tester, bloc: bloc);
      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      await tester.tap(find.byType(EvaButton));
      await tester.pumpAndSettle();

      expect(bloc.state.isSignedIn, isFalse);
      expect(find.text('No such user in this build.'), findsOneWidget);
    });
  });

  group('a null onResult — the route table\'s own trap', () {
    testWidgets('signing in still works, and the page simply comes down', (
      WidgetTester tester,
    ) async {
      // `pushPath('/login')` reaches this page with `onResult == null`: it is the
      // one route with no guard. Phase 4 measured the case; this proves the screen
      // survives it rather than crashing on `onResult!(…)`.
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      await tester.tap(find.byType(EvaButton));
      await tester.pumpAndSettle();

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

      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
      expect(find.text('أنشئ حسابًا'), findsOneWidget);
      expect(find.text('المتابعة عبر Google'), findsOneWidget);
      expect(find.text('اقرأ. تأمل. تذكّر.'), findsOneWidget);

      final BuildContext context = tester.element(
        find.byType(EvaTextField).first,
      );
      expect(
        Directionality.of(context),
        TextDirection.rtl,
        reason: 'the app declares `ar` and Material supplies the direction',
      );
    });

    testWidgets('keeps the orb group, because the variant is the route\'s', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));

      // `NeuralVariant.login` in both directions — see `LoginPage`'s doc. If this
      // ever became language-dependent it would be a second source of truth for one
      // fact, which is the failure `orbGroupFor` documents.
      expect(find.byType(NeuralBackground), findsOneWidget);
      final NeuralBackground background = tester.widget<NeuralBackground>(
        find.byType(NeuralBackground),
      );
      expect(background.variant, NeuralVariant.login);
    });

    testWidgets('the fields are labelled in Arabic, not in English', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));

      expect(find.bySemanticsLabel('البريد الإلكتروني'), findsOneWidget);
      expect(find.bySemanticsLabel('كلمة المرور'), findsOneWidget);

      handle.dispose();
    });
  });
}

/// A port a test can disagree with.
///
/// `FakeAuthRepository` judges the credentials with the **same** `validateLogin` the
/// form uses, so a form-valid submission always succeeds and the error path is
/// unreachable through it. A real adapter will disagree — a wrong password, a
/// network, a server that no longer knows this reader — and the screen has to
/// render that, so it is rendered against the mocked **port** rather than against a
/// subclass (which `FakeAuthRepository`'s `final` forbids anyway, and which would
/// have been a second copy of the repository's rules).
class MockAuthRepository extends Mock implements AuthRepository {}
