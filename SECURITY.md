# Security policy

This file describes what the attack surface of this client actually **is**
today, rather than what a template says it should be. If a section here reads
as a caveat rather than a control, that is because the control belongs to a
component this repository does not own.

## Supported versions

The app is pre-release and there are no tagged releases yet. `pubspec.yaml`
declares `version: 1.0.0+1` and `publish_to: 'none'`, so nothing has been cut,
signed, or shipped to a store.

| Version | Supported |
| --- | --- |
| `main` | Yes — this is the only thing supported. |

> [!NOTE]
> There is no LTS branch and no backport policy, because there are no releases
> to backport to. If that changes, this table changes with it.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: open the **Security** tab of
this repository on GitHub and choose **Report a vulnerability**. That opens a
private advisory only the maintainer can read, which is the channel you want
for anything exploitable.

If private reporting is not available to you, email **<fadyph2003@gmail.com>**
with the same content.

Please include what you ran, what you expected, what happened, and the
platform. A proof of concept against the in-memory backend is more useful
than a description.

I ask for three things, and I will do all three in return:

- **Good faith.** Tell me what the impact is, and let me confirm it. I will not
  treat a mistaken report as a hostile one.
- **No public disclosure until I acknowledge the report.** That gives me time
  to ship a fix and publish an advisory.
- **Do not access data belonging to other users.** The backend in this project
  is seeded with demo accounts and runs with no authentication at all, so it is
  trivially "reachable". Probing it is expected; using one seed identity to
  impersonate another is not, and neither is anything against a deployment you
  do not own.

## Threat model

Everything below is a property of the system as it stands, not a list of
vulnerabilities waiting to be found. Most of it is inherited from the backend,
which is a separate project this repository must never modify — so if you are
here to report one of these, you are reporting a bug, not a vulnerability, and
the fix belongs elsewhere.

### There is no authentication on the backend

This is the single most important line in this file.

The API has **no authentication endpoint at all**. Identity is three headers
the client sets on every request, and none of them is verified:

| Header | What the server actually does with it |
| --- | --- |
| `X-User-Id` | Checks that it is present and non-empty, and nothing else. Any non-empty string — including a non-UUID such as `not-a-uuid` — is accepted and echoed back with a `200`. |
| `X-Group-Id` | Required on the reading and leaderboard routes. Never validated against anything. |
| `X-User-Role` | Parsed, then **never checked**. |

So `X-User-Id` is an identity *header*, not a credential. Anyone who can reach
the API can claim any identity on it.

> [!WARNING]
> **This client cannot fix this, and neither can a patch to it.** Any
> deployment of this client **must** put a real authenticating proxy — or a
> gateway that terminates TLS and verifies a token — in front of the API, and
> must strip the client's identity headers before setting its own. Running this
> client against an exposed, unauthenticated backend means anyone can read and
> write every reader's streak, answers, and standing.

Login in the app is UI-only. A `FakeAuthRepository` returns a seeded session
and no login request is ever sent, so nothing on screen is a claim about an
authenticated user.

### `X-User-Role` is not an authorization check

The header is parsed and ignored. Never gate a UI affordance on it in the
expectation that the server enforces the same rule: the server enforces
nothing. The client uses the role to **gate its own navigation** — see the
next section — and for nothing else, and it must stay that way.

### The servant portal's role gate is advisory, and it is measured

The portal added a **client-side** gate. `RoleGuard`
(`lib/app/router/role_guard.dart`) reads the `RoleAccess` seam over
`UserRole.grantsFor` and refuses to push `/servant/report`,
`/servant/schedule` and `/servant/questions` to a reader whose role does not
grant them.

**That gate is a navigation decision, not a boundary, and the backend is the
reason.** The portal's four routes were measured against the deployed
backend on **2026-10-22** (`YoussefOS2510/EvangelionBackend` @ `aa1da23`):
with `X-User-Role: kid`, with `viewer_servant`, with `admin_servant`, and
with no role header at all, **all four answer byte-identical bodies**. The
header is parsed by `identity.middleware.ts:24` and never read again, so the
server enforces **no role** on the routes that schedule a reading, commit
questions, draft questions, or report a cohort's roster. The measurement is
in [`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md).

Two consequences, and the second is the one that bites:

- **A reader refused in the app is not refused by the server.** The gate is
  the client's, and a client-side gate is a suggestion to a client.
- **A reader *not* refused in the app is not refused by the server either.**
  There is no 403 to expect. The server answers the request, and what it
  answers is somebody else's cohort — a roster of children's names — and a
  schedule that rewrites a reading.

So the role is **advisory UX**, and it must stay that way: it decides what
the app *draws*, never what the API *allows*. A deployment that needs the
second thing needs a gateway that authenticates and authorizes, in front of
the API, stripping these headers and setting its own — the same requirement
the warning above states for identity.

### Traffic is TLS, and the host is still not allowlisted

The default base URL is `https://evangelion-backend.vercel.app` — the deployed
backend, served over TLS by Vercel (ADR-0023). **The app's traffic is
encrypted in transit**, and the Android release build carries no cleartext
exemption: `android:usesCleartextTraffic="true"` was removed from
`android/app/src/main/AndroidManifest.xml` and now lives only in the `debug`
and `profile` manifests, because the local backend is still plain HTTP.
iOS never had an ATS exception, so it was already TLS-only.

**What is still true, and was true before:** the configured host is **not
allowlisted** beyond whatever you pass at build time. A
`--dart-define=API_BASE_URL=…` pointing at a plaintext host will be reached
over plaintext by a debug build, and a release build will refuse it outright —
which is the Android manifest doing its job, not a client-side check.

**And the identity is still the client's to claim.** `X-User-Id` is a header
the client sets, and the server enforces **presence**, not the shape of the
value. The client checks the shape itself, and that check now matters more
than it did: the deployed backend's database is a `uuid` column, so a
non-UUID `X-User-Id` is a **500** there rather than an echo
(`docs/DRIFT.md` §11).

### Settings are local-only, and there is nothing to protect

Appearance, reading, and about settings are persisted with
`shared_preferences` and never synced to a server. There is no account data,
no token, and no credential in local storage.

The consequence cuts both ways: there is no credential to steal, and equally
**no server-side revocation**. A signed-out device keeps its local settings,
because nothing tells the server or the app to clear them. Settings here are
not security state and must not be used as one.

### `AuthGuard` is a navigation convenience, not a boundary

`lib/app/router/auth_guard.dart` redirects to `/login` when there is no
session. That is a UX affordance. It is trivially bypassed — the session is
local state, and a redirect on a client is a suggestion to a client. Its own
doc comment says it must not grow a role check or token validation, because
that would be theatre that reads as defence.

Treat it exactly as what it is.

### Secret masking is enforced structurally

Four classes in this client hold a password. A generated `toString` would write
a reader's typed password into every log line and every failed assertion, so
each class declares its own `toString` that does not interpolate the field.

That is enforced by `test/core/common/secret_masking_test.dart`, which is
**structural**: it scans `lib/` for any class declaring a password field and
requires a `toString` that does not interpolate it, plus a behavioural half
against the classes that exist today. It discovers its own subjects, so a
class added tomorrow is covered without anyone remembering to add a test.

Please report anything that defeats it — a codegen path that emits a `toString`
bypassing the scan, a way to read the field back out of a log or a failure
message, or a class that holds a secret under a name the scan does not match.

### Third-party assets are bundled into the binary

Five font families ship as **20 static TTF files** under `assets/fonts/`, and
they are compiled into the binary rather than fetched at runtime. They are
third-party SIL Open Font License binaries, not code written for this project.

> [!NOTE]
> No license text is bundled alongside them under `assets/fonts/` today. The
> upstream licenses travel with the fonts, but a distribution that ships the
> binaries without them is a licensing gap worth closing before any real
> release.

Report a font asset you can show is compromised or has been substituted — a
file that does not match its declared family and weight in
[`pubspec.yaml`](pubspec.yaml), or one carrying unexpected payload. Because
there is no runtime fetch, asset substitution is a **supply-chain** concern
about the repository rather than a network one.

### The release state, plainly

A reader deciding whether to install this should know all of this:

- The Android application id in `android/app/build.gradle.kts` and the iOS
  bundle identifier are both still the `flutter create` placeholders,
  `com.example.evangelion`.
- There is no release build, no signing configuration, and no distribution.
- There is no tagged release and the package is marked `publish_to: 'none'`.

Nothing here is installed from a store and nothing should be treated as
authentic until those placeholders are replaced and a build is signed.

## Out of scope

Two categories of report will be declined, and both are about scope rather than
about severity:

- **Findings that require the backend to already be compromised.** A defect in
  a client that reads a payload the server already controls is not a client
  vulnerability.
- **Reports against the backend itself.** The API is a separate project with
  its own repository and its own disclosure process. Report it there. This
  repository does not own it, cannot patch it, and must never modify it.

If you are unsure which side of that line a finding falls on, send it anyway
and say which side you think it is. Deciding where it belongs is my job, not
yours, and a wrong guess costs you nothing.

## Related documents

Contributing work, rather than reporting a problem, is covered in
[`CONTRIBUTING.md`](CONTRIBUTING.md). Where to ask anything that is neither a
bug nor a security issue is [`SUPPORT.md`](SUPPORT.md). The measured
behaviour of the backend this client talks to is in
[`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md), and the
architecture that decides what runs on which side is in
[`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) §5.
