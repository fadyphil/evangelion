import 'package:evangelion/core/domain/entities/user_settings.dart';

/// How many stars the witness sky holds before the oldest is evicted.
///
/// The prototype's `starCap` (`eva/redesign.html:1131`, re-pinned at `:1512`):
/// `addStar` removes the oldest `.star` `while(starCount() >= starCap)` *before*
/// appending (`:1147`) — effective max exactly 44 — and the slider re-trims to
/// it (`:1486-1487`).
///
/// ## WHY IT LIVES HERE, IN `features/sky/domain/`, AND NOT ON THE PORT
///
/// Two writers need this one number — `SkyRepositoryImpl.record` (which evicts)
/// and `SkyCubit`'s optimistic frame (which must show the eviction before the
/// store answers) — and the dependency direction is strictly inward
/// (`presentation → domain ← data`), so neither may import it from the other.
/// `SkyRepository`'s doc says the cap "is unmodelled: no cap field or method on
/// this port", and that file is frozen — so the number lives in the feature's own
/// pure-Dart domain, which both writers already reach. A second copy in either
/// writer would be the "two implementations of one number" drift this repository
/// rejects wherever it finds it.
///
/// ## AND NOW THE CAP IS **THE READER'S CHOICE** — WHICH IS WHAT MAKES THIS A
/// ## POLICY AND NOT A CONSTANT
///
/// `eva/redesign.html:669` puts a range on the Star-count slider
/// (`min="0" max="60" value="44"`) and `:1486-1487` writes the reader's choice
/// into the prototype's `starCap` and re-trims the sky to it. **The client's
/// `UserSettings.starCount` IS that variable** (`core/domain/entities/
/// user_settings.dart`), and its default is 44 — the same literal as
/// [skyStarCap].
///
/// ### THE NUMBER IS STILL IN ONE PLACE, AND IT IS STILL THIS FILE
///
/// A preference does not dissolve the argument this file exists to make. There
/// are three facts and each has exactly one home:
///
/// | fact | home |
/// | --- | --- |
/// | the **default** cap (44) | [skyStarCap], here |
/// | the **range** the reader may choose (0…60) | `kStarCountMin` / `kStarCountMax`, in `core/domain/entities/user_settings.dart` |
/// | the **clamp** that turns a chosen count into a cap | `clampStarCount`, in the same place — and [skyStarCapFor] is this feature's name for it |
/// | the **live** cap | the reader's `UserSettings.starCount` — the settings cubit's state |
///
/// The two writers hold **no cap of their own**: each asks a *cap reader* — an
/// `int Function()` — and clamps whatever it is told with [skyStarCapFor]. Two
/// writers asking one reader cannot disagree about the number, which is the
/// whole point of the file.
///
/// **AND THE RANGE IS IN THE SHARED KERNEL RATHER THAN TWICE, ONCE.** The
/// range is the *star count preference's* range, and the preference is in
/// `core/domain/`; the sky's writers need it too, and a feature may not import
/// another feature (Gate 2). So the range and its clamp live with the field
/// they bound, and this file names them.
///
/// **The two spellings of 44 that exist are pinned by a test**, not by a shared
/// declaration: `core/domain/` may not name `features/sky/` — AGENT_CONTEXT §3,
/// Gate 2 — so `UserSettings`'s default literal and [skyStarCap] cannot be one
/// declaration. `sky_star_cap_test.dart` is what keeps them in step.
///
/// ### WHY THE READER IS A **SEAM** AND NOT A VALUE
///
/// The composition root builds both writers (`sky_module.dart`,
/// `navigation_injection.dart`) and the reader changes the cap at runtime, so a
/// cap handed over at construction would be a snapshot: wrong the moment the
/// slider moves, and — if each writer took its own — two different snapshots of
/// one number. The seam is the answer: one reader, asked by both writers, at
/// write time.
///
/// ### WHY THE READER IS FED BY THE **COMPOSITION ROOT**
///
/// The live value lives in the settings cubit's state, and the two writers are a
/// data class and a presentation class that may not reach `features/settings/`
/// (Gate 2) and may not read a presentation cubit from the data layer. The
/// composition root is the one place allowed to know about both — it already
/// builds the `SettingsHandle` over that cubit — so it reads the chosen count
/// there and hands the same reader to both writers. The report for this task
/// carries the exact two-line change, because `lib/app/di/` is outside this
/// slice's paths.
///
/// ## AND THE CAP IS **NOT** A TRIM: LOWERING IT DELETES NOTHING
///
/// The prototype's slider re-trims the sky the moment it moves
/// (`eva/redesign.html:1486-1487`) — its stars are DOM elements, and removing
/// one removes it for good. **This client's sky is persisted**
/// (`sky_local_data_source.dart`) and a reader's lit verses are their own record
/// of what they have read, so a decoration setting must not delete it.
///
/// **The decision: the cap applies to NEW WRITES ONLY.** Lowering the cap trims
/// nothing by itself; the next new lighting evicts the oldest entries down to
/// the new cap, which is the prototype's own one-at-a-time eviction (`:1147`) and
/// the same deletion the prototype performs. The divergence from `:1486-1487` is
/// recorded at the control, and the decision is this file's: the cap is a bound
/// on the sky's size, not a command to shorten a reader's history.
const int skyStarCap = 44;

/// The cap the sky is held to for a reader who chose [count].
///
/// **THE RANGE AND ITS CLAMP ARE NOT DECLARED HERE.** They are in
/// `core/domain/entities/user_settings.dart` — as `kStarCountMin`,
/// `kStarCountMax` and `clampStarCount` — because the range is used by **two**
/// features (this one and the settings feature's own clamps) and §3's placement
/// test puts a two-consumer fact in the shared kernel. A feature may not import
/// another feature (Gate 2) and `core/domain/` may not name a feature, so the
/// shared kernel is the only home both may reach.
///
/// **Two spellings of `0` and `60` in two features is the "two implementations
/// of one number" drift this repository rejects wherever it finds it.** The
/// prototype's own numbers are `eva/redesign.html:669` —
/// `<input type="range" id="setStarCount" min="0" max="60" value="44">`.
///
/// **THIS IS THE SKY'S NAME FOR THE SHARED CLAMP, AND IT IS ONE FUNCTION.**
/// The table in this file's header used to name the clamp as the sky's own, and
/// the honest answer is that it is not: the number it clamps is the **star
/// count preference's** range, and the preference is the shared kernel's. The
/// sky applies the shared clamp, under the name the sky's two writers already
/// use.
///
/// **Applied by the writers, not by the reader.** The reader answers a chosen
/// count; the writer that is about to enforce it is the boundary where the
/// value becomes a cap, and both writers apply this same function — so the two
/// cannot clamp differently.
int skyStarCapFor(int count) => clampStarCount(count);
