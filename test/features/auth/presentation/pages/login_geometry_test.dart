/// **Decision 8's harness.** AGENT_CONTEXT §9, decision 8, names this phase as the
/// owner of "a prototype-comparison harness — a `ds.tsx` line map plus a test that
/// renders the React component and the Flutter widget over the same inputs and
/// compares geometry".
///
/// ## WHAT THE GAP ACTUALLY IS
///
/// "A golden captures whatever the widget currently renders" — so a
/// **systematic** transcription error, present in both the widget and its golden,
/// is invisible by construction. Phase 3 found exactly one such error (`TextLink`'s
/// chevron inked `ink` where `ds.tsx:283` writes `hex.ember`) and found it by
/// *reading the prototype*, not by any test failing.
///
/// This file closes the narrow, mechanical half of that gap for the one screen this
/// phase writes. It cannot render the React component — there is no JS runtime in
/// this test process and `eva/` is reference material (AGENT_CONTEXT §2, §8). So it
/// does the next mechanical thing: **it parses `LoginScreen.tsx` and
/// `ds.tsx`, extracts the declared geometry, and compares that against what the
/// Flutter widget actually rendered.** The prototype's numbers are an input; a
/// transcription slip becomes a failing assertion rather than a ratified golden.
///
/// ## WHY A PARSER AND NOT A HAND-COPIED TABLE
///
/// A hand-copied table of "the prototype says 72" is the same defect in a new
/// shape: the copy is made once, by the same reader, and the test then asserts
/// against it forever. Reading the `.tsx` at test time means the table cannot
/// drift from the file, and a *renumbering* of `LoginScreen.tsx` turns this suite
/// red rather than leaving it confidently checking a line that moved.
///
/// ## AND WHAT IT STILL CANNOT SEE — stated, not discovered in Phase 9
///
/// * **Only geometry.** Colours, radii and blur radii are tokens this phase reads
///   from the palette, and no test here compares them to the prototype's
///   `rgba()` strings. `no_colour_literals_test` covers the design system; a
///   *wrong token* is still invisible to this suite.
/// * **Only what `RenderBox` exposes.** A `padding: 24` that became
///   `EdgeInsets.all(24)` renders identically, and this cannot tell. It can tell
///   20 from 24.
/// * **`ds.tsx` is read for its line numbers, `LoginScreen.tsx` for its numbers.**
///   `ds.tsx` supplies the shared component geometry (the field's 52, the button's
///   52); `LoginScreen.tsx` supplies this screen's own (the 72 spacer, the 28
///   radius). Where a value appears in both, the screen's own copy is the one
///   transcribed — and `LoginPage`'s doc cites the screen for exactly that reason.
/// * **No golden is compared to `eva/`.** `golden_pairs_test.dart` remains the
///   narrow dark-vs-light check it says it is. This file is the one that reads the
///   prototype.
library;

import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
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

import '../../../../support/login_harness.dart';

/// One declared number in a `.tsx` file.
final class PrototypeValue {
  /// A value of [value] declared at [line] of [file].
  const PrototypeValue({
    required this.label,
    required this.file,
    required this.line,
    required this.value,
  });

  /// What the number is, in this project's words.
  final String label;

  /// The prototype file, relative to the repository root.
  final String file;

  /// The 1-based line the number is declared on.
  final int line;

  /// The number itself.
  final double value;

  @override
  String toString() => '$label = $value  ($file:$line)';
}

/// The prototype files this harness reads.
///
/// `eva/` is **reference material and is never written to** (AGENT_CONTEXT §2, §8);
/// these are read-only paths and the harness asserts they exist so a moved file is a
/// failure rather than an empty extraction.
const String loginScreen = 'eva/src/screens/LoginScreen.tsx';

const String dsComponents = 'eva/src/components/ds.tsx';

/// Every `fontSize: N` / `width: N` / `height: N` / `marginBottom: N` declaration in
/// [file], keyed by the text immediately preceding it.
///
/// A single regex rather than one per property, because the point is to notice a
/// number the prototype declares and this phase **failed** to transcribe — which
/// means the enumeration cannot be limited to the properties already accounted for.
Map<String, PrototypeValue> declaredValues(String file) {
  final File source = File(file);
  expect(
    source.existsSync(),
    isTrue,
    reason:
        '$file is missing. This harness cannot read the prototype, so it does not '
        'pass — a missing reference is reported, never assumed unchanged.',
  );

  final Map<String, PrototypeValue> found = <String, PrototypeValue>{};
  final List<String> lines = source.readAsLinesSync();
  // `key: 42` and `key: '42'` both occur; the second is a string and is skipped.
  final RegExp declaration = RegExp(r'(\w+):\s*(\d+(?:\.\d+)?)\b');

  for (int i = 0; i < lines.length; i++) {
    // `allMatches`, not `firstMatch`: React style objects put **several**
    // declarations on one line — `LoginScreen.tsx:11` alone has `flex: 1`,
    // `padding: '0 24px'` and `minHeight: 844` — and a first-match loop therefore
    // never saw the `minHeight` the anti-vacuity test below looks for. That test
    // failed on its first run for exactly that reason, which is what it is for.
    for (final RegExpMatch match in declaration.allMatches(lines[i])) {
      final double value = double.parse(match.group(2)!);
      // A `0` in a style object is a structural `zIndex: 0` or a `lineHeight: 0`
      // nobody transcribes; the ones that matter are the non-zero geometry.
      if (value == 0) {
        continue;
      }
      // Keyed by **line number** and property, not by the property's offset in the
      // line: an offset key collides between two lines that share a column, and a
      // colliding key silently drops one of them. That is not hypothetical — the
      // first version of this function used an offset key, the extraction returned
      // exactly as many entries as the claims table had, and the anti-vacuity test
      // below correctly refused to believe it.
      found['$i:${match.group(1)}'] = PrototypeValue(
        label: match.group(1)!,
        file: file,
        line: i + 1,
        value: value,
      );
    }
  }
  return found;
}

/// One transcription claim: a prototype line, the value on it, and — where this
/// page publishes a constant for it — the symbol that constant lives in.
typedef PrototypeClaim = ({
  String label,
  int line,
  double expected,
  String? symbol,
});

/// Every constant this page publishes for a prototype number, by name.
///
/// The single place the two are joined, so a claim can name a symbol and the
/// assertion can read it without a second table drifting in step.
const Map<String, double> _loginConstants = <String, double>{
  'kRootGutter': LoginPage.kRootGutter,
  'kTopSpacer': LoginPage.kTopSpacer,
  'kBrandGap': LoginPage.kBrandGap,
  'kBrandBottomGap': LoginPage.kBrandBottomGap,
  'kWordmarkLineHeight': LoginPage.kWordmarkLineHeight,
  'kTaglineTopGap': LoginPage.kTaglineTopGap,
  'kFormGap': LoginPage.kFormGap,
  'kBottomSpacer': LoginPage.kBottomSpacer,
  'kFormRadius': LoginPage.kFormRadius,
  // Moved here from `login_page_test.dart`, which held eleven
  // `expect(LoginPage.kX, 24)` assertions — a second, prototype-unlinked copy of
  // these numbers. This constant was the one the old copy was the *only* cover of,
  // so deleting that suite without adding this row would have lost it.
  'kSignUpRowGap': LoginPage.kSignUpRowGap,
};

/// The social-button numbers, which live on a feature widget rather than on the
/// page.
///
/// One entry, not two. `kSocialButtonGap` was here and in the prototype table, and
/// `SocialAuthButton` **never read it**: the prototype's `gap: 10` separated the
/// brand mark from the label, the mark is not reproduced (that widget's own doc
/// says why), and the doc claimed the 10 was "also the inset that keeps a long
/// Arabic label off the rim" when the inset is `EvaSpacing.lg`. So the symbol map
/// was certifying `10` for a constant nothing consulted. It is deleted; its table
/// row is deleted with it.
const Map<String, double> _socialConstants = <String, double>{
  'socialButtonHeight': SocialAuthButton.kSocialButtonHeight,
};

/// The values this page claims to have transcribed, with the prototype line each
/// one comes from.
///
/// Each entry is `(label, prototype line, the value on that line, the symbol this
/// page publishes it as — or null)`. The line numbers are checked against the
/// prototype file itself, and the values are checked against **this page's
/// constants**.
///
/// ## WHY THE SYMBOL COLUMN EXISTS, AND IT IS NOT REDUNDANT
///
/// The first version of this table had no symbol column and asserted only that
/// `LoginScreen.tsx:14` still said `72`. Changing `LoginPage.kTopSpacer` from 72 to
/// 71 — a transcription slip, one character — left all 37 tests **green**. The
/// prototype was right, the citation was right, and the page was wrong: which is
/// exactly decision 8's failure mode, one layer in from where it was written to
/// apply. A line map with nothing linking it to the code is documentation with a
/// test runner attached.
///
/// A `null` symbol is a real answer, not an omission — but only where the
/// *rendered* half really checks it, and this table used to say otherwise.
///
/// The first version of this paragraph read: "`ds.tsx:19`'s `60` becomes
/// `SealMonogram.defaultSize` and `:28`'s `34` is not a Material slot at all (see
/// recorded decision 5) … **Those two are checked by the rendered half of this file
/// instead.**" Only the first was true.
///
/// * `:19`'s **60** is: the rendered half asserts the painted `SealMonogram` is
///   `60 × 60` — the prototype's number, not merely "equal to whatever
///   `defaultSize` currently is".
/// * `:28`'s **34** is **not, and cannot be**. The wordmark renders at
///   `displaySmall`, which is 36sp in Material 3's `englishLike` geometry; there is
///   no 34sp slot and inventing one would be a token this project is not allowed to
///   invent (§5.2, recorded decision 5). So 34 is a prototype number with **no
///   Dart constant to compare against**, and the rendered half pins the
///   *substitution* — 36, and not `displayLarge`'s 57 — rather than pretending the
///   prototype's number is enforced.
///
/// That is the difference between a claim and a record, and it was this file's own
/// defect-8 failure mode inside the harness built to prevent it.
const List<PrototypeClaim> loginClaims = <PrototypeClaim>[
  (label: 'root padding', line: 11, expected: 24, symbol: 'kRootGutter'),
  (label: 'top spacer', line: 14, expected: 72, symbol: 'kTopSpacer'),
  (label: 'brand column gap', line: 17, expected: 14, symbol: 'kBrandGap'),
  (
    label: 'brand column marginBottom',
    line: 17,
    expected: 48,
    symbol: 'kBrandBottomGap',
  ),
  (label: 'seal width', line: 19, expected: 60, symbol: null),
  (label: 'seal height', line: 19, expected: 60, symbol: null),
  (label: 'seal border width', line: 21, expected: 1.5, symbol: null),
  (label: 'seal letter fontSize', line: 25, expected: 28, symbol: null),
  // The wordmark. `null` is right, and the paragraph above says why: 34 is not a
  // Material slot and the rendered half pins the 36 it became instead.
  (label: 'wordmark fontSize', line: 28, expected: 34, symbol: null),
  (label: 'tagline fontSize', line: 31, expected: 15, symbol: null),
  (label: 'tagline marginTop', line: 31, expected: 6, symbol: 'kTaglineTopGap'),
  (label: 'form borderRadius', line: 42, expected: 28, symbol: 'kFormRadius'),
  (label: 'form padding', line: 42, expected: 24, symbol: null),
  (label: 'form gap', line: 43, expected: 16, symbol: 'kFormGap'),
  // `LoginScreen.tsx:68` — the sign-up row's `gap: 6`. This row exists because
  // `login_page_test.dart`'s eleven-literal assertion block was deleted as a second
  // prototype-unlinked copy of these numbers, and this was the one constant only
  // that block covered. See `_loginConstants`.
  (label: 'sign-up row gap', line: 68, expected: 6, symbol: 'kSignUpRowGap'),
  // `:91-92`, not `:92-93`. The first version of this table cited 92 for the
  // height and 93 for the gap, and the harness made both of them **fail on its
  // first run** — the prototype puts `borderRadius: 14, height: 50` on line 91.
  // A wrong citation in a doc comment is exactly what decision 8 says is
  // invisible, and here it was not: that is the whole point of reading the file
  // instead of copying a number into a table.
  (
    label: 'social button height',
    line: 91,
    expected: 50,
    symbol: 'socialButtonHeight',
  ),
  (label: 'social button borderRadius', line: 91, expected: 14, symbol: null),
  // **No `social button gap` row.** `:92`'s `gap: 10` is there in the prototype and
  // it is deliberately not transcribed: it separated the brand mark from the label,
  // the mark is not reproduced, and nothing in `SocialAuthButton` reads a 10. The
  // row and the constant are gone together, because a row with no symbol certified
  // a number the screen does not use. The line map no longer mentions `:92` at all,
  // and the reason is recorded in `_socialConstants`.
  (label: 'bottom spacer', line: 99, expected: 40, symbol: 'kBottomSpacer'),
];

/// One `ds.tsx` number, the symbol that renders it, and — where the screen renders
/// a **different** number — the substituted value.
///
/// ## WHY THIS TABLE NOW HAS A SYMBOL COLUMN, AND WHY THAT IS THE FINDING
///
/// The first version of `dsClaims` had `label` / `line` / `expected` and nothing
/// else, and its doc claimed "this suite asserts those tokens against the
/// prototype" for `kEvaTextFieldHeight` and `kEvaButtonHeight`. It did not: no row
/// named a symbol, the two tests below it only compared a **prototype line's text**
/// against a **number typed into a table**, and neither `kEvaTextFieldHeight` nor
/// `kEvaButtonHeight` appeared anywhere in the file outside that sentence. The map
/// did not exist.
///
/// So the assertion was structurally incapable of noticing a Phase-3 token that
/// disagreed with `ds.tsx`, which is the exact claim it made.
///
/// Two rows were also **green while the screen rendered something else**, which is
/// worse than not asserting:
///
/// | `ds.tsx` | prototype | rendered | symbol |
/// | --- | --- | --- | --- |
/// | `Input label` `:298` | 10 | **12** | `labelMedium` |
/// | `ButtonText` `:277` | 15 | **14** | `bodyMedium` |
///
/// Both deltas follow from AGENT_CONTEXT §6's recorded decision 5 — sizes are
/// Material 3's by decision, and §5.2 specifies none — so the **code** is
/// defensible. The **record** was not: a table that looked like a transcription
/// check and was not one. So each row now names the symbol that renders it, and a
/// row whose rendered value differs carries that value in [rendered] and is
/// asserted as a recorded substitution rather than as a transcription.
typedef DsClaim = ({
  String label,
  int line,
  double expected,
  String? symbol,
  double? rendered,
});

/// The shared components' own geometry, from `ds.tsx`.
///
/// Read separately from the screen's numbers because they are **not** the same
/// facts: `Input`'s 52 is a component property that Phase 3 already transcribed into
/// [kEvaTextFieldHeight], and `ButtonPrimary`'s 52 into [kEvaButtonHeight].
///
/// [rendered] is non-null exactly where the screen renders a **substituted** value,
/// and the two groups of tests below treat those rows differently on purpose: a row
/// with a null [rendered] is a transcription claim, and a row with one is a
/// recorded divergence whose arithmetic is named in the failure message.
const List<DsClaim> dsClaims = <DsClaim>[
  (
    label: 'Input height',
    line: 306,
    expected: 52,
    symbol: 'kEvaTextFieldHeight',
    rendered: null,
  ),
  (
    label: 'Input borderRadius',
    line: 306,
    expected: 14,
    symbol: 'EvaRadii.input',
    rendered: null,
  ),
  (
    label: 'Input left padding',
    line: 309,
    expected: 16,
    symbol: 'EvaSpacing.lg',
    rendered: null,
  ),
  // The 44 is not a scale step and has no token — see
  // `kEvaTextFieldPadding`'s own doc, and the rendered half of this file, which
  // asserts it there. So no symbol, and no [rendered] substitution.
  (
    label: 'Input right padding',
    line: 309,
    expected: 44,
    symbol: null,
    rendered: null,
  ),
  (
    label: 'Input error fontSize',
    line: 320,
    expected: 12,
    symbol: 'bodySmall',
    rendered: null,
  ),
  (
    label: 'ButtonPrimary borderRadius',
    line: 240,
    expected: 14,
    symbol: 'EvaRadii.button',
    rendered: null,
  ),
  (
    label: 'ButtonPrimary height',
    line: 240,
    expected: 52,
    symbol: 'kEvaButtonHeight',
    rendered: null,
  ),
  (
    label: 'ButtonPrimary fontSize',
    line: 237,
    expected: 16,
    symbol: 'titleMedium',
    rendered: null,
  ),
  // `TextLink`'s label is `labelLarge`, which is 14sp; the prototype writes 15.
  // Recorded decision 5, and the substitution is *towards* the prototype.
  (
    label: 'ButtonText fontSize',
    line: 277,
    expected: 15,
    symbol: 'bodyMedium',
    rendered: 14,
  ),
  // The prototype's chevron is `fontSize: 16`; `TextLink` draws
  // `Icons.chevron_right` at `EvaSpacing.lg`, which is 16. A glyph size read as an
  // icon size, and it happens to be the same number.
  (
    label: 'ButtonText chevron fontSize',
    line: 283,
    expected: 16,
    symbol: 'EvaSpacing.lg',
    rendered: null,
  ),
  // `ds.tsx:298` writes `F.mono, 10, 700`. `EvaTypography.monoCaps` is
  // `labelMedium`'s geometry with the mono family, and `labelMedium` is 12sp.
  // Recorded decision 5: §5.2 gives `mono` neither a slot nor a size.
  (
    label: 'Input label fontSize',
    line: 298,
    expected: 10,
    symbol: 'labelMedium',
    rendered: 12,
  ),
  (
    label: 'Input stack gap',
    line: 296,
    expected: 6,
    symbol: 'kEvaTextFieldStackGap',
    rendered: null,
  ),
];

/// Resolves a [DsClaim]'s symbol to the size the app actually renders.
///
/// A `switch` over the symbols rather than a `const` map, because five of the eleven
/// are **theme slots** — `bodySmall`, `titleMedium`, `bodyMedium`, `labelMedium` —
/// and a `const` map cannot hold `textTheme.bodySmall!.fontSize`. The `_` arm throws
/// rather than returning a default, so a symbol added to a row and not to this
/// function is a **compile-clean runtime failure**, not a silently-skipped row.
double _dsSymbol(String symbol, TextTheme textTheme) => switch (symbol) {
  'kEvaTextFieldHeight' => kEvaTextFieldHeight,
  'EvaRadii.input' => EvaRadii.input,
  'EvaSpacing.lg' => EvaSpacing.lg,
  'kEvaTextFieldStackGap' => kEvaTextFieldStackGap,
  'EvaRadii.button' => EvaRadii.button,
  'kEvaButtonHeight' => kEvaButtonHeight,
  'bodySmall' => textTheme.bodySmall!.fontSize!,
  'titleMedium' => textTheme.titleMedium!.fontSize!,
  'bodyMedium' => textTheme.bodyMedium!.fontSize!,
  'labelMedium' => textTheme.labelMedium!.fontSize!,
  _ => throw ArgumentError.value(symbol, 'symbol', 'no rendered size is known'),
};

void main() {
  group('the line map — every claim points at a real prototype line', () {
    // The mechanical half of decision 8's harness, and the part that would have
    // caught a renumbered citation. `LoginPage`'s doc comment quotes these line
    // numbers to a reader; this asserts each one is still the line it claims to be.
    for (final PrototypeClaim claim in loginClaims) {
      test('LoginScreen.tsx:${claim.line} — ${claim.label}', () {
        final File source = File(loginScreen);
        final List<String> lines = source.readAsLinesSync();

        expect(
          claim.line,
          lessThanOrEqualTo(lines.length),
          reason: 'the line does not exist any more',
        );

        final String text = lines[claim.line - 1];

        expect(
          text,
          matches(_numberIn(claim.expected)),
          reason:
              'LoginScreen.tsx:${claim.line} no longer declares '
              '${claim.label} = ${claim.expected}. Either the prototype moved the '
              'number or this claim was wrong; both need the citation updated: '
              '"$text"',
        );
      });
    }

    for (final DsClaim claim in dsClaims) {
      test('ds.tsx:${claim.line} — ${claim.label}', () {
        final List<String> lines = File(dsComponents).readAsLinesSync();

        expect(
          claim.line,
          lessThanOrEqualTo(lines.length),
          reason: 'the line does not exist any more',
        );

        expect(
          lines[claim.line - 1],
          matches(_numberIn(claim.expected)),
          reason:
              'ds.tsx:${claim.line} no longer declares ${claim.label} = '
              '${claim.expected}. Update the citation and the widget together: '
              '"${lines[claim.line - 1]}"',
        );
      });
    }
  });

  group('the shared components, checked against `ds.tsx`', () {
    // ## WHAT THIS GROUP IS THAT THE LINE MAP IS NOT
    //
    // The line map above compares `ds.tsx`'s **text** against a number typed into a
    // table. It cannot see a Phase-3 token that disagrees with `ds.tsx`, because no
    // Dart symbol appears in the comparison at all — which is exactly what the
    // `dsClaims` doc used to claim it did, for `kEvaTextFieldHeight` and
    // `kEvaButtonHeight`, neither of which appeared in this file outside that
    // sentence.
    //
    // Two groups rather than one, because a row is either a **transcription claim**
    // or a **recorded divergence** and asserting both the same way would launder the
    // second into the first:
    final TextTheme textTheme = EvaTypography.textTheme(const EvaColors.dark());

    for (final DsClaim claim in dsClaims) {
      final String? symbol = claim.symbol;
      if (symbol == null) {
        continue;
      }
      final double? rendered = claim.rendered;

      if (rendered == null) {
        test('${claim.label} is ${claim.expected}', () {
          final double resolved = _dsSymbol(symbol, textTheme);
          expect(
            resolved,
            claim.expected,
            reason:
                'ds.tsx:${claim.line} declares ${claim.label} = '
                '${claim.expected}, and $symbol renders $resolved',
          );
        });
      } else {
        test('${claim.label} is the recorded substitution, ${claim.expected} -> '
            '$rendered', () {
          final double resolved = _dsSymbol(symbol, textTheme);
          final double delta = rendered - claim.expected;
          expect(
            resolved,
            rendered,
            reason:
                'ds.tsx:${claim.line} declares ${claim.label} = '
                '${claim.expected} and the screen renders $resolved, a delta of '
                '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}sp. Both '
                'follow AGENT_CONTEXT §6 recorded decision 5 (sizes are Material '
                "3's by decision; §5.2 specifies none) — but a decision that "
                'justifies the number does not make the gap disappear, so it is '
                'pinned rather than claimed away.',
          );
        });
      }
    }

    test('and the two substitutions are exactly the two recorded ones', () {
      // Anti-vacuity in the other direction. A table where every row had a
      // `rendered` value would be a table of divergences, and one where none did
      // would be a table of claims — and neither is what the prototype says.
      final List<String> substituted = dsClaims
          .where((DsClaim claim) => claim.rendered != null)
          .map((DsClaim claim) => claim.label)
          .toList();

      expect(
        substituted,
        <String>['ButtonText fontSize', 'Input label fontSize'],
        reason:
            'these are the only two places where the screen renders a size other '
            'than ds.tsx declares. A third would be a new decision 5 substitution '
            'and belongs in a decision, not in a tolerance',
      );
    });

    test('and every symbol in the table resolves', () {
      // A symbol added to a row but not to `_dsSymbol` throws there rather than
      // failing a named assertion, so this is the assertion that says so.
      for (final DsClaim claim in dsClaims) {
        final String? symbol = claim.symbol;
        if (symbol == null) {
          continue;
        }
        expect(
          () => _dsSymbol(symbol, textTheme),
          returnsNormally,
          reason: '$symbol (for ${claim.label}) has no resolved size',
        );
      }
      expect(_dsSymbol('kEvaTextFieldHeight', textTheme), 52);
      expect(_dsSymbol('kEvaButtonHeight', textTheme), 52);
    });
  });

  group("the page publishes the prototype's numbers, not its own", () {
    // The half that was missing, and the half that matters. See the table's doc.
    for (final PrototypeClaim claim in loginClaims) {
      final String? symbol = claim.symbol;
      if (symbol == null) {
        continue;
      }
      test('LoginPage.${claim.label} is ${claim.expected}', () {
        final double published =
            _loginConstants[symbol] ?? _socialConstants[symbol]!;
        expect(
          published,
          claim.expected,
          reason:
              'LoginScreen.tsx:${claim.line} declares ${claim.label} = '
              '${claim.expected}, and this page publishes $symbol as $published',
        );
      });
    }

    test(
      'and the form padding, which is an EdgeInsets rather than a double',
      () {
        // It does not fit the table's `double` column, and it is the number a reader
        // would otherwise have to take on trust.
        expect(LoginPage.kFormPadding, const EdgeInsets.all(24));
      },
    );

    test('every symbol the table names resolves to a real constant', () {
      // Anti-vacuity in the other direction. A `symbol` that did not resolve would
      // throw inside the lookup above rather than fail a named assertion, and a
      // table that quietly shrank would leave the rest of the file green.
      //
      // **One social symbol, not two** — `kSocialButtonGap` was deleted, and the
      // count is the assertion that says so. Ten login symbols: nine from the first
      // table plus `kSignUpRowGap`, which arrived here from
      // `login_page_test.dart`.
      expect(_loginConstants.length, greaterThanOrEqualTo(10));
      expect(_socialConstants, hasLength(1));
      expect(_loginConstants.keys, contains('kSignUpRowGap'));
      expect(
        _socialConstants.keys,
        isNot(contains('socialButtonGap')),
        reason:
            'the prototype\'s `gap: 10` separated the brand mark from the label, '
            'the mark is not reproduced, and `SocialAuthButton` read neither the '
            'constant nor the 10 — so a row and a symbol here would certify a '
            'number the screen does not use',
      );
      expect(
        loginClaims
            .map((PrototypeClaim claim) => claim.symbol)
            .whereType<String>()
            .toSet()
            .difference(<String>{
              ..._loginConstants.keys,
              ..._socialConstants.keys,
            }),
        isEmpty,
      );
      expect(
        loginClaims
            .where((PrototypeClaim claim) => claim.symbol != null)
            .length,
        greaterThanOrEqualTo(10),
        reason:
            'most of the table is checked against a constant, not just a line',
      );
    });
  });

  group('the extraction is not vacuous', () {
    // The anti-vacuity half. A parser that matched nothing would make every line
    // above pass on an empty read — the failure mode AGENT_CONTEXT §7 documents and
    // the one `glass_blur_budget_test.dart` guards against.
    test('the screen declares far more numbers than this page claims', () {
      final Map<String, PrototypeValue> declared = declaredValues(loginScreen);

      expect(
        declared.length,
        greaterThan(loginClaims.length),
        reason:
            'the parser found ${declared.length} numbers and the claims list '
            '${loginClaims.length}. A parser that reads almost nothing would let '
            'every line-map test pass on an empty extraction.',
      );
    });

    test('the screen really does declare `minHeight: 844` — the defect we removed', () {
      // Defect #9 is asserted **present in the prototype** and absent from the
      // widget, because "this phase did not add a fixed height" is only meaningful
      // against a prototype that has one.
      expect(
        declaredValues(loginScreen).values
            .where((PrototypeValue value) => value.value == 844),
        isNotEmpty,
      );
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

    testWidgets('the form is 28-radius, 24-padded and 16-gapped', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // `LoginScreen.tsx:42-43`.
      final GlassSurface form = tester.widget<GlassSurface>(
        find.byType(GlassSurface),
      );
      expect(form.radius, LoginPage.kFormRadius);
      expect(form.radius, 28);
      expect(form.padding, const EdgeInsets.all(24));
      expect(form.tier, GlassTier.tint);

      // The **gap**, measured. The claim is arithmetic, and arithmetic is the only
      // thing worth asserting: field, then `kFormGap`, then the next field.
      //
      // The first version of this was
      //
      // ```dart
      // expect(passwordTop - emailTop, greaterThan(0));
      // ```
      //
      // under a comment claiming "Reading the rendered tops proves the column is
      // actually spaced". It does not: inserting a `SizedBox(height: 1)` or
      // replacing one `SizedBox(height: LoginPage.kFormGap)` with
      // `SizedBox(height: 40)` left the whole suite green, because
      // `greaterThan(0)` only says the two fields are not on the same line. The
      // measured truth is `emailTop=284.0, emailHeight=74.0, passwordTop=374.0`,
      // so the delta is `74 + 16` — the field's own height plus the gap.
      //
      // Two extras that the old version faked, and are deleted rather than kept:
      //
      // ```dart
      // final List<double> tops = tester
      //     .widgetList<EvaTextField>(find.byType(EvaTextField))
      //     .map((EvaTextField _) => 0.0)     // a fabricated list of zeros
      //     .toList();
      // expect(tops, hasLength(2));
      // ```
      //
      // A list of zeros whose only assertion is its length: `hasLength(2)` was
      // carrying a claim ("the form has two fields") that it established by
      // measuring nothing. The count is asserted below, against the finder, where
      // it is a real fact.
      final Finder fields = find.byType(EvaTextField);
      expect(fields, findsNWidgets(2), reason: 'the form has two fields');

      final double emailTop = tester.getTopLeft(fields.first).dy;
      final double emailHeight = tester.getSize(fields.first).height;
      final double passwordTop = tester.getTopLeft(fields.last).dy;

      expect(
        passwordTop - emailTop,
        emailHeight + LoginPage.kFormGap,
        reason:
            'the column is email field, then $emailHeight of field plus a '
            '${LoginPage.kFormGap} gap — so any other spacing is a gap the '
            'prototype does not declare',
      );
    });

    testWidgets('the two spacers are 72 and 40 tall', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // Read straight off the tree rather than off the constants, so a page that
      // declares `kTopSpacer = 72` and renders something else is caught.
      final Iterable<double> heights = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((SizedBox box) => box.height ?? double.nan);

      expect(heights, contains(LoginPage.kTopSpacer));
      expect(heights, contains(LoginPage.kBottomSpacer));
      expect(
        tester.getSize(find.byType(SealMonogram)).width,
        // **60, the prototype's number** — not `SealMonogram.defaultSize`.
        //
        // The first version compared the rendered width to `defaultSize`, which is
        // a tautology about two things that are supposed to agree: change both to 48
        // and the assertion stays green with `LoginScreen.tsx:19` wrong. The only
        // other test in the repository that mentioned 60 was
        // `seal_monogram_test.dart`, one file away from this claim.
        //
        // `LoginScreen.tsx:19` writes `width: 60, height: 60`, so the height is
        // asserted against the same literal rather than left implied.
        60,
        reason: 'LoginScreen.tsx:19 — 60x60',
      );
      expect(
        tester.getSize(find.byType(SealMonogram)).height,
        60,
        reason: 'LoginScreen.tsx:19 — 60x60',
      );
    });

    testWidgets('the social buttons are 50 tall with a 14 radius', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      expect(
        tester.getSize(find.byType(SocialAuthButton).first).height,
        SocialAuthButton.kSocialButtonHeight,
      );
      expect(SocialAuthButton.kSocialButtonHeight, 50);

      final BoxDecoration box =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(SocialAuthButton).first,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(box.borderRadius, isA<BorderRadius>());
      expect((box.borderRadius! as BorderRadius).topLeft.x, EvaRadii.button);
      expect((box.borderRadius! as BorderRadius).topLeft.x, 14);
    });

    testWidgets('the toggle is 18 inside a 28 target, and the field is 52', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      expect(PasswordVisibilityToggle.glyphSize, 18);
      expect(PasswordVisibilityToggle.targetSize, 28);
      expect(
        tester.getSize(find.byType(PasswordVisibilityToggle)).width,
        PasswordVisibilityToggle.targetSize,
      );

      // `ds.tsx:306` — the field's own 52, which `EvaTextField` owns.
      expect(kEvaTextFieldHeight, 52);

      // The arithmetic that makes a 28-wide toggle possible where
      // `IconActionButton`'s 44 is not: the field reserves [kEvaTextFieldPadding]'s
      // right inset for the control, and the control plus `EvaTextField`'s own
      // `EvaSpacing.sm` of padding has to fit inside it or the row overflows.
      expect(
        PasswordVisibilityToggle.targetSize + EvaSpacing.sm,
        lessThanOrEqualTo(kEvaTextFieldPadding.right),
        reason:
            'a 28-wide toggle plus 8 of padding is 36, inside the 44 of reserve; '
            "IconActionButton's 44 plus 8 would be 52 and would push the field's "
            'text out of its own box',
      );

      // The prototype's own arithmetic does **not** say what
      // `kEvaTextFieldPadding`'s doc comment claims. It says "the 44 is the icon
      // inset (14) plus the icon's own 18" — and 14 + 18 is 32, not 44. Recorded
      // here as a measurement rather than a correction: the 44 is transcribed
      // faithfully from `ds.tsx:309`, only the explanation attached to it does not
      // add up, and this phase may not rewrite a Phase-3 doc comment. The number is
      // the right number; the story about where it came from is not.
      expect(kEvaTextFieldPadding.right, 44);
      expect(14 + 18, isNot(kEvaTextFieldPadding.right));
    });

    testWidgets('the wordmark is not `displayLarge` — decision 5', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: bloc, size: const Size(430, 932));

      // `displayLarge` is 57sp where the prototype's largest type is 34px, and
      // AGENT_CONTEXT §6 decision 5 says it wraps to four lines at 1.22× on a 320px
      // screen, which §14 forbids. So the wordmark uses `displaySmall`.
      final Text wordmark = tester.widget<Text>(find.text('Evangelion'));
      final BuildContext context = tester.element(find.text('Evangelion'));

      expect(
        wordmark.style?.fontFamily,
        EvaTypography.displayFamily,
        reason: 'it is still the display serif — just not the 57sp slot',
      );
      // `displaySmall`, stated rather than merely "not `displayLarge`". The old
      // assertion — `isNot(displayLarge.fontSize)` — passed for **any** second slot,
      // including one nobody chose.
      expect(
        wordmark.style?.fontSize,
        Theme.of(context).textTheme.displaySmall!.fontSize,
        reason:
            'the substitution is `displaySmall`, so that is what it renders at',
      );
      expect(
        wordmark.style?.fontSize,
        isNot(Theme.of(context).textTheme.displayLarge!.fontSize),
      );
      expect(
        Theme.of(context).textTheme.displaySmall!.fontFamily,
        EvaTypography.displayFamily,
      );
      // **The prototype's 34 is not asserted, and this is the record.** There is no
      // 34sp Material slot and §5.2 gives none, so inventing one is out of scope;
      // `displaySmall` is 36sp, a **2sp substitution**. `loginClaims` says
      // `LoginScreen.tsx:28` is 34 with a `null` symbol, and the reason is there:
      // the number is untranscribable rather than unasserted.
      expect(
        wordmark.style?.fontSize,
        36,
        reason:
            'the rendered size, recorded. `LoginScreen.tsx:28` declares 34 and the '
            'screen renders 36 — a decision 5 substitution with no constant to '
            'compare against, so it is pinned as what it is',
      );
    });
  });
}

/// `24` as the prototype writes it, `1.5` as it writes it.
///
/// The prototype writes `borderRadius: 28` and `border: 1.5px solid` — a number
/// with a unit — so a plain `'$expected'` substring would miss the second. Keeping
/// the string form next to the number keeps the two in step.
String _format(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

/// The prototype's spelling of [value] as a **whole-token** pattern.
///
/// ## WHY THIS IS A REGEX AND NOT `contains`
///
/// `contains('24')` is satisfied by `padding: '0 240px'` and by `minHeight: 8440`;
/// `contains('14')` by `width: 144`; `contains('6')` by `gap: 16`. Every one of
/// those would leave the line map green with the claim wrong, which is the same
/// shape as the *"a 4-character substring standing in for a parameter"* defect
/// this project has already paid for — and it was here, in the harness written to
/// catch transcription slips.
///
/// The anchors are `(?<![0-9.])` and `(?![0-9.])`: no digit or decimal point
/// immediately before or after. `84` therefore does not match inside `844`, and
/// `1.5` does not match inside `1.55` — while `1.5px`, `0 24px`, `'16'` and `50,`
/// all still match, which is every shape the prototype actually writes.
///
/// A dot is in the exclusion class as well as a digit so that a decimal is atomic
/// from both sides: `6` must not be found inside `1.6`.
String _numberIn(double value) {
  final String digits = _format(value);
  return '(?<![0-9.])${RegExp.escape(digits)}(?![0-9.])';
}
