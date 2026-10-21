import 'dart:ui' show Tristate;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/features/auth/presentation/widgets/role_picker.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// The role picker — behaviour and widget tests, **alongside** the widget rather
/// than before it (AGENT_CONTEXT §6 exempts widget and screen work from the
/// red-first ceremony).
///
/// ## WHAT IS WORTH TESTING, AND WHY IT IS NOT THE OBVIOUS LIST
///
/// The widget is three lines of wiring around `SegmentedControl`, so a test
/// that asserted "it renders a `SegmentedControl`" would be reading the
/// implementation back. What is worth pinning is the **three claims this widget
/// makes that the design system does not**:
///
/// * it offers **all three** roles, in the enum's own order;
/// * it **reports** the tap and does **not** keep the value — a control that
///   kept its own copy would be a second source of truth beside the bloc's
///   `AuthState.role`;
/// * its **track is named differently from its options**, which is recorded
///   decision 129's defect and the reason `SegmentedControl.semanticLabel`
///   exists.
///
/// The last one is the sharpest: `SegmentedControl`'s default track label is
/// `labelOf(selected)`, so a picker that did not pass one would put **two
/// activatable nodes on screen with the identical label** — and the suite
/// cannot see that by looking at a widget tree, so it is read off the semantics
/// tree.
void main() {
  /// The picker on its own, in the app's own theme and direction.
  ///
  /// The app's own localizations delegates, because the picker reads
  /// `context.l10n` — and the harness's default pair supports **only** `en`, so
  /// an `ar` locale would resolve back to English. `login_harness.dart` passes
  /// the same trio.
  Widget picker({
    required UserRole selected,
    required ValueChanged<UserRole> onChanged,
  }) => evaPrimitiveHarness(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
    child: RolePicker(selected: selected, onChanged: onChanged),
  );

  group('the options', () {
    testWidgets('are all three roles, in the enum\'s own order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        picker(selected: UserRole.kid, onChanged: (UserRole _) {}),
      );
      await tester.pump();

      final SegmentedControl<UserRole> control = tester
          .widget<SegmentedControl<UserRole>>(
            find.byType(SegmentedControl<UserRole>),
          );

      expect(control.values, UserRole.values);
      expect(control.values, hasLength(3));
      expect(control.values, <UserRole>[
        UserRole.kid,
        UserRole.viewerServant,
        UserRole.adminServant,
      ]);
    });

    testWidgets('and each is painted with its own label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        picker(selected: UserRole.kid, onChanged: (UserRole _) {}),
      );
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      // The control upper-cases its labels under LTR (`redesign.html:183`'s
      // `text-transform: uppercase`), so the **painted** text is the upper-case
      // form while the **semantic** label is the string as written.
      expect(find.text(en.authRoleKid.toUpperCase()), findsOneWidget);
      expect(find.text(en.authRoleServant.toUpperCase()), findsOneWidget);
      expect(find.text(en.authRoleAdmin.toUpperCase()), findsOneWidget);
    });
  });

  group('the selection', () {
    testWidgets('the chosen one is marked as selected, and the others are not', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        picker(selected: UserRole.adminServant, onChanged: (UserRole _) {}),
      );
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      // **Both directions**, because `SemanticsFlag.isSelected` is a
      // `Tristate` — a node that says nothing about its selection reads the same
      // as one that says "not selected" to a reader, and an assertion that only
      // checked the selected option would pass against a control that marked
      // *every* option selected.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(en.authRoleAdmin))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
        reason:
            '§14: without `selected`, a screen-reader user cannot tell which of '
            'the three options is chosen',
      );
      for (final String unchosen in <String>[
        en.authRoleKid,
        en.authRoleServant,
      ]) {
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(unchosen))
              .flagsCollection
              .isSelected,
          Tristate.isFalse,
          reason: '"$unchosen" is not the chosen one',
        );
      }

      handle.dispose();
    });

    testWidgets('a tap is REPORTED, and the widget keeps no value of its own', (
      WidgetTester tester,
    ) async {
      final List<UserRole> reported = <UserRole>[];
      await tester.pumpWidget(
        picker(selected: UserRole.kid, onChanged: reported.add),
      );
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      await tester.tap(find.text(en.authRoleAdmin.toUpperCase()));
      await tester.pump();

      expect(
        reported,
        <UserRole>[UserRole.adminServant],
        reason:
            'the parent owns the value: a widget that kept its own copy would be '
            'a second source of truth beside `AuthState.role`',
      );

      // And the widget did **not** move its own selection — the parent has not
      // fed a new `selected` back, so the painted selection is still the one it
      // was built with. That is the whole of "controlled".
      final SegmentedControl<UserRole> control = tester
          .widget<SegmentedControl<UserRole>>(
            find.byType(SegmentedControl<UserRole>),
          );
      expect(control.selected, UserRole.kid);
    });
  });

  group('the names', () {
    testWidgets('the track is named by the control, not by the selection', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        picker(selected: UserRole.kid, onChanged: (UserRole _) {}),
      );
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      // The defect this guards: `SegmentedControl`'s default track label is
      // `labelOf(selected)`, so a picker that passed no `semanticLabel` would
      // put **two** activatable nodes on screen with the identical label
      // "Kid" — the track and the selected segment. Recorded decision 129.
      expect(
        find.bySemanticsLabel(en.authRoleLabel),
        findsOneWidget,
        reason: 'the track has a name of its own',
      );
      expect(
        find.bySemanticsLabel(en.authRoleKid),
        findsOneWidget,
        reason: 'and the selected segment keeps its own name',
      );
      expect(
        en.authRoleLabel,
        isNot(en.authRoleKid),
        reason: 'the two names are different strings, so the two nodes cannot collide',
      );

      handle.dispose();
    });

    testWidgets('and every option is named', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        picker(selected: UserRole.kid, onChanged: (UserRole _) {}),
      );
      await tester.pump();

      final AppLocalizationsEn en = AppLocalizationsEn();
      for (final String label in <String>[
        en.authRoleKid,
        en.authRoleServant,
        en.authRoleAdmin,
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: '§14 — no option may lose its name',
        );
      }

      handle.dispose();
    });
  });

  group('the label mapping', () {
    test('is exhaustive, and a fourth role would not compile', () {
      final AppLocalizationsEn en = AppLocalizationsEn();

      expect(RolePicker.labelFor(en, UserRole.kid), en.authRoleKid);
      expect(
        RolePicker.labelFor(en, UserRole.viewerServant),
        en.authRoleServant,
      );
      expect(RolePicker.labelFor(en, UserRole.adminServant), en.authRoleAdmin);
    });
  });
}
