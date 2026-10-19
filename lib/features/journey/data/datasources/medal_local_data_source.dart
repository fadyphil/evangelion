import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';

/// The medals this client can read — ADR-0022's fiction, in one class.
///
/// ## THIS FILE **IS** ADR-0022'S "NO SCREEN MAY RENDER A HARD-CODED …" — MADE A
/// DATA SOURCE
///
/// The fiction table's medals row: **stub** — "an achievements table"
/// (`docs/adr/0022-full-fidelity-redesign-supersedes-0001.md:57`). The
/// correction under it is the part that shaped this class: the backend
/// registers **fourteen** routes and **none of them enumerates a medal**
/// (`:23-27`), so the medals are invented here and nowhere else.
///
/// ## AND THE SERVER HAS **NEVER HONOURED** THIS CONTRACT
///
/// ADR-0022's "Worse" section, quoted: "A mapper for medals or cheer is a
/// contract the server has never honoured, which is the exact class
/// AGENT_CONTEXT §5 trap 1 warns about" (`:221-226`). So this class is a
/// **transcription**, in `test/support/contract_payloads.dart`'s sense: it
/// describes a shape this backend cannot produce, and it says so rather than
/// pretending otherwise.
///
/// ## SO WHAT EXACTLY IS INVENTED, AND WHAT IS **NOT**
///
/// **Invented — which medals exist.** The four below are the prototype's
/// (`:599-602`). The *other eight* of the twelve have no name anywhere: the
/// prototype draws four and writes "4 / 12" (`:597`), so the eight unnamed
/// medals are this class's invention and not the prototype's.
///
/// **Invented — how many of the twelve are earned.** Four of twelve, because
/// the prototype says "4 / 12" and nothing in it says which four. It draws
/// exactly four, so the drawn four are the earned four, and the eight unnamed
/// are the unearned ones — an inference, not a transcription, and the reason
/// the count is a stub's to own.
///
/// **Not invented — the names.** "first light", "psalmist", "streak ×7" and
/// "john" are the prototype's own i18n rows (`:937`), and they live in the ARB
/// as the four `journeyMedal*` keys rather than here: a translated string does
/// not arrive as data, and this class is data.
///
/// **Not invented — the emblems and the blooms.** They are the prototype's
/// design facts (`:599-602`) and they belong to the medal itself, so they are
/// on the enum (`features/journey/domain/medal.dart`) — named, and not
/// valued, for the reasons that file gives.
///
/// ## AND WHY THE CLASS IS **NOT** `final`
///
/// Because it is the **seam**, and the port's whole promise hangs off it: the
/// repository's failure arm is unreachable without a data source that can
/// fail, and this one cannot — it is four literals. A `final` class cannot be
/// implemented outside its own library, so a `final` stub would make the port's
/// "never throws, always a `Result`" promise **untestable**, which is the same
/// reason `LibraryCatalogueRepository` is an interface rather than a concrete
/// class. §4's "final by default" yields to substitutability, and the
/// substitute is the test's, not the app's.
///
/// ## AND WHY ITS CONSTRUCTOR IS **NOT** `const`
///
/// Because it **holds its shelf**, and a shelf is a value built by a copy —
/// `MedalShelf`'s doc measures why — so the field's initialiser is not a const
/// expression and the compiler does not allow a const constructor here. That is
/// §4's "const wherever the compiler allows it" and this is the compiler's
/// answer, and it is also why the DI module can write `MedalLocalDataSource()`
/// without a `const` and without a lint.
class MedalLocalDataSource {
  /// The stub: the four medals the prototype draws, out of the twelve it
  /// counts.
  ///
  /// ## THE ORDER IS THE PROTOTYPE'S, AND IT IS NOT A MEANING
  ///
  /// `:599-602` draws first light, psalmist, streak ×7 and john, in that
  /// order, and the strip draws them in the order it is handed them. The
  /// prototype's order is a demo order — there is no ranking in it and no
  /// sense in which "streak ×7" comes after "psalmist" — so nothing above
  /// this line may sort them and call the result better.
  ///
  /// ## AND `total` IS **12** BECAUSE THE PROTOTYPE SAYS TWELVE
  ///
  /// `:597` writes "4 / 12", and the twelve has no other source: there is no
  /// achievements table, no medals route, and no rule anywhere that says how
  /// many medals a reader could earn. The number is the prototype's, and it
  /// is a fiction this class owns.
  MedalLocalDataSource()
    : _shelf = MedalShelf(
        earned: const <Medal>[
          Medal.firstLight,
          Medal.psalmist,
          Medal.streakSeven,
          Medal.john,
        ],
        total: 12,
      );

  /// The shelf this source answers with.
  ///
  /// **Held rather than built per call**, so the shelf is one value for the
  /// life of the source: the DI registration is a `lazySingleton`, and a cubit
  /// that reads the same shelf twice reads the *same* shelf, so the state it
  /// holds does not report a change every time the four medals are read again.
  final MedalShelf _shelf;

  /// The reader's shelf.
  ///
  /// **Throws** if the shelf cannot be produced — the data source's contract,
  /// and the repository's job to turn a throw into a typed failure. This one
  /// cannot fail: it is four literals.
  MedalShelf shelf() => _shelf;
}
