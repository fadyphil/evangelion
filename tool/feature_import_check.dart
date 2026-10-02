// Cross-feature import check — the body of Gate 2 in `tool/verify_purity.sh`.
//
// Enforces AGENT_CONTEXT §3 "Feature independence" (*no feature may import
// another feature — no exceptions*) mechanically. Read `verify_purity.sh` for
// the gate's output formatting and exit-code contract; this file only decides
// *whether* something is a violation and prints one line per violation.
//
// WHY THIS IS DART AND NOT SHELL: the rule compares the importing file's own
// feature against the feature it imports, and same-package imports are legal in
// two different syntaxes — `package:evangelion/features/quiz/…` and
// `../../quiz/…`. Turning `../..` into a path is exactly the sort of thing a
// shell one-liner gets subtly wrong, and here the failure mode of getting it
// wrong is the silent pass this gate exists to prevent: a regex that fails to
// compile (or a normalizer that never fires) prints nothing and exits 0, which
// reads as "clean". `Uri` removes dot segments by definition, so there is no
// hand-rolled path arithmetic here to be wrong.
//
// PURE DART: `dart:io` only, no `package:` import, no build step. It adds no
// dependency and needs no code generation.
//
// Usage:  dart run tool/feature_import_check.dart      (from the package root)
// Exit:   0 = clean, 1 = violations found (one `path:line: directive` line
//         each, on stdout), 2 = the check could not run.

import 'dart:io';

/// The prefix a `package:` URI must have to point inside this package.
const String _packagePrefix = 'package:evangelion/';

/// The first segment of every path this check reasons about.
const String _lib = 'lib';

/// An `import`, `export`, or `part` directive and the URI it names.
///
/// Three deliberate choices, each of which closes a hole a narrower version of
/// this pattern leaves open:
///
/// * `import|export|part` — `export` re-exposes another library's whole surface
///   to whoever imports this one, so a domain file that re-exports Flutter is
///   exactly as impure as one that imports it; `part` pulls a file into this
///   library's namespace. Only matching `import` misses both.
/// * `(['"])([^'"]+)\1` — both quote styles. Single quotes are the house style
///   and `prefer_single_quotes` (enabled, and fatal under `--fatal-infos`) makes
///   the double-quoted form an analyzer error today, but this check must not
///   lean on an unrelated lint to stay honest.
/// * `^\s*` anchored to a directive keyword — a substring scan for
///   `package:flutter/` also matches the phrase inside a doc comment that
///   *explains* why a file is dependency-free, and that false positive would
///   force the documentation to be watered down to keep the gate green.
///
/// `part of '…'` is deliberately not matched: it names the *parent* of a part,
/// not a file being pulled in.
final RegExp _directivePattern = RegExp(
  r'''^\s*(?:import|export|part)\s+(['"])([^'"]+)\1''',
  multiLine: true,
);

void main(List<String> args) {
  final List<File> sources = _dartFilesUnderLib();

  var violations = 0;

  for (final File file in sources) {
    final String path = _packageRelative(file.path);
    final String? owner = _ownerOf(path);

    // Only these two shapes are gate-2 subjects. `lib/app/` is the composition
    // root, which is *supposed* to reach into features to wire them up.
    if (owner == null) {
      continue;
    }

    final String source = file.readAsStringSync();
    final Uri importer = Uri.parse(path);

    for (final RegExpMatch match in _directivePattern.allMatches(source)) {
      final String uri = match.group(2)!;
      final String? target = _resolveToLibPath(importer, uri);
      if (target == null) {
        continue;
      }

      final String? targetFeature = _featureOf(target);
      if (targetFeature == null) {
        continue;
      }

      // `core/` owns no feature, so it may import none; two features may only
      // reach their own.
      if (owner == targetFeature && owner != 'core') {
        continue;
      }

      violations++;
      stdout.writeln(
        '$path:${_lineOf(source, match.start)}: '
        '${_lineAt(source, match.start).trimRight()}'
        '  — $owner must not depend on $targetFeature',
      );
    }
  }

  if (violations > 0) {
    exit(1);
  }
}

/// Every `.dart` file under `lib/`, sorted so output is reproducible.
List<File> _dartFilesUnderLib() {
  try {
    return Directory(_lib)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
  } on PathNotFoundException {
    stderr.writeln('FATAL: lib/ not found — the feature gate did not run');
    exit(2);
  }
}

/// Strips the working directory so paths compare as `lib/…`.
String _packageRelative(String path) {
  final String root = Directory.current.path;
  final String prefix = root.endsWith('/') ? root : '$root/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

/// The feature that *owns* [path], or null when no gate-2 rule applies.
///
/// `lib/features/<f>/…` → `<f>`; `lib/core/…` → `core`.
String? _ownerOf(String path) {
  final List<String> segments = path.split('/');

  // `lib/features/quiz/domain/x.dart` needs four segments; `lib/features/` on
  // its own is a directory, not a file with an owner.
  if (segments.length < 4 || segments[0] != _lib) {
    return null;
  }

  if (segments[1] == 'features') {
    return segments[2];
  }
  if (segments[1] == 'core') {
    return 'core';
  }
  return null;
}

/// The feature [path] belongs to *as an import target*, or null.
///
/// Deliberately stricter than [_ownerOf]: a target must be inside a feature
/// directory, so it needs the extra segment.
String? _featureOf(String path) {
  final List<String> segments = path.split('/');

  if (segments.length < 4) {
    return null;
  }
  if (segments[0] != _lib || segments[1] != 'features') {
    return null;
  }
  return segments[2];
}

/// Resolves a directive's URI to a `lib/`-relative path, or null when it points
/// outside this package — `dart:core`, `package:dio`, the SDK.
///
/// Handles both legal forms of a same-package import: the `package:evangelion/`
/// URI and a relative path such as `../../quiz/domain/quiz_session.dart`. Both
/// go through the same `Uri` normalisation, so neither syntax can smuggle a
/// `..` past the check and the two forms cannot disagree about where a file is.
String? _resolveToLibPath(Uri importer, String uri) {
  if (uri.contains(':')) {
    if (!uri.startsWith(_packagePrefix)) {
      // `dart:core`, `package:dio`, the SDK — another library entirely.
      return null;
    }
    // A `package:` URI names its target relative to the lib/ root.
    return Uri.parse('$_lib/${uri.substring(_packagePrefix.length)}')
        .normalizePath()
        .path;
  }

  // No scheme, so it is a same-package relative import: resolve it against the
  // importing file. `Uri.resolve` already removes dot segments; normalising
  // again is idempotent and keeps both branches provably identical.
  return importer.resolve(uri).normalizePath().path;
}

/// 1-based line number of [offset] within [source].
int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

/// The whole line containing [offset], without its newline.
String _lineAt(String source, int offset) {
  // `lastIndexOf` rejects a negative `fromIndex`, and a directive on the very
  // first line of a file has offset 0 — so the start index is not `offset - 1`.
  final int start = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
  final int end = source.indexOf('\n', offset);
  return source.substring(start, end == -1 ? source.length : end);
}
