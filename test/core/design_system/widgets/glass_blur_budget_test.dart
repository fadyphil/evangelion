import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// §13.4's blur budget, enforced rather than documented.
///
/// `09-quality-gates.md` §13.4 counts **eight** `backdrop-filter: blur(Npx)` sites
/// across the six shipped screens and rules that only **two** of them may
/// actually blur. Every one of the eight is a `saveLayer` plus a full read-back
/// of everything painted behind it, **per frame**.
///
/// ## WHY A SOURCE SCAN AND NOT A RUNTIME COUNT
///
/// The obvious alternative — count `BackdropFilter`s in the tree — cannot work,
/// and the reason is worth stating because it is easy to assume otherwise. Only
/// the screens that exist are pumped by this suite, and Phase 3 is the phase that
/// writes the six real screens. A runtime count over today's stubs is zero, and
/// it stays zero however many `.blur` sites Phase 3 adds, because the sites are
/// source, not state.
///
/// A diff is review, not a gate either. `GlassTier`'s own doc used to justify the
/// enum with "this type exists so that adding one is visible in a diff" — which
/// is true and is also the thing that is not a gate: a reviewer has to notice,
/// count, and remember the number. This walks the files instead.
///
/// ## THE TWO ALLOWED SITES
///
/// | site | why |
/// | --- | --- |
/// | `/` (Home) — today's-reading panel | it sits directly over the animated background and is expected to let it show through |
/// | `/` (Home) — the top bar | same, and the only other surface that overlays the orbs |
///
/// Both are Home, both are `GlassSurface(tier: GlassTier.blur)`, and neither
/// exists yet. The budget is therefore 2 while the count is 0 — which is the
/// point: Phase 3 spends two, and the third is red.
///
/// Everything else is `GlassTier.tint`: a translucent fill, a hairline rim and
/// the ambient shadow, with no `saveLayer` at all.
///
/// ## FAIL-CLOSED, DELIBERATELY
///
/// `AGENT_CONTEXT` §7, "a gate that cannot fail is worse than no gate":
///
/// - `lib/features/` missing → **fail**, naming the path. A phase that has not
///   created it yet is not a reason to pass.
/// - a file that cannot be read → **fail**, naming the file. A permissions error
///   must not read as "no violations found".
/// - an empty walk → **fail**. `lib/features/` with no `.dart` files under it is
///   a walk that found nothing, and a count of zero over nothing is not a pass.
/// Every `.dart` file under `lib/features/`, failing closed.
///
/// The one walk both tests use, so there is a single place where "the scan could
/// not run" is turned into a failure rather than a pass.
List<File> _featureDartFiles() {
  final Directory features = Directory.fromUri(
    packageRoot.uri.resolve('lib/features/'),
  );
  expect(
    features.existsSync(),
    isTrue,
    reason:
        'lib/features/ does not exist. The gate cannot run, so it does not '
        'pass — a missing target is reported, never assumed clean.',
  );

  final List<File> files = <File>[];
  try {
    files.addAll(<File>[
      for (final FileSystemEntity entity in features.listSync(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]);
  } on FileSystemException catch (error) {
    fail('lib/features/ could not be walked: ${error.message}');
  }
  expect(
    files,
    isNotEmpty,
    reason:
        'the walk found no .dart file under lib/features/. That is a walk that '
        'proved nothing, not a clean tree.',
  );
  return files;
}

/// Every executable line in [files] mentioning [marker], as `file:line: text`.
///
/// Comments are skipped: a doc comment naming the enum is where a reader learns
/// the budget, not a call site spending it. `readAsLinesSync` throws on an
/// unreadable file and that throw fails the test naming it.
List<String> _sitesMentioning(List<File> files, String marker) {
  final List<String> hits = <String>[];
  for (final File file in files) {
    final List<String> lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final String trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
      if (lines[i].contains(marker)) {
        hits.add('${packageRelative(file.uri)}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

void main() {
  test('at most two features blur — §13.4 spends two of eight', () {
    final List<File> files = _featureDartFiles();
    final List<String> hits = _sitesMentioning(files, 'GlassTier.blur');

    expect(
      hits,
      hasLength(lessThanOrEqualTo(2)),
      reason:
          '§13.4 budgets two blur sites across the six screens — Home\'s '
          "today's-reading panel and Home's top bar — and lists eight prototype "
          'sites that would each be a per-frame saveLayer. The over-budget '
          'sites are:\n${hits.join('\n')}',
    );
  });

  test('and the budget is not satisfied by moving the blur out of the enum', () {
    // The obvious way to defeat the scan above is to stop naming the enum and
    // build a `BackdropFilter` directly. `GlassSurface` owns the widget, so a
    // feature that needs a blur goes through the enum; this asserts the second
    // spelling is absent too, so the scan has to be honoured rather than worked
    // around. A hand-built `BackdropFilter` is the same per-frame `saveLayer`
    // with no budget attached to it.
    final List<File> files = _featureDartFiles();
    final List<String> direct = <String>[
      ..._sitesMentioning(files, 'BackdropFilter'),
      ..._sitesMentioning(files, 'ImageFilter.blur'),
    ]..sort();
    expect(
      direct,
      isEmpty,
      reason:
          'a feature must reach the blur through GlassTier.blur, which is what '
          'the budget above counts:\n${direct.join('\n')}',
    );
  });
}
