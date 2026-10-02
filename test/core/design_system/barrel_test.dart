import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_import_graph.dart';

/// The package root, found by walking up from the working directory until a
/// `pubspec.yaml` appears.
///
/// NOT from `Platform.script`. Under `flutter test` the script is a generated
/// bootstrap file in a temporary directory, so counting parents off it lands
/// somewhere else entirely — the first draft of this test looked for the design
/// system under `/home`, which is a memorable way to notice.
///
/// `dart:io` in a test is the only way to answer "does the barrel cover every
/// file" without writing a code generator, and Phase 0's suite already relies on
/// the filesystem being honest — see the comment in `app_test.dart` about the
/// composition-root import-graph walk.
Directory get _root => packageRoot;

String get _barrelSource =>
    File.fromUri(_root.uri.resolve('lib/core/design_system/barrel.dart'))
        .readAsStringSync();

/// Every URI the barrel re-exports, in source order.
///
/// ## WHY THE PATTERN STOPS AT THE QUOTE, NOT THE SEMICOLON
///
/// This used to be `^export '([^']+)';$`, requiring the line to end in `';`. A
/// `show`/`hide` combinator puts text between the URI and the semicolon:
///
/// ```dart
/// export 'package:flutter/material.dart' show ThemeData;
/// ```
///
/// That line matched nothing at all, so it was invisible to BOTH checks built on
/// this list — "one export per file on disk" never saw the extra entry, and
/// "re-exports nothing from a feature, a domain, or the framework" never saw the
/// framework. The confirmed result of appending exactly that line:
///
/// ```
/// flutter test          → 5 barrel tests pass
/// dart analyze          → No issues found!      (the export is legal Dart)
/// tool/verify_purity.sh → PASSED, all gates exercised and clean  (Gate 1 never
///                          scans this file)
/// ```
///
/// Three checks, three green ticks, three different things not being looked at.
/// The `directivePattern` in `test/support/project_import_graph.dart` had it
/// right — `([^'"]+)\1` terminates at the closing quote — and the two patterns
/// disagreed, which is the shape of this bug: one copy of a parser, two
/// definitions of "a directive".
List<String> get _exportedUris => <String>[
  for (final RegExpMatch match in RegExp(
    r"^export\s+'([^']+)'",
    multiLine: true,
  ).allMatches(_barrelSource))
    match.group(1)!,
];

/// Every `.dart` file under `theme/`, `tokens/`, `effects/` and `widgets/`, as a
/// package URI.
///
/// `effects/` and `widgets/` joined the list in Phase 2. Before that they were
/// excluded by *absence* rather than by an allowlist that would have needed
/// editing every phase — which is exactly why a new `effects/*.dart` could land
/// un-exported for a whole phase without a thing going red.
List<String> get _designSystemFiles {
  final List<String> uris = <String>[
    for (final String dir in <String>['effects', 'theme', 'tokens', 'widgets'])
      for (final FileSystemEntity entity in Directory.fromUri(
        _root.uri.resolve('lib/core/design_system/$dir/'),
      ).listSync())
        if (entity is File && entity.path.endsWith('.dart'))
          // Interpolated as one expression rather than two adjacent literals:
          // `no_adjacent_strings_in_list` is enabled so a half-written entry is a
          // lint error, and a silent `'package:evangelion/core/…'` on its own
          // line would be exactly that.
          'package:evangelion/core/design_system/$dir/${entity.uri.pathSegments.last}',
  ];
  uris.sort();
  return uris;
}

void main() {
  group('the barrel is the single import surface', () {
    test('every public token and theme symbol is reachable through it', () {
      // If this compiles, the barrel exports each of these. Naming them IS the
      // assertion: a removed export becomes a compile error here rather than a
      // silently unavailable API that only breaks in whichever file happens to
      // import the deep path directly.
      expect(
        const EvaColors.dark().canvas,
        isNot(const EvaColors.light().canvas),
      );
      expect(StickerSlot.values.length, 7);
      expect(EvaStickerPalette.colors.length, 7);
      expect(EvaSpacing.screenHorizontal, 20.0);
      expect(EvaRadii.chip, 999.0);
      expect(EvaMotion.fast, const Duration(milliseconds: 150));
      expect(EvaElevations.card, 0.0);
      expect(EvaTypography.uiFamily, 'DMSans');
      expect(evaScalerFor(3).scale(1.0), 1.0);
      expect(
        EvaTheme.build(const EvaColors.dark()).brightness,
        Brightness.dark,
      );
      expect(EvaThemeDark.theme.brightness, Brightness.dark);
      expect(EvaThemeLight.theme.brightness, Brightness.light);
    });

    testWidgets('the EvaColorsX extension is reachable too', (
      WidgetTester tester,
    ) async {
      // An `extension` declaration is not a value, so the only way to assert one
      // was exported is to call it. `context.colors` fails to COMPILE if
      // `EvaColorsX` did not survive the re-export — which is precisely why it
      // needs naming, and why this test is a widget test.
      late EvaColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaThemeDark.theme,
          home: Builder(
            builder: (BuildContext context) {
              seen = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.canvas, const EvaColors.dark().canvas);
    });

    test('exports one URI per token and theme file that exists on disk', () {
      // THE GATE THAT CAN FAIL. A new `tokens/*.dart` nobody adds to the barrel
      // is invisible until a feature imports the deep path directly, and from
      // then on two import styles coexist — and `tool/verify_purity.sh` Gate 1
      // would still be green, because the deep import is a legal one. Comparing
      // the export list against the directory listing makes that a red the
      // moment the file lands.
      final List<String> onDisk = _designSystemFiles;
      expect(onDisk, isNotEmpty, reason: 'the design system has files');

      final List<String> exported = _exportedUris..sort();
      expect(
        exported,
        onDisk,
        reason: 'the barrel and the design-system tree have drifted apart',
      );
      expect(exported.length, onDisk.length);
      expect(exported.toSet().length, exported.length, reason: 'no duplicates');
    });

    test('re-exports nothing from a feature, a domain, or the framework', () {
      // The barrel is the one file every layer may import. If it re-exported
      // `package:flutter/material.dart`, a pure-Dart file importing only the
      // barrel would acquire a Flutter dependency.
      //
      // WHAT THIS DOES NOT DO, and it is worth being exact because the barrel's
      // own doc comment used to overclaim: it does not make Gate 1 fire. Gate 1
      // matches a directive against the file that *contains* it, with no graph
      // resolution, so a `core/domain/*.dart` file that imported this barrel
      // would pass Gate 1 while transitively depending on Flutter. The check
      // below stops the barrel from being the cause; the group that follows it
      // is what stops a *pure-Dart importer* from acquiring the dependency.
      expect(_exportedUris, isNotEmpty);
      for (final String uri in _exportedUris) {
        expect(
          uri,
          startsWith('package:evangelion/core/design_system/'),
          reason: '$uri is not a design-system export',
        );
        expect(uri, isNot(contains('features/')), reason: uri);
        expect(uri, isNot(contains('/domain/')), reason: uri);
        expect(uri, isNot(contains('flutter')), reason: uri);
        expect(uri, isNot(contains('dio')), reason: uri);
      }

      // Belt and braces on the specific URI rather than by substring, because the
      // substring form above is itself the sort of loose match that produced this
      // bug: it would miss `package:flutter_test/…` and read as thorough.
      expect(
        importUrisOf('${_root.path}/lib/core/design_system/barrel.dart'),
        everyElement(startsWith(packagePrefix)),
        reason: 'every barrel export is a same-package URI',
      );
    });

    test('exports are sorted, so a diff of the barrel stays readable', () {
      // `dart format` does not sort directives; `directives_ordering` sorts
      // imports within a file, and it does apply to exports, so an unsorted
      // barrel would already be a lint failure. Asserting it here names the
      // reason instead of leaving it to the analyzer.
      final List<String> exported = _exportedUris;
      final List<String> sorted = <String>[...exported]..sort();
      expect(exported, sorted);
    });
  });

  group('the barrel cannot launder Flutter into a pure-Dart importer', () {
    // THE INVARIANT AGENT_CONTEXT §7 EXISTS TO ENFORCE, and the one that was
    // unchecked.
    //
    // Gate 1 is a per-file regex: it reads the directives *in the file it is
    // scanning* and stops. That is enough for `import 'package:flutter/…'` in a
    // domain file, and useless for everything else — a domain file that reaches
    // Flutter through a chain of files, or through this barrel, is Flutter-
    // dependent in every sense that matters and prints `ok`.
    //
    // So this walks the graph instead of the file. Every file in every directory
    // Gate 1 claims to police is an entry point, and each one's whole transitive
    // closure is checked. The barrel is named in the entries below because it is
    // the one project file a pure-Dart file is *tempted* to import — it looks
    // like the polite thing to do, and it is the shortest path from "I need
    // `EvaSpacing.xl`" to "a domain library needs Flutter".

    /// Every `.dart` file under each directory `verify_purity.sh` Gate 1 claims
    /// to police, as package-relative paths.
    ///
    /// Read from disk rather than hand-listed, so a new domain file is covered
    /// the day it lands. `lib/features/*/domain` is included by glob for the same
    /// reason — it is empty in Phase 1 and must not silently become an unchecked
    /// directory once the features arrive.
    List<String> pureDartEntries() {
      final List<String> roots = <String>[
        'lib/core/domain/',
        'lib/core/common/',
        'lib/core/navigation/',
        'lib/features/',
      ];
      final List<String> entries = <String>[];
      for (final String root in roots) {
        final Directory dir = Directory.fromUri(_root.uri.resolve(root));
        if (!dir.existsSync()) continue;
        for (final FileSystemEntity entity in dir.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          if (entity.path.contains('/domain/') ||
              root == 'lib/core/domain/' ||
              root == 'lib/core/common/' ||
              root == 'lib/core/navigation/') {
            entries.add(packageRelative(entity.uri));
          }
        }
      }
      entries.sort();
      return entries;
    }

    test('nothing reachable from the shared kernel imports Flutter', () {
      // The specific walk the task names. `usecase.dart` is the one pure-Dart
      // file every feature use case implements against, so if anything in the
      // kernel's closure reached Flutter, every feature would inherit it and
      // Gate 1 would still print `ok` for all of them.
      final Set<String> reachable = reachableProjectFiles(
        'lib/core/domain/usecase/usecase.dart',
      );

      // Anti-vacuity, asserted before the contents: a walker that matched no
      // directive returns the entry point alone, and the loop below would then
      // be checking one file's own two lines — which Gate 1 already does.
      expect(
        reachable,
        containsAll(<String>[
          'lib/core/domain/usecase/usecase.dart',
          'lib/core/common/result.dart',
        ]),
        reason: 'the walk must follow the kernel\'s own edges',
      );

      for (final String path in reachable) {
        expect(
          forbiddenImportUrisOf(path),
          isEmpty,
          reason:
              '$path is reachable from the shared kernel and must stay pure',
        );
      }
    });

    test('no file in any pure-Dart directory reaches Flutter transitively', () {
      // The general form. Walking every entry rather than naming one means the
      // barrel — or any future indirection — cannot become a hole, and it cannot
      // become a hole quietly, because the entry list is read off disk.
      final List<String> entries = pureDartEntries();

      // The composition root is NOT in this list on purpose: it is a Flutter file
      // by design, and `injection_test.dart` owns the separate claim that it is
      // Flutter-free *internally*.
      expect(
        entries,
        isNotEmpty,
        reason:
            'the pure-Dart directories must exist for this to mean anything',
      );

      for (final String entry in entries) {
        final Set<String> reachable = reachableProjectFiles(entry);
        expect(reachable, contains(entry), reason: '$entry must reach itself');
        for (final String path in reachable) {
          expect(
            forbiddenImportUrisOf(path),
            isEmpty,
            reason:
                '$path is reachable from $entry — a pure-Dart importer must not '
                'acquire flutter/dio/http through a chain',
          );
        }
      }
    });

    test('the walk does detect Flutter — proven where it genuinely is', () {
      // The negative control for the three assertions above, and the reason the
      // barrel is deliberately NOT in `pureDartEntries()`. The design system is a
      // Flutter surface by design: `eva_colors.dart` imports
      // `package:flutter/material.dart`, `sticker_palette.dart` imports
      // `package:flutter/painting.dart`, and the barrel reaches both. So
      // walking *from* the barrel finds Flutter immediately — which is precisely
      // the fact that makes a clean result from a pure-Dart entry mean something,
      // and precisely why the rule is that a pure-Dart file must not import it.
      //
      // Without this, "no forbidden URIs found" is indistinguishable from a
      // walker that cannot recognise one.
      final Set<String> reachable = reachableProjectFiles(
        'lib/core/design_system/barrel.dart',
      );

      expect(reachable, isNotEmpty);
      final Set<String> found = <String>{
        for (final String path in reachable) ...forbiddenImportUrisOf(path),
      };
      expect(
        found,
        isNotEmpty,
        reason:
            'the design system IS a Flutter surface; a walk that found nothing '
            'here would mean the walk finds nothing anywhere',
      );
      expect(
        found,
        contains('${flutterPrefix}material.dart'),
        reason: 'reachable through eva_colors.dart, one barrel hop away',
      );

      // …and the token file a pure-Dart caller is most likely to want is itself
      // Flutter-free, which is exactly the trap: `eva_spacing.dart` looks
      // importable, and it is only safe because nothing else in its closure
      // reaches the framework.
      expect(
        forbiddenImportUrisOf('lib/core/design_system/tokens/eva_spacing.dart'),
        isEmpty,
      );
    });

    test('and no pure-Dart file imports the barrel in the first place', () {
      // The root cause, rather than the symptom. Even with the transitive walk
      // above, a domain file reaching the barrel would be *legal under Gate 1*
      // and only caught because this suite happens to exist. Naming it here says
      // the barrel is a presentation-layer import, which is the rule from
      // `07-file-map.md` that makes the walk above a backstop rather than the
      // primary defence.
      final List<String> entries = pureDartEntries()
          .where((String path) => !path.contains('/design_system/'))
          .toList();

      for (final String entry in entries) {
        expect(
          importUrisOf(entry),
          isNot(contains('$packagePrefix/core/design_system/barrel.dart')),
          reason:
              '$entry is pure Dart and must not reach for the design system',
        );
      }
    });

    test('the walk that makes those three tests real sees every form', () {
      // Anti-vacuity for the walker itself, in the file that depends on it most.
      // `injection_test.dart` carries the same test for the composition root;
      // it is duplicated here rather than shared because the consequence of the
      // walk narrowing is *different* in each file — a broken walk would leave
      // the DI claims unverified and the barrel claims unverified, and neither
      // file's other tests would notice.
      final Directory fixture = writeDirectiveFixture();
      addTearDown(() => fixture.deleteSync(recursive: true));

      final Set<String> reachable = reachableProjectFiles(
        '${fixture.uri.path}/entry.dart',
      );

      expect(
        fileNamesOf(reachable),
        containsAll(<String>['entry.dart', 'middle.dart', 'deepest.dart']),
        reason: 'import, part and double-quoted export must all be followed',
      );
      // The deepest file's only directive is an `export … show Color;`, which is
      // the exact shape that hid from the old barrel regex.
      expect(
        forbiddenImportUrisOf('${fixture.uri.path}/deepest.dart'),
        contains('${flutterPrefix}material.dart'),
        reason: 'a `show` combinator must not hide a forbidden URI',
      );
    });
  });
}
