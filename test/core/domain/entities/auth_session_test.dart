import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// [AuthSession] — red-first (AGENT_CONTEXT §6: domain entities).
///
/// The field list is the plan's, so what is pinned here is the two properties
/// that are not visible in it:
///
/// * **`role` defaults to `kid`**, which is a protocol value and not a
///   privilege — AGENT_CONTEXT §5, trap 7 says `X-User-Role` is parsed and never
///   checked, so nothing in this app may gate on it.
/// * **every field takes part in equality.** A member left out of `props` is a
///   piece of state the app cannot see change, which for a session means a stale
///   one that looks current.
void main() {
  /// A fixed instant, so no assertion depends on the clock.
  final DateTime created = DateTime.utc(2026, 1, 1);

  AuthSession session({
    String userId = '11111111-1111-1111-1111-111111111111',
    String email = 'david@evangelion.app',
    String displayName = 'David Mina',
    String initials = 'DM',
    String role = 'kid',
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
    test('role defaults to kid, which is the role this backend parses', () {
      expect(AuthSession.defaultRole, 'kid');
      expect(session().role, 'kid');
    });

    test('two sessions with the same values are equal', () {
      expect(session(), session());
    });

    test('and one differing field makes them unequal', () {
      // Enumerated rather than a single field, because a member left out of
      // `props` is the failure this catches and one field would not find it.
      final Map<String, AuthSession> others = <String, AuthSession>{
        'userId': session(userId: '22222222-2222-2222-2222-222222222222'),
        'email': session(email: 'peter@evangelion.app'),
        'displayName': session(displayName: 'Peter George'),
        'initials': session(initials: 'PG'),
        'role': session(role: 'leader'),
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
