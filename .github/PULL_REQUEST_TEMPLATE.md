# Pull request

This repository runs eight gates, and a reviewer should not have to reconstruct
your gate run from the diff. Answer the five questions below in this
description rather than leaving a reviewer to go and find the answers. They are
the questions listed in [CONTRIBUTING.md](../CONTRIBUTING.md), same order.

> [`docs/agents/AGENT_CONTEXT.md`](../docs/agents/AGENT_CONTEXT.md) is the
> single source of truth for scope, architecture, and standards. It **wins over
> every other document in this repository**, including CONTRIBUTING.md and this
> template. If this checklist disagrees with it, this checklist is wrong.

## What this changes

One paragraph, or a `file:line` pair. Say what changed and what problem that
solves.

## The gate summary

Paste the output of this, run before you opened the pull request:

```bash
tool/verify_all.sh --with-build
```

"Tests pass" is not an answer, and neither is a paraphrase of the output. Paste
the summary block. A reviewer who has to rebuild your evidence will not.

| # | Gate | Result |
| --- | --- | --- |
| 1 | Format | |
| 2 | Analyze | |
| 3 | Architecture | |
| 4 | Citations and reachability | |
| 5 | Fixable APIs | |
| 6 | Test suite | |
| 7 | Coverage floor | |
| 8 | Linux build | |

## Reviewer questions

Answer each one. "Not applicable" is an answer; silence is not.

- **Which gate proves this change?** Name the gate, the exact command, and the
  output that proves it.
- **Did you plant a violation to prove the gate fires?** Required if this change
  touched a gate or a gate's inputs. Give the scratch path you used outside the
  repository and the exit code you observed.
  [`tool/verify_gates_selftest.sh`](../tool/verify_gates_selftest.sh) does this
  for the existing gates if you want a worked example.
- **Are the goldens and the prototype citations a coupled pair?** If any golden
  changed, every changed golden has been re-checked against its `eva/`
  citation. **Re-recording goldens without re-checking the citations is a review
  failure**, not an oversight.
- **Did the coverage floor move?** If
  [`tool/baseline/gates.txt`](../tool/baseline/gates.txt) is in the diff,
  `--update-baseline` was run deliberately and the old and new values are
  explained here. It is written only by that flag, and re-recording the floor is
  never a way to make a red run green.
- **Does this change a documented invariant?** If so, AGENT_CONTEXT was updated
  in this same change, with the measurement that establishes the new invariant.

## Confirmations

Tick each one, or explain why it does not apply.

- [ ] `dart analyze` ran with `--fatal-infos --fatal-warnings` and reported zero
      issues. That single command is the enforcement for types, lints, and
      deprecated API usage alike.
- [ ] No `// ignore:` directive appears in hand-written code. Dart has no
      `unnecessary_ignore`, so an ignore nobody needed could not have been
      detected. If you believe you need one, change the declaration instead.
- [ ] No `print` and no `dynamic`.
- [ ] No dependency outside the approved set, and nothing changed in
      `docs/plans/`.
- [ ] The commit message is `<type>(<scope>): <subject>`.

## Scope and the backend

The backend is a **separate project in a read-only sibling checkout**. This
repository must never modify it. If the task appeared to need a backend change,
did you stop and escalate that in your report rather than working around it?

Also confirm the change stays inside the locked scope: six screens, Library and
Profile cut. AGENT_CONTEXT §2 is a table of decisions that are not open to
renegotiation, and a change that reopens one is a change that has to say so
out loud here.

## Anything else

Open questions, known gaps, or a claim in this description that no gate
enforces and that a reader should treat as a person's assertion rather than a
measurement. [`docs/DRIFT.md`](../docs/DRIFT.md) is a catalogue of what that
looks like once it has gone stale.