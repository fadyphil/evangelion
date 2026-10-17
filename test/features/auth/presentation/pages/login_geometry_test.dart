/// **Decision 8's harness, re-pointed.** AGENT_CONTEXT §9, decision 8, names this
/// phase as the owner of "a prototype-comparison harness — a line map plus a test
/// that renders the prototype and the Flutter widget over the same inputs and
/// compares geometry". Through Phase 4 that meant parsing `LoginScreen.tsx` and
/// `ds.tsx`. Phase 5.1 rebuilt the screen against `eva/redesign.html:503-511`,
/// and this file moved with it: **it now parses the redesign's own markup and
/// CSS**, extracts the declared geometry at test time, and compares that against
/// what the Flutter page actually rendered.
///
/// ## WHY THE PARSER READS THE FILE AND NOT A TABLE
///
/// Unchanged from the harness's first version, because the argument was never
/// about React: a hand-copied table of "the prototype says 34" is the same defect
/// in a new shape — the copy is made once, by the same reader, and the test then
/// asserts against it forever. Reading `eva/redesign.html` at test time means the
/// table cannot drift from the file, and a renumbered or reworded prototype rule
/// turns this suite red rather than leaving it confidently checking a line that
/// moved. `eva/` is read-only reference material (AGENT_CONTEXT §2, §8); the
/// harness asserts the file exists so a moved file is a failure, not an empty
/// extraction.
///
/// ## WHAT THE REDESIGN'S CSS LETS THE PARSER DO THAT THE TSX DID NOT
///
/// The React prototype put geometry in inline style objects keyed by camelCase;
/// the redesign puts it in **selector-keyed rules** — `.lmark`, `.field input`,
/// `.cta`, `.ghosts`, `.lfoot`. So the extractor is a rule reader, not a
/// line-number reader: `rule('.lmark')` returns the declarations between that
/// selector's braces, and a selector that stops existing is a failure with its
/// name on it. Line numbers appear in this file only in comments, as citations —
/// never as offsets the parser depends on.
///
/// ## AND WHAT IT STILL CANNOT SEE — carried over, because it is still true
///
/// * **Only geometry.** Colours and blurs are tokens Phase 2 settled; no test
///   here compares `rgba()` strings. `no_colour_literals_test` covers the design
///   system; a *wrong token* is still invisible to this suite.
/// * **Only what `RenderBox` exposes.** A `padding: 14px 16px` that became two
///   constants renders identically, and this cannot tell. It can tell 14 from
///   18.
/// * **Two divergences are recorded rather than papered over**, both named on
///   the constants they belong to: the field's 52 height against the CSS box's
///   padding-derived height (`kEvaTextFieldHeight`'s own doc), and the field's
///   reserved message line making the page's inter-field gaps the *sum* of the
///   prototype's box gap and the message line (`kEvaTextFieldMsgMinHeight`).
/// * **No golden is compared to `eva/`.** This file is the one that reads the
///   prototype.
library;

import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
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

import '../../../../support/login_harness.dart';

/// The prototype this harness reads.
const String prototype = 'eva/redesign.html';

/// The login section's markup, as the file draws it: one section, ids and
/// classes. `eva/redesign.html:503-511`.
const List<String> loginSectionMarkers = <String>[
  'id="rLogin"',
  'class="lmark"',
  'class="ltag mono"',
  'id="liEmail"',
  'id="liPass"',
  'id="liCta"',
  'class="ghosts"',
  'class="lfoot mono"',
];

/// Reads the prototype and returns the declarations inside `selector`'s rule.
///
/// The regex walks the file's `<style>` text for `\selector… { … }` and splits
/// the body on `;`. A missing rule **throws** — with `StateError`, not
/// `expect`, because this helper also runs at group-construction time, outside
/// any test body, where `expect` is illegal (`OutsideTestException`, measured).
/// The claims group below re-asserts the same conditions inside real tests.
Map<String, String> rule(String selector) {
  final File source = File(prototype);
  if (!source.existsSync()) {
    throw StateError(
      '$prototype is missing. This harness cannot read the prototype, so it '
      'does not pass — a missing reference is reported, never assumed '
      'unchanged.',
    );
  }
  final RegExpMatch? match = RegExp(
    // **Anchored to a line start**, because the stylesheet's selectors nest:
    // `.screen[data-mode=light] .field input` (`:85`) contains `.field input`
    // as a substring, and an unanchored search would read the light-mode
    // override — two declarations, no radius, no margin — as if it were the
    // rule. Every selector the claims table names starts its own line.
    '(^|\\n)${RegExp.escape(selector)}\\s*\\{([^}]*)\\}',
  ).firstMatch(source.readAsStringSync());
  if (match == null) {
    throw StateError(
      '$selector is not in $prototype any more. Either the prototype changed '
      'shape — in which case this harness and the page it guards both need '
      're-reading — or the selector was mistyped here.',
    );
  }
  return <String, String>{
    // `group(2)`, not 1: the line-start anchor added `(^|\n)` as the first
    // capture group, and reading group 1 would split a newline on `;` — the
    // empty map that failed the selector test below.
    for (final String declaration in match.group(2)!.split(';'))
      if (declaration.contains(':'))
        declaration.split(':').first.trim(): declaration
            .split(':')
            .skip(1)
            .join(':')
            .trim(),
  };
}

/// The numeric value of `property` in `declarations`, in logical pixels.
///
/// CSS lengths here are `Npx`; anything else (a bare `0`, a percentage, an `em`)
/// is a shape the caller converts deliberately, because the conversion is the
/// claim — see `kWordmarkTracking`'s row, whose value is `.3em` **of 26px** and
/// whose conversion is the whole content of the constant. Throws, for the same
/// out-of-test reason [rule] does.
double px(Map<String, String> declarations, String property) {
  final String? raw = declarations[property];
  if (raw == null) {
    throw StateError('$property is not declared where the harness looked.');
  }
  final RegExpMatch? match = RegExp(r'(-?\d+(?:\.\d+)?)px?').firstMatch(raw);
  if (match == null) {
    throw StateError(
      '$property is "$raw", which is not a pixel length this parser reads. If '
      'the prototype changed units, the conversion is a claim and belongs in a '
      'constant with its reasoning — not in this helper.',
    );
  }
  return double.parse(match.group(1)!);
}

void main() {
  group('the prototype file, as this harness reads it', () {
    test('exists, and still contains the login section', () {
      final String html = File(prototype).readAsStringSync();
      for (final String marker in loginSectionMarkers) {
        expect(
          html.contains(marker),
          isTrue,
          reason:
              'the login section lost `$marker`. The harness reads the '
              'prototype\'s own markup; a section that changed shape is a '
              'failure here before it is a silent drift in the page.',
        );
      }
    });

    test('every selector the claims table names resolves to a real rule', () {
      for (final String selector in <String>[
        '.login',
        '.lmark',
        '.ltag',
        '.field',
        '.field input',
        '.field .msg',
        '.cta',
        '.ghosts',
        '.ghosts button',
        '.lfoot',
      ]) {
        expect(
          rule(selector),
          isNotEmpty,
          reason: '$selector resolved to no declarations',
        );
      }
    });
  });

  group('the page publishes the prototype\'s numbers, not its own', () {
    // One row per constant: what it is, which rule declares it, and the value
    // extracted from that rule **at test time**. The expected column is
    // computed, never hand-typed — a hand-typed 34 here would be the second
    // copy this harness exists to prevent.
    final Map<String, String> login = rule('.login');
    // A local alias only so the rows below read like a table; `rule` itself is
    // already const-callable, so the alias is too.
    const Map<String, String> Function(String) at = rule;

    test('kRootGutter is `.login`\'s horizontal padding', () {
      // `padding: 0 34px` — the vertical half is 0 and the horizontal half is
      // the gutter. The parser reads the pair; the page passes the horizontal
      // one to `NeuralScaffold`.
      expect(px(login, 'padding'), LoginPage.kRootGutter);
    });

    test('kWordmarkSize is `.lmark`\'s font-size', () {
      expect(px(at('.lmark'), 'font-size'), LoginPage.kWordmarkSize);
    });

    test('kWordmarkTracking is `.lmark`\'s .3em at that size', () {
      // The conversion is the claim: CSS tracks in `em` of the element's own
      // size, Flutter in px, so the constant is `letter-spacing` ×
      // `font-size` — both extracted, their product asserted.
      final Map<String, String> mark = at('.lmark');
      final double em = double.parse(
        RegExp(r'([\d.]+)em').firstMatch(mark['letter-spacing']!)!.group(1)!,
      );
      expect(em * LoginPage.kWordmarkSize, LoginPage.kWordmarkTracking);
    });

    test('kMarkToTagGap is `.lmark`\'s margin-bottom', () {
      expect(px(at('.lmark'), 'margin-bottom'), LoginPage.kMarkToTagGap);
    });

    test('kTagToFieldsGap is `.ltag`\'s margin-bottom', () {
      expect(px(at('.ltag'), 'margin-bottom'), LoginPage.kTagToFieldsGap);
    });

    test('kFieldGap is `.field`\'s margin-bottom', () {
      expect(px(at('.field'), 'margin-bottom'), LoginPage.kFieldGap);
    });

    test('kCtaTopGap is `.field`\'s margin and `.cta`\'s, summed', () {
      // Flex does not collapse margins (`:128` — `.route` is `display:flex`),
      // so the rendered gap between the last field's box and the CTA is the
      // **sum** of the two margins. Both are extracted; their sum is the
      // constant.
      expect(
        px(at('.field'), 'margin-bottom') + px(at('.cta'), 'margin-top'),
        LoginPage.kCtaTopGap,
      );
    });

    test(
      'kGhostsGap and kGhostsTopGap are `.ghosts`\'s gap and margin-top',
      () {
        final Map<String, String> ghosts = at('.ghosts');
        expect(px(ghosts, 'gap'), LoginPage.kGhostsGap);
        expect(px(ghosts, 'margin-top'), LoginPage.kGhostsTopGap);
      },
    );

    test('kFooterBottomGap is `.lfoot`\'s bottom', () {
      expect(px(at('.lfoot'), 'bottom'), LoginPage.kFooterBottomGap);
    });

    test('the field box\'s radius is `EvaRadii.input`, and that is 14', () {
      // The box moved to `:376-379` in Phase 4; the token it names is the
      // palette's, and this is the join between the two: the CSS says 14px,
      // the token says 14, and if either moves this goes red.
      expect(px(at('.field input'), 'border-radius'), EvaRadii.input);
      expect(EvaRadii.input, 14.0);
    });

    test('the buttons are pills, and the token is the CSS\'s 999', () {
      // `:381` for `.cta`, `:388` for `.ghosts button` — both pills, and the
      // design system's `kEvaButtonRadius` names `EvaRadii.chip` for exactly
      // that shape.
      expect(px(at('.cta'), 'border-radius'), kEvaButtonRadius);
      expect(px(at('.ghosts button'), 'border-radius'), kEvaButtonRadius);
      expect(kEvaButtonRadius, 999.0);
    });

    test('the message line\'s reservation is `.msg`\'s, whole', () {
      // The page's inter-field gaps are the prototype's **sums**: the field
      // box's margin plus the always-reserved message line below the input.
      // `kEvaTextFieldMsgMinHeight` and `kEvaTextFieldMsgGap` are the widget's
      // half of that sum, and the CSS is the other.
      final Map<String, String> msg = at('.field .msg');
      expect(px(msg, 'min-height'), kEvaTextFieldMsgMinHeight);
      expect(px(msg, 'margin-top'), kEvaTextFieldMsgGap);
    });
  });

  group('the geometry the widget actually rendered', () {
    // The other half: read the **rendered** boxes rather than the page's constants.
    // A constant can be right while the widget ignores it, and a widget can be right
    // while its constant is a lie; only the render box settles it.
    late AuthBloc bloc;

    setUp(() {
      final FakeAuthRepository repository = FakeAuthRepository(
        AuthLocalDataSource(),
      );
      bloc = AuthBloc(
        signIn: SignIn(repository),
        getCurrentSession: GetCurrentSession(repository),
        signOut: SignOut(repository),
      );
    });
    tearDown(() => bloc.close());

    /// Past the wordmark's entrance, so the letters rest at their end state
    /// before any box is measured.
    Future<void> pumpSettled(WidgetTester tester) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));
      await tester.pump(const Duration(milliseconds: 1200));
    }

    testWidgets('the root gutter is the prototype\'s 34', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      final NeuralScaffold scaffold = tester.widget<NeuralScaffold>(
        find.byType(NeuralScaffold),
      );
      expect(scaffold.padding.horizontal / 2, LoginPage.kRootGutter);
      // And the field actually sits at it, not at the scaffold's default:
      expect(
        tester.getTopLeft(find.byType(EvaTextField).first).dx,
        LoginPage.kRootGutter,
      );
    });

    testWidgets('the wordmark renders 26px Inter at 7.8px of tracking', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      final Text letter = tester.widget<Text>(find.text('V'));
      expect(letter.style!.fontSize, LoginPage.kWordmarkSize);
      expect(letter.style!.letterSpacing, LoginPage.kWordmarkTracking);
      expect(letter.style!.fontWeight, FontWeight.w800);
    });

    testWidgets('the vertical rhythm is 6 · 34 · 14 · 22 · 14 · 10', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      final AppLocalizationsEn en = AppLocalizationsEn();
      // mark → tag: `.lmark`'s margin-bottom. The letters' boxes are the
      // wordmark's own box (the Stack sizes to the row), and the tagline's box
      // starts where the 6px `SizedBox` ends — both are widget boxes, so the
      // read is the margin and not a leading artefact.
      final double markBottom = tester.getBottomRight(find.text('V')).dy;
      final double tagTop = tester
          .getTopLeft(find.text(_monoUpper(LoginPage.kTaglineText)))
          .dy;
      expect(tagTop - markBottom, moreOrLessEquals(LoginPage.kMarkToTagGap));
      // tag → first field: `.ltag`'s margin-bottom.
      final double tagBottom = tester
          .getBottomRight(find.text(_monoUpper(LoginPage.kTaglineText)))
          .dy;
      final double fieldTop = tester
          .getTopLeft(find.byType(EvaTextField).first)
          .dy;
      expect(fieldTop - tagBottom, moreOrLessEquals(LoginPage.kTagToFieldsGap));
      // field → field: `.field`'s margin-bottom, between the two widgets —
      // whose boxes now include the reserved message line, exactly as the
      // prototype's `.field` boxes include theirs.
      final double field1Bottom = tester
          .getBottomRight(find.byType(EvaTextField).first)
          .dy;
      final double field2Top = tester
          .getTopLeft(find.byType(EvaTextField).at(1))
          .dy;
      expect(field2Top - field1Bottom, moreOrLessEquals(LoginPage.kFieldGap));
      // field → CTA: the two flex margins, summed — see the claims row.
      final Finder cta = find.ancestor(
        of: find.text(en.authEnterTheWord),
        matching: find.byType(EvaButton),
      );
      final double ctaTop = tester.getTopLeft(cta).dy;
      final double field2Bottom = tester
          .getBottomRight(find.byType(EvaTextField).at(1))
          .dy;
      expect(ctaTop - field2Bottom, moreOrLessEquals(LoginPage.kCtaTopGap));
      // CTA → ghosts: `.ghosts`' margin-top, button box to button box.
      final Finder google = find.ancestor(
        of: find.text(LoginPage.kGhostGoogle),
        matching: find.byType(EvaButton),
      );
      final double ghostsTop = tester.getTopLeft(google).dy;
      final double ctaBottom = tester.getBottomRight(cta).dy;
      expect(ghostsTop - ctaBottom, moreOrLessEquals(LoginPage.kGhostsTopGap));
      // ghost → ghost: `.ghosts`' gap, across the two pills' boxes.
      final double googleRight = tester.getTopRight(google).dx;
      final double appleLeft = tester
          .getTopLeft(
            find.ancestor(
              of: find.text(LoginPage.kGhostApple),
              matching: find.byType(EvaButton),
            ),
          )
          .dx;
      expect(appleLeft - googleRight, moreOrLessEquals(LoginPage.kGhostsGap));
    });

    testWidgets('the footer rides 26px above the viewport\'s bottom edge', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      final Size surface =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final double footerBottom = tester
          .getBottomRight(find.text(_monoUpper(LoginPage.kFooterText)))
          .dy;
      // The footer's TEXT box, not its padding: the overlay's `Align` puts the
      // text 26 above the bottom, and the text's own leading sits inside that.
      expect(
        surface.height - footerBottom,
        moreOrLessEquals(LoginPage.kFooterBottomGap, epsilon: 8),
        reason:
            'the text\'s leading is inside the reserved band, so the read '
            'is the band\'s bottom edge minus the glyphs, within a leading',
      );
    });

    testWidgets('the field renders 52 tall over the reserved message line', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      // The box: 52 (the recorded divergence — the CSS box is padding-derived
      // and lands 43–45; `kEvaTextFieldHeight`'s doc owns that argument). The
      // shell is the field's Row — the inner `TextField` is the editable inside
      // it and is 24 tall on its own. The column: 52 + 5 + 13 — the reserved
      // line below the shell, which is the page's other half of every
      // inter-field gap.
      final EvaTextField field = tester.widget<EvaTextField>(
        find.byType(EvaTextField).first,
      );
      expect(field.showLabel, isFalse, reason: 'the redesign\'s field is bare');
      final double shellHeight = tester
          .getSize(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byType(EvaTextField).first,
                    matching: find.byType(TextField),
                  ),
                  matching: find.byType(Row),
                )
                .first,
          )
          .height;
      expect(shellHeight, kEvaTextFieldHeight);
      final double columnHeight = tester
          .getSize(find.byType(EvaTextField).first)
          .height;
      expect(
        columnHeight,
        moreOrLessEquals(
          kEvaTextFieldHeight + kEvaTextFieldMsgGap + kEvaTextFieldMsgMinHeight,
        ),
      );
    });

    testWidgets('the section\'s elements are the page\'s elements', (
      WidgetTester tester,
    ) async {
      await pumpSettled(tester);

      // `eva/redesign.html:503-511`, element for element: one mark, one tag,
      // two bare fields, one CTA, two ghost pills, one footer. Counted, because
      // a screen missing one element is still a screen — the same reason
      // `login_page_test.dart` enumerates, from the geometry side: a count here
      // is what catches the page rendering a `.field`'s worth of extra widget.
      expect(find.text('V'), findsOneWidget);
      expect(find.text(_monoUpper(LoginPage.kTaglineText)), findsOneWidget);
      expect(find.byType(EvaTextField), findsNWidgets(2));
      expect(find.byType(EvaButton), findsNWidgets(3));
      expect(find.text(_monoUpper(LoginPage.kFooterText)), findsOneWidget);
    });
  });

  group('the extraction is not vacuous', () {
    test('the login rules declare far more numbers than the claims read', () {
      // The claims table is a **selection** — the layout the page actually
      // transcribes — and this is the check that the selection is small
      // relative to what the prototype declares. If the prototype's login CSS
      // ever shrinks to roughly the claims' size, the harness is reading a
      // different block than the one it thinks it is reading.
      int declared = 0;
      for (final String selector in <String>[
        '.login',
        '.lmark',
        '.ltag',
        '.field',
        '.field input',
        '.field input:focus',
        '.field .msg',
        '.cta',
        '.ghosts',
        '.ghosts button',
        '.lfoot',
      ]) {
        declared += rule(selector).length;
      }
      expect(declared, greaterThan(30));
    });
  });
}

/// `.mono`'s LTR uppercase, spelled the way the page spells it.
String _monoUpper(String source) => source.toUpperCase();
