import 'package:evangelion/core/domain/entities/user_role.dart';

/// The role question navigation asks, as its own seam.
///
/// ## WHY THIS IS NOT A MEMBER ON `AuthStatus`
///
/// Two questions, two seams, and the second one **cannot** be merged into the
/// first. `core/navigation/auth_status.dart:36-40` says, in its own words:
///
/// > It is not a security boundary and it is not a session store. […] The guard
/// > protects navigation flow and nothing else. `isAuthenticated` must therefore
/// > be a plain read of whatever the app currently believes, never a
/// > validation, a token check or a network call.
///
/// `AuthStatus` is therefore scoped to **"is there a session"**, and its own doc
/// closes the door on anything else. Adding `allows(UserCapability)` beside
/// `isAuthenticated` would make one class answer two unrelated questions — §3's
/// SRP row, "one reason to change per file" — and it would fail in the shape that
/// is hardest to see, because both members would be `bool`-shaped and a reader
/// would assume they answer the same question. A guard reading `status.allows(…)`
/// would look like a guard reading `status.isAuthenticated`, and one of those
/// fails closed and the other fails loud.
///
/// *Rejected: a `UserRole role` getter on `AuthStatus`, with `allows` derived
/// from it.* Same objection with less surface, and worse: it makes the grant
/// table reachable from a seam whose whole documented contract is that it holds
/// no role, so the next reader has to re-derive whether the two are related.
///
/// ## AND DECISION 75 IS PRECISELY THE PRECEDENT FOR KEEPING THEM APART
///
/// This is not only an SRP argument invented here. Recorded decision 75
/// (`AGENT_CONTEXT.md:2055-2056`) exists in this repository **to keep two
/// mechanisms apart** that look like the dual-source shape, and it names the
/// rule in its own words:
///
/// > THE SEAM IS TWO DIFFERENT QUESTIONS, NOT A DUPLICATE SOURCE OF TRUTH.
///
/// The two arms decision 75 kept are a payload's language and the ambient locale.
/// These two are "is there a session" and "what may this reader be offered".
/// Both halves of decision 75's test are met, which is why it applies rather than
/// merely rhymes:
///
///  * **They are different facts, not two names for one.** `AuthStatus` holds a
///    `bool` the bloc publishes; `RoleAccess` reads a role and a grant table.
///    Nothing in either can be derived from the other.
///  * **They survive each other disagreeing.** A signed-in `kid` answers
///    `isAuthenticated == true` and `allows(manageQuestions) == false` in the
///    same instant. One seam says yes while the other says no, and collapsing
///    them would delete the distinction rather than the redundancy.
///
/// ## THIS IS **NOT** A SECURITY BOUNDARY, AND THE BACKEND IS WHY
///
/// Read this before adding a check anywhere on the strength of it. It is the
/// same measurement `core/domain/entities/user_role.dart` records, repeated here
/// because this is the file a gate author will read.
///
/// The backend parses `X-User-Role` at `src/middleware/identity.middleware.ts:24`
/// and assigns it to `request.user.role` at `:31`, **and never reads it again**.
/// Measured against `HEAD = 4a1c834`: `rg 'user\??\.role' src/` returns **no
/// matches** and `rg '403' src/` returns **no matches** — zero role guards and
/// zero forbidden responses across all **seventeen** route registrations in
/// `src/` — fourteen `fastify.<verb>(` calls under the `/api/v1` prefix
/// registered at `app.ts:133-140`, plus `/json`, `/documentation` and `/health`
/// at `app.ts:94,99,107`. There is no `fastify.route(` anywhere in `src/`, so
/// those fourteen are the whole of the API surface. Every endpoint is callable by
/// anyone who sends a user id.
///
/// **The zero-match greps are the argument; the seventeen is only evidence that
/// the sweep was total**, and it is stated here because `user_role.dart` records
/// that an earlier draft of this same comment claimed *eighteen* without
/// measuring it.
///
/// So `allows` prevents **accidents**, never **attacks**: that a child is not
/// dropped onto a scheduling screen that makes no sense for them, and that a
/// servant is not shown a control that reports nothing. There is nothing on the
/// server for an attacker to defeat — the header is set by the client, the
/// client is the attacker's own device, and every request succeeds whatever
/// role it claims.
///
/// ## [allows] ANSWERS A UI QUESTION, NOT A SECURITY ONE
///
/// * *"Should this screen be **offered**?"* — the question [allows] answers.
///   A false answer means the reader is not shown something.
///
/// * *"May this **request** be made?"* — the question that would make it a
///   boundary, and the one this client cannot answer. The wire has no opinion:
///   the header goes out, the server stores it, and the response is identical
///   whatever it said.
///
/// **A passing `allows` therefore means "this screen was chosen sensibly for this
/// reader", never "this reader is allowed to be here."** A caller that wants the
/// second thing has the wrong tool and no tool in this repository answers it.
///
/// ## THE NEVER-THROW OBLIGATION, AND WHY IT IS THIS FILE'S TO CARRY
///
/// **An implementation MUST NOT throw.** `AuthStatus` states the same obligation
/// for `isAuthenticated` (`auth_status.dart:48-95`) and explains the cost: a
/// throw there escapes `AuthGuard.onNavigation` and is never converted into
/// anything, so on a cold launch the reader gets a blank first frame and the
/// only trace is `FlutterError.onError`.
///
/// A role check **has** a consumer now, and it is the one this file was
/// written for: the servant portal's `RoleGuard` asks it, and — since the
/// servant portal's Task 1 — so does the **identity interceptor**, which reads
/// the same registration to put `X-User-Role` on the wire. That is the point of
/// the seam being one registration: the guard's answer and the header's value
/// are one fact read from two angles.
///
/// So the cost of a throw here is **stated rather than measured** for the
/// *navigation* half, and the half that *is* reachable is pinned:
///
///  * `role_access_test.dart` asserts a throwing implementation's throw
///    **propagates** rather than being absorbed, in the shape of
///    `auth_guard_test.dart`'s "and it does not swallow a throwing seam";
///  * it asserts this file contains **no `catch` at all**, so the obligation
///    holds structurally rather than by every future call site remembering not
///    to handle one.
///
/// **AND THE INTERCEPTOR'S USE MAKES THE OBLIGATION LOUDER, NOT QUIETER.** A
/// throw out of [role] would escape `onRequest` — inside dio's own request
/// pipeline, where a throw is not a refusal but a **failed request**, and the
/// reader would see a network error rather than a role that could not be read.
/// That is a *worse* outcome than the guard's silent `false`, which is why the
/// implementation behind the registration reads a field and cannot throw.
///
/// Why absorbing it would be worse than propagating it: a `try`/`catch` here
/// would answer `false` for a role the app simply could not read, and a silent
/// `false` is indistinguishable from a real refusal. That is the argument
/// `auth_guard.dart` gives for not catching a throwing `AuthStatus` either, and
/// §7's rule that a gate must be able to fail applies to a decision as much as to
/// a check.
///
/// ## AND THE VALUE IS A PLAIN READ, NEVER A LOOKUP THAT CAN FAIL
///
/// [role] is a getter over whatever the app currently believes, exactly as
/// `auth_status.dart` demands of `isAuthenticated`. It is **not** a `Future`, it
/// is not awaited anywhere, and it cannot be made into one by accident: an
/// `async` seam would still compile, would leave every call site holding a
/// `Future` nobody awaits, and would turn a refusal into a loading state —
/// recorded decision 9, contract 1. `role_access_test.dart` asserts the
/// absence of `Future`, `Stream`, `async` and `await` from this file's
/// executable source, which is the only way to make that a fact about the file
/// in a language with no reflection.
///
/// PURE DART — `core/navigation/` is held to no Flutter, Dio or http by
/// `tool/verify_purity.sh` Gate 1, and that is not decoration: the screens that
/// will consult this seam live in features, and a Flutter type here would put a
/// `BuildContext` inside the shared kernel.
///
/// **Gate 1 was negative-controlled against this file specifically**, because it
/// is the pure-Dart thing the gate exists to protect. Planting
/// `import 'package:flutter/material.dart';` as line 1 of a scratch copy under
/// `/tmp/opencode/purity/` and running the script there printed
/// `VIOLATION lib/core/navigation/role_access.dart:1` and exited **1**; the
/// unplanted copy printed `9 pure-Dart dir(s) reach no flutter/dio/http` and
/// exited 0. §7's rule that "a gate has to be able to fail before you may
/// believe it passes" is recorded here rather than in a commit message,
/// because this file is the first thing a reader will check and the evidence
/// should travel with it.
abstract interface class RoleAccess {
  /// The role the app currently believes this reader holds.
  ///
  /// A plain read. Cheap, side-effect-free, and never a validation — see the
  /// file's section on the never-throw obligation for what happens when it is
  /// not.
  UserRole get role;

  /// Whether [capability] is one [role] grants.
  ///
  /// **A UI question, not a security one** — "should this screen be offered",
  /// never "may this request be made". The grant table is
  /// [UserRole.grantsFor], and this method's whole job is to answer from it
  /// rather than from a comparison ladder of its own: a second copy of the
  /// table is a second source of truth, free to drift from the first, and the
  /// drift would be silent in both directions.
  ///
  /// MUST NOT throw, for the same reason [role] must not. See above.
  bool allows(UserCapability capability);
}

/// The canonical [RoleAccess]: it answers from a reader, and reads it again on
/// every call.
///
/// ## WHY IT TAKES A READER AND NOT A `UserRole`
///
/// Because a role **changes**, and a value copied out of its holder at
/// construction is a second source of truth that goes stale silently.
/// `AuthSession.role` is the truth; this is a way of asking for it.
///
/// That argument is not hypothetical on this seam's own side of the
/// architecture, it is measured on its sibling. Recorded decision 9's contract 4
/// — "It is not a mirror. The answer is read from the bloc's current state on
/// every call rather than cached" — exists because `BlocAuthStatus` froze the
/// answer at construction in a draft, **and all 1200 tests were green**. The
/// cost surfaced only end to end: the reader signs in, the bloc's state becomes
/// `signedIn`, the form reports `LoginOutcome.signedIn`, the guard asks the seam
/// again on the re-evaluation and gets the stale `false`, and the stack settles
/// back on `LoginRoute` with `HomePage` never built — the same defect, one
/// layer up.
///
/// On this seam the same freeze would be worse still, because the role is
/// **chosen on the login screen** (§2 decision 3 — there is no auth endpoint,
/// `FakeAuthRepository` hands out a seeded session). A role access built at
/// composition time would capture the role that did not exist yet.
///
/// *Rejected: a mutable `UserRole role` field with a setter.* It satisfies every
/// test in `role_access_test.dart`, and it is a shape this repository has
/// rejected before for exactly this reason — decisions **5** and **68** each
/// removed a second copy of one value in favour of a single source. Decision 75
/// is deliberately **not** in that list: it is the counter-example, the record of
/// a seam that looks like the same shape and was kept anyway (see the section on
/// `AuthStatus` above, which is what it is precedent for). Decision 68's own
/// wording is the dual-source removal — "the 'dual source of truth for one value'
/// shape that defect 5 already removed from the design system"
/// (`AGENT_CONTEXT.md:1822-1823`) — and decision 75 confirms the pair by name
/// (`AGENT_CONTEXT.md:2063-2064`). So it is **twice**, not three times. A
/// writable role field would hand every caller the ability to disagree with
/// `AuthSession.role` and nothing to catch it.
/// *Rejected: naming the parameter `role` and passing it by value.* A reader is
/// one word longer and the difference is the entire point of the class.
///
/// ## TWO HAZARDS THE CONSTRUCTOR DOES **NOT** RULE OUT
///
/// Everything above is about rejecting shapes. These two hazards are the ones a
/// reader *does* keep, so they are named here rather than left to be discovered.
///
/// **1. A reader that captures a session is a frozen seam wearing this class's
/// name.** [LiveRoleAccess] rejects a mutable *field*, which is a different
/// thing entirely — nothing stops the composition root from writing a perfectly
/// legal closure:
///
/// ```dart
/// final AuthSession? s = bloc.state.session;
/// LiveRoleAccess(() => s!.role); // compiles, and is frozen forever
/// ```
///
/// `AuthSession` is `freezed` with `final UserRole role`, so the snapshot can
/// never go stale *and* never updates: the field is immutable, so no setter
/// exists to fix it, and no compiler warning appears because `s!.role` is a
/// perfectly valid read. This is **exactly** the defect decision 9 contract 4
/// records, in a form the mutable-field argument above would wave through. The
/// reader must close over the **bloc or locator**, never over a session value
/// pulled out of one; `() => bloc.state.session?.role ?? UserRole.kid` is live,
/// `() => s!.role` is not.
///
/// **2. [allows] re-reads the role on every call, so two calls in one decision
/// are NOT a consistent snapshot.** This is the property the class is *for* —
/// see "WHY IT TAKES A READER AND NOT A `UserRole`" above — and it has a
/// consequence worth stating: a caller that reads `role` once and then reads it
/// again within a single navigation decision can be handed **two different
/// roles**, because the bloc emitted in between. A guard that must reason about
/// one reader consistently has to capture `final UserRole role = access.role;`
/// once and pass that to `UserRole.grantsFor` itself. The seam guarantees
/// liveness; it does not guarantee atomicity across two reads, and no seam built
/// on a reader can.
///
/// The freeze-at-construction contract this paragraph defends is pinned in two
/// places now. `test/app/di/navigation_injection_test.dart:393` drives the bloc
/// and re-reads the seam, and the `same()` post-mortem above it (`:371-392`)
/// records how a freeze there shipped with all 1200 tests green.
/// [RoleAccess]'s analogue is in `role_access_test.dart`, which holds it by
/// **counting reads** rather than comparing answers.
///
/// **AND THE REGISTRATION THAT NOW EXISTS IS HELD BY THE SAME KIND OF
/// ASSERTION.** The servant portal's Task 1 registered the seam in
/// `auth_module.dart` — the **pure** half — and
/// `test/app/di/injection_test.dart`'s "the role seam is registered in the PURE
/// half" group asserts that it is a **singleton** and that it answers the
/// **session's** role once one exists. A registration that froze the role at
/// composition would answer the seed for ever, and that is the whole defect
/// the paragraph above is about, in the place it now lives.
///
/// ## THE COMPOSITION ROOT IS WHERE THE READER COMES FROM
///
/// It cannot be written here: `AuthBloc` reaches `flutter_bloc`, which
/// re-exports the widget layer, and Gate 1 holds this directory Flutter-free.
/// That is the same wall recorded decision 17 records for `AuthBloc` itself, and
/// it is why the bloc-backed implementation belongs beside `BlocAuthStatus` in
/// `lib/app/di/navigation_injection.dart`, hand-registered.
///
/// **AND THE REGISTRATION THAT EXISTS IS OVER THE **PURE** HALF, NOT THE BLOC.**
/// Since the servant portal's Task 1 this seam is registered in
/// `lib/app/di/modules/auth_module.dart` — the **pure** half — over the
/// `AuthLocalDataSource`'s **synchronous** view of the session, because
/// `injection.dart`'s transitive project-local import graph is required to stay
/// Flutter-free (AGENT_CONTEXT §6, recorded decision 4) and `AuthBloc` would
/// have dragged the widget layer into it.
///
/// That is what makes the **interceptor** able to read it: the header's value
/// is wanted **per request**, and a reader that had to be awaited could not
/// answer a synchronous header write. The store is an in-memory field by
/// design — see `AuthLocalDataSource`'s own doc — so a synchronous read is a
/// field read and not a lie about a platform channel.
///
/// A reader also keeps **the composition root's** choice out of this file: a
/// caller may read a bloc's state, a session field, or a value in a test, and
/// none of those types has to appear here.
///
/// ## AND IT CANNOT BE SLOW, BECAUSE IT HAS NOWHERE TO BE SLOW
///
/// The body of [allows] is a set lookup on an unmodifiable `const` table —
/// [UserRole.grantsFor] returns one by construction — and the body of [role] is
/// one field read of whatever the reader closes over. There is no allocation on
/// either path, which is what lets a future guard call `allows` several times
/// per navigation without thinking about it.
final class LiveRoleAccess implements RoleAccess {
  /// Answers from [read], consulted afresh on every call.
  const LiveRoleAccess(this._read);

  /// What the app currently believes. A field read at the call site, so it must
  /// be cheap and side-effect-free — the same contract `AuthStatus` states for
  /// its own reader, and for the same reason: navigation asks on every push and
  /// again on every stack re-evaluation.
  final UserRole Function() _read;

  @override
  UserRole get role => _read();

  @override
  bool allows(UserCapability capability) =>
      UserRole.grantsFor(role).contains(capability);
}
