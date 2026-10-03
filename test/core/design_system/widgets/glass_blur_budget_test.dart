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
/// enum with "this type exists so that adding one is visible in a diff" — which is
/// true and is also the thing that is not a gate: a reviewer has to notice,
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
/// ### WHAT THIS GATE COUNTS, AND WHAT IT DOES NOT — CORRECTED IN PHASE 5
///
/// An earlier version of this comment said the gate "fails above two occurrences,
/// **names the two allowed sites**, and fails closed on a missing directory". The
/// first two were true; the third half was not, and the gap is worth recording
/// because it was measured.
///
/// **It counts; it does not attribute.** The implementation compares a list length
/// against 2 and prints the offending `file:line` **on failure**. Nothing ties a
/// site to a screen. So the ceiling is satisfied by *any* two blur sites in
/// `lib/features/`, and Phase 5 measured exactly that: changing `/login`'s form from
/// `GlassTier.tint` to `GlassTier.blur` — which §13.4 forbids by name — left this
/// gate **green**, because the count went from 0 to 1 and 1 ≤ 2.
///
/// The counter-evidence is that the mistake is caught elsewhere, and the reason the
/// gate is still worth running is that it catches the *third*. Per-screen
/// attribution now exists where the screen is: `login_geometry_test.dart` asserts
/// `/login`'s form is `GlassTier.tint`, and Phase 6 owns Home's two.
///
/// So the honest statement is: **this gate bounds the count and refuses the
/// hand-built `BackdropFilter`; it does not tell you which screen spent the budget.
/// A reader must not treat a green run as "every screen used its tint".**
///
/// ## TWO DIRECTORIES, TWO ALLOWANCES, ONE CEILING
///
/// The first version walked `lib/features/` only. That was a **structural blind
/// spot**, and Phase 3 is what opened it: three of the eight prototype blur sites
/// — `Input` (now [EvaTextField]), `StatTile` and `SettingsTile` — became
/// *primitives in `lib/core/design_system/widgets/`*, outside the walk's reach.
/// A planted `StatTile(tier: GlassTier.blur)` kept the gate at 2/2 green while
/// adding a third `saveLayer` over content, so the gate's own doc claim ("fails
/// above two occurrences") was only half-delivered.
///
/// So the walk covers both directories, each with its own allowance, and the
/// **global** ceiling is what the rule actually says:
///
/// | directory | `GlassTier.blur` allowance | direct `BackdropFilter` allowance |
/// | --- | --- | --- |
/// | `lib/features/` | 2 — the two allowed sites | 0 |
/// | `lib/core/design_system/widgets/` | 1 — `GlassSurface`'s own tier test | 0 outside `glass_surface.dart` |
///
/// The design-system allowance is 1 and not 0 because `GlassSurface` is the widget
/// that *owns* the blur: `final Widget body = tier == GlassTier.blur ? …` is the
/// one line in the whole tree that decides whether a `BackdropFilter` exists. A
/// primitive cannot spend the budget — it can only pass the tier through — and
/// pinning that at 1 is what keeps a second `GlassTier.blur` comparison inside
/// `lib/core/design_system/widgets/` from being possible.
///
/// ## FAIL-CLOSED, DELIBERATELY
///
/// `AGENT_CONTEXT` §7, "a gate that cannot fail is worse than no gate":
///
/// - a scanned directory missing → **fail**, naming the path. A phase that has not
///   created it yet is not a reason to pass.
/// - a file that cannot be read → **fail**, naming the file. A permissions error
///   must not read as "no violations found".
/// - an empty walk → **fail**. A directory with no `.dart` files under it is a walk
///   that found nothing, and a count of zero over nothing is not a pass.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// The screens, where §13.4's two allowed sites will be.
const String _features = 'lib/features/';

/// The primitives, which may pass a tier through but never spend one.
const String _widgets = 'lib/core/design_system/widgets/';

/// Every `.dart` file under [root], failing closed.
List<File> _dartFilesUnder(String root) {
  final Directory dir = Directory.fromUri(packageRoot.uri.resolve(root));
  expect(
    dir.existsSync(),
    isTrue,
    reason:
        '$root does not exist. The gate cannot run, so it does not pass — a '
        'missing target is reported, never assumed clean.',
  );

  final List<File> files = <File>[];
  try {
    files.addAll(<File>[
      for (final FileSystemEntity entity in dir.listSync(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]);
  } on FileSystemException catch (error) {
    fail('$root could not be walked: ${error.message}');
  }
  expect(
    files,
    isNotEmpty,
    reason:
        'the walk found no .dart file under $root. That is a walk that proved '
        'nothing, not a clean tree.',
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
  test('at most two sites blur anywhere — §13.4 spends two of eight', () {
    final List<String> features = _sitesMentioning(
      _dartFilesUnder(_features),
      'GlassTier.blur',
    );
    final List<String> widgets = _sitesMentioning(
      _dartFilesUnder(_widgets),
      'GlassTier.blur',
    );

    expect(
      features,
      hasLength(lessThanOrEqualTo(2)),
      reason:
          "§13.4 budgets two blur sites across the six screens — Home's "
          "today's-reading panel and Home's top bar — and lists eight prototype "
          'sites that would each be a per-frame saveLayer. The over-budget '
          'sites:\n${features.join('\n')}',
    );
    expect(
      widgets,
      hasLength(lessThanOrEqualTo(1)),
      reason:
          'a design-system primitive cannot spend the budget: `GlassSurface` owns '
          'the blur and every primitive passes a `tier` through. One occurrence is '
          "GlassSurface's own `tier == GlassTier.blur` test; a second means a "
          'primitive is deciding for itself:\n${widgets.join('\n')}',
    );
    // The ceiling the rule states, over both directories together. Two separate
    // per-directory bounds would let a fourth site through by arithmetic — 2 in
    // features plus 1 in the design system is 3 — so the global figure is asserted
    // as well as the two that make it up.
    expect(
      features.length + widgets.length,
      lessThanOrEqualTo(2 + 1),
      reason:
          '§13.4 budgets two screen sites. The one design-system occurrence is '
          "GlassSurface's own decision, not a site, and the two together are the "
          'whole of what exists:\n${[...features, ...widgets].join('\n')}',
    );
  });

  test('a primitive cannot become a blur site', () {
    // The blind spot the two-directory walk exists to close, asserted directly so
    // the reason it was widened cannot be quietly forgotten: `StatTile` is a
    // primitive, `tier: GlassTier.blur` is the exact line that would have gone
    // unnoticed, and it is in `lib/core/design_system/widgets/`.
    final List<String> hits = _sitesMentioning(
      _dartFilesUnder(_widgets),
      'tier: GlassTier.blur',
    );
    expect(
      hits,
      isEmpty,
      reason:
          '§13.4 — a `GlassTier.blur` in the design system is a per-frame '
          "saveLayer with no screen behind it to justify the budget. Only Home's "
          "today's-reading panel and Home's top bar may blur:\n${hits.join('\n')}",
    );
  });

  test('and the budget is not satisfied by moving the blur out of the enum', () {
    // The obvious way to defeat the scan above is to stop naming the enum and
    // build a `BackdropFilter` directly. `GlassSurface` owns the widget, so a
    // feature that needs a blur goes through the enum; this asserts the second
    // spelling is absent too, so the scan has to be honoured rather than worked
    // around. A hand-built `BackdropFilter` is the same per-frame `saveLayer`
    // with no budget attached to it.
    final List<String> featureDirect = <String>[
      ..._sitesMentioning(_dartFilesUnder(_features), 'BackdropFilter'),
      ..._sitesMentioning(_dartFilesUnder(_features), 'ImageFilter.blur'),
    ]..sort();
    expect(
      featureDirect,
      isEmpty,
      reason:
          'a feature must reach the blur through GlassTier.blur, which is what '
          'the budget above counts:\n${featureDirect.join('\n')}',
    );

    // And in the design system, the one `BackdropFilter` in the tree is inside
    // `glass_surface.dart` — the widget that owns it. Named rather than counted,
    // so a second `BackdropFilter` in a *different* primitive is an offender even
    // though the total would still be two.
    final List<String> widgetDirect = <String>[
      ..._sitesMentioning(_dartFilesUnder(_widgets), 'BackdropFilter'),
      ..._sitesMentioning(_dartFilesUnder(_widgets), 'ImageFilter.blur'),
    ]..sort();
    expect(
      widgetDirect,
      isNotEmpty,
      reason:
          'glass_surface.dart still builds its own BackdropFilter; if this is '
          'empty the widget has been restructured and this allowance needs '
          'rewriting rather than passing silently',
    );
    expect(
      widgetDirect,
      everyElement(
        startsWith('lib/core/design_system/widgets/glass_surface.dart:'),
      ),
      reason:
          'only GlassSurface may build a BackdropFilter. Every other primitive '
          'must go through the tier, which is what carries the budget:\n'
          '${widgetDirect.join('\n')}',
    );
  });
}
