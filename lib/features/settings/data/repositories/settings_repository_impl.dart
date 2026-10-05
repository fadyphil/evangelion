import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';

/// The only [SettingsRepository] that ships: `shared_preferences`, and nothing else.
///
/// ## IT ADDS **NOTHING** TO THE DATA SOURCE, AND THAT IS THE POINT
///
/// `DioReadingRepository`'s doc gives the long version for the reading side — the
/// mapper owns the wire's meaning and the repository owns transport, so neither can
/// drift — and the same division applies here with one fewer layer. The store already
/// answers every unreadable field with its default (`SettingsLocalDataSource.read`'s
/// doc), so there is nothing here to translate: [load] is the store's `read` and
/// [save] is its `write` plus the `Result` wrapper the port demands.
///
/// ## AND IT WRAPS **THROWING** INTO A TYPED [FailureResult], WHICH IS THE WHOLE
/// ## OF WHAT IT DOES
///
/// `SettingsRepository`'s LSP row says an implementation "never throws". `Shared
/// Preferences.getInstance()` reads from disk over a platform channel, and a
/// platform with no plugin registered throws `MissingPluginException` out of it — a
/// real possibility, and the exact shape of fault `ApiErrorMapper` turns into
/// `FailureKind.network` rather than letting it escape. Both arms of this class are
/// `try`/`catch` over the store and nothing else.
///
/// **Two `try` blocks, and that is the whole class.** `07-file-map.md` §7.1 lists
/// `core/network/api_error_mapper.dart` as one of the four additions new since the
/// original plan, and it is deliberately **not** reused here: there is no HTTP
/// response to map, so `FailureKind.network` is read from `DioExceptionType`'s
/// absence — a channel that is not there is the storage-layer equivalent of a
/// host that is not answering.
final class SettingsRepositoryImpl implements SettingsRepository {
  /// Reads and writes through [store].
  const SettingsRepositoryImpl(this._store);

  final SettingsLocalDataSource _store;

  @override
  Future<Result<UserSettings>> load() async {
    try {
      return Result<UserSettings>.success(await _store.read());
    } on Object catch (error) {
      // `catch (Object)` rather than `catch (Exception)` deliberately: a plugin
      // channel failure arrives as a `PlatformException`, which is an `Exception`,
      // but `MissingPluginException`'s ancestry is not something this file should be
      // asserting, and a settings store that cannot be read must be a typed failure
      // whatever it threw. An `Error` escaping would take the frame with it, so it is
      // caught too — see the class doc.
      return Result<UserSettings>.failure(_unreachable(error));
    }
  }

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async {
    try {
      await _store.write(settings);
      return Result<UserSettings>.success(settings);
    } on Object catch (error) {
      return Result<UserSettings>.failure(_unreachable(error));
    }
  }

  /// The typed failure both arms return.
  ///
  /// **A [FailureKind.storage], which is a kind this repository introduces.**
  ///
  /// `failure.dart` documents its kinds from the HTTP and parsing vocabulary. A local
  /// store has no status code and no body, so reusing `network` for "the preferences
  /// could not be read" would be a claim about a transport this app never makes, and
  /// reusing `serialization` would claim the *value* was unreadable — which
  /// `SettingsLocalDataSource.read` deliberately answers with a default instead.
  ///
  /// A third kind is the honest answer and it is additive: a kind nothing produces yet
  /// is inert, and `failure_test.dart` asserts the set so this addition is visible in a
  /// diff rather than appearing as a new arm in a `switch` with no writer.
  static Failure _unreachable(Object error) => Failure(
    kind: FailureKind.storage,
    message: 'The preferences could not be reached: $error',
  );
}
