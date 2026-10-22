import 'dart:io';

import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_light.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_typography.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **No `EvaTypography.textTheme(` call site outside a reviewed allowlist, and
/// the theme's own copy is provably the same style.**
///
/// ## WHAT THIS GATE IS FOR
///
/// `EvaTypography.textTheme(colors)` rebuilds a whole [TextTheme] — **thirty**
/// [TextStyle] allocations per call: fifteen from `TextTheme.apply` and
/// fifteen from the `copyWith` that assigns the families
/// (`lib/core/design_system/tokens/eva_typography.dart:138-167`). And the
/// theme **already builds the identical theme once** and installs it in the
/// [ThemeData] (`lib/core/design_system/theme/eva_theme.dart:59` builds it,
/// `:85` installs it).
///
/// So every call site outside the theme is doing work the theme has already
/// done — and the work is not free: a `TextTheme` is fifteen slots, so a call
/// is thirty `TextStyle`s for a value the tree already holds.
///
/// ## THE GATE HAS TWO HALVES, AND THEY SHARE ONE DEFINITION
///
/// **Half 1 — the count.** A source scan over `lib/` that finds every
/// `textTheme(` call site. A **new** site is red; a **stale** allowlist row is
/// red; a scan that finds **nothing** is red, because that means the matcher
/// rotted rather than the tree becoming clean.
///
/// **Half 2 — the equality proof.** The reason de-duplicating those call sites
/// would be *safe* is that `Theme.of(context).textTheme.<slot>` equals
/// `EvaTypography.textTheme(colors).<slot>`. **That has never been proven**, and
/// it is the load-bearing half: if the two were not equal, de-duplicating would
/// be a **visual change**, which this repository forbids.
///
/// **THE ANSWER IS MEASURED, NOT ASSUMED, AND IT IS RECORDED BELOW.** The
/// measurement is a field-by-field diff of every slot, for **dark × light** and
/// **en × ar**, taken two ways: from a pumped widget tree and from the
/// [ThemeData] the app installs. The measured answer is that **all fifteen
/// slots are equal in all six comparisons**, and the diff is empty.
///
/// ## WHY THEY ARE EQUAL — THE MECHANISM, SO THE NEXT LANE CAN TRUST IT
///
/// The trap this gate exists to catch is real: `ThemeData` layers the
/// **locale's** typography geometry over the theme's own text theme
/// (`ThemeData.localize`, `theme_data.dart:1743-1766`), and Material's Arabic
/// geometry is the `tall` script category (`flutter_localizations`'s
/// `material_ar.arb` sets `scriptCategory: tall`) while Eva's is
/// `englishLike` (`typography.dart:2096-2112` vs `:2132-2148`). So the *naive*
/// expectation is that an Arabic reader gets different line heights from an
/// English one.
///
/// **There are TWO independent reasons they do not, and both are measured
/// rather than assumed.**
///
/// **THE FIRST IS `inherit: false`.** Every style in
/// `Typography.material2021()`'s `englishLike` carries `inherit: false`
/// (`typography.dart:2097-2111`). Eva's styles are derived from it by
/// `TextTheme.apply` → `TextStyle.apply`, and `TextStyle.apply` passes
/// `inherit: inherit` through unchanged (`text_style.dart:1013-1014`). And
/// `TextStyle.merge` **returns the other style untouched** when the other
/// style's `inherit` is false (`text_style.dart:1079-1081`):
///
/// ```dart
/// if (!other.inherit) { return other; }
/// ```
///
/// So the merge that `ThemeData` performs — both in its constructor
/// (`theme_data.dart:524`) and in `localize` (`theme_data.dart:1762`) — hands
/// back **Eva's own `TextStyle`**, and the locale geometry never gets a say.
/// Without the short-circuit the merge would be a field-by-field build, and
/// the result would carry `decoration: TextDecoration.none` from the
/// colour-only theme — a difference `TextStyle.==` reports. The third test in
/// the "why" group exercises that counterfactual.
///
/// **THE SECOND IS THAT MATERIAL 3's ARABIC GEOMETRY IS THE ENGLISH ONE.**
/// `tall` is identical to `englishLike` in every field `TextStyle.==` compares
/// (`typography.dart:2132-2148` against `:2096-2112`); only `dense`, the CJK
/// category, differs, and only in `textBaseline`. So even without the
/// short-circuit, **the sizes and the line heights would not have moved for
/// an Arabic reader**. The fourth test in that group measures it.
///
/// Together they mean the Arabic arm and the English arm render the same
/// lines, which is what the app's own bilingual typography decision
/// (AGENT_CONTEXT §6, "bilingual typography") wants: a reader who switches
/// arms mid-verse must not see the line height jump.
///
/// **AND THE MECHANISM IS NOT THE CLAIM.** The claim is the measurement; the
/// mechanism is why the measurement was worth making. The test computes the
/// diff at run time and asserts it is empty, so a future change to
/// `eva_typography.dart` that broke the equality would turn this file red
/// rather than quietly changing what the app renders.
void main() {
  group('the `textTheme` call-site budget', () {
    test('no file outside the allowlist rebuilds a `TextTheme`', () {
      final Map<String, List<_Site>> found = _foundByFile('lib');

      // **THE GATE THAT CAN FAIL.** A scan that finds nothing is a scan whose
      // matcher has rotted — a call moved into a helper, a call written
      // `EvaTypography .textTheme (` with a space, a call renamed — and a scan
      // that reports a clean run over a surface it no longer examines is
      // **the ADR-0020 shape**. So **zero is a failure**, not a pass.
      expect(
        found.values.fold<int>(0, (int sum, List<_Site> v) => sum + v.length),
        greaterThan(0),
        reason:
            'the scan found NO `textTheme` call site at all, which means the '
            'matcher stopped matching rather than the tree becoming clean. A '
            'gate that reports a pass over a surface it no longer examines is '
            'worse than no gate.',
      );

      final List<String> unexpected = <String>[
        for (final MapEntry<String, List<_Site>> entry in found.entries)
          if (!_allowlist.containsKey(entry.key))
            '${entry.key}: ${_describe(entry.value)}',
      ];
      expect(
        unexpected,
        isEmpty,
        reason:
            'a `textTheme` call site outside the allowlist. The theme already '
            'builds the identical theme once '
            '(`lib/core/design_system/theme/eva_theme.dart:59`) and installs '
            'it in the `ThemeData` (`:85`), so every site outside the theme '
            'rebuilds about thirty `TextStyle`s for a value the tree already '
            'holds. A new site has to be **reviewed**, not merely written — '
            'and the review is the equality proof in the second group, which '
            'is what makes replacing the call with `Theme.of(context).textTheme` '
            'safe rather than a visual change. Unreviewed sites:\n'
            '${unexpected.join('\n')}',
      );
    });

    test('and every allowlist row still matches a site', () {
      // **A STALE ROW IS A FAILURE, and not a note.** The allowlist is a record
      // of what was reviewed; a row whose site has gone is a row that still
      // permits a `textTheme` nobody has looked at, and the day the site comes
      // back it comes back unexamined.
      final Map<String, List<_Site>> found = _foundByFile('lib');
      final List<String> stale = <String>[];
      for (final MapEntry<String, List<String>> row in _allowlist.entries) {
        final List<_Site> site = found[row.key] ?? const <_Site>[];
        if (_sameMultiset(row.value, site)) continue;
        stale.add(
          '${row.key} — allowed: ${row.value.join(' | ')} · found: '
          '${_describe(site)}',
        );
      }
      expect(
        stale,
        isEmpty,
        reason:
            'an allowlist row no longer matches the tree. Either the site was '
            'removed — in which case **delete the row** — or it was changed, in '
            'which case the change has to be **re-reviewed** and the row '
            'rewritten. A stale row is an amnesty nobody re-read:\n'
            '${stale.join('\n')}',
      );
    });

    test('and the allowlist is not empty, because a rule that allows nothing '
        'is not a rule', () {
      expect(
        _allowlist,
        isNotEmpty,
        reason:
            'the allowlist is empty, which would mean the gate forbids every '
            '`textTheme` call in the tree — and there are legitimate ones, '
            'because the theme itself is built by one.',
      );
      expect(
        _allowlist.values.fold<int>(0, (int s, List<String> v) => s + v.length),
        16,
        reason:
            'sixteen sites are reviewed and allowed: the theme\'s own build '
            'site, the three derivations inside the type system, and twelve in '
            'the features. If this number moved, the allowlist above and the '
            'tree have drifted apart, and one of them is wrong.',
      );
      expect(
        _allowlist.length,
        11,
        reason:
            'eleven files carry a reviewed site. A new file with a new site is '
            'red twice over — once for the unlisted file, once for the count.',
      );
    });
  });

  group('the scan is negative-controlled', () {
    test('it DOES find a planted call site, and does NOT find a comment or a '
        'declaration', () {
      final Directory root = _scratchDirectory();
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      // **A real site.** The same shape as the ones in `lib/`.
      File('${root.path}/planted_site.dart').writeAsStringSync('''
// Planted by this test: a real call site.
class PlantedSite {
  void build() {
    final TextTheme theme = EvaTypography.textTheme(colors);
  }
}
''');

      // **A comment.** The repository mentions `textTheme` in prose, and a doc
      // comment must never count as a site.
      File('${root.path}/planted_comment.dart').writeAsStringSync('''
// Planted by this test: a comment, not a call site.
///
/// A doc comment that says `EvaTypography.textTheme(colors)` must not be a
/// site, and a block comment /* EvaTypography.textTheme(colors) */ must not be
/// a site either.
class PlantedComment {
  const PlantedComment();
}
''');

      // **The declaration.** `EvaTypography`'s own `static TextTheme
      // textTheme(EvaColors colors)` is a *definition*, not a call, and a
      // scanner that counted it would report a site in the one file that
      // defines the thing being scanned for.
      File('${root.path}/planted_declaration.dart').writeAsStringSync('''
// Planted by this test: the declaration, not a call.
abstract final class PlantedType {
  static TextTheme textTheme(EvaColors colors) {
    return const TextTheme();
  }
}
''');

      // **A declaration that ALSO calls, on one line.** The shape that
      // excludes the whole line would lose: the declaration is not a call, but
      // the call beside it is.
      File('${root.path}/planted_declaration_with_a_call.dart')
          .writeAsStringSync('''
// Planted by this test: a declaration that also calls.
abstract final class PlantedBoth {
  static TextTheme textTheme(EvaColors colors) =>
      EvaTypography.textTheme(colors);
}
''');

      final Map<String, List<_Site>> found = _foundByFile(root.path);

      final List<String> foundKeys = found.keys.toList();
      expect(
        foundKeys.where((String key) => key.endsWith('planted_site.dart')),
        hasLength(1),
        reason:
            'the planted call site was NOT found, so the matcher has rotted and '
            'every assertion in this file is currently vacuous. The scan '
            'returned: ${foundKeys.join(', ')}',
      );
      expect(
        foundKeys.where((String key) => key.endsWith('planted_comment.dart')),
        isEmpty,
        reason:
            'a call site inside a comment was counted. A comment is prose and '
            'prose is not a call.',
      );
      expect(
        foundKeys.where(
          (String key) => key.endsWith('planted_declaration.dart'),
        ),
        isEmpty,
        reason:
            'the declaration of `textTheme` was counted as a call site. A '
            'definition is not a call.',
      );
      expect(
        foundKeys.where(
          (String key) => key.endsWith('planted_declaration_with_a_call.dart'),
        ),
        hasLength(1),
        reason:
            'a line carrying BOTH a declaration and a call was not reported. '
            'The declaration is judged per match, so the call beside it must '
            'still count — otherwise excluding the declaration would open a '
            'hole in the scan.',
      );
    });
  });

  group('the equality proof — the theme the app installs', () {
    for (final _BrightnessLocale combination in _combinations) {
      testWidgets(
        'the pumped tree and `EvaTypography` agree, in ${combination.label}',
        (WidgetTester tester) async {
          final _Installed installed = await _installedTextTheme(
            tester,
            brightness: combination.brightness,
            locale: combination.locale,
          );

          // **ANTI-VACUITY: THE ARM IS THE ARM IT CLAIMS TO BE.** If the
          // Arabic localisations had failed to load, `Theme.of` would have
          // fallen back to `ScriptCategory.englishLike` and the "ar" row would
          // have been the "en" row wearing a different label. The category is
          // read out of the tree, not assumed.
          expect(
            installed.scriptCategory,
            combination.expectedScriptCategory,
            reason:
                'the ${combination.label} arm did not resolve to the script '
                'category it claims. The Arabic row of this proof would be the '
                'English row under another name, and the proof would be '
                'vacuous.',
          );

          _expectSameStyles(
            installed: installed.textTheme,
            expected: EvaTypography.textTheme(combination.colors),
            where: 'Theme.of(context).textTheme in ${combination.label}',
          );
        },
      );
    }

    for (final _Palette palette in _palettes) {
      test('the installed `ThemeData` and `EvaTypography` agree, in '
          '${palette.label}', () {
        final TextTheme installed = palette.theme.textTheme;
        _expectSameStyles(
          installed: installed,
          expected: EvaTypography.textTheme(palette.colors),
          where: 'the installed ThemeData.textTheme in ${palette.label}',
        );
      });
    }
  });

  group('and the reason it holds is `inherit: false`', () {
    test('Eva\'s own styles do not inherit, so Material\'s merge returns them '
        'untouched', () {
      final TextStyle eva = EvaTypography.textTheme(const EvaColors.dark())
          .bodyLarge!;

      expect(
        eva.inherit,
        isFalse,
        reason:
            '`EvaTypography`\'s styles are derived from '
            '`Typography.material2021().englishLike`, whose styles carry '
            '`inherit: false` (`typography.dart:2097-2111`), and `TextStyle.'
            'apply` passes `inherit` through unchanged (`text_style.dart:'
            '1013-1014`). If this ever reads `true`, the merge below stops '
            'short-circuiting and the equality this file proves stops holding.',
      );

      // **THE MECHANISM, EXERCISED.** `ThemeData`'s constructor merges the
      // colour-only theme under Eva's (`theme_data.dart:524`), and
      // `ThemeData.localize` merges the locale's geometry under it again
      // (`theme_data.dart:1762`). `TextStyle.merge` returns the other style
      // **untouched** when the other style's `inherit` is false
      // (`text_style.dart:1079-1081`).
      final TextStyle colourOnly = Typography.material2021().white.bodyLarge!;
      final TextStyle merged = colourOnly.merge(eva);
      expect(
        merged,
        eva,
        reason:
            'merging the colour-only theme under Eva\'s style changed it, so '
            'the short-circuit is not happening and the equality this file '
            'proves is an accident rather than a property.',
      );
      expect(
        merged.debugLabel,
        eva.debugLabel,
        reason:
            'the merged style carries a different debug label, so it is a '
            'different object built field by field rather than Eva\'s own '
            'style handed back.',
      );
    });

    test('and the counterfactual: an inheriting style would NOT survive the '
        'merge', () {
      final TextStyle eva = EvaTypography.textTheme(const EvaColors.dark())
          .bodyLarge!;
      final TextStyle colourOnly = Typography.material2021().white.bodyLarge!;

      // **THE COUNTERFACTUAL IS THE POINT.** If Eva's styles inherited, the
      // merge would be a field-by-field build and the result would carry
      // `decoration: TextDecoration.none` from the colour-only theme — which
      // `TextStyle.==` reports as a difference. So `inherit: false` is
      // load-bearing, and this is the half of the proof that says so.
      final TextStyle inheriting = eva.copyWith(inherit: true);
      final TextStyle mergedIfInheriting = colourOnly.merge(inheriting);
      expect(
        mergedIfInheriting,
        isNot(eva),
        reason:
            'an inheriting style survived the merge unchanged, which would '
            'mean `inherit: false` is not what makes the equality hold.',
      );
      expect(
        mergedIfInheriting.decoration,
        TextDecoration.none,
        reason:
            'the counterfactual is expected to pick up `decoration: none` '
            'from the colour-only theme — the field that makes the merged '
            'style differ from Eva\'s own.',
      );
    });

    test('and Material 3\'s Arabic geometry is the English geometry anyway', () {
      // **A SECOND, INDEPENDENT REASON, MEASURED RATHER THAN ASSUMED.**
      // Material 3's `tall` script category — the one Arabic resolves to — is
      // identical to `englishLike` in every field `TextStyle.==` compares
      // (`typography.dart:2132-2148` against `:2096-2112`); only `dense`, the
      // CJK category, differs, and only in `textBaseline`. (`debugLabel` does
      // differ, and `TextStyle.==` does not compare it — it does not render.)
      // So even without the `inherit: false` short-circuit, **the sizes and
      // the line heights would not have moved for an Arabic reader.**
      final Typography typography = Typography.material2021();
      for (final MapEntry<String, TextStyle?> slot in _slotsOf(
        typography.englishLike,
      ).entries) {
        final TextStyle? tall = _slotsOf(typography.tall)[slot.key];
        expect(
          tall,
          slot.value,
          reason:
              'Material 3\'s `tall` geometry differs from `englishLike` in '
              '${slot.key}, so the Arabic arm carries its own line heights and '
              'the "the geometry is the same" claim no longer holds',
        );
      }
    });
  });
}

/// One call site: the line it is on, and the normalised text of the line.
///
/// **The line is for the MESSAGE, and the text is for the KEY.** The key is
/// the file plus the multiset of these statements, because a `file:line` key
/// is brittle in the worst way — any edit above a site moves it, and the gate
/// would cry wolf on a change that changed nothing. The line is carried
/// alongside so a failure can still say *where* to look.
class _Site {
  const _Site({required this.line, required this.statement});

  /// The one-based line the site is on, in the comment-stripped source.
  final int line;

  /// The line with its whitespace collapsed.
  final String statement;

  @override
  String toString() => '$line: $statement';
}

/// The `TextStyle` slots of a [TextTheme], by name.
///
/// **The fifteen slots Material 3 defines**, read off a [TextTheme] rather than
/// listed twice, so the two sides of every comparison are enumerated by the
/// same code and cannot drift apart.
Map<String, TextStyle?> _slotsOf(TextTheme theme) => <String, TextStyle?>{
  'displayLarge': theme.displayLarge,
  'displayMedium': theme.displayMedium,
  'displaySmall': theme.displaySmall,
  'headlineLarge': theme.headlineLarge,
  'headlineMedium': theme.headlineMedium,
  'headlineSmall': theme.headlineSmall,
  'titleLarge': theme.titleLarge,
  'titleMedium': theme.titleMedium,
  'titleSmall': theme.titleSmall,
  'bodyLarge': theme.bodyLarge,
  'bodyMedium': theme.bodyMedium,
  'bodySmall': theme.bodySmall,
  'labelLarge': theme.labelLarge,
  'labelMedium': theme.labelMedium,
  'labelSmall': theme.labelSmall,
};

/// The fields of two [TextStyle]s that differ, by name.
///
/// **EVERY field, not the nine the brief names**, because a difference in one
/// field is a **visual** difference and the whole constraint this file exists
/// to protect rides on the answer being complete. `TextStyle.==` is not enough
/// on its own: it compares neither `textHeightBehavior` nor `debugLabel`
/// (`text_style.dart:1486-1518`).
///
/// **`leadingDistribution` is the public face of `textHeightBehavior`.** The
/// painting-level [TextStyle] does not expose `textHeightBehavior` at all in
/// Flutter 3.47 — it derives the `dart:ui` one from `leadingDistribution` in
/// its constructor (`text_style.dart:1405-1409`) — so a difference in
/// `leadingDistribution` *is* a difference in `textHeightBehavior`, and
/// `leadingDistribution` is the field this diff reads.
List<String> _differingFields(TextStyle? left, TextStyle? right) {
  if (left == null || right == null) {
    return <String>['nullness(left: $left, right: $right)'];
  }
  final List<String> differences = <String>[];
  void field(String name, Object? a, Object? b) {
    if (a != b) differences.add(name);
  }

  field('inherit', left.inherit, right.inherit);
  field('color', left.color, right.color);
  field('backgroundColor', left.backgroundColor, right.backgroundColor);
  field('foreground', left.foreground, right.foreground);
  field('background', left.background, right.background);
  field('fontSize', left.fontSize, right.fontSize);
  field('fontWeight', left.fontWeight, right.fontWeight);
  field('fontStyle', left.fontStyle, right.fontStyle);
  field('letterSpacing', left.letterSpacing, right.letterSpacing);
  field('wordSpacing', left.wordSpacing, right.wordSpacing);
  field('height', left.height, right.height);
  field(
    'leadingDistribution',
    left.leadingDistribution,
    right.leadingDistribution,
  );
  field('textBaseline', left.textBaseline, right.textBaseline);
  field('locale', left.locale, right.locale);
  field('fontFamily', left.fontFamily, right.fontFamily);
  field('decoration', left.decoration, right.decoration);
  field('decorationColor', left.decorationColor, right.decorationColor);
  field('decorationStyle', left.decorationStyle, right.decorationStyle);
  field(
    'decorationThickness',
    left.decorationThickness,
    right.decorationThickness,
  );
  field('overflow', left.overflow, right.overflow);

  if (!listEquals(left.fontFamilyFallback, right.fontFamilyFallback)) {
    differences.add('fontFamilyFallback');
  }
  if (!listEquals(left.shadows, right.shadows)) differences.add('shadows');
  if (!listEquals(left.fontFeatures, right.fontFeatures)) {
    differences.add('fontFeatures');
  }
  if (!listEquals(left.fontVariations, right.fontVariations)) {
    differences.add('fontVariations');
  }
  return differences;
}

/// Asserts that two [TextTheme]s carry the same [TextStyle] in every slot.
///
/// **The diff is computed, not asserted from a table.** A table of "these slots
/// are equal" would be a claim about code that could change under it, and the
/// failure it would report — "slot X is not in the list" — would not say *how*
/// it differs. Computing the diff says exactly which field moved.
void _expectSameStyles({
  required TextTheme installed,
  required TextTheme expected,
  required String where,
}) {
  final Map<String, TextStyle?> installedSlots = _slotsOf(installed);
  final Map<String, TextStyle?> expectedSlots = _slotsOf(expected);

  expect(
    installedSlots.keys.toSet(),
    expectedSlots.keys.toSet(),
    reason:
        'the two themes do not expose the same slots, so $where cannot be '
        'compared slot by slot',
  );

  // **AND THE COMPARISON IS NOT VACUOUS.** A `_slotsOf` that returned an empty
  // map would leave the loop below with nothing to compare, and an empty
  // difference list would read as a pass. Material 3 defines **fifteen**
  // slots, and all fifteen have to be here.
  expect(
    expectedSlots.length,
    15,
    reason:
        'the comparison enumerated ${expectedSlots.length} slots, not the '
        'fifteen Material 3 defines, so the diff below is over a smaller '
        'surface than the claim and an empty difference list would mean '
        'nothing',
  );
  expect(
    installedSlots.values.where((TextStyle? style) => style == null),
    isEmpty,
    reason:
        'the installed theme is missing a slot in $where, so the comparison '
        'against Eva\'s theme is not over the same surface',
  );

  final List<String> differences = <String>[];
  for (final MapEntry<String, TextStyle?> slot in expectedSlots.entries) {
    final List<String> differing = _differingFields(
      slot.value,
      installedSlots[slot.key],
    );
    for (final String field in differing) {
      differences.add('${slot.key}.$field');
    }
  }

  // **THE MEASUREMENT, PRINTED.** The evidence for the claim is in the test
  // run's output, not only in this file's prose.
  debugPrint(
    'textTheme equality — $where — '
    '${expectedSlots.length} slots compared, '
    '${differences.length} differing '
    '(${differences.isEmpty ? 'identical' : differences.join(', ')})',
  );

  expect(
    differences,
    isEmpty,
    reason:
        'the theme the app installs does NOT carry the same `TextStyle` as '
        '`EvaTypography.textTheme(colors)` in $where. A difference in any of '
        'these fields is a **visual** difference, and replacing a call site '
        'with `Theme.of(context).textTheme` would therefore change what the '
        'reader sees. The differing fields are: ${differences.join(', ')}',
  );

  // **AND THE PLAIN `==` HOLDS TOO**, because that is the comparison a reader
  // will actually write when they de-duplicate a call site.
  expect(
    installedSlots['bodyLarge'],
    expectedSlots['bodyLarge'],
    reason: '`bodyLarge` differs by `==` in $where',
  );
}

/// The `textTheme` call sites in every file of [root], by file.
Map<String, List<_Site>> _foundByFile(String root) {
  final Map<String, List<_Site>> found = <String, List<_Site>>{};
  for (final FileSystemEntity entity in _dartFilesIn(root)) {
    final File file = entity as File;
    final List<_Site> sites = <_Site>[];
    final List<String> lines = stripComments(file.readAsStringSync())
        .split('\n');
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      if (!_isCallLine(line)) continue;
      sites.add(
        _Site(line: i + 1, statement: line.replaceAll(RegExp(r'\s+'), '')),
      );
    }
    if (sites.isNotEmpty) {
      found[_relative(file)] = sites;
    }
  }
  return found;
}

/// Whether [line] holds a **call** to `textTheme(` rather than a declaration
/// of it.
///
/// **THE DECLARATION IS JUDGED PER MATCH, NOT PER LINE.** `static TextTheme
/// textTheme(EvaColors colors)` is the one shape in the tree that names
/// `textTheme(` without calling it, and a scanner that counted it would report
/// a site in the file that *defines* the thing being scanned for. But
/// excluding the whole **line** would be a hole: a one-line declaration that
/// also calls — `static TextTheme textTheme(EvaColors c) =>
/// EvaTypography.textTheme(c);` — would have its real call skipped with it.
/// So the shape is decided **per match**, and a line is a site when it holds
/// at least one match that is not a declaration.
bool _isCallLine(String line) {
  for (final RegExpMatch match in _callSite.allMatches(line)) {
    if (_declarationPrefix.hasMatch(line.substring(0, match.start))) continue;
    return true;
  }
  return false;
}

/// A call to `textTheme(` — qualified (`EvaTypography.textTheme(`) or not.
///
/// **The UNQUALIFIED form is matched too, deliberately.** `EvaTypography`'s own
/// three derivations — `scriptureLatin`, `scriptureArabic` and `monoCaps` —
/// call `textTheme(colors)` from inside the class, and they rebuild a whole
/// `TextTheme` each. A matcher that only looked for `EvaTypography.textTheme(`
/// would miss all three, and a gate that cannot see three of the sixteen sites
/// is a gate reporting a clean run over a surface it never examined.
final RegExp _callSite = RegExp(r'\btextTheme\s*\(');

/// The text that precedes a **declaration** of `textTheme`.
///
/// The type, then the name, then the parameter list — `TextTheme textTheme(`.
/// **A call never has that shape**: a call is preceded by the receiver and a
/// dot (`EvaTypography.textTheme(`) or by nothing at all, and the *variable*
/// `final TextTheme textTheme = …` is not a match for the call pattern in the
/// first place, because `textTheme` there is followed by ` =` and not by `(`.
final RegExp _declarationPrefix = RegExp(r'TextTheme\??\s+$');

/// Whether two multisets of statements are the same.
///
/// **Sorted, and compared element by element** — and *not* as sets, because two
/// sites can carry the same text and a set would collapse them.
bool _sameMultiset(List<String> a, List<_Site> b) {
  if (a.length != b.length) return false;
  final List<String> sortedA = List<String>.of(a)..sort();
  final List<String> sortedB = b.map((_Site s) => s.statement).toList()..sort();
  for (int i = 0; i < sortedA.length; i++) {
    if (sortedA[i] != sortedB[i]) return false;
  }
  return true;
}

/// The sites of a file, for a failure message.
String _describe(List<_Site> sites) =>
    sites.map((_Site s) => '${s.line}: ${s.statement}').join(' | ');

/// Every `.dart` file under [directory], excluding the generated ones.
List<FileSystemEntity> _dartFilesIn(String directory) {
  final Directory dir = Directory(directory);
  if (!dir.existsSync()) {
    throw StateError(
      '$directory does not exist — the scan would find nothing '
      'and report a clean run over a surface it never examined',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !_generated.contains(_fileName(f)))
      .toList();
}

/// The generated files, which are the framework's and the generator's and not
/// the tree's.
const Set<String> _generated = <String>{
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
};

String _fileName(File file) {
  final String path = file.path;
  final int slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}

String _relative(File file) {
  final String path = file.path.replaceAll('\\', '/');
  return path.startsWith('./') ? path.substring(2) : path;
}

/// Removes `/* */` and `//` comments, preserving line structure.
///
/// **Ported from `tool/gates/orphan_widget_check.py`'s `strip_comments`, not
/// reinvented** — and the same routine `test/setstate_budget_test.dart` uses.
/// Two gates that strip comments have to strip them the same way, and this one
/// removes a block comment by replacing it with the same number of newlines,
/// so the line count — and therefore every reported `file:line` — is unchanged,
/// and it removes a line comment by removing the rest of the line.
final RegExp _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final RegExp _lineComment = RegExp(r'//[^\n]*');

String stripComments(String text) {
  final String withoutBlocks = text.replaceAllMapped(_blockComment, (Match m) {
    final int newlines = '\n'.allMatches(m.group(0)!).length;
    return List<String>.filled(newlines, '\n').join();
  });
  return withoutBlocks.replaceAll(_lineComment, '');
}

/// A scratch directory outside the repository, for the negative control.
Directory _scratchDirectory() {
  final Directory base = Directory('/tmp/opencode');
  final Directory root = base.existsSync() ? base : Directory.systemTemp;
  final Directory dir = Directory(
    '${root.path}/eva_text_theme_callsite_negative_control',
  );
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  return dir;
}

/// What the app's tree actually hands to its widgets.
///
/// **The `TextTheme` AND the script category it was resolved under**, because
/// the category is what makes the Arabic row of the proof a *different*
/// measurement from the English one rather than the same measurement twice.
class _Installed {
  const _Installed({required this.textTheme, required this.scriptCategory});

  /// `Theme.of(context).textTheme`.
  final TextTheme textTheme;

  /// `MaterialLocalizations.of(context).scriptCategory`.
  final ScriptCategory scriptCategory;
}

/// The `TextTheme` the app's tree actually hands to its widgets.
///
/// **The app's own shape**: `theme:` is the light palette, `darkTheme:` the
/// dark one, and `themeMode` picks — exactly as `lib/app/app.dart:421-438`
/// does it.
Future<_Installed> _installedTextTheme(
  WidgetTester tester, {
  required Brightness brightness,
  required Locale locale,
}) async {
  final List<_Installed> captured = <_Installed>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: EvaThemeLight.theme,
      darkTheme: EvaThemeDark.theme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          captured.add(
            _Installed(
              textTheme: Theme.of(context).textTheme,
              scriptCategory: MaterialLocalizations.of(context).scriptCategory,
            ),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured.single;
}

/// One (brightness, locale) combination, and the palette it installs.
class _BrightnessLocale {
  const _BrightnessLocale({
    required this.label,
    required this.brightness,
    required this.locale,
    required this.colors,
    required this.expectedScriptCategory,
  });

  /// A readable name for the combination.
  final String label;

  /// Which palette the tree installs.
  final Brightness brightness;

  /// The locale the tree is localised to.
  final Locale locale;

  /// The palette's own colours — the argument to `EvaTypography.textTheme`.
  final EvaColors colors;

  /// The script category the locale must resolve to.
  ///
  /// **Arabic is `tall`** — `flutter_localizations`' `material_ar.arb` sets
  /// `scriptCategory: tall` — and English is `englishLike`. Recorded here so
  /// the proof can assert that the arm it measured is the arm it claims.
  final ScriptCategory expectedScriptCategory;
}

/// The four combinations a reader can be in.
const List<_BrightnessLocale> _combinations = <_BrightnessLocale>[
  _BrightnessLocale(
    label: 'dark × en',
    brightness: Brightness.dark,
    locale: Locale('en'),
    colors: EvaColors.dark(),
    expectedScriptCategory: ScriptCategory.englishLike,
  ),
  _BrightnessLocale(
    label: 'dark × ar',
    brightness: Brightness.dark,
    locale: Locale('ar'),
    colors: EvaColors.dark(),
    expectedScriptCategory: ScriptCategory.tall,
  ),
  _BrightnessLocale(
    label: 'light × en',
    brightness: Brightness.light,
    locale: Locale('en'),
    colors: EvaColors.light(),
    expectedScriptCategory: ScriptCategory.englishLike,
  ),
  _BrightnessLocale(
    label: 'light × ar',
    brightness: Brightness.light,
    locale: Locale('ar'),
    colors: EvaColors.light(),
    expectedScriptCategory: ScriptCategory.tall,
  ),
];

/// One palette and the [ThemeData] the app installs for it.
class _Palette {
  const _Palette({
    required this.label,
    required this.theme,
    required this.colors,
  });

  /// A readable name for the palette.
  final String label;

  /// The installed theme.
  final ThemeData theme;

  /// The palette's own colours.
  final EvaColors colors;
}

/// The two palettes, and the themes the app installs for them.
///
/// **Not `const`**, because `EvaThemeDark.theme` and `EvaThemeLight.theme` are
/// `static final` singletons — which is deliberate on their side
/// (`eva_theme_dark.dart`'s own doc: `MaterialApp` compares `theme` and
/// `darkTheme` by identity) and cannot be a constant here.
final List<_Palette> _palettes = <_Palette>[
  _Palette(
    label: 'dark',
    theme: EvaThemeDark.theme,
    colors: const EvaColors.dark(),
  ),
  _Palette(
    label: 'light',
    theme: EvaThemeLight.theme,
    colors: const EvaColors.light(),
  ),
];

/// The sixteen reviewed sites, and why each is legitimate.
///
/// **The key is the file plus the multiset of normalised statements**, and not
/// `file:line`: a `file:line` key is brittle in the worst way, because any
/// edit above a site moves it, and the gate would cry wolf on a change that
/// changed nothing. A **file** plus the **normalised text of each statement**
/// is stable under line shifts, and it catches all three things a gate must: a
/// **new** statement, a **removed** one, and an **edited** one.
///
/// **AND THE LINE NUMBERS BELOW ARE **NOT** PART OF THE KEY.** They are
/// recorded in the comments beside each row — measured on 2026-10-22 — because
/// a reader needs to know where to look, but a row whose site has moved one
/// line down is still the same reviewed site and must not turn the gate red.
/// The **found** line is what a failure message prints, so that message is
/// always right even when the allowlist's own line note has drifted.
///
/// **And the multiset, and not a set**, because two sites can carry the same
/// text and a set would collapse them into one and a second would slip
/// through.
const Map<String, List<String>> _allowlist = <String, List<String>>{
  // ## THE **THEME** — the one build that has to happen.
  //
  // `EvaTheme.build` is where the `TextTheme` is made, and the `ThemeData`
  // installs it at `:85`. Every other site in this table is a *second* copy of
  // this one, and this is the copy that counts.
  //
  // `lib/core/design_system/theme/eva_theme.dart:59`
  'lib/core/design_system/theme/eva_theme.dart': <String>[
    'finalTextThemetextTheme=EvaTypography.textTheme(colors);',
  ],

  // ## THE **TYPE SYSTEM** — three derivations inside `EvaTypography` itself.
  //
  // `scriptureLatin`, `scriptureArabic` and `monoCaps` are the styles Material
  // has no slot for, and each is derived from a slot of the theme rather than
  // restated. They are reviewed and allowed because they are the **definition**
  // of the slot-less styles — but they are also three of the sixteen rebuilds,
  // and a later lane that de-duplicates the feature sites should look at them
  // too.
  //
  // `lib/core/design_system/tokens/eva_typography.dart:179`, `:188`, `:198`
  'lib/core/design_system/tokens/eva_typography.dart': <String>[
    'textTheme(colors).bodyLarge!.copyWith(fontFamily:scriptureFamily);',
    'textTheme(colors).bodyLarge!.copyWith(fontFamily:arabicFamily);',
    'textTheme(colors).labelMedium!.copyWith(fontFamily:monoFamily);',
  ],

  // ## THE **READING SANCTUARY** — five sites over four files.
  //
  // `verse_line.dart` carries two, in the same verse build: the Latin arm and
  // the Arabic arm. `reading_app_bar.dart` carries two, and `reading_quiz_cta`
  // one.
  //
  // `lib/features/reading/presentation/widgets/verse_line.dart:357`, `:419`
  'lib/features/reading/presentation/widgets/verse_line.dart': <String>[
    'returnEvaTypography.textTheme(colors).bodyLarge!.copyWith(',
    'EvaTypography.textTheme(colors).bodyLarge!.copyWith(',
  ],
  // `lib/features/reading/presentation/widgets/reading_app_bar.dart:225`, `:355`
  'lib/features/reading/presentation/widgets/reading_app_bar.dart': <String>[
    'style:EvaTypography.textTheme(colors).bodyLarge!',
    'EvaTypography.textTheme(colors).bodyLarge!.copyWith(',
  ],
  // `lib/features/reading/presentation/widgets/reading_quiz_cta.dart:165`, `:184`
  'lib/features/reading/presentation/widgets/reading_quiz_cta.dart': <String>[
    '?EvaTypography.textTheme(colors).bodySmall!.copyWith(',
    'style:EvaTypography.textTheme(colors).bodySmall!.copyWith(',
  ],
  // `lib/features/reading/presentation/widgets/reading_pill.dart:341`
  'lib/features/reading/presentation/widgets/reading_pill.dart': <String>[
    'EvaTypography.textTheme(colors).bodyMedium!.copyWith(',
  ],

  // ## THE **JOURNEY** — two sites.
  //
  // `lib/features/journey/presentation/widgets/journey_hero_number.dart:113`
  'lib/features/journey/presentation/widgets/journey_hero_number.dart':
      <String>['EvaTypography.textTheme(colors).displayLarge!.copyWith('],
  // `lib/features/journey/presentation/widgets/journey_identity.dart:60`
  'lib/features/journey/presentation/widgets/journey_identity.dart': <String>[
    'EvaTypography.textTheme(colors).headlineSmall!.copyWith(',
  ],

  // ## THE **HOME DOCK** — three sites.
  //
  // `lib/features/home/presentation/widgets/greeting_block.dart:120`
  'lib/features/home/presentation/widgets/greeting_block.dart': <String>[
    'EvaTypography.textTheme(colors).headlineMedium!.copyWith(',
  ],
  // `lib/features/home/presentation/widgets/library_carousel.dart:378`
  'lib/features/home/presentation/widgets/library_carousel.dart': <String>[
    'EvaTypography.textTheme(colors).headlineSmall!.copyWith(',
  ],
  // `lib/features/home/presentation/widgets/streak_chip.dart:169`
  'lib/features/home/presentation/widgets/streak_chip.dart': <String>[
    'EvaTypography.textTheme(colors).headlineSmall!.copyWith(',
  ],
};
