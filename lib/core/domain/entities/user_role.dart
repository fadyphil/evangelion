/// What a reader is allowed to do in this client, and what the three roles grant.
///
/// ## WHAT THIS FILE IS, IN ONE LINE
///
/// A transcription of the backend's own role union, plus the answer to "which
/// role may open which screen" — a question the client can only answer because
/// the backend never asks it.
///
/// ## WHY ROLE IS AN ENUM AND NOT A `String`
///
/// `AuthSession.role` was a `String` and every question about it was an
/// equality guess. `role == 'viewer_servant'` compiles for a typo, runs for a
/// value the backend has never sent, and answers `false` — so a gate written
/// that way is **silently closed**, which is the failure mode that reads as
/// "the feature did not work" rather than "the constant is wrong". Worse, a
/// `String` cannot answer "what does this role grant?" at all: that answer has
/// to live somewhere, and with an untyped field it lands in an `if` ladder
/// inside whichever widget happened to need it first.
///
/// An enum makes all three roles **checkable** and the grants **nameable**. The
/// Dart member is camelCase (`viewerServant`) while the wire value is the
/// backend's snake_case (`'viewer_servant'`) — they are spelled apart on
/// purpose, and [wireValue] is the only sanctioned way to write one onto the
/// wire. §4 forbids `describeEnum` for exactly this reason: `.name` is the Dart
/// spelling and is never a wire value.
///
/// ## THIS IS **NOT** A SECURITY BOUNDARY, AND THE BACKEND IS WHY
///
/// Read this section before adding a check anywhere on the strength of it.
///
/// The backend parses `X-User-Role` at `src/middleware/identity.middleware.ts:24`
/// and assigns it to `request.user.role` at `:31`, **and never reads it again**.
/// Measured against `HEAD = 4a1c834`: `rg 'user\??\.role' src/` returns **no
/// matches**, and `rg '403' src/` returns **no matches** — zero role guards and
/// zero forbidden responses across all **seventeen** route registrations in
/// `src/` — fourteen under `/api/v1`, plus `/json`, `/documentation` and
/// `/health` in `app.ts`, counted by grepping the `.get(`/`.post(`/… calls in
/// `src/` and cross-checked against `app.ts`'s own route registrations. Every
/// endpoint is callable by anyone who sends a user id.
///
/// The count is stated because it was **measured**, and because the previous
/// draft of this comment said *eighteen* without measuring it. The number is
/// load-bearing here only as evidence that the sweep was total; the argument it
/// supports is the two zero-match greps beside it, not the tally.
///
/// So a role gate in this client prevents **accidents**, never **attacks**. What
/// it buys is that a child is not dropped onto a scheduling screen that makes no
/// sense for them, and that a servant is not shown a control that reports
/// nothing. What it does not buy is any property an attacker would have to
/// defeat, because there is nothing on the server to defeat: the header is set
/// by the client, the client is the attacker's own device, and every request
/// succeeds whatever role it claims.
///
/// **The correct reading of a passing grant check is "this screen was chosen
/// sensibly for this reader", never "this reader is allowed to be here."**
///
/// ## WHERE THE ROLE COMES FROM, AND WHY THAT IS THE STRANGE PART
///
/// There is **no `/auth`, no `/me` and no `/login` endpoint on this backend**
/// (AGENT_CONTEXT §2, decision 3 — "Login and onboarding are UI-only"). The
/// client therefore cannot ask who anyone is, and `FakeAuthRepository` hands out
/// a seeded session. The role is **chosen locally on the login screen** until
/// the backend ships real authentication.
///
/// This is worth stating plainly because it is the one fact that would make
/// this file look like fiction: nothing here is a claim about a user the server
/// has told us about. It is a claim about a button someone pressed. When
/// authentication lands, the choice moves from the login screen to a real
/// response, and this file's job does not change — but every value in
/// [UserRole.grantsFor] becomes a claim about the server rather than about the
/// form.
///
/// ## AND THE TWO CONVERSIONS ARE **NOT** IN THE SAME STATE
///
/// [UserRole.grantsFor] is **live**, and it is read in **exactly one place in
/// the whole app**: `LiveRoleAccess.allowsRole` in
/// `core/navigation/role_access.dart`. The navigation guard asks the seam, the
/// portal's hub asks the seam, and the seam is the only holder of the table —
/// so "may this reader be offered this screen?" has **one** answer path, and a
/// second reader of the table would be the "two sources of truth for one value"
/// shape this repository has removed three times on purpose.
///
/// [UserRole.fromWire] has **no caller in `lib/`** yet, and that is a task
/// boundary rather than dead code: the wire decoder is the mechanism, and the
/// transport that would carry a role off the wire belongs to a future change.
/// A reader who greps for a caller, finds none, and reads that as dead code
/// should read the opposite — the absence is the task boundary, and these are
/// the two seams it hands forward. The [UserRole] enum itself is live:
/// `AuthSession.role` and the seed both name it.
///
/// ## AND NOTHING HERE RENDERS, SO NOTHING HERE IS TRANSLATED
///
/// A [UserCapability] is named in English because it is a **symbol**, never
/// drawn. No screen renders a capability name, so none of the six is a string
/// table entry — adding one would be inventing bilingual copy for a value no
/// reader ever sees, and `gen_l10n` would then carry a key with no consumer.
///
/// The cost is recorded rather than hidden: if a future screen ever *shows* a
/// capability, that name has to move to the ARB. **No gate in this suite scans
/// for an untranslated identifier** — the design-system gates are structural and
/// colour-literal based, so a capability name drawn on screen would reach a
/// reader verbatim and nothing would turn red.
///
/// PURE DART — `core/domain/` is held to no Flutter, Dio or http by Gate 1.
enum UserRole {
  /// A child reader. The only role this client seeds, and the one
  /// `identity.middleware.ts:24` defaults to when the header is absent or
  /// empty.
  kid('kid'),

  /// A viewer servant. `identity.middleware.ts:5`'s `'viewer_servant'`.
  viewerServant('viewer_servant'),

  /// An admin servant. `identity.middleware.ts:5`'s `'admin_servant'`.
  adminServant('admin_servant');

  const UserRole(this.wireValue);

  /// The value this client sends as `X-User-Role`.
  ///
  /// Spelled out per member rather than derived from `name`, and the reason is
  /// the whole reason this enum exists: `UserRole.viewerServant.name` is
  /// `'viewerServant'`, which is in **none** of the backend's three declared
  /// values. A derived spelling would send a role the server stores happily and
  /// no client can name.
  final String wireValue;

  /// The role [wire] names, or [kid] if it names none of them.
  ///
  /// ## WHY THE FALLBACK IS `kid` AND NOT A THROW
  ///
  /// Because that is what the server does, and a client that answered
  /// differently would be disagreeing with it about a header both of them can
  /// see. `identity.middleware.ts:24` is
  ///
  /// ```ts
  /// const userRole = (request.headers['x-user-role'] as …) || 'kid';
  /// ```
  ///
  /// so an **absent** header and an **empty** one both arrive as `'kid'` — in
  /// JavaScript `''` is falsy, which is why the empty string is in the fallback
  /// group in the test rather than treated as a parse error. Matching the
  /// server's default is also the *safe* direction: the fallback grants a kid's
  /// capabilities, which is the narrowest of the three tables.
  ///
  /// *Rejected: throwing.* A role this client never sends cannot arrive here
  /// today, so a throw would be a branch with no reachable input — recorded
  /// decision 14's defect class, where a fixture describes a state the system
  /// cannot produce and deleting the code turns nothing red.
  ///
  /// ## WHY THE MATCH IS EXACT: NO FOLDING, NO TRIMMING, NO SPACE STRIPPING
  ///
  /// Folding would make this function accept a **wider** set of values than the
  /// backend's TypeScript union declares. `identity.middleware.ts:5` types the
  /// role as exactly `'kid' | 'viewer_servant' | 'admin_servant'`; a folded
  /// `'ADMIN_SERVANT'` is a string this client's UI would grant on, and one no
  /// server would ever mint. The first version to fold would therefore be
  /// strictly more permissive than the protocol it decodes, which is the
  /// wrong direction for a fallback to fail.
  ///
  /// **The same argument rules out normalising whitespace, and it is the reason
  /// the test pins padding rather than only capitals.** `switch (wire.trim())`
  /// accepts `' admin_servant'`, and `switch (wire.replaceAll(' ', ''))` accepts
  /// `'admin _servant'` — each a value outside the union, and each one the
  /// decoder would silently launder into a real role. Neither is assumed
  /// harmless: both were applied to the implementation and measured against the
  /// suite before this paragraph was written, and they are why
  /// `user_role_test.dart` holds a whitespace and separator negative set rather
  /// than a single `'kid '` case. An arm for `'admin-servant'` is the third
  /// widening fault this file has to survive, and it is a spelling fault rather
  /// than a normalisation — see that negative set.
  ///
  /// `'kid'` is spelled out as an arm even though `_` would catch it, because
  /// the three recognised values are the ones a reader of this function is
  /// checking and the fallback should not have to be reasoned about to see them.
  static UserRole fromWire(String wire) => switch (wire) {
    'kid' => UserRole.kid,
    'viewer_servant' => UserRole.viewerServant,
    'admin_servant' => UserRole.adminServant,
    _ => UserRole.kid,
  };

  /// The capabilities [role] grants.
  ///
  /// ## WHY IT IS A STATIC AND NOT A TOP-LEVEL FUNCTION
  ///
  /// [fromWire] above is the file's other conversion, and it is a static on this
  /// enum; a free `grantsFor` beside it made this the only entity file in
  /// `core/domain/entities/` with one, against the sibling
  /// `reading_language.dart`, which puts both of its conversions on the enum.
  /// Both directions of the role conversation are now reached the same way.
  ///
  /// A **static taking the role** rather than an instance getter, because the
  /// argument is a `UserRole` either way and the grant table is policy over the
  /// whole enum: `role.grants` would read as a property of one value, and the
  /// ladder property below is a statement about all three tables together.
  ///
  /// ## THE TABLE IS A LADDER, AND THE LADDER IS ASSERTED
  ///
  /// Three literal sets rather than one composed from another, because a `const`
  /// set cannot spread and a runtime composition would either allocate on every
  /// call or hide the table behind three private constants a reader has to chase.
  /// Three literals keep the whole grant policy visible in one expression.
  ///
  /// The cost of literals is that nothing *structurally* keeps them nested, so
  /// this function's tests assert it: admin ⊇ viewer servant ⊇ kid, and admin
  /// granted every [UserCapability] the enum declares. Both are properties no
  /// per-role exact-set assertion can express, and either one failing means the
  /// ladder stopped being a ladder.
  ///
  /// ## AND WHY THE SET IS UNMODIFIABLE
  ///
  /// A capability table that a caller can widen is a table no longer describing
  /// this file's policy — it describes whatever the last caller added, in one
  /// screen's lifetime, with no record. `const` set literals are unmodifiable by
  /// construction rather than by convention, so the guarantee survives someone
  /// writing `UserRole.grantsFor(r).add(…)` and finding out.
  ///
  /// **Neither the narrowest nor the widest table is a security control.** See the
  /// file's opening section: the server enforces nothing, so a grant that is
  /// accidentally too wide is a UI bug and one that is too narrow is a UI bug.
  /// What unmodifiability buys is that the *policy* stays the policy.
  static Set<UserCapability> grantsFor(UserRole role) => switch (role) {
    UserRole.kid => const <UserCapability>{
      UserCapability.readOwnReading,
      UserCapability.submitQuiz,
      UserCapability.viewCohortLeaderboard,
    },
    UserRole.viewerServant => const <UserCapability>{
      UserCapability.readOwnReading,
      UserCapability.submitQuiz,
      UserCapability.viewCohortLeaderboard,
      UserCapability.viewServantReport,
    },
    UserRole.adminServant => const <UserCapability>{
      UserCapability.readOwnReading,
      UserCapability.submitQuiz,
      UserCapability.viewCohortLeaderboard,
      UserCapability.viewServantReport,
      UserCapability.scheduleReading,
      UserCapability.manageQuestions,
    },
  };
}

/// One thing a role can do in this client.
///
/// ## EVERY MEMBER IS A SCREEN OR A CONTROL, NEVER AN ENDPOINT
///
/// These are **client-side** affordances. They do not correspond to routes this
/// client calls in a different way, and nothing here should be read as "the
/// server allows this" — the server allows all of it to everyone, which is the
/// section at the top of this file.
///
/// The six are named for what a screen would need in order to make sense for
/// the reader holding the role, and the table itself is
/// [UserRole.grantsFor] on the enum rather than a top-level function beside
/// this one:
///
/// | capability | the kid / servant / admin reading |
/// | --- | --- |
/// | [readOwnReading] | reading today's passage. Every role. |
/// | [submitQuiz] | answering a question. Every role. |
/// | [viewCohortLeaderboard] | the ranking card on `/`. Every role. |
/// | [viewServantReport] | the daily servant report. Servants and admins. |
/// | [scheduleReading] | choosing what a group reads next. Admins. |
/// | [manageQuestions] | authoring and committing questions. Admins. |
///
/// The first three are what the reader came for, and every role has them
/// because a servant is also a reader — a viewer servant who could not read
/// today's passage would be a strange product, and the backend would let them
/// try anyway.
enum UserCapability {
  /// Open and read the passage scheduled for today.
  readOwnReading,

  /// Answer a reflection question and submit it.
  submitQuiz,

  /// See where this reader stands in their group's ranking.
  viewCohortLeaderboard,

  /// Open the daily report a servant prepares for their group.
  viewServantReport,

  /// Schedule the next reading for a group.
  scheduleReading,

  /// Write, edit and commit reflection questions.
  manageQuestions,
}
