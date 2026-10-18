import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_book.freezed.dart';

/// Which part of the canon a [LibraryBook] belongs to.
///
/// `redesign.html:1036-1037` — `CATS = {poetry, gospel, torah, prophets, history,
/// apocalypse}` — and an enum rather than the six strings for the reason
/// `GreetingPeriod` is one: a `switch` over it is exhaustive, so a seventh category
/// arriving tomorrow is a compile error in every consumer rather than a missing
/// translation discovered on the Arabic arm.
///
/// **Which is why the label is an ARB key and not a field.** The category's *name*
/// is a translation decision (`CATS` holds `["poetry","شعر"]`), and §5's rule is
/// that a translated string does not arrive as data. The *book's* names are the
/// other way round — see [LibraryBook.nameEn].
enum LibraryCategory {
  /// `poetry` — `شعر`. `redesign.html:1036`.
  poetry,

  /// `gospel` — `إنجيل`. `redesign.html:1036`.
  gospel,

  /// `torah` — `توراة`. `redesign.html:1036`.
  torah,

  /// `prophets` — `أنبياء`. `redesign.html:1036`.
  prophets,

  /// `history` — `تاريخ`. `redesign.html:1036`, and only a sealed book carries it.
  history,

  /// `apocalypse` — `رؤيا`. `redesign.html:1036`, and only a sealed book carries it.
  apocalypse,
}

/// One book in `/`'s carousel.
///
/// ## THIS IS THE ADR-0022 FICTION TABLE'S ONE STUB ON THIS SCREEN, IN ENTITY FORM
///
/// `redesign.html:536` draws the library as a horizontal strip of books, and
/// ADR-0022's row for it reads: **stub** — "hardcoded; **no endpoint enumerates
/// books**". The correction under it is the part that shaped this entity: "the
/// library's *catalogue* is the fiction, not its text" — `GET /bible/verses/{ar,en}`
/// really does serve any book's passage, and what is invented is the **order, the
/// names, the counts and the completion**.
///
/// So every field here is one of those four, and none of it pretends otherwise:
/// there is no `id` the server recognises (the prototype's are `psalms`, `acts`),
/// and the catalogue is the fixture. The data source that produces these is the
/// ADR's "one adapter" — when a books endpoint arrives, `LibraryBook` does not
/// move and no screen changes.
///
/// ## WHY THE NAMES ARE FIELDS AND THE CATEGORY IS AN ENUM
///
/// **The asymmetry is deliberate and it is the translation rule.** A book's name
/// is *data* — `المزامير` is how the catalogue spells Psalms, not how this app
/// translates the word — so it arrives as a field with one value per arm. A
/// *category* is a closed set the app itself labels, so its six names are ARB keys
/// and the widget resolves them; see [LibraryCategory].
///
/// ## AND WHY `bloomArgb` IS AN `int` IN A FLUTTER-FREE FILE
///
/// Because the prototype's per-book hue is one of the invented things — `--bh` is
/// written on each element (`redesign.html:1312`, `:1315`) and `GlassSurface`'s
/// `bloomColor` takes a `Color`, so the value has to cross the domain boundary
/// somehow. A packed ARGB `int` crosses it as data, and `flutter/material.dart`
/// does not. The alternative — a presentation-side `Map<String, Color>` keyed by
/// id — would put the fiction in a widget file, which is the arrangement ADR-0022
/// exists to forbid ("the fiction lives in data sources").
@freezed
final class LibraryBook with _$LibraryBook {
  /// A catalogue entry.
  const LibraryBook({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.category,
    required this.sealed,
    required this.bloomArgb,
    this.verseCount,
  });

  /// The catalogue's own key — `psalms`, `acts`. **Not a server id.**
  ///
  /// It is the carousel's `ValueKey` and the `dict` key of `BOOKS`/`SEALED`
  /// (`redesign.html:1312`, `:1033`), which is a local lookup and nothing else: no
  /// endpoint takes it, and `GET /bible/verses` takes a `book_number` this client
  /// has no catalogue of. Recorded because an id that looks like a wire id is the
  /// kind of field a later author will pass to a request.
  final String id;

  /// The English name, as the catalogue spells it — `psalms`, lower-case.
  ///
  /// **Lower-case and not capitalised**, because the card is where the prototype
  /// puts it and `:1313` writes `s.name` uncapitalised while `:1033`'s *sealed
  /// sheet* capitalises (`openSealed`, `:1043`). The card's own line is
  /// `${b.name}` and this is that.
  final String nameEn;

  /// The Arabic name — `المزامير`.
  final String nameAr;

  /// Which part of the canon, for the card's caption line.
  final LibraryCategory category;

  /// Whether this scroll is sealed.
  ///
  /// `redesign.html:1032-1035` — two of the six are in `SEALED` and the label
  /// reads "6 scrolls · 4 open", so the sealed set is **four-and-two by
  /// construction** and the label's arithmetic follows from this flag rather than
  /// from a second count that could disagree with it.
  ///
  /// **The unlock rule is NOT modelled.** ADR-0022 prices it: "`finish Isaiah to
  /// unseal Acts` (`:1033`, `:733`) is invented", and the sheet it would open
  /// (`openSealed`, `:1039-1048`) is not part of Task 5.2's range. When the rule
  /// arrives it is a second field beside this one, not a reinterpretation of it.
  final bool sealed;

  /// The card's wash — the prototype's per-book `--bh`, packed as `0xAARRGGBB`.
  ///
  /// Transcribed, not derived from the book's `hsl`: `BOOKS` carries both
  /// (`redesign.html:1019-1031`) and they are **not the same colour** — genesis is
  /// `hsl(33,69%,52%)`, which is `rgb(217,124,48)`, beside the
  /// `rgba(217,142,50,.5)` it is drawn with. The card draws `--bh`, so that is
  /// what this is, and the `hsl` is the reader's shader hue (`:1350`,
  /// `setTargetHue(b.hsl,…)`) which no widget on this screen reads.
  ///
  /// **The alpha is the prototype's own and it is not `.55` throughout** — the four
  /// open books are `.55 / .5 / .5 / .5` and the two sealed are `.45 / .5`. The
  /// wash's own fade is [`kGlassBloomFadeStop`], so this is the colour at the
  /// bottom edge of the card and nothing multiplies it except the light-mode
  /// dimmer `GlassSurface` applies. See `glass_surface.dart`'s
  /// `kGlassBloomFadeStop`, which is where the gradient's own fade lives.
  final int bloomArgb;

  /// How many verses the card's caption counts — `6` for psalms.
  ///
  /// **`null` for a sealed book, and that is the prototype's own distinction:**
  /// `redesign.html:1317` writes `${CATS[s.cat][li()]}` for a sealed card and
  /// `:1313` writes `${CATS[b.cat][li()]} · ${N(b.en.length)} ${tr('verses')}` for
  /// an open one — because `SEALED` holds no verse array at all. A non-null count
  /// on a sealed card would be a number this client has no source for.
  final int? verseCount;
}
