import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';

/// The one [MedalRepository] that ships.
///
/// ## IT IS A PASS-THROUGH, AND THAT IS THE POINT
///
/// `MedalLocalDataSource.shelf()` returns a shelf of four literals, so
/// this class does almost nothing: it wraps the shelf in a `Result` and hands
/// it on. Every other adapter in `lib/` is doing work — mapping a body,
/// translating a status — and this one is here so that **the fiction has
/// exactly one file** and the port has exactly one implementation to swap when
/// an achievements endpoint arrives (ADR-0022: "replacing invented data with a
/// real endpoint is a change to one adapter and no change to a screen").
///
/// ## AND IT **NEVER THROWS**, WHICH IS THE PART THAT IS NOT A PASS-THROUGH
///
/// §3's LSP row: "never throws across the seam, always returns `Result`". A
/// data source that cannot produce a shelf throws — that is its contract — and
/// this class turns the throw into a typed failure, because an exception
/// crossing this seam reaches the journey's cubit, where nothing catches it.
///
/// **The shipped stub cannot fail**, and the catch is here anyway: it makes
/// "never throws" a property of the **port** rather than of the one adapter
/// that happens to ship today, and it is the whole difference between a
/// failing shelf and a crash.
final class MedalRepositoryImpl implements MedalRepository {
  /// A repository over [dataSource].
  const MedalRepositoryImpl(this._dataSource);

  /// Where the shelf comes from.
  final MedalLocalDataSource _dataSource;

  @override
  Future<Result<MedalShelf>> shelf() async {
    try {
      return Result<MedalShelf>.of(_dataSource.shelf());
    } on Object catch (error) {
      // `catch (Object)` and not `catch (Exception)`, for the reason
      // `SkyRepositoryImpl`'s doc measures: a fault that crosses a seam arrives
      // as whatever crossed it, and an `Error` escaping would take the frame
      // with it.
      return Result<MedalShelf>.left(_unreadable(error));
    }
  }

  /// The typed failure a shelf that cannot be read produces.
  ///
  /// **A [FailureKind.unknown]**, and not one of the narrower kinds: there is
  /// no transport here to call it `network`, no response body to call it
  /// `serialization`, and no device store to call it `storage`. `unknown` is
  /// exactly "a fault with no better classification", and it is never a
  /// fallback for success — this arm is a failure, and it says which one.
  static Failure _unreadable(Object error) => Failure(
    kind: FailureKind.unknown,
    message: 'The medal shelf could not be read: $error',
  );
}
