import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/project_import_graph.dart';

/// ## WHY A GATE OVER THE GOLDENS THEMSELVES
///
/// A golden test's name claims a property its body may not deliver. Two of Phase
/// 3's said "a golden per theme" while capturing **byte-identical** files:
///
/// | pair | md5 | bytes |
/// | --- | --- | --- |
/// | `eva_chip_filter_{dark,light}.png` | `a69ebc37…` | 3001 each |
/// | `text_link_{dark,light}.png` | `e0339a1e…` | 2872 each |
///
/// A full sweep of all 84 goldens found those two and nothing else — so this is
/// not a widespread pattern, it is exactly two mistakes, and both are invisible
/// from inside either test:
///
/// - `text_link` passed `color: Color(0xFFE8A33D)`, a literal that happens to be
///   the **dark** palette's `ember`. `matchesGoldenFile` compares bytes and saw
///   two correct captures of one hard-coded colour.
/// - `eva_chip_filter` passed an unselected `filter` chip with a sticker colour,
///   and an unselected `filter` chip reads **no** `colors.*` at all while the
///   sticker palette is a *static* map shared by both themes. So the widget is
///   genuinely theme-invariant and no amount of re-pumping would have separated
///   the two files.
///
/// (Phase 2's byte-identical light goldens were a third instance and a different
/// cause — `MaterialApp`'s `AnimatedTheme` lerping a theme change inside one test
/// body. `streak_flame_test.dart` records that mechanism and why the theme loop is
/// now outside `testWidgets`. The loop was never the problem here: it was
/// correctly outside both bodies.)
///
/// A duplicate pair is not merely a wasted assertion. It is an assertion that
/// **cannot fail**: whatever the theme, the file is compared against a copy of
/// itself, so a widget that ignored the palette entirely, or a theme that stopped
/// changing, would both pass. The name is the whole claim and the name is false.
///
/// ## WHAT THIS DOES AND DOES NOT BUY
///
/// It buys exactly one thing: a *pair* whose two files are identical is a failure
/// with a reason that says why. Everything else a golden does — pinning the
/// resolved style, catching a widget that ignores its own parameters — is
/// untouched, and those two pairs were not worthless: `TextLink` ignoring `color`
/// or `EvaChip` ignoring `sticker` would still have turned them red. What they
/// could never do is catch a **theming** regression, which is the only thing the
/// name claimed.
///
/// It cannot tell a genuinely theme-invariant widget from a mistake, and it does
/// not try: the fix for a widget that really is theme-invariant is to stop
/// capturing it twice under a per-theme name, and that is a judgement this gate
/// does not make for you.
void main() {
  test('no `*_dark.png` golden is byte-identical to its `*_light.png` sibling', () {
    final List<Directory> roots = <Directory>[
      for (final String relative in const <String>[
        'test/core/design_system/widgets/goldens',
        'test/core/design_system/effects/goldens',
      ])
        Directory.fromUri(packageRoot.uri.resolve(relative)),
    ];

    final List<File> images = <File>[];
    for (final Directory dir in roots) {
      expect(
        dir.existsSync(),
        isTrue,
        reason:
            '$dir does not exist. The gate cannot run, so it does not pass — a '
            'missing directory is reported, never assumed clean.',
      );
      try {
        images.addAll(<File>[
          for (final FileSystemEntity entity in dir.listSync(
            recursive: true,
            followLinks: false,
          ))
            if (entity is File && entity.path.endsWith('.png')) entity,
        ]);
      } on FileSystemException catch (error) {
        fail('$dir could not be walked: ${error.message}');
      }
    }

    expect(
      images,
      isNotEmpty,
      reason:
          'the walk found no .png under either goldens directory. A count of '
          'zero over nothing is not a pass.',
    );

    // Keyed by directory **plus** stem. The stem alone is not unique —
    // `neural_background_*` exists in one directory and the widget goldens in
    // another — and an earlier version of this loop keyed on the whole
    // package-relative path, which then made `_sibling` look for
    // `…/goldens/test/core/…/goldens/…_light.png` and find nothing. The gate went
    // green over the two duplicates it exists to catch, which is §7's failure in
    // miniature: the check ran, matched nothing, and said nothing about it.
    final Map<String, List<File>> darkPairs = <String, List<File>>{};
    for (final File image in images) {
      final String path = packageRelative(image.uri);
      if (!path.endsWith('_dark.png')) continue;
      final String stem = path.substring(0, path.length - '_dark.png'.length);
      darkPairs.putIfAbsent(stem, () => <File>[]).add(image);
    }
    // The control for the loop above: a walk that found no dark golden would find
    // no duplicates and pass, so the pairs are counted before they are judged.
    expect(
      darkPairs,
      isNotEmpty,
      reason:
          'there are per-theme golden pairs to compare — if this is zero the '
          'walk is broken',
    );

    final List<String> duplicates = <String>[];
    final List<String> unpaired = <String>[];
    for (final MapEntry<String, List<File>> pair in darkPairs.entries) {
      final File? light = _lightSiblingOf(pair.value.single);
      if (light == null) {
        unpaired.add(packageRelative(pair.value.single.uri));
        continue;
      }
      if (!_identicalBytes(pair.value.single, light)) continue;
      duplicates.add(
        '${packageRelative(pair.value.single.uri)} and '
        '${packageRelative(light.uri)} are byte-identical '
        '(${pair.value.single.lengthSync()} bytes each)',
      );
    }

    // Every `*_dark.png` in the tree has a `*_light.png` sibling today, and the
    // check is one line — so it is here rather than left implicit. A dark capture
    // with no light sibling is the same defect wearing a different hat: a
    // per-theme golden where one of the two themes was never captured. Written
    // after the duplicate scan so the failure a reader sees first is the one the
    // gate exists for.
    expect(
      unpaired,
      isEmpty,
      reason:
          'these goldens are named per theme but have no `_light.png` sibling, so '
          'half of what the name claims was never captured:\n'
          '${unpaired.join('\n')}',
    );

    expect(
      duplicates,
      isEmpty,
      reason:
          'a `*_dark.png` / `*_light.png` pair that is byte-identical cannot '
          'detect a theming regression, which is the only thing its test name '
          'claims. Either the widget resolved to the same thing in both themes — '
          'a hard-coded colour literal, or a style that reads no `colors.*` at '
          'all — or the two captures were taken before the theme change settled. '
          'Give the golden a theme-derived style, or stop capturing it twice '
          'under a per-theme name:\n${duplicates.join('\n')}',
    );
  });

  test('and the walk is not vacuous over the whole set', () {
    // The two goldens this gate exists for are gone, which means the pair count
    // has to come from the *other* pairs instead — so the number is stated rather
    // than left implicit. It is a count a reviewer can compare with
    // `find test -name '*_dark.png' | wc -l`, which is the only way to tell a
    // gate that is working from one that has stopped looking.
    int darkCount = 0;
    for (final String relative in const <String>[
      'test/core/design_system/widgets/goldens',
      'test/core/design_system/effects/goldens',
    ]) {
      final Directory dir = Directory.fromUri(
        packageRoot.uri.resolve(relative),
      );
      darkCount += dir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((File f) => f.path.endsWith('_dark.png'))
          .length;
    }
    expect(darkCount, greaterThan(10));
  });
}

/// The `*_light.png` beside [dark]'s `*_dark.png`, or `null` when there is none.
///
/// The suffix is swapped **in place** on the package-relative path. An earlier
/// version took a bare stem and re-prefixed a goldens root, which produced
/// `…/goldens/test/core/…/goldens/foo_light.png` and found nothing — so the gate
/// reported zero duplicates over the two pairs it was written for. §7's rule is
/// about gates that cannot fail; this one failed *silently*, which is the same
/// defect wearing a green hat.
File? _lightSiblingOf(File dark) {
  final String path = packageRelative(dark.uri);
  final File sibling = File.fromUri(
    packageRoot.uri.resolve(
      '${path.substring(0, path.length - '_dark.png'.length)}_light.png',
    ),
  );
  return sibling.existsSync() ? sibling : null;
}

/// Whether two files hold the same bytes.
///
/// Byte-for-byte, not "looks the same": `matchesGoldenFile` compares bytes, so a
/// gate that compared anything looser would disagree with the thing it is gating.
bool _identicalBytes(File a, File b) =>
    a.readAsBytesSync().toString() == b.readAsBytesSync().toString();
