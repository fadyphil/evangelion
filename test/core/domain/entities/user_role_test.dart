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
/// time, the way `login_geometry_test.dart` opens the design reference:
/// `eva/redesign.html` is a file in this repository's tree, and `EvangelionBackend` is read-only
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
///
/// ## THE WIDENING GAP, AND WHY THE OLD NEGATIVES COULD NOT SEE IT
///
/// `user_role.dart` argues at length that accepting a wider set than the
/// protocol declares "is the wrong direction for a fallback to fail". The first
/// version of this suite could not check that argument, because both of its
/// space-bearing negatives (`'kid '` and `'viewer servant'`) are **satisfied by
/// the fallback**: `'kid '` is trimmed to `'kid'` by a buggy `switch
/// (wire.trim())` and still answers `kid`, and `'viewer servant'` has no
/// normalisation that reconstructs a declared role at all. Measured against the
/// pre-fix suite, all three of these left **every test green**:
///
/// | mutation to `fromWire` | red tests, before the fix |
/// | --- | --- |
/// | `switch (wire.trim())` | 0 |
/// | `switch (wire.replaceAll(' ', ''))` | 0 |
/// | extra arm `'admin-servant' => UserRole.adminServant` | 0 |
///
/// The fix is [_wideningCases] plus its test, and the same three mutations are
/// the ones it is measured against. **Every case there is a spelling of a
/// non-kid role**, which is the load-bearing property: the fallback answer and a
/// fold of `'kid'` are the same answer, so a case that can only be laundered
/// into `'kid'` proves nothing.
///
/// ## THE ROUND TRIP IS BLIND TO AN ENCODER TYPO, AND SAYS SO
///
/// `every role survives its own wire value` closes over its own output:
/// mutating `kid('kid')` to `kid('kid ')` leaves it green, because
/// `fromWire('kid ')` answers `kid` by the fallback and the loop compares that
/// against the `kid` it just read. Only the encoder-direction test beside it
/// — which asserts no `wireValue` contains whitespace — turns that mutation
/// red. The round trip is kept, because the property it does check is real and
/// is the reason both functions exist; what it cannot check is now written down
/// next to it instead of being claimed.
///
/// ## [_wideningCases]: A SPELLING AND THE NORMALISATION THAT WOULD ABSORB IT
///
/// Every entry is a spelling of a **non-kid** role that at least one plausible
/// widening launders into a declared one. The `fault` is that laundering, written
/// out, so a red test names its own mutation in the failure message instead of
/// printing a string a reader has to reverse-engineer.
///
/// Entries are ordered by the normalisation they isolate. `trim()` and
/// `replaceAll(' ', '')` are *different* faults and neither subsumes the other:
/// `trim()` leaves an internal space alone, and `replaceAll(' ', '')` leaves a
/// tab alone. One case for each, so deleting any single case loses exactly the
/// mutation it was written for.
const List<({String wire, String fault})> _wideningCases =
    <({String wire, String fault})>[
      (
        wire: ' admin_servant',
        fault:
            'leading space — trim() or replaceAll(\' \', \'\') reads it as'
            ' admin_servant',
      ),
      (
        wire: 'admin_servant ',
        fault:
            'trailing space — trim() or replaceAll(\' \', \'\') reads it as'
            ' admin_servant',
      ),
      (
        wire: '\tadmin_servant',
        // The only case a plain replaceAll(' ', '') cannot catch: a tab is
        // whitespace but not a space, so this one isolates trim() on its own.
        fault:
            'leading tab — trim() reads it as admin_servant, and'
            ' replaceAll(\' \', \'\') cannot, which is why this case exists',
      ),
      (
        wire: 'admin _servant',
        // The counterpart: trim() cannot catch this one, so the internal-space
        // case is not redundant with the padding cases either.
        fault:
            'internal space — replaceAll(\' \', \'\') reads it as'
            ' admin_servant, and trim() cannot',
      ),
      (
        wire: 'admin_s ervant',
        fault:
            'internal space inside the second token —'
            ' replaceAll(\' \', \'\') reads it as admin_servant',
      ),
      (
        wire: 'admin-servant',
        fault:
            'hyphen instead of underscore — an added'
            " 'admin-servant' => adminServant arm absorbs it",
      ),
      (
        wire: 'viewer-servant',
        fault:
            'hyphen instead of underscore on the other non-kid role — an added'
            " 'viewer-servant' => viewerServant arm absorbs it",
      ),
      (
        wire: 'admin  servant',
        fault:
            'a doubled internal space — replaceAll(\' \', \'\') reads it as'
            ' admin_servant',
      ),
    ];
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
      // The round trip is the property the pair of functions exists for: the
      // enumeration means a `fromWire` that forgets a member fails here, and it
      // means a *misspelt* wire value fails here too — as long as the misspelling
      // is not one the decoder happens to accept.
      //
      // ## WHAT IT IS BLIND TO, MEASURED
      //
      // It does **not** catch a typo in the encoder. Mutating `kid('kid')` to
      // `kid('kid ')` left this test GREEN: `fromWire('kid ')` answers `kid` by
      // the fallback, and the loop then compares that against the very `kid` it
      // read the wrong wire value from — the round trip closes over its own
      // output. The earlier comment here claimed it caught exactly that; it did
      // not. The encoder-side guard is the test below, and this one is kept
      // because the property it does check is real.
      for (final UserRole role in UserRole.values) {
        expect(
          UserRole.fromWire(role.wireValue),
          role,
          reason:
              'the wire value ${role.wireValue} did not decode back to $role',
        );
      }
    });

    test('no wire value carries whitespace, so an encoder typo fails', () {
      // The direction the round trip cannot supply, and the one that turns
      // `kid('kid ')` red. Asserted against every member over the enumeration
      // rather than as a literal list, because the list spelling is already held
      // by the wire-names assertion above and this is about a *property* of the
      // spelling, not about which three strings they are: a fourth member typed
      // as `kid('kid  ')` is caught by this, and by no literal list that
      // somebody remembered to update.
      for (final UserRole role in UserRole.values) {
        expect(
          role.wireValue,
          role.wireValue.trim(),
          reason:
              '${role.wireValue} is padded, and a decoder that trims would'
              ' hide it',
        );
        // Padding is what `trim()` catches; an internal space survives `trim()`
        // and is what `replaceAll(' ', '')` would absorb, so the guard has to be
        // the wider "contains no whitespace at all".
        expect(
          role.wireValue.contains(RegExp(r'\s')),
          isFalse,
          reason:
              '${role.wireValue} contains whitespace, which no wire value'
              ' this backend mints contains',
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

    test('a widening normalisation is rejected, not silently absorbed', () {
      // THE MUTATION-CATCHING HALF, and the test the file doc's widening table
      // is measured against. One expectation per case rather than one set, so
      // the `reason` can name the specific normalisation that was accepted — a
      // set comparison would report only "\{kid\} != \{kid, adminServant\}" and
      // leave the reader to work out which case widened.
      //
      // Looped rather than written out eight times so a future normaliser adds
      // one row here rather than one copy of a block, and so the enumeration
      // cannot drift from the doc's claim about which normalisation each row
      // isolates.
      for (final ({String wire, String fault}) widening in _wideningCases) {
        expect(
          UserRole.fromWire(widening.wire),
          UserRole.kid,
          reason:
              'fromWire accepted "${widening.wire}", which is not one of the'
              ' three declared spellings: ${widening.fault}',
        );
      }
    });

    test('a spelling a human types from memory is not a role', () {
      // THE CONFORMANCE HALF, and it is deliberately a separate test. Every
      // case below is a real thing a person or a caller can produce, and each
      // must decode to the fallback — but **none of them can detect a widening
      // decoder**, because no normalisation reconstructs a declared role from
      // any of them. They are kept for the contract they do hold, and split out
      // so that no reader mistakes them for evidence about trimming.
      //
      // `'kid '` is the instructive one: it is the case this file's earlier
      // revision used as its padding coverage, and it was worth nothing for
      // that purpose, because `switch (wire.trim())` answers `kid` to it too.
      expect(UserRole.fromWire('teacher'), UserRole.kid);
      expect(UserRole.fromWire('kid '), UserRole.kid);
      expect(UserRole.fromWire(' kid'), UserRole.kid);
      // The underscore is the separator, not a space and not a hyphen — the two
      // spellings a human writes when typing a role from memory. The hyphen one
      // is also a widening case; it sits here with its sibling for readability
      // and is duplicated in [_wideningCases], where it can fail.
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

  group('UserRole.grantsFor', () {
    test('a kid reads, answers and sees the cohort board — and nothing else', () {
      // The exact set, not three `isNot(contains(…))` assertions: an exact set
      // fails on a grant that was *added* as well as one that was removed,
      // where the negatives catch only the addition. Three roles times three
      // negatives would be nine assertions covering one mutation each, and the
      // set is the same nine claims in nine lines.
      expect(UserRole.grantsFor(UserRole.kid), <UserCapability>{
        UserCapability.readOwnReading,
        UserCapability.submitQuiz,
        UserCapability.viewCohortLeaderboard,
      });
    });

    test('a viewer servant adds the servant report to a kid', () {
      expect(UserRole.grantsFor(UserRole.viewerServant), <UserCapability>{
        UserCapability.readOwnReading,
        UserCapability.submitQuiz,
        UserCapability.viewCohortLeaderboard,
        UserCapability.viewServantReport,
      });
    });

    test(
      'an admin servant is granted exactly the six declared capabilities',
      () {
        expect(UserRole.grantsFor(UserRole.adminServant), <UserCapability>{
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
        UserRole.grantsFor(UserRole.adminServant),
        containsAll(UserCapability.values),
      );
    });

    test('the ladder is monotone: admin ⊇ viewer servant ⊇ kid', () {
      // No exact-set assertion can express this, which is why it is its own
      // test: it is the property the three literal tables rest on, and a future
      // fourth role added beside them would break it if the ladder were not
      // actually a ladder.
      expect(
        UserRole.grantsFor(UserRole.adminServant),
        containsAll(UserRole.grantsFor(UserRole.viewerServant)),
      );
      expect(
        UserRole.grantsFor(UserRole.viewerServant),
        containsAll(UserRole.grantsFor(UserRole.kid)),
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
            () => UserRole.grantsFor(role).add(UserCapability.manageQuestions),
            throwsUnsupportedError,
            reason: 'UserRole.grantsFor($role) handed out a mutable set',
          );
        }
      },
    );
  });
}
