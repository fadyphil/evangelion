import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **No `setState` in `lib/` outside a reviewed allowlist.**
///
/// ## WHAT THIS GATE IS FOR
///
/// §13 rule 1 says **"No `setState` per frame"**, and it has said it since
/// the first phase. **It was never enforced against anything**, so the tree
/// grew to **twenty-nine** of them, and several of those rebuilt a **whole
/// screen** to change one boolean — the reading page's selected verse rebuilt
/// the scaffold, the forty-four-star sky and every visible verse; a toast on
/// `/settings` rebuilt the thirty-three-row Workshop; a Hue slider drag
/// rebuilt a thousand and two hundred and thirty-six widgets.
///
/// The measurement is `test/rebuild_isolation_budget_test.dart` and the
/// numbers are in `docs/PERFORMANCE.md`.
///
/// ## THE RULE, AND WHY IT IS A GATE AND NOT A CONVENTION
///
/// **`setState` rebuilds the whole `State.build` output.** It is the right
/// tool when that output *is* the state — a leaf, a button, a card's own
/// surface. It is the wrong tool when one boolean flips a screen.
///
/// **And a rule that cannot fail is worse than no rule**, which this
/// repository has met three times (ADR-0020, decision 142). So the rule is a
/// gate: a **new** `setState` is red, and an allowlist row that no longer
/// matches anything is **also** red — because a stale row is an amnesty
/// nobody re-read.
///
/// ## WHY THE KEY IS A **FILE** AND A **MULTISET OF STATEMENTS**
///
/// Because a `file:line` key is brittle in the worst way: any edit above a
/// site moves it, and the gate would cry wolf on a change that changed
/// nothing. A **file** plus the **normalised text of each statement** is
/// stable under line shifts, and it catches all three things a gate must:
/// a **new** statement, a **removed** one, and an **edited** one.
///
/// **And the multiset, and not a set**, because two sites can carry the same
/// text — `/settings`'s four `setState(() {` are identical — and a set would
/// collapse them into one and a fifth would slip through.
///
/// ## AND WHY COMMENTS ARE STRIPPED FIRST
///
/// Because the repository mentions `setState` in **prose** in seven places,
/// and a doc comment must never count as a site. The routine is **ported from
/// `tool/gates/orphan_widget_check.py`**, not reinvented: two gates that strip
/// comments have to strip them the same way.
void main() {
  group('the `setState` budget', () {
    test('no file outside the allowlist calls `setState`', () {
      final Map<String, List<String>> found = _foundByFile();

      // **THE GATE THAT CAN FAIL.** A scan that finds nothing is a scan whose
      // matcher has rotted — `setState (` with a space, `context.setState`, a
      // call moved into a helper — and a scan that reports a clean run over a
      // surface it no longer examines is **the ADR-0020 shape**, and the third
      // time this repository has met it. So **zero is a failure**, not a pass.
      expect(
        found.values.fold<int>(0, (int sum, List<String> v) => sum + v.length),
        greaterThan(0),
        reason:
            'the scan found NO `setState` at all, which means the matcher '
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
            'a `setState` outside the allowlist. The rule is §13 rule 1 — "no '
            '`setState` per frame" — and it is now enforced. A new site has to '
            'be **reviewed**, not merely written: a `setState` rebuilds the '
            'whole `State.build` output, so it belongs in a leaf, or in a '
            '`ValueNotifier` whose consumer is the one thing that changed. '
            'Unreviewed sites:\n${unexpected.join('\n')}',
      );
    });

    test('and every allowlist row still matches a site', () {
      // **A STALE ROW IS A FAILURE, and not a note.** The allowlist is a
      // record of what was reviewed; a row whose site has gone is a row that
      // still permits a `setState` nobody has looked at, and the day the
      // site comes back it comes back unexamined.
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
            'an allowlist row no longer matches the tree. Either the site was '
            'removed — in which case **delete the row** — or it was changed, in '
            'which case the change has to be **re-reviewed** and the row '
            'rewritten. A stale row is an amnesty nobody re-read:\n'
            '${stale.join('\n')}',
      );
    });

    test('and the allowlist is not empty, because a rule that allows '
        'nothing is not a rule', () {
      expect(
        _allowlist,
        isNotEmpty,
        reason:
            'the allowlist is empty, which would mean the gate forbids every '
            '`setState` in the tree — and there are **sixteen** that are '
            'legitimate, because their `build` output *is* the state.',
      );
      expect(
        _allowlist.values.fold<int>(0, (int s, List<String> v) => s + v.length),
        16,
        reason:
            'sixteen sites are reviewed and allowed. If this number moved, the '
            'allowlist above and the tree have drifted apart, and one of them '
            'is wrong.',
      );
    });
  });
}

/// The `setState` statements in every file of `lib/`, by file.
///
/// **The statements are the matched LINE, whitespace-collapsed.** A multi-line
/// `setState(() {` is identified by its first line, and that is enough: the
/// gate is about *whether a site exists*, not about what it does.
Map<String, List<String>> _foundByFile() {
  final Map<String, List<String>> found = <String, List<String>>{};
  for (final FileSystemEntity entity in _dartFilesIn('lib')) {
    final File file = entity as File;
    final List<String> statements = <String>[];
    for (final String line in stripComments(
      file.readAsStringSync(),
    ).split('\n')) {
      if (line.contains('setState(')) {
        statements.add(line.replaceAll(RegExp(r'\s+'), ''));
      }
    }
    if (statements.isNotEmpty) {
      found[_relative(file)] = statements;
    }
  }
  return found;
}

/// Whether two multisets of statements are the same.
///
/// **Sorted, and compared element by element** — and *not* as sets, because
/// two sites can carry the same text and a set would collapse them.
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

/// The sixteen reviewed sites, and why each is legitimate.
///
/// **Every row's reason is the same question**: *is the `State.build` output
/// the state?* If yes, `setState` is the right tool. If no, the state belongs
/// in a `ValueNotifier` whose consumer is the one thing that changed.
///
/// **And the rows are grouped by that answer**, so a reader can see the shape
/// of what is left rather than a flat list.
const Map<String, List<String>> _allowlist = <String, List<String>>{
  // ## THE **COMPOSITION ROOT** — the whole app, twice.
  //
  // The first is **guarded**: it fires only when `themeMode`, `locale`,
  // `fontStep` or `reducedMotion` changed, because those four are the only
  // settings that reach the shell. The second is the platform's own
  // accessibility signal, which changes a handful of times in a session.
  //
  // **Both are the whole application**, and both are rare by construction.
  'lib/app/app.dart': <String>[
    'if(materialChanged)setState((){});',
    'setState((){});',
  ],

  // ## THE **AURORA'S** BACKING WIDGET — three widgets, once at startup.
  //
  // `LumenBackground`'s build output is three widgets: the flat canvas, or
  // the boundary, the filter and the paint. The `setState` says "the shader
  // finished loading", and it happens **once**, at launch.
  'lib/core/design_system/effects/lumen_background.dart': <String>[
    'setState(()=>_program=program);',
  ],

  // ## THE **POINTER STATE** — a leaf's own surface.
  //
  // A button's build output *is* the button. The press highlight and the
  // hover wash are read by that output and by nothing else, so a `setState`
  // rebuilds the button and nothing else.
  //
  // **And the two hover rows are desktop-only** — `MouseRegion.onEnter` fires
  // for a mouse and a stylus and never for a finger.
  'lib/core/design_system/widgets/eva_button.dart': <String>[
    'setState(()=>_hovered=value);',
    'setState(()=>_pressed=value);',
  ],
  'lib/core/design_system/widgets/icon_action_button.dart': <String>[
    'setState(()=>_hovered=value);',
    'setState(()=>_pressed=value);',
  ],
  'lib/core/design_system/widgets/settings_tile.dart': <String>[
    'setState(()=>_hovered=value);',
  ],

  // ## THE **SEGMENTED CONTROL'S** THUMB — the control's own measurement.
  //
  // The measured rect is read by **one** `AnimatedPositioned` and by nothing
  // else. A `ValueNotifier` would narrow it further, and the control's own
  // build output is a handful of widgets — so the row is a **leaf** by the
  // rule, and it stays.
  'lib/core/design_system/widgets/segmented_control.dart': <String>[
    'setState((){',
  ],

  // ## THE **DOCK SLOT** — the slot's own press scale.
  //
  // One `Transform.scale` reads it, and the slot is a leaf.
  'lib/features/dock/presentation/widgets/lumen_dock.dart': <String>[
    'setState(()=>_pressed=pressed);',
  ],

  // ## THE **SELAH CARD** — the card's own surface, four times.
  //
  // All four write the countdown, and the countdown is read by the card's own
  // fill, its border, its button label and its count. **Once a second**, for
  // the length of the silence, and the card is **inside** `/`'s scroll — so
  // this is the one `setState` in the tree that fires on a **timer**.
  //
  // **And it is still a leaf**: the card's build output is about ten widgets,
  // and the rest of the home page does not rebuild with it.
  'lib/features/home/presentation/widgets/selah_card.dart': <String>[
    'setState((){',
    'setState((){',
    'setState((){',
    'setState((){',
  ],

  // ## THE **QUIZ'S CTA** — the button's own hover wash.
  //
  // **Desktop-only**, for the same reason the buttons' is.
  'lib/features/quiz/presentation/pages/quiz_page.dart': <String>[
    'onEnter:enabled?(_)=>setState(()=>_hovered=true):null,',
    'onExit:enabled?(_)=>setState(()=>_hovered=false):null,',
  ],
};
