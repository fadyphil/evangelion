import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/home/domain/library_book.dart';

/// The scrolls `/`'s carousel offers, in the order the catalogue draws them.
///
/// ## WHY IT IS A PORT AND NOT A CONSTANT LIST IN THE PAGE
///
/// ADR-0022's rule, quoted: "Every stub sits behind a repository port, so replacing
/// invented data with a real endpoint is a change to **one adapter** and no change
/// to a screen. **No screen may render a hard-coded reader, medal, cheer or
/// star**; the fiction lives in data sources, which is where §2 decision 3 already
/// put the seeded session." The book catalogue is the last row of that list this
/// client has to ship, and this is its port.
///
/// The alternative — `const List<LibraryBook>` in the widget or the page — is the
/// arrangement the ADR was written against, and it has a concrete cost beyond
/// tidiness: a test could not substitute a two-book catalogue without a widget
/// override, so every assertion about "the carousel's fourth card" would be an
/// assertion about a literal that a product change edits silently.
///
/// ## WHY IT LIVES IN `features/home/` AND NOT IN `core/domain/`
///
/// §3's placement test is **two or more consumers**, and this has one: `/` renders
/// the carousel (`redesign.html:536`) and nothing else reads a catalogue today.
/// `core/domain/repositories/` holds the six ports whose readers are spread across
/// features — `sky_repository.dart` states its own three-consumer table as the
/// reason — and a seventh port there for a one-consumer fiction would put a
/// document in the shared kernel about a screen's stub.
///
/// The entity is here for the same reason, and ADR-0022's second consumer does not
/// arrive with this one: `/journey` (Task 5.6) derives its rings from
/// `GET /streak`'s `history[]`, and that row carries the **server's** book names
/// (`streak.service.ts:116-118`) rather than the catalogue's. If a later screen
/// needs both, the promotion is `git mv` and an import — and it will be a real
/// decision then, rather than a file moved in advance of a reader.
///
/// ## AND WHY IT IS NOT THE SEEDED-SESSION SHORTCUT
///
/// §2 decision 3 put a hard-coded *reader* behind `FakeAuthRepository` for the same
/// reason this exists, and the difference is that `AuthRepository`'s seed is one
/// reader for a screen that needs a name. The catalogue is six books for a screen
/// that needs six cards, and each of the six carries a colour, a category and a
/// count. The rule is the same either way and the shape is different.
abstract interface class LibraryCatalogueRepository {
  /// Every book the carousel draws, in order — `redesign.html:1311-1318`.
  ///
  /// ## THE ORDER IS THE CATALOGUE'S, AND IT IS **NOT** THE BIBLE'S
  ///
  /// `BOOKS` is `{psalms, john, genesis, isaiah}` and `SEALED` is
  /// `{acts, revelation}` (`redesign.html:1018-1035`), and the carousel draws all
  /// four open books first and then the two sealed ones — which is why the label
  /// reads "6 scrolls · **4 open**". That is a reading order chosen for the demo
  /// (Psalms, a gospel, a Torah book, a prophet, then the two locked behind them),
  /// not canon.
  ///
  /// An implementation therefore returns the order the prototype draws and **does
  /// not sort by [LibraryBook.id], by `book_number` or by any name**: the label's
  /// "4 open" and the sealed flag are the only claims about position this app
  /// makes, and both are satisfied by any order that keeps the open books ahead of
  /// the sealed ones. The first release's adapter satisfies it by construction.
  ///
  /// ## NEVER THROWS, ALWAYS A `Result` (§3, LSP)
  ///
  /// The same promise `StreakRepository` makes, for the same reason: an exception
  /// crossing this seam reaches `HomeBloc`, where nothing catches it. **The shipped
  /// adapter cannot fail** — it is a literal list — and it returns
  /// `Result.of` anyway, so that swapping in a network-backed catalogue needs no
  /// change above the port.
  Future<Result<List<LibraryBook>>> books();
}
