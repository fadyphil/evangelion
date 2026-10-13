import 'package:freezed_annotation/freezed_annotation.dart';

part 'sky_entry.freezed.dart';

/// One lit verse in the witness sky.
///
/// ## WHY IT IS IN `core/domain/` AND NOT IN ANY ONE FEATURE
///
/// Three consumers, which is §3's placement test. `reading` lights entries as
/// verses scroll into view, `quiz` fires flares for the celebrated moments,
/// and `journey` counts the sky for its widget. A copy inside any one feature
/// would make the other two import it, which §3 forbids with no exceptions
/// and `tool/verify_purity.sh` Gate 2 fails on the line.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// Flutter, no Dio and no `http`. A star is data; the widget that draws it
/// lives in the presentation layer of whichever screen renders the sky.
///
/// ## THE PROTOTYPE IT TRANSCRIBES
///
/// `eva/redesign.html:1143-1159` — `addStar(big)` appends one `.star` `span`
/// per call, evicting the oldest past `starCap` (`:1147`), and `:1167-1185` —
/// `drawConstellation` reads the stars back in that same DOM order for its
/// polyline. So a sky is an *ordered* collection of entries, and the order is
/// lit order: [litAt] is what carries it.
///
/// ## THE FIELDS, AND WHAT EACH ONE IS FOR
///
/// * [book], [chapter], [verse] — the verse this star is. Together they form
///   [key], the `book:chapter:verse` string the repository stores by.
/// * [isFlare] — whether this star is drawn with the `:124` flare keyframes.
///   A verse read lights `addStar(false)` (`:1217`); the three celebrated
///   moments light `addStar(true)` — the cheer (`:1123`), the finished reading
///   (`:1330`) and a correct quiz answer (`:1428`). It defaults to `false`
///   because the ordinary read is the common case and the flare is the marked
///   one.
/// * [litAt] — when the verse was lit. The constellation polylines follow lit
///   order, so the repository keeps entries in [litAt] order and this field is
///   what sorts them.
///
/// ## EQUALITY IS GENERATED, AND DEDUPE IS NOT `==`
///
/// `freezed` (AGENT_CONTEXT §2.1 decision 8a) gives `==` from the constructor,
/// and — per hazard 2 of that same decision — offers no per-field exclusion.
/// So [litAt] and [isFlare] stay inside `==`: a re-lit verse compares *unequal*
/// to its first lighting, and that is deliberate. "Two readings of the same
/// verse produce one entry" is a **repository** property, not an entity one:
/// `SkyRepository` stores by [key], the first lit wins the position, and a
/// flare upgrades in place (see that port's doc for the rule and its test).
/// Excluding the two fields from `==` would make "lit twice" and "lit once,
/// then flared" indistinguishable to every `contains` and `switch` holding
/// entries, which is exactly the spurious-equality cost hazard 2 records for
/// `Failure.details`.
///
/// ## THE **NON-REDIRECTING** CONSTRUCTOR FORM
///
/// `const factory SkyEntry({...}) = _SkyEntry;` — freezed's other documented
/// shape — silently emits a fieldless mixin here (the build succeeds and the
/// analyzer reports `final_not_initialized` against generated code), as
/// recorded on `user_settings.dart:85-100`. This file matches the repository
/// convention instead: the non-redirecting form with its fields declared and
/// documented in place.
///
/// A reader who re-reads John 3:16 sees one star, not two — and the test that
/// holds the boundary is `sky_entry_test.dart`'s "a re-lit verse is NOT `==`",
/// which asserts the entity says "different" so the repository can say "one".
@freezed
final class SkyEntry with _$SkyEntry {
  /// One lit verse.
  const SkyEntry({
    required this.book,
    required this.chapter,
    required this.verse,
    this.isFlare = false,
    required this.litAt,
  });

  /// The book the lit verse belongs to, e.g. `'John'`.
  final String book;

  /// The chapter the lit verse belongs to.
  final int chapter;

  /// The verse that was lit.
  final int verse;

  /// Whether this star is drawn with the flare keyframes.
  ///
  /// `false` for an ordinary read (`eva/redesign.html:1217`), `true` for the
  /// three celebrated moments (`:1123`, `:1330`, `:1428`). Defaults to
  /// `false` — the ordinary read is the common case.
  final bool isFlare;

  /// When the verse was lit, in the order the constellation draws.
  ///
  /// `eva/redesign.html:1143-1159` appends each star after the last and
  /// `:1167-1185` reads them back in that same order, so the repository keeps
  /// entries sorted by this field and a re-lit verse keeps its *first* lit
  /// instant (see `SkyRepository`).
  final DateTime litAt;

  /// The `book:chapter:verse` key the repository stores by.
  ///
  /// `eva/redesign.html:1131-1133` is the `POSRANGE`/defaults/cap context the
  /// starfield lives in: one key, one star, whatever lit it.
  String get key => '$book:$chapter:$verse';
}
