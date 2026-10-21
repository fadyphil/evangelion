import 'dart:io';

import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/navigation/role_access.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_import_graph.dart';

/// [RoleAccess] — the role seam navigation reads, and the never-throw
/// obligation it carries.
///
/// ## WHY THIS SUITE EXISTS SEPARATELY FROM `auth_status_test.dart`
///
/// `AuthStatus` asks "is there a session". [RoleAccess] asks a **different**
/// question — "may this screen be offered to this reader" — and the two cannot
/// be merged, because `auth_status.dart:36-40` says in its own words that
/// `isAuthenticated` "must therefore be a plain read of whatever the app
/// currently believes, never a validation". A role check is not a validation
/// and a validation is not a role check; one class answering both violates §3's
/// SRP row ("one reason to change per file") in the shape hardest to see,
/// because both members would be `bool`-shaped and a reader would assume they
/// answered the same question.
///
/// ## AND WHY A CROSS-PRODUCT LOOP RATHER THAN THREE WRITTEN LADDERS
///
/// The obvious suite is `expect(access.allows(manageQuestions), isFalse)` for
/// `kid`, `isFalse` for `viewerServant`, `isTrue` for `adminServant`, written
/// out. That is a **hand transcription of [UserRole.grantsFor]**, and a
/// transcription is a second source of truth: it agrees with the table today
/// and nothing detects the day a seventh capability is added to it. The loops
/// below derive every expectation from `UserRole.grantsFor(role)` itself, so the
/// only thing they can disagree with the implementation about is whether
/// `allows` consulted the table — which is the whole subject.
///
/// The anti-vacuity half sits beside them and is what makes them trustworthy: a
/// loop over a table that granted everything, or nothing, would pass for the
/// wrong reason, so both directions are shown to be populated.
///
/// ## AND WHERE THE GUARD'S OWN HALVES LIVE
///
/// There **is** a role guard in the tree — `lib/app/router/role_guard.dart`,
/// landed with the servant portal's routes — and it reads this seam. This
/// suite used to say there was none, and to point at `user_role.dart`'s
/// record of its own unreferenced conversions; that paragraph described a
/// state that had already stopped being true, and a reader who took it at
/// face value would look for a guard that was right there in `lib/`.
///
/// So the obligation is split across two suites, and the split is
/// deliberate. **Here**, the seam's own halves: the throw **propagates**
/// rather than being absorbed, and the seam contains **no handler that could
/// swallow one** — the property that makes a guard's behaviour predictable
/// rather than hopeful. **There**, in `test/app/router/role_guard_test.dart`,
/// the guard's halves: what the guard does with a seam that breaks its
/// contract, and the fact that it reads the role **once** per decision, so
/// the grant and the refusal's destination are one snapshot.
void main() {
  group('the seam', () {
    test('role reports what the app currently believes, for every role', () {
      for (final UserRole role in UserRole.values) {
        expect(LiveRoleAccess(() => role).role, role);
      }
    });

    test('and one class implements it with no help from the shipped one', () {
      // The `auth_status_test.dart` parallel: the shape a feature or a test is
      // asked to produce, built here from nothing but the interface.
      const UserRole held = UserRole.kid;
      final RoleAccess access = _MutableRoleAccess(() => held);

      expect(access.role, UserRole.kid);
      expect(access.allows(UserCapability.submitQuiz), isTrue);
      expect(access.allows(UserCapability.manageQuestions), isFalse);
    });
  });

  group('allows answers exactly the grant table, over the whole cross product', () {
    for (final ({String label, RoleAccess Function(UserRole Function()) build})
        subject
        in _subjects) {
      test('${subject.label}, for all three roles', () {
        UserRole held = UserRole.kid;
        final RoleAccess access = subject.build(() => held);

        for (final UserRole role in UserRole.values) {
          held = role;
          final Set<UserCapability> granted = UserRole.grantsFor(role);

          for (final UserCapability capability in UserCapability.values) {
            expect(
              access.allows(capability),
              granted.contains(capability),
              reason:
                  'allows($capability) for $role disagreed with '
                  'UserRole.grantsFor, which grants ${granted.length} of '
                  '${UserCapability.values.length} capabilities',
            );
          }
        }
      });
    }

    test('and the cross product is populated in BOTH directions, or the loops '
        'above assert nothing', () {
      // The anti-vacuity half. Each loop is evidence only if it contains at
      // least one pair that must be `true` and at least one that must be
      // `false`: an implementation hard-coded to `true` would otherwise satisfy
      // a table that granted everything, and one hard-coded to `false` a table
      // that granted nothing. The total is compared against the product of the
      // two enumerations rather than written down, because a seventh
      // capability must not invalidate the assertion — the property is "both
      // sides are non-empty and every pair was visited once", not a count.
      int allowed = 0;
      int denied = 0;

      for (final UserRole role in UserRole.values) {
        final RoleAccess access = LiveRoleAccess(() => role);
        for (final UserCapability capability in UserCapability.values) {
          if (access.allows(capability)) {
            allowed++;
          } else {
            denied++;
          }
        }
      }

      expect(allowed, greaterThan(0), reason: 'nothing is ever granted');
      expect(denied, greaterThan(0), reason: 'everything is always granted');
      expect(
        allowed + denied,
        UserRole.values.length * UserCapability.values.length,
        reason:
            'the loop must visit every role/capability pair exactly once — a '
            'smaller total means it skipped some and a larger one means the '
            'table is not the one being walked',
      );
    });
  });

  group('allowsRole answers for the role it is HANDED', () {
    // ## WHY THE SEAM HAS A MEMBER THAT TAKES A ROLE
    //
    // `role_access.dart`'s hazard #2 says a caller that must reason about ONE
    // reader consistently has to capture the role once — because a seam built
    // on a reader guarantees liveness and NOT atomicity, and two reads in one
    // decision can be handed two roles if the app emits in between.
    //
    // The hazard's first draft told such a caller to "pass that to
    // `UserRole.grantsFor` itself", and that would have been the wrong remedy:
    // it makes the caller answer the grant from the TABLE, while the seam
    // answers it from the same table — two copies of one policy, free to
    // drift. Decisions 5 and 68 each removed a second copy of one value in
    // favour of a single source.
    //
    // `allowsRole` is the seam's own answer to that: the role is HANDED in, so
    // the seam is still the one that knows what a role grants, and the caller
    // still gets its answer from the seam rather than from a table of its own.
    // The portal's `RoleGuard` is the consumer this member was written for.

    // The same cross product the `allows` loop walks, with the role supplied
    // rather than read — and the same two implementations, so the shipped one
    // is never the only thing under test.
    for (final ({String label, RoleAccess Function(UserRole Function()) build})
        subject
        in _subjects) {
      test('${subject.label}, for all three roles', () {
        UserRole held = UserRole.kid;
        final RoleAccess access = subject.build(() => held);

        for (final UserRole role in UserRole.values) {
          held = role;
          final Set<UserCapability> granted = UserRole.grantsFor(role);

          for (final UserCapability capability in UserCapability.values) {
            expect(
              access.allowsRole(role, capability),
              granted.contains(capability),
              reason:
                  'allowsRole($role, $capability) disagreed with '
                  'UserRole.grantsFor, which grants ${granted.length} of '
                  '${UserCapability.values.length} capabilities',
            );
          }
        }
      });
    }

    test('and it does NOT read the seam: the role is handed in', () {
      // The property that makes the member worth having. If `allowsRole` read
      // the role for itself, a caller that captured one would be back to two
      // reads — and the role it was handed would be beside the point.
      //
      // The seam here holds `kid` and is asked about `adminServant`, so the
      // two answers differ: a member that read the seam would answer about
      // `kid` and refuse.
      for (final ({
            String label,
            RoleAccess Function(UserRole Function()) build,
          })
          subject
          in _subjects) {
        int reads = 0;
        const UserRole held = UserRole.kid;
        final RoleAccess access = subject.build(() {
          reads++;
          return held;
        });

        final bool granted = access.allowsRole(
          UserRole.adminServant,
          UserCapability.manageQuestions,
        );

        expect(
          reads,
          0,
          reason:
              '${subject.label}.allowsRole read the seam: the role is handed to '
              'it, and a second read is the defect hazard #2 is about',
        );
        expect(
          granted,
          isTrue,
          reason:
              'the answer is about the role HANDED (an admin servant), not the '
              'role the seam happens to hold (a kid)',
        );
      }
    });

    test('and it answers even when the seam behind it could not be read', () {
      // A total function of its argument. The role is handed in, so nothing is
      // read and nothing can fail — which is the other half of "the role is
      // handed": the grant for a role the caller already holds cannot be
      // lost to a broken reader.
      final RoleAccess access = LiveRoleAccess(
        () => throw StateError('role is undefined behaviour'),
      );

      expect(
        () => access.allowsRole(UserRole.kid, UserCapability.submitQuiz),
        returnsNormally,
        reason:
            'the role was handed in, so the seam had nothing to read and nothing '
            'that could throw — a broken reader cannot take an answer away',
      );
    });

    test('and `allows` and `allowsRole` are ONE answer path', () {
      // The seam's own rule, restated as a fact about the code: `allows` MUST
      // answer through `allowsRole`, so a caller that asks either way gets the
      // same answer, and the grant table is consulted in one place.
      //
      // The read count is the half that can catch a divergence, because a
      // second copy of the table would answer the same way while reading the
      // seam a different number of times.
      for (final ({
            String label,
            RoleAccess Function(UserRole Function()) build,
          })
          subject
          in _subjects) {
        for (final UserRole role in UserRole.values) {
          int reads = 0;
          final RoleAccess access = subject.build(() {
            reads++;
            return role;
          });

          for (final UserCapability capability in UserCapability.values) {
            expect(
              access.allows(capability),
              access.allowsRole(role, capability),
              reason:
                  '${subject.label}: allows and allowsRole disagreed for $role / '
                  '$capability, so the seam has two answers for one question',
            );
          }

          expect(
            reads,
            UserCapability.values.length,
            reason:
                'each `allows` reads the role exactly once — a second read per '
                'answer is the two-reads hazard, and zero reads would mean the '
                'answer came from somewhere other than the seam',
          );
        }
      }
    });
  });

  group('the seam is LIVE, not a snapshot', () {
    test('changing the role mid-life flips the answer, in both directions', () {
      // The property that separates a seam from a value. Recorded decision 9's
      // contract 4 is the same claim about `bool`, and `auth_guard_test.dart`
      // pins it by flipping one session and watching the decision move with it.
      // Here the flip walks the whole ladder, because a single pair would not
      // distinguish "live" from "recomputed, with the wrong role": kid and admin
      // servant differ on three capabilities, kid and viewer servant on one.
      UserRole held = UserRole.kid;
      final RoleAccess access = LiveRoleAccess(() => held);

      expect(access.allows(UserCapability.manageQuestions), isFalse);
      expect(access.allows(UserCapability.viewServantReport), isFalse);

      held = UserRole.viewerServant;

      expect(access.role, UserRole.viewerServant);
      expect(access.allows(UserCapability.manageQuestions), isFalse);
      expect(access.allows(UserCapability.viewServantReport), isTrue);
      expect(access.allows(UserCapability.readOwnReading), isTrue);

      held = UserRole.adminServant;

      expect(access.role, UserRole.adminServant);
      expect(access.allows(UserCapability.manageQuestions), isTrue);
      expect(access.allows(UserCapability.viewServantReport), isTrue);
      expect(
        access.allows(UserCapability.readOwnReading),
        isTrue,
        reason:
            'a capability every role holds must stay true across the flip — a '
            'seam answering from the ladder position rather than from the set '
            'loses it at one end',
      );

      held = UserRole.kid;

      expect(
        access.allows(UserCapability.manageQuestions),
        isFalse,
        reason:
            'and back down again, so the property is "follows the role" rather '
            'than "a servant can do more than a child, once"',
      );
    });

    test('and it consults the source on every call rather than caching', () {
      // The mutation this defeats is reading the role once into a field at
      // construction: identical answers to the test above for the FIRST role,
      // and wrong for every later one — recorded decision 9 contract 4, measured
      // there against a real sign-in that left all 1200 tests green. Counting the
      // reads is what distinguishes "consulted the source again" from
      // "consulted a source that happened to change", which comparing answers
      // alone cannot.
      int reads = 0;
      // Never reassigned, and that is the point of the test rather than an
      // oversight: it isolates *how many times* the source was consulted from
      // *what it said*, so a cache is the only thing that can fail it.
      const UserRole held = UserRole.kid;
      final RoleAccess access = LiveRoleAccess(() {
        reads++;
        return held;
      });

      access.allows(UserCapability.submitQuiz);
      final int afterFirst = reads;

      access.allows(UserCapability.submitQuiz);

      expect(
        reads,
        greaterThan(afterFirst),
        reason:
            'a second `allows` must consult the source again; reading it once '
            'and caching makes the seam a snapshot',
      );
    });
  });

  group('the NEVER-THROW obligation', () {
    test('allows never throws, for any role and any capability — including the '
        'pairs whose answer is false', () {
      // "Including the false ones" is the load-bearing half. A guard written as
      // `if (!access.allows(c)) refuse()` reaches `allows` exactly when the
      // answer is `false`, so an implementation that behaves only on the granted
      // half has left its one interesting path untested.
      for (final UserRole role in UserRole.values) {
        final RoleAccess access = LiveRoleAccess(() => role);
        for (final UserCapability capability in UserCapability.values) {
          expect(
            () => access.allows(capability),
            returnsNormally,
            reason: 'allows($capability) threw for $role',
          );
          expect(
            () => access.allowsRole(role, capability),
            returnsNormally,
            reason: 'allowsRole($role, $capability) threw',
          );
        }
      }
    });

    test('a throwing role read PROPAGATES rather than being swallowed', () {
      // `role_access.dart` says MUST NOT throw and, like `auth_status.dart`
      // before it, that a throw is undefined behaviour rather than something the
      // seam absorbs. This is the falsifiable half of that sentence, in the
      // shape of `auth_guard_test.dart`'s "and it does not swallow a throwing
      // seam": a `try`/`catch` around the read turns this red, which is a far
      // cheaper signal than a screen noticing.
      final RoleAccess access = LiveRoleAccess(
        () => throw StateError('role is undefined behaviour'),
      );

      expect(
        () => access.allows(UserCapability.submitQuiz),
        throwsStateError,
        reason:
            'catching here would answer `false` for a role the app simply could '
            'not read, and a silent `false` is indistinguishable from a real '
            'refusal — the argument `auth_guard.dart` records for not catching '
            'a throwing `AuthStatus` either',
      );
    });

    test('and the seam holds no handler that COULD swallow one', () {
      // The structural half, and what makes the behavioural test above a
      // statement about the file rather than about one call site. Comments are
      // stripped first (`withoutDartComments`, the helper every other source
      // gate in this repository uses) because both files *document* the
      // prohibition — a bare `contains('catch')` would fail on their own doc
      // comments.
      //
      // BOTH files, not just `role_access.dart`. `landingRouteFor` is reached
      // from the same navigation code as `allows`, and a `catch` there would be
      // the same defect with the same failure mode — a silent `AppRoutes.home`
      // for a role whose landing could not be computed. The obligation is on
      // the seam, and the seam is both files.
      for (final String path in <String>[_roleAccessPath, _landingRoutePath]) {
        expect(
          _executableSourceOf(path).contains('catch'),
          isFalse,
          reason:
              '$path must have no handler at all: the never-throw obligation '
              'then holds structurally instead of by every call site '
              'remembering not to catch',
        );
      }
    });

    test('and both `catch` scans are looking at executable code, not at '
        'comments', () {
      // The anti-vacuity half that the cross-file positive control below does
      // NOT supply. That control proves the *helper* can still find a `catch`
      // somewhere; it cannot prove this particular file retained code after
      // stripping, because both files are **over 90% documentation by bytes**
      // (`withoutDartComments` leaves ~5% and ~7% of them respectively). A
      // helper regression that over-stripped *these two files* specifically would
      // return an empty string, `contains('catch')` would be `false`, and both
      // gates above would go green while looking at nothing at all.
      //
      // So each file is checked directly: non-empty after stripping, and still
      // carrying a token that can only survive in executable source. The marker
      // is per-file because the two differ in shape — `role_access.dart`
      // declares classes, `landing_route.dart` is a bare `switch` expression
      // with no `class` token at all, so a single `contains('class')` would
      // have gone red on the file it is meant to protect.
      expect(
        _executableMarkerOf,
        hasLength(2),
        reason: 'every file in the `catch` scan needs its own marker',
      );

      for (final MapEntry<String, String> entry
          in _executableMarkerOf.entries) {
        final String source = _executableSourceOf(entry.key);

        expect(
          source.trim(),
          isNotEmpty,
          reason:
              '${entry.key} is empty after comment stripping, so the `catch` '
              'scan beside it is reading an empty string and passing for a '
              'reason that has nothing to do with handlers',
        );
        expect(
          source,
          contains(entry.value),
          reason:
              '${entry.key} kept no `${entry.value}` after stripping, so the '
              'scan is provably not looking at its executable code — this is '
              'the assertion that stops the gate being green on nothing',
        );
      }
    });

    test('and that `catch` scan is not vacuous: it still sees one where there '
        'is one', () {
      // A scanner pointed at a path that does not exist, or one whose comments
      // ate the whole file, finds nothing and passes. `dio_reading_repository`
      // is a real `catch` in executable code in this repository, so the same
      // scanner must report it.
      expect(File(_roleAccessPath).existsSync(), isTrue);
      expect(
        _executableSourceOf(_dioRepositoryPath).contains('catch'),
        isTrue,
        reason:
            'the scanner can still find a handler, which is what makes the '
            'assertion beside it mean something',
      );
    });

    // A hand-written `_ThrowingRoleAccess` used to stand here, asserted to throw
    // on both members. It is deleted rather than repaired: its body was a literal
    // `throw StateError`, so nothing but editing the fixture could turn the
    // assertions red — it proved that a class written to throw throws. The
    // counter-example it was reaching for is already played above by
    // "a throwing role read PROPAGATES rather than being swallowed", which
    // throws through the *shipped* implementation instead of a second one kept
    // alive only to be broken.
  });

  group('the seam cannot express an async read', () {
    test('neither new file declares a Future, a Stream, async or await', () {
      // A structural assertion, and a real one. `auth_status.dart:38-40` says
      // `isAuthenticated` "must therefore be a plain read … never a validation,
      // a token check or a network call" — and an `async` seam is exactly how
      // that promise is broken: the types still compile, the guard call site
      // acquires a `Future` nobody awaits, and the redirect becomes a loading
      // state. Recorded decision 9 spells that cost out. Reading the tokens out
      // of the source makes the property a fact about the file rather than a
      // convention.
      //
      // Dart has no reflection, so there is no way to ask an interface what it
      // declares; a source scan is the honest instrument, and `withoutDartComments`
      // is load-bearing because both files *document* the prohibition.
      for (final String path in <String>[_roleAccessPath, _landingRoutePath]) {
        final String source = _executableSourceOf(path);

        for (final String token in <String>[
          'Future',
          'Stream',
          'async',
          'await',
        ]) {
          expect(
            source.contains(token),
            isFalse,
            reason:
                '$path declares `$token`, so the seam could answer a question '
                'that has to be awaited. `AuthStatus.isAuthenticated` forbids '
                'that in prose and this makes it a fact about the file',
          );
        }
      }
    });

    test('and that token scan is not vacuous: it finds a Future where there is '
        'one', () {
      // Without this, a scanner pointed at a path that does not exist finds
      // nothing and the loop above passes while looking at nothing.
      // `usecase.dart` is pure Dart in the same Gate 1 family as the seam, so
      // it is a fair control: same helper, and a `Future` in executable code.
      expect(
        _executableSourceOf('lib/core/domain/usecase/usecase.dart'),
        contains('Future'),
        reason:
            'the scanner must be able to find a `Future` where one exists, or '
            'the assertion beside it proves nothing',
      );
    });

    test('and the token scan is looking at executable code in BOTH files, not '
        'at comments', () {
      // The same gap the `catch` scan has, and for the same reason: the
      // `usecase.dart` control above proves the HELPER works, not that these
      // two files kept code through it. Both are **over 90% documentation by
      // bytes**, so an over-stripping regression would hand the loop above an
      // empty string and turn a green gate into a claim about nothing.
      //
      // Reuses `_executableMarkerOf` rather than restating the tokens, so the
      // two gates cannot drift apart about which files they are protecting.
      expect(
        <String>{_roleAccessPath, _landingRoutePath},
        _executableMarkerOf.keys.toSet(),
        reason:
            'the token scan walks these two files, so the marker table must '
            'cover exactly them — a tenth entry here would assert on a file no '
            'gate reads, and a missing one would leave it unprotected',
      );

      for (final MapEntry<String, String> entry
          in _executableMarkerOf.entries) {
        final String source = _executableSourceOf(entry.key);

        expect(
          source.trim(),
          isNotEmpty,
          reason:
              '${entry.key} is empty after comment stripping, so the token scan '
              'beside it is reading an empty string',
        );
        expect(
          source,
          contains(entry.value),
          reason:
              '${entry.key} kept no `${entry.value}` after stripping, so the '
              '`Future`/`Stream`/`async`/`await` loop is provably not looking at '
              'its executable code',
        );
      }
    });
  });

  group('Gate 1, transitively', () {
    test('the seam closure is itself plus the role entity, and reaches no '
        'flutter, dio or http', () {
      // `verify_purity.sh` Gate 1 checks a file's OWN directives. It cannot see
      // a file that is itself Flutter-free but imports something that is not,
      // which is precisely how this seam would rot — the day someone reaches
      // for a `BuildContext` or a bloc here to "simplify" it, every direct
      // import gate stays green while the closure goes Flutter-bound. This is
      // `auth_status_test.dart`'s walk, same helper, same reasoning.
      const String entry = 'lib/core/navigation/role_access.dart';
      final Set<String> reachable = reachableProjectFiles(entry);

      for (final String path in reachable) {
        expect(
          forbiddenImportUrisOf(path),
          isEmpty,
          reason:
              '$path must stay Flutter-free: `core/navigation/` is a Gate 1 '
              'pure-Dart directory',
        );
      }

      expect(
        reachable,
        <String>{entry, 'lib/core/domain/entities/user_role.dart'},
        reason:
            'the strongest form of the claim: the seam imports the role entity '
            'and nothing else. One more import and this fails.',
      );
    });

    test('the landing-route closure is itself, the route constants and the '
        'role entity — and reaches no flutter either', () {
      const String entry = 'lib/core/navigation/landing_route.dart';
      final Set<String> reachable = reachableProjectFiles(entry);

      for (final String path in reachable) {
        expect(forbiddenImportUrisOf(path), isEmpty, reason: path);
      }

      expect(reachable, <String>{
        entry,
        'lib/core/navigation/app_routes.dart',
        'lib/core/domain/entities/user_role.dart',
      });
    });
  });
}

/// The implementations the cross-product loops drive.
///
/// Every implementation is driven through the same loop, so the shipped one is
/// never the only thing under test. An interface nobody can implement by hand
/// is an interface whose only implementation is the one being tested —
/// `auth_status_test.dart`'s "one boolean a feature can implement on its own"
/// in the role seam's shape.
///
/// Each subject is built from a *reader* rather than a value because a
/// `RoleAccess` holds its role and a loop has to change it per iteration; the
/// reader is what makes "swap the role, ask again" expressible without either
/// implementation growing a test-only setter.
///
/// **File-level rather than local to one group** because two groups now drive
/// it — the one about `allows` and the one about `allowsRole` — and two
/// copies of a list of implementations is exactly the "second source of truth"
/// shape this suite is about.
final List<({String label, RoleAccess Function(UserRole Function()) build})>
_subjects = <({String label, RoleAccess Function(UserRole Function()) build})>[
  (label: 'LiveRoleAccess', build: LiveRoleAccess.new),
  (label: '_MutableRoleAccess', build: _MutableRoleAccess.new),
];

/// The smallest thing that can implement [RoleAccess], built from the
/// interface alone.
///
/// Two shapes of the same idea sit side by side in this suite because they fail
/// differently. [_MutableRoleAccess] holds its role in a **field**, which is
/// what makes "change it and ask again" expressible without the test growing a
/// setter that production does not have. [LiveRoleAccess] holds a **reader**,
/// which is what the composition root can actually be given — a bloc's state is
/// not a value this client may copy out of it.
///
/// [read] is not optional: a role access with no source would have to invent
/// one, and inventing a default role is exactly the failure this mechanism
/// exists to prevent (`user_role.dart` measures the same shape at the decoder).
final class _MutableRoleAccess implements RoleAccess {
  _MutableRoleAccess(this._read);

  final UserRole Function() _read;

  @override
  UserRole get role => _read();

  @override
  bool allows(UserCapability capability) => allowsRole(role, capability);

  @override
  bool allowsRole(UserRole role, UserCapability capability) =>
      UserRole.grantsFor(role).contains(capability);
}

/// The seam file, named once so a rename is a two-line diff.
const String _roleAccessPath = 'lib/core/navigation/role_access.dart';

/// The landing-route file, named for the same reason.
const String _landingRoutePath = 'lib/core/navigation/landing_route.dart';

/// A repository that genuinely catches, so the `catch` scan has a positive
/// control that is not a comment.
const String _dioRepositoryPath =
    'lib/features/reading/data/repositories/dio_reading_repository.dart';

/// Each file the two structural scans walk, mapped to a token that can only
/// survive comment stripping if executable code is still there.
///
/// **This is the anti-vacuity table for both source gates in this suite.** The
/// cross-file positive controls (`_dioRepositoryPath`, `usecase.dart`) prove the
/// *helper* works; they cannot prove these two files retained code through it,
/// and both are overwhelmingly documentation (over 90% by bytes each), so a
/// helper regression that over-stripped them would return `''`, make every
/// `contains(...)` assertion below false, and turn both gates green while
/// scanning nothing.
///
/// The markers are **per file** rather than one shared token because the two
/// files have different shapes: `role_access.dart` declares classes, while
/// `landing_route.dart` is a single `switch` expression with no `class` token at
/// all. A single `contains('class')` would have gone red on one of the two files
/// it is meant to protect — measured, not assumed.
///
/// The percentages are deliberately **not** written as byte counts: this table
/// lives in a test file, and any statement of the form "this file has N bytes"
/// placed in a comment inside the file being measured is invalidated by the act
/// of writing it. The share of each file that is executable — currently ~5% and
/// ~7%, so over 90% documentation each — is the property that matters here, and
/// it is the one that survives being restated.
const Map<String, String> _executableMarkerOf = <String, String>{
  _roleAccessPath: 'class',
  _landingRoutePath: 'landingRouteFor',
};

/// [path]'s source with every Dart comment removed.
String _executableSourceOf(String path) =>
    withoutDartComments(File(path).readAsStringSync());
