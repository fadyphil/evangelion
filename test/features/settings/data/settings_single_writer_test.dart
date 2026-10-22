import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **The settings keys have exactly ONE writer in `lib/`.**
///
/// ## WHY THIS GATE EXISTS, AND IT IS NOT A TIDINESS GATE
///
/// `SettingsLocalDataSource.write` writes **only the keys that changed** — it
/// keeps the record it last wrote and diffs against it. That is safe because of
/// one invariant:
///
/// > after every successful write, the store holds exactly the record it was
/// > given, for the twenty-nine keys the store owns.
///
/// The invariant has **exactly one way to break**, and it is not a bug in the
/// data source: it is a **second writer**. Something else changing `eva.hue`
/// behind the data source's back would leave the diff base describing a store
/// that no longer exists, and the next write would **skip** the key it should
/// have written — the reader's setting would silently stop persisting.
///
/// So "the settings keys are written in exactly one place" is a **load-bearing
/// invariant of the diff**, and this file is the gate that holds it. The gate is
/// a **scan**, and its shape is `test/setstate_budget_test.dart`'s, because that
/// is the model this repository has for a scan that must be able to fail:
///
/// * a scan that finds **nothing** is a **failure** — its matcher has rotted, and
///   a gate that reports a clean run over a surface it no longer examines is
///   worse than no gate;
/// * an allowlist row that no longer matches the tree is a **failure** — a stale
///   row is an amnesty nobody re-read;
/// * comments are **stripped before matching**, using the same routine
///   `setstate_budget_test.dart` ports from `tool/gates/orphan_widget_check.py`.
///
/// ## AND WHY A **COMMENT** IS NOT A MENTION
///
/// `sky_local_data_source.dart` names `kThemeModeKey` in a doc comment, to say
/// that the sky's keys are namespaced one level deeper than the settings' are.
/// That is prose about the convention, not a second writer, and a scan that
/// counted it would report a violation that does not exist — which is how a gate
/// teaches its readers to ignore it.
///
/// ## AND WHY THE KEY SET IS **DISCOVERED** RATHER THAN WRITTEN OUT
///
/// Because a **written-out** list is a list of the keys the tree *had*, and the
/// gate would then be blind to a key that was **added** — which is the change
/// most likely to be made, and the one the allowlist row has to be re-reviewed
/// for. The discovery reads the store's own `const String k…Key = '…';`
/// declarations, so a key that is added, removed or renamed changes what the
/// scan finds, and the allowlist row below — which is **written out**, on
/// purpose — stops matching.
///
/// **The two halves are deliberately different.** The scan discovers; the
/// allowlist is written out. A row derived from the tree would always match it.
void main() {
  group('the settings keys have ONE writer', () {
    test('the store declares the keys the gate expects', () {
      // **THE SCAN IS NOT VACUOUS, AND THIS IS WHERE IT IS PROVEN.** The
      // discovery below reads the store's own declarations; if that file moves,
      // or its declarations change shape, the discovery finds **nothing** — and a
      // scan that finds nothing reports a clean run over a surface it never
      // examined. So the count is asserted here, before anything is concluded
      // from it.
      final List<({String constant, String key})> discovered = _discoverKeys();

      expect(
        discovered,
        hasLength(29),
        reason:
            'the discovery found ${discovered.length} key declarations in '
            '$_storePath, not 29. Either the file moved, or its declarations '
            'changed shape, or a key was added or removed — and every '
            'conclusion this gate draws is drawn from that list, so a wrong list '
            'makes the gate meaningless rather than merely incomplete.',
      );
      expect(
        discovered.map((({String constant, String key}) e) => e.key).toSet(),
        hasLength(29),
        reason:
            'and the twenty-nine declarations name twenty-nine distinct keys',
      );
    });

    test('no file outside the allowlist touches a settings key', () {
      final Map<String, List<String>> found = _foundByFile();

      // **THE GATE THAT CAN FAIL.** A scan that finds nothing is a scan whose
      // matcher has rotted — the constant names moved, or the literals changed
      // shape — and a scan that reports a clean run over a surface it no longer
      // examines is the ADR-0020 shape. So **zero is a failure**, not a pass.
      expect(
        found.values.fold<int>(0, (int sum, List<String> v) => sum + v.length),
        greaterThan(0),
        reason:
            'the scan found NO settings key at all, which means the matcher '
            'stopped matching rather than the tree becoming clean. A gate that '
            'reports a pass over a surface it no longer examines is worse than '
            'no gate.',
      );

      final List<String> unexpected = <String>[
        for (final MapEntry<String, List<String>> entry in found.entries)
          if (!_allowlist.containsKey(entry.key))
            '${entry.key}: ${entry.value.join(' | ')}',
      ];
      expect(
        unexpected,
        isEmpty,
        reason:
            'a file outside the allowlist names a settings key. The diff in '
            '`SettingsLocalDataSource.write` is only safe while this store is the '
            'sole writer of these keys: a second writer would leave the diff '
            'base describing a store that no longer holds it, and the next save '
            'would skip the key it should have written — the setting would stop '
            'persisting, silently. A second writer has to be a **deliberate** '
            'decision, and this gate is where it is recorded.\n'
            '${unexpected.join('\n')}',
      );
    });

    test('and every allowlist row still matches the tree', () {
      // **A STALE ROW IS A FAILURE, and not a note.** The allowlist is a record of
      // what was reviewed; a row whose site has gone is a row that still permits a
      // second writer nobody has looked at, and the day the site comes back it
      // comes back unexamined. **A key that was added, removed or renamed lands
      // here**, because the scan discovers the keys and the row is written out.
      final Map<String, List<String>> found = _foundByFile();
      final List<String> stale = <String>[];
      for (final MapEntry<String, List<String>> row in _allowlist.entries) {
        final List<String> site = found[row.key] ?? const <String>[];
        if (_sameMultiset(row.value, site)) continue;
        stale.add(
          '${row.key} — allowed: ${row.value.join(' | ')} · found: '
          '${site.join(' | ')}',
        );
      }
      expect(
        stale,
        isEmpty,
        reason:
            'an allowlist row no longer matches the tree. Either the keys moved '
            'out of the file — in which case **delete the row** — or a key was '
            'added, removed or renamed, in which case the change has to be '
            '**re-reviewed** and the row rewritten. A stale row is an amnesty '
            'nobody re-read:\n${stale.join('\n')}',
      );
    });

    test('and the allowlist is not empty, because a rule that allows nothing '
        'is not a rule', () {
      expect(
        _allowlist,
        isNotEmpty,
        reason:
            'the allowlist is empty, which would mean the gate forbids the store '
            'from touching its own keys — and the store is the one file that is '
            'supposed to write them.',
      );
      expect(
        _allowlist.values.fold<int>(0, (int s, List<String> v) => s + v.length),
        29,
        reason:
            'twenty-nine keys are the store\'s. If this number moved, the '
            'allowlist above and the tree have drifted apart, and one of them is '
            'wrong.',
      );
    });
  });
}

/// The file that owns the settings keys.
const String _storePath =
    'lib/features/settings/data/datasources/settings_local_data_source.dart';

/// The settings keys, **discovered** from the store's own declarations.
///
/// **And why the discovery throws rather than returning an empty list**: a
/// discovery that found nothing would leave every conclusion in this file drawn
/// from an empty list, and the gate would report a clean run over a surface it
/// never examined. A missing file is a **broken gate**, and it says so.
List<({String constant, String key})> _discoverKeys() {
  final File file = File(_storePath);
  if (!file.existsSync()) {
    throw StateError(
      '$_storePath does not exist — the discovery would find no keys and the '
      'gate would report a clean run over a surface it never examined',
    );
  }
  final String source = stripComments(file.readAsStringSync());
  final RegExp declaration = RegExp(r"const String (k\w+Key) = '([^']+)';");
  return <({String constant, String key})>[
    for (final Match match in declaration.allMatches(source))
      (constant: match.group(1)!, key: match.group(2)!),
  ];
}

/// The settings keys mentioned in every file of `lib/`, by file.
///
/// **A file is mentioned once per key it names**, so the value is the list of the
/// keys it names — and a file that names the same key twice is still one mention,
/// because the question is "does this file touch this key", not "how often".
Map<String, List<String>> _foundByFile() {
  final List<({String constant, String key})> keys = _discoverKeys();
  final Map<String, List<String>> found = <String, List<String>>{};
  for (final FileSystemEntity entity in _dartFilesIn('lib')) {
    final File file = entity as File;
    final String source = stripComments(file.readAsStringSync());
    final List<String> mentioned = <String>[
      for (final ({String constant, String key}) entry in keys)
        if (_mentions(source, entry)) entry.key,
    ];
    if (mentioned.isNotEmpty) {
      found[_relative(file)] = mentioned;
    }
  }
  return found;
}

/// Whether [source] names the key in [entry].
///
/// **Both spellings count**: the constant's name (how the rest of `lib/` refers
/// to it) and the literal value (how a file that does not import the constant
/// would have to write it). A scan that matched only the constant would pass
/// over a file that wrote `'eva.shader.hue'` by hand.
bool _mentions(String source, ({String constant, String key}) entry) =>
    RegExp('\\b${entry.constant}\\b').hasMatch(source) ||
    source.contains("'${entry.key}'");

/// Whether two multisets are the same.
bool _sameMultiset(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final List<String> sortedA = List<String>.of(a)..sort();
  final List<String> sortedB = List<String>.of(b)..sort();
  for (int i = 0; i < sortedA.length; i++) {
    if (sortedA[i] != sortedB[i]) return false;
  }
  return true;
}

/// Every `.dart` file under [directory], excluding the generated ones.
List<FileSystemEntity> _dartFilesIn(String directory) {
  final Directory dir = Directory(directory);
  if (!dir.existsSync()) {
    throw StateError(
      '$directory does not exist — the scan would find nothing '
      'and report a clean run over a surface it never examined',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !_generated.contains(_fileName(f)))
      .toList();
}

/// The generated files, which are the framework's and the generator's and not
/// the tree's.
const Set<String> _generated = <String>{
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
};

String _fileName(File file) {
  final String path = file.path;
  final int slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}

String _relative(File file) {
  final String path = file.path.replaceAll('\\', '/');
  return path.startsWith('./') ? path.substring(2) : path;
}

/// Removes `/* */` and `//` comments, preserving line structure.
///
/// **Ported from `tool/gates/orphan_widget_check.py`'s `strip_comments`, not
/// reinvented.** Two gates that strip comments have to strip them the same
/// way, and this one is the gate that had it right: it removes a block
/// comment by replacing it with the same number of newlines, so the line
/// count — and therefore every reported `file:line` — is unchanged, and it
/// removes a line comment by removing the rest of the line.
final RegExp _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final RegExp _lineComment = RegExp(r'//[^\n]*');

String stripComments(String text) {
  final String withoutBlocks = text.replaceAllMapped(_blockComment, (Match m) {
    final int newlines = '\n'.allMatches(m.group(0)!).length;
    return List<String>.filled(newlines, '\n').join();
  });
  return withoutBlocks.replaceAll(_lineComment, '');
}

/// The one file that is allowed to name the settings keys, and the keys it owns.
///
/// **One row, and the row is the whole point.** The data source owns these keys,
/// and the diff it now performs is only safe because it is the only writer.
///
/// **The keys are written out rather than derived**, for the reason the scan
/// discovers: a row derived from the tree would always match the tree, and a
/// rule that cannot fail is not a rule. A key that is added, removed or renamed
/// has to be **re-reviewed** here, and this is where that is recorded.
const Map<String, List<String>> _allowlist = <String, List<String>>{
  'lib/features/settings/data/datasources/settings_local_data_source.dart':
      <String>[
        'eva.theme_mode',
        'eva.font_step',
        'eva.language',
        'eva.reduced_motion',
        'eva.communion.veil_witnesses',
        'eva.communion.show_podium',
        'eva.shader.enabled',
        'eva.shader.shape',
        'eva.shader.reach',
        'eva.shader.glow',
        'eva.shader.touch_glow',
        'eva.shader.hue',
        'eva.shader.melt',
        'eva.shader.rays',
        'eva.shader.white',
        'eva.shader.dots',
        'eva.sky.pref.stars_on',
        'eva.sky.pref.constellations',
        'eva.sky.pref.count',
        'eva.sky.pref.brightness',
        'eva.sky.pref.shape',
        'eva.sky.pref.field',
        'eva.sky.pref.twinkle',
        'eva.ritual.focus_delay',
        'eva.ritual.selah_length',
        'eva.ritual.breath',
        'eva.ritual.vespers',
        'eva.ritual.calm',
        'eva.ritual.haptics',
      ],
};
