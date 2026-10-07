import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// [UserRole] and [UserCapability] — red-first (AGENT_CONTEXT §6: domain
/// entities).
///
/// ## WHAT IS PINNED HERE, AND WHAT IS NOT
///
/// The literals `'viewer_servant'` and `'admin_servant'` are a **transcription**
/// of the backend's own union at `identity.middleware.ts:5`
/// (`role: 'kid' | 'viewer_servant' | 'admin_servant'`), read against
/// `HEAD = 4a1c834`. This suite deliberately does **not** open that file at test
/// time, the way `login_geometry_test.dart` opens `eva/`: `EvaScreen.tsx` is a
/// file in this repository's tree, and `EvangelionBackend` is read-only
/// reference material at another path that may not exist on a fresh clone. A
/// test that cannot load is not a test that can fail, so the provenance is
/// declared here instead — which is the arrangement `test/support/
/// contract_payloads.dart` already uses for the same reason.
///
/// So this suite pins **the client's own contract**: that these three
/// spellings are the wire, that the Dart names are camelCase and the wire names
/// snake_case, that a role survives its own wire value, and that the fallback is
/// [UserRole.kid]. If the backend ever renames a role, this suite stays green
/// and the client silently degrades — the failure this admits is the price of
/// not reaching outside the repository, and it is the same trade
/// AGENT_CONTEXT's §5 recorded facts make.
///
/// ## WHY THE CASE-SENSITIVITY IS ASSERTED AS A SET, AND WHAT IT DOES NOT BUY
///
/// Seven spellings, one assertion, and the answer is "none of these is a role"
/// rather than seven repetitions of [UserRole.kid]. That is a compactness and
/// readability choice, and it is recorded as one because the first version of
/// this comment claimed something stronger and the claim was false.
///
/// **The false claim, kept because the measurement is the useful part.** It said
/// a set comparison was *necessary*, on the reasoning that a folding
/// `fromWire` "would answer `kid` to `'VIEWER_SERVANT'`". Measured: folding on
/// `toLowerCase()` answers **`viewerServant`**, because `viewer_servant` **is** a
/// real role — so a plain `expect(…, UserRole.kid)` catches it on the first
/// spelling, and that mutation turned exactly one test red (this one). The set
/// form was never what caught it.
///
/// **What the pair of directions is actually for.** An implementation that
/// recognises *nothing* and answers `kid` to every string passes the case
/// assertion — correctly, since it folds nothing. Measured: that mutation turns
/// the mapping test and the round-trip test red and leaves this one green. So
/// the negative case assertion and the positive mapping assertion are what
/// close the loop between them, and neither is redundant: a set comparison
/// alone would be satisfied by an implementation that decodes nothing.
void main() {
  group('the three roles, and no fourth', () {
    test('UserRole.values is exactly kid, viewerServant, adminServant, in order', () {
      // Enumerated rather than counted, because a fourth member is a product
      // decision somebody makes by typing, and a count is what they would check.
      // Order is pinned too: it is the backend union's own order, and a ladder
      // read top-down should not reshuffle silently.
      expect(UserRole.values, <UserRole>[
        UserRole.kid,
        UserRole.viewerServant,
        UserRole.adminServant,
      ]);
    });

    test('the Dart names are camelCase and the wire names are snake_case', () {
      // Two assertions rather than one, because the mismatch between them is the
      // whole reason `wireValue` exists: `UserRole.viewerServant.name` is
      // `'viewerServant'`, which is **not** a value the backend has ever seen.
      expect(
        UserRole.values.map((UserRole role) => role.name).toList(),
        <String>['kid', 'viewerServant', 'adminServant'],
      );
      expect(
        UserRole.values.map((UserRole role) => role.wireValue).toList(),
        <String>['kid', 'viewer_servant', 'admin_servant'],
      );
    });

    test('no two roles share a wire value', () {
      // The failure this catches is a copied literal: two members writing
      // `'viewer_servant'`, where every decoded request would be ambiguous and
      // no individual assertion would notice — each member would still be equal
      // to itself.
      expect(
        UserRole.values.map((UserRole role) => role.wireValue).toSet(),
        hasLength(3),
      );
    });

    test('every role survives its own wire value', () {
      // The round trip is the property the pair of functions actually exists
      // for, and it is checked in both directions by the enumeration: a typo in
      // `wireValue` fails here, and so does a `fromWire` that forgets a member.
      for (final UserRole role in UserRole.values) {
        expect(
          UserRole.fromWire(role.wireValue),
          role,
          reason:
              'the wire value ${role.wireValue} did not decode back to $role',
        );
      }
    });
  });

  group('fromWire recognises exactly the backend spellings', () {
    test('and maps each of the three', () {
      expect(UserRole.fromWire('kid'), UserRole.kid);
      expect(UserRole.fromWire('viewer_servant'), UserRole.viewerServant);
      expect(UserRole.fromWire('admin_servant'), UserRole.adminServant);
    });

    test('a string no role declares falls back to kid', () {
      expect(UserRole.fromWire('teacher'), UserRole.kid);
      expect(UserRole.fromWire('kid '), UserRole.kid);
      // The underscore is the separator, not a space and not a hyphen — the two
      // spellings a human writes when typing a role from memory.
      expect(UserRole.fromWire('viewer servant'), UserRole.kid);
      expect(UserRole.fromWire('viewer-servant'), UserRole.kid);
    });

    test('an empty string falls back to kid, because the server reads it as absent', () {
      // Not a guess about this client's own sanity-checking. `identity.middleware.ts:24`
      // is `(request.headers['x-user-role'] as …) || 'kid'`, and in JavaScript an
      // empty string is falsy — so a header sent empty arrives at the server as
      // `kid`. Answering anything else here would be the client disagreeing
      // with the server about what it just received.
      expect(UserRole.fromWire(''), UserRole.kid);
    });

    test('the Dart spelling is not a wire value and decodes to kid', () {
      // Pinned because it is the mistake this type exists to prevent: a caller
      // reaches for `.name`, sends `'viewerServant'`, and the server stores a
      // role that is in none of its three declared values.
      expect(UserRole.fromWire('viewerServant'), UserRole.kid);
      expect(UserRole.fromWire('adminServant'), UserRole.kid);
    });

    test('case is NOT folded: only the three declared spellings are accepted', () {
      // One assertion over seven spellings rather than seven over one. The
      // `admin_servant`/`viewer_servant` folds are the load-bearing two: a
      // folding implementation answers a *real* role for them, so this fails on
      // the first of those rather than on the fallbacks. See the file doc for
      // what this assertion does not buy on its own.
      expect(
        <UserRole>{
          for (final String spelling in <String>[
            'KID',
            'Kid',
            'VIEWER_SERVANT',
            'Viewer_Servant',
            'viewerservant',
            'ADMIN_SERVANT',
            'Admin_Servant',
          ])
            UserRole.fromWire(spelling),
        },
        <UserRole>{UserRole.kid},
        reason: 'a capitalised spelling was accepted as a role',
      );
    });
  });

  group('grantsFor', () {
    test('a kid reads, answers and sees the cohort board — and nothing else', () {
      // The exact set, not three `isNot(contains(…))` assertions: an exact set
      // fails on a grant that was *added* as well as one that was removed,
      // where the negatives catch only the addition. Three roles times three
      // negatives would be nine assertions covering one mutation each, and the
      // set is the same nine claims in nine lines.
      expect(grantsFor(UserRole.kid), <UserCapability>{
        UserCapability.readOwnReading,
        UserCapability.submitQuiz,
        UserCapability.viewCohortLeaderboard,
      });
    });

    test('a viewer servant adds the servant report to a kid', () {
      expect(grantsFor(UserRole.viewerServant), <UserCapability>{
        UserCapability.readOwnReading,
        UserCapability.submitQuiz,
        UserCapability.viewCohortLeaderboard,
        UserCapability.viewServantReport,
      });
    });

    test(
      'an admin servant is granted exactly the six declared capabilities',
      () {
        expect(grantsFor(UserRole.adminServant), <UserCapability>{
          UserCapability.readOwnReading,
          UserCapability.submitQuiz,
          UserCapability.viewCohortLeaderboard,
          UserCapability.viewServantReport,
          UserCapability.scheduleReading,
          UserCapability.manageQuestions,
        });
      },
    );

    test('and no capability is unreachable, so no enum member is dead', () {
      // The pair to the exact set above, and it catches the opposite fault: a
      // seventh `UserCapability` declared and granted to nobody, which every
      // grant assertion above would pass straight over. Recorded decision 57
      // refused a verse-number flag for exactly this reason — a capability with
      // no consumer is state nobody reads.
      expect(
        grantsFor(UserRole.adminServant),
        containsAll(UserCapability.values),
      );
    });

    test('the ladder is monotone: admin ⊇ viewer servant ⊇ kid', () {
      // No exact-set assertion can express this, which is why it is its own
      // test: it is the property the three literal tables rest on, and a future
      // fourth role added beside them would break it if the ladder were not
      // actually a ladder.
      expect(
        grantsFor(UserRole.adminServant),
        containsAll(grantsFor(UserRole.viewerServant)),
      );
      expect(
        grantsFor(UserRole.viewerServant),
        containsAll(grantsFor(UserRole.kid)),
      );
    });

    test(
      'the returned set is unmodifiable, so a grant table cannot be widened',
      () {
        // Looped over every role rather than one, because a `Set.of(…)` in a single
        // branch would be invisible from the other two. Enumerated over
        // [UserRole.values] so a fourth role is covered by writing nothing.
        for (final UserRole role in UserRole.values) {
          expect(
            () => grantsFor(role).add(UserCapability.manageQuestions),
            throwsUnsupportedError,
            reason: 'grantsFor($role) handed out a mutable set',
          );
        }
      },
    );
  });
}
