// Route-inventory parser — the body of Gate 4 in `tool/verify_purity.sh`.
//
// AGENT_CONTEXT §2 locks six route paths plus a wildcard, and `app_routes.dart`
// says PURE DART on purpose: Phase 4's router, Phase 5's auth guard and every
// page's app-bar title all read from it, and none of them should need a binding
// to do so. Neither claim was checked until this file existed. See
// `verify_purity.sh` for the gate's output formatting and exit-code contract;
// this file only decides *what is declared*.
//
// WHY A PARSER AND NOT A LIST. `app_routes.dart` is a class of static
// constants. Dart has no reflection, so a test cannot enumerate a class's
// statics, and the shape every earlier version of this suite used was a
// hand-written `Map<String, String>` in the test file enumerating the constants
// it knew about. That list is a second source of truth, and it drifts silently:
// adding four constants to `AppRoutes` while leaving the list alone — including
// one that duplicates `/login`, one padded `' /quiz '`, one uppercase `/QUIZ`,
// and one second spelling `/login/` — leaves the whole suite green, which
// defeats five of the seven structural invariants. Two of those invariants name
// exactly that hazard in their own comments.
//
// An `AppRoutes.values` list in production would not have fixed it. It moves the
// second source of truth from the test file to `lib/`, and a constant added
// outside that list still drifts — Dart offers no way to close the window
// completely. Parsing the declaration site does close it for the case that
// matters: a route that is *declared* is a route the invariants are about.
//
// WHAT IT STILL DOES NOT SEE, stated plainly: a route built by an expression
// rather than a literal (`static const String x = '$prefix/login';`). Those are
// reported as unparsed and fail the gate, because an invariant that skips a
// declaration is worse than one that admits it cannot see it. And a declaration
// that appears inside a comment is parsed as a declaration — reported as a route,
// so it fails the invariants loudly rather than passing unnoticed.
//
// PURE DART: `dart:io` only, no `package:` import, no dependency, no codegen.
// Same shape and exit-code contract as `feature_import_check.dart`.
//
// Usage:  dart run tool/route_check.dart      (from the package root)
// Exit:   0 = every route declaration parsed, 1 = some did not, 2 = the
//         check could not run.

import 'dart:io';

/// The declaration site this check reads. Single source, named here so the test
/// that shares this parser cannot point it somewhere else by accident.
const String routesFile = 'lib/core/navigation/app_routes.dart';

/// Matches every `static const String <name> = …;` declaration, initialiser
/// included, and captures the name.
///
/// `dotAll` so a declaration wrapped across lines is still one declaration.
/// `^[ \t]*` rather than `^\s*` so a `///` doc comment above a declaration cannot
/// be absorbed into the match by the leading `[\s\S]*?` — the capture would then
/// be the wrong identifier.
final RegExp _declarationPattern = RegExp(
  r'^[ \t]*static\s+const\s+String\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=[^;]*;',
  multiLine: true,
  dotAll: true,
);

/// The same, but requiring the initialiser to be a single plain string literal
/// with no interpolation and no escapes.
///
/// Both quote styles: the *test* side of this pair must not depend on
/// `prefer_single_quotes` staying enabled to keep reading the file correctly.
final RegExp _literalDeclarationPattern = RegExp(
  r'''^[ \t]*static\s+const\s+String\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(['"])([^'"$]*)\2\s*;''',
  multiLine: true,
  dotAll: true,
);

/// Every `static const String` name declared in [source], in declaration order.
List<String> declaredRouteNames(String source) => _declarationPattern
    .allMatches(source)
    .map((RegExpMatch match) => match.group(1)!)
    .toList();

/// `name -> value` for every `static const String` in [source] whose initialiser
/// is a plain string literal.
///
/// A name absent from this map but present in [declaredRouteNames] is a
/// declaration this parser cannot evaluate, and the caller is expected to fail on
/// it rather than skip it.
Map<String, String> declaredRouteValues(String source) {
  final Map<String, String> routes = <String, String>{};
  for (final RegExpMatch match in _literalDeclarationPattern.allMatches(
    source,
  )) {
    routes[match.group(1)!] = match.group(3)!;
  }
  return routes;
}

/// [declaredRouteNames] minus the names [declaredRouteValues] could evaluate.
List<String> unparsedRouteNames(String source) {
  final Set<String> parsed = declaredRouteValues(source).keys.toSet();
  return declaredRouteNames(source)
      .where((String name) => !parsed.contains(name))
      .toList();
}

void main(List<String> args) {
  final File file = File(routesFile);

  // A missing file is exit 2, not exit 0: "no violations" and "nothing to look
  // at" are different answers, and this gate has to be able to tell them apart.
  if (!file.existsSync()) {
    stderr.writeln('FATAL: $routesFile not found — the route gate did not run');
    exit(2);
  }

  final String source;
  try {
    source = file.readAsStringSync();
  } on FileSystemException catch (error) {
    stderr.writeln('FATAL: could not read $routesFile: ${error.message}');
    exit(2);
  }

  final List<String> names = declaredRouteNames(source);
  if (names.isEmpty) {
    stderr.writeln(
      'FATAL: no `static const String` declarations found in $routesFile — '
      'the route gate did not run',
    );
    exit(2);
  }

  final List<String> unparsed = unparsedRouteNames(source);
  for (final String name in unparsed) {
    stdout.writeln(
      '$routesFile: $name — initialiser is not a plain string literal, so the '
      'structural invariants cannot be evaluated against it',
    );
  }

  if (unparsed.isNotEmpty) {
    exit(1);
  }

  stdout.writeln(
    '${names.length} route declaration(s), all plain string literals',
  );
}
