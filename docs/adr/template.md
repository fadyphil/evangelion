# ADR-NNNN: <Imperative title — "Use X", not "We will use X">

The record of one architectural decision: what forced it, what was chosen, what
was rejected, and what it costs.

- **Status:** proposed
- **Date decided:** YYYY-MM-DD
- **Recorded:** YYYY-MM-DD
- **Deciders:** <who decided>
- **Authority:** `docs/agents/AGENT_CONTEXT.md` <section or decision number>

## Context

What forced the decision. Name the constraint, the measurement, or the failure
that made the previous approach untenable. Two to five sentences — if this
section runs past ten lines, the ADR is too long or the decision is too small
to record.

## Decision

What was decided, stated in present tense as a fact of the codebase. "The
client reads X", not "the client will read X".

## Alternatives considered

### <Alternative name>

- **Pros:** <what it would have been better at>
- **Cons:** <what it would have cost>
- **Why not:** <the specific reason, with a measurement or a `file:line` where
  one exists>

A rejected alternative with no recorded reason is not a rejected alternative —
it is an option somebody forgot to consider. "We did not think of it" is an
honest entry and belongs here.

## Consequences

### Better

- <what becomes easier>

### Worse

- <what becomes harder, stated plainly rather than softened>

### Neutral / noted

- <what is unchanged, or what a future change must watch for>

## Traceability

Where this decision came from, and what depends on it. Every entry is a path a
reader can open.

- `docs/agents/AGENT_CONTEXT.md` §N decision N
- <any other source, each with a path or a `file:line`>
