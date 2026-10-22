import 'dart:io';

import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/freezed_types.dart';
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

      // `SignInParams` — the fourth subject, and the one this test **omitted**.
      //
      // The file's own doc names it ("`SignInParams` (`sign_in.dart`), which was
      // never an `Equatable` at all and carries its own hand-written `==`,
      // `hashCode` and `toString`") and the scan above covers it, but the behavioural
      // half asserted against the other three only. So the rule was half-enforced: the
      // scan proved `SignInParams` declares a `toString`, and nothing proved the
      // declared one masks. A body that interpolated `password` would have kept every
      // test in this file green.
      const SignInParams params = SignInParams(
        email: 'reader@example.com',
        password: secret,
        role: UserRole.kid,
      );
      expect(params.toString(), contains('reader@example.com'));
      expect(params.toString(), isNot(contains(secret)));
      expect(params.toString(), contains('********'));

      // And its equality, which is the other half of what it hand-wrote. Without it
      // the class cannot be compared in a `Set` or matched by `Bloc` state, and a
      // careless `==` would make two different passwords equal.
      expect(
        params,
        const SignInParams(
          email: 'reader@example.com',
          password: secret,
          role: UserRole.kid,
        ),
      );
      expect(
        params,
        isNot(
          const SignInParams(
            email: 'reader@example.com',
            password: 'a-different-secret-entirely',
            role: UserRole.kid,
          ),
        ),
      );
      expect(params, isNot(equals(Object())));

      // **And the ROLE is part of that equality**, which the servant portal's
      // Task 1 added to the class. Two params that differ only in the role are
      // different params — a `==` that ignored it would let a bloc think
      // nothing changed when the reader picked a different role.
      expect(
        params,
        isNot(
          const SignInParams(
            email: 'reader@example.com',
            password: secret,
            role: UserRole.adminServant,
          ),
        ),
      );
    });
  });

  // ## THE **CHILD** A **ROSTER** IS ABOUT
  //
  // The rule above is about a **secret** — a credential, and a thing that must
  // never be in a log. This one is about **a person**: a **child** this client
  // shows to somebody else. The servant's cohort and the communion board are
  // rosters of children, and their names and ids are **other people's
  // children's** data — the server sent it, and this client is the one that
  // writes it into a console, a crash report, or a failed `expect`.
  //
  // **AND THE SHAPE OF THE RULE IS THE SAME, BECAUSE THE SHAPE OF THE RISK
  // IS.** freezed's generated `toString` lists every property, so the same
  // override the password rule asks for is the override this one asks for —
  // and the same structural scan finds the classes that need it.
  group('no class holding a child may print the child', () {
    late final List<File> sources = _dartSourcesIn('lib');
    late final Map<String, String> bodies = _classBodies(sources);
    late final Map<String, Set<String>> holders = _childHolders(bodies);

    test('the scan is not vacuous — it finds the classes that hold a child', () {
      expect(
        holders.keys,
        containsAll(<String>[
          'RosterStudent',
          'ServantReport',
          'LeaderboardRow',
          'LeaderboardBoard',
        ]),
        reason:
            'these hold a child or a roster of them; if this fails the scan is '
            'broken, not the code. Every class it finds must mask — that is the '
            'next two assertions.',
      );
    });

    test('every class that holds a child declares its own toString', () {
      // **AND ONLY THE FREEZED ONES, BECAUSE ONLY THEY LEAK.** A plain class's
      // `toString` is `Instance of 'X'` — it carries no field at all — so
      // asking a plain class for an override would be asking for noise. A
      // **freezed** class gets a generated `toString` that lists every
      // property, and that is the one this rule is about.
      final Set<String> freezed = freezedTypeNamesInLib();
      final List<String> offenders = <String>[];

      for (final MapEntry<String, Set<String>> entry in holders.entries) {
        if (!freezed.contains(entry.key)) continue;
        final String body = bodies[entry.key]!;
        final RegExpMatch? toString = RegExp(r'String\s+toString\s*\(\)\s*=>')
            .firstMatch(body);
        if (toString == null) {
          offenders.add(
            '${entry.key} holds a child and has no toString override, so freezed '
            'generates one that lists every field — the name, the id and the '
            'roster',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a class holding a child with no toString override writes that '
            'child into every log line. freezed would generate one and '
            'reintroduce this.',
      );
    });

    test("no class's toString carries the child's name, id or roster", () {
      final List<String> offenders = <String>[];

      for (final MapEntry<String, Set<String>> entry in holders.entries) {
        final String body = bodies[entry.key]!;
        final RegExpMatch? toString = RegExp(
          r'String\s+toString\s*\(\)\s*=>(.*?);',
          dotAll: true,
        ).firstMatch(body);
        final String? printed = toString?.group(1);
        if (printed == null) continue;
        for (final String field in entry.value) {
          if (RegExp('\\\$\\{?$field\\b').hasMatch(printed)) {
            offenders.add('${entry.key}.toString carries `$field`');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a toString that carries the child writes that child to every log '
            'line that touches the value — and the roster carries every child '
            'at once',
      );
    });

    test('and the running classes do not print the child — the behavioural half', () {
      // A structural check cannot tell a correct override from an empty one, so
      // the property is asserted against the running classes too. Same file, so
      // the structural and behavioural halves of one rule cannot drift apart.
      //
      // The name is a phrase that cannot occur by coincidence, so a match means
      // a leak and not a substring accident.
      const String name = 'Peter-Ilias-Georgiou';
      const String id = '99999999-8888-7777-6666-555555555555';

      const RosterStudent student = RosterStudent(
        userId: id,
        fullName: name,
        preferredLang: 'en',
        totalPoints: 120,
        currentStreak: 4,
        pointsEarnedToday: 10,
        completedToday: true,
        questionsProgress: '3/5',
      );
      expect(student.toString(), isNot(contains(name)));
      expect(student.toString(), isNot(contains(id)));

      const ServantReport report = ServantReport(
        groupId: 3,
        reportDate: '2026-10-21',
        totalStudents: 1,
        completedCount: 1,
        students: <RosterStudent>[student],
      );
      expect(report.toString(), isNot(contains(name)));
      expect(report.toString(), isNot(contains(id)));

      const LeaderboardRow row = LeaderboardRow(
        rank: 1,
        score: 40,
        initials: 'PG',
        userId: id,
        fullName: name,
        currentStreak: 4,
      );
      expect(row.toString(), isNot(contains(name)));
      expect(row.toString(), isNot(contains(id)));

      const LeaderboardBoard board = LeaderboardBoard(
        window: LeaderboardWindow.weekly,
        groupId: 3,
        rows: <LeaderboardRow>[row],
        standing: LeaderboardStanding(rank: 2, score: 30),
        cohortSize: 12,
      );
      expect(board.toString(), isNot(contains(name)));
      expect(board.toString(), isNot(contains(id)));
    });

    // The negative control for this rule, and the reason the scan above can be
    // trusted: a scan with no control is indistinguishable from a scan that
    // was never blind. The password rule above has one; this one needs its
    // own, and it needs **both** shapes — the child and the roster.
    test(
      'a planted class that holds a child is found, and its leak is seen',
      () {
        final Directory dir = Directory.systemTemp.createTempSync('child_gate');
        addTearDown(() => dir.deleteSync(recursive: true));
        final File planted = File('${dir.path}/planted.dart')
          ..writeAsStringSync('''
/// A planted row, holding a child's name and printing it.
library;

final class PlantedChild {
  const PlantedChild({required this.fullName, required this.userId});

  final String fullName;

  final String userId;

  @override
  String toString() => 'PlantedChild(fullName: \$fullName)';
}

/// A planted roster, holding the children and printing the roster.
final class PlantedRoster {
  const PlantedRoster({required this.children});

  final List<PlantedChild> children;

  @override
  String toString() => 'PlantedRoster(children: \$children)';
}
''');

        final Map<String, String> bodies = _classBodies(<File>[planted]);
        final Map<String, Set<String>> holders = _childHolders(bodies);

        // **THE CHILD**, and the two fields of its identity.
        expect(
          holders.keys,
          contains('PlantedChild'),
          reason:
              'the scan reads a declared `fullName` and nothing else — a class '
              'that holds a child must be found by that declaration alone',
        );
        expect(
          holders['PlantedChild'],
          containsAll(<String>[kChildNameField, kChildIdField]),
          reason: 'and the name and the id are what it may not print',
        );

        // **AND THE ROSTER**, which is found in the second pass — and which
        // carries the children without ever naming one.
        expect(
          holders.keys,
          contains('PlantedRoster'),
          reason:
              'a class that holds a roster of children is found by the '
              'declaration of the list, and the list is what it may not print',
        );
        expect(holders['PlantedRoster'], contains('children'));

        // **AND BOTH LEAKS ARE VISIBLE**, so the interpolation check is not a
        // check over nothing.
        for (final MapEntry<String, Set<String>> entry in holders.entries) {
          final RegExpMatch? toString = RegExp(
            r'String\s+toString\s*\(\)\s*=>(.*?);',
            dotAll: true,
          ).firstMatch(bodies[entry.key]!);
          expect(
            toString,
            isNotNull,
            reason: '${entry.key} declares a toString',
          );
          final String printed = toString!.group(1)!;
          final bool leaks = entry.value.any(
            (String field) => RegExp('\\\$\\{?$field\\b').hasMatch(printed),
          );
          expect(
            leaks,
            isTrue,
            reason: '${entry.key}.toString prints one of ${entry.value}',
          );
        }
      },
    );
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
///
/// **AND IT IS A **DECLARATION**, NEVER A **MENTION**.** The word "password"
/// appears in this repository's prose, in field names like `passwordError`, and
/// in the arguments of a constructor — and a scan that matched any of those
/// would report classes that hold no secret at all. A **declared field** is the
/// only thing that carries one.
Map<String, String> _classesHolding(List<File> sources, String field) =>
    _classesDeclaring(
      _classBodies(sources),
      RegExp(
        r'^\s*final\s+String\??\s+' + field + r'\s*(?:=[^;]*)?;',
        multiLine: true,
      ),
    );

/// Map of class name to that class's source text, for every class in [bodies]
/// whose body **declares** something matching [declaration].
///
/// ## AND THE **SLICING** IS **ONE IMPLEMENTATION**
///
/// The body of a class runs to the start of the next class in the same file, or
/// to the end of the file. Two rules need that boundary — the password rule
/// and the child rule — and two copies of it would be two things to keep in
/// step, which is the drift §7 warns about. So the boundary is computed once,
/// by [_classBodies], and the two rules filter the same map.
Map<String, String> _classesDeclaring(
  Map<String, String> bodies,
  RegExp declaration,
) {
  final Map<String, String> found = <String, String>{};

  for (final MapEntry<String, String> entry in bodies.entries) {
    // Per CLASS, not per file. Testing the file and then flagging every class
    // in it reports offenders that hold no secret at all — the first version
    // of this scan named `LoginValidation`, whose only fields are
    // `emailError` and `passwordError`.
    if (!declaration.hasMatch(entry.value)) continue;
    found[entry.key] = entry.value;
  }

  return found;
}

/// Map of class name to that class's source text, for every class in [sources].
///
/// The body runs from the end of the class's name to the start of the next
/// class in the same file, or to the end of the file.
///
/// ## WHY THE **BODY** AND NOT THE **FILE**
///
/// Per class, not per file: testing the file and then flagging every class in
/// it reports offenders that hold no secret at all. The first version of this
/// scan named `LoginValidation`, whose only fields are `emailError` and
/// `passwordError` — it was in the same file as `LoginCredentials`.
Map<String, String> _classBodies(List<File> sources) {
  final Map<String, String> bodies = <String, String>{};
  final RegExp classStart = RegExp(
    r'^(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*class\s+(\w+)',
    multiLine: true,
  );

  for (final File file in sources) {
    final String text = withoutDartComments(file.readAsStringSync());
    final List<RegExpMatch> classes = classStart.allMatches(text).toList();

    for (int i = 0; i < classes.length; i++) {
      final RegExpMatch m = classes[i];
      final int end = i + 1 < classes.length
          ? classes[i + 1].start
          : text.length;
      bodies[m.group(1)!] = text.substring(m.end, end);
    }
  }

  return bodies;
}

/// The field that carries **a child's name**, and the server's own key for it.
///
/// The server sends `full_name` — the roster's own row (`admin.routes.ts:404`)
/// and the board's row alike — and both classes that hold a child's name from
/// the server spell it `fullName`. So the key is **the server's**, and a class
/// added tomorrow that holds a child's name spells it the same way.
const String kChildNameField = 'fullName';

/// The field that carries **a child's id**, and the server's own key for it.
///
/// `user_id` — the roster's row (`admin.routes.ts:403`) and the board's row
/// alike. The id is the other half of the identity: it is the key the cheer
/// is recorded against, and it is not unique in the way a name is not, so
/// neither is a thing to print.
const String kChildIdField = 'userId';

/// The field that carries **the initials derived from a child's name**.
///
/// `initials` — the board's own two-letter monogram. The house's words for it
/// are "one or two letters standing in for the child, never their name", so a
/// `toString` that prints them still carries a piece of the child's name, and
/// this rule treats that as the name it is.
const String kChildInitialsField = 'initials';

/// The child's identity, in **every form** this client carries it.
///
/// The name, the id, the initials derived from the name, and — for a class
/// that holds a roster — the roster that holds them all.
const Set<String> kChildIdentityFields = <String>{
  kChildNameField,
  kChildIdField,
  kChildInitialsField,
};

/// Map of class name to the fields that class may not print, for every class
/// that holds a child's identity.
///
/// ## AND THERE ARE **TWO** SHAPES, AND BOTH ARE FOUND BY A **DECLARATION**
///
/// * a class that **declares** a `String` field named [kChildNameField] — it
///   holds **a child**;
/// * a class that **declares** a `List<X>` field where `X` is such a class —
///   it holds **a roster of children**, and the roster is every child at once.
///
/// The second shape is found in a **second pass**, because it can only be
/// found once the first pass has said which classes hold a child. A roster
/// holder's own `toString` does not have to interpolate the name to carry it:
/// it interpolates the **roster**, and the roster carries the names.
///
/// ## AND THE **FIELDS** ARE **WHAT EACH CLASS MAY NOT PRINT**
///
/// A class that holds a child may not print the name or the id, and a class
/// that holds a roster may not print the roster field. A class that holds both
/// — a row that carried a roster of its own — would carry both sets.
Map<String, Set<String>> _childHolders(Map<String, String> bodies) {
  final Map<String, Set<String>> holders = <String, Set<String>>{};

  final Map<String, String> named = _classesDeclaring(
    bodies,
    RegExp(
      r'^\s*final\s+String\??\s+' + kChildNameField + r'\s*(?:=[^;]*)?;',
      multiLine: true,
    ),
  );
  for (final String name in named.keys) {
    holders[name] = <String>{...kChildIdentityFields};
  }

  // **THE SECOND PASS**, over the classes the first pass found.
  final RegExp roster = RegExp(
    r'^\s*final\s+List<(\w+)\??>\??\s+(\w+)\s*(?:=[^;]*)?;',
    multiLine: true,
  );
  for (final MapEntry<String, String> entry in bodies.entries) {
    for (final RegExpMatch match in roster.allMatches(entry.value)) {
      if (!named.containsKey(match.group(1))) continue;
      holders
          .putIfAbsent(entry.key, () => <String>{...kChildIdentityFields})
          .add(match.group(2)!);
    }
  }

  return holders;
}
