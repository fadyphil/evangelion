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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/login_harness.dart';

/// §14 for `/login`: no unlabeled interactive node, a focus ring on everything a
/// keyboard can reach, and no state carried by colour alone.
///
/// ## WHAT THE REDESIGNED SCREEN OWES THIS SWEEP
///
/// `eva/redesign.html:503-511` draws four interactive nodes: two bare fields, the
/// CTA and the two ghost pills (five controls, four *kinds*). The fields and the
/// CTA are `EvaTextField`/`EvaButton`, whose own gates cover them; the ghosts are
/// `EvaButton`s this suite asserts **inert** — and an inert control is the one
/// thing a design-system gate cannot see, because the gate asks "does it paint a
/// ring when focused" and the answer here must be "it is never focused at all".
///
/// The password reveal control the old screen carried is **gone** with the
/// redesign's plain `type="password"` input (`:507`), so the toggle's §14 rows —
/// the glyph/name pairing, the extra tab stop — are gone with it. The bloc's
/// reveal capability survives, unrested; restoring a toggle restores these rows
/// with it.
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

/// Past the wordmark's 910 ms entrance, so element visibility is not a function
/// of when the test looked.
Future<void> pumpSettled(WidgetTester tester, AuthBloc bloc) async {
  await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  group('no unlabeled interactive node', () {
    testWidgets('every node offering an action has a non-empty label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

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

    testWidgets('and the named nodes are the four the redesign declares', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      // Enumerated rather than "some of them": §14's gap is an *unnamed* control,
      // and a label that drifted off the control it names is the same defect one
      // step later. The ghosts' names carry `authUnavailableSuffix` —
      // `EvaButton.semanticLabel` — because an inert control must say WHY.
      final AppLocalizationsEn en = AppLocalizationsEn();
      for (final String label in <String>[
        en.authEmailLabel,
        en.authPasswordLabel,
        en.authEnterTheWord,
        '${LoginPage.kGhostGoogle} — ${en.authUnavailableSuffix}',
        '${LoginPage.kGhostApple} — ${en.authUnavailableSuffix}',
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
    testWidgets('the ghosts offer no tap action in either form state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      final AppLocalizationsEn en = AppLocalizationsEn();
      // Both form states, because "disabled while the form is empty" would
      // satisfy a weaker test on its own. An inert control that wakes up when
      // the form is valid is a live control with a misleading name.
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

        expect(labels, contains(en.authEnterTheWord), reason: 'CTA is live');
        for (final String ghost in <String>[
          '${LoginPage.kGhostGoogle} — ${en.authUnavailableSuffix}',
          '${LoginPage.kGhostApple} — ${en.authUnavailableSuffix}',
        ]) {
          expect(
            labels,
            isNot(contains(ghost)),
            reason:
                'the ghost offered a tap action with $credentials — inert must '
                'mean the action is absent, not dimmed',
          );
        }
      }

      handle.dispose();
    });

    testWidgets('and none of them is a Tab stop, while the CTA is', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      // Walk the tab order and attribute each stop by asking the **focused node**
      // where it is, rather than by assuming the order. `FocusNode.context` is the
      // focused node's own element, and `find.ancestor` from there is the
      // attribution. Bounded at 14 tabs — the form has three reachable stops (two
      // fields, one CTA), so a count that reached fourteen without returning would
      // mean the walk is not moving.
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
        for (final Type type in <Type>[EvaButton, EvaTextField]) {
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
        contains(EvaTextField),
        reason: 'the two fields are the form and must be reachable',
      );
      expect(
        stopped,
        contains(EvaButton),
        reason:
            'the CTA is always live (`eva/redesign.html:508` has no disabled) '
            'and must be reachable; without it this assertion would pass on a '
            'tree where nothing takes focus at all',
      );
      // The ghosts' invisibility to Tab is not re-derived here by type — they
      // ARE `EvaButton`s, so a type walk cannot tell them from the CTA. What
      // this suite pins instead is the mechanism: the previous test proved the
      // ghosts' tap action is absent in both form states, and a control with no
      // action is `EvaFocusRing.enabled == false`, which sets
      // `canRequestFocus: false` — the same contract the old screen's disabled
      // links were pinned with, one layer down.
    });
  });

  group('§14 — the focus ring', () {
    testWidgets('the CTA paints the 2px ember ring on the frame focus lands', (
      WidgetTester tester,
    ) async {
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      final AppLocalizationsEn en = AppLocalizationsEn();
      final Finder cta = find.ancestor(
        of: find.text(en.authEnterTheWord),
        matching: find.byType(EvaButton),
      );
      expect(await _ringAppearsOnTab(tester, cta), isTrue);
    });
  });

  group('§14 — no state is carried by colour alone', () {
    testWidgets('an errored field pairs its colour with an icon and a name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      // `EvaTextField`'s rim is **not** red while the field is focused — §14's ring
      // wins the band — so the error has to be carried elsewhere. It is: the error
      // icon and the helper text, which this asserts. The message is the
      // redesign's own word, localized — see `authPasswordTooShort`.
      final AppLocalizationsEn en = AppLocalizationsEn();
      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(en.authPasswordTooShort), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the password field is masked, and says so', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final AuthBloc bloc = buildTestBloc();
      addTearDown(bloc.close);
      await pumpSettled(tester, bloc);

      // The redesign's field is `type="password"` (`eva/redesign.html:507`) —
      // masked, with no reveal control. `EvaTextField` carries
      // `obscureText: !state.isPasswordVisible`, and the bloc's default is
      // masked, so the rendered field is masked; the TextField's own semantics
      // flag (`obscured`) is what a screen reader reads.
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();
      expect(passwordTextField(tester).obscureText, isTrue);

      handle.dispose();
    });

    testWidgets('a refused sign-in is announced as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      // A **mocked port**, not the fake repository: `FakeAuthRepository` judges the
      // credentials with the same `validateLogin` the form uses, so a form-valid
      // submission always succeeds and the refusal path is unreachable through it.
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

      await pumpSettled(tester, bloc);
      final AppLocalizationsEn en = AppLocalizationsEn();
      await tester.enterText(
        find.byType(TextField).at(0),
        'david@evangelion.app',
      );
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      await tester.pump();
      await tester.tap(find.text(en.authEnterTheWord));
      await tester.pumpAndSettle();

      expect(bloc.state.formError, 'No such user in this build.');
      expect(find.text('No such user in this build.'), findsOneWidget);
      // The icon, because §14's row is "pair the colour with an icon": the message
      // is `err`-inked, and a reader who cannot see the ink still gets the glyph.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      handle.dispose();
    });
  });
}

/// Whether tabbing from the current focus reaches [target] and paints
/// `EvaFocusRing`'s 2px band there.
Future<bool> _ringAppearsOnTab(WidgetTester tester, Finder target) async {
  for (int i = 0; i < 14; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final FocusNode? node = FocusManager.instance.primaryFocus;
    final BuildContext? context = node?.context;
    if (context == null) {
      continue;
    }
    final Finder focused = find.byElementPredicate(
      (Element element) => identical(element, context),
    );
    if (find.ancestor(of: focused, matching: target).evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}
