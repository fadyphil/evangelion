import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/journey/domain/medal.dart';

/// The reader's medal shelf: the medals they have earned, and how many exist.
///
/// ## WHY THE LIST IS **COPIED**
///
/// A shelf is a value, and a caller that mutated the list it was handed would
/// be editing the state a cubit holds. `LibraryCatalogueRepositoryImpl` makes
/// the same call for the same reason — "the catalogue is a value, and
/// `HomeBloc`'s state holding an unmodifiable list is one more place the
/// catalogue cannot be edited from a widget" — and the copy is what makes that
/// claim true rather than merely stated.
///
/// **Which is why this constructor is not `const`.** §4 asks for `const`
/// wherever the compiler allows it, and the compiler does not allow it here:
/// `List.unmodifiable` is not a const expression, and a `const` constructor
/// would take the caller's list as it stands and hand back a mutable one. The
/// alternative — a `const` constructor and a trust-the-caller rule — is the
/// arrangement that made the catalogue's list editable from a widget.
///
/// ## AND WHY IT HAS **VALUE** EQUALITY
///
/// A shelf is compared, not merely carried: it sits in a cubit's state beside
/// the other numbers on the screen, and a state that compares by identity would
/// report a change every time the same four medals were read again. `List`'s
/// own `==` is identity, so the list is compared element by element here
/// rather than handed to it.
final class MedalShelf {
  /// A shelf of [earned] medals, out of [total] that exist.
  MedalShelf({required List<Medal> earned, required this.total})
    : earned = List<Medal>.unmodifiable(earned),
      assert(
        earned.length <= total,
        'a reader cannot have earned more medals than exist',
      );

  /// The medals the reader has earned, in the order the strip draws them.
  ///
  /// **Unmodifiable**, and a copy rather than the list it was handed — see the
  /// class doc.
  final List<Medal> earned;

  /// How many medals exist in all.
  ///
  /// **The prototype's "4 / 12" (`:597`) is this number and the other half of
  /// it**, and the twelve is a fiction with no name behind it: the prototype
  /// draws four and writes twelve, so the eight unnamed medals are the stub's
  /// invention and not the prototype's. The data source's doc says so.
  final int total;

  /// Two shelves are the same shelf when they hold the same medals, in the
  /// same order, out of the same total.
  ///
  /// **`runtimeType` is checked** for the reason `Failure`'s `==` checks it
  /// (decision 131): Dart's generics are covariant, so a `MedalShelf` would
  /// otherwise equal a subclass that answers a different question.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedalShelf &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          _sameMedals(earned, other.earned);

  /// Agrees with `==`, and hashes the medals in order.
  @override
  int get hashCode => Object.hash(total, Object.hashAll(earned));
}

/// Whether two medal lists hold the same medals in the same order.
///
/// `List`'s own `==` is identity, and this file is a pure-Dart directory where
/// `package:flutter/foundation.dart`'s `listEquals` cannot be reached — so
/// the comparison is written out, and the reason it is written out is the
/// reason the shelf compares by value at all.
bool _sameMedals(List<Medal> a, List<Medal> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The medals `/journey` draws, behind a port.
///
/// ## WHY IT IS A PORT AND NOT A LIST IN THE PAGE
///
/// ADR-0022's rule, quoted: "Every stub sits behind a repository port, so
/// replacing invented data with a real endpoint is a change to **one adapter**
/// and no change to a screen. **No screen may render a hard-coded reader,
/// medal, cheer or star**; the fiction lives in data sources, which is where §2
/// decision 3 already put the seeded session."
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:126-129`). The
/// medal shelf is the "medal" in that sentence.
///
/// The alternative — a `List<Medal>` in the page — is the arrangement the ADR
/// was written against, and it has a concrete cost beyond tidiness: the count
/// beside the strip is "4 / 12" (`:597`), and a screen that held the list
/// would hold the count too. Then the day either became real there would be
/// no seam to change, and the fiction would have been written into the widget
/// rather than into a data source.
///
/// ## AND WHY IT LIVES IN `features/journey/` AND NOT IN `core/domain/`
///
/// §3's placement test is **two or more consumers**
/// (`docs/agents/AGENT_CONTEXT.md:243-244`), and this has **one**: `/journey`
/// draws the strip, and nothing else in the app reads a shelf. The shared
/// kernel holds the ports whose readers are spread across features — and the
/// book catalogue's port says the same about itself, in the file this one is
/// modelled on (`lib/features/home/domain/library_catalogue_repository.dart:21-28`):
/// "§3's placement test is **two or more consumers**, and this has one: `/`
/// renders the carousel (`redesign.html:536`) and nothing else reads a
/// catalogue today. `core/domain/repositories/` holds the seven ports whose
/// readers are spread across features — `sky_repository.dart` states its own
/// three-consumer table as the reason — and an eighth port there for a
/// one-consumer fiction would put a document in the shared kernel about a
/// screen's stub."
///
/// **The medal shelf is that eighth port's exact case**, and the catalogue is
/// the precedent rather than an assumption: it earned its place in
/// `features/home/` by this very argument, and when ADR-0022's second consumer
/// arrived for it the answer was still "not yet" — the promotion is `git mv`
/// and an import, and it will be a real decision then.
///
/// **And the promotion cannot happen by accident.** `tool/verify_purity.sh`'s
/// Gate 2 fails the day a second feature imports this file, because a feature
/// may not import another feature. So the shelf moves to `core/domain/` as a
/// **decision with its reasoning attached**, and not as an import somebody
/// added on a Tuesday; and until that day, the shared kernel does not carry a
/// document about one screen's stub.
abstract interface class MedalRepository {
  /// The reader's shelf — the medals they have earned, and how many exist.
  ///
  /// **Never throws, always a [Result]** (§3's LSP row): an exception crossing
  /// this seam reaches the journey's cubit, where nothing catches it. The
  /// shipped adapter cannot fail — its source is four literals — and it
  /// returns a `Result` anyway, so that swapping in an achievements endpoint
  /// needs no change above this line.
  Future<Result<MedalShelf>> shelf();
}
