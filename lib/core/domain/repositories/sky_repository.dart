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
/// * [count] — how many stars are lit, for `journey`'s widget
///   (`updateSkyWidget` writes `jSkyN` in `eva/redesign.html:1167-1185`'s
///   neighbourhood). A count rather than a length-of-[entries] so the widget
///   never has to hold the whole sky to draw a number.
/// * [clear] — empties the sky. Two callers, both in the prototype: the cap
///   eviction that removes the oldest star past `starCap`
///   (`eva/redesign.html:1147`), and the Stars-off switch that calls
///   `clearStars()` (`:1483`).
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
/// `sky_repository_test.dart` pins all four arms: order, one-entry,
/// flare-upgrade, and clear.
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
/// * **[entries] is in lit order**, oldest first. A store that cannot order
///   (a set, a map read without sorting) sorts by [SkyEntry.litAt] on the way
///   out, because the constellation draws in that order.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// store, no `Dio` and no `SharedPreferences`. The stub adapter lives in data.
abstract interface class SkyRepository {
  /// Lights [entry], idempotently by [SkyEntry.key].
  ///
  /// A verse never lit is appended, keeping lit order. A verse lit before
  /// keeps its position and its first [SkyEntry.litAt]; a re-record with
  /// [SkyEntry.isFlare] set upgrades the stored entry to a flare in place.
  /// Returns the entry as stored.
  Future<Result<SkyEntry>> record(SkyEntry entry);

  /// The lit entries, oldest first.
  Future<Result<List<SkyEntry>>> entries();

  /// How many entries are lit.
  Future<Result<int>> count();

  /// Empties the sky: the cap eviction's oldest-first removal taken to its
  /// limit, and the Stars-off `clearStars()`.
  Future<Result<void>> clear();
}
