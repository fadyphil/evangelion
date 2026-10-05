import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
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
import 'package:evangelion/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:evangelion/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// The numbers `LoginScreen.tsx` declares are published as constants on the page,
/// and they live in `login_geometry_test.dart`'s prototype-linked table.
///
/// ## THE ELEVEN `expect(LoginPage.kX, 24)` ASSERTIONS THAT USED TO BE HERE
///
/// They were deleted rather than kept. Each one re-spelled a prototype number as a
/// bare literal in a suite that has no access to `eva/`, which is a **second,
/// prototype-unlinked copy** of exactly the numbers `login_geometry_test.dart`
/// exists to hold against the file they came from — and the two copies could
/// disagree with nothing noticing. The symbol column there does what these did and
/// more: it joins the number to `LoginScreen.tsx`'s line, so a transcription slip
/// is a red on the *prototype's* citation as well as on the constant.
///
/// One constant was genuinely only covered here: [LoginPage.kSignUpRowGap]. It has
/// no row in that table, so a row was **added** (`LoginScreen.tsx:68`, `gap: 6`)
/// rather than losing the assertion. That is the difference between moving a check
/// and deleting one.
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

    testWidgets('and imposes no height of its own — defect #9', (
      WidgetTester tester,
    ) async {
      // The prototype writes `minHeight: 844` at `LoginScreen.tsx:11`, and
      // `NeuralScaffold` already refuses to. What is left to check here is that
      // **the page** adds nothing of its own.
      //
      // ## THE FIRST VERSION SCANNED `SizedBox` HEIGHTS, AND COULD NOT SEE IT
      //
      // ```dart
      // .map((SizedBox box) => box.height ?? 0)
      // .where((double height) => height > LoginPage.kTopSpacer)
      // ```
      //
      // A `null` height is not a *small* height — it is **no claim at all** — and a
      // page imposes its height without naming one in three ordinary ways: a
      // `SizedBox.expand()`, a `ConstrainedBox` with unbounded height, and a
      // `minHeight` on the root. All three read as "0" above.
      //
      // The two remaining `SizedBox` assertions are kept because they are cheap and
      // they name the two defects precisely — but the load-bearing one is the
      // third, and it is the claim itself rather than a proxy for it.
      //
      // ## WHY THE CLAIM IS ASSERTED OVER THE PAGE'S OWN SUBTREE
      //
      // Every assertion below is scoped to `SingleChildScrollView`'s descendants.
      // Unscoped, two of them fail on **correct** code: `NeuralScaffold`'s ambient
      // background contributes three `ConstrainedBox(BoxConstraints.biggest)` and a
      // `SizedBox.expand()`-shaped layer, and "the background fills the screen" is
      // not "the page imposes a height". Scoped, the check asks the question it
      // means: does the page's own content contain an unbounded height?
      //
      // (An earlier attempt asserted this by measuring the scrollable's
      // `maxScrollExtent + viewportDimension` at two viewport heights. Deleted: with
      // `NeuralScaffold.scrollable`'s `SliverFillRemaining` the extent is
      // viewport-derived, so it read 932 at a 568-tall viewport and 816 at a
      // 932-tall one — a difference caused by the scroll view, not by the page.)
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      final Finder ownContent = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(SizedBox),
      );

      final List<double> declaredHeights = tester
          .widgetList<SizedBox>(ownContent)
          .map((SizedBox box) => box.height)
          .whereType<double>()
          .toList();

      expect(
        declaredHeights.where((double h) => h > LoginPage.kTopSpacer),
        isEmpty,
        reason: 'the page declares no fixed height',
      );
      expect(
        tester
            .widgetList<SizedBox>(ownContent)
            .where((SizedBox box) => box.height == double.infinity),
        isEmpty,
        reason:
            'a `SizedBox.expand()` is a fixed height expressed as infinity, and '
            '`height ?? 0` reads it as no height at all',
      );

      // ## THE `constraints:` ROUTE IS **NOT** COVERED, AND THE LIMIT IS RECORDED
      //
      // A third assertion was written and deleted: `find.byWidgetPredicate((w) =>
      // w is ConstrainedBox && !w.constraints.hasBoundedHeight)`, scoped to the
      // page's own subtree. It found two `ConstrainedBox(BoxConstraints.biggest)`
      // on correct code — one per `TextField`, from inside `EditableText`'s own
      // scrollable — and there is no way to tell those from a `constraints:` the
      // *page* added. A predicate that cannot tell the defect from the framework is
      // not a weaker gate; it is a gate that is either always green or always red.
      //
      // So the honest statement is: `SizedBox(height: …)` and `SizedBox.expand()`
      // are covered, and a page that imposed its height through
      // `constraints:` on some other widget would still pass. The gate catches what
      // a reader would write by hand, which is the case the review raised, and the
      // remaining route is named here rather than left to be discovered.
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

  group('the two placeholders the prototype draws', () {
    // `LoginScreen.tsx:49,51` — `placeholder="you@example.com"` and
    // `placeholder="••••••••"`. Both are on the prototype's `Input` elements and
    // **neither** was transcribed until Phase 5's review: `EvaTextField` had no
    // `hintText` parameter at all, so there was nothing to pass one to. The strings
    // were already in `LoginStrings` — `emailHint` and `passwordHint` — waiting on a
    // parameter that did not exist.
    //
    // Asserted as *rendered text*, not as a parameter, because the parameter would
    // be satisfied by `LoginPage` passing the string into a widget that silently
    // dropped it, which is the whole shape of the omission.
    testWidgets('are drawn in both empty fields', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
    });

    testWidgets('and are Arabic-arm placeholders too, verbatim', (
      WidgetTester tester,
    ) async {
      // Both are the same in either arm, and that is a decision rather than an
      // oversight — `LoginStrings`'s own doc says why: `you@example.com` is not
      // Arabic, and a masked placeholder whose digits changed per locale would
      // re-measure the field on every locale switch.
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc, locale: const Locale('ar'));

      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
    });

    testWidgets('and each disappears the moment there is a character instead', (
      WidgetTester tester,
    ) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      await tester.enterText(_emailFinder, 'david@evangelion.app');
      await tester.pump();
      expect(
        find.text('you@example.com'),
        findsNothing,
        reason:
            'a placeholder under real text is the artefact prototype defect #8 '
            'produced differently — here it would just be clutter',
      );
      expect(
        find.text('••••••••'),
        findsOneWidget,
        reason: 'the password field is still empty',
      );

      await tester.enterText(_passwordFinder, 'correct horse');
      await tester.pump();
      expect(find.text('••••••••'), findsNothing);
    });

    testWidgets('and neither is announced as part of the field\'s name — §14', (
      WidgetTester tester,
    ) async {
      // The reason `EvaTextField` draws the placeholder itself instead of handing
      // it to `InputDecoration.hintText`: Material merges the hint into
      // `EditableText`'s semantics node, so the field's accessible name becomes
      // `"Email" + "\n" + "you@example.com"` and `find.bySemanticsLabel('Email')`
      // matches nothing. Measured. A browser puts only the `<label>` in an
      // `<input>`'s accessible name, so the prototype's own behaviour is the label
      // alone.
      final SemanticsHandle handle = tester.ensureSemantics();
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      expect(find.bySemanticsLabel('Email'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('you@example.com')),
        findsNothing,
        reason: 'the placeholder is drawn, and it is not the field\'s name',
      );

      handle.dispose();
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

  group('a typed run sits where the placeholder was', () {
    // A READER REPORTED THIS, and no assertion in this file would have caught it.
    // `EvaTextField` sets `contentPadding: EdgeInsets.zero` with `isDense: true`,
    // which leaves the `RenderEditable` no vertical inset at all, so a typed line
    // sat at the TOP of the row — while `_Placeholder`, which draws the hint through
    // `Align(AlignmentDirectional.centerStart)`, was centred. Empty fields looked
    // correct because an empty row is one line tall and there is no gap to see; the
    // moment a character arrived, the two disagreed.
    //
    // So this compares the SAME field before and after typing. That framing is the
    // whole point: two rules that are each individually plausible can disagree, and
    // an assertion about the field in isolation ("roughly centred in the viewport")
    // would pass with the bug present on a taller row.
    testWidgets('in the email field', (WidgetTester tester) async {
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      // The hint's distance from the field's own centre, taken first.
      final double hintOffset = _runOffsetFromFieldCentre(
        tester,
        find.text('you@example.com'),
        _emailFinder,
      );

      await tester.enterText(_emailFinder, 'reader@example.com');
      await tester.pump();

      expect(
        _typedRunOffsetFromFieldCentre(tester, _emailFinder),
        closeTo(hintOffset, 1.0),
        reason:
            'the typed run and the hint it replaced must share a vertical '
            'position inside the field, which is '
            '${tester.getSize(_emailFinder).height}px tall here',
      );
    });

    testWidgets('in the password field, whose row carries a trailing toggle', (
      WidgetTester tester,
    ) async {
      // One field is not the other: the password row is taller because of the
      // visibility toggle, so the two have separate geometry.
      final LoginFixture fixture = buildFixture();
      await pumpLogin(tester, bloc: fixture.bloc);

      final double hintOffset = _runOffsetFromFieldCentre(
        tester,
        find.text('••••••••'),
        _passwordFinder,
      );

      await tester.enterText(_passwordFinder, 'correct-horse');
      await tester.pump();

      expect(
        _typedRunOffsetFromFieldCentre(tester, _passwordFinder),
        closeTo(hintOffset, 1.0),
      );
    });
  });
}

/// [run]'s distance from the vertical centre of the [field] containing it.
///
/// Measured from the FIELD's centre rather than as an absolute position, so the
/// number is meaningful without knowing the field's height, and so one helper can
/// describe both a hint and a typed value for comparison.
double _runOffsetFromFieldCentre(
  WidgetTester tester,
  Finder run,
  Finder field,
) => (tester.getRect(run).center.dy - tester.getRect(field).center.dy).abs();

/// The same distance for a **typed** value, which `find.text` cannot locate.
///
/// Both plain and obscured runs are painted by `RenderEditable` rather than by a
/// `Text` widget, so asking for the bullets of an obscured field finds zero
/// widgets — that was the first version of this test and it failed on the
/// password field exactly that way. The caret rect is the honest instrument: it is
/// drawn at the run's own line box, so its position *is* where a reader sees the
/// glyphs, in either obscuring state.
/// The [RenderEditable] inside [editable], which is not the one its finder returns.
///
/// `tester.renderObject(find.byType(EditableText))` yields a
/// `_RenderCompositionCallback`, so casting it to `RenderEditable` throws a
/// `_TypeError` instead of returning null — and `find.byType(RichText)` finds
/// **nothing**, because the run is painted by the editable's own paragraph rather
/// than by a `RichText` widget. Both were tried.
///
/// The real object is a **descendant**: Flutter wraps the editable in a chain of
/// input and semantics layers between the widget and its render object — walked
/// here as `_RenderCompositionCallback → RenderTapRegion → RenderMouseRegion →
/// RenderPointerListener(×2) → RenderSemanticsAnnotations → RenderIgnorePointer →
/// RenderLeaderLayer → _RenderSizeChangedWithCallback → RenderEditable`. The chain
/// is walked rather than hard-coded to a depth, because a hard-coded depth is
/// another number that goes stale when Flutter inserts a layer.
RenderEditable _findRenderEditable(WidgetTester tester, Finder editable) {
  RenderObject? node = tester.renderObject(editable.first);
  while (node != null && node is! RenderEditable) {
    final List<RenderObject> children = <RenderObject>[];
    node.visitChildren(children.add);
    node = children.isEmpty ? null : children.first;
  }
  expect(
    node,
    isA<RenderEditable>(),
    reason: 'no RenderEditable below $editable',
  );
  return node! as RenderEditable;
}

double _typedRunOffsetFromFieldCentre(WidgetTester tester, Finder field) {
  final RenderEditable editable = _findRenderEditable(
    tester,
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  // The caret ahead of the first character; it shares the run's vertical
  // position, which is the property under test.
  final Rect caret = editable.getLocalRectForCaret(
    const TextPosition(offset: 0),
  );
  final Offset centre = editable.localToGlobal(caret.center);
  return (centre.dy - tester.getRect(field).center.dy).abs();
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
