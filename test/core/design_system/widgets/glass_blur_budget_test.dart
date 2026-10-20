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
/// The counter-evidence is that the mistake is caught elsewhere, and the reason
/// the gate is still worth running is that it catches the *third*. Per-screen
/// attribution now exists where the screen is: `login_geometry_test.dart` asserts
/// `/login`'s form is `GlassTier.tint`, and Phase 6 owns Home's two.
///
/// So the honest statement is: **this gate bounds the count and refuses the
/// hand-built `BackdropFilter`; it does not tell you which screen spent the budget.
/// A reader must not treat a green run as "every screen used its tint".**
///
/// ## ONE ROOT, ONE EXCLUSION, ONE CEILING — AND THE SECOND BLIND SPOT
///
/// The first version walked `lib/features/` only. That was a **structural blind
/// spot**, and Phase 3 is what opened it: three of the eight prototype blur sites
/// — `Input` (now [EvaTextField]), `StatTile` and `SettingsTile` — became
/// *primitives in `lib/core/design_system/widgets/`*, outside the walk's reach.
/// A planted `StatTile(tier: GlassTier.blur)` kept the gate at 2/2 green while
/// adding a third `saveLayer` over content, so the gate's own doc claim ("fails
/// above two occurrences") was only half-delivered.
///
/// The repair added a **second** root, `lib/core/design_system/widgets/`, and it
/// worked — and **it left the same defect one directory over.** The walk named
/// two directories, and `lib/` has five more, and **two of them were never
/// walked at all**: `lib/core/design_system/effects/` and `lib/app/`. A real
/// `BackdropFilter` planted in either leaves this gate **green**, and `lib/app/`
/// is exactly where Phase 6 put the new navigation chrome — the dock shell,
/// which is the one piece of the app that sits over everything.
///
/// **So the walk is now `lib/` as a whole, and the only exclusion is
/// `glass_surface.dart`.** One root, one exclusion, and the rule is the one the
/// table below states:
///
/// | where | `GlassTier.blur` | direct `BackdropFilter` |
/// | --- | --- | --- |
/// | `lib/features/` | **1** — Home's today's-reading panel | **1** — the redesign's dock, and only the dock |
/// | `lib/core/design_system/`, `glass_surface.dart` **excluded** | **0** | **0** |
/// | everywhere else in `lib/` — `lib/app/`, `lib/core/common/`, `lib/l10n/`, … | **0** | **0** |
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
/// **AND THE SENTENCE THIS SECTION USED TO END WITH WAS TOO STRONG, AND IT IS
/// CORRECTED HERE RATHER THAN LEFT.** It read "no file other than
/// `glass_surface.dart` may mention `GlassTier.blur` at all", which the tree has
/// never obeyed: `lib/features/home/…/verse_of_the_day_card.dart` names the
/// enum, and it is the one budgeted site the table grants it to. The table is
/// the rule; the sentence was shorthand for the design-system row, and a gate
/// whose own doc states a rule the tree breaks is a doc problem as much as a gate
/// problem.
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
///
/// **AND THE EMPTY-WALK RULE NOW HAS THREE BUCKETS TO KEEP.** The walk's root is
/// `lib/` as a whole, so "the walk found something" is no longer enough on its
/// own: a bucket with no `.dart` file in it is a walk that proved nothing *about
/// that bucket*, and a budget over nothing is not a pass. All three are asserted.
///
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

/// The whole of `lib/`. **One root**, and the only exclusion is [_ownerPath].
///
/// The two-directory walk this replaced named `lib/features/` and
/// `lib/core/design_system/widgets/` and left `lib/core/design_system/effects/`
/// and `lib/app/` unwalked — and a real `BackdropFilter` in either left the gate
/// green. See the doc above.
const String _libRoot = 'lib/';

/// The screens, where §13.4's two allowed sites are. A **path prefix**, not a
/// walk root any more: the walk is over `lib/` and this is one of the three
/// buckets it splits into.
const String _featuresPath = 'lib/features/';

/// The primitives, which may pass a tier through but never spend one. A path
/// prefix, and the whole design system — `effects/` and `tokens/` included,
/// which the two-directory walk never reached.
const String _designSystemPath = 'lib/core/design_system/';

/// The one file in the whole of `lib/` that may own a blur site.
///
/// **The exact path, not the file name.** A name-matched exclusion would also
/// forgive a *second* `glass_surface.dart` anywhere else in `lib/`, and "the
/// owner" is one file rather than one name — the same reason the walk's
/// exclusion is the only one it has.
///
/// The owner's sites are its own implementation — the blur decision, and since
/// Phase 5.2 the bloom decision — rather than budget spendings, so they are
/// not counted against anybody.
const String _ownerPath = 'lib/core/design_system/widgets/glass_surface.dart';

/// The three buckets the walk splits `lib/` into.
typedef _Buckets = ({
  List<File> features,
  List<File> designSystem,
  List<File> elsewhere,
});

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

/// The walked files, split into the three buckets the rule talks about.
///
/// `features` — the screens, where §13.4's two allowed sites are.
/// `designSystem` — the primitives, the whole of `lib/core/design_system/`,
/// `effects/` and `tokens/` included.
/// `elsewhere` — **everything else in `lib/`**, and the bucket the two-directory
/// walk never had: `lib/app/`, `lib/core/common/`, `lib/core/domain/`,
/// `lib/l10n/`, `lib/main.dart` and the rest of the tree.
///
/// **The owner is excluded from all three**, and it is the only exclusion.
_Buckets _walk() {
  final List<File> features = <File>[];
  final List<File> designSystem = <File>[];
  final List<File> elsewhere = <File>[];
  for (final File file in _dartFilesUnder(_libRoot)) {
    if (packageRelative(file.uri) == _ownerPath) continue;
    final String path = packageRelative(file.uri);
    if (path.startsWith(_featuresPath)) {
      features.add(file);
    } else if (path.startsWith(_designSystemPath)) {
      designSystem.add(file);
    } else {
      elsewhere.add(file);
    }
  }

  // **Fail closed, per bucket.** The root is `lib/` as a whole now, so "the
  // walk found something" says nothing about any one bucket. An empty bucket is
  // a walk that proved nothing *about that bucket*, and a budget over nothing
  // is not a pass.
  expect(
    features,
    isNotEmpty,
    reason:
        'no .dart file under $_featuresPath. The walk of the whole of '
        '$_libRoot found nothing to spend the budget over, which is not a '
        'clean tree.',
  );
  expect(
    designSystem,
    isNotEmpty,
    reason:
        'no .dart file under $_designSystemPath. The walk of the whole of '
        '$_libRoot found no primitive to rule on, which is not a clean tree.',
  );
  expect(
    elsewhere,
    isNotEmpty,
    reason:
        'no .dart file outside $_featuresPath and $_designSystemPath. The walk '
        'of the whole of $_libRoot found nothing else, which is not a clean '
        'tree.',
  );

  return (features: features, designSystem: designSystem, elsewhere: elsewhere);
}

/// The owner itself — the one file in `lib/` that may build a filter.
List<File> _ownerFiles() =>
    _dartFilesUnder(_libRoot)
        .where((File file) => packageRelative(file.uri) == _ownerPath)
        .toList();

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
    final _Buckets walk = _walk();
    // The screens, where §13.4's two allowed sites are.
    final List<String> features = _blurSites(walk.features);
    // The primitives, which may not spend one at all.
    final List<String> designSystem = _blurSites(walk.designSystem);
    // **And everything else in `lib/`** — the bucket the two-directory walk
    // never had, and the one that let a `BackdropFilter` live in
    // `lib/core/design_system/effects/` and in `lib/app/` while this gate
    // stayed green.
    final List<String> elsewhere = _blurSites(walk.elsewhere);

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
      designSystem,
      isEmpty,
      reason:
          'a design-system primitive cannot spend the budget OR compare against '
          'it: `GlassSurface` is the widget that owns the blur, and its own two '
          'comparisons (the blur decision and, since Phase 5.2, the bloom '
          'decision) are its implementation rather than spendings. Any OTHER file '
          'under `$_designSystemPath` naming `GlassTier.blur` — or building a '
          '`BackdropFilter` by hand — is a primitive deciding for itself:\n'
          '${designSystem.join('\n')}',
    );
    expect(
      elsewhere,
      isEmpty,
      reason:
          'a blur may be spent in `$_featuresPath` and nowhere else, and '
          '`$_designSystemPath` is not the only other place there is. The walk '
          'covers the whole of `$_libRoot` — `lib/app/` included, which is where '
          'Phase 6 put the navigation chrome — so a filter built outside the '
          'features is found rather than merely unwalked:\n'
          '${elsewhere.join('\n')}',
    );
    // The ceiling the rule states, over the whole of `lib/` together. Two
    // separate per-directory bounds would let a third site through by
    // arithmetic, so the global figure is asserted as well as the three that
    // make it up — and it is 2 + 0 + 0 now, because the owner's comparisons
    // are not budget spenders.
    expect(
      features.length + designSystem.length + elsewhere.length,
      lessThanOrEqualTo(2 + 0 + 0),
      reason:
          '§13.4 budgets ONE screen site and the redesign\'s dock is the second. '
          "The design-system occurrences are GlassSurface's own decisions, not "
          'sites, and the two together are the whole of what exists:\n'
          '${[...features, ...designSystem, ...elsewhere].join('\n')}',
    );
  });

  test('a primitive cannot become a blur site', () {
    // The blind spot the design-system walk exists to close, asserted directly
    // so the reason it was widened cannot be quietly forgotten: `StatTile` is a
    // primitive, `tier: GlassTier.blur` is the exact line that would have gone
    // unnoticed, and it is in `lib/core/design_system/widgets/`.
    //
    // **And a hand-built `BackdropFilter` is the same blind spot with the other
    // spelling** — which is how the redesign's dock found it. A primitive that
    // builds its own filter spends the budget without the enum ever appearing.
    //
    // **The design system is the WHOLE of it now**, `effects/` and `tokens/`
    // included. The two-directory walk named `lib/core/design_system/widgets/`
    // and left `lib/core/design_system/effects/` unwalked, and a real
    // `BackdropFilter` planted there left this gate green.
    final List<String> hits = _blurSites(_walk().designSystem);
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
    final _Buckets walk = _walk();
    final List<String> featureDirect = <String>[
      ..._sitesMentioning(walk.features, 'BackdropFilter'),
      ..._sitesMentioning(walk.features, 'ImageFilter.blur'),
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

    // And the owner still builds its own — **named rather than counted**, so a
    // second `BackdropFilter` in a *different* primitive is an offender even
    // though the total would still be two. The owner is also the only
    // exclusion the walk has, so an owner that stopped existing would make
    // every allowance below vacuous: the gate says so rather than passing
    // quietly.
    final List<File> owner = _ownerFiles();
    expect(
      owner,
      hasLength(1),
      reason:
          'the owner of the blur — `$_ownerPath` — is the walk\'s ONLY exclusion, '
          'and it is gone. Every allowance below is stated against it, and a '
          'rule with no owner is a rule with no referent: find the file, or '
          'rewrite the rule rather than passing silently',
    );
    final List<String> ownerDirect = <String>[
      ..._sitesMentioning(owner, 'BackdropFilter'),
      ..._sitesMentioning(owner, 'ImageFilter.blur'),
    ]..sort();
    expect(
      ownerDirect,
      isNotEmpty,
      reason:
          'glass_surface.dart still builds its own BackdropFilter; if this is '
          'empty the widget has been restructured and this allowance needs '
          'rewriting rather than passing silently',
    );

    // **And over the WHOLE of `lib/` — the owner, the features and everything
    // else — a direct filter is only allowed in two places.** This is the
    // widened form of the check that used to read the design system alone:
    // `lib/core/design_system/effects/` and `lib/app/` were outside it, and a
    // `BackdropFilter` in either was invisible to it.
    final List<String> everyDirect = <String>[
      ..._sitesMentioning(_dartFilesUnder(_libRoot), 'BackdropFilter'),
      ..._sitesMentioning(_dartFilesUnder(_libRoot), 'ImageFilter.blur'),
    ]..sort();
    expect(
      everyDirect,
      everyElement(
        anyOf(
          startsWith('$_ownerPath:'),
          startsWith('lib/features/dock/presentation/widgets/'),
        ),
      ),
      reason:
          'only GlassSurface may build a BackdropFilter, and the redesign\'s '
          'dock is the one named exception. Every other file in `$_libRoot` must '
          'go through the tier, which is what carries the budget:\n'
          '${everyDirect.join('\n')}',
    );
  });
}
