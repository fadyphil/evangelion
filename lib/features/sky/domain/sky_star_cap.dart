/// How many stars the witness sky holds before the oldest is evicted.
///
/// The prototype's `starCap` (`eva/redesign.html:1131`, re-pinned at `:1512`):
/// `addStar` removes the oldest `.star` while the count is past it (`:1147`), and
/// the slider re-trims to it (`:1486-1487`).
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
const int skyStarCap = 44;
