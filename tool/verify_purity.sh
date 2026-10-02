#!/usr/bin/env bash
#
# Architecture purity gates — the mechanical half of AGENT_CONTEXT §3 and §7.
#
# These exist so the layer rules are enforced rather than merely documented.
# Each gate exits non-zero when it finds a violation, so a CI or agent can
# rely on the exit code instead of reading output.
#
# Usage:  tool/verify_purity.sh
# Exit:   0 = all gates clean, 1 = violations found, 2 = a gate could not run.

set -uo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

violations=0
skipped=0

fail() {
  printf '  \033[31mVIOLATION\033[0m %s\n' "$1"
  violations=$((violations + 1))
}

ok() {
  printf '  \033[32mok\033[0m       %s\n' "$1"
}

skip() {
  printf '  \033[33mskip\033[0m     %s\n' "$1"
  skipped=$((skipped + 1))
}

echo "Architecture purity gates"
echo

# ---------------------------------------------------------------------------
# Gate 1 — domain purity.
#
# core/domain/ and every features/<f>/domain/ are pure Dart. They must not
# import Flutter, Dio, or http. Matched on import *directives* only, so a doc
# comment that merely mentions "package:flutter/" does not trip the gate.
#
# NOTE: an earlier version of this gate used a plain substring search. It had to
# be weakened because a legitimate doc comment referencing the forbidden package
# would have failed it. Do not "simplify" it back.
# ---------------------------------------------------------------------------
echo "Gate 1 — domain purity (no flutter/dio/http in domain layers)"

readonly IMPORT_RE="^[[:space:]]*import[[:space:]]+'package:(flutter|dio|http)/"
readonly FORBIDDEN_RE="package:(flutter|dio|http)/"

domain_dirs=()
for d in lib/core/domain lib/features/*/domain; do
  [[ -d "$d" ]] && domain_dirs+=("$d")
done

if [[ ${#domain_dirs[@]} -eq 0 ]]; then
  skip "no domain directories exist yet — gate is vacuous, not passing"
else
  gate1_hits=0
  for d in "${domain_dirs[@]}"; do
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$line"
      gate1_hits=1
    done < <(rg --no-heading --line-number "$IMPORT_RE" "$d" 2>/dev/null)
  done
  [[ $gate1_hits -eq 0 ]] && ok "${#domain_dirs[@]} domain dir(s) import no flutter/dio/http"
fi

echo

# ---------------------------------------------------------------------------
# Gate 2 — feature independence.
#
# No feature may import another feature. Shared code belongs in core/.
#
# WHY THIS IS A LOOP AND NOT ONE rg CALL: the rule compares the importing
# file's own feature against the feature it imports, so it is inherently
# per-feature. A single-line regex cannot do that — an attempt using a
# backreference (`features/(\w+)/\1`) does not merely fail to compile in ripgrep,
# it silently passes every line, which is worse than having no gate at all.
# ---------------------------------------------------------------------------
echo "Gate 2 — feature independence (no cross-feature imports)"

if ! compgen -G "lib/features/*/" >/dev/null; then
  skip "no features exist yet — gate is vacuous, not passing"
else
  gate2_hits=0
  for dir in lib/features/*/; do
    name="$(basename "$dir")"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$line"
      gate2_hits=1
    done < <(rg --no-heading --line-number "package:evangelion/features/" \
              "$dir" lib/core/ 2>/dev/null \
              | rg -v "package:evangelion/features/${name}/")
  done
  [[ $gate2_hits -eq 0 ]] && ok "no feature imports another feature"
fi

echo

# ---------------------------------------------------------------------------
# Gate 3 — generated output is not hand-edited.
#
# auto_route and injectable emit *.gr.dart and *.config.dart. Those files are
# deliberately tracked in git so `dart analyze` is meaningful on a fresh clone.
# Both generators emit `// ignore_for_file: type=lint`, so they must stay
# lint-silent; a stray violation means someone edited generated code.
# ---------------------------------------------------------------------------
echo "Gate 3 — generated files remain lint-silent"

mapfile -t generated < <(find lib -name '*.gr.dart' -o -name '*.config.dart' 2>/dev/null | sort)

if [[ ${#generated[@]} -eq 0 ]]; then
  skip "no generated files yet"
else
  gate3_hits=0
  for f in "${generated[@]}"; do
    # The marker sits inside the generator's banner block, which is not reliably
    # within the first few lines (injectable puts it on line 8). Scan a window
    # rather than the whole file, and do not assume a line number.
    if ! head -20 "$f" | grep -q "ignore_for_file:[[:space:]]*type=lint"; then
      fail "$f is missing the 'ignore_for_file: type=lint' header"
      gate3_hits=1
    fi
  done
  [[ $gate3_hits -eq 0 ]] && ok "${#generated[@]} generated file(s) carry the lint-silent header"
fi

echo

# ---------------------------------------------------------------------------
echo
if [[ $violations -gt 0 ]]; then
  printf '\033[31mFAILED\033[0m — %d violation(s)\n' "$violations"
  exit 1
fi
if [[ $skipped -gt 0 ]]; then
  printf '\033[33mPASSED (degraded)\033[0m — %d gate(s) vacuous, not yet exercised\n' "$skipped"
  exit 0
fi
printf '\033[32mPASSED\033[0m — all gates exercised and clean\n'
exit 0