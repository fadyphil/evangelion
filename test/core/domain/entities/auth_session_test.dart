import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// [AuthSession] — red-first (AGENT_CONTEXT §6: domain entities).
///
/// The field list is the plan's, so what is pinned here is the two properties
/// that are not visible in it:
///
/// * **`role` defaults to [UserRole.kid]**, and the default is asserted against
///   the enum rather than against the string `'kid'`. The wire spelling is now a
///   separate claim living in `user_role_test.dart`; keeping it here too would
///   be a second place the wire is transcribed, and this suite's subject is the
///   *field*, not the protocol.
/// * **every field takes part in equality.** A member left out of the generated
///   `==` is a piece of state the app cannot see change, which for a session means
///   a stale one that looks current.
void main() {
  /// A fixed instant, so no assertion depends on the clock.
  final DateTime created = DateTime.utc(2026);

  AuthSession session({
    String userId = '11111111-1111-1111-1111-111111111111',
    String email = 'david@evangelion.app',
    String displayName = 'David Mina',
    String initials = 'DM',
    UserRole role = UserRole.kid,
    DateTime? createdAt,
  }) => AuthSession(
    userId: userId,
    email: email,
    displayName: displayName,
    initials: initials,
    createdAt: createdAt ?? created,
    role: role,
  );

  group('AuthSession', () {
    test('role defaults to UserRole.kid, which is the role this backend parses', () {
      // The **enum**, not the string. `AuthSession.defaultRole` is a `UserRole`
      // now, and asserting it against `'kid'` would be asserting the wire
      // spelling in a file whose subject is the field's default — see the file
      // doc.
      expect(AuthSession.defaultRole, UserRole.kid);
      expect(session().role, UserRole.kid);
    });

    test('two sessions with the same values are equal', () {
      expect(session(), session());
    });

    test('and one differing field makes them unequal', () {
      // Enumerated rather than a single field, because a member left out of the
      // generated `==` is the failure this catches and one field would not find
      // it.
      final Map<String, AuthSession> others = <String, AuthSession>{
        'userId': session(userId: '22222222-2222-2222-2222-222222222222'),
        'email': session(email: 'peter@evangelion.app'),
        'displayName': session(displayName: 'Peter George'),
        'initials': session(initials: 'PG'),
        // A different **role**, and one that is a member of the enum rather than
        // a string the field could not hold: a freezed `==` derives from the
        // constructor, so a field whose type cannot carry the variant would
        // make this entry untestable rather than informative.
        'role': session(role: UserRole.adminServant),
        'createdAt': session(createdAt: created.add(const Duration(days: 1))),
      };

      for (final MapEntry<String, AuthSession> entry in others.entries) {
        expect(
          session() == entry.value,
          isFalse,
          reason: 'a session differing only in ${entry.key} compared equal',
        );
      }
    });
  });
}
