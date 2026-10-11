# Support

This repository is a Flutter client with a small number of places questions
can usefully go. The table below routes you to one of them.

## Where to ask

Most questions land in GitHub Issues, and that is fine. What matters is that a
security issue does not, and that a backend issue goes to the project that owns
the backend.

| I want to… | Go to |
| --- | --- |
| Report a bug | [GitHub Issues](https://github.com/fadyphil/evangelion/issues/new/choose) |
| Request a feature | [GitHub Issues](https://github.com/fadyphil/evangelion/issues/new/choose) |
| Ask a usage question | [GitHub Issues](https://github.com/fadyphil/evangelion/issues/new/choose) |
| Report a security issue | **Do not open an issue.** Follow [`SECURITY.md`](SECURITY.md) |
| Report a problem with the backend | **Not this repository.** See below. |
| Contribute a fix | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Report unacceptable behaviour | [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) |

> [!NOTE]
> This repository has **no Discussions tab** configured, so questions go in
> Issues. Two issue templates are configured — a bug report and a feature
> request — and the checklist below covers what both of them ask for. If the
> missing Discussions tab is inconvenient, it is a reasonable thing to want
> changed.

## Before you file

Almost every bug report that gets answered on the first pass carries the same
five things. They are cheap to collect and they are the difference between a
question and a round trip.

| Include | Why |
| --- | --- |
| What you ran | The exact command, not "the app". |
| The full gate output | Paste the whole `tool/verify_all.sh` summary, not your paraphrase of it. |
| `flutter --version` | This repository pins Flutter 3.47.4 and Dart 3.13.3. A different version is a very common cause. |
| The platform and OS | The only currently supported target is Linux desktop. |
| Whether it reproduces against the stock backend | Started with `NODE_ENV=development PORT=3000 node dist/server.js`, unmodified. |

If you are reporting something a reader can see rather than something you have
read in the code, a screenshot or a short screen recording is worth more than a
description of what you expected to happen.

## Backend issues are not filed here

The API this client talks to is a **separate project in a separate
repository**, and this repository neither owns it nor may modify it. A wrong
response shape, a missing endpoint, or a server that will not start is a bug in
that project and belongs in its own tracker.

How to tell which side you are looking at:

- **The client.** A screen renders the wrong thing, a widget is misplaced, a
  test fails, a gate is red, or a documented invariant in
  [`docs/agents/AGENT_CONTEXT.md`](docs/agents/AGENT_CONTEXT.md) does not match
  the code. File here.
- **The backend.** An endpoint 404s, a header is rejected, a response body
  disagrees with the contract in AGENT_CONTEXT §5, or the server will not boot.
  File there.

Measurements of how the backend actually behaves — including several places
where it disagrees with itself — are in
[`docs/BACKEND-VERIFICATION.md`](docs/BACKEND-VERIFICATION.md). Read it before
you file; it may already record your observation, and if it does, that is the
answer.

> [!WARNING]
> An empty response is a fact about a **process**, not a property of a system.
> If you report "the leaderboard is always empty", say how you started the
> server. Started under `NODE_ENV=test`, the in-memory fallback skips its
> pre-seed and the endpoint answers empty every time.

## Licence

The project is licensed under the [MIT License](LICENSE).
