import 'dart:io';

import 'project_import_graph.dart';

/// The classes `freezed` owns, discovered by **scanning `lib/`** rather than by
/// being listed here.
///
/// ## WHY IT IS DISCOVERED AND NOT DECLARED
///
/// Two gates in this suite need the same fact — "which classes did the migration
/// convert" — and both need it to stay honest as `lib/` moves:
///
/// * `freezed_structural_equality_test.dart` asserts structural equality over the
///   converted set, so a class converted and not listed there is a hole in that
///   gate;
/// * `no_identical_on_converted_types_test.dart` claims **no test relies on
///   `identical()` on a converted type**, and a converted type missing from this
///   list would be a type the claim silently does not cover.
///
/// A hand-written list would make both failures invisible, which is the failure
/// mode AGENT_CONTEXT §7 calls "a gate that cannot fail is worse than no gate".
/// So the list is derived: **a class is converted when its declaration carries
/// `@freezed` or `@Freezed(…)`**, and the two classes that must NOT be in it —
/// `Failure` and `Result`'s arms — carry neither.
///
/// ## WHY GENERATED PARTS ARE EXCLUDED
///
/// `*.freezed.dart` files declare `mixin _$X` and `class _X`, which are the
/// generator's own scaffolding rather than a converted type, and they are
/// regenerated on every `build_runner` run — including a mutation experiment that
/// deletes one by hand. Including them would make this list change under a test
/// that is supposed to describe `lib/`.
///
/// ## THE ANNOTATION IS MATCHED **PER DECLARATION**, NOT PER FILE
///
/// `@freezed` sits on the line above a class, and several files hold several
/// classes (`auth_bloc.dart` holds one base and six events). A per-file match would
/// report every class in a file as converted, which would put the three sealed
/// bases' *neighbours* into the gate's scope — and `Failure`, `Success` and
/// `FailureResult` all live in files that also hold other declarations.
Set<String> freezedTypeNamesInLib({String root = 'lib'}) {
  final Set<String> found = <String>{};

  for (final File file in _dartSourcesIn(root)) {
    if (file.path.endsWith('.freezed.dart')) continue;
    final String text = withoutDartComments(file.readAsStringSync());
    final List<RegExpMatch> declarations = _classDeclaration
        .allMatches(text)
        .toList();

    for (int i = 0; i < declarations.length; i++) {
      final RegExpMatch declaration = declarations[i];
      // The annotation block immediately above the declaration, back to the
      // previous declaration so one file's second class cannot inherit the first
      // one's `@freezed`.
      final int previousEnd = i == 0 ? 0 : declarations[i - 1].start;
      final String block = text.substring(previousEnd, declaration.start);
      if (!_freezedAnnotation.hasMatch(block)) continue;
      found.add(declaration.group(1)!);
    }
  }

  return found;
}

final RegExp _freezedAnnotation = RegExp(r'@freezed\b|@Freezed\s*\(');

final RegExp _classDeclaration = RegExp(
  r'^\s*(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*'
  r'class\s+(\w+)',
  multiLine: true,
);

/// Every `.dart` file under [root], recursively, in a stable order.
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
