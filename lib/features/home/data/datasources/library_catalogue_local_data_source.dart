import 'package:evangelion/features/home/domain/library_book.dart';

/// The catalogue, transcribed from `eva/redesign.html:1018-1035`.
///
/// ## THIS FILE **IS** ADR-0022'S "NO SCREEN MAY RENDER A HARD-CODED …" — MADE A
/// DATA SOURCE
///
/// The fiction table's library row: **stub** — "hardcoded; **no endpoint
/// enumerates books**", with the correction that per-book passage text is real and
/// only the **order, the names, the counts and the completion** are invented. This
/// is where those four things live, and nothing above this line knows they are
/// invented: `LoadLibraryCatalogue` asks a port, `HomeBloc` holds a
/// `List<LibraryBook>`, and `LibraryCarousel` renders a list.
///
/// **Six books, four open and two sealed, is not a choice this client made.** The
/// prototype draws four in `BOOKS` (`redesign.html:1018-1031`) and two in `SEALED`
/// (`:1032-1035`), the label says "6 scrolls · 4 open" (`:930`), and the six
/// together are what the carousel shows. Choosing a different six would be choosing
/// to disagree with the thing this client is transcribing.
///
/// ## AND EVERY NUMBER HERE IS A TRANSCRIPTION, WITH ITS LINE
///
/// The table below is the file's index. Nothing in it is typed from memory:
///
/// | id | CSS | name / `arName` | category | wash | count |
/// | --- | --- | --- | --- | --- | --- |
/// | `psalms` | `:1005` | `psalms` / `المزامير` | `poetry` | `rgba(228,87,214,.55)` | 6 |
/// | `john` | `:1013` | `john` / `يوحنا` | `gospel` | `rgba(244,227,178,.5)` | 5 |
/// | `genesis` | `:1019` | `genesis` / `التكوين` | `torah` | `rgba(217,142,50,.5)` | 5 |
/// | `isaiah` | `:1025` | `isaiah` / `إشعياء` | `prophets` | `rgba(139,92,246,.5)` | 4 |
/// | `acts` | `:1033` | `acts` / `أعمال الرسل` | `history` | `rgba(211,69,91,.45)` | — |
/// | `revelation` | `:1034` | `revelation` / `الرؤيا` | `apocalypse` | `rgba(211,69,91,.5)` | — |
///
/// **The counts are the prototype's excerpt lengths** — `b.en.length` at
/// `redesign.html:1313` — which are 6, 5, 5 and 4 *lines of a demo corpus*, not
/// Psalm counts and not the 31,104 verses the backend actually holds
/// (`memory_db.ts:151-166`). The card therefore says "poetry · 6 verses" about
/// Psalms, which is what the prototype says and is wrong about the Bible. It is
/// carried because the card's caption line is part of the surface being
/// transcribed, and **a correct count is not available**: no endpoint enumerates
/// books, so any real number here would be a second fiction.
///
/// The sealed books carry **no count** at all, which is the prototype's own
/// distinction rather than a gap: `:1317` writes the category alone for a sealed
/// card because `SEALED` holds no verse array.
final class LibraryCatalogueLocalDataSource {
  /// The data source. Stateless and `const`.
  const LibraryCatalogueLocalDataSource();

  /// The six scrolls, in the order `redesign.html:1311-1318` draws them.
  ///
  /// ## WHY THE ALPHAS ARE PRE-PACKED AND NOT COMPUTED
  ///
  /// `0xAARRGGBB` here is the prototype's `rgba(r,g,b,a)` with `a × 255` rounded
  /// — `.55 → 140 = 0x8C`, `.5 → 128 = 0x80`, `.45 → 115 = 0x73`. Writing them as
  /// literals makes each card's colour readable next to the CSS it came from; a
  /// `Color.fromARGB(0, r, g, b).withValues(alpha: .55)` chain would need
  /// `material.dart` in a data layer and would make the number a computation a
  /// reviewer has to re-derive to check.
  ///
  /// `library_catalogue_local_data_source_test.dart` re-reads the four open
  /// washes out of `eva/redesign.html` and compares them to these values, so the
  /// table above and this list cannot drift apart.
  List<LibraryBook> books() => const <LibraryBook>[
    LibraryBook(
      id: 'psalms',
      nameEn: 'psalms',
      nameAr: 'المزامير',
      category: LibraryCategory.poetry,
      sealed: false,
      bloomArgb: 0x8CE457D6, // rgba(228,87,214,.55)
      verseCount: 6,
    ),
    LibraryBook(
      id: 'john',
      nameEn: 'john',
      nameAr: 'يوحنا',
      category: LibraryCategory.gospel,
      sealed: false,
      bloomArgb: 0x80F4E3B2, // rgba(244,227,178,.5)
      verseCount: 5,
    ),
    LibraryBook(
      id: 'genesis',
      nameEn: 'genesis',
      nameAr: 'التكوين',
      category: LibraryCategory.torah,
      sealed: false,
      bloomArgb: 0x80D98E32, // rgba(217,142,50,.5)
      verseCount: 5,
    ),
    LibraryBook(
      id: 'isaiah',
      nameEn: 'isaiah',
      nameAr: 'إشعياء',
      category: LibraryCategory.prophets,
      sealed: false,
      bloomArgb: 0x808B5CF6, // rgba(139,92,246,.5)
      verseCount: 4,
    ),
    LibraryBook(
      id: 'acts',
      nameEn: 'acts',
      nameAr: 'أعمال الرسل',
      category: LibraryCategory.history,
      sealed: true,
      bloomArgb: 0x73D3455B, // rgba(211,69,91,.45)
    ),
    LibraryBook(
      id: 'revelation',
      nameEn: 'revelation',
      nameAr: 'الرؤيا',
      category: LibraryCategory.apocalypse,
      sealed: true,
      bloomArgb: 0x80D3455B, // rgba(211,69,91,.5)
    ),
  ];
}
