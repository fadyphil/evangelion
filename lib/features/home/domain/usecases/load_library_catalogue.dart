import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';

/// The scrolls the carousel draws.
///
/// A [NoParamsUseCase] like `LoadStreakSummary`, for §6 decision 3's reason: the
/// two-member shape is a standalone interface and `usecase()` is the only spelling
/// that compiles.
///
/// ## WHY THIS IS A USE CASE AND NOT A FIELD THE BLOC HOLDS
///
/// The catalogue is a **constant**, and the cheapest spelling of that is a
/// `const` list the bloc holds. It is not the spelling that survives the ADR: the
/// moment a books endpoint exists, `LibraryBook` becomes a mapping of a response
/// and the "fetch" needs a port, a data source and a failure arm — a state machine
/// with three statuses, a retry, and a card that has to render an error. Every one
/// of those is already built for the four sections `/` does have, and **none of it
/// has to be built twice** if the section exists from the start.
///
/// So the section is there in Phase 5.2 with its one difference that the failure
/// arm is unreachable: the shipped adapter is a literal list and returns
/// `Result.of`. `home_bloc_test.dart` says so where a reader can check it rather
/// than leaving it to be discovered when the adapter stops being literal.
final class LoadLibraryCatalogue implements NoParamsUseCase<List<LibraryBook>> {
  /// Loads the catalogue through [repository].
  const LoadLibraryCatalogue(this._repository);

  final LibraryCatalogueRepository _repository;

  @override
  Future<Result<List<LibraryBook>>> call() => _repository.books();
}
