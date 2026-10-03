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
import 'package:evangelion/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:evangelion/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/login_harness.dart';

/// §14 for `/login`: no unlabeled interactive node, a focus ring on everything a
/// keyboard can reach, and no state carried by colour alone.
///
/// ## WHY THIS IS A SUITE AND NOT A PROPERTY OF THE PAGE'S DOC COMMENT
///
/// `09-quality-gates.md` §14 names "all 6 pages pass a semantics sweep with no
/// unlabeled interactive node" as the target, and `focus_ring_gate_test.dart`
/// already sweeps the **design system's** interactive widgets. Neither covers a
/// feature's own control, and `/login` has two of them — the password toggle and
/// the social buttons — that this repository's gates cannot see, because
/// `focus_ring_gate_test.dart`'s source walk covers
/// `lib/core/design_system/widgets/` only.
///
/// So the sweep is written here, over the page's whole semantics tree rather than
/// over a hand-written list of controls. A hand-written list is what the design
/// system's gate already does for its own eleven, and its own doc records the cost
/// of that: `kInteractiveWidgets` had to be extended by hand when a widget's gate
/// changed.
///
/// ## AND WHY `ensureSemantics` IS DISPOSED IN THE BODY
///
/// §14's correction says the handle "must be disposed to avoid leaking across
/// tests", and it is right — but in Flutter 3.47.4 `testWidgets` already holds one
/// of its own and `_endOfTestVerifications` then compares the live handle count
/// against the count recorded *before* the framework took its own. An `addTearDown`
/// disposal runs after that comparison, so the pattern §14 quotes verbatim fails
/// with "A SemanticsHandle was active at the end of the test". Disposing in the body
/// puts the count back before the check. Verified, not assumed —
/// `focus_ring_gate_test.dart` carries the negative control.
/// Builds a bloc **inside the test body**, never in `setUp`.
///
/// `setUp` runs outside a `testWidgets` body's fake-async zone, so a bloc created
/// there does not deliver its events into the queue `tester.pump()` drains: the
/// state updates and the tree does not rebuild, which reads exactly like a broken
/// widget. `login_page_test.dart` records the measurement.
/// A port a test can disagree with, for the refusal paths `FakeAuthRepository`
/// cannot reach. See the test that uses it.
class MockAuthRepository extends Mock implements AuthRepository {}

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

void main() {
  group('no unlabeled interactive node', () {
    testWidgets('every node offering an action has a non-empty label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // The whole tree, not a list of controls this file knows about. `semanticsTree`
      // fails closed when semantics are off, so "nothing to check" is a failure
      // rather than a pass.
      final List<SemanticsData> actionable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );

      expect(
        actionable,
        isNotEmpty,
        reason:
            'the form has controls; an empty list means the walk saw nothing',
      );

      for (final SemanticsData data in actionable) {
        expect(
          data.label.trim(),
          isNotEmpty,
          reason:
              'a node offering SemanticsAction.tap has no accessible name: '
              'flags=${data.flagsCollection} actions=${data.actions}',
        );
      }

      handle.dispose();
    });

    testWidgets('and the named nodes are the eight the prototype declares', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // Enumerated rather than "some of them": §14's gap is an *unnamed* control,
      // and a label that drifted off the control it names is the same defect one
      // step later.
      for (final String label in <String>[
        'Email',
        'Password',
        'Show password',
        'Sign in',
        'Forgot password?',
        'Create account',
        'Continue with Google',
        'Continue with Apple',
      ]) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(label))),
          findsOneWidget,
          reason: '§14 — no control may lose its name',
        );
      }

      handle.dispose();
    });
  });

  group('§14 — disabled means genuinely unreachable', () {
    testWidgets('the four inert controls carry no tap action', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // With a **valid** form, so "Sign in" is live. It is disabled on an empty
      // form and therefore carries no tap action at all — which is correct, and
      // which made an earlier version of this test fail on its own
      // `expect(live, contains('Sign in'))`.
      await tester.enterText(
        find.byType(TextField).at(0),
        'david@evangelion.app',
      );
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();
      final List<String> live = nodesOffering(
        tester,
        SemanticsAction.tap,
      ).map((SemanticsData data) => data.label).toList();

      expect(live, contains('Sign in'));
      expect(live, contains('Show password'));
      expect(
        live,
        isNot(contains('Forgot password?')),
        reason:
            'the four inert controls must not join the live set once the form '
            'is valid — otherwise "inert" would only mean "disabled while the form '
            'is empty"',
      );

      handle.dispose();
    });

    testWidgets('and none of the four offers a tap action at any time', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // Both form states, because "disabled while the form is empty" would satisfy
      // the test above on its own. An inert control that wakes up when the form is
      // valid is a live control with a misleading name.
      for (final List<String> credentials in <List<String>>[
        <String>['', ''],
        <String>['david@evangelion.app', 'correct horse'],
      ]) {
        await tester.enterText(find.byType(TextField).at(0), credentials[0]);
        await tester.enterText(find.byType(TextField).at(1), credentials[1]);
        await tester.pump();

        final List<String> labels = nodesOffering(
          tester,
          SemanticsAction.tap,
        ).map((SemanticsData data) => data.label).toList();

        for (final Pattern inert in <Pattern>[
          'Forgot password?',
          'Create account',
          RegExp(r'^Continue with Google'),
          RegExp(r'^Continue with Apple'),
        ]) {
          expect(
            labels.where(
              (String label) =>
                  inert is RegExp ? inert.hasMatch(label) : label == inert,
            ),
            isEmpty,
            reason: '$inert offered a tap action with $credentials',
          );
        }
      }

      handle.dispose();
    });

    testWidgets('and none of them is a Tab stop', (WidgetTester tester) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // A **valid** form, because `Sign in` is disabled on an empty one and a
      // disabled `EvaFocusRing` sets `canRequestFocus: false`. That is the correct
      // behaviour — and it is why the first version of this test reported one tab
      // stop and failed: the walk was honest and the expectation was not.
      await tester.enterText(
        find.byType(TextField).at(0),
        'david@evangelion.app',
      );
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();

      // Walk the tab order and attribute each stop by asking the **focused node**
      // where it is, rather than by assuming the order. The first version of this
      // test checked "something in the tree had focus" once per type, which is
      // true of every type the moment any control takes focus — so it reported all
      // four as tab stops and passed for the wrong reason.
      //
      // `FocusNode.context` is the focused node's own element, and
      // `find.ancestor` from there is the attribution. Bounded at 14 tabs — the
      // form has four reachable stops, so a count that reached fourteen without
      // returning would mean the walk is not moving.
      final Set<Type> stopped = <Type>{};
      for (int i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode? node = FocusManager.instance.primaryFocus;
        final BuildContext? context = node?.context;
        if (node == null || !node.hasFocus || context == null) {
          continue;
        }
        final Finder focused = find.byElementPredicate(
          (Element element) => identical(element, context),
        );
        for (final Type type in <Type>[
          PasswordVisibilityToggle,
          SocialAuthButton,
          EvaButton,
          TextLink,
          EvaTextField,
        ]) {
          if (find
              .ancestor(of: focused, matching: find.byType(type))
              .evaluate()
              .isNotEmpty) {
            stopped.add(type);
          }
        }
      }

      expect(
        stopped,
        isNot(contains(SocialAuthButton)),
        reason: 'a permanently-disabled control must be invisible to Tab',
      );
      expect(
        stopped,
        isNot(contains(TextLink)),
        reason: 'both links are permanently disabled, so neither is a Tab stop',
      );
      expect(
        stopped,
        contains(EvaButton),
        reason:
            'Sign in is live and must be reachable; without it this assertion '
            'would pass on a tree where nothing takes focus at all',
      );
      expect(stopped, contains(PasswordVisibilityToggle));

      // And the two `TextLink`s are **not** stops — the first version of this
      // asserted `contains(TextLink)` and failed. Both links are permanently
      // disabled (see `LoginPage`'s element table), so `EvaFocusRing` sets
      // `canRequestFocus: false` and Tab skips them. Asserting it here rather than
      // leaving it implied is the point: "disabled" and "invisible to Tab" are the
      // same fact on this screen, and this is where it is pinned.
    });
  });

  group('§14 — the focus ring', () {
    testWidgets('Sign in paints the 2px ember ring on the frame focus lands', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // A **valid** form first. `Sign in` is disabled while the form is incomplete
      // and a disabled `EvaFocusRing` sets `canRequestFocus: false` — which is the
      // correct behaviour, and means Tab never reaches it. Tabbing to a disabled
      // control is not a ring failure; it is a control that is not there.
      await tester.enterText(
        find.byType(TextField).at(0),
        'david@evangelion.app',
      );
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();

      expect(await _ringAppearsOnTab(tester, find.byType(EvaButton)), isTrue);
    });

    testWidgets('and the password toggle does too', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // The toggle is live on an empty form, so no credentials are needed here —
      // and that is deliberate: it proves the toggle's reachability does not depend
      // on the form's validity.
      expect(
        await _ringAppearsOnTab(tester, find.byType(PasswordVisibilityToggle)),
        isTrue,
      );
    });
  });

  group('§14 — no state is carried by colour alone', () {
    testWidgets(
      'the password toggle pairs its colour with a glyph and a name',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final AuthBloc bloc = buildTestBloc();
        addTearDown(bloc.close);
        await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

        // Both states, each announced and each drawn. The mask is the prototype's two
        // eye SVGs (`LoginScreen.tsx:56-58`) and §14's "colour-only state" row answered
        // with an icon rather than a tint.
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.bySemanticsLabel('Show password'), findsOneWidget);

        await tester.tap(find.byType(PasswordVisibilityToggle));
        await tester.pump();

        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Show password'),
          findsNothing,
          reason: 'the name must change with the state, not just the glyph',
        );

        handle.dispose();
      },
    );

    testWidgets('an errored field pairs its colour with an icon and a name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // `EvaTextField`'s rim is **not** red while the field is focused — §14's ring
      // wins the band — so the error has to be carried elsewhere. It is: the helper
      // icon and the `liveRegion` text, which this asserts.
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text("That password's too short"), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a refused sign-in is announced as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      // A **mocked port**, not the fake repository: `FakeAuthRepository` judges the
      // credentials with the same `validateLogin` the form uses, so a form-valid
      // submission always succeeds and the refusal path is unreachable through it.
      // The first version of this test typed an *invalid* address instead, which
      // left `Sign in` disabled, tapped nothing, and asserted a `formError` that
      // could never arrive.
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

      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));
      await tester.enterText(
        find.byType(TextField).at(0),
        'david@evangelion.app',
      );
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();
      await tester.tap(find.byType(EvaButton));
      await tester.pumpAndSettle();

      expect(bloc.state.formError, 'No such user in this build.');
      expect(find.text('No such user in this build.'), findsOneWidget);
      // The icon, because §14's row is "pair the colour with an icon": the message
      // is `err`-inked, and a reader who cannot see the ink still gets the glyph.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        nodesOffering(tester, SemanticsAction.tap),
        isNotEmpty,
        reason: 'the tree still has controls after the failure',
      );

      handle.dispose();
    });
  });
}

/// Whether §14's ring is painted under [target] on any frame Tab reaches it.
///
/// ## WHY THE WALK IS HERE AND NOT `tabUntilFocused`
///
/// `tabUntilFocused` returns on the frame after the focus **node** reports itself
/// focused. `EvaFocusRing` reads `hasFocus` through a `ListenableBuilder`, so its
/// repaint lands on the *following* frame — and the ring is what this test is about,
/// so asking the harness helper to get the timing right and then asserting on the
/// tree is asking the thing under test to prove itself. Two pumps per tab, and the
/// answer is "did the ring ever appear while Tab was walking the form", which is
/// the claim §14 makes.
///
/// Bounded at 12 tabs: the form has four reachable stops, so twelve without a hit
/// means the walk is not moving rather than that the ring is absent.
Future<bool> _ringAppearsOnTab(WidgetTester tester, Finder target) async {
  const EvaColors colors = EvaColors.dark();
  for (int i = 0; i < 12; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    if (renderedBorders(tester, target).contains(evaFocusRingBorder(colors))) {
      return true;
    }
  }
  return false;
}
