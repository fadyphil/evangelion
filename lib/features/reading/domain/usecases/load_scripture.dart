import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Today's passage, in full, in the reader's language.
///
/// ## WHAT IT ADDS: NOTHING, AND THAT IS THE POINT
///
/// `LoadTodayReading` in `features/home/domain/` already says this at greater
/// length, and the argument is the same: §3's DIP row makes a use case that
/// reclassified an error or reshaped an entity a **second** place where the wire's
/// meaning is decided, and `ApiErrorMapper` plus `TodayReadingMapper` are already
/// it.
///
/// What this class buys is the **seam**: `ReadingCubit` depends on a use case, so a
/// test can hold the request open without a class of its own, and swapping the
/// adapter is a change to one provider in `reading_module.dart` rather than to
/// every caller. `home_bloc_test.dart`'s group for "which section failed" is the
/// precedent, and it could only exist because that seam does.
///
/// ## AND IT IS **NOT** THE SAME USE CASE AS `LoadTodayReading`
///
/// Two use cases over one port, and that is deliberate: they return different
/// types (`ScriptureText` against `TodayReading`), they serve different screens,
/// and §3's ISP row asks for the smallest interface that satisfies a client rather
/// than one fat operation. A single `LoadReading` returning a union would force
/// every caller to narrow before it could read a field.
///
/// Note what that means for the **request count**: `home` and `reading` are
/// different routes and only ever one of them is on screen, so no screen asks for
/// both. A design where a single screen wanted both would issue two `GET`s, and the
/// honest fix for that would be a cache in the adapter — not a merged use case.
final class LoadScripture implements UseCase<ReadingLanguage, ScriptureText> {
  /// Loads today's passage through [repository].
  const LoadScripture(this._repository);

  final ReadingRepository _repository;

  @override
  Future<Result<ScriptureText>> call(ReadingLanguage params) =>
      _repository.todayScripture(language: params);
}
