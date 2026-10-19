# AGENTS.md — Evangelion Flutter client

Flutter client for **Evangelion**, a bilingual (Arabic Smith & Van Dyck / English NKJV)
Sunday-School daily Bible reading platform. Fastify 3.47-era backend, live REST API.

> **The authority for how to build this project is
> [`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md).** It defines scope,
> architecture, Dart standards, the forbidden-API table, the TDD protocol, and the
> verification gates. Read it before writing code. It overrides any conflicting statement
> anywhere else in this repository, including these docs and anything under `docs/plans/`.

## Commands

```bash
flutter pub get                                           # install
flutter run -d linux                                      # the only device currently available
dart analyze --fatal-infos --fatal-warnings               # types + lint + DEPRECATION — THE gate
dart format --output=none --set-exit-if-changed lib test  # formatting gate
flutter test                                              # unit + widget + golden
flutter test --coverage                                   # coverage -> coverage/lcov.info
```

**Use `flutter test`, never `dart test`.** The plain Dart VM has no `dart:ui` and cannot
compile Flutter SDK sources, so `dart test` fails to load *every* test file — including the
pure-Dart ones — because each imports `flutter_test`.

The analyzer command is `dart analyze`, not `flutter analyze`, so the documented gate is
byte-identical to AGENT_CONTEXT §7.

Target a different backend at build time:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:3000
```

### If it aborts with `GLib-GIO-ERROR … 'xsettings' does not contain a key named 'antialiasing'`

The app **built and launched** — this is an environment fault, not a code fault. Check
`echo $GSETTINGS_SCHEMA_DIR`. If it points inside a **snap** directory (VS Code ships
one at `~/snap/code/*/.local/share/glib-2.0/schemas`, which contains no GNOME
schemas), GLib searches there, finds nothing, and aborts on every launch:

```bash
GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas flutter run -d linux
```

That fixes the abort. If the window still does not appear, the GTK shell is picking
X11 on a Wayland session (`gdk_x11_window_get_xid: assertion 'GDK_IS_X11_WINDOW
(window)' failed`); run it from your own terminal, where the session env is correct.

**Do not trust a build to mean the app runs.** Per decision 142,
`flutter build linux --release` reported `✓ Built` for three commits while the toolchain
was missing entirely. `tool/verify_linux_build.sh` exists because of that, and
`flutter doctor`'s `✓ Linux toolchain` line is the one command that checks the
*machine* rather than the source.

### Running the backend (read-only — never modify it)

```bash
cd /home/fady/Projects/EvangelionBackend
NODE_ENV=development PORT=3000 node dist/server.js
```

`NODE_ENV=development` is **not optional**. `InMemoryRedisFallback`'s constructor
pre-seeds the leaderboard ZSETs only when `NODE_ENV !== 'test'`, so a server started
under `NODE_ENV=test` answers with an empty leaderboard — which is how decision 143
came to record "the leaderboard is always empty" as a property of the backend when it
was a property of a process. No Postgres or Redis is required; both fall back to
in-memory.

If you background it, use `setsid … & disown`. A plain `&` is killed when the calling
shell exits and every request then returns `000`, which reads like a server fault.

What the running server is actually like is measured in
[`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md).

## Architecture in one paragraph

Feature-first clean architecture. Dependency direction is strictly inward:
`presentation → domain ← data`. The shared kernel `core/domain/` holds the four repository
ports and every entity consumed by two or more features. `core/domain/` and every
`features/*/domain/` are **pure Dart** — no `package:flutter`, no `package:dio`, no
`package:http`. **No feature may import another feature.** If two features need the same
type, it belongs in `core/domain/`.

The **seven** screens are `/login`, `/`, `/reading`, `/quiz`, `/result`, `/settings` and
`/communion` (the cohort's board, renamed from `/leaderboard` in Task 5.5).

The Library and Profile screens were **cut** under ADR-0001 and are **coming back**
under ADR-0022: the library carousel returns to `/` as a surface and Profile becomes
`/journey`. `/result` retires to a modal in Phase 6. **AGENT_CONTEXT §2's route table
is the authority on what is registered today** — this paragraph is a summary, and a
summary that drifts is worse than no summary.

## Non-negotiables

1. **`dart analyze` must report zero issues** with `--fatal-infos --fatal-warnings`. It is
   the objective gate for types, lints, and deprecated API usage alike.
2. **No deprecated APIs.** The forbidden list is in AGENT_CONTEXT §4. The list is a seed —
   the analyzer is the enforcement. Fix with `dart fix --apply --code=deprecated_member_use`.
3. **Domain purity is mechanically checked.** See AGENT_CONTEXT §7 for the `rg` commands.
   Matches mean failure.
4. **The backend is read-only.** Never write to `/home/fady/Projects/EvangelionBackend`.
   It is reference material, not a workspace.
5. **Never** add a dependency, new screen, or endpoint outside the current task's scope.

## Regenerating code

```bash
dart run build_runner build
dart run build_runner clean   # only when a stale generated file needs purging
```

In `build_runner` 2.16.x the old `--delete-conflicting-outputs` flag was **removed**. Passing
it prints `W These options have been removed and were ignored` and still exits `0`, so an
agent believes the outputs were purged when they were not. Run `clean` explicitly instead.

Two generators run: `auto_route_generator` (emits `*.gr.dart` routers) and
`injectable_generator` (emits `*.config.dart` DI registration). Both regenerate
**globally** across the package, so two agents must never run codegen concurrently.

`build.yaml` pins both injectable builders to `lib/**/*.dart`; build_runner silently
ignores options for an unknown builder key, so a stale key leaves the file inert without
erroring.

## Project layout

```
lib/
  main.dart            bootstrap
  app/                 composition root: DI, router
  core/
    design_system/     tokens, theme, effects, 27 widgets
    common/            Result, Failure, AppConfig
    domain/            SHARED KERNEL: ports + multi-consumer entities (pure Dart)
    network/           Dio client, header interceptor, error mapper
    navigation/        route name constants
  features/<f>/
    domain/            this feature's use cases only (pure Dart)
    data/              models, mappers, data sources, repository impls
    presentation/      bloc/cubit, pages, widgets
assets/fonts/          20 static TTFs, 5 families (bundled, not fetched at runtime)
docs/plans/            port plan, corrected against live-API scope
docs/agents/           AGENT_CONTEXT.md — the authority
eva/                   React design prototype (reference only, not built)
```

## Git

One branch per phase (`feat/phase-N-<name>`), merged to `main` at each gate after review.
Commit format: `<type>(<scope>): <subject>`.

## Deployment note

`android/app/build.gradle.kts` still uses the placeholder application id
`com.example.evangelion`. Same for the iOS bundle identifier. Change both before any real
distribution.