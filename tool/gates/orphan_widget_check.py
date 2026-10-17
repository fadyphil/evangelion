#!/usr/bin/env python3
"""orphan_widget_check.py — a widget built and tested but never placed on a screen.

## WHAT THIS IS FOR

AGENT_CONTEXT decision 144 records the defect this exists to make impossible:

> "`LeaderboardCard` was written, given a DI seam, a five-surface overflow matrix
> and a 21-test view suite — and **no page instantiated it**. ... Every §7 gate
> was green throughout."

Three suites were green and correct about their own subject: the view suite proved
the card renders (by instantiating it directly), the bloc test proved it fetches,
and the page test asserted the greeting, the wordmark, the flame and the panel. The
join between them was untested. The recorded lesson:

> "Three suites, all green, all correct about their own subject, and together they
> could not tell whether the feature shipped."

So the question this answers is not "is this widget tested" — it is **"does any
page's tree contain it"**, which is the only question none of those suites asked.

## THE TRANSITIVITY PROBLEM, AND WHY A NAIVE VERSION IS WRONG

A widget is placed if it is *reachable* from a page, not if it is *named* by one.
`SealFabTrigger` is built by `SealFab`, which `HomePage` places — so `SealFab`
places it, and a scan that only looked inside `presentation/pages/` would report
two false positives on its first run. An earlier hand-written version of this check
did exactly that: it listed `SealFabPill`, `SealFabTrigger`, `EvaInk`,
`EvaSectionHeader` and `PassageDropCap` as orphans, and every one of them is
placed.

So reachability is computed transitively: a widget is placed if any *placed* widget
constructs it, and the walk terminates on cycles.

## WHAT COUNTS AS "A WIDGET"

Only classes extending `StatelessWidget` or `StatefulWidget` from
`package:flutter/widgets.dart`. A plain value class, a painter, an inherited
widget or an enum is not a widget for this purpose — `EvaFocusRingScope` is one and
is correctly invisible here.

## WHAT IT DOES NOT CHECK

Whether the placed widget renders *the right data*, or appears in the right order,
or is visible at the viewport it matters at. It answers one question: is this class
in any screen's tree. That is the question decision 144 says nothing was asking.

Exit:  0 every widget is placed (or is allowlisted with a written reason)
       1 at least one widget is built, tested and never placed
       2 the check could not run
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

DECL = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|sealed\s+)*"
    r"class\s+(?P<name>[A-Z][A-Za-z0-9_]*)"
    # The optional type-parameter list is NOT optional. `class SegmentedControl<T>
    # extends StatefulWidget` is a widget like any other, and an earlier version of
    # this pattern had no `(?:\s*<[^>]*>)?` and therefore matched no generic widget
    # at all — silently, with no error. `SegmentedControl` was reported as neither
    # placed nor orphaned for that reason. A gate that quietly skips a class of
    # declarations is the same defect as one that cannot fail.
    r"(?:\s*<[^>{]*>)?"
    r"\s+extends\s+(?:StatelessWidget|StatefulWidget)\b",
    re.M,
)

SKIP_SUFFIXES = (".gr.dart", ".freezed.dart", ".config.dart")

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    """Remove `/* */` and `//` comments, preserving line structure.

    Doc comments matter here: a widget's own `///` prose naming its siblings is
    exactly the kind of text that makes a bare-name scan report a false pass.
    Newlines are preserved so a stripped file still reports the same line count,
    which keeps any reported `file:line` meaningful.
    """
    text = _BLOCK_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    text = _LINE_COMMENT.sub("", text)
    # Doc comments are `///` and get caught by the line rule above; a block form
    # `/** ... */` is caught by the block rule. Nothing else is stripped, so a
    # string literal containing a name would be a false negative — acceptable,
    # because this only ever errs toward reporting MORE, never fewer.
    return text

# Classes that are legitimately not placed on a page, each with the reason. An
# entry here is a PRODUCT decision, not a convenience — the same rule
# `text_contrast_gate_test.dart` applies to `knownSubstandard`: the list cannot
# grow silently.
ALLOWLIST: dict[str, str] = {
    "WitnessSky": (
        "Phase 3 Task 3.3 shipped the widget; Phase 5 places it. It is the "
        "full-bleed `#sky` layer (eva/redesign.html:116) and its three consumers "
        "are Phase 5's screens — `/reading` lights verses as they scroll into "
        "view (eva/redesign.html:1208-1221), `/quiz` fires the flares "
        "(`:1428`) and `/journey` counts the sky (`:1186-1189`). Placing it "
        "here would mean inventing the reader's scroll observer, a router entry "
        "and a settings row — all three of which the dispatch for this task "
        "explicitly withholds. The entry is STALE the moment any page "
        "constructs it, and the gate reports that, so it cannot outlive its "
        "reason."
    ),
    "SealMonogram": (
        "Phase 5.1 rebuilt `/login` against eva/redesign.html:503-511, whose "
        "brand block is a wordmark and a tagline — the seal is one of the "
        "elements the redesign deleted from that screen. The widget survives "
        "because Task 4.2 re-rolled its treatment to `.jorb` "
        "(eva/redesign.html:392-395) and `/journey` draws that orb in Task 5.6; "
        "between those two tasks it is genuinely unplaced. Same mechanism as "
        "WitnessSky's entry: STALE the moment any page constructs it."
    ),
}


def dart_files() -> list[Path]:
    out: list[Path] = []
    for root in ("lib",):
        base = ROOT / root
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.dart")):
            if p.name.endswith(SKIP_SUFFIXES):
                continue
            out.append(p)
    return out


def main() -> int:
    files = dart_files()
    if not files:
        print("FATAL: no lib/ to scan", file=sys.stderr)
        return 2

    texts: dict[Path, str] = {}
    for p in files:
        texts[p] = p.read_text(encoding="utf-8", errors="ignore")

    # name -> declaring file, and name -> set of names that construct it
    declared: dict[str, Path] = {}
    for p, t in texts.items():
        if "/widgets/" not in p.as_posix():
            continue
        for m in DECL.finditer(t):
            declared.setdefault(m.group("name"), p)

    if not declared:
        print("FATAL: found zero widget classes — the pattern has rotted", file=sys.stderr)
        return 2

    def constructs(haystack: str, name: str, hay_name: str) -> bool:
        """True if `name` is CONSTRUCTED in `haystack`, by a class other than itself.

        Both exclusions are load-bearing, and neither was optional.

        **Comments.** A bare-name match reports false PLACES. This repository
        discusses `EvaChip` and `SegmentedControl` constantly — in design-system
        docs, in `language_sheet.dart`'s "why not a SegmentedControl" reasoning,
        in `leaderboard_page.dart` describing a window switcher it does not have —
        and every one is prose, not a construction. Both widgets are in fact built,
        tested (8 and 3 goldens) and never rendered.

        **Self.** A widget's own constructor declaration matches its own name:
        `const SegmentedControl({...})`. Without excluding that, every widget
        places ITSELF and the gate reports zero orphans forever — which is the
        decision-144 failure mode wearing a green tick.

        The self test is by NAME, not by file: `seal_fab.dart` declares `SealFab`,
        `SealFabTrigger` and `SealFabPill`, and `SealFab` really does construct the
        other two. An earlier version excluded by file and reported both of them
        as orphans, which is the opposite error and just as wrong.
        """
        code = strip_comments(haystack)
        if hay_name == name:
            return False
        # The type argument is part of a generic construction:
        # `SegmentedControl<AppThemeMode>(...)` at settings_page.dart:203. A
        # pattern that stopped at `(` missed every generic widget's call sites,
        # which is how `SegmentedControl` was first reported as an orphan when
        # it is on `/settings` today.
        return re.search(rf"\b{re.escape(name)}\s*(?:<[^;{{}}]*>)?\s*\(", code) is not None

    # The root set: page files name what is on a screen directly.
    pages = [p for p in files if "/presentation/pages/" in p.as_posix()]
    if not pages:
        print("FATAL: no page files found — nothing is 'placed' by definition", file=sys.stderr)
        return 2

    placed: set[str] = set()
    for p in pages:
        t = texts[p]
        for name, owner in declared.items():
            if constructs(t, name, "<page> " + p.name):
                placed.add(name)

    # Transitive closure: a placed widget places what it constructs.
    changed = True
    while changed:
        changed = False
        for name in list(placed):
            owner = declared[name]
            t = texts[owner]
            for other, other_owner in declared.items():
                if other in placed:
                    continue
                if constructs(t, other, name):
                    placed.add(other)
                    changed = True

    orphans = sorted(n for n in declared if n not in placed)

    # An allowlisted entry must actually be unplaced — otherwise the exemption has
    # rotted and is hiding nothing.
    stale = sorted(n for n in ALLOWLIST if n in placed)
    for n in stale:
        print(f"  STALE    {n} is allowlisted but IS placed — remove the entry")
    stale_allow = [n for n in stale if n in ALLOWLIST]

    allowed_orphans = [n for n in orphans if n in ALLOWLIST]
    real_orphans = [n for n in orphans if n not in ALLOWLIST]

    print(f"widget classes declared under */widgets/ : {len(declared)}")
    print(f"reachable from a page                   : {len(placed)}")
    print(f"not placed                              : {len(orphans)}"
          f"  (allowlisted {len(allowed_orphans)}, real {len(real_orphans)})")

    if stale_allow:
        print()
        for n in stale_allow:
            print(f"  STALE ALLOWLIST  {n}")
        print()
        print(f"FAILED — {len(stale_allow)} allowlist entr(ies) are stale.")
        return 1

    if real_orphans:
        print()
        for n in real_orphans:
            print(f"  ORPHAN  {n}  ({declared[n].relative_to(ROOT).as_posix()})")
        print()
        print(f"FAILED — {len(real_orphans)} widget(s) are built and never placed.")
        print("Decision 144: a widget with a full test suite and no page that")
        print("instantiates it is invisible to every assertion that does not look")
        print("for it on the screen. Place it, delete it, or allowlist it WITH a")
        print("written reason — never suppress the failure.")
        return 1

    print("PASSED — every widget is reachable from a page.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
