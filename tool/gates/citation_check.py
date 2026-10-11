#!/usr/bin/env python3
"""citation_check.py — every `X.tsx:NNN` claim must resolve to a real prototype line.

## WHAT THIS IS FOR

AGENT_CONTEXT recorded decision 8: "Nothing in this suite compares a golden to the
React prototype... every transcription claim in this repository is a claim a human
verified by reading `eva/`". That is still true of 1000-odd citations, and it has
a demonstrated failure rate — Phase 5's prototype harness "found two of its own
citations wrong on its first run" (decision 8), and decision 33 found three more.

So the claims are checked mechanically here, in the smallest way that can catch
rot: does the cited line exist?

## WHAT IT DOES AND DOES NOT CHECK

It checks **existence and range**. A citation to `ds.tsx:525` must be within
`ds.tsx`, which is 570 lines today. It does NOT check that line 525 says what the
citing comment claims it says — that needs the claim to carry its own expected
value, which five of seven screens now do in their own geometry harnesses.

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

# `name.tsx:12` and `name.tsx:12-34`. The name may be preceded by anything, so a
# match inside a longer word is fine — `ds.tsx` inside `HomeScreen.ds.tsx` should
# resolve.
CITATION = re.compile(r"(?P<file>[A-Za-z0-9_]+\.tsx):(?P<from>\d+)(?:-(?P<to>\d+))?")

# Only these trees are scanned. `eva/` is the reference material itself, so
# scanning it would report every example in a comment.
ROOTS = ("lib", "test", "tool")

SKIP_SUFFIXES = (".gr.dart", ".freezed.dart", ".config.dart")


def prototype_files() -> dict[str, int]:
    """name -> line count, for every `.tsx` under eva/src."""
    out: dict[str, int] = {}
    eva = ROOT / "eva" / "src"
    if not eva.is_dir():
        return out
    for p in sorted(eva.rglob("*.tsx")):
        with p.open(encoding="utf-8", errors="ignore") as fh:
            out[p.name] = sum(1 for _ in fh)
    return out


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
    return files


def main() -> int:
    if not (ROOT / "eva" / "src").is_dir():
        print("FATAL: eva/src not found — nothing to check against", file=sys.stderr)
        return 2

    lens = prototype_files()
    if not lens:
        print("FATAL: no .tsx files under eva/src", file=sys.stderr)
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
                    problems.append((path, lineno, f"{cite}  -> no such prototype file"))
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

    print(f"prototype files: {len(lens)}  ({', '.join(sorted(lens))})")
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

    print("PASSED — every citation resolves to a real prototype line.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
