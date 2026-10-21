import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// **A cubit behind a controlled field must take every keystroke.**
///
/// ## WHAT THIS GATE IS FOR
///
/// `lib/core/design_system/widgets/eva_controlled_field.dart` is the
/// mechanism, and its doc says this:
///
/// > **It does not make a state that *refuses* a keystroke agree with the
/// > screen.** … the cubit must take every keystroke, or the screen and the
/// > state disagree and the field cannot tell which of them is right.
///
/// **THE RULE IS LOAD-BEARING, AND IT IS NOT ABOUT THE FIELD.** The field
/// cannot correct a state that refuses: its third guard — *the controlled
/// value must have moved* — means a value the state kept is never written
/// back, so the character the reader typed stays on the screen **for ever**
/// while the state does not have it. The field and the state disagree, and
/// neither of them knows which is right.
///
/// **AND THE CLAIM WAS FALSE OF ONE CUBIT.** `QuestionAuthoringCubit`'s
/// `setOptionText` returned early when the question had no option under the
/// letter — so the doc's "every cubit in this repository takes it" was a
/// premise that was quietly untrue. **A premise that is quietly untrue is
/// the same failure AGENT_CONTEXT §7 calls "a gate that cannot fail"** —
/// the safety does not depend on the claim being true *being* true, it
/// depends on a reader being able to check it.
///
/// This gate is that check.
///
/// ## THE RULE, AND HOW IT IS FOUND
///
/// The rule: **a keystroke writer does not refuse.**
///
/// The inventory is **derived**, and this is the whole point:
///
/// 1. the **hosts** are the files under `lib/` that use the controlled field;
/// 2. the **cubits** are the `*_cubit.dart` files those hosts import;
/// 3. the **writers** are the public `void set…` methods in those cubits.
///
/// **A GATE THAT NAMES ITS OWN SUBJECT CANNOT NOTICE THE SUBJECT MOVING.**
/// A screen that adopts the controlled field brings its cubit with it, and a
/// writer added to a derived cubit is checked the day it is written.
///
/// ## AND THE WRITERS ARE FOUND BY THE HOUSE'S `set…` NAMING, AND THAT IS A
/// ## PROXY — AND THE PROXY IS THE POINT
///
/// A naming-free scan of every public method would also catch the **button**
/// writers — `addOption` and `removeOption` — and **those refuse on
/// purpose**: a second tap on "add" must not overwrite an option, and a
/// remove of an option that is not there must not remove another one. So the
/// rule is about *keystrokes*, and `set…` is what a keystroke writer is
/// called in this repository.
///
/// ## AND THE CHECK IS LEXICAL, AND IT IS AN OVER-APPROXIMATION
///
/// It asks whether a writer's body contains the token `return` — and a
/// string literal naming the word would be reported too. **That is the
/// conservative direction**: a report that turns out to be a string is one
/// line to reword, and the alternative — a check that reasons about Dart's
/// grammar — is a parser this repository has no reason to own. The cubits
/// hold no strings (`ServantReportCubit`'s own doc says so), so the
/// over-approximation costs nothing today.
///
/// ## FAIL-CLOSED
///
/// AGENT_CONTEXT §7, "a gate that cannot fail is worse than no gate":
///
/// - `lib/` missing → **fail**, naming the path.
/// - an empty walk → **fail**. A walk that found nothing proves nothing.
/// - **a matcher that stopped matching** → **fail**. Two of the tests in the
///   file plant a writer that refuses — one with a single-line parameter list
///   and one with a multi-line one — and require the matcher to see both.
void main() {
  group('the keystroke takers', () {
    test('no cubit behind a controlled field has a writer that can refuse', () {
      final Set<String> cubits = _cubitsBehindControlledFields();

      // **THE DERIVATION IS NOT VACUOUS.** A scan that finds nothing is a
      // scan whose matcher has rotted, and a scan that reports a clean run
      // over a surface it no longer examines is the ADR-0020 shape.
      expect(
        cubits,
        isNotEmpty,
        reason:
            'no cubit was derived from the controlled field, which means the '
            'derivation stopped working rather than the tree becoming empty. '
            'A gate that reports a pass over a surface it no longer examines '
            'is worse than no gate.',
      );

      // **AND THE THREE CUBITS THAT ARE BEHIND THE THREE SCREENS ARE AMONG
      // THEM.** The derivation is mechanical, so this is the check that the
      // mechanical part is still reaching the thing it is about.
      final List<String> sorted = cubits.toList()..sort();
      expect(
        cubits,
        containsAll(<String>[
          'lib/features/servant/presentation/cubit/question_authoring_cubit.dart',
          'lib/features/servant/presentation/cubit/schedule_reading_cubit.dart',
          'lib/features/servant/presentation/cubit/servant_report_cubit.dart',
        ]),
        reason:
            'the question editor\'s, the schedule form\'s and the report '
            'form\'s cubits are the ones behind the controlled field, and the '
            'derivation has to reach all three. Derived:\n'
            '${sorted.join('\n')}',
      );

      final List<String> refusing = <String>[
        for (final String cubit in cubits)
          for (final ({String name, List<String> body}) writer in _writersIn(
            File.fromUri(packageRoot.uri.resolve(cubit)).readAsStringSync(),
          ))
            if (_canRefuse(writer.body)) '$cubit — ${writer.name}',
      ];

      expect(
        refusing,
        isEmpty,
        reason:
            'a keystroke writer that can refuse. The controlled field cannot '
            'correct a state that refuses a keystroke: its third guard — *the '
            'controlled value must have moved* — means the value the state '
            'kept is never written back, so the reader\'s character stays on '
            'the screen for ever while the state does not have it, and '
            'neither of them knows which is right. A writer that takes the '
            'keystroke is the rule; the field depends on it. Offending '
            'writers:\n${refusing.join('\n')}',
      );
    });

    test('and every derived cubit has at least one writer to check', () {
      final Set<String> cubits = _cubitsBehindControlledFields();

      final List<String> withoutWriters = <String>[
        for (final String cubit in cubits)
          if (_writersIn(File(cubit).readAsStringSync()).isEmpty) cubit,
      ];

      expect(
        withoutWriters,
        isEmpty,
        reason:
            'a derived cubit with no `set…` writer in it. Either the naming '
            'the gate looks for has changed — in which case the gate is '
            'looking at nothing — or the cubit has no keystroke writer, which '
            'is worth a reader\'s attention rather than a silent pass. '
            'Cubits with no writer:\n${withoutWriters.join('\n')}',
      );
    });

    test('and the matcher sees a writer that can refuse', () {
      // The anti-vacuity for the matcher itself, in the file that depends on
      // it most. **A scan whose pattern stopped matching reports a clean
      // tree**, and the test above would then pass over a surface it no
      // longer examines.
      const String planted = '''
class Probe {
  void setThing(String text) {
    if (text.isEmpty) return;
    emit(text);
  }
}
''';

      final List<({String name, List<String> body})> writers = _writersIn(
        planted,
      );

      expect(
        writers.map((({String name, List<String> body}) w) => w.name),
        <String>['setThing'],
        reason: 'the matcher must see the writer it is looking for',
      );
      expect(
        writers.where(
          (({String name, List<String> body}) w) => _canRefuse(w.body),
        ),
        hasLength(1),
        reason:
            'a writer that returns before it emits is a writer that can '
            'refuse, and the matcher must see it',
      );
    });

    test('and the matcher sees a refusing writer whose parameters run over '
        'several lines', () {
      // **THE SHAPE THAT BROKE THE FIRST VERSION OF THIS GATE.** A writer
      // whose parameters run over several lines ends them with `  }) {` —
      // two spaces, a bracket, a brace — and that line looks exactly like a
      // class member. Reading it as one truncated the body **before the
      // first statement**, so the gate reported a clean tree over
      // `QuestionAuthoringCubit.setOptionText` — the very writer that
      // refused. **A gate that cannot see the defect it exists to catch is
      // worse than no gate**, and the only defence is to plant the shape.
      const String planted = '''
class Probe {
  void setThing(
    String letter, {
    required bool arabic,
    required String text,
  }) {
    final String? value = null;
    if (value == null) return;
    emit(text);
  }
}
''';

      final List<({String name, List<String> body})> writers = _writersIn(
        planted,
      );

      expect(
        writers.map((({String name, List<String> body}) w) => w.name),
        <String>['setThing'],
        reason: 'the matcher must see the writer it is looking for',
      );
      expect(
        writers.where(
          (({String name, List<String> body}) w) => _canRefuse(w.body),
        ),
        hasLength(1),
        reason:
            'the writer\'s body must reach past the parameter list\'s closing '
            'brace, or a refusal inside it is invisible',
      );
    });

    test('and a writer that takes the keystroke is not reported', () {
      // **THE GREEN DIRECTION.** A check that reported every writer would
      // satisfy "the gate can fail" and mean nothing.
      const String planted = '''
class Probe {
  void setThing(String text) {
    emit(text);
  }
}
''';

      expect(
        _writersIn(
          planted,
        ).where((({String name, List<String> body}) w) => _canRefuse(w.body)),
        isEmpty,
        reason: 'a writer that emits what it was given takes the keystroke',
      );
    });
  });
}

/// The cubit files behind the controlled field, derived from the tree.
///
/// **The hosts are the files that USE the field**, and the cubits are the
/// ones those files import. A file that uses the field and imports no cubit
/// — the option editor, which forwards to its caller — contributes nothing,
/// and the screen that binds it contributes the cubit.
Set<String> _cubitsBehindControlledFields() {
  final Directory lib = Directory.fromUri(packageRoot.uri.resolve('lib/'));
  if (!lib.existsSync()) {
    throw StateError(
      'lib/ does not exist — the scan would find nothing and report a clean '
      'run over a surface it never examined',
    );
  }

  final List<File> files = <File>[];
  try {
    files.addAll(<File>[
      for (final FileSystemEntity entity in lib.listSync(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]);
  } on FileSystemException catch (error) {
    throw StateError('lib/ could not be walked: ${error.message}');
  }
  if (files.isEmpty) {
    throw StateError(
      'the walk found no .dart file under lib/. That is not a clean tree.',
    );
  }

  final Set<String> cubits = <String>{};
  for (final File file in files) {
    if (_generated.contains(_fileName(file))) continue;
    final String relative = packageRelative(file.uri);
    final String source = withoutDartComments(file.readAsStringSync());
    if (!_usesTheField.hasMatch(source)) continue;
    // **AN ABSOLUTE PATH**, because the helper reads the file it is given and
    // a relative one would be resolved against the process's working
    // directory rather than against the package root.
    final String absolute = File.fromUri(packageRoot.uri.resolve(relative))
        .path;
    for (final String uri in importUrisOf(absolute)) {
      if (!uri.startsWith(packagePrefix)) continue;
      if (!uri.endsWith('_cubit.dart')) continue;
      cubits.add('lib/${uri.substring(packagePrefix.length)}');
    }
  }
  return cubits;
}

/// A use of the controlled field — a construction, and not a mention.
///
/// **The open paren is the whole of the distinction**, and it is the same
/// distinction `mirrored_controller_check_test.dart` draws for a controller:
/// a mention is a name in prose, and a use is a construction.
final RegExp _usesTheField = RegExp(r'\bEvaControlledField\s*\(');

/// A public keystroke writer's declaration — `  void set…(`.
///
/// **The two-space indent is the class member's**, and `dart format` is gate
/// 1, so the shape is the tree's shape and not a guess. The body of a writer
/// runs to the next member of the class.
final RegExp _writerDeclaration = RegExp(r'^  void (set[A-Z]\w*)\(');

/// A member of the class — the boundary a writer's body ends at.
///
/// **AND NOT A PARAMETER LIST'S CLOSING BRACE.** A writer whose parameters
/// run over several lines ends them with `  }) {` — two spaces, a closing
/// bracket and a brace — and that line is **not** a member: it is the
/// writer's own head. Reading it as a member truncated the body before the
/// first statement, and the gate reported a clean tree over a writer that
/// refused — which is the one thing this gate exists to prevent.
///
/// **SO A MEMBER IS A DOC COMMENT, AN ANNOTATION, OR A DECLARATION**, and a
/// closing brace is none of the three. Every member of every cubit in this
/// repository is introduced by a `///` doc comment or an `@` annotation, and
/// `dart format` is gate 1, so the shape is the tree's shape and not a
/// guess. **The self-test below plants the multi-line-parameter shape**, so
/// the mistake cannot come back.
final RegExp _classMember = RegExp(r'^  (///|@|\w)');

/// The end of the class — a brace at column zero.
final RegExp _endOfClass = RegExp(r'^}');

/// The token `return` — a writer that leaves without emitting.
final RegExp _returns = RegExp(r'\breturn\b');

/// An emit of the state the cubit already holds — a refusal without a
/// `return`.
final RegExp _emitsTheSameState = RegExp(r'emit\(\s*(?:this\.)?state\s*\)');

/// The keystroke writers in [source], with their bodies.
List<({String name, List<String> body})> _writersIn(String source) {
  final List<String> lines = withoutDartComments(source).split('\n');
  final List<({String name, List<String> body})> writers =
      <({String name, List<String> body})>[];

  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? declaration = _writerDeclaration.firstMatch(lines[i]);
    if (declaration == null) continue;

    // **THE BODY RUNS TO THE NEXT MEMBER OF THE CLASS.**
    int end = lines.length;
    for (int j = i + 1; j < lines.length; j++) {
      if (_classMember.hasMatch(lines[j]) || _endOfClass.hasMatch(lines[j])) {
        end = j;
        break;
      }
    }

    // **THE NAME IS THE DECLARATION'S OWN**, so there is no second regex
    // that could disagree with the first about which writer this is.
    final String name = declaration.group(1)!;
    writers.add((name: name, body: lines.sublist(i, end)));
  }
  return writers;
}

/// Whether a writer's body can refuse a keystroke.
bool _canRefuse(List<String> body) => body.any(
  (String line) => _returns.hasMatch(line) || _emitsTheSameState.hasMatch(line),
);

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
