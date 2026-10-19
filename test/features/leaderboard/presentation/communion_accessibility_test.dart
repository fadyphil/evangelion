import 'dart:ui' show Tristate;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_app_bar.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// §14 for `/communion`'s app bar — the two controls the prototype draws at
/// `eva/redesign.html:614` (`.chev`) and `:616` (`.iconbtn`).
///
/// ## WHAT THE DEFECT WAS, MEASURED
///
/// The app bar used to build both controls from a private `_IconHit`: a bare
/// `GestureDetector` inside a `Tooltip`. A probe over that shape found:
///
/// * **zero** `FocusableActionDetector`s in the bar, and four `Tab` presses
///   left the focus on the modal scope's `FocusScope` — so **neither control
///   was keyboard-reachable** and §14's focus ring could never paint on
///   either of them;
/// * a semantics node with `label=""`, `isButton == false`, and a tap action
///   and nothing else. `RenderSemanticsGestureHandler` sets `config.onTap`
///   but **not** `config.isButton`, and a `Tooltip` contributes only a
///   `semanticsTooltip` — never a `label`.
///
/// So the two controls were **announced with no name** and were **not
/// buttons**. On desktop the back chevron is the **only** way out of
/// `/communion` — there is no bottom nav and no system back — so a
/// keyboard-only reader could land on this screen and never leave it.
///
/// ## AND WHY THE FIX IS `IconActionButton`
///
/// The `_IconHit`'s own doc justified itself by saying `IconActionButton`
/// "cannot express" a 30px control inside a 44px app bar "because it is a
/// 44px pill". That is false, and `icon_action_button.dart:43-52` says so in
/// its own words: the pill is a **30px silhouette inside the existing 44px
/// box**. The shipped widget already models the prototype's two app-bar roles
/// — the bare `.chev` glyph (`:149`) and the 30px `.iconbtn` pill (`:151`)
/// with its `.lit` state (`:154`) — and it carries the focus node, the ring,
/// the name and the tap action.
///
/// ## THE FIVE CHECKS, ONE TEST EACH
///
/// A control that is reachable, ringed, named, a button, and pressable is
/// five separate claims, and a failure that names only the *line* it failed
/// on cannot say which claim broke. So each check is its own `testWidgets`,
/// and each is generated for **both** controls — which is why a failure names
/// the check *and* the control.
///
/// ## AND THE NEGATIVE CONTROL, BECAUSE A SUITE THAT CANNOT FAIL IS WORSE
///
/// ## THAN NO SUITE
///
/// The last group builds a control with the **shape** of a compliant one and
/// **none** of the behaviour — the removed `_IconHit`, verbatim — and watches
/// every one of the five checks go red. Without it, "the two controls are
/// reachable, ringed, named, buttons and pressable" and "the five checks are
/// measuring nothing" are indistinguishable from the outside.
void main() {
  for (final ({String role, IconData icon, bool isBack}) control
      in <({String role, IconData icon, bool isBack})>[
        (
          role: 'the back chevron',
          icon: Icons.arrow_back_ios_new,
          isBack: true,
        ),
        (
          role: 'the veil toggle',
          icon: Icons.visibility_outlined,
          isBack: false,
        ),
      ]) {
    group(control.role, () {
      testWidgets('is a tab stop', (WidgetTester tester) async {
        await _pumpAppBar(tester, onBack: _noop, onToggleVeil: _noop);

        _expectControlPresent(tester, control.icon, control.role);
        final Finder button = _control(control.icon);

        // `tabUntilFocused` is the mechanical form of "can a keyboard reach
        // this?", and it is the **strict** one: it returns only when the
        // *primary* focus is inside the finder, so a Tab that landed on the
        // modal scope's `FocusScope` — the old defect's exact symptom — does
        // not count. It throws a `StateError` rather than failing an
        // `expect`, so an unreachable control fails loudly and by name.
        await tabUntilFocused(tester, button);
      });

      testWidgets('paints §14\'s ring when focused', (
        WidgetTester tester,
      ) async {
        await _pumpAppBar(tester, onBack: _noop, onToggleVeil: _noop);

        _expectControlPresent(tester, control.icon, control.role);
        final Finder button = _control(control.icon);
        await tabUntilFocused(tester, button);

        // `renderedBorders` reads what is **PAINTED**, not what the widget
        // declares. A gate that re-derives the number under test agrees with
        // a wrong widget whenever both are wrong the same way.
        expect(
          renderedBorders(tester, button),
          contains(evaFocusRingBorder(_darkColors)),
          reason:
              '§14 — ${control.role} took focus but painted no 2px ember-at-40% '
              'border.',
        );
      });

      testWidgets('has a non-empty accessible name', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await _pumpAppBar(tester, onBack: _noop, onToggleVeil: _noop);

          final SemanticsData node = _nodeNamed(
            tester,
            await _name(control.isBack),
          );
          expect(
            node.label.trim(),
            isNotEmpty,
            reason:
                '§14\'s first row: an icon-only control with no accessible name. '
                'A `Tooltip` contributes a `semanticsTooltip` and never a '
                '`label`, so the name has to be published as one.',
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('reports itself as a button', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await _pumpAppBar(tester, onBack: _noop, onToggleVeil: _noop);

          final SemanticsData node = _nodeNamed(
            tester,
            await _name(control.isBack),
          );
          expect(
            node.flagsCollection.isButton,
            isTrue,
            reason:
                '§14 — ${control.role} is a button and must say so. A '
                '`GestureDetector` publishes `config.onTap` and never '
                '`config.isButton`, so a reader is told "tap here" on '
                'something that announces as a plain group.',
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('offers a tap action, and the tap reaches its callback', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          final _Calls back = _Calls();
          final _Calls veil = _Calls();
          await _pumpAppBar(tester, onBack: back.call, onToggleVeil: veil.call);

          final SemanticsData node = _nodeNamed(
            tester,
            await _name(control.isBack),
          );
          expect(
            node.hasAction(SemanticsAction.tap),
            isTrue,
            reason:
                '§14 — ${control.role} offers a reader nothing to press. A node a '
                'reader can name but not activate is this row\'s whole defect, and '
                'the pointer path (`tester.tap`) never sees it.',
          );

          // The **screen-reader** path, not the pointer one. `tester.semantics
          // .tap` performs `SemanticsAction.tap` on the node the reader would
          // land on, which is the path a TalkBack double-tap takes.
          final _Calls own = control.isBack ? back : veil;
          final _Calls other = control.isBack ? veil : back;

          tester.semantics.tap(find.semantics.byLabel(node.label));
          await tester.pump();

          expect(own.count, 1, reason: '${control.role} ran its own callback');
          expect(
            other.count,
            0,
            reason: 'and did not run the other control\'s',
          );
        } finally {
          handle.dispose();
        }
      });
    });
  }

  group('the inert chevron', () {
    testWidgets('announces itself as disabled and offers no action', (
      WidgetTester tester,
    ) async {
      // `onBack: null` is the shape a screen with no route behind it can
      // honestly offer, and §14's disabled row is about the **action being
      // absent** — not about a flag that says "disabled" while the control
      // still responds. A reader who presses a control announced as disabled
      // and gets a response has been told a lie.
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpAppBar(tester, onBack: null, onToggleVeil: _noop);

        final String name = await _name(true);
        final SemanticsData node = _nodeNamed(tester, name);
        expect(
          node.flagsCollection.isEnabled,
          isNot(Tristate.isTrue),
          reason: 'the inert chevron does not announce itself as enabled',
        );
        expect(
          node.hasAction(SemanticsAction.tap),
          isFalse,
          reason: 'and it offers no tap, because there is nothing behind one',
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('the negative control, so this suite is known to bite', () {
    testWidgets('the old shape fails all five checks', (
      WidgetTester tester,
    ) async {
      // The removed `_IconHit`, verbatim: a `Tooltip` over a bare
      // `GestureDetector` in a 44px box. It has the **shape** of a compliant
      // control — a glyph, a hit target, a tooltip — and none of the
      // behaviour. Every check below is the check the real controls pass.
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpControl(tester, const _OldShapeIconHit());
        final Finder control = find.byType(_OldShapeIconHit);

        // 1 — **not a tab stop.** The old shape built no focus node at all,
        // so Tab walked straight past it and landed on the scope.
        //
        // **Awaited inside a helper rather than through `expectLater`**, because
        // `expectLater(future, …)` evaluates its future argument *before* it
        // enters the guarded zone — and the guarded `sendKeyEvent` inside
        // `tabUntilFocused` is still in flight at that moment, which the
        // framework reports as a "guarded function conflict" rather than as
        // the failure this row is about.
        expect(
          await _caught(() => tabUntilFocused(tester, control)),
          isA<StateError>(),
          reason:
              'the old shape was unreachable by keyboard, which is the defect\'s '
              'first half',
        );

        // 2 — **no ring.** Nothing painted a border, focused or not.
        expect(
          renderedBorders(tester, control),
          isEmpty,
          reason: 'the old shape painted no border of any kind',
        );
        expect(
          () => _expectRing(tester, control),
          throwsA(isA<TestFailure>()),
          reason:
              'and so the ring assertion the two real controls pass fails on it — '
              'which is the only reason the two passes are worth anything',
        );

        // 3, 4 and 5 — a tap with **no name** and **not a button**.
        //
        // The tap action itself was there, and that is exactly why the defect
        // survived: every committed test used the **pointer** path, which
        // never consults the semantics tree.
        final List<SemanticsData> tappable = nodesOffering(
          tester,
          SemanticsAction.tap,
        );
        expect(
          tappable,
          hasLength(1),
          reason:
              'the old shape did publish a tap — which is why the pointer path '
              'never noticed anything was wrong',
        );
        expect(
          tappable.single.label,
          isEmpty,
          reason: 'and it announced no name at all',
        );
        expect(
          tappable.single.flagsCollection.isButton,
          isFalse,
          reason: 'and it was not a button',
        );
        expect(
          () => _expectNamedButton(tester, 'Ringless'),
          throwsA(isA<TestFailure>()),
          reason:
              'so the check the two real controls pass — a node with that name, '
              'a button, offering a tap — fails on it',
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

/// The two controls' widgets, found by the glyph they draw.
///
/// The bar builds two `IconActionButton`s and the widget itself carries no
/// key, so the glyph is the honest way to tell them apart — and it is the
/// glyph the reader sees.
Finder _control(IconData icon) => find.byWidgetPredicate(
  (Widget w) => w is IconActionButton && w.icon == icon,
);

/// The glyph itself, found by its `IconData`.
///
/// **Implementation-agnostic on purpose**: the control is on the bar if it
/// draws the glyph, whatever it is built from.
Finder _glyph(IconData icon) =>
    find.byWidgetPredicate((Widget w) => w is Icon && w.icon == icon);

/// Asserts that the control is on the bar, and that it is the shipped widget.
///
/// The two assertions say different things on purpose. The **glyph** check is
/// implementation-agnostic — the control is there if it draws the glyph. The
/// `IconActionButton` check says what it has to *be*: the widget that carries
/// the focus node, the §14 ring, the accessible name and the tap action. A
/// control that is a bare `GestureDetector` again is the defect this suite
/// exists for, and the failure has to name that rather than say "0 widgets".
void _expectControlPresent(WidgetTester tester, IconData icon, String role) {
  expect(_glyph(icon), findsOneWidget, reason: '$role draws its glyph at all');
  expect(
    _control(icon),
    findsOneWidget,
    reason:
        '$role is built as an `IconActionButton` — the shipped widget that '
        'carries the focus node, the §14 ring, the accessible name and the tap '
        'action. A control that is a bare `GestureDetector` again is the '
        'defect this suite exists for.',
  );
}

/// The accessible name a control is expected to carry.
///
/// The back chevron's name is the **framework's** — `MaterialLocalizations`'
/// `backButtonTooltip` — and the veil's is the app's own `leaderboardVeil`.
/// Both are read from their owner rather than typed here, because a
/// hand-typed string in a test is a second copy of the corpus.
Future<String> _name(bool isBack) async => isBack
    ? (await GlobalMaterialLocalizations.delegate.load(const Locale('en')))
          .backButtonTooltip
    : AppLocalizationsEn().leaderboardVeil;

/// The one [SemanticsData] whose label is [name].
SemanticsData _nodeNamed(WidgetTester tester, String name) {
  final Iterable<SemanticsData> matches = semanticsTree(tester)
      .where((SemanticsData data) => data.label == name);
  expect(matches, hasLength(1), reason: 'exactly one node announces `$name`');
  return matches.single;
}

/// §14's ring, read off what is **painted**.
void _expectRing(WidgetTester tester, Finder target) {
  expect(
    renderedBorders(tester, target),
    contains(evaFocusRingBorder(_darkColors)),
  );
}

/// The whole of the naming half of §14's rows, as one check.
///
/// Extracted so the negative control can watch it fail rather than
/// re-implementing it — the same idiom `focus_ring_gate_test.dart` uses for
/// its `_expectRing`.
void _expectNamedButton(WidgetTester tester, String name) {
  final SemanticsData node = _nodeNamed(tester, name);
  expect(node.label.trim(), isNotEmpty);
  expect(node.flagsCollection.isButton, isTrue);
  expect(node.hasAction(SemanticsAction.tap), isTrue);
}

/// The colours the ring is specified against.
EvaColors get _darkColors => EvaThemeDark.theme.extension<EvaColors>()!;

/// The error [action] threw, or `null` if it threw nothing.
Future<Object?> _caught(Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (error) {
    return error;
  }
  return null;
}

/// Pumps the app bar with the two callbacks under test.
Future<void> _pumpAppBar(
  WidgetTester tester, {
  required VoidCallback? onBack,
  required VoidCallback onToggleVeil,
  bool isVeiled = false,
}) => _pumpControl(
  tester,
  CommunionAppBar(
    title: 'The Communion',
    isVeiled: isVeiled,
    onToggleVeil: onToggleVeil,
    onBack: onBack,
  ),
);

/// Pumps [child] in the arrangement the app's own screens are pumped in.
///
/// The app's `localizationsDelegates` are needed for two reasons: the veil's
/// name comes from the app's ARB, and the back chevron's comes from
/// `MaterialLocalizations`, whose `Default` pair resolves only `en`.
Future<void> _pumpControl(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
  await tester.pump();
}

/// A callback that counts how many times it ran.
class _Calls {
  int count = 0;

  void call() => count++;
}

void _noop() {}

/// The removed `_IconHit`, verbatim — the negative control.
///
/// It has the **shape** of a compliant control (a 44px box, a glyph, a
/// tooltip) and **none** of the behaviour: no focus node, no ring, no
/// accessible name, and no `isButton`. Its one present behaviour is the tap
/// action a `GestureDetector` publishes — which is precisely why the defect
/// survived every committed test.
class _OldShapeIconHit extends StatelessWidget {
  const _OldShapeIconHit();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Ringless',
    textStyle: const TextStyle(fontFamily: EvaTypography.uiFamily),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(child: Icon(Icons.arrow_back_ios_new, size: 16)),
      ),
    ),
  );
}
