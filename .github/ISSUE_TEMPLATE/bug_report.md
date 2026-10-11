---
name: Bug report
description: Behaviour differs from what the gates or the documentation say
title: "bug: "
labels:
  - bug
assignees: []
---

# Bug report

This repository is gated rather than casual: a claim about behaviour is worth
much more with a command attached than without one. The questions below are the
ones [SUPPORT.md](../../SUPPORT.md) already lists, in the order that triage
actually needs them.

## What you ran, and what you expected instead

The exact command, not "the app", and what you expected it to do. If the
expectation comes from a document, name the document.

## The full gate output

Paste the whole output of the run below, not a paraphrase of it and not the
first error. **A bug report without this cannot be triaged in this
repository**, because every answer starts from knowing which gates are already
red.

```bash
tool/verify_all.sh
```

If this exits `2` rather than `1`, say so. Exit `2` means a gate could not run
and checked nothing, which is a different situation from a gate that ran and
failed, and the difference is invisible in the exit code once the script is
gone.

## Your toolchain

```bash
flutter --version
```

Flutter 3.47.4 and Dart 3.13.3 are what this project is recorded against, and a
version difference is a very common cause of a report nobody can reproduce.

## Platform and device

The only currently supported target is Linux desktop. Give the OS and the
display server, and the window size if the problem looks size-dependent.

## Against the stock backend?

Four of the seven screens read live data, so state which of these you tried:

- [ ] Reproduces against the stock backend, started unmodified with
      `NODE_ENV=development PORT=3000 node dist/server.js`.
- [ ] Reproduces with no backend running.
- [ ] Not tested against a backend.

`NODE_ENV=development` is not optional. Started under `NODE_ENV=test`, the
in-memory fallback skips its pre-seed and the leaderboard answers empty every
time, so "the leaderboard is always empty" is a fact about that process rather
than about the backend.

## Is this a backend bug?

This client does not own the API. If an endpoint 404s, a header is rejected, or
a response body disagrees with the contract in AGENT_CONTEXT §5, that belongs in
the backend's own tracker, not here.
[`docs/BACKEND-VERIFICATION.md`](../../docs/BACKEND-VERIFICATION.md) records
several places where the backend disagrees with itself — read it before filing,
it may already answer your report.

## Is this visual only?

A layout, colour, spacing, or typography defect may already be known. A major UI
overhaul is planned, and the design-system decisions behind it are under review.
[ROADMAP.md](../../ROADMAP.md) records what that overhaul will touch; the
decisions themselves are
[ADR-0016](../../docs/adr/0016-dark-glassmorphic-design-system.md) through
[ADR-0019](../../docs/adr/0019-performance-budget.md). Say so here if your
report is visual-only, and a reviewer will tell you whether it is planned.

If a reader can see the problem rather than read it in the code, a screenshot
or a short screen recording is worth more than a paragraph of description.