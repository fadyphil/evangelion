#!/usr/bin/env python3
"""citation_check.py — every `X.html:NNN` claim must resolve to a real reference line.

## WHAT THIS IS FOR

AGENT_CONTEXT recorded decision 8: "Nothing in this suite compares a golden to the
React prototype... every transcription claim in this repository is a claim a human
verified by reading `eva/`". That is still true of 1000-odd citations, and it has
a demonstrated failure rate — Phase 5's prototype harness "found two of its own
citations wrong on its first run" (decision 8), and decision 33 found three more.

So the claims are checked mechanically here, in the smallest way that can catch
rot: does the cited line exist?

## THE REACT PROTOTYPE IS **RETIRED**, AND THIS GATE IS WHAT ENFORCES IT

`eva/src/` — the superseded React prototype — was deleted. **Its citations are
gone with it**, and the pattern below still MATCHES a `.tsx` citation on purpose:
**a `.tsx` citation is now a broken citation**, because no `.tsx` file is a
reference any more, and the gate says so by name.

**That is the point of leaving `tsx` in the pattern.** A pattern that stopped
matching `.tsx` would report a clean run over a surface it no longer examines —
the ADR-0020 shape, and the defect this repository has now met three times (a
gate that cannot fail, an inventory that hid a third of the design system, and
now a pattern that would have hidden a whole design). **The retirement is
enforced by the gate, not by a convention.**

## WHAT IT DOES AND DOES NOT CHECK

It checks **existence and range**. A citation to `redesign.html:525` must be
within `redesign.html`. It does NOT check that line 525 says what the citing
comment claims it says — that needs the claim to carry its own expected value,
which five of seven screens now do in their own geometry harnesses.

This is a floor, not a proof. A citation can resolve and still be about the wrong
line. That is what the per-screen geometry harnesses are for, and this does not
replace them.

## THE `WordReference.tsx` CLASS OF FINDING

A citation can also name a file that never existed. One does, in
`reading_text_scale_test.dart`. That is reported rather than exempted: a reference
a reader cannot follow is not documentation.

Exit:  0 every citation resolves
       1 at least one citation does not resolve (each printed with file:line)
       2 the check could not run
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


# **THE LIVE DOCUMENTS ARE SCANNED TOO**, and that is a strengthening rather
# than a chore: the authority document, the ADRs, the plan, the drift catalogue
# and the seams map are where the client's *claims* live, and until the
# prototype's retirement nothing in them was checked by anything.
#
# **`docs/plans/` is the ONE exception, and it is deliberate.** It is a
# historical record of analyses made against the React prototype, it is owned by
# somebody else (AGENTS.md: "Do not rewrite `docs/plans/`"), and it still
# carries about fifty citations to a prototype that has since been retired.
# **A document that records a past analysis is allowed to point at the past.**
DOC_ROOTS = ("docs/agents", "docs/adr", "docs/superpowers")
DOC_FILES = ("docs/DRIFT.md", "docs/SEAMS.md", "docs/ARCHITECTURE.md")
ROOTS = ("lib", "test", "tool")

SKIP_SUFFIXES = (".gr.dart", ".freezed.dart", ".config.dart")

# The two references the citations are resolved against, both NAMED rather than
# globbed.
#
# * `eva/redesign.html` — the design source of truth. Every screen, every token,
#   every number in the redesign is transcribed from it.
# * `eva/brief.txt` — the **original** brief, the one the React prototype was
#   built from and the one this redesign partly contradicts. It is the source of
#   the design *language* — "the ONLY sacred cues are: gold flecks, the verse
#   marker, and beautiful typography" — and a handful of claims still cite it.
#
# **Named, not globbed, is deliberate.** `eva/` was a Vite project and contained
# an `index.html` — the app shell, not a design reference. A `rglob("*.html")`
# picked it up and would have let a citation resolve against a file that
# declares no geometry at all. **A reference that is named cannot acquire a
# sibling by accident.**
#
# **AND THE BRIEF'S LINES ARE NOW CHECKED, WHICH THEY WERE NOT BEFORE.** Its
# filename had a hyphen in it, and the pattern above matches `[A-Za-z0-9_]+`, so
# `pasted-attachment.txt:97` never matched and its eight line citations were
# **never verified by anything**. Moving it to `brief.txt` and adding `txt` to
# the pattern closes that hole.
HTML_REFERENCE = ROOT / "eva" / "redesign.html"
BRIEF_REFERENCE = ROOT / "eva" / "brief.txt"

# BOTH references are REQUIRED, and their absence is FATAL rather than a reduced
# set of checks.
#
# That was found by planting a violation: removing redesign.html while nothing
# cited it yet left 12 .tsx files resolving, so the gate reported a green run
# over a reference that no longer existed. The check that would have caught it
# was the one doing the checking, so nothing noticed.
#
# This is the ADR-0020 shape exactly — a gate that passes over a surface it is
# no longer examining — and the only repair is to make the missing input loud.
#
# **The React prototype's directory is NOT in this list any more, and its
# absence IS the retirement.** It was `REQUIRED_REFERENCES = (TSX_ROOT,
# HTML_REFERENCE)`; now it is two named files.
REQUIRED_REFERENCES = (HTML_REFERENCE, BRIEF_REFERENCE)

# `name.html:12` and `name.html:12-34`. The name may be preceded by anything, so a
# match inside a longer word is fine — `ds.html` inside `HomeScreen.ds.html` should
# resolve.
#
# `.html` is the redesigned reference, committed as the design source of truth. It is
# a single file, `eva/redesign.html`, and a citation to it is `redesign.html:NNN`.
# The extension is alternated rather than a second pattern so the range syntax is
# written once.
#
# **`.tsx` IS STILL IN THE PATTERN, AND THAT IS DELIBERATE.** The React prototype
# is retired, so a `.tsx` citation is a citation to a file that does not exist —
# and the gate must say so rather than stop looking. A pattern that stopped
# matching would report a clean run over a surface it no longer examines, and
# that is the failure this gate exists to prevent.
#
# **THE NAMED REFERENCES ARE MATCHED BY NAME, NOT BY EXTENSION.** A generic
# `.txt` arm looked like the obvious thing to add for the brief, and it made
# every `CMakeLists.txt:25` in the tree — a quoted CMake error message — into a
# broken citation. A citation may name **one of the references**, or a `.tsx`
# or `.html`, and those two extensions are unambiguous here: there is exactly
# one `.html` and it is the design reference, and `.tsx` is retired and must be
# reported.
_CITE_NAMES = "|".join(re.escape(p.name) for p in REQUIRED_REFERENCES)
CITATION = re.compile(
    rf"(?P<file>(?:{_CITE_NAMES})|[A-Za-z0-9_]+\.(?:tsx|html)):"
    r"(?P<from>\d+)(?:-(?P<to>\d+))?"
)


def reference_files() -> dict[str, int]:
    """name -> line count, for every reference file a citation may name."""
    out: dict[str, int] = {}
    for path in REQUIRED_REFERENCES:
        if path.is_file():
            with path.open(encoding="utf-8", errors="ignore") as fh:
                out[path.name] = sum(1 for _ in fh)
    return out


def missing_references() -> list[str]:
    """Every required reference that is absent, named for the error message."""
    missing = []
    for path in REQUIRED_REFERENCES:
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
    return missing


def scanned_files() -> list[Path]:
    files: list[Path] = []
    for root in ROOTS:
        base = ROOT / root
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.dart")):
            if p.name.endswith(SKIP_SUFFIXES):
                continue
            files.append(p)
    for root in DOC_ROOTS:
        base = ROOT / root
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.md")):
            files.append(p)
    for name in DOC_FILES:
        p = ROOT / name
        if p.is_file():
            files.append(p)
    return files


def main() -> int:
    absent = missing_references()
    if absent:
        print(
            "FATAL: a required design reference is missing — "
            + ", ".join(absent)
            + ". Citations cannot be verified against what is not there, and "
            "silently checking a smaller surface is the failure this gate exists "
            "to prevent.",
            file=sys.stderr,
        )
        return 2

    lens = reference_files()
    if not lens:
        print("FATAL: reference files were found but none could be read", file=sys.stderr)
        return 2

    files = scanned_files()
    if not files:
        print("FATAL: no Dart files to scan", file=sys.stderr)
        return 2

    total = 0
    resolved = 0
    problems: list[tuple[Path, int, str]] = []

    for path in files:
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), 1):
            for m in CITATION.finditer(line):
                total += 1
                name = m.group("file")
                lo = int(m.group("from"))
                hi = int(m.group("to")) if m.group("to") else lo
                cite = f"{name}:{m.group('from')}"
                if m.group("to"):
                    cite += f"-{m.group('to')}"

                if name not in lens:
                    problems.append((path, lineno, f"{cite}  -> no such reference file"))
                    continue
                n = lens[name]
                if hi > n:
                    problems.append(
                        (path, lineno, f"{cite}  -> {name} has {n} lines (max {n})")
                    )
                elif lo < 1:
                    problems.append((path, lineno, f"{cite}  -> line numbers start at 1"))
                else:
                    resolved += 1

    if total == 0:
        print("FATAL: found zero citations — the pattern has rotted", file=sys.stderr)
        return 2

    print(f"reference files: {len(lens)}  ({', '.join(sorted(lens))})")
    print(f"citations found: {total}   resolved: {resolved}   broken: {len(problems)}")

    if problems:
        print()
        for path, lineno, why in problems:
            rel = path.relative_to(ROOT).as_posix()
            print(f"  BROKEN  {rel}:{lineno}  {why}")
        print()
        print(f"FAILED — {len(problems)} of {total} citations do not resolve.")
        print("Fix the citation or delete the claim. A reference a reader cannot")
        print("follow is not documentation.")
        return 1

    print("PASSED — every citation resolves to a real reference line.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
