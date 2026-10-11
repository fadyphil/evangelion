---
name: Feature request
description: Propose a change and argue it is in scope, not just useful
title: "feat: "
labels:
  - enhancement
assignees: []
---

# Feature request

A request here has two parts, and the second is the one that decides whether it
proceeds. What the change adds is easy to describe. What problem it solves, and
whether the project is allowed to solve it, is the part that needs an argument.

## What problem does this solve?

Describe the situation someone is in today, and what they cannot do. A proposal
stated as a list of screens, endpoints, or widgets answers a different question
than the one that matters, and it is the question that survives review.

If you have already looked for an existing answer, link to it. A proposal that
misses an existing design decision tends to get re-litigated rather than
decided.

## Is this already planned?

Before you file, check the two places that record what is planned:

- [ROADMAP.md](../../ROADMAP.md), which separates work that is blocked on the
  backend from work that is decided and not yet started, and
- the ADRs in [`docs/adr/`](../../docs/adr/), which carry the current decisions
  and their status.

If your request overlaps something already recorded there, say which entry it
overlaps. A request that reopens a decided item is a legitimate request, but it
is a different kind of request and needs to be framed as one.

## Scope check

[`docs/agents/AGENT_CONTEXT.md`](../../docs/agents/AGENT_CONTEXT.md) is the
single source of truth for scope, and §2 is a table of **locked decisions** —
agreed, not open to renegotiation. Two of them bound every request:

- **Six screens.** Library and Profile are cut. There is no passage library, no
  category system, no reflection history, and no user profile.
- **Live API, local settings.** Reading, quiz, result, and streak come from the
  backend; settings are local only, with no server sync.

A request outside that scope is not refused automatically. It has to **reopen
the locked decision** explicitly, in this issue, by saying which decision and
why it should change — which is a different and much larger task than the one
you are proposing. Saying that here is not an obstacle; arriving without it
is.

## Implementation sketch

Roughly how you would build it, which layer it touches, and what it would cost
in tests. If you do not know yet, say so — that is a useful thing to know at the
start of a discussion and an unhelpful thing to guess at.

## Anything else

Links to prior discussion, or to the `eva/` prototype if this has a visual side.
Note that this repository has no Discussions tab, so prior discussion means an
issue or a pull request, and those are linked like any other file.