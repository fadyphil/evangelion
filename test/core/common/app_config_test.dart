import 'package:evangelion/core/common/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    group('apiBaseUrl', () {
      test(
        'defaults to the local Evangelion API when no dart-define is set',
        () {
          expect(AppConfig.apiBaseUrl, 'http://localhost:3000');
        },
      );

      test('targets the /api/v1 host without duplicating the prefix', () {
        // The prefix itself belongs to the endpoint definitions, not the base
        // URL, so it must not be baked into the configuration.
        expect(AppConfig.apiBaseUrl, isNot(contains('/api/v1')));
      });
    });

    group('timeouts', () {
      test('connectTimeout is 10 seconds', () {
        expect(AppConfig.connectTimeout, const Duration(seconds: 10));
      });

      test('receiveTimeout is 15 seconds', () {
        expect(AppConfig.receiveTimeout, const Duration(seconds: 15));
      });

      test('receiveTimeout is strictly greater than connectTimeout', () {
        expect(AppConfig.receiveTimeout, greaterThan(AppConfig.connectTimeout));
      });
    });

    group('seeded in-memory-backend identity', () {
      test('seedUserId is the David Mina UUID known to the backend', () {
        expect(AppConfig.seedUserId, '11111111-1111-1111-1111-111111111111');
      });

      test('seedUserId is a valid UUID shape', () {
        // The backend rejects a malformed X-User-Id with 401.
        expect(
          AppConfig.seedUserId,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            ),
          ),
        );
      });

      test('seedGroupId is 3, the only cohort with a working reading', () {
        expect(AppConfig.seedGroupId, 3);
      });

      test('userRole is kid', () {
        expect(AppConfig.userRole, 'kid');
      });
    });
  });
}
