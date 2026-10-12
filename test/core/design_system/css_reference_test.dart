import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/css_reference.dart';

/// What the redesigned reference must actually contain, so a harness built on top
/// of [CssReference] is built on facts rather than on the file being present.
///
/// The file is `eva/redesign.html`, committed verbatim. It is token-driven, and
/// these tests are what make that a verified property rather than an assumption:
/// a count that matches because nothing was asked is the vacuous pass this
/// repository keeps finding in its own gates.
void main() {
  final File file = File('eva/redesign.html');

  CssReference? loaded;
  setUpAll(() {
    loaded = CssReference.fromFile(file);
  });

  group('the reference is readable and non-empty', () {
    test('eva/redesign.html exists and parses', () {
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'The redesigned reference is a required input. '
            'A harness that cannot read it does not pass — a missing reference '
            'is reported, never assumed unchanged.',
      );
      expect(
        loaded,
        isNotNull,
        reason:
            'CssReference.fromFile returned null, so the file could not be '
            'read. Everything below would be vacuous.',
      );
    });

    test('and it declares a token table worth the name', () {
      // 21 custom-property declarations were measured across the file. Assert a
      // floor rather than an exact figure so a legitimate design edit does not
      // break this, while an EMPTY or near-empty table cannot pass.
      expect(
        loaded!.tokenNames().length,
        greaterThanOrEqualTo(15),
        reason:
            'A table this small means the parser found almost nothing, and '
            'every test below would pass for the wrong reason.',
      );
      expect(
        loaded!.tokenNames(),
        containsAll(<String>['void-1', 'gold', 'ink-0', 'scr', 'ui', 'ar']),
        reason:
            'These are measured present in eva/redesign.html. Their absence '
            'means the parser is wrong, not that the design changed.',
      );
    });
  });

  group('every var() in the source resolves', () {
    test('the only undefined token is the one the design sets per element', () {
      final List<String> unresolved = loaded!.unresolvedTokens();
      // `--bh` is genuinely absent from the stylesheet. Four audit spans set it
      // with an inline `style` attribute, and three rules read `var(--bh)` with no
      // fallback. It is undefined by design, not by mistake, and a resolver that
      // found a value for it would be inventing one.
      expect(
        unresolved,
        <String>['bh'],
        reason:
            'These var() references name tokens the stylesheet never '
            'declares. `--bh` is expected: it is set per element by an inline '
            'style attribute. Anything else is a broken reference or a broken '
            'parser.',
      );
    });

    test('and there were var() references to check in the first place', () {
      // 264 measured. A count floor, so "no unresolved tokens" cannot be
      // achieved by the parser having found nothing.
      int calls = 0;
      for (final String line in loaded!.lines) {
        calls += RegExp(r'var\(\s*--').allMatches(line).length;
      }
      expect(
        calls,
        greaterThanOrEqualTo(200),
        reason:
            'Only $calls var() call sites were found. eva/redesign.html has '
            'more than 200, so a parser that found almost none would make every '
            'other test in this file pass vacuously.',
      );
    });

    test('every var() either resolves, or names a per-element value', () {
      // Three rules in eva/redesign.html read `var(--bh)` with no fallback, and
      // `--bh` is set per element by an inline `style` attribute on four audit
      // spans rather than in any rule. Those three are CORRECT CSS and there is no
      // value to resolve them to.
      //
      // The contract is therefore not "everything resolves" — which would be a
      // test that forces a resolver to invent the missing three — but "everything
      // either resolves or is a token the file genuinely does not declare".
      final List<String> unresolved = <String>[];
      final List<String> resolved = <String>[];
      final RegExp call = RegExp(r'var\(\s*(--[A-Za-z0-9_-]+)\s*\)');

      for (int i = 0; i < loaded!.lines.length; i++) {
        final String? value = loaded!.resolveValue(loaded!.lines[i]);
        for (final RegExpMatch m in call.allMatches(loaded!.lines[i])) {
          final String name = m.group(1)!.substring(2);
          if (value != null && value.trim().isNotEmpty) {
            resolved.add(name);
          } else {
            unresolved.add('line ${i + 1}: $name');
          }
        }
      }
      expect(
        resolved.length,
        greaterThanOrEqualTo(250),
        reason:
            'Only ${resolved.length} var() references resolved. The file has '
            '264, so a resolver finding almost nothing would satisfy this '
            'test for the wrong reason.',
      );
      // Every unresolved one must name a token the file does not declare — which
      // is the definition of a per-element value here, not a parser failure.
      for (final String entry in unresolved) {
        final String name = entry.split(': ').last;
        expect(
          loaded!.declaration(name),
          isNull,
          reason:
              '$entry did not resolve, but $name IS declared in the file. '
              'That is a resolver failure, not a per-element value.',
        );
      }
      expect(
        unresolved.toSet(),
        <String>{'line 279: bh', 'line 299: bh', 'line 415: bh'},
        reason:
            'Only the three known per-element reads may fail to resolve. '
            'New ones mean either the design gained a per-element token or the '
            'resolver broke. Found: ${unresolved.join(', ')}',
      );
    });
  });

  group('the light palette is a scope, not a second truth', () {
    const String light = '.screen[data-mode=light]';

    test('the tokens light mode overrides were measured, and differ', () {
      // Nine measured at lines 56-58. Assert the distinction, not just presence:
      // a resolver that ignored the scope would return the :root colour for
      // every one of them and this would not catch it.
      for (final String name in <String>[
        'void-1',
        'ink-0',
        'ink-1',
        'gold',
        'ember',
        'glass-fill',
        'glass-line',
      ]) {
        final CssDeclaration? dark = loaded!.declaration(name);
        final CssDeclaration? pale = loaded!.declaration(name, scope: light);
        expect(
          pale,
          isNotNull,
          reason: '$name is measured under $light at lines 56-58.',
        );
        expect(
          pale!.selector,
          light,
          reason: '$name should resolve to the light scope when asked for it.',
        );
        expect(
          pale.value,
          isNot(dark?.value),
          reason:
              '$name overrides in light mode. If both scopes hold the same '
              'value the override is doing nothing and the scope is untested.',
        );
      }
    });

    test('a token light mode does NOT override still inherits from :root', () {
      // `--scr` is a font family declared once in :root and never overridden, so
      // a scoped lookup must fall back rather than return null. This is the half
      // of cascade that a scope-aware-but-thorough resolver gets wrong.
      final CssDeclaration? scoped = loaded!.declaration('scr', scope: light);
      expect(scoped, isNotNull);
      expect(scoped!.selector, ':root');
    });

    test('asking for a scope nothing declares still returns the base value', () {
      // Not a token, not a selector the file uses. Must not return null — that
      // would make a harness treat a typo'd scope as a broken design.
      final CssDeclaration? d = loaded!.declaration(
        'gold',
        scope: '.no-such-scope',
      );
      expect(d, isNotNull);
      expect(d!.selector, ':root');
    });
  });

  group('it refuses rather than guesses', () {
    test('an undefined token resolves to null, not to a plausible value', () {
      expect(loaded!.declaration('no-such-token'), isNull);
      expect(loaded!.resolveValue('var(--no-such-token)'), isNull);
    });

    test('a cycle is detected, not followed until the depth limit', () {
      // Followed naively this is an infinite loop. maxDepth would also stop it,
      // but stopping at a depth limit reports "too deep" rather than "this is a
      // cycle", and the caller needs to tell those apart.
      const String cyclic = '''
        :root { --a: var(--b); --b: var(--c); --c: var(--a); }
        .x { width: var(--a); }
      ''';
      final CssReference cyc = CssReference.parse(cyclic);
      expect(cyc.declaration('a'), isNotNull, reason: 'it parsed the token');
      expect(
        cyc.resolveValue('var(--a)'),
        isNull,
        reason: 'a cycle must resolve to null, not to a value or a hang',
      );
    });

    test('var() with a fallback resolves even when the token is undefined', () {
      // Legal CSS, and legal here: `var(--x, 12px)` means 12px when --x is absent.
      const String src =
          ':root { --w: 8px; }\n'
          '.x { width: var(--nope, 12px); }';
      final CssReference c = CssReference.parse(src);
      expect(c.resolveValue('var(--nope, 12px)'), contains('12px'));
    });

    test('a chained token resolves through to its literal', () {
      const String src =
          ':root { --a: 4px; --b: var(--a); }\n'
          '.x { width: var(--b); }';
      final CssReference c = CssReference.parse(src);
      expect(c.resolveValue('var(--b)'), '4px');
    });

    test(
      'a line that declares nothing returns null rather than a neighbour',
      () {
        const String src =
            ':root { --a: 4px; }\n'
            '.x { padding: 8px; margin: 0; }';
        final CssReference c = CssReference.parse(src);
        expect(c.numericAt(2, 'padding'), 8.0);
        expect(
          c.numericAt(2, 'width'),
          isNull,
          reason:
              'There is no width on that line. Returning the padding, or null-'
              'coerced-to-zero, would both turn a wrong citation into a pass.',
        );
        expect(c.numericAt(999, 'padding'), isNull, reason: 'past the end');
        expect(c.numericAt(0, 'padding'), isNull, reason: 'lines are 1-based');
      },
    );

    test('and a var() on the cited line resolves to its number', () {
      const String src =
          ':root { --gap: 14px; }\n'
          '.x { padding: var(--gap); }';
      final CssReference c = CssReference.parse(src);
      expect(c.numericAt(2, 'padding'), 14.0);
    });
  });
}
