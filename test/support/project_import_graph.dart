/// The project-local import graph, as something a test can walk, plus the Dart
/// source scanner the source gates share.
///
/// ## WHY THIS IS A SHARED HELPER AND NOT A COPY IN EACH SUITE
///
/// AGENT_CONTEXT §7 makes domain purity an invariant, and `tool/verify_purity.sh`
/// Gate 1 enforces it with a single regex against the *importing file's own
/// directives*. That regex has no graph resolution, so it cannot see a file that
/// is itself Flutter-free but reaches Flutter transitively — through an `export`,
/// through a `part`, or through a barrel that re-exports the framework. A
/// `core/domain/*.dart` file that imported `core/design_system/barrel.dart`
/// would pass Gate 1 the day the barrel grew a `package:flutter/material.dart`
/// re-export, and the flag would read `ok`.
///
/// Walking the graph is the only way to see that. The walk itself is not
/// trivial — `import`, `export` and `part`, in both quote styles, in both
/// `package:evangelion/…` and relative forms — and two independent copies of it
/// would be two things to keep in step, which is the exact failure mode §7 warns
/// about. So the walk lives here once.
///
/// [withoutDartComments] is here for the same reason and arrived the same way.
/// It began as a private copy inside `no_colour_literals_test.dart`, and
/// `focus_ring_gate_test.dart` then needed the identical function — where a
/// *second* copy would have been free to diverge on the three inputs that
/// actually broke the first one (nested `/* */`, an apostrophe in a `///` line,
/// and a `'''` block). One implementation, one set of tests.
///
/// Pure `dart:io`, no `package:flutter`, no dependency, no codegen, and not a
/// `*_test.dart` — `flutter test` collects only the latter, so this is a library
/// the suites import rather than a suite of its own.
library;

import 'dart:io';

/// Matches an `import`, `export`, or `part` directive and captures its URI.
///
/// All three directives, not just `import`. `export` re-exposes another
/// library's whole surface to whoever imports this one, and `part` pulls a file
/// into this library's namespace, so either one makes `package:flutter/` just
/// as reachable from an importer as a direct import does — and neither trips a
/// lint. A walk that only understands `import` reports "Flutter-free" over a
/// graph that is not.
///
/// ## THE COMBINATOR TRAP, WHICH IS WHY THIS IS ANNOTATED
///
/// The URI group is `([^'"]+)`, terminated by the *closing quote*, not by the
/// end of the line or by the semicolon. A combinator puts text between the two:
///
/// ```dart
/// export 'package:flutter/material.dart' show ThemeData;
/// ```
///
/// An earlier version of `barrel_test.dart` matched `^export '([^']+)';$`, which
/// required the line to END in `';` — so every `show`/`hide` export was invisible
/// to it, in both the "is every file exported" check and the "re-exports nothing
/// from the framework" check. `dart analyze` reported nothing (the export is
/// legal Dart) and Gate 1 reported `ok` (it never scanned the barrel). Three
/// checks agreed and all three were looking somewhere else. Anything that parses
/// a directive must therefore stop at the quote, never at the `;`.
final RegExp directivePattern = RegExp(
  r"""^\s*(?:import|export|part)\s+(['"])([^'"]+)\1""",
  multiLine: true,
);

/// The URI scheme prefix of this package's own imports.
const String packagePrefix = 'package:evangelion/';

/// The URI prefix the architecture forbids in a pure-Dart graph.
const String flutterPrefix = 'package:flutter/';

/// Package root, always with a trailing separator.
final String _rootPath = Directory.current.uri.path;

/// Walks the project-local import graph from [entry] and returns every file it
/// can reach, as a package-relative path. [entry] itself is included.
///
/// `import`, `export`, and `part` directives are all followed — see
/// [directivePattern] — in both `package:evangelion/…` and relative forms,
/// because `@InjectableInit(preferRelativeImports: true)` makes the generated
/// config import its sibling relatively. `dart:` and external packages are not
/// followed: `get_it` and `injectable` are pure Dart and declare no Flutter
/// dependency, so the project-local closure is the whole of what this needs to
/// police.
Set<String> reachableProjectFiles(String entry) {
  final Set<String> seen = <String>{};
  final List<Uri> pending = <Uri>[Directory.current.uri.resolve(entry)];

  while (pending.isNotEmpty) {
    final Uri fileUri = pending.removeLast();
    if (!seen.add(_relativise(fileUri))) {
      continue;
    }

    final String source = File.fromUri(fileUri).readAsStringSync();
    for (final RegExpMatch match in directivePattern.allMatches(source)) {
      // Group 2 matched a URI between matched quotes, so it cannot be null.
      final String target = match.group(2)!;

      if (target.startsWith(packagePrefix)) {
        pending.add(
          Directory.current.uri.resolve(
            'lib/${target.substring(packagePrefix.length)}',
          ),
        );
      } else if (!target.contains(':')) {
        // A relative import: no scheme, so it resolves against the importing
        // file. Anything with a scheme (`dart:`, `package:`) is external.
        pending.add(fileUri.resolve(target));
      }
    }
  }

  return seen;
}

/// Strips the package-root prefix so results compare as plain relative paths.
String _relativise(Uri fileUri) {
  final String path = fileUri.toFilePath();
  return path.startsWith(_rootPath) ? path.substring(_rootPath.length) : path;
}

/// [fileUri] as a package-relative path, matching what
/// [reachableProjectFiles] returns.
///
/// The two have to agree for a walk to be checkable: a caller that enumerates
/// entry points off the filesystem holds absolute paths, and one that walks from
/// them holds relative ones. Comparing an absolute path against a relative set
/// fails without naming the mismatch, which is the least useful failure shape
/// there is — "expected `…/lib/core/common/app_config.dart`, actual
/// `lib/core/common/app_config.dart`" reads like a bug in the walk.
String packageRelative(Uri fileUri) => _relativise(fileUri);

/// The URIs named by [path]'s `import`, `export`, and `part` directives.
///
/// Directive-only on purpose. A substring scan for `package:flutter/` also
/// matches the phrase inside a doc comment that *explains* why a file is
/// Flutter-free, which is a false positive that would force the documentation
/// to be watered down to keep the gate green.
Set<String> importUrisOf(String path) => directivePattern
    .allMatches(File(path).readAsStringSync())
    .map((RegExpMatch match) => match.group(2)!)
    .toSet();

/// The forbidden URIs named by [path]'s own directives — Flutter, Dio or http.
///
/// Named rather than just Flutter because that is the set Gate 1 enforces, and
/// this helper is the transitive version of that gate. A gap between the two —
/// a scheme Gate 1 forgot and this one remembers — would be a hole in the gate
/// itself, so the two lists are kept together.
Set<String> forbiddenImportUrisOf(String path) => <String>{
  for (final String uri in importUrisOf(path))
    if (uri.startsWith(flutterPrefix) ||
        uri.startsWith('package:dio/') ||
        uri.startsWith('package:http/'))
      uri,
};

/// The package root, found by walking up from the working directory until a
/// `pubspec.yaml` appears.
///
/// NOT from `Platform.script`. Under `flutter test` the script is a generated
/// bootstrap file in a temporary directory, so counting parents off it lands
/// somewhere else entirely. Suite-local copies of this walk existed before this
/// helper; both are replaced by the one above.
Directory get packageRoot {
  Directory dir = Directory.current.absolute;
  while (!File.fromUri(dir.uri.resolve('pubspec.yaml')).existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'no pubspec.yaml above ${Directory.current.path} — the design-system '
        'barrel test cannot locate the package root',
      );
    }
    dir = parent;
  }
  return dir;
}

/// The file names in [paths], so an assertion about *which* files were reached
/// does not depend on the temp directory's separator or location.
Set<String> fileNamesOf(Iterable<String> paths) =>
    paths.map((String path) => path.split(Platform.pathSeparator).last).toSet();

/// Writes a throwaway import graph whose every directive is deliberately
/// non-default — a double-quoted `export` with a `show` combinator, a `part`,
/// then a plain relative `import` — and returns the directory holding it.
///
/// Built at run time rather than committed. A committed fixture would need a
/// `// ignore: prefer_single_quotes` header to survive `dart analyze`, and a
/// fixture the analyzer tolerates no longer proves the walk sees double quotes
/// or combinators.
///
/// The `show` combinator is the point of the deepest file: it is the exact shape
/// that defeated `barrel_test.dart`'s old export regex, so the fixture fails the
/// moment the pattern is narrowed back to `\1;`.
Directory writeDirectiveFixture() {
  final Directory dir = Directory.systemTemp.createTempSync(
    'evangelion_import_graph',
  );
  File(
    '${dir.path}/deepest.dart',
  ).writeAsStringSync('export "package:flutter/material.dart" show Color;\n');
  File('${dir.path}/middle.dart').writeAsStringSync("part 'deepest.dart';\n");
  File('${dir.path}/entry.dart').writeAsStringSync("import 'middle.dart';\n");
  return dir;
}

/// Strips every comment from [source], newlines preserved.
///
/// ## WHY A SOURCE GATE NEEDS THIS
///
/// A source gate asks "does this file use `EvaFocusRing`?" and a doc comment
/// explaining that a `GestureDetector` is *deliberately not* wrapped in one
/// answers that question — with the word the gate is looking for. The gate then
/// passes on the strength of its own documentation. That is not a hypothetical:
/// the focus-ring gate's ring check was a bare `source.contains`, and a doc
/// comment reading *"Deliberately not an [EvaFocusRing]"* defeated it while the
/// file shipped an unfocusable drag surface.
///
/// ## WHY A HAND-ROLLED SCANNER AND NOT A REGULAR EXPRESSION
///
/// Three inputs, each of which cost a real bug when this was simpler:
///
/// - Dart **nests** block comments, so `/* a /* b */ c */` needs a depth
///   counter; a regex ends at the inner `*/` and leaves `c */` looking like code.
/// - **An apostrophe inside a line comment desynchronises a scanner that only
///   handles block comments.** `/// … the prototype's hexes` opens what the
///   scanner thinks is a string literal, and the `'` in the next comment closes
///   it, so the block comment between them is emitted verbatim and the gate flags
///   its own documentation.
/// - `//` has to be recognised *before* `/*`, or `///` opens a block comment.
///
/// Triple-quoted strings are tracked, because a `'''` block is a string and its
/// contents must not be mistaken for code.
///
/// ## FAILS CLOSED
///
/// An unbalanced scan throws [StateError] rather than returning a plausible
/// answer. A comment parser that has lost track must say so; a scanner that
/// guessed would report a clean tree over a file it never understood, which is
/// §7's "a gate that cannot fail is worse than no gate" in its purest form.
///
/// Strings are **kept**, comments only: a string literal naming a colour or a
/// widget is code-adjacent at worst, and reporting it is diagnosable where
/// silently dropping it is not.
///
/// [no_colour_literals_test.dart] holds the behavioural tests for this function;
/// they moved here with it rather than being copied, so the tests and the
/// implementation cannot drift apart.
String withoutDartComments(String source) {
  final StringBuffer out = StringBuffer();
  final int n = source.length;
  int blockDepth = 0;
  String terminator = '';
  int i = 0;

  while (i < n) {
    final String ch = source[i];
    final String next = i + 1 < n ? source[i + 1] : '';

    if (blockDepth > 0) {
      if (ch == '\n') {
        out.write(ch);
      } else if (ch == '/' && next == '*') {
        blockDepth++;
        i += 2;
        continue;
      } else if (ch == '*' && next == '/') {
        blockDepth--;
        i += 2;
        continue;
      }
      i++;
      continue;
    }

    if (terminator.isNotEmpty) {
      if (ch == r'\' && terminator.length == 1 && i + 1 < n) {
        out.write(ch);
        out.write(source[i + 1]);
        i += 2;
        continue;
      }
      if (source.startsWith(terminator, i)) {
        out.write(terminator);
        i += terminator.length;
        terminator = '';
        continue;
      }
      out.write(ch);
      i++;
      continue;
    }

    if (ch == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch == '/' && next == '*') {
      blockDepth++;
      i += 2;
      continue;
    }
    if (ch == "'" || ch == '"') {
      // `'''` is one delimiter of three, not an empty string followed by a
      // stray quote — so the length has to be decided before the scan starts.
      final String term = source.startsWith(ch * 3, i) ? ch * 3 : ch;
      out.write(term);
      i += term.length;
      terminator = term;
      continue;
    }
    out.write(ch);
    i++;
  }

  if (blockDepth != 0 || terminator.isNotEmpty) {
    throw StateError(
      'the comment scan finished unbalanced (blockDepth=$blockDepth, '
      'terminator="$terminator"). A gate that cannot parse the file must say so '
      'rather than report a clean tree.',
    );
  }
  return out.toString();
}
