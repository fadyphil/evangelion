import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// Colour literals under `lib/` are confined to the token tables.
///
/// AGENT_CONTEXT §4 requires every colour to resolve through `EvaColors` or
/// `EvaStickerPalette`, and "no hex literals in production code" is the
/// mechanical form of that. It is also, on its own, unenforceable by review —
/// `0xFF6C3FE8` looks like a colour nobody chose and behaves like a colour nobody
/// chose, in a design system whose whole premise is that the values were.
///
/// So this walks the files rather than trusting a diff.
///
/// ## THE TWO FILES THAT ARE ALLOWED TO HOLD LITERALS
///
/// - `tokens/**` — Phase 1's published token table. That is what a token *is*.
/// - `effects/neural_orbs.dart` — the transcription of `ORB_CONFIGS`
///   (`eva/src/components/ds.tsx:68-112`) and of the aurora `rgba()` bands
///   (`ds.tsx:170-190`). **Neither is a design-system token**: `03-design-system.md`
///   §5.1 publishes fourteen colour tokens per brightness and not one of them is
///   an orb accent or an aurora stop, and the sticker palette is a different
///   seven-colour vocabulary. Promoting prototype data into `EvaColors` would put
///   values into a file that claims to be the spec's token table; keeping the
///   literals at their single transcription site means they are declared once,
///   asserted by `neural_orbs_test.dart`, and reachable from nowhere else.
///
/// This test is why that second bullet is a decision rather than a leak: move a
/// literal into a painter and this goes red.
void main() {
  test('no colour literal exists outside the token tables', () {
    final List<String> offenders = <String>[];
    final Directory lib = Directory.fromUri(packageRoot.uri.resolve('lib/'));
    final List<File> files = <File>[
      for (final FileSystemEntity entity in lib.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ];

    expect(files, isNotEmpty, reason: 'the walk has to find something');

    for (final File file in files) {
      final String relative = packageRelative(file.uri);
      if (relative.startsWith('lib/core/design_system/tokens/')) continue;
      if (relative == 'lib/core/design_system/effects/neural_orbs.dart') {
        continue;
      }
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        // Doc comments quote the prototype's hexes on purpose — that is where a
        // reader learns which token came from where.
        final String trimmed = line.trimLeft();
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        if (line.contains('Color(0x') || line.contains('Color.fromARGB')) {
          offenders.add('$relative:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'every colour resolves through EvaColors / EvaStickerPalette, or '
          'through the one transcribed prototype table in neural_orbs.dart',
    );
  });
  test('and the transcription file really does hold both tables', () {
    // Without this the first test could be satisfied by an allowlist that grew,
    // or by a file whose tables were moved somewhere the first test does not
    // reach. Both failure modes are the same bug: two homes for one table.
    final String source = File.fromUri(
      packageRoot.uri.resolve(
        'lib/core/design_system/effects/neural_orbs.dart',
      ),
    ).readAsStringSync();
    expect(
      'const Map<OrbGroup, List<OrbSpec>> orbGroups'.allMatches(source).length,
      1,
      reason: 'the ORB_CONFIGS transcription',
    );
    expect(
      'abstract final class NeuralAurora'.allMatches(source).length,
      1,
      reason:
          'the aurora band transcription, kept beside the orbs so this '
          'file\'s allowlist above is a single entry',
    );
  });
}
