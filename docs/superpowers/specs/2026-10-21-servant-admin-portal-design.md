# The Servant/Admin Portal — Design

> **Authority:** `docs/agents/AGENT_CONTEXT.md` is the single source of truth and
> **wins over this document**. This spec records a decision that **reverses
> AGENT_CONTEXT §2 decision 5**, and the amendment to that file ships in the same
> change (`docs/adr/0026-the-servant-admin-portal.md`).
>
> **Status:** approved 2026-10-21. **Date:** 2026-10-21. **Deciders:** the user.

---

## 1. What is being built

A **servant portal** — a second, adult-facing surface in the same Flutter client —
that lets a church servant:

* **read** the daily roster completion report for a cohort, and
* (**admin only**) schedule a reading for a cohort, decide whether its question is
  AI-generated or hand-written, and author the question and its answers.

There are **two** admin types, matching the backend's own role union:

| role | wire value | may do |
| --- | --- | --- |
| `kid` | `kid` | the reader's app only |
| `viewerServant` | `viewer_servant` | the reader's app **+ the daily report** |
| `adminServant` | `admin_servant` | the reader's app **+ the daily report + scheduling + authoring** |

**Kids cannot reach the admin shell. The admin shell can reach the kids' shell.**

---

## 2. The authority change

`AGENT_CONTEXT.md` §2 decision 5 reads, today:

> **No servant/admin portal.** Those backend routes stay untested from the client.

It is **reversed** by the user on 2026-10-21 and becomes:

> **5 (amended 2026-10-21).** The servant/admin portal ships as the `servant`
> feature. The two servant roles land on `/servant`; a `kid` cannot reach it. The
> backend's admin and AI routes are now client surface, and the role union is
> honoured **as advisory UX, not authorisation** — the backend parses
> `X-User-Role` at `src/middleware/identity.middleware.ts:24`, assigns it at `:31`,
> and never reads it again (`rg 'user\??\.role' src/` → no matches; `rg '403' src/`
> → no matches).

The reversal is recorded in `docs/adr/0026-the-servant-admin-portal.md`, and
`lib/core/navigation/app_routes.dart`'s `servant` constant — whose own doc says
"**the successor that registers the portal route replaces this paragraph**" — has
that paragraph **replaced**, not annotated.

**This is not a security boundary.** A role gate here prevents *accidents*: a child
is not dropped onto a scheduling screen, and a viewer servant is not shown a
control that reports nothing. Nothing on the server enforces any of it, because the
header is set by the client and every endpoint answers whoever asks.

---

## 3. Routes

| Route | Page | `kid` | `viewerServant` | `adminServant` |
| --- | --- | --- | --- | --- |
| `/login` | `LoginPage` (role picker added) | ✅ | ✅ | ✅ |
| `/` | the dock shell (the reader's app) | ✅ | ✅ | ✅ |
| `/servant` | `ServantHomePage` — the hub | ❌ | ✅ | ✅ |
| `/servant/report` | `ServantReportPage` | ❌ | ✅ | ✅ |
| `/servant/schedule` | `ScheduleReadingPage` | ❌ | ❌ | ✅ |
| `/servant/questions` | `QuestionAuthoringPage` | ❌ | ❌ | ✅ |

`/servant` is **already declared** in `lib/core/navigation/app_routes.dart` and is
**already the landing route** for both servant roles
(`lib/core/navigation/landing_route.dart`). What this change adds is the three
sub-routes and the registration.

### 3.1 The hub, not a tab shell

`/servant` is a **hub page**: the sections this role has, as a list. It is not an
`AutoTabsRouter`, because a `viewerServant` has **one** section and a tab shell
with one tab is a tab bar that exists to hold one thing.

### 3.2 The two directions of access

* **Kids → admin shell: blocked twice.** The dock shell carries **no** admin
  entry, *and* a `RoleGuard` refuses the navigation. The second is the one that
  counts; the first is decoration, and the test asserts the second.
* **Admin → kids shell: allowed.** The hub carries a "read as a reader" entry that
  pushes `/`, and both servant roles keep `readOwnReading`, `submitQuiz` and
  `viewCohortLeaderboard` in `UserRole.grantsFor` (already true today).

### 3.3 The landing route

`landingRouteFor(role)` gets its **first caller**: after a successful sign-in the
app lands on `landingRouteFor(session.role)` — `/` for a `kid`, `/servant` for
either servant role. The function already existed with no caller; the seam was
built for exactly this.

---

## 4. How a reader becomes an admin

There is **no auth endpoint** (AGENT_CONTEXT §2 decision 3), so the role is
**chosen locally on the login screen** — which is what
`lib/core/domain/entities/user_role.dart` already documents.

A **three-way `SegmentedControl`** on `/login` (kid / viewer servant / admin
servant) whose value flows:

```
AuthState.role  →  SignInParams.role  →  AuthRepository.signIn(role:)  →
seedAuthSession(role:)  →  AuthSession.role
```

### 4.1 The wire follows the session

`X-User-Role` is today a **frozen `kid` string** baked into
`IdentityHeadersInterceptor` at composition. It becomes a **live reader** so the
client does not claim `kid` while the UI says `admin_servant`:

* `IdentityHeadersInterceptor.role` becomes `String Function()` — a reader, not a
  value. The interceptor calls it **per request**.
* The reader is fed by the **same `RoleAccess` instance** the navigation guard
  reads, over the `AuthLocalDataSource`'s session.

**One session, one role, no mirror.** `AuthSession.role` is the source of truth;
`RoleAccess` is a *reader* over it (the `LiveRoleAccess` shape that already
exists in `lib/core/navigation/role_access.dart`), and the interceptor reads the
same seam. The backend ignores the header; the client still must not lie about it.

**The wiring must stay in the pure half.** `core_module.dart` builds the `Dio`,
and `injection.dart`'s graph must stay Flutter-free (recorded decision 4). So
`RoleAccess` is registered in the **pure** module — over the pure
`AuthLocalDataSource` — and both the interceptor and the guard read that one
registration. `AuthBloc` (Flutter-side) is **not** in this path.

> `AuthLocalDataSource` gains a **synchronous** view of its session
> (`AuthSession? get currentSession`). The store is an in-memory field by design
> (its own doc says so), so a synchronous read is honest here; the async
> `readSession()` stays for the port.

---

## 5. Feature layout

`lib/features/servant/` — feature-first, `presentation → domain ← data`, and
`features/servant/domain/` is **pure Dart** (Gate 1).

```
lib/features/servant/
  domain/
    entities/
      reading_schedule.dart      ReadingSchedule, ExcludedVerse
      schedule_result.dart       ScheduleResult
      question_draft.dart        QuestionDraft, QuestionOption, QuestionType
      commit_result.dart         CommitResult
      servant_report.dart        ServantReport
      roster_student.dart        RosterStudent
    repositories/
      servant_admin_repository.dart   ServantAdminRepository
      servant_report_repository.dart  ServantReportRepository
    usecases/
      schedule_reading.dart
      commit_questions.dart
      generate_ai_draft.dart
      load_daily_report.dart
  data/
    datasources/
      servant_remote_data_source.dart
    mappers/
      schedule_mapper.dart
      question_mapper.dart
      report_mapper.dart
    repositories/
      dio_servant_admin_repository.dart
      dio_servant_report_repository.dart
  presentation/
    cubit/
      servant_report_cubit.dart
      schedule_reading_cubit.dart
      question_authoring_cubit.dart
    pages/
      servant_home_page.dart
      servant_report_page.dart
      schedule_reading_page.dart
      question_authoring_page.dart
    widgets/
      roster_row.dart
      question_option_editor.dart
```

### 5.1 The two ports

Two **narrow** ports, not one fat one (AGENT_CONTEXT §3, ISP):

```dart
abstract interface class ServantAdminRepository {
  Future<Result<ScheduleResult>> scheduleReading(ReadingSchedule schedule);
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  });
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  });
}

abstract interface class ServantReportRepository {
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,      // YYYY-MM-DD
  });
}
```

Both live in `features/servant/domain/repositories/` — **one** consumer each
(the `servant` feature), so §3's placement test keeps them out of
`core/domain/`. The `kid`'s shell needs neither.

### 5.2 The entities

| entity | fields |
| --- | --- |
| `ReadingSchedule` | `groupIds: List<int>`, `scheduledDate: String`, `bookNumber: int`, `startChapter: int`, `startVerse: int`, `endChapter: int?`, `endVerse: int`, `excludedVerses: List<ExcludedVerse>`, `generateAiQuestions: bool` |
| `ExcludedVerse` | `chapter: int`, `verse: int` |
| `ScheduleResult` | `message: String`, `readingIds: List<String>` |
| `QuestionDraft` | `type: QuestionType`, `promptAr: String`, `promptEn: String`, `options: Map<String, QuestionOption>`, `correctAnswer: String`, `pointsValue: int`, `sortOrder: int`, `isApproved: bool` |
| `QuestionOption` | `ar: String`, `en: String` |
| `CommitResult` | `message: String`, `questionIds: List<String>` |
| `ServantReport` | `groupId: int`, `reportDate: String`, `totalStudents: int`, `completedCount: int`, `students: List<RosterStudent>` |
| `RosterStudent` | `userId`, `fullName`, `preferredLang`, `totalPoints: int`, `currentStreak: int`, `pointsEarnedToday: int`, `completedToday: bool`, `questionsProgress: String` |

`QuestionType` is an enum over the backend's three: `mcq`, `trueFalse`,
`shortAnswer` — with the wire spellings `mcq`, `true_false`, `short_answer`
spelled out per member (the `UserRole.wireValue` rule: `.name` is never a wire
value).

---

## 6. The endpoints, exactly as the backend expects them

Read from `/home/fady/Projects/EvangelionBackend/src/modules/admin/admin.routes.ts`
and `.../ai/ai.routes.ts` (read-only reference material).

| screen | call | request | response |
| --- | --- | --- | --- |
| schedule | `POST /api/v1/admin/readings/schedule` | `{group_ids: int[], scheduled_date: 'YYYY-MM-DD', book_number: 1..66, start_chapter, start_verse, end_chapter?, end_verse, excluded_verses: [{chapter,verse}], generate_ai_questions: bool}` | `201 {message, reading_ids: string[]}` |
| questions (manual) | `POST /api/v1/admin/questions/commit` | `{reading_id, questions: [{type, prompt_ar, prompt_en, options: {A: {ar,en}, …}, correct_answer, points_value, sort_order, is_approved}]}` | `201 {message, question_ids: string[]}` |
| questions (AI) | `POST /api/v1/admin/questions/ai-generate` | `{reading_id, type: 'mcq'\|'true_false'}` | `200 {reading_id, draft_question: {type, prompt_ar, prompt_en, options, correct_answer}}` |
| report | `GET /api/v1/servant/reports/daily?group_id=&date=` | — | `200 {group_id, report_date, total_students, completed_count, students: [{user_id, full_name, preferred_lang, total_points, current_streak, points_earned_today, completed_today, questions_progress}]}` |

### 6.1 The three doors into a question

1. **AI at schedule time.** `generate_ai_questions: true` → the server generates
   and attaches the question inside the schedule transaction. One call.
2. **Hand-written.** `generate_ai_questions: false` → the admin writes the
   question and the answers on `/servant/questions`, which receives the
   `reading_id` from the schedule response, and commits.
3. **AI draft, then edit, then commit.** Schedule without AI → "generate a draft"
   (`ai-generate`) → the admin edits it → commit.

The draft's `options` has the **same shape** as the commit endpoint's
(`Record<string, {ar, en}>` — `ai.service.ts:9` and its `responseSchema`), so a
draft is editable and committable without a conversion.

### 6.2 Three backend behaviours the UI must state, not hide

* **Re-scheduling updates in place.** The insert is
  `ON CONFLICT (group_id, scheduled_date) DO UPDATE` (`admin.routes.ts:157`), so
  scheduling the same group and date again **replaces** the passage.
* **Re-scheduling with AI on deletes the previous questions.**
  `DELETE FROM questions WHERE reading_id = $1` (`admin.routes.ts:195`). The
  schedule screen says so before the admin toggles AI on over an existing
  schedule.
* **The schedule endpoint is the only one that creates a reading.** There is
  **no "list my scheduled readings" endpoint** — so a questions screen for a
  reading scheduled in a *previous* session needs a typed `reading_id`. The
  screen accepts one and says where it came from, rather than pretending a
  lookup exists.

---

## 7. Presentation

* **No `setState`.** `test/setstate_budget_test.dart` is a gate: a new
  `setState` outside the reviewed allowlist is red. Every piece of mutable state
  lives in a cubit, and the cubit is a **whole-state writer** (ADR-0009).
* **Three cubits**, one per screen that has server state:
  * `ServantReportCubit` — `groupId`, `date`, `status`, `report`, `failure`.
  * `ScheduleReadingCubit` — the form fields, `status`, `result`, `failure`.
  * `QuestionAuthoringCubit` — `readingId`, the draft being edited, `status`,
    `commitResult`, `failure`.
* **The design system is reused, not extended.** The pages are composed from the
  existing widgets: `NeuralScaffold`, `EvaTextField`, `EvaButton`,
  `SegmentedControl` (the role picker), `EvaToggle` (the AI switch),
  `SettingsGroup` / `SettingsTile` (the hub), `StatTile` (the report's
  numbers), `EmptyState`, `ErrorView`, `EvaToast`, `HairlineDivider`.
  **No new tokens, no colour literals** (`no_colour_literals_test.dart`), and
  **no new blur** — the `lib/features/` blur budget is **1** today
  (`glass_blur_budget_test.dart`) and this adds none.
* **The admin screens have no counterpart in `eva/redesign.html`.** They are
  **written, not transcribed**, so the citation gate gets no new
  `redesign.html:NNN` claims to resolve — and the pages must not cite the
  prototype as if it described them.
* **Both languages.** The app is bilingual, so the new strings go into
  `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` and are regenerated with
  `flutter gen-l10n` (which is **not** `build_runner`).

---

## 8. The access rule on the wire

`/servant*` routes carry a **second** guard beside `AuthGuard`:

```
guards: [AuthGuard(authStatus), RoleGuard(roleAccess, UserCapability.viewServantReport)]
```

`RoleGuard` **refuses** — it redirects to the landing route — and **never
throws**, for `AuthGuard`'s recorded reason: a throw escapes
`onNavigation`, the router builds nothing, and a cold launch gets a blank first
frame. `RoleAccess.allows` is documented as a **UI question, not a security
one**, and that wording must survive into the guard's own doc.

**The guard reads the role ONCE, and the seam answers for a given role.** A
seam built on a reader guarantees liveness, not atomicity — two reads can be
handed two roles if the app emits in between — and `role_access.dart`'s own
hazard #2 names the remedy: capture the role once. So the interface gains
`allowsRole(UserRole role, UserCapability capability)`, `allows` answers through
it, and the guard captures the role **once** per navigation, asks the grant for
*that* role, and sends the refusal to `landingRouteFor` of *that same role*.
**One answer path**: the guard and the hub must not answer the same question
from two places.

---

## 9. Testing

### 9.1 Red-first (AGENT_CONTEXT §6)

Entities · use cases · models and mappers · the two repositories · every cubit
(`bloc_test` + `mocktail`) · `RoleGuard` · the changed `AuthRepository` port.

### 9.2 Alongside the widget

Behaviour + widget + golden tests for the four pages, and for the two new
widgets (`roster_row.dart`, `question_option_editor.dart`).

### 9.3 The negative controls

* a `kid` is refused `/servant` — **asserted in the failing direction**;
* a `viewerServant` sees **no** "schedule a reading" entry on the hub;
* an `adminServant` **does**;
* the hub's "read as a reader" entry pushes `/`;
* the role picker on `/login` puts the chosen role in the session, and the
  interceptor's `X-User-Role` header says it.

---

## 10. The gates (AGENT_CONTEXT §7)

All eight must pass before the work is reported done:

| gate | what this work can break |
| --- | --- |
| 1 format | new files |
| 2 analyze | every new file; `deprecated_member_use` is the enforcement |
| 3 architecture | `features/servant/domain/` must be pure; no feature may import another |
| 4 citations + orphans | every new widget must be on a registered page's tree; every new page must be registered in the router |
| 5 `dart fix --dry-run` | — |
| 6 `flutter test` | — |
| 7 coverage | `tool/baseline/gates.txt` is a **budget of uncovered lines**; new uncovered lines push it over |
| 8 Linux build | — |

Plus the standing gates: the `setState` budget, the rebuild-isolation budget, the
colour-literal gate, the Arabic-typography gate, the blur budget, the barrel
inventory, and the secret-masking scan.

**A gate that cannot fail is worse than no gate.** Every gate this work touches
is negative-controlled: the violation is planted in a scratch copy outside the
repository, the correct non-zero exit and message are confirmed, and the
violation is removed.

---

## 11. What is explicitly **out** of scope

* **No backend change.** The backend is read-only reference material
  (AGENT_CONTEXT §8.2).
* **No new dependency** (AGENT_CONTEXT §8.4).
* **No `docs/plans/` rewrite** (AGENT_CONTEXT §8.6).
* **No real authentication.** The role picker is a local choice, and the
  `UserRole` doc says so.
* **No "list my scheduled readings" screen** — the endpoint does not exist
  (§6.2).
* **No editing or deleting an already-committed question** — the backend has no
  such endpoint.
* **No server-side role enforcement** — the backend has none, and adding one is
  a backend change.
* **No medals, notes or any other invented surface.**

---

## 12. The portal's **visual** design

> **Status:** approved 2026-10-22. **Deciders:** the user. This section
> records a change to §7's *"The design system is reused, not extended"* — the
> system is still reused and still not extended, but **how the portal's four
> screens are composed** is decided here rather than left to the settings
> screen's components.

### 12.1 The problem this answers

The portal's four screens shipped as **the Settings screen's own components**:
`SettingsGroup` (a mono-caps gold section label) around `SettingsTile`s (flat
hairline rows with a chevron). The hub was therefore four flat rows under a
gold label on a bare canvas, and each of the three working screens was **one
undifferentiated list** — the schedule form's **eight** fields in a row, and the
editor's **eleven** controls in a row.

**Three things were missing, and all three are facts a reader needs:**

1. **Identity.** Nothing said which role was looking at the hub, and the hub's
   whole content depends on it — a viewer servant is offered one section and an
   admin servant three. Nothing said which day it was either, and the report
   is *today's* report.
2. **Hierarchy.** Every section looked the same, so the day's one routine task
   looked the same as the two occasional ones.
3. **A way out.** The three sub-routes are **pushed**, and `NeuralScaffold` has
   no app bar and no leading control of its own — its own doc says so: *"No
   `appBar`, no `floatingActionButton`, no `drawer`."* So a servant who opened
   the daily report on the **Linux desktop build** — the only device this app
   is currently runnable on — had **no visible way back to the portal**.

`CommunionAppBar`'s own doc records the same finding for `/communion` and the
same reason its control exists.

### 12.2 The hub is a **portal**, not a list

| | what it is | how it is drawn |
| --- | --- | --- |
| **The masthead** | the place, the standing, the day | the display serif at `headlineSmall`; the standing in `emberInk`; the day in `ink2` |
| **The hero** | the daily report | a gold-washed `GlassSurface` with a 46px ruled mark, the title in the display serif, and a **gold** chevron |
| **The duties** | scheduling and authoring | two smaller panels under one gold mono-caps heading; the title and the mark share a line and the explanation sits under it |
| **The exit** | the reader's own shell | **not a panel** — a flat row under a rule, in the quieter inks |

**Three treatments, not three sizes of one card.** The craft floor this
repository holds itself to refuses a page whose structure is a column of
same-shaped cards, and the portal's cards are not that: the hero is a tinted
panel with a mark, the duties are flatter panels with a different internal
layout, and the exit is not a panel at all — because it is not one of the
portal's sections.

**The hero's gold is `EvaColors.ember` and its mark's glyph is `emberInk`.**
Decision 153's own split — *ember fills, emberInk writes* — decides it: a wash
and a rim are fills, and a glyph is writing. The two are the same value in
**dark**, so this moves the light palette only, and it moves it because
`ember`'s `#D4891A` measures about 2:1 against the light canvas (under the 3:1
WCAG asks of a meaningful glyph) while `emberInk`'s `#845610` measures 5.54:1.

**The gold wash and rim are the redesign's own rule**, `redesign.html:263`:
`.selah.active{background:rgba(232,176,75,.06);border-color:rgba(232,176,75,.5)}`.

### 12.3 The date is **the locale's own pattern**

`intl` ships a date pattern per locale, and the two arms write the same day two
different — and each in its own right — ways. Measured on `intl` 0.20.3:

```text
en  MMMMEEEEd -> "EEEE, MMMM d"  -> Wednesday, October 21
ar  MMMMEEEEd -> "EEEE، d MMMM"  -> الأربعاء، ٢١ أكتوبر
```

The English arm puts the month first and the Arabic arm puts the day first,
and the **separator is the locale's own** — the Arabic pattern carries '،'. A
hand-written pattern literal would have put an ASCII comma in an Arabic
sentence, and `MaterialLocalizations.formatMediumDate` writes "Thu, Oct 22"
beside "الخميس، ٢٢ أكتوبر": an abbreviated English weekday against a full
Arabic one, on a screen that is bilingual.

**And the tables these patterns come from are FLUTTER'S, not `intl`'s** —
which is not a detail, because the two differ in the numerals.
`flutter_localizations`'s own `loadDateIntlDataIfNotLoaded` installs **its**
`generated_date_localizations.dart` through `intl`'s
`initializeDateFormattingCustom`, for every locale at once, the first time any
Material localisation loads. Flutter's `ar` table carries **`ZERODIGIT: '٠'`**;
`intl`'s own `ar` table has **no `ZERODIGIT`** and would write "21 أكتوبر" in
ASCII digits. **So the Arabic-Indic day on the hub is Flutter's table**, and
it agrees with the app's own numeral rule (`arabicIndicDigits`) because they
are the same digits.

**No year**: the portal's sections are about *one day*, and the year matters on
the report screen, which has a **date field** that says so.

### 12.4 The three working screens are **grouped**, and they have an app bar

* Each opens with **`ServantAppBar`** — a back chevron and the screen's name —
  and the screen's name is **no longer** a settings group's label. A section
  label is a marker in the middle of a page; a title is a title.
* The schedule form's eight fields become **three named groups** — *the cohort
  and the day*, *the passage*, *the question* — and the editor's eleven
  controls become **three** — *the reading*, *the question*, *the answer*.
* **The primary action leaves the group.** A button nested inside a labelled
  group reads as one more thing that group is for.

**The field order is unchanged**, so the suites that type into
`find.byType(TextField).at(n)` still address the same fields.

### 12.5 The app bar is **viewport-fixed**, and its title's box is **computed**

**Fixed**, because the two screens it titles are long — eight fields and
eleven controls, which is several screens of scrolling at 320×568 — and a back
control that scrolls off is not a back control. `NeuralScaffold`'s own doc
names the rule for the `overlay` slot this uses: *"A floating affordance that
scrolls off is not a floating affordance — it is the last thing on the page
until you scroll back."* And `/reading`, the app's other long pushed screen,
already answers it the same way.

The two app bars that **scroll** — `CommunionAppBar` and `WorkshopAppBar` —
are on screens that are **tabs of the dock shell**, so the dock is always on
screen and the bar is not the only chrome. **The portal has no dock.**

**The title's box is computed, not a percentage.** The prototype's
`redesign.html:145` is `max-width:52%`, which is a number for a **390px**
frame with 18px of app-bar padding — a title box of 184px. At **320** this
app's bar is 288px wide, so the same 52% would be **149.8px**, and
"Schedule a reading" at the reader's largest text scale measures **172.4px**.
The title would have been **truncated**, and a truncated title is §14's "the
reader's words deleted".

So the cap is **the bar's width less the two control zones** — at 320, 288 −
104 = **184px**, which is the prototype's own 390px number, and 34px more than
its 52% would give at 320. The title stays centred, the chevron stays clear of
it, and the longest of the three titles fits at the narrowest surface and the
largest scale.

`servant_text_scale_test.dart` holds both: the title's **truncation flag** at
320 × 1.22, and **that the bar does not move when the form scrolls**.

### 12.6 What this **did not** change

* **No new token.** Every colour is `EvaColors`; the palette table is untouched.
* **No new blur.** The `lib/features/` budget is still **one**, and the home
  screen's today's-reading panel still has it.
* **No new dependency** (AGENT_CONTEXT §8.4).
* **No new endpoint, and no new data.** The hub cannot show a live number,
  because the backend has no "list my cohorts" and no "list scheduled
  readings" route (§6.2) — so it carries the role, the day and one line per
  section, and **nothing it cannot know**.

### 12.7 The hero's rim, measured

The hero's rim is `ember` at **50%** and its wash is `ember` at **6%** — the
redesign's own rule, `redesign.html:263`. Measured against the surface
beneath:

| | the hero's rim against the canvas | the app's own `glassBorder` against the canvas | the mark's glyph against the hero's surface |
| --- | --- | --- | --- |
| dark | **3.21:1** | 1.01:1 | **8.66:1** |
| light | **1.60:1** | 1.19:1 | **5.26:1** |

**The light figure is the honest one and it is below the 3:1 WCAG asks of a
component boundary.** The hero's rim is *stronger* than the design system's own
panel rim in both palettes — the light palette's panel rims have never
reached 3:1 — and **what carries the hero in the light palette is the wash and
the mark's glyph, not the rim**. The mark's ruled box is a frame around a glyph
that measures 5.26:1, and the numbers are here so a reader can check that
rather than take it.

A rim strong enough to clear 3:1 in the light palette would need a **new
token** — `ember` and `emberInk` are the only two golds the palette publishes,
and `emberDeep` at full strength is a different colour in the dark palette.
*"No new tokens"* decides it, and the measurement is what makes the decision a
recorded one rather than an unnoticed one.

### 12.8 The gates this work is held to

* **The viewport matrix now covers the portal** — all four screens at 320×568,
  390×844 and 430×932, and the hub in **both** arms. The matrix was written
  for the reader's six screens and the portal landed after it, so the app's
  second surface had no viewport coverage at all.
* **The portal has a text-scale harness** — `servant_text_scale_test.dart` —
  which the other seven screens have and the portal did not. The viewport
  matrix deliberately does not sweep the scale, so before this file the
  portal's four screens had **neither** a scale harness **nor** a scale sweep.
* **The Arabic typography gate declares every new Arabic run**, and the hub's
  day is **fixed** there for the same reason the golden fixes it: a gate that
  declared "today" would be a gate that failed every morning.
* **The hub's day is a seam** — `ServantHomePage.today` — exactly as
  `ServantReportPage.today` is, and for the reason its doc gives: *"A golden
  is not a shape: it is a picture."*
