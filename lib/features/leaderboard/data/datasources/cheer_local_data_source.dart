/// The session's cheered witnesses, held in memory.
///
/// This **is** `eva/redesign.html:1066` transcribed:
///
/// ```js
/// const cheered=new Set();
/// ```
///
/// One set, declared once, never cleared — no storage, no server, no TTL. The
/// screen's re-entry persistence is therefore the lifetime of this object, and the
/// DI registration makes that object a `lazySingleton` so a route pop and push does
/// not forget a cheer the way a fresh `Set` per page build would.
///
/// ## WHY THE DATA SOURCE HOLDS THE SET AND THE REPOSITORY DOES NOT
///
/// The repository is a projection over this seam; the set is the adapter's state.
/// Keeping them apart is what makes "the local set becomes a GET/POST" a change to
/// one file, with the repository's `Result` translation still true afterwards.
final class CheerLocalDataSource {
  /// An empty session.
  CheerLocalDataSource();

  final Set<String> _cheered = <String>{};

  /// A read-only snapshot of the set.
  ///
  /// A copy, not the live set: a caller that mutated what it was handed would be
  /// writing through a read seam, and `Set.unmodifiable` makes that a thrown
  /// [UnsupportedError] at the call site instead of a silent state change.
  Set<String> read() => Set<String>.unmodifiable(_cheered);

  /// Records a cheer for [userId], and reports whether it was **new**.
  ///
  /// The return value is [Set.add]'s own contract — `true` only on the first call
  /// for an id — which is the local transcription of the prototype's
  /// `if(cheered.has(p.id)) return;` (`redesign.html:1120`). The cubit does not rely
  /// on it today (it checks its mirrored state first); it is here so a future
  /// adapter can answer a duplicate POST with the same idempotent success.
  bool add(String userId) => _cheered.add(userId);
}
