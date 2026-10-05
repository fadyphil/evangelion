import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';

/// The three rows Home's card shows.
///
/// ## WHY `3` AND NOT "ENOUGH TO FILL THE CARD"
///
/// It is a request to the server, so it changes bytes on the wire and the size of the
/// JSON decoded — not a number the card clamps to afterwards. The seeded endpoint
/// returns `total_ranked: 0` and an empty array, so today both values produce the same
/// empty body; the difference shows up the first time a cohort has more than three
/// scorers, and asking then would mean the card's `limit` was never the thing anyone
/// measured.
///
/// Three is also the number the card can show without the reader scrolling, which is
/// the actual constraint. It is one constant rather than a field on `UserSettings`,
/// because a setting for it would be a preference about the design of a widget, not
/// about the reader.
const int kLeaderboardPreviewLimit = 3;

/// The weekly top rows for Home's card.
///
/// A [NoParamsUseCase] rather than a `UseCase<void, LeaderboardBoard>`: AGENT_CONTEXT §6
/// recorded decision 3 says the `extends` clause is illegal Dart for a `void`
/// parameter, so the two-member shape is a standalone interface.
///
/// ## WHY THE WINDOW IS FIXED HERE RATHER THAN TAKEN AS A PARAMETER
///
/// Because `/` has no window control, and a parameter with exactly one caller passing
/// one value is a parameter that will be passed wrong. The segmented control belongs to
/// `/leaderboard`, which owns `LoadLeaderboard` and takes the window as input. When the
/// card grows a control, this becomes `UseCase<LeaderboardWindow, LeaderboardBoard>`
/// and the constant moves with it.
///
/// **Weekly** is also the server's own default for the parameter, so this asks for what
/// an unspecified request would have got.
final class LoadLeaderboardPreview
    implements NoParamsUseCase<LeaderboardBoard> {
  /// Loads the preview through [repository].
  const LoadLeaderboardPreview(this._repository);

  final LeaderboardRepository _repository;

  @override
  Future<Result<LeaderboardBoard>> call() => _repository.board(
    window: LeaderboardWindow.weekly,
    limit: kLeaderboardPreviewLimit,
  );
}
