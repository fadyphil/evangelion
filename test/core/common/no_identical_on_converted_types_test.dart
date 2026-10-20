import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/freezed_types.dart';
import '../../support/project_import_graph.dart';

/// No test may rely on `identical()` — or `same()`, which is the same question
/// asked more legibly — on a **`freezed`-converted** type.
///
/// ## WHAT THIS FORBIDS, AND WHY IT IS WORTH A GATE
///
/// AGENT_CONTEXT §2.1, hazard 3: "`freezed` generates `const` constructors,
/// which adds new `const`-canonicalisation surfaces", against a project that has
/// shipped **eight** canonicalisation bugs already. `this project`'s own history
/// names the shapes:
///
/// * `expect(const Foo(...), const Foo(...))` is `expect(identical(a, a), true)`
///   — Dart canonicalises const instances, so the comparison passes against *any*
///   `==`, including a broken one. `failure_test.dart` and `result_test.dart`
///   both open with a paragraph about it; `home_bloc_test.dart` deleted an
///   assertion rather than suppress the lint that made it unwritable.
/// * `identical(a, b)` on a **generated** type additionally couples the test to
///   freezed's internals — `streak_summary_test.dart`'s
///   `isNot(identical(live, live.copyWith()))` asserts that the generated
///   `copyWith` never returns `this`, which is an implementation detail of a
///   generator, not a property of the client.
///
/// So the claim is narrow and mechanical: **no site in `test/` relies on object
/// identity for a converted type, unless it is in the table below with a reason.**
///
/// ## THE TABLE IS EXHAUSTIVE, NOT AN ALLOWLIST OF EXCEPTIONS
///
/// Every `identical(` / `same(` site in `test/` is listed, with the audit outcome
/// for each — the migration's own audit, made permanent so the next one cannot
/// quietly add a site. Four assertions hold it:
///
/// 1. every live site is attributed to a named test and is in the table;
/// 2. every table row still has a live site, so a row cannot outlive its code;
/// 3. each row's site count matches, so a *second* site added inside an
///    already-reviewed test is caught;
/// 4. a row marked `converted: true` must have a converted type inside its
///    window, and one marked `false` must not — which is what stops the flag
///    from drifting away from the code it describes.
///
/// ## WHY THE TABLE IS ~40 ROWS AND NOT ~6
///
/// A shorter table of "the converted-type sites only" needs a **window
/// heuristic** to decide which sites those are, and a window heuristic is a
/// false-negative machine: change the line spacing inside a test and a site
/// stops looking like it is about a converted type. Auditing all of them costs a
/// longer file and buys a claim that cannot go stale silently.
void main() {
  late final Set<String> converted = freezedTypeNamesInLib();
  late final List<_Site> sites = _identitySites();

  group('the scan is not vacuous', () {
    test('it reads the test tree and finds sites', () {
      expect(
        sites,
        isNotEmpty,
        reason:
            'a scan that reads no files passes everything. The walk found no '
            '`identical(` and no `same(` anywhere in `test/`, which means the '
            'tree was not walked, not that the codebase is clean',
      );
      expect(
        sites.length,
        greaterThanOrEqualTo(40),
        reason:
            'the migration\'s audit counted ${sites.length}; a large drop means '
            'the tree stopped being walked',
      );
    });

    test('and the exclusion list is exactly the two files it names', () {
      // An exclusion is a hole in the scan, so it is a fact about the suite that
      // is asserted rather than left in a literal somebody widens on a bad day.
      expect(_excludedFromScan, hasLength(2));
      expect(
        _excludedFromScan,
        containsAll(<String>[
          'test/core/common/no_identical_on_converted_types_test.dart',
          'test/support/freezed_types.dart',
        ]),
      );
    });

    test('and it found the converted set it is about', () {
      expect(
        converted,
        hasLength(46),
        reason:
            'the converted set moved, so the table\'s flags are stale. 34 was the '
            'migration\'s output; Phase 9 converted `UserSettings` and `SettingsState`, '
            'Phase 1 converted `LeaderboardRow`, `LeaderboardStanding`, '
            '`LeaderboardBoard`, `LeaderboardQuery` and `LeaderboardState`, '
            'Phase 3 converted `SkyEntry` and `SkyState`, and Phase 5.2 converted '
            '`StreakHistoryEntry` and `LibraryBook`',
      );
    });
  });

  group('every identity site is attributed to a named test', () {
    test('no site sits outside a `test(…)` this scan can name', () {
      final List<String> unattributed = <String>[
        for (final _Site site in sites)
          if (site.testName == null) '${site.path}:${site.line}',
      ];
      expect(
        unattributed,
        isEmpty,
        reason:
            'a site outside any named test cannot be reviewed, so it cannot be '
            'allowed. Either the site moved into a helper or the scan cannot see '
            'the test it is in',
      );
    });
  });

  group('the audited table', () {
    test('every live site is a row in the table', () {
      final List<String> unlisted = <String>[
        for (final _Site site in sites)
          if (!_reviewed.containsKey('${site.path}#${site.testName}'))
            '${site.path}#${site.testName} (${site.snippet})',
      ];
      expect(
        unlisted,
        isEmpty,
        reason:
            'an `identical()` / `same()` reached `test/` without being audited. '
            'Add it to [_reviewed] with its outcome, or delete it — an '
            'unreviewed identity assertion on a generated type is exactly the '
            'coupling this gate exists to catch',
      );
    });

    test('no row outlives the code it reviewed', () {
      final List<String> stale = <String>[
        for (final String key in _reviewed.keys)
          if (!sites.any(
            (_Site site) => '${site.path}#${site.testName}' == key,
          ))
            key,
      ];
      expect(
        stale,
        isEmpty,
        reason:
            'a row for a test that no longer contains an identity site. Either '
            'the site was removed (delete the row) or the test was renamed '
            '(update the key), and a stale row is a claim about code that is not '
            'there',
      );
    });

    test('each row counts the sites inside its test', () {
      final List<String> mismatched = <String>[
        for (final MapEntry<String, _Reviewed> entry in _reviewed.entries)
          if (entry.value.sites !=
              sites
                  .where(
                    (_Site site) =>
                        '${site.path}#${site.testName}' == entry.key,
                  )
                  .length)
            '${entry.key}: table says ${entry.value.sites}',
      ];
      expect(
        mismatched,
        isEmpty,
        reason:
            'a test gained or lost an identity site since it was reviewed. That '
            'is a new unreviewed site, or a removed one — either way the row has '
            'to be re-read',
      );
    });

    test('and the `converted:` flag still matches the code', () {
      final List<String> drifted = <String>[
        for (final MapEntry<String, _Reviewed> entry in _reviewed.entries)
          if (entry.value.converted !=
              sites.any(
                (_Site site) =>
                    '${site.path}#${site.testName}' == entry.key &&
                    _mentionsAny(site.window, converted),
              ))
            '${entry.key}: table says converted: ${entry.value.converted}',
      ];
      expect(
        drifted,
        isEmpty,
        reason:
            'the flag and the code disagree about whether this site is about a '
            'freezed-converted type. The flag is the interesting half of the '
            'row, so it has to be true',
      );
    });

    test('and every converted-type site carries a reason', () {
      final List<String> unreasoned = <String>[
        for (final MapEntry<String, _Reviewed> entry in _reviewed.entries)
          if (entry.value.converted && entry.value.reason.trim().length < 40)
            entry.key,
      ];
      expect(
        unreasoned,
        isEmpty,
        reason:
            'a converted-type site with no stated outcome is a row that permits '
            'itself. The reason is the whole content of the row',
      );
    });
  });
}

/// Two paths the scan does not read, and the assertion below holds the list to
/// exactly these.
///
/// * **this file** — a gate that audits its own text cannot be edited. Its reason
///   strings necessarily quote `identical(`, so every edit would rewrite its own
///   table, and a table that rewrites itself is not an audit.
/// * **`test/support/freezed_types.dart`** — a library, not a test. Its identity
///   sites are helper code, and a shared fixture cannot be attributed to any one
///   test's claim.
///
/// **AND IT IS **ONE FILE**, NOT THE WHOLE `test/support/` DIRECTORY** — the
/// bullet used to say "`test/support/`", which is a directory, and the list
/// holds one file. **`test/support/design_system_harness.dart` IS SCANNED**, and
/// it is the file with the most identity sites in the tree, so a reader who
/// believed the bullet would have believed a hole that is not there.
///
/// Asserting the list is exactly these two is what stops it becoming a blanket.
const Set<String> _excludedFromScan = <String>{
  'test/core/common/no_identical_on_converted_types_test.dart',
  'test/support/freezed_types.dart',
};

/// One `identical(` / `same(` occurrence, with everything needed to key it.
class _Site {
  const _Site({
    required this.path,
    required this.line,
    required this.testName,
    required this.snippet,
    required this.window,
  });

  /// Package-relative, so the table survives an absolute-path change.
  final String path;
  final int line;

  /// The nearest enclosing `test(` / `testWidgets(` name, or `null`.
  final String? testName;

  /// The source line, trimmed — enough to recognise the row.
  final String snippet;

  /// The test's whole body, for the converted-type check.
  final String window;
}

/// One audited row.
class _Reviewed {
  const _Reviewed({
    required this.sites,
    required this.converted,
    required this.reason,
  });

  /// How many identity sites the test contains.
  final int sites;

  /// Whether any of them is about a `freezed`-converted type.
  final bool converted;

  /// What the migration's audit concluded about it.
  final String reason;
}

/// Every `identical(` / `same(` site in `test/`, keyed by `path#testName`.
///
/// Read by the four assertions in the second group; the table itself is
/// [_reviewed] at the bottom of this file.
List<_Site> _identitySites() {
  final List<_Site> found = <_Site>[];

  for (final File file in _dartSourcesIn('test')) {
    if (_excludedFromScan.contains(_relative(file.path))) continue;
    // Comments are stripped first, and that is not tidiness. Six of this
    // repository's gates carry a paragraph *explaining* the canonicalisation trap
    // in prose that contains the word `identical(`, and `failure_test.dart`'s
    // header does it too — so a scan that reads comments reports a site in a file
    // whose only identity assertion is in its own documentation. The same
    // [withoutDartComments] every other source gate here uses.
    final List<String> lines = withoutDartComments(file.readAsStringSync())
        .split('\n');
    // Two boundaries per file: where each test starts (so a site can be attributed
    // and its window ended), and where each `group(` starts (so the window can
    // reach a fixture declared above the test rather than above the group).
    //
    // The window is one test's body **plus the group it sits in**, and the group
    // is not decoration: `quiz_session_test.dart` declares `aSession` once at
    // group level and the identity site below it never names the type, so a
    // test-only window would report that site as unrelated to a converted type —
    // which is exactly the kind of thing this table exists to catch.
    final List<int> starts = <int>[];
    final List<String> names = <String>[];
    final List<int> groups = <int>[];
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'\bgroup\(').hasMatch(lines[i])) groups.add(i);
      // ## THE DECLARATION IS MATCHED AGAINST A **WINDOW**, NOT A LINE
      //
      // The name may sit on the next line — this repository has more than one
      // `test(\n  'a name that is long',\n  () {` — and the pattern below
      // matches across the newline. **Matching it against one line at a time
      // found every declaration whose name is on the same line and MISSED every
      // declaration whose name is not**, and a missed declaration is not a
      // missing site: it is a site attributed to the *previous* test.
      //
      // **AND THAT IS NOT A COSMETIC MISATTRIBUTION.** A site's `testName` is
      // what the table is keyed on, so a missed boundary means a table row
      // claims a test holds an identity site when the test holds none, and the
      // row that DOES hold the site is keyed under the wrong name. Task 5.7
      // found this the hard way: a new test inserted above two `same(...)`
      // calls moved those two sites onto the new test's row, and the gate
      // reported that the *old* row had lost a site it never had.
      //
      // The window is **three lines**, which is enough for `test(`, a newline,
      // the name and its closing quote, and short enough that a declaration
      // three lines apart cannot be captured by accident.
      final String window = lines
          .sublist(i, (i + 3).clamp(0, lines.length))
          .join('\n');
      final RegExpMatch? name = _testDeclaration.firstMatch(window);
      if (name == null) continue;
      starts.add(i);
      names.add(_nameOn(name, lines, i));
    }

    for (int i = 0; i < lines.length; i++) {
      if (_identityCallAt(lines[i]) == null) continue;
      final int end = _endOfTest(starts, i, lines.length);
      found.add(
        _Site(
          path: _relative(file.path),
          line: i + 1,
          testName: _enclosingTest(starts, names, i),
          snippet: lines[i].trim(),
          window: lines.sublist(_startOfGroup(groups, i), end).join('\n'),
        ),
      );
    }
  }

  return found;
}

/// Matches the opening of a test declaration and captures its name.
///
/// The name may sit on the next line — this repository has more than one
/// `test(\n  'a name that is long',\n  () {` — so a pattern that stops at the
/// first line would miss half the suite.
final RegExp _testDeclaration = RegExp(
  r'''\b(?:test|testWidgets)\(\s*(?:r?)?'([\s\S]*?)'\s*(?:,|\))''',
);

/// The offset of the identity call on [line], or `null` when there is none.
///
/// `same(` needs a word boundary on the left so `isNot(same(x))` matches while
/// `surname(` and `className()` do not.
///
/// ## AND A LINE CARRYING A **TRIPLE-QUOTED** STRING IS SKIPPED WHOLESALE
///
/// The comment-stripper this scan sits beside — `withoutDartComments` in
/// `test/support/project_import_graph.dart` — tracks `'''` blocks explicitly,
/// because a `'''` block is a string and its contents must not be mistaken for
/// code. **This helper is per line, so it cannot see a block that spans
/// lines**, and a `'''` payload that contained the word `identical(` would be
/// reported as a live site.
///
/// **The failure direction is the safe one** — a false positive turns the gate
/// RED over a file with nothing wrong with it, and a false negative would need
/// an unterminated string on one line, which is not valid Dart. So the
/// conservative reading is the right one: **a line that opens or closes a
/// triple-quoted string is skipped entirely.** The cost is that a real
/// identity call on the same line as a `'''` is missed — and the tree has
/// eight `'''` blocks and none of them carries an identity call.
///
/// ## AND A MATCH INSIDE A **STRING LITERAL** IS NOT A CALL
///
/// The scan reads the tree looking for **calls**, and the word `identical(`
/// inside a string is prose. There was exactly one of them in the tree when
/// Task 5.7 measured it, and it was a test's own NAME:
///
/// ```dart
/// test('a factory registration IS distinguishable, so identical() has teeth', …
/// ```
///
/// **And it was in the audited table.** The row for the *previous* test claimed
/// a site that was the next test's name, and its reason described something
/// else entirely — which is the failure this whole file exists to prevent: a
/// row that claims to have reviewed a site, over a site that is not there.
///
/// The rule is the same one the comment-stripping above applies, one layer
/// down: **a call is code, and a word in prose is not a call.** The test's
/// NAME is still needed — it is the boundary this scan attributes sites to —
/// so the strings are not stripped; they are simply not mistaken for calls.
///
/// **AND THE ROW THAT WAS WRONG BECAUSE OF IT IS GONE, NOT RE-POINTED.**
/// `test/app/di/injection_test.dart` had a row for *"nothing is registered for
/// an unregistered type"*, and that test has never contained an identity call —
/// it asserts `throwsA(isA<StateError>())`. The row was counting the **next**
/// test's name:
///
/// ```dart
/// test('a factory registration IS distinguishable, so identical() has teeth', …
/// ```
///
/// **The row's reason described something else entirely** — "two sites, both
/// `isNull`-shaped" — which is the failure this whole file exists to prevent: a
/// row claiming to have reviewed a site, over a site that was not there. The
/// row is deleted, and the test it named is now correctly *not* in the table.
int? _identityCallAt(String line) {
  // **A line carrying a triple-quoted string is skipped wholesale** — see
  // [_identityCallAt]'s doc for why the conservative reading is the right one.
  if (line.contains("'''") || line.contains('"""')) return null;
  for (final RegExpMatch match in RegExp(
    r'\bidentical\(|(?<![\w.])same\(',
  ).allMatches(line)) {
    if (_insideStringLiteral(line, match.start)) continue;
    return match.start;
  }
  return null;
}

/// Is [at] inside a quoted string on [line]?
///
/// A **character** scan and not a parser, and the reason is that the question
/// is only ever asked about a match on a single line: a quote that is open at
/// [at] means the match is prose. Escaped quotes are skipped, and the two
/// quote characters are tracked separately so a `'` inside a `"…"` does not
/// close it.
bool _insideStringLiteral(String line, int at) {
  bool inSingle = false;
  bool inDouble = false;
  for (int i = 0; i < at && i < line.length; i++) {
    final String character = line[i];
    if (character == r'\' && (inSingle || inDouble)) {
      i++;
      continue;
    }
    if (character == "'" && !inDouble) {
      inSingle = !inSingle;
    } else if (character == '"' && !inSingle) {
      inDouble = !inDouble;
    }
  }
  return inSingle || inDouble;
}

/// The test name from the match, with adjacent literals joined.
///
/// Unescaping is not cosmetic: `auth_usecases_test.dart` names a test
/// `returns the repository\'s success untouched`, and a table keyed on the raw
/// capture has to spell the backslash. A key nobody can write by hand is a row
/// nobody adds, so the capture is normalised instead.
String _nameOn(RegExpMatch match, List<String> lines, int index) => match
    .group(1)!
    .replaceAll(r"\'", "'")
    .replaceAll('\n', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _startOfGroup(List<int> groups, int at) {
  int start = 0;
  for (final int candidate in groups) {
    if (candidate > at) break;
    start = candidate;
  }
  return start;
}

/// Clamped to the file, so the caller can `sublist` without an upper bound.
int _endOfTest(List<int> starts, int at, int lineCount) {
  for (final int candidate in starts) {
    if (candidate > at) return candidate;
  }
  return lineCount;
}

String? _enclosingTest(List<int> starts, List<String> names, int at) {
  String? name;
  for (int i = 0; i < starts.length; i++) {
    if (starts[i] > at) break;
    name = names[i];
  }
  return name;
}

bool _mentionsAny(String window, Set<String> names) {
  final String code = withoutDartComments(window);
  for (final String name in names) {
    if (RegExp('\\b$name\\b').hasMatch(code)) return true;
  }
  return false;
}

List<File> _dartSourcesIn(String root) {
  final Directory dir = Directory(root);
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
}

String _relative(String path) =>
    path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?(?=test/)'), '');

/// ## THE AUDITED TABLE
///
/// Keyed `path#test name`. `converted` is the flag the fourth assertion checks
/// against the code; `reason` is what the migration's audit concluded.
const Map<String, _Reviewed> _reviewed = <String, _Reviewed>{
  'test/app/app_settings_wiring_test.dart#`SettingsScope.of` resolves the app\'s own handle':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`SettingsHandle` is a plain closure holder, not a generated type, so the '
            'flag is `false` — and the assertion is exactly that: the page and `getIt` '
            'hold **the same handle object**, because it is one app-wide seam and a '
            'second registration would silently split the two. This is the Phase-9 '
            'version of the bug where `app.dart` built its own handle and the page '
            'read the locator\'s. `same(...)` pins the wiring and no `==` override '
            'could stand in for it.',
      ),
  'test/app/app_settings_wiring_test.dart#and `MaterialApp` still declares both palettes by identity':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'Two `ThemeData`s, one `same(...)` each. Flutter decides whether to '
            're-localise by comparing `theme`/`darkTheme` by identity, and this arm '
            'asserts the preference **swapped** them — so identity is the claim. '
            '`UserSettings` (converted) is what drives it, but the site is about '
            '`ThemeData`.',
      ),
  'test/app/app_settings_wiring_test.dart#and the handle READS them back, as a call-through':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'The handle\'s `settings` getter must hand back the **same object** the '
            'cubit holds, not an equal one: a cached copy in the handle would be a '
            'second source of truth for one preference, which is the hazard the '
            'handle was written to prevent. `UserSettings` is a **converted** type, '
            'so this is the canonicalisation trap in its purest form — two equal '
            'records are the same record to `==` and a different one to '
            '`identical`.',
      ),
  'test/core/domain/entities/user_settings_test.dart#two identical records are equal and are two objects':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'The canonicalisation probe, in the shape this repository has used eight '
            'times: a `freezed` value type must not hand back one instance for two '
            'equal constructions, because a client comparing `a == b` and a client '
            'comparing `a` would then agree about two different states. '
            '`identical(a, b), isFalse` on `UserSettings` is the property; a `==` '
            'assertion could not express it.',
      ),
  'test/app/app_test.dart#darkTheme is a genuinely different theme, not the same twice':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Two `ThemeData`s compared with `isFalse`. Flutter has no value '
            'equality for `ThemeData`, so identity IS the claim: two lookups of '
            'the same slot must not hand back the same object. Untouched by the '
            'migration.',
      ),
  'test/app/app_test.dart#they are the two Eva instance themes, by identity':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            '`MaterialApp` decides whether to re-localise by comparing '
            '`theme`/`darkTheme` by identity, so the two Eva themes have to be '
            'distinct objects. `same(...)` over two `ThemeData`s. Untouched.',
      ),
  'test/app/di/injection_test.dart#a singleton registration yields one instance for every lookup':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'DI lifetime for `GetIt`. The comment in the file names the choice: '
            '`same(...)` prints both operands where `identical(a, b)` + '
            '`isTrue` prints neither, so a failure says which two disagreed.',
      ),
  'test/app/di/injection_test.dart#and it is a singleton, so there is one identity in the app':
      _Reviewed(
        sites: 1,
        converted: false,
        reason: 'DI lifetime for the `Dio` client.',
      ),
  'test/app/di/injection_test.dart#resolves to the same instance the app uses':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'DI lifetime for `@Named(\'apiBaseUrl\')` and for a '
            '`NoParamsUseCase`. Value equality would let a factory pass both, '
            'which is why identity is the assertion.',
      ),
  'test/app/di/injection_test.dart#two lookups are the identical instance':
      _Reviewed(
        sites: 3,
        converted: false,
        reason:
            'Three DI-lifetime rows in one test: `GetIt` itself, a '
            '`NoParamsUseCase` and a named singleton. All hand-written '
            'registrations; no converted type is in the window.',
      ),
  'test/app/di/navigation_injection_test.dart#and the auth registrations are reachable from the same locator':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'DI reachability for `AppRouter`. Not an identity claim about a '
            'converted type — the window names none, and the flag agrees.',
      ),
  'test/app/di/navigation_injection_test.dart#and the bloc is a singleton, so there is one session to read':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE because the window names `AuthBloc`/`AuthState`, and '
            'the window-level flag is deliberately conservative. The site '
            'itself compares `getIt<AuthBloc>()` twice: the BLoC is '
            'hand-written, its STATE is converted, and freezed generates `==` '
            'without touching instance identity — so a factory registration '
            'would still fail this. Unchanged by the migration.',
      ),
  'test/app/di/navigation_injection_test.dart#re-binding AuthStatus does not reach a router that already exists':
      _Reviewed(
        sites: 3,
        converted: false,
        reason:
            'Three sites: `AuthStatus` vs a replacement, the re-bound status, '
            'and `AppRouter` identity across the re-binding. `AuthStatus` is a '
            'hand-written interface, not a converted type.',
      ),
  'test/app/di/navigation_injection_test.dart#two lookups are the identical router':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The lifetime assertion `06-navigation.md` §8 asks for. `AppRouter` '
            'is generated by auto_route and is not a freezed type.',
      ),
  'test/app/neural_motion_scope_placement_test.dart#and it is the one bundle, shared by every descendant':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'An `InheritedWidget` publishing one bundle: "every descendant '
            'reads the same bundle" is observable only as identity, and a '
            'rebuilt bundle would restart the motion. Design-system type, '
            'untouched.',
      ),
  'test/app/router/app_router_test.dart#is RouteType.custom over EvaMotion.fadeSlide and EvaMotion.screen':
      _Reviewed(
        sites: 1,
        converted: false,
        reason: '`EvaMotion` enum identity on a `CustomRouteType`. Untouched.',
      ),
  'test/core/common/failure_test.dart#a details value with no == override cannot break equality':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'Two anti-vacuity guards on `Failure`, whose `details` field has no '
            '`==` override — the whole of recorded hazard 2. `Failure` is '
            'deliberately NOT converted, so these are the pin, not a side '
            'effect.',
      ),
  'test/core/common/failure_test.dart#equal failures share a hash code':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`Failure` hash equality, asserted on two non-canonicalised '
            'instances. Part of the hand-written `hashCode` contract hazard 2 '
            'pins.',
      ),
  'test/core/common/failure_test.dart#every kind round-trips through its wire name':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Enum identity: `values.byName(k)` must return THE member. Enums '
            'have value equality, so this is free insurance. Untouched.',
      ),
  'test/core/common/failure_test.dart#identical fields are equal — as distinct objects':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The anti-vacuity guard for the whole `Failure` equality group: '
            '`expect(identical(a, b), isFalse)` before `expect(a, b)`. Kept '
            'verbatim through the migration — `Failure` was excluded from it.',
      ),
  'test/core/common/failure_test.dart#structurally identical detail maps leave them equal':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The pin for hazard 2 itself: two distinct maps and two distinct '
            'values, asserted non-identical so the equality arm cannot be '
            'canonicalisation.',
      ),
  'test/core/common/freezed_structural_equality_test.dart#and every type freezed owns is asserted above':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE, and the site is this gate\'s own file-scope '
            '`_equalAndDistinct` helper, which sits after the last group so it '
            'lands in that group\'s window. It asserts `identical(a, b)` is '
            'false BEFORE `expect(a, b)`, for every converted type — the '
            'anti-canonicalisation guard the whole file rests on. A converted '
            'type compared by identity on purpose, and the only such site '
            'outside the table below.',
      ),
  'test/core/common/result_test.dart#equal failure results share a hash code':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`Left<Failure, T>` hash equality. `Result<T>` and its arms stayed '
            'hand-written with `Failure` (§2.1 decision 7), so this is '
            'untouched.',
      ),
  'test/core/common/result_test.dart#equal successes share a hash code':
      _Reviewed(
        sites: 1,
        converted: false,
        reason: '`Right<Failure, T>` hash equality, same reasoning.',
      ),
  'test/core/common/result_test.dart#two failures carrying structurally equal Failures are equal':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'Two anti-vacuity guards, one of them on the nested `Failure`: '
            '`Result<T>` is excluded from the migration, and this file is its '
            'pinned contract.',
      ),
  'test/core/common/result_test.dart#two successes with equal values are equal — as distinct objects':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The anti-vacuity guard for the `Right<Failure, T>` equality group. '
            'Untouched by the migration.',
      ),
  'test/core/design_system/effects/lumen_canvas_test.dart#loads the shader and memoises the wrapper':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`LumenProgram.load()` memoises the wrapper: two loads must hand '
            'back the same wrapper object, which is the observable half of '
            '"holding one instance". The wrapper defines no `==`, so identity '
            'IS the claim — a second wrapper around the same engine program '
            'would pass any equality check while doubling the sharing the '
            'class exists to provide.',
      ),
  'test/core/design_system/effects/lumen_canvas_test.dart#each program hands out its own FragmentShader':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`newShader()` must allocate: two calls hand back two uniform '
            'buffers, which is why `LumenCanvas` calls it once and mutates '
            'the result. `FragmentShader` defines no `==`, so only identity '
            'can say "a second call is a second buffer" — the `isFalse` half '
            'carries the allocation claim.',
      ),
  'test/core/design_system/effects/lumen_canvas_test.dart#a failed load is not memoised':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The memoised good program is untouched by the failures in this '
            'test: two loads hand back the same wrapper. Same shape as the '
            'memoise row — identity is the claim because the wrapper defines '
            'no `==`, and a reloaded-but-equal program would pass `==` while '
            'hiding a broken cache.',
      ),
  'test/core/design_system/effects/lumen_canvas_test.dart#the FragmentShader is allocated once, on the first paint':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`paint` must mutate one `FragmentShader` in place across frames: '
            'identical pixels cannot tell one buffer from two, so instance '
            'identity is the only witness that hard rule 2 holds — a '
            'per-frame allocator passes every pixel test in the file. '
            '`FragmentShader` defines no `==`.',
      ),
  'test/core/design_system/effects/neural_background_test.dart#NeuralBackground.build does not re-run across 60 frames':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Widget identity: "build ran once" is observable only as "the same '
            'boundary object". Phase 5 performance mitigation, untouched.',
      ),
  'test/core/design_system/effects/neural_background_test.dart#but the ListenableBuilder DOES rebuild — that is §13.1':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The negative control for the row above: a rebuild must produce a '
            'NEW boundary. Without it, "never rebuilt" would also be satisfied '
            'by "never built".',
      ),
  'test/core/design_system/effects/neural_background_test.dart#changing the palette repaints the painter':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`CustomPaint` identity across a palette change — Phase 8\'s '
            'recorded case, where comparing two `CustomPaint`s with `identical` '
            'is vacuous because `CustomPaint` is rebuilt every build. The '
            'assertion here is the `isFalse` half, which is the one with '
            'content. Untouched.',
      ),
  'test/core/design_system/effects/neural_background_test.dart#changing the variant repaints the painter':
      _Reviewed(
        sites: 1,
        converted: false,
        reason: 'The second `CustomPaint` identity row, same shape.',
      ),
  'test/core/design_system/effects/neural_background_test.dart#the page above the background is untouched too':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`Element` identity for a `Text` above the background: sixty '
            'animation frames must not rebuild the subtree. Untouched.',
      ),
  'test/core/design_system/effects/neural_motion_test.dart#a second mount gets brand new controllers':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'Identity of a remounted motion bundle and of its `Listenable` '
            'field. One of the recorded canonicalisation traps (`same()` on a '
            'canonicalised field) and it is on a design-system type. Untouched.',
      ),
  'test/core/design_system/theme/eva_theme_test.dart#is what both instance files call':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`EvaTheme.build` returns a fresh `ThemeData` rather than the '
            'static instance — the regression guard for the `const` '
            'canonicalisation bug this project has already shipped. `ThemeData` '
            'identity, untouched.',
      ),
  'test/core/design_system/theme/eva_theme_test.dart#reading EvaThemeDark.theme twice returns the same object':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'The documented POSITIVE half of that trap: two const expressions '
            'of the same palette are one object, asserted deliberately, which '
            'is what lets `MaterialApp` compare by identity. Untouched.',
      ),
  'test/core/design_system/theme/eva_theme_test.dart#they are distinct ThemeData instances':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The negative half: the light and dark themes must not be the same '
            'object. Untouched.',
      ),
  'test/core/design_system/tokens/eva_colors_test.dart#a copyWith on a CUSTOM sticker map does not revert to stock':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'Map identity, twice. `EvaColors.copyWith` is hand-written and the '
            'design system is out of the migration\'s scope, so the hand-rolled '
            '`copyWith` here is untouched on purpose.',
      ),
  'test/core/design_system/tokens/eva_colors_test.dart#interpolates every sticker slot into a map of its own':
      _Reviewed(
        sites: 2,
        converted: false,
        reason:
            'A `Color.lerp` must alias neither endpoint\'s map. Map identity is '
            'the only way to say that.',
      ),
  'test/core/design_system/tokens/eva_colors_test.dart#is usable as a const value, so themes can be const':
      _Reviewed(
        sites: 5,
        converted: false,
        reason:
            'Five rows asserting Dart\'s const canonicalisation as a fact about '
            '`EvaColors`, each next to its deliberately-vacuous self-comparison '
            'control. This is the trap this repository has already shipped a '
            'fix for, kept as a live guard. Untouched.',
      ),
  'test/core/design_system/tokens/eva_colors_test.dart#with no arguments returns an equal, distinct instance':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`EvaColors.copyWith()` must return an equal but DISTINCT object — '
            'the same shape as the `StreakSummary` row below, and here the '
            'hand-rolled method guarantees it. Untouched.',
      ),
  'test/core/design_system/tokens/eva_typography_test.dart#is a distinct object per palette, and reflects the ink it was given':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Colour-value identity on a text style: two `TextTheme`s built from two '
            'palettes must not be the same object. `EvaColors` is hand-written and '
            '`TextTheme` is the framework\'s, so no converted type is in the window. '
            'Untouched.',
      ),
  'test/core/design_system/widgets/sun_burst_test.dart#a palette change repaints the painter':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`CustomPaint` identity on a palette change, the `SunBurst` half of '
            'Phase 8\'s case. Untouched.',
      ),
  'test/core/domain/entities/quiz_session_test.dart#`withAnswerAt` replaces one answer and leaves the rest verbatim':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND DELIBERATELY KEPT. `next.answers[1]` is a '
            '`QuizAnswer`, so this is identity on a freezed type. '
            '`withAnswerAt` is hand-written and rebuilds `answers` from the '
            'same element references, and freezed\'s data class stores the list '
            'it was given rather than copying it, so the claim still holds: '
            '"every other entry carried verbatim". It is a claim about freezed '
            'doing nothing, which the migration did not change.',
      ),
  'test/core/domain/entities/reading_language_test.dart#round-trips through fromCode':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Enum identity on `ReadingLanguage`. Untouched — enums are not '
            'converted.',
      ),
  'test/core/domain/entities/scripture_verse_test.dart#`copyWith` replaces the lists wholesale':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND NOW LOAD-BEARING ON GENERATED CODE. '
            '`source.copyWith()` forwards `verses: _self.verses` untouched, so '
            'the returned `ScriptureText` holds the SAME list — which is '
            'exactly what "replaced wholesale, not cloned" means, and the '
            'neighbouring two assertions cover the replacing half. If freezed '
            'ever deep-copied collections this row would go red, and it should: '
            'it is the observable half of "copyWith does not clone".',
      ),
  'test/core/domain/entities/sky_entry_test.dart#two identical entries are equal and are two objects':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'The canonicalisation probe, in the same shape as `UserSettings`: '
            '`identical(a, b), isFalse` first, because two identically-written '
            'constant expressions would be canonicalised into one instance and '
            '`expect(a, b)` would then pass against any `==`, including a '
            'broken one. The `lit(…)` helper is what keeps both constructions '
            'non-constant — the same trick `user_settings_test.dart`\'s '
            '`step()` plays for the same reason.',
      ),
  'test/core/domain/entities/streak_summary_test.dart#and it is not the same object as an equal one':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND THE COUPLING IS NAMED. `live.copyWith()` with no '
            'arguments returns a NEW `StreakSummary`, so the assertion holds — '
            'but it holds because freezed\'s generated `copyWith` calls the '
            'constructor unconditionally instead of returning `this`, which is '
            'an implementation detail of a generator. Recorded rather than '
            'rewritten: it is the non-vacuity guard for the group above it, and '
            '`freezed_structural_equality_test.dart` now builds two '
            'equal-but-distinct instances directly, which is the durable form '
            'of the same guard.',
      ),
  'test/core/domain/entities/streak_summary_test.dart#and names the wire value back':
      _Reviewed(
        sites: 1,
        converted: false,
        reason: 'Enum identity on `StreakTodayStatus`. Untouched.',
      ),
  'test/features/auth/data/fake_auth_repository_test.dart#returns the SAME session object on a second sign-in':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND UNCHANGED. `AuthSession` is freezed now, but '
            'freezed generates `==` and never touches instance identity, so '
            'this still passes for the same reason: the fake MEMOISES one '
            'seeded session. If it started returning a fresh-but-equal session '
            'this would go red, which is correct — the row is a caching claim, '
            'and that is what the test is for.',
      ),
  'test/features/auth/domain/usecases/auth_usecases_test.dart#and passes a failure straight through':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE because the window names `AuthSession`; the site '
            'itself compares a `Failure`, which stayed hand-written. `SignOut` '
            'returns the port\'s failure object rather than a copy.',
      ),
  'test/features/auth/domain/usecases/auth_usecases_test.dart#and surfaces a failure rather than dropping it':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'The `isFailure` half of the row above, with no identity site of '
            'its own beyond the shared window. Untouched.',
      ),
  'test/features/auth/domain/usecases/auth_usecases_test.dart#returns the repository\'s failure untouched':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE for the same window reason. The compared object is a '
            'hand-written `Failure`.',
      ),
  'test/features/auth/domain/usecases/auth_usecases_test.dart#returns the repository\'s success untouched':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND UNCHANGED. `SignIn` returns the port\'s own '
            '`AuthSession` without rebuilding it, so `same(session)` holds. A '
            'use case that reconstructed an equal session would go red — and '
            'that is the claim: the use case adds nothing to the port (§3, '
            'DIP).',
      ),
  'test/features/auth/domain/usecases/auth_usecases_test.dart#returns the session the port reports':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'CONVERTED, AND UNCHANGED. `GetCurrentSession`\'s half of the same '
            'claim.',
      ),
  'test/features/auth/presentation/pages/login_accessibility_test.dart#and none of them is a Tab stop, while the CTA is':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            '`Element` identity inside `find.byElementPredicate`: "the focused '
            'control is the one the focus node belongs to" is not expressible '
            'by value. Untouched. The row\'s key moved with the test in Phase '
            '5.1, when the redesigned screen\'s tab walk gained its new name; '
            'the site itself is the same one the first version of this row '
            'reviewed.',
      ),
  'test/features/auth/presentation/pages/login_accessibility_test.dart#a refused sign-in is announced as a live region':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'The SAME justification as the row above, attributed to a '
            'different name: the site lives in the file\'s shared '
            '`_ringAppearsOnTab` helper, and the audit\'s window attributes a '
            'helper at end-of-file to the last test that runs before it — '
            'which is the refusal test. FLAGGED TRUE only because the audit\'s '
            'window names a converted type in the refusal test\'s own body '
            '(`AuthSession`); the site compares `Element`s — "the focused '
            'control is the one the focus node belongs to", not expressible by '
            'value — and is untouched.',
      ),
  'test/features/reading/data/dio_repositories_test.dart#and the fake cannot throw either, because it is handed a Result':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE because the window names a converted entity; the site '
            'compares a repository object (`asPort same(fake)`) — LSP '
            'substitutability, not entity equality. Untouched.',
      ),
  'test/features/reading/data/mappers/streak_summary_mapper_test.dart#is `const`':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'Dart\'s canonicalisation on the hand-written `StreakSummaryMapper`. '
            'The window names no converted type, and the flag agrees.',
      ),
  'test/features/reading/data/mappers/submit_result_mapper_test.dart#the mapper is `const`, so it registers as a singleton':
      _Reviewed(
        sites: 1,
        converted: true,
        reason:
            'FLAGGED TRUE because the window names `SubmitResult`; the site '
            'compares two `SubmitResultMapper`s, a hand-written `const` class. '
            'Identity here asserts Dart\'s canonicalisation, and freezed did not '
            'change it.',
      ),
  'test/features/reading/data/mappers/today_reading_mapper_test.dart#is `const`, so it registers as a singleton and allocates nothing':
      _Reviewed(
        sites: 1,
        converted: false,
        reason:
            'A `const` mapper\'s identity, and it is worth being exact about what it '
            'claims: Dart **canonicalises `const` instances**, so `same()` on two '
            '`const` expressions is true by the language and not by the mapper being '
            'a singleton. The real claim is that the mapper is declared `const` at '
            'all, and that is a compile-time fact. `TodayReadingMapper` is '
            'hand-written, so no converted type is in the window. Untouched.',
      ),
};
