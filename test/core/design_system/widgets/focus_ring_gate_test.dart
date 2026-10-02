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
/// It gave the rule and no owner. Phase 3 has eleven interactive widgets, which is
/// eleven chances to forget one — and a convention with eleven chances is the
/// same defect as the documented-but-unenforced `BackdropFilter` budget that Phase
/// 2 had to fix by writing `glass_blur_budget_test.dart`.
///
/// So there are **three** checks here, and they fail for three different reasons:
///
/// 1. **The source gate** walks every `lib/core/design_system/widgets/**/*.dart`
///    and asks a question no test can ask at runtime: *does this file declare a
///    callback in its public constructor?* If it does, it must reference
///    `EvaFocusRing` or `evaFocusRingSpec`, or appear in [_delegatesFocusRingTo]
///    with its interactive surfaces enumerated. A **new** interactive widget is
///    covered the day it lands, with no edit to this file — which is the whole
///    point, because a hand-listed inventory of eleven names is the convention
///    this gate replaces.
/// 2. **The behavioural gate** pumps each widget in [kInteractiveWidgets], tabs to
///    it, and reads the **rendered** [Border]s out of its tree, comparing them
///    against [evaFocusRingBorder]. This is what catches a ring that is present
///    but wrong — transparent, 1px, the wrong hue, or a widget that takes focus
///    and draws nothing.
/// 3. **The negative control** proves gate 2 can fail at all, by building a
///    widget that has the *shape* of a compliant one and none of the behaviour.
///
/// The numbers themselves are pinned in `focus_ring_resolver_test.dart`; this
/// file is about presence, which is a different question from value.
///
/// ## WHAT THE SOURCE GATE STILL CANNOT SEE — STATED, NOT DISCOVERED LATER
///
/// The ring check is per **file**, so a file that wraps one control in
/// [EvaFocusRing] and leaves a second one on a bare `InkWell` still passes. That
/// is not a gap this file can close from source without a Dart parser, and
/// `EvaInk`'s doc already records the same limit for the same reason. The
/// behavioural gate is the other half of the answer — it pumps each widget — and
/// that is why [kInteractiveWidgets] lives in the harness and is shared with the
/// activatable gate in `controls_test.dart`: one inventory, two §14 rows, and a
/// widget added without a row is a row the other gate cannot check either.
void main() {
  group('§14 — the focus ring, on every interactive widget', () {
    for (final InteractiveWidget entry in kInteractiveWidgets) {
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
            'only reason the eleven passes above are worth anything',
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
      final List<File> files = _widgetDartFiles();
      expect(
        files.length,
        greaterThan(10),
        reason: 'a walk that found one or two files proves nothing',
      );

      final List<String> offenders = <String>[];
      for (final File file in files) {
        final String relative = packageRelative(file.uri);
        // Comments stripped **before** either check. See [_mentionsTheRing].
        final String code = withoutDartComments(file.readAsStringSync());
        if (!_declaresACallback(code)) continue;
        if (_delegatesFocusRingTo.containsKey(relative)) {
          offenders.addAll(_unattributedSurfaces(relative, code));
          continue;
        }
        if (!_mentionsTheRing(code)) offenders.add(relative);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'every widget with a callback in its public constructor has to carry '
            "§14's focus ring, either by using EvaFocusRing / evaFocusRingSpec "
            'or by being listed in _delegatesFocusRingTo with its interactive '
            'surfaces enumerated. These files do neither:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the walk is recursive, and a planted subtree proves it', () {
      // The negative control for the one line above a reader cannot check by
      // reading it: `listSync()` without `recursive: true` reads a single level,
      // so `widgets/sub/zz.dart` was invisible and a whole new subtree of widgets
      // could ship with no ring on any of them while the gate reported a clean
      // tree. Planted under the real directory and removed in `finally`, so the
      // control is about the walk and not about a committed fixture.
      final Directory sub = Directory.fromUri(
        packageRoot.uri.resolve(
          'lib/core/design_system/widgets/zz_walk_probe/',
        ),
      );
      final File planted = File.fromUri(sub.uri.resolve('zz.dart'));
      try {
        sub.createSync(recursive: true);
        planted.writeAsStringSync(_ringlessWidgetSource);
        expect(
          _widgetDartFiles().map((File f) => packageRelative(f.uri)),
          contains(packageRelative(planted.uri)),
          reason:
              'a one-level walk cannot see widgets/sub/zz.dart, which is exactly '
              'the evasion it used to permit',
        );
      } finally {
        if (sub.existsSync()) sub.deleteSync(recursive: true);
      }
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

    group('and it detects the callback TYPE, not a spelling', () {
      // Four planted evasions, each of which walked straight through the first
      // version of this gate — which matched eight literal substrings
      // (`VoidCallback`, `onPressed,`, …). None of those eight appears below.
      const String inlineFunctionType = '''
class Demo extends StatelessWidget {
  const Demo({super.key});
  final void Function(Offset) onPanUpdate;
  final bool Function() onSelected;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';
      const String namedDragCallback = '''
class Demo extends StatelessWidget {
  const Demo({super.key});
  final GestureDragUpdateCallback? onSwipe;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';
      const String genericallyTyped = '''
class Demo extends StatelessWidget {
  const Demo({super.key});
  final void Function(FocusNode, KeyEvent)? onKeyEvent;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';
      const String getterTyped = '''
class Demo extends StatelessWidget {
  const Demo({super.key});
  final VoidCallback get onPressed => () {};
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';

      for (final (String label, String source) in <(String, String)>[
        ('an inline `void Function(Offset)`', inlineFunctionType),
        ('a named drag callback type', namedDragCallback),
        ('a nullable inline function type', genericallyTyped),
        ('a callback-typed getter', getterTyped),
      ]) {
        test('catches $label', () {
          expect(
            _declaresACallback(source),
            isTrue,
            reason:
                '$label is a callback in the public surface however it is '
                'spelled, and the whole rule is about the type',
          );
        });
      }
    });

    group('and a doc comment cannot answer the ring question', () {
      // The evasion this fix exists for. The ring check was a bare
      // `source.contains`, so a doc comment explaining that a control is
      // *deliberately not* focusable satisfied the gate **and** shipped an
      // unringed drag surface. Comments are stripped first now, with the shared
      // stripper — the three inputs that broke the first copy (nesting, an
      // apostrophe in a `///` line, a triple-quoted block) cannot be re-broken
      // here because there is now only one implementation to break.
      const String ringInAComment = '''
/// Deliberately not an [EvaFocusRing]: this is reachable through
/// Semantics(onIncrease / onDecrease) instead, and a tab stop here would be a
/// third stop for one value.
class Demo extends StatelessWidget {
  const Demo({super.key});
  final GestureDragUpdateCallback? onSwipe;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}''';

      test('a comment naming the ring is not the ring', () {
        expect(_mentionsTheRing(ringInAComment), isFalse);
        expect(
          _mentionsTheRing(withoutDartComments(ringInAComment)),
          isFalse,
          reason:
              'and stripping the comments changes nothing — that is the point',
        );
      });

      test('but a real call still is', () {
        expect(
          _mentionsTheRing(
            'class A extends EvaFocusRing {}\n// and [EvaFocusRing] is named too',
          ),
          isTrue,
        );
      });
    });

    test('the delegation list is a decision, and its claims are checked', () {
      // The first version of this test asserted only `entry.reason.isNotEmpty`, so
      // a reason could be any string at all — including one that had quietly
      // stopped being true. Both current reasons happen to be accurate; nothing
      // enforced that.
      //
      // "Accurate" is mechanical here, not a matter of taste. A delegation says:
      // *every interactive surface in this file is one of these, and that widget
      // carries the ring.* So the claims are checked against the code — each named
      // surface is present, the symbol exists, the file builds nothing else
      // interactive, and the reason names what it delegates to.
      for (final _RingDelegation entry in _delegatesFocusRingTo.values) {
        final File file = File.fromUri(packageRoot.uri.resolve(entry.path));
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${entry.path} is listed as delegating but does not exist — an '
              'exemption pointing at nothing is worse than no exemption',
        );
        final String code = withoutDartComments(file.readAsStringSync());
        expect(
          code.contains('class ${entry.symbol}'),
          isTrue,
          reason:
              '${entry.path} is listed as delegating for ${entry.symbol}, and '
              'that class is not in it',
        );
        expect(
          entry.reason,
          isNotEmpty,
          reason: '${entry.path} delegates with no reason given',
        );
        for (final String surface in entry.surfaces) {
          expect(
            code.contains('$surface('),
            isTrue,
            reason:
                'the reason for ${entry.path} claims the ring is delegated to '
                '$surface, and the file no longer builds one. Either the '
                'delegation has become true — delete the entry — or false: carry '
                'the ring.',
          );
          expect(
            entry.reason,
            contains(surface),
            reason:
                'the reason must name what it delegates to, so it cannot drift '
                'away from ${entry.surfaces.join(', ')} unnoticed',
          );
        }
        expect(
          _unattributedSurfaces(entry.path, code),
          isEmpty,
          reason:
              '${entry.path} builds an interactive surface that '
              '${entry.surfaces.join(', ')} does not cover. A file-keyed '
              'exemption covers every surface ever added to it, which is the '
              'fourth evasion; the surfaces are enumerated instead, so adding one '
              'is a deliberate edit to this test.',
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

/// A widget whose **only** callback is an inline function type, with no ring and
/// no mention of one outside this sentence.
///
/// The exact shape of the planted evasion that used to survive: `dir.listSync()`
/// read one level, so `widgets/sub/zz.dart` was never walked; and the callback
/// detector matched spellings, so `final void Function(Offset) onPanUpdate;` was
/// not a "callback declaration". Both halves have to hold for the gate to pass
/// it, so both have to be exercised together.
const String _ringlessWidgetSource = '''
import 'package:flutter/widgets.dart';

/// A control with no ring, for the recursive-walk negative control.
class RinglessDrag extends StatelessWidget {
  const RinglessDrag({super.key});

  final void Function(Offset) onPanUpdate;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''';

/// Every widget file, recursively, failing closed.
///
/// `recursive: true` is the fix, not a default: without it the walk saw only the
/// files sitting directly in `widgets/`, and a new subtree was invisible to it —
/// which is a gate that cannot fail over an entire directory. Fails closed on an
/// unreadable directory and on an empty walk, per §7.
List<File> _widgetDartFiles() {
  final Directory dir = Directory.fromUri(
    packageRoot.uri.resolve('lib/core/design_system/widgets/'),
  );
  expect(dir.existsSync(), isTrue, reason: 'the widgets directory must exist');

  final List<File> files = <File>[];
  try {
    files.addAll(<File>[
      for (final FileSystemEntity entity in dir.listSync(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]);
  } on FileSystemException catch (error) {
    fail(
      'lib/core/design_system/widgets/ could not be walked: ${error.message}',
    );
  }
  return files;
}

/// One recorded decision: this file's interactive surfaces are entirely other
/// widgets that carry the ring themselves.
@immutable
class _RingDelegation {
  const _RingDelegation({
    required this.path,
    required this.symbol,
    required this.surfaces,
    required this.reason,
  });

  /// The widget file, package-relative.
  final String path;

  /// The class the decision is about. Checked, so an exemption cannot outlive the
  /// symbol it was written for.
  final String symbol;

  /// Every interactive surface the file is allowed to build.
  ///
  /// **The enumeration is the point.** A file-path exemption covers every surface
  /// ever added to that file: a second, ringless `GestureDetector` dropped into
  /// `error_view.dart` inherited the exemption for free. Naming the surfaces means
  /// a new one is an offender until someone decides about it here.
  final List<String> surfaces;

  /// Why the delegation is legitimate. Must name each surface, so it cannot go on
  /// describing something the file no longer does.
  final String reason;
}

/// The two files whose interactive surface is entirely a *child* widget that
/// carries the ring itself.
///
/// The source scan genuinely cannot see through them — it reads one file at a
/// time — so this list exists to record a **decision** rather than an omission,
/// and the behavioural gate above is what keeps each entry honest: it pumps
/// `ErrorView` and `FontSizeStepper` and fails if no ring appears. Delete an
/// entry's implementation of the ring and the behavioural gate goes red, which is
/// why this is a list with reasons and not a suppression comment.
const Map<String, _RingDelegation>
_delegatesFocusRingTo = <String, _RingDelegation>{
  'lib/core/design_system/widgets/error_view.dart': _RingDelegation(
    path: 'lib/core/design_system/widgets/error_view.dart',
    symbol: 'ErrorView',
    surfaces: <String>['EvaButton'],
    reason:
        'the only interactive surface is its retry action, which is an '
        'EvaButton — and EvaButton carries the ring. The behavioural gate '
        'above proves it renders by pumping exactly this widget.',
  ),
  'lib/core/design_system/widgets/font_size_stepper.dart': _RingDelegation(
    path: 'lib/core/design_system/widgets/font_size_stepper.dart',
    symbol: 'FontSizeStepper',
    surfaces: <String>['IconActionButton', 'GestureDetector'],
    reason:
        'the two steppers are IconActionButtons, which carry the ring. The '
        'track is a GestureDetector that is deliberately not focusable — it '
        'is reachable through Semantics onIncrease / onDecrease instead, so a '
        'screen-reader user is not offered a third tab stop.',
  ),
};

/// The interactive-surface constructors whose callbacks §14's ring row applies to.
///
/// Not `InkWell` / `InkResponse`: those reach the focus tree through
/// [EvaFocusRing]'s own node, so finding one is finding the ring. `GestureDetector`
/// brings its own recognisers and its own absence of any focus node, which is
/// exactly the shape the delegation list has to account for.
const List<String> _interactiveSurfaces = <String>[
  'GestureDetector',
  'EvaInk',
  'EvaFocusRing',
];

/// The interactive surfaces built by [code] that [_RingDelegation.surfaces] does
/// not list, as readable strings.
///
/// Comments are already out of [code] — [withoutDartComments] ran on it — so a
/// doc comment saying "deliberately not a GestureDetector" cannot be counted as
/// one. That is the fourth evasion, and this is what closes it.
List<String> _unattributedSurfaces(String path, String code) {
  final _RingDelegation? delegation = _delegatesFocusRingTo[path];
  if (delegation == null) return const <String>[];
  return <String>[
    for (final String surface in _interactiveSurfaces)
      if (!delegation.surfaces.contains(surface) && code.contains('$surface('))
        '$path builds $surface(, which the delegation does not list',
  ];
}

/// Whether [source] declares a callback in its public constructor.
///
/// ## THE TYPE, NOT THE SPELLING
///
/// The first version asked whether the file contained one of eight literal
/// substrings, which is an allowlist of *names* and misses by construction.
/// `final void Function(Offset) onPanUpdate;` is a callback in the public surface
/// of a widget, it is the shape `EvaFocusRing`'s own `onKeyEvent` is declared
/// with, and it was invisible.
///
/// So the rule is now the type: a named callback typedef, an inline function
/// type, or a **name** that reads as one. The name rule is the last resort and the
/// loosest, and it is why the two function-type patterns come first — for a
/// `final bool Function() onSelected` the type already answers, and the name
/// answer would have been luck.
///
/// `Function(` alone is not enough: `Iterable.map`'s `R Function(T)` and
/// `Widget Function()` — the shape every `build` override and every
/// `EvaFocusRingScope` constructor argument has — would make every widget in the
/// design system "interactive". The return type has to be there too.
final RegExp _inlineFunctionType = RegExp(
  r'\b(?:void|bool|int|double|num|String|Object|T|Future<[^>]*>|'
  r'KeyEventResult|SemanticsAction|Widget\?*)\s+Function\s*[<(]',
);

/// A declared parameter whose name reads as a callback.
///
/// `on[A-Z]…` followed by `,`, `=` or `)`, so `onPanUpdate`, `onSwipe:` and
/// `onPressed = null` are caught while a field called `only` is not.
final RegExp _callbackShapedName = RegExp(r'\bon[A-Z]\w*\s*[,=)]');

/// The named callback typedefs Flutter and this design system actually use.
///
/// A list rather than a pattern because there is no spelling of "a typedef ending
/// in `Callback`" that does not also match `GestureDragUpdateCallback?` written
/// *inside a doc comment* — and the list is short and stable for the same reason
/// the colour gate's marker list is.
const List<String> _callbackTypeNames = <String>[
  'VoidCallback',
  'GestureTapCallback',
  'GestureTapDownCallback',
  'GestureTapUpCallback',
  'GestureTapCancelCallback',
  'GestureDragStartCallback',
  'GestureDragUpdateCallback',
  'GestureDragEndCallback',
  'GestureDragDownCallback',
  'GestureDragCancelCallback',
  'GestureLongPressCallback',
  'GestureForcePressStartCallback',
  'ValueChanged<',
  'ValueGetter<',
  'ValueSetter<',
  'AsyncCallback',
  'ReorderCallback',
  'HoverCallback',
  'ScaleCallback',
  'ScrollEndNotificationCallback',
];

/// Whether [source] declares a callback in its public constructor.
///
/// [source] must already have its comments stripped — see [_mentionsTheRing] for
/// why that is not optional.
bool _declaresACallback(String source) =>
    _callbackTypeNames.any(source.contains) ||
    _inlineFunctionType.hasMatch(source) ||
    _callbackShapedName.hasMatch(source);

/// Whether [source] reaches §14's ring.
///
/// The five forms are the five ways the design system spells it, and they are
/// spelled out rather than reduced to a pattern because the reduction is what let
/// a doc comment through: this used to be a bare `source.contains` over the whole
/// file, comments included, so `/// Deliberately not an [EvaFocusRing]` satisfied
/// it and the unringed control beside the comment shipped.
bool _mentionsTheRing(String source) =>
    source.contains('extends EvaFocusRing') ||
    source.contains('EvaFocusRing(') ||
    source.contains('EvaFocusRingScope(') ||
    source.contains('evaFocusRingBorder(') ||
    source.contains('evaFocusRingSpec(');

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
