import 'dart:io';

import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_import_graph.dart';

/// A gate on a **structural** property, so it survives code generation.
///
/// ## WHAT IT FORBIDS
///
/// Any class in `lib/` that holds a `password` field must declare its own
/// `toString`, and that `toString` must not interpolate the password.
///
/// **Four classes hold a password today**, and each declares its own: three
/// converted — `LoginCredentials` (`login_credentials.dart`), `AuthState` and
/// `AuthPasswordChanged` (`auth_bloc.dart`) — and `SignInParams`
/// (`sign_in.dart`), which was never an `Equatable` at all and carries its own
/// hand-written `==`, `hashCode` and `toString`.
///
/// The default is the same in both worlds and that is why this gate survived the
/// migration unchanged: Equatable's default `toString` printed every entry in
/// `props`, and **freezed's generated one lists every property**. Either way a
/// secret-holding class without an override writes the secret into every log
/// line, every crash report, and every failed `expect` that prints the value.
///
/// ## WHY IT IS A SOURCE SCAN AND NOT A BEHAVIOURAL TEST
///
/// A behavioural assertion ("`toString()` does not contain the password") passes
/// today and is worth having — `secret_masking_test.dart` has it. But it only
/// covers the classes somebody remembered, and it says nothing about a class
/// added tomorrow.
///
/// This one discovers its own subjects. That matters because `freezed` is being
/// adopted, and freezed **generates `toString`**. It skips the member when the
/// class declares one, so the fix is available — but nothing in a green suite
/// distinguishes "freezed respected my override" from "freezed replaced it and
/// my password is now in the logs". This gate is what distinguishes them.
///
/// The scan is the same shape as `injection_test.dart`'s cross-feature import
/// scan, extended in Phase 7 for the same reason: a property that only a
/// reviewer would otherwise notice is a property nobody notices.
void main() {
  group('no class holding a password may print it', () {
    late final List<File> sources = _dartSourcesIn('lib');

    test('the scan is not vacuous — it finds the classes that hold one', () {
      expect(
        sources,
        isNotEmpty,
        reason: 'a scan that reads no files passes everything',
      );
      expect(
        _classesHolding(sources, 'password').keys,
        containsAll(<String>[
          'LoginCredentials',
          'AuthPasswordChanged',
          'AuthState',
        ]),
        reason:
            'these mask deliberately; if this fails the scan is broken, '
            'not the code. Every entry it finds must mask — that is the next '
            'two assertions.',
      );
    });

    test('every class with a password field declares its own toString', () {
      final List<String> offenders = <String>[];

      for (final MapEntry<String, String> entry in _classesHolding(
        sources,
        'password',
      ).entries) {
        final RegExpMatch? toString = RegExp(r'String\s+toString\s*\(\)\s*=>')
            .firstMatch(entry.value);
        if (toString == null) {
          offenders.add(
            '${entry.key} holds a password and has no toString override, so '
            'Equatable prints every prop',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a secret-holding class with no toString override leaks into '
            'logs. freezed would generate one and reintroduce this.',
      );
    });

    test("no class's toString interpolates a password", () {
      final List<String> offenders = <String>[];

      for (final MapEntry<String, String> entry in _classesHolding(
        sources,
        'password',
      ).entries) {
        final RegExpMatch? toString = RegExp(
          r'String\s+toString\s*\(\)\s*=>(.*?);',
          dotAll: true,
        ).firstMatch(entry.value);
        final String? body = toString?.group(1);
        if (body == null) continue;
        if (RegExp(r'\$\{?password\b').hasMatch(body)) {
          offenders.add('${entry.key}.toString interpolates the password');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a toString that interpolates the secret writes it to every '
            'log line that touches the value',
      );
    });

    // The negative control for the stripper fix, and the reason the stripper is
    // the shared one. A scan improvement with no control is indistinguishable
    // from a scan that was never blind.
    test('a class hidden behind a `/*` in a doc comment is still found', () {
      // Exactly the shape that used to be invisible: a doc comment containing a
      // glob-shaped path, then — further down the same file — a class that holds
      // a password and prints it.
      final Directory dir = Directory.systemTemp.createTempSync('secret_gate');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File planted = File('${dir.path}/planted.dart')
        ..writeAsStringSync('''
/// The reading endpoint's own copy, per `readings/today/*.current_streak`.
library;

final class PlantedHolder {
  const PlantedHolder({required this.password});

  final String password;

  @override
  String toString() => 'PlantedHolder(password: \$password)';
}
''');

      final Map<String, String> found = _classesHolding(<File>[
        planted,
      ], 'password');
      expect(
        found.keys,
        contains('PlantedHolder'),
        reason:
            'the scan read past the `/*` inside the doc comment. Before the '
            'shared stripper it saw an empty file and reported nothing, '
            'which is the silent-pass shape this gate has to avoid',
      );
      expect(
        RegExp(r'\$\{?password\b').hasMatch(found['PlantedHolder']!),
        isTrue,
        reason:
            'and the body it reports is the class body, so the '
            'interpolation check below can see the leak',
      );
    });

    test('every masking class masks — the behavioural half', () {
      // A structural check cannot tell a correct override from an empty one, so
      // the property is asserted against the running classes too. Same file, so
      // the structural and behavioural halves of one rule cannot drift apart.
      //
      // The secret is a phrase that cannot occur by coincidence anywhere in the
      // class, so a match means a leak and not a substring accident.
      const String secret = 'correct-horse-battery-staple';

      const LoginCredentials credentials = LoginCredentials(
        email: 'reader@example.com',
        password: secret,
      );
      expect(credentials.toString(), contains('reader@example.com'));
      expect(credentials.toString(), isNot(contains(secret)));
      expect(credentials.toString(), contains('********'));

      const AuthPasswordChanged changed = AuthPasswordChanged(secret);
      expect(changed.toString(), isNot(contains(secret)));
      expect(changed.toString(), contains('********'));

      const AuthState state = AuthState(
        status: AuthSessionStatus.signedOut,
        email: 'reader@example.com',
        password: secret,
      );
      expect(state.toString(), contains('reader@example.com'));
      expect(state.toString(), isNot(contains(secret)));
      expect(state.toString(), contains('********'));
    });
  });
}

/// Every `.dart` file under [root], recursively.
List<File> _dartSourcesIn(String root) {
  final Directory dir = Directory(root);
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
}

/// Map of class name to that class's source text, for every class in [sources]
/// that declares a field of type `String` named [field].
///
/// ## COMMENTS ARE STRIPPED WITH THE **SHARED** STRIPPER, AND THAT IS A FIX
///
/// This scan used its own per-line `//` + `/* … */` cut. `lib/` is prose-heavy
/// and writes glob-shaped paths in prose — `home_bloc.dart:8` says
/// `` `readings/today/*.current_streak` ``, `streak_summary.dart:119` says
/// `` `readings/today/*` ``, and `submit_result.dart:44` says the same — so for
/// each of those files the first `/*` **inside a doc comment** opened a block
/// comment that ran to the end of the file, and every class below it became
/// invisible to this scan.
///
/// Measured: the naive stripper found **none** of `HomeEvent`, `HomeCleared`,
/// `HomeStarted`, `HomeRetried` and `HomeState`. None of them holds a password
/// today, so the gate was green over a hole — which is the worst state a gate can
/// be in, because a leak planted in one of those classes would have shipped with
/// a green run behind it.
///
/// [withoutDartComments] decides `//` before `/*`, handles nested blocks and
/// apostrophes, and **throws** on an unbalanced scan rather than returning a
/// plausible answer. `no_colour_literals_test.dart` holds its behavioural tests.
///
/// Comments are stripped first. Without that, `class\s+(\w+)` matches prose —
/// this repository's doc comments say "class doc" and "the class rule" often
/// enough to invent classes named `doc` and `rule`, and the scan then reports
/// offenders that do not exist. That is the failure mode of every regex gate in
/// this project: right answer, unreachable reason.
///
/// The class pattern carries its modifiers because a bare `class\s+` does not
/// find `final class`, and every entity and state here is declared `final`.
Map<String, String> _classesHolding(List<File> sources, String field) {
  final Map<String, String> found = <String, String>{};
  final RegExp declaration = RegExp(
    '^\\s*final\\s+String\\??\\s+$field\\s*(?:=[^;]*)?;',
    multiLine: true,
  );
  final RegExp classStart = RegExp(
    r'^(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*class\s+(\w+)',
    multiLine: true,
  );

  for (final File file in sources) {
    final String text = withoutDartComments(file.readAsStringSync());
    final List<RegExpMatch> classes = classStart.allMatches(text).toList();

    for (int i = 0; i < classes.length; i++) {
      final RegExpMatch m = classes[i];
      // The body runs to the start of the next class, or to end of file.
      final int end = i + 1 < classes.length
          ? classes[i + 1].start
          : text.length;
      final String body = text.substring(m.end, end);

      // Per CLASS, not per file. Testing the file and then flagging every class
      // in it reports offenders that hold no secret at all — the first version
      // of this scan named `LoginValidation`, whose only fields are
      // `emailError` and `passwordError`.
      if (!declaration.hasMatch(body)) continue;
      found[m.group(1)!] = body;
    }
  }

  return found;
}
