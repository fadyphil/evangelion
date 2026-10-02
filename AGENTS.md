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
flutter pub get                 # install
flutter run -d linux            # the only device currently available
flutter analyze                 # types + lint + DEPRECATION warnings — the main gate
dart format lib test            # formatting
flutter test                    # unit + widget + golden
dart test --coverage=coverage   # coverage -> coverage/lcov.info
```

Target a different backend at build time:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:3000
```

## Architecture in one paragraph

Feature-first clean architecture. Dependency direction is strictly inward:
`presentation → domain ← data`. The shared kernel `core/domain/` holds the four repository
ports and every entity consumed by two or more features. `core/domain/` and every
`features/*/domain/` are **pure Dart** — no `package:flutter`, no `package:dio`, no
`package:http`. **No feature may import another feature.** If two features need the same
type, it belongs in `core/domain/`.

The six screens are `/login`, `/`, `/reading`, `/quiz`, `/result`, `/settings`. The
Library and Profile screens were **cut** — the backend has no endpoints for them.

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
dart run build_runner build --delete-conflicting-outputs
```

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