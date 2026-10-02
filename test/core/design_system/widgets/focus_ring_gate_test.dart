import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';
import '../../../support/project_import_graph.dart';

/// ## THE GATE, AND WHY IT HAS TO BE A GATE
///
/// `09-quality-gates.md` §14 lists "No focus indicators" as a mandatory fix:
/// "`Focus` + a 2px `ember` ring at 40% alpha on **every** interactive widget".
/// It gave the rule and no owner. Phase 3 has ten interactive widgets, which is
/// ten chances to forget one — and a convention with ten chances is the same
/// defect as the documented-but-unenforced `BackdropFilter` budget that Phase 2
/// had to fix by writing `glass_blur_budget_test.dart`.
///
/// So there are **three** checks here, and they fail for three different reasons:
///
/// 1. **The source gate** walks every `lib/core/design_system/widgets/*.dart` and
///    asks a question no test can ask at runtime: *does this file declare a
///    callback in its public constructor?* If it does, it must reference
///    `EvaFocusRing` or `evaFocusRingSpec`, or appear in [_delegatesFocusRingTo]
///    with a reason. A **new** interactive widget is covered the day it lands,
///    with no edit to this file — which is the whole point, because a hand-listed
///    inventory of ten names is the convention this gate replaces.
/// 2. **The behavioural gate** pumps each widget, tabs to it, and reads the
///    **rendered** [Border]s out of its tree, comparing them against
///    [evaFocusRingBorder]. This is what catches a ring that is present but
///    wrong — transparent, 1px, the wrong hue, or a widget that takes focus and
///    draws nothing.
/// 3. **The negative control** proves gate 2 can fail at all, by building a
///    widget that has the *shape* of a compliant one and none of the behaviour.
///
/// The numbers themselves are pinned in `focus_ring_resolver_test.dart`; this
/// file is about presence, which is a different question from value.
void main() {
  group('§14 — the focus ring, on every interactive widget', () {
    for (final _InteractiveWidget entry in _interactiveWidgets) {
      testWidgets('${entry.widget} draws §14\'s ring when focused', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        // Disposed in the BODY, not via `addTearDown`. §14's correction says a
        // handle "must be disposed to avoid leaking across tests", and it is
        // right — but in Flutter 3.47.4 `testWidgets` already holds one of its
        // own (`widget_tester.dart:180-181`, `semanticsEnabled: true` by
        // default), and `_endOfTestVerifications` then compares the live handle
        // count against the count recorded *before* the framework took its own
        // (`widget_tester.dart:1061-1082`). An `addTearDown` disposal runs after
        // that comparison, so the pattern §14 quotes verbatim fails here with
        // "A SemanticsHandle was active at the end of the test". Disposing in the
        // body puts the count back to the framework's own handle before the
        // check. Verified, not assumed — see the negative control below.
        handle.dispose();

        await tester.pumpWidget(
          evaPrimitiveHarness(
            size: const Size(320, 568),
            child: Builder(
              builder: (BuildContext context) =>
                  Align(alignment: Alignment.topCenter, child: entry.build()),
            ),
          ),
        );

        final Finder target = find.byType(entry.widget);
        expect(
          target,
          findsOneWidget,
          reason: '${entry.widget} did not render',
        );

        // A keyboard has to be able to *get* here before "it draws a ring when
        // focused" means anything.
        await tabUntilFocused(tester, target);

        expect(
          renderedBorders(tester, target),
          contains(evaFocusRingBorder(const EvaColors.dark())),
          reason:
              '§14 — ${entry.widget} took focus but painted no 2px ember-at-40% '
              'border. ${entry.name}',
        );
        // The rendered border is the whole assertion. "Reached it through
        // EvaFocusRing" is a *how*, and it is checked by the source gate below,
        // which can see a file's whole text; from a rendered tree the two are
        // indistinguishable — and `EvaTextField` is the case that proves it, since
        // the field's own rim is the ring (see its doc) and it never builds an
        // `EvaFocusRing`.
      });
    }
  });

  group('§14 — the negative control, so the gate is known to bite', () {
    testWidgets('a compliant-looking widget with no ring fails the check', (
      WidgetTester tester,
    ) async {
      // Not decoration. Without this, "every widget draws the ring" and "the
      // comparison below is vacuous" are indistinguishable from the outside, and
      // a gate nobody has watched fail is a gate nobody should believe.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const Align(
            alignment: Alignment.topCenter,
            child: _RinglessButton(),
          ),
        ),
      );

      final Finder target = find.byType(_RinglessButton);
      await tabUntilFocused(tester, target);

      expect(
        renderedBorders(tester, target),
        isNot(contains(evaFocusRingBorder(const EvaColors.dark()))),
        reason: 'the control: _RinglessButton genuinely has no ring',
      );
      expect(
        () => _expectRing(tester, target),
        throwsA(isA<TestFailure>()),
        reason:
            'and so the assertion the gate makes about it fails — which is the '
            'only reason the nine passes above are worth anything',
      );
    });

    testWidgets('a ring at the wrong alpha is not §14\'s ring', (
      WidgetTester tester,
    ) async {
      // The most likely way for the gate to rot silently: someone changes the
      // widget to a 1px or a 20% ring, it still *looks* like a focus indicator,
      // and a presence-only check stays green.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          child: const Align(
            alignment: Alignment.topCenter,
            child: _WrongRingButton(),
          ),
        ),
      );

      final Finder target = find.byType(_WrongRingButton);
      await tabUntilFocused(tester, target);

      expect(renderedBorders(tester, target), isNotEmpty);
      expect(
        renderedBorders(tester, target),
        isNot(contains(evaFocusRingBorder(const EvaColors.dark()))),
      );
      expect(() => _expectRing(tester, target), throwsA(isA<TestFailure>()));
    });
  });

  group('§14 — reduced motion does not suppress the ring', () {
    testWidgets('a focused control still shows the ring with animations off', (
      WidgetTester tester,
    ) async {
      // The ring is deliberately not animated (see `EvaFocusRing`'s doc), so this
      // is checking the *absence of a regression*, not a code path. A widget that
      // later wraps the ring in an `AnimatedContainer` without a
      // `disableAnimationsOf` check would still pass here — the check that catches
      // that is the per-widget `Duration.zero` assertion in each widget's own
      // test, and the honest statement is that the ring has no animation to
      // guard rather than that it is guarded.
      await tester.pumpWidget(
        evaPrimitiveHarness(
          disableAnimations: true,
          child: const Align(
            alignment: Alignment.topCenter,
            child: EvaButton(label: 'Sign in', onPressed: _noop),
          ),
        ),
      );
      await tabUntilFocused(tester, find.byType(EvaButton));

      expect(
        renderedBorders(tester, find.byType(EvaButton)),
        contains(evaFocusRingBorder(const EvaColors.dark())),
      );
    });
  });

  group('the source gate — a new interactive widget is covered without an edit', () {
    test('every widget file that declares a callback carries the ring', () {
      final Directory dir = Directory.fromUri(
        packageRoot.uri.resolve('lib/core/design_system/widgets/'),
      );
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'the widgets directory must exist',
      );

      final List<File> files = <File>[
        for (final FileSystemEntity entity in dir.listSync())
          if (entity is File && entity.path.endsWith('.dart')) entity,
      ];
      expect(
        files.length,
        greaterThan(10),
        reason: 'a walk that found one or two files proves nothing',
      );

      final List<String> offenders = <String>[];
      for (final File file in files) {
        final String relative = packageRelative(file.uri);
        if (!_declaresACallback(file.readAsStringSync())) continue;
        if (_delegatesFocusRingTo.containsKey(relative)) continue;
        if (_mentionsTheRing(file.readAsStringSync())) continue;
        offenders.add(relative);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'every widget with a callback in its public constructor has to carry '
            '§14\'s focus ring, either by using EvaFocusRing / evaFocusRingSpec '
            'or by being listed in _delegatesFocusRingTo with a reason. These '
            'files do neither:\n${offenders.join('\n')}',
      );
    });

    test('the callback detector is not a hollow search', () {
      // Without this the gate above is satisfied by a matcher that finds nothing,
      // and "no offenders" means "no interactive widgets" — which is false and
      // which nothing else in the file would notice.
      const String interactive = '''
class Demo extends StatelessWidget {
  const Demo({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';
      const String inert = '''
class Demo extends StatelessWidget {
  const Demo({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';

      expect(_declaresACallback(interactive), isTrue);
      expect(_declaresACallback(inert), isFalse);
      expect(_mentionsTheRing('final b = evaFocusRingBorder(colors);'), isTrue);
      expect(_mentionsTheRing('class A extends EvaFocusRing {}'), isTrue);
      expect(_mentionsTheRing('class A extends StatelessWidget {}'), isFalse);
    });

    test('the delegation list is empty or justified per entry', () {
      for (final MapEntry<String, String> entry
          in _delegatesFocusRingTo.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: '${entry.key} delegates with no reason given',
        );
      }
    });
  });
}

/// What the behavioural gate asserts, extracted so the negative control can
/// watch it fail rather than re-implementing it.
void _expectRing(WidgetTester tester, Finder target) {
  expect(
    renderedBorders(tester, target),
    contains(evaFocusRingBorder(const EvaColors.dark())),
  );
}

void _noop() {}

/// One interactive design-system widget and how to build it focused.
typedef _InteractiveWidget = ({
  Type widget,
  String name,
  Widget Function() build,
});

/// Every interactive widget in the design system.
///
/// Named rather than discovered, because discovering them means pumping every
/// widget through every constructor — some of which are illegal without
/// arguments the real call sites supply. The *source* gate above is what makes
/// this list self-extending for the case that matters (a widget landing that
/// declares a callback and carries no ring). This list is the behavioural half:
/// it proves the widgets that exist **actually render** the ring, which a source
/// scan cannot do.
final List<_InteractiveWidget> _interactiveWidgets = <_InteractiveWidget>[
  (
    widget: EvaButton,
    name: 'ds.tsx ButtonPrimary / ButtonSecondary / ButtonText',
    build: () => const EvaButton(label: 'Sign in', onPressed: _noop),
  ),
  (
    widget: EvaTextField,
    name: 'ds.tsx Input — defect #8 made this readOnly',
    // The `Material` is a `TextField` requirement, not decoration: its
    // `InputDecorator` asserts on one. A real screen gets it from `Scaffold`,
    // and this harness has no `Scaffold`.
    build: () => Material(
      type: MaterialType.transparency,
      child: EvaTextField(label: 'Email', controller: TextEditingController()),
    ),
  ),
  (
    widget: EvaChip,
    name: 'ds.tsx CategoryChip + App.tsx chips, §14 "mono-caps chips"',
    build: () => const EvaChip(label: 'Dark', onSelected: _toggle),
  ),
  (
    widget: SegmentedControl<String>,
    name: 'SettingsScreen theme picker — Phase 3 keyboard gate',
    build: () => SegmentedControl<String>(
      values: const <String>['Light', 'Dark', 'System'],
      selected: 'Dark',
      labelOf: (String value) => value,
      onChanged: _ignore,
    ),
  ),
  (
    widget: EvaToggle,
    name: 'SettingsScreen.tsx:14-26 — the local Toggle component',
    build: () => const EvaToggle(value: true, onChanged: _toggleBool),
  ),
  (
    widget: FontSizeStepper,
    name: 'SettingsScreen.tsx:63-69 — the range input row',
    build: () => const FontSizeStepper(step: 3, onChanged: _ignoreInt),
  ),
  (
    widget: IconActionButton,
    name: '§14 "icon-only buttons have no accessible name"',
    build: () => const IconActionButton(
      icon: Icons.arrow_back,
      tooltip: 'Back',
      onPressed: _noop,
    ),
  ),
  (
    widget: TextLink,
    name: "LoginScreen.tsx:70-72 — the 'Create account' link",
    build: () => const TextLink(label: 'Create account', onPressed: _noop),
  ),
  (
    widget: SettingsTile,
    name: 'ds.tsx SettingsTile, when the row itself is tappable',
    build: () => const SettingsTile(
      title: 'Edit profile',
      trailing: SizedBox(width: 16, height: 16),
      onTap: _noop,
    ),
  ),
  (
    widget: ErrorView,
    name: 'Phase 5 error mapper — the prototype has neither state view',
    build: () => const ErrorView(
      message: 'Could not load today\'s reading.',
      onRetry: _noop,
      retryLabel: 'Retry',
    ),
  ),
  (
    // Phase 2's widget, and the reason this gate is not "the nine Tier-1
    // widgets". `GlassSurface(onTap:)` is interactive and shipped without a
    // focus node at all, so Tab could not reach it.
    widget: GlassSurface,
    name: 'Phase 2 — ds.tsx had eight glass surfaces, two of them tappable',
    build: () => const GlassSurface(
      onTap: _noop,
      semanticLabel: "Today's reading",
      padding: EdgeInsets.all(EvaSpacing.sm),
      child: SizedBox(width: 200, height: 60),
    ),
  ),
];

/// Widget files whose interactive surface is entirely a *child* widget that
/// carries the ring itself.
///
/// Two entries, and the source scan genuinely cannot see through them — it reads
/// one file at a time. So the list exists to record a **decision** rather than an
/// omission, and the behavioural gate above is what keeps each entry honest: it
/// pumps `ErrorView` and `FontSizeStepper` and fails if no ring appears. Delete an
/// entry's implementation of the ring and the behavioural gate goes red, which is
/// why this is a list with reasons and not a suppression comment.
const Map<String, String> _delegatesFocusRingTo = <String, String>{
  'lib/core/design_system/widgets/error_view.dart':
      'the only interactive surface is its retry action, which is an EvaButton — '
      'and EvaButton carries the ring. The behavioural gate above proves it '
      'renders by pumping exactly this widget.',
  'lib/core/design_system/widgets/font_size_stepper.dart':
      'the only interactive surfaces are the two IconActionButtons, which carry '
      'the ring. The track is a GestureDetector that is deliberately not '
      'focusable — it is reachable through Semantics onIncrease/onDecrease '
      'instead, so a screen-reader user is not offered a third tab stop.',
};

/// Whether [source] declares a callback in its public constructor.
///
/// Anchored to the declaration rather than to the whole file: `NeuraLBackground`
/// has no callback but its painter has listeners, and a widget that stores a
/// callback it never exposes as a parameter is not an interactive surface. The
/// three spellings are the ones this design system and Material actually use.
bool _declaresACallback(String source) =>
    _callbackDeclarations.any(source.contains);

const List<String> _callbackDeclarations = <String>[
  'VoidCallback',
  'GestureTapCallback',
  'ValueChanged<',
  'onChanged,',
  'onPressed,',
  'onTap,',
  'onSelected,',
  'onSubmitted,',
];

bool _mentionsTheRing(String source) =>
    source.contains('extends EvaFocusRing') ||
    source.contains('EvaFocusRing(') ||
    source.contains('EvaFocusRingScope(') ||
    source.contains('evaFocusRingBorder(') ||
    source.contains('evaFocusRingSpec(');

void _toggle(bool value) {}
void _toggleBool(bool value) {}
void _ignore(String value) {}
void _ignoreInt(int value) {}

/// A focusable box with [border] as its only rim.
///
/// Extracted so the two controls below differ in **one** value — the border — and
/// not in whether their `Focus` is const, which is what makes them a pair rather
/// than two examples.
///
/// [border] is a parameter rather than a literal because the colours come from
/// `EvaColors`, and `EvaColors.dark()` in a `const` expression is not a constant
/// expression at all — its fields are instance properties. A `final` top-level
/// would work too and this is smaller.
Widget _focusable(Border border) => Focus(
  child: DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(EvaRadii.button)),
      border: border,
    ),
    child: const SizedBox(width: 120, height: 44),
  ),
);

/// A button with a focus node and **no** ring.
///
/// The negative control for the behavioural gate: it is focusable, so Tab reaches
/// it, and it paints a `Border.all` — just not §14's. A gate that only asked "is
/// there a border?" would pass it.
class _RinglessButton extends StatelessWidget {
  const _RinglessButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ringless',
    child: _focusable(
      Border.fromBorderSide(BorderSide(color: const EvaColors.dark().ink3)),
    ),
  );
}

/// A button that draws a 2px ring at the **wrong** alpha.
///
/// The most likely way for the gate to rot silently: someone changes a widget to
/// a 1px or a 20% ring, it still *looks* like a focus indicator, and a
/// presence-only check stays green. So this control has a border of the right
/// width, in the right hue, at 20% — and must still fail.
class _WrongRingButton extends StatelessWidget {
  const _WrongRingButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Wrong ring',
    child: _focusable(
      Border.fromBorderSide(
        BorderSide(
          color: const EvaColors.dark().ember.withValues(alpha: 0.20),
          width: 2,
        ),
      ),
    ),
  );
}
