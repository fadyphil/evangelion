import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';

/// The witness sky: the lit verses, in lit order.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN ANY ONE FEATURE
///
/// Three consumers, which is §3's placement test:
///
/// | consumer | what it asks |
/// | --- | --- |
/// | `reading` | [record], as verses scroll into view (`addStar(false)`) |
/// | `quiz` | [record], with [SkyEntry.isFlare] set, for the celebrated moments |
/// | `journey` | [count] (and [entries]), for the sky widget's star count |
///
/// A port inside any one feature would make the other two import it, which §3
/// forbids with no exceptions and `tool/verify_purity.sh` Gate 2 fails on the
/// line. This is the fifth narrow port of §3's ISP row — four narrow ports, a
/// fat `EvangelionRepository` forbidden — and it appears for the same reason
/// the other four did: the readers are spread across the app.
///
/// ## FOUR METHODS, AND WHAT EACH ONE IS FOR
///
/// * [record] — lights one verse. Idempotent by [SkyEntry.key]: the reader
///   that lights (quiz flares) and the sanctuary that re-lights on scroll
///   both call it, and neither has to check first.
/// * [entries] — the sky in lit order, for the constellation polylines
///   (`eva/redesign.html:1167-1185` read the stars back in DOM order).
/// * [count] — how many stars are lit, for `journey`'s widget, which draws
///   one number (`jSkyN` at `eva/redesign.html:596`, written by
///   `updateSkyWidget` at `:1186-1187`). A count rather than a
///   length-of-[entries] so `journey` depends on the smallest interface that
///   satisfies it (§3, ISP).
/// * [clear] — empties the sky for the Stars-off switch, which calls
///   `clearStars()` (`eva/redesign.html:1483`; defined at `:1135-1136`). The
///   cap trim (`:1147`) is a one-at-a-time eviction inside `addStar`, not a
///   caller of this method — and the cap itself (`starCap`, `44` at `:1131`,
///   re-applied by the slider at `:1487`) is unmodelled: no cap field or
///   method on this port.
///
/// **No `watch`, no stream.** Nothing outside this process writes the sky —
/// the ADR below makes it a local stub — so a `Stream` here would carry at
/// most the values the same process just recorded. The change signal, when a
/// screen needs one, is that screen's own cubit, exactly as `SettingsCubit`
/// owns the settings change signal (see `SettingsRepository`'s doc).
///
/// ## THE DEDUPE RULE, STATED ONCE
///
/// Stored by [SkyEntry.key]. A second record with the same key is **not** a
/// second entry: the first lit wins the position *and* keeps its [SkyEntry.litAt],
/// and a flare upgrades in place — a re-record with [SkyEntry.isFlare] set
/// turns the stored ordinary star into a flare without moving it. So a verse
/// read (`addStar(false)`, `eva/redesign.html:1217`) and later celebrated
/// (`addStar(true)`, `:1123`, `:1330`, `:1428`) is one star that brightens,
/// never two stars and never a star that jumps to the end of the polyline.
///
/// Flare upgrade is MONOTONE: a stored flare is never downgraded by an
/// ordinary re-record. A last-write-wins store would dim a celebrated star
/// (`:1123`, `:1330`, `:1428`) back to an ordinary one on the next scroll
/// re-light (`:1217`) — `sky_repository_test.dart`'s downgrade test fails
/// against exactly that mutation.
///
/// `sky_repository_test.dart` pins six behaviours: lit-event order
/// (including out-of-order records), one entry per verse, flare upgrade,
/// flare monotonicity, clear, and Left propagation. [count] and [clear] ride
/// on the same map the other arms exercise, so those two are consistency
/// checks — `count` agrees with `entries.length`, empty after `clear` —
/// rather than independent behaviours.
///
/// ## STUB STATUS (ADR-0022)
///
/// The starfield is **`stub (local)`** — "a stars table"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:59`) — and **no
/// screen may render hard-coded stars** (`:126-129`): the fiction lives in
/// data sources, which is where §2 decision 3 already put the seeded session.
/// Replacing the stub with a real endpoint is a change to one adapter and no
/// change to a screen, because every reader goes through this port.
///
/// ## WHAT AN IMPLEMENTATION OWES (§3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`.
/// * **Always return a [Result]**, success included. [record] returns the
///   *stored* entry rather than the argument — mirroring `SettingsRepository.save`'s
///   contract — so a caller that re-lights a verse sees the first lit instant
///   it actually holds, never having to re-read to find out.
/// * **[entries] is in lit-event order**, oldest record first. Order is the
///   record sequence — the prototype's DOM-append (`eva/redesign.html:1153`)
///   read back in DOM order (`:1169`), evicting oldest-first (`:1147`) — and
///   [SkyEntry.litAt] is the audit stamp, never the sort key. A store that
///   cannot preserve insertion order must reconstruct the sequence, not sort
///   by [SkyEntry.litAt]: `/reading` lights on scroll, so an earlier verse
///   can be recorded with a later instant and a timestamp sort would draw the
///   polyline backwards. Equal instants need no tiebreak — position comes
///   from the call, not the clock, so two verses lit in the same millisecond
///   are still sequenced.
/// * **A store that cannot be reached reports `FailureKind.storage`**
///   (`failure.dart:83`) — the device-side taxonomy, not `network` (no
///   request was made) and not `serialization` (no value was misread). The
///   sibling `SettingsRepository` names the same kind for the same reason
///   (its `:51-56`).
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// store, no `Dio` and no `SharedPreferences`. The stub adapter lives in data.
abstract interface class SkyRepository {
  /// Lights [entry], idempotently by [SkyEntry.key].
  ///
  /// A verse never lit is appended, keeping lit-event order. A verse lit
  /// before keeps its position and its first [SkyEntry.litAt]; a re-record
  /// with [SkyEntry.isFlare] set upgrades the stored entry to a flare in
  /// place, and the upgrade is monotone — an ordinary re-record never dims a
  /// stored flare. Returns the entry as stored.
  Future<Result<SkyEntry>> record(SkyEntry entry);

  /// The lit entries, oldest record first (lit-event order, never a
  /// [SkyEntry.litAt] sort).
  Future<Result<List<SkyEntry>>> entries();

  /// How many entries are lit.
  Future<Result<int>> count();

  /// Empties the sky: the Stars-off `clearStars()`.
  Future<Result<void>> clear();
}
