# docs/proposals/ — NOT WHAT THIS CODEBASE SHIPS

Everything in this directory is a **design proposal**. None of it describes the code as
it exists, and none of it may be used as a reference for what the client does.

**If you are reading this to understand the client, stop and read
[`../DRIFT.md`](../DRIFT.md) and `docs/agents/AGENT_CONTEXT.md` instead.**

## Why these are here rather than deleted

They were written against the **backend's** surface rather than the client's, and they
are kept because the backend contract they describe is real even where the client
implementation is not. `models.md` §0.1 flags its own status correctly; `CLIENT.md` does
not, which is why the banner below is mandatory rather than decorative.

## `CLIENT.md`

Written 2026-10-10, untracked until this move. **It describes an architecture this
project rejected and then, in part, adopted.** Specifically wrong as a description:

| It says | The client actually does |
| --- | --- |
| `Either<Failure,T>` from `fp_dart` | ✅ now true — see `lib/core/common/result.dart` |
| `json_serializable` DTOs in `wire/dto/` | ❌ no such dependency, no such directory (banned, decision 8c) |
| 14 DTOs; bilingual **and** localized shapes | ❌ the client reads one shape: `GET /readings/today/{en,ar}` |
| "7 screens · 4 endpoints" | ⚠️ 7 routes, 5 endpoints — and its "7 screens" counted differently |
| `getOrElse` is unsound; never use it | ❌ **false** — `R` is the payload type, not inferred |
| `identity_headers.dart:125 defaultGroupId = 3` | ⚠️ verify against the file before trusting the line number |

Its **§6 trap table and §3 wire shapes are the valuable part** — those were read off the
backend and are worth re-verifying, not re-deriving.

## `models.md`

Better behaved. Its §0.1 opens by naming its own conflict with decision 8c, which is the
right thing to do and is why it needs no correction. Its DTO classes are a **proposal
for `json_serializable`** that was never adopted.

One claim in it is now **provably false** and is worth reading for the reasoning rather
than the conclusion:

> §0.1 / §7 imply `fp_dart` is a better `Either` and the hand-written `Result` should be
> replaced.

The replacement happened (`docs/DRIFT.md` §3). The expected wins did **not**:
`fp_dart` does not fix collection equality, and it loses the covariance guard that
decision 131 built. The features gained — `flatMap`, `traverse`, `Either.Do` — are
available and **currently unused**.

## Rule

Nothing in `docs/` root may describe a design. If a proposal becomes the design, it
moves out of here **and** the authority document (`docs/agents/AGENT_CONTEXT.md`) is
amended in the same change, so there is never a moment where two documents disagree
about what ships.
