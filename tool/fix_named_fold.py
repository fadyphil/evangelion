#!/usr/bin/env python3
"""Rewrite `fold({onSuccess: A, onFailure: B})` into fp_dart's `fold(B, A)`.

## WHY A PARSER AND NOT A REGEX

An earlier attempt used `re.S` with `(?P<fail>.*?)`, which does not stop at the
arm boundary. Against

    result.fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => -1)

it produced `fold<int>((Failure _, Function(int v) Function => v) => -1)` —
the success arm's parameter list ended up in the failure arm's slot, and the
file stopped compiling. `dart fix` then "repaired" the broken syntax into
different broken syntax. The rule's own count reported a MATCH before it ran,
so the dry run said it would work. It matched. It was wrong.

So this walks the parentheses instead. It finds `fold(`, then matches balanced
parentheses to find the two named arguments, then splits at the comma that
sits at depth 0. Arm bodies containing commas, nested calls and block bodies
are all handled, because depth — not a character class — decides what is an
arm boundary.

Usage: tool/fix_named_fold.py [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def split_top_level(body: str) -> list[str]:
    """Split a call's argument list on commas that are at parenthesis depth 0."""
    parts, depth, cur = [], 0, []
    in_str = None
    i = 0
    while i < len(body):
        c = body[i]
        if in_str:
            cur.append(c)
            if c == "\\":
                if i + 1 < len(body):
                    cur.append(body[i + 1])
                    i += 2
                    continue
            elif c == in_str:
                in_str = None
            i += 1
            continue
        if c in "'\"":
            in_str = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                break
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    parts.append("".join(cur))
    # A trailing comma leaves an empty final part. Dart allows it, and the
    # original hand-written call used it, so it must not turn a two-arm call
    # into an apparent three-argument one.
    while parts and not parts[-1].strip():
        parts.pop()
    return parts


def rewrite(text: str) -> tuple[str, int]:
    out, i, n = [], 0, 0
    # `onSuccess:` need not be adjacent to the `(` — the arms are routinely
    # written one per line, which is exactly the shape an anchored pattern
    # missed. Search for the bare `.fold` and let the argument check below
    # decide whether it is a NAMED fold worth rewriting.
    pat = re.compile(r"\.fold(?P<t><[^<>\n]*>)?\(")
    while True:
        m = pat.search(text, i)
        if not m:
            out.append(text[i:])
            break
        out.append(text[i : m.start()])
        # walk from the '(' to its matching ')'
        depth, j, in_str = 0, m.end() - 1, None
        while j < len(text):
            c = text[j]
            if in_str:
                if c == "\\":
                    j += 1
                elif c == in_str:
                    in_str = None
            elif c in "'\"":
                in_str = c
            elif c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = text[m.end() - 1 + 1 : j]  # between the parens
        parts = split_top_level(body)
        stripped = [p.strip() for p in parts]
        # Only rewrite a genuinely NAMED fold. `onSuccess:`/`onFailure:` may
        # appear in an arm BODY (a nested call), so the label has to be at the
        # start of its own argument, not merely present somewhere.
        if len(parts) != 2 or not (
            stripped[0].startswith("onSuccess:") and stripped[1].startswith("onFailure:")
        ):
            out.append(text[m.start() : j + 1])
            i = j + 1
            continue
        succ = re.sub(r"^\s*onSuccess:\s*", "", parts[0])
        fail = re.sub(r"^\s*onFailure:\s*", "", parts[1])
        fail = re.sub(r",\s*$", "", fail)
        t = m.group("t") or ""
        out.append(f".fold{t}(\n{fail},\n{succ},\n)")
        n += 1
        i = j + 1
    return "".join(out), n


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    total, changed = 0, 0
    for base in ("lib", "test"):
        for p in sorted((ROOT / base).rglob("*.dart")):
            if p.relative_to(ROOT).as_posix().endswith((".gr.dart", ".freezed.dart")):
                continue
            t = p.read_text(encoding="utf-8")
            if ".fold" not in t or "onSuccess:" not in t:
                continue
            new, n = rewrite(t)
            if n:
                total += n
                changed += 1
                if not args.dry_run:
                    p.write_text(new, encoding="utf-8")

    print(f"{'DRY RUN — ' if args.dry_run else ''}rewrote {total} named fold(s) "
          f"across {changed} file(s)")
    if total == 0:
        print("  <-- MATCHED NOTHING. Either already done, or the pattern rotted.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())