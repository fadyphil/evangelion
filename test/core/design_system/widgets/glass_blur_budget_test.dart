/// §13.4's blur budget, enforced rather than documented.
///
/// `09-quality-gates.md` §13.4 counts **eight** `backdrop-filter: blur(Npx)` sites
/// across the six shipped screens and rules that only **one** of them may
/// actually blur. Every one of the eight is a `saveLayer` plus a full read-back
/// of everything painted behind it, **per frame**.
///
/// ## THE CEILING FOR `lib/features/` IS **TWO**, AND THE SECOND IS THE DOCK
///
/// §13 rule 4's per-screen line said "`/`: `.blur` on the today's-reading panel
/// **and the top bar**", and this file's doc repeated it. **Both were wrong.**
/// `ds.tsx:499-530` is `TopBar`, and it contains **no `backdropFilter` at all** —
/// the prototype's top bar is a transparent `div` over the animated background, and
/// that is deliberate.
///
/// So the shipped budget on `/` is one site, and the ceiling was 1 — which is
/// what caught a second blur with nothing red. **Phase 6 of the Lumen
/// redesign raised it to two, and the second site is named: the redesign's own
/// dock** (`eva/redesign.html:210` — `backdrop-filter:blur(22px)`).
///
/// **The dock is ONE `BackdropFilter` for three tabs**, because the shell that
/// hosts them is one widget — not three, which is what a per-tab dock would
/// have cost.
///
/// The inventory it is derived from did **not** change: eight prototype sites, of
/// which six survive in `ds.tsx` after `PassageCard` is cut with the library, plus
/// two inline (the Login form and Home's panel) = 8.
///
/// ## THE COUNT IS OF **SITES**, NOT OF LINES, AND THAT IS NOT A DETAIL
///
/// A blur site has **two spellings** — `GlassTier.blur`, the design system's own
/// way of asking for one, and a hand-built `BackdropFilter` — and the redesign's
/// dock is the second, because `GlassSurface` paints a *panel* and the dock is a
/// full-width bar. A count that read only the enum would have been **blind to
/// it**, and a count of *lines* would have read the dock's one site as two
/// (`BackdropFilter(` on one line, `ImageFilter.blur(` on the next) and charged
/// the budget for a blur that does not exist.
///
/// So the count is of sites, of both spellings, and **the dock's site is charged
/// to the budget like any other** — the exception is about the *shape*, not
/// about escaping the count.
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
/// | the **dock** — the redesign's five-slot bar | the prototype's own `backdrop-filter:blur(22px)` (`:210`), and **one** filter for three tabs |
///
/// The first is `GlassSurface(tier: GlassTier.blur)`. The second builds its own
/// filter, because `GlassSurface` paints a *panel* and the dock is a bar — see
/// the third test below for the exception and what it does **not** buy. The
/// count is 2 and the ceiling is 2, so the third is red — which is the point.
///
/// Everything else is `GlassTier.tint`: a translucent fill, a hairline rim and the
/// ambient shadow, with no `saveLayer` at all.
///
/// **The top bar used to be in that table.** It is not, and `GlassSurface`'s doc
/// carries the correction at length.
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
/// | `lib/features/` | **1** — Home's today's-reading panel | 0 |
/// | `lib/core/design_system/widgets/`, `glass_surface.dart` **excluded** | **0** | 0 outside `glass_surface.dart` |
///
/// The design-system row **excludes the owner**, and Phase 5.2 is what moved it
/// from "1, counted" to "0, elsewhere". While `GlassSurface` decided the blur in
/// exactly one line, a count of 1 for the whole directory was a working proxy for
/// "no primitive decides". ADR-0022 gave the one budgeted site its wash too —
/// `redesign.html:250` gives the home card `backdrop-filter: blur(12px)`,
/// `.bloom` **and** `.hor` together, so `GlassTier.blur` now paints the wash and
/// the seam as well — and the owner legitimately grew a second internal
/// comparison (`bloomed = tier == GlassTier.bloom || tier == GlassTier.blur`).
/// Counting the directory would put that gate at 2 and read as a violation, when
/// both sites are the same file deciding for itself.
///
/// So the rule is now stated in the only form that survives the owner growing:
/// **no file other than `glass_surface.dart` may mention `GlassTier.blur` at
/// all** — a primitive cannot spend the budget, and cannot even compare against
/// it — while the global ceiling drops to match, because the owner's sites are
/// its own implementation and not budget spenders.
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
/// ## THE **STRINGS** WERE WRONG TOO, AND A STRING IS WHAT A DEVELOPER READS
///
/// Phase 6's correction reached the assertion (`<= 1`) and the first failure
/// message, and missed this file's test *name* and this second failure message —
/// both of which still said "two sites" and "Home's top bar may blur".
///
/// That is not a naming nit, because **the message is the artifact a developer
/// reads when they trip the gate.** The gate was tripped deliberately during the
/// review: `/login`'s form was moved back to `GlassTier.blur` to read the output,
/// and the output was half-corrected. A developer who had planted a blur in a
/// design-system primitive would have been told by this line that the top bar was
/// an allowed second site — and gone looking for a precedent that does not exist.
///
/// So: **a correction to a gate has to reach every string the gate can print**, not
/// only the number in its `expect`. The name is listed here for the same reason —
/// a test named "at most two" that asserts "at most one" is the kind of mismatch a
/// reader trusts the name over.
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

/// Every executable line in [files] mentioning any of [markers], as
/// `file:line: text`.
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

/// Every **blur site** in [files], counted as sites and not as lines.
///
/// A site is a `GlassTier.blur` — the design system's own way of asking for a
/// blur — **or** a `BackdropFilter(`, which is the widget that spends it. The
/// count is of **sites**, and that is not a detail: the redesign's dock spells
/// its one site over two lines (`BackdropFilter(` on one, `ImageFilter.blur(`
/// on the next), and a count of *lines* would read that one site as two and
/// charge the budget for a blur that does not exist.
///
/// **The count is of occurrences, not of lines**, and that is the second half
/// of the same point: a line that mentions the enum twice is still one line
/// but could be two sites, and the budget is about sites.
List<String> _blurSites(List<File> files) {
  final List<String> hits = <String>[];
  for (final File file in files) {
    final List<String> lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final String trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
      final int onThisLine = _sitePattern.allMatches(lines[i]).length;
      for (int n = 0; n < onThisLine; n++) {
        hits.add('${packageRelative(file.uri)}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

/// The two spellings of "this line spends a blur".
///
/// `ImageFilter.blur` alone is **not** one: a filter that is built and never
/// applied costs nothing, and the redesign's dock's `ImageFilter.blur(` sits
/// under the `BackdropFilter(` that applies it.
final RegExp _sitePattern = RegExp(r'GlassTier\.blur\b|BackdropFilter\s*\(');

void main() {
  test('at most TWO screen sites blur — §13.4 spends one of eight, and the '
      'redesign\'s dock is the second', () {
    final List<String> features = _blurSites(_dartFilesUnder(_features));
    // **The owner is excluded, and the rest of the directory is at ZERO.** While
    // GlassSurface decided the blur in one line, a directory count of 1 was a
    // proxy for "no primitive decides"; Phase 5.2 gave the budgeted site its wash
    // too (`redesign.html:250` — blur, `.bloom` and `.hor` together), so the
    // owner legitimately holds two internal comparisons and the proxy broke.
    // Excluding `glass_surface.dart` and requiring zero elsewhere is *stronger*
    // for every primitive than the count it replaces.
    final List<String> widgets = _blurSites(
      _dartFilesUnder(_widgets)
          .where((File file) => !file.uri.path.endsWith('glass_surface.dart'))
          .toList(),
    );

    expect(
      features,
      hasLength(lessThanOrEqualTo(2)),
      reason:
          "§13.4 budgets ONE blur site across the six screens — Home's "
          "today's-reading panel — and lists eight prototype sites that would "
          'each be a per-frame saveLayer. The top bar is NOT the second: '
          '`ds.tsx:499-530` has no `backdropFilter` in it. **Phase 6 added the '
          "second**: the redesign's own dock blurs (`eva/redesign.html:210` — "
          '`backdrop-filter:blur(22px)`), and it is **one** `BackdropFilter` for '
          'three tabs rather than three. The over-budget sites:\n'
          '${features.join('\n')}',
    );
    expect(
      widgets,
      isEmpty,
      reason:
          'a design-system primitive cannot spend the budget OR compare against '
          'it: `GlassSurface` is the widget that owns the blur, and its own two '
          'comparisons (the blur decision and, since Phase 5.2, the bloom '
          'decision) are its implementation rather than spendings. Any OTHER file '
          'under `lib/core/design_system/widgets/` naming `GlassTier.blur` — or '
          'building a `BackdropFilter` by hand — is a primitive deciding for '
          'itself:\n${widgets.join('\n')}',
    );
    // The ceiling the rule states, over both directories together. Two separate
    // per-directory bounds would let a third site through by arithmetic, so the
    // global figure is asserted as well as the two that make it up — and it is
    // 2 + 0 now, because the owner's comparisons are not budget spenders.
    expect(
      features.length + widgets.length,
      lessThanOrEqualTo(2 + 0),
      reason:
          '§13.4 budgets ONE screen site and the redesign\'s dock is the second. '
          "The design-system occurrences are GlassSurface's own decisions, not "
          'sites, and the two together are the whole of what exists:\n'
          '${[...features, ...widgets].join('\n')}',
    );
  });

  test('a primitive cannot become a blur site', () {
    // The blind spot the two-directory walk exists to close, asserted directly so
    // the reason it was widened cannot be quietly forgotten: `StatTile` is a
    // primitive, `tier: GlassTier.blur` is the exact line that would have gone
    // unnoticed, and it is in `lib/core/design_system/widgets/`.
    //
    // **And a hand-built `BackdropFilter` is the same blind spot with the other
    // spelling** — which is how the redesign's dock found it. A primitive that
    // builds its own filter spends the budget without the enum ever appearing.
    final List<String> hits = _blurSites(
      _dartFilesUnder(_widgets)
          .where((File file) => !file.uri.path.endsWith('glass_surface.dart'))
          .toList(),
    );
    expect(
      hits,
      isEmpty,
      reason:
          '§13.4 — a `GlassTier.blur` in the design system is a per-frame '
          'saveLayer with no screen behind it to justify the budget, and a '
          'hand-built `BackdropFilter` is the same spend with a different '
          "spelling. Only Home's today's-reading panel and the redesign's dock "
          'may blur — the top bar is NOT a second one, because `ds.tsx:499-530` '
          "has no `backdropFilter` in it:\n${hits.join('\n')}",
    );
  });

  test('and the budget is not satisfied by moving the blur out of the enum', () {
    // The obvious way to defeat the scan above is to stop naming the enum and
    // build a `BackdropFilter` directly. `GlassSurface` owns the widget, so a
    // feature that needs a blur goes through the enum; this asserts the second
    // spelling is accounted for too, so the scan has to be honoured rather than
    // worked around. A hand-built `BackdropFilter` is the same per-frame
    // `saveLayer` with no budget attached to it.
    //
    // **AND THE REDESIGN'S DOCK IS THE ONE NAMED EXCEPTION — and the exception
    // is about the SHAPE, not about the budget.** `GlassSurface` paints a
    // *panel*: a fill, a rim and a shadow, with one radius on all four corners.
    // The dock is a full-width **bar** with its own alpha (0.86 dark, 0.74
    // light), a hairline on its **top** edge only, a radius on its **top** two
    // corners only, and the prototype's own 22px blur radius — none of which
    // `GlassSurface` can express. So the dock builds its own filter.
    //
    // **What the exception does NOT do is escape the budget.** The count above
    // is of **sites** and it counts *both* spellings, so the dock's one site is
    // charged to the budget like any other, and a third site is still red. The
    // rule this test states is therefore the one that is actually true: **every
    // blur a feature spends is visible to the budget, and exactly one feature
    // spends one outside the enum.**
    final List<String> featureDirect = <String>[
      ..._sitesMentioning(_dartFilesUnder(_features), 'BackdropFilter'),
      ..._sitesMentioning(_dartFilesUnder(_features), 'ImageFilter.blur'),
    ]..sort();
    expect(
      featureDirect,
      isNotEmpty,
      reason:
          "the redesign's dock builds its own filter — `GlassSurface` paints a "
          'panel and the dock is a full-width bar. If this is empty the dock has '
          'been restructured and this allowance needs rewriting rather than '
          'passing silently',
    );
    expect(
      featureDirect.every(
        (String hit) =>
            hit.startsWith('lib/features/dock/presentation/widgets/'),
      ),
      isTrue,
      reason:
          '**exactly one** feature may build a direct filter, and it is the '
          "redesign's dock. Every other feature must reach the blur through "
          'GlassTier.blur, which is what the budget above counts:\n'
          '${featureDirect.join('\n')}',
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
