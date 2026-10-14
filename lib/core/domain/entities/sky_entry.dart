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
/// per call (`:1153`), evicting the oldest past `starCap` (`:1147`), and
/// `drawConstellation` reads the stars back in that same DOM order (`:1169`)
/// for its polyline. So a sky is an *ordered* collection of entries, and the
/// order is lit-event order: the sequence of `record` calls. [litAt] is the
/// audit stamp of each event, not the sort key — see its field doc and
/// `SkyRepository`'s order rule, which state the one definition together.
///
/// ## THE FIELDS, AND WHAT EACH ONE IS FOR
///
/// * [book], [chapter], [verse] — the verse this star is. Together they form
///   [key], the `book:chapter:verse` string the repository stores by.
/// * [isFlare] — whether this star is a **flare**: drawn at a fixed 5px with
///   the wide halo from `starShadows` (`:1137-1142`, `:1148`) rather than the
///   3–5px ordinary draw. A verse read lights `addStar(false)` (`:1217`); the
///   three celebrated moments light `addStar(true)` — the cheer (`:1123`), the
///   finished reading (`:1330`) and a correct quiz answer (`:1428`). It defaults
///   to `false` because the ordinary read is the common case and the flare is
///   the marked one.
///
///   **This doc once said "drawn with the `:124` flare keyframes", and that
///   became false when `WitnessSky` landed** — the `:124` keyframes are a
///   one-shot ring that ends at a **transparent** shadow, and reproducing it
///   faithfully would mean one `AnimationController` per star under a design
///   system whose whole §13.2 argument is that four ambient clocks is the
///   number. What is rendered is the flare's *resting* appearance, which is what
///   the prototype itself leaves on screen after 900ms. `witness_sky.dart`'s
///   class doc carries the full reasoning and the rejected alternatives.
/// * [litAt] — when the verse was lit: the audit stamp of the lit event, not
///   the sort key. Order is the record sequence (`SkyRepository`'s rule); a
///   re-lit verse keeps its *first* instant, and equal instants need no
///   tiebreak because position never comes from the timestamp.
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

  /// Whether this star is a **flare**.
  ///
  /// `false` for an ordinary read (`eva/redesign.html:1217`), `true` for the
  /// three celebrated moments (`:1123`, `:1330`, `:1428`). Defaults to
  /// `false` — the ordinary read is the common case.
  ///
  /// **What a flare IS, precisely** — a fixed 5px size (`:1148`, where an
  /// ordinary star is `3 + rand*2`) and the wide halo from `starShadows`
  /// (`:1137-1142`): `14px`/`30px` in dark and `10px`/`20px` in light, against
  /// `8px`/`16px` and `6px`/`12px` for an ordinary star.
  ///
  /// **What it is NOT, and this line was wrong until `WitnessSky` landed.** It
  /// read "whether this star is drawn with the flare keyframes", which promised
  /// a rendered animation the widget does not draw. The `:124` declaration is
  /// `flare .9s var(--e-light) 1` — a one-shot `box-shadow` ring running
  /// `0 0 0 0 rgba(255,255,255,.9)` → `0 0 0 22px rgba(255,255,255,0)` (`:126`),
  /// i.e. it **ends at nothing**. Two reasons it is not ported, both carried in
  /// `witness_sky.dart`'s class doc: it would need one controller per star
  /// against §13.2's four-clock budget, and its end state — which is what a
  /// reader sees 900ms later, and what §14's reduced-motion rule jumps to — is
  /// exactly the resting appearance described above.
  ///
  /// **On a polygon shape the flare is the size alone.** `s-dot` rounds its
  /// border box, so its `box-shadow` survives; `s-star`, `s-cross` and
  /// `s-diamond` are `clip-path`ed, and an outer shadow is drawn outside the
  /// border edge only (CSS Backgrounds 3 §6.1.1). For those three the fixed 5px
  /// is the whole of the difference. See `skyClipsPaint`.
  final bool isFlare;

  /// When the verse was lit.
  ///
  /// The audit stamp of the lit event, carried verbatim — including through
  /// `copyWith(isFlare: true)`, which is how a flare upgrade keeps the first
  /// instant. It is never the sort key: the repository orders by record
  /// sequence (lit-event order), so two verses lit in the same millisecond
  /// are still sequenced and no tiebreak exists.
  final DateTime litAt;

  /// The `book:chapter:verse` key the repository stores by.
  ///
  /// `eva/redesign.html:1131-1133` is the `POSRANGE`/defaults/cap context the
  /// starfield lives in: one key, one star, whatever lit it.
  ///
  /// The `int` segments make the key injective over verses, but there is no
  /// inverse: a book name containing `:` would parse ambiguously, so no
  /// `fromKey` is offered.
  String get key => '$book:$chapter:$verse';
}
