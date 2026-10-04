import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// Today's reading, in the reader's language.
///
/// ## WHY THE LANGUAGE IS THE **PARAMETER** AND NOT A READ FROM SOMEWHERE
///
/// Because §3 forbids a `domain/` file naming anything that is not a port, and a
/// `Locale` is neither pure Dart nor available here — `core/domain/` is held
/// Flutter-free by Gate 1. So the caller supplies the [ReadingLanguage] it already
/// resolved at the presentation edge (`Localizations.localeOf(context)`), and
/// this file never learns where a locale comes from.
///
/// ## WHAT IT ADDS: NOTHING, AND THAT IS THE POINT
///
/// One port call and one return. §3's DIP row makes a use case that reclassified
/// an error or reshaped an entity a **second** place where the wire's meaning is
/// decided, and `ApiErrorMapper` plus `TodayReadingMapper` are already it. What
/// this class buys is the seam: `HomeBloc` depends on a use case, so a test can
/// substitute a slow one without a class of its own, and swapping the adapter is a
/// change to one provider in `home_module.dart` rather than to every caller.
final class LoadTodayReading implements UseCase<ReadingLanguage, TodayReading> {
  /// Loads today's reading through [repository].
  const LoadTodayReading(this._repository);

  final ReadingRepository _repository;

  @override
  Future<Result<TodayReading>> call(ReadingLanguage params) =>
      _repository.today(language: params);
}
