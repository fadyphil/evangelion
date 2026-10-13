import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sky_state.freezed.dart';

/// Where the witness sky is in its own short lifecycle.
///
/// Two values and **not** one, and `ReadingStatus` gives the argument verbatim: a
/// two-value enum has to encode "still asking" as "no data", which is how a screen
/// ends up unable to tell *still asking* from *asked and there was nothing*.
///
/// Here the distinction is smaller but it is the same one. [loading] means the
/// cubit has **not yet read** the store — which is a fact a reader can see, because
/// the sky starts empty and a reader who lit verses yesterday sees none for a
/// frame. [ready] means the stored answer is on screen.
enum SkyStatus {
  /// The stored sky has not been read yet, so the cubit is holding no stars and
  /// says so.
  loading,

  /// The stored sky is on screen.
  ready,

  /// The store could not be reached. [SkyState.failure] is non-null, the last
  /// confirmed sky is still on screen, and the reader's next record may still
  /// succeed.
  failed,
}

/// The witness sky's state: the lit entries in lit-event order, and nothing else.
///
/// ## [entries] IS **ALWAYS** POPULATED, INCLUDING ON FAILURE
///
/// The first version `SettingsState` ever had was `UserSettings?` and emptied it
/// while loading, which is the shape that is **wrong** here for the same measured
/// reason: `journey`'s widget draws one number from this state on every frame, and a
/// nullable list would make it handle "there is nothing yet" — and the sky in
/// particular has no honest answer for it, because an empty sky is already a state
/// this app can render. So [entries] carries **no stars** while loading and keeps
/// the last confirmed stars after a failure, and [status] says which of the two the
/// reader is looking at.
///
/// ## [entries] IS IN LIT-EVENT ORDER, AND [count] IS NOT A SECOND COPY
///
/// The constellation polylines read the stars back in DOM order
/// (`eva/redesign.html:1169`), so the list is the record sequence oldest-first —
/// never a `litAt` sort — exactly as `SkyRepository.entries` promises. [count] is a
/// getter over that same list rather than a second field, because a field could
/// disagree with the list it counts and nothing would notice: `journey` depends on
/// the smallest interface that satisfies it (§3, ISP), and the getter is that
/// interface without a second source of truth.
@freezed
final class SkyState with _$SkyState {
  /// The lit sky, oldest record first.
  ///
  /// ## [entries] IS **REQUIRED**, FOR THE GENERATOR REASON `SettingsState` NAMES
  ///
  /// It reads as though `this.entries = const <SkyEntry>[]` would do, and it does
  /// not — measured on `SettingsState`, not assumed: `freezed` moves a constructor
  /// default into its generated `copyWith`/`==` and then **revives** the constant
  /// expression, and reviving a list of a generated type fails while the
  /// `.freezed.dart` files are themselves being generated. So the default is
  /// written at the one place that constructs the first state — the cubit's
  /// `super(...)` — which is where it reads better anyway: "the sky starts empty"
  /// is a statement about the sky, and it is visible there.
  const SkyState({
    required this.entries,
    this.status = SkyStatus.loading,
    this.failure,
  });

  /// Where the read is.
  final SkyStatus status;

  /// The lit entries, oldest record first — the record sequence, never a
  /// [SkyEntry.litAt] sort.
  final List<SkyEntry> entries;

  /// Why the store could not be reached, or `null`.
  final Failure? failure;

  /// How many stars are lit: `journey`'s widget draws this one number
  /// (`eva/redesign.html:1186-1187`).
  ///
  /// **A getter and not a field**, so it cannot disagree with [entries]: the port
  /// carries `count` as a separate arm because `journey` depends on the smallest
  /// interface that satisfies it, and this is that arm without a second copy.
  int get count => entries.length;
}
