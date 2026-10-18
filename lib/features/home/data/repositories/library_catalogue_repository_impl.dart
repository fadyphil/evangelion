import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/home/data/datasources/library_catalogue_local_data_source.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';

/// The one `LibraryCatalogueRepository` that ships.
///
/// ## IT IS A PASS-THROUGH, AND THAT IS THE POINT
///
/// `LibraryCatalogueLocalDataSource.books()` returns a `const` list of six, so this
/// class does nothing but wrap it in a `Result` and hand it on. Every other
/// adapter in `lib/` is doing work — mapping a body, translating a status — and
/// this one is here so that **the fiction has exactly one file** and the port has
/// exactly one implementation to swap when a books endpoint arrives
/// (ADR-0022: "replacing invented data with a real endpoint is a change to one
/// adapter and no change to a screen").
///
/// ## WHY THE LIST IS COPIED
///
/// `books()` is a `Future`, so a caller cannot mutate the returned list while the
/// future is pending — but it can mutate it afterwards, and the data source's
/// list is a `const` literal that every caller would share. The adapter hands back
/// a fresh `List.unmodifiable` of the books: the catalogue is a value, and
/// `HomeBloc`'s state holding an unmodifiable list is one more place the
/// catalogue cannot be edited from a widget.
///
/// The **books themselves** are immutable and are not copied. They are `const`
/// and the entities carry no mutable field.
final class LibraryCatalogueRepositoryImpl
    implements LibraryCatalogueRepository {
  /// A repository over [dataSource].
  const LibraryCatalogueRepositoryImpl(this._dataSource);

  /// Where the catalogue comes from.
  final LibraryCatalogueLocalDataSource _dataSource;

  @override
  Future<Result<List<LibraryBook>>> books() async {
    // `Result.of` and not a thrown failure: see the port's doc. The shipped
    // adapter has no fault to report, and spelling the success arm explicitly is
    // what lets a network-backed replacement return `Result.left` without any
    // signature change above this line.
    return Result<List<LibraryBook>>.of(
      List<LibraryBook>.unmodifiable(_dataSource.books()),
    );
  }
}
