#!/usr/bin/env bash
#
# Architecture purity gates — the mechanical half of AGENT_CONTEXT §3 and §7.
#
# These exist so the layer rules are enforced rather than merely documented.
# Each gate exits non-zero when it finds a violation, so a CI or agent can
# rely on the exit code instead of reading output.
#
# Four gates, each negative-controlled: 1 domain purity · 2 feature independence
# · 3 generated files stay lint-silent · 4 the route inventory is readable.
# See AGENT_CONTEXT §7 for what each one matches and why those patterns must not
# be narrowed.
#
# Usage:  tool/verify_purity.sh
# Exit:   0 = all gates clean (or degraded/vacuous, as printed),
#         1 = violations found, 2 = a gate could not run.
#
# NOTE ON `set -e`: deliberately NOT used. Exit code 1 from `rg` means "no
# matches", which is the outcome these gates *want*, and `-e` would abort the
# script at that point instead of letting the status be read as clean. Every
# scanning status is therefore captured explicitly and dispatched by hand.

set -uo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

# ---------------------------------------------------------------------------
# Preflight — a gate that could not run must say so, loudly.
#
# `rg` writes its own failures to stderr. Discarding stderr and matching on
# stdout alone turns a broken or missing toolchain into empty output, which an
# unguarded `while read` loop silently swallows: no iterations, no violations,
# a green tick. A previous version of this script did exactly that and
# *upgraded* the failure into "PASSED — all gates exercised and clean". So the
# tools are checked up front, and every scan below distinguishes "found
# nothing" from "could not look".
# ---------------------------------------------------------------------------
command -v rg >/dev/null 2>&1 || {
  printf 'FATAL: ripgrep (rg) is not on PATH — gates did not run\n' >&2
  exit 2
}
# ...and prove it can actually MATCH. `command -v` only proves a binary exists;
# an `rg` that reports "no matches" for everything — a wrapper, a shell alias, a
# broken install — would turn every gate into a silent pass, and its exit 1 is
# indistinguishable from the legitimate "found nothing". Matching a line piped
# in on stdin needs no fixture file to keep in sync.
printf 'purity_probe\n' | rg --quiet '^purity_probe$' - || {
  printf 'FATAL: rg cannot match a known string — gates did not run\n' >&2
  exit 2
}
[[ -d lib ]] || {
  printf 'FATAL: no lib/ under %s — gates did not run\n' "$ROOT" >&2
  exit 2
}

readonly TMP_CAPTURE="$(mktemp)"
trap 'rm -f "$TMP_CAPTURE"' EXIT

# Status of the last `scan`. 0 = matches, 1 = no matches (the GOOD outcome).
_RG_RC=0
# Why the last `scan` failed, in words, for the FATAL message.
_SCAN_ERR=''

# Runs `rg "$1" "${@:2}"` into $TMP_CAPTURE and stashes the status in $_RG_RC.
# Returns non-zero only when the result cannot be believed, so the caller must
# treat that as fatal rather than as "clean". The capture goes through a file
# rather than a pipe or a process substitution because $_RG_RC has to survive
# the command — inside `<(...)` the status would belong to a subshell that is
# gone by the time it is read.
scan() {
  rg --no-heading --line-number "$1" "${@:2}" >"$TMP_CAPTURE"
  _RG_RC=$?
  _SCAN_ERR=''
  case $_RG_RC in
    0)
      # rg exits 0 only when it matched, and a match always prints a line. Exit
      # 0 with nothing captured is self-contradictory: this rg is claiming a
      # match it did not report, and believing it would be a silent pass.
      if [[ ! -s "$TMP_CAPTURE" ]]; then
        _SCAN_ERR='rg exited 0 but captured no matching line'
        return 1
      fi
      ;;
    1) return 0 ;;
    *)
      _SCAN_ERR="rg exited $_RG_RC"
      return 1
      ;;
  esac
  return 0
}

# Prints every non-empty captured line as a violation and counts them.
report_capture() {
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "$line"
  done <"$TMP_CAPTURE"
}

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
# Every directory that is documented as PURE DART must not reach Flutter, Dio, or
# http. That is currently:
#
#   lib/core/domain        the shared kernel: entities and ports (AGENT_CONTEXT §3)
#   lib/features/*/domain  each feature's own use cases
#   lib/core/common        Result<T>, Failure, AppConfig
#   lib/core/navigation    AppRoutes
#
# WHY core/common AND core/navigation ARE IN THIS LIST, and why that is a claim
# rather than a preference. Both files document the property in their own words —
# app_routes.dart: "staying Flutter-free keeps the constants readable from any
# layer"; app_config.dart: "Pure Dart by design: no Flutter import, so this can
# be read from core/domain/". Both are load-bearing: Phase 5 has core/domain/
# use cases reading AppConfig, and Phase 4 makes AppRoutes the most-imported file
# in the app. Neither was checked by anything, so adding
# `import 'package:flutter/material.dart';` to either left every gate green.
#
# Do NOT narrow this list back to the domain directories without reading those
# two doc comments and re-deciding.
#
# WHY `import|export|part` AND NOT JUST `import`: all three directives make the
# named library part of this file's own surface. An `export` of
# `package:flutter/material.dart` is exactly as impure as an `import` of it,
# and it satisfies no lint, so nothing else in the toolchain catches it. Same
# for `part`, which pulls a file into this library's namespace. DO NOT NARROW
# THIS TO `import` — that regression was found by negative control, not by
# reading the code.
#
# WHY THE MATCH IS ANCHORED TO A DIRECTIVE KEYWORD: an earlier version of this
# gate used a plain substring search. It had to be weakened because a legitimate
# doc comment referencing the forbidden package would have failed it. Do not
# "simplify" it back.
#
# Single quotes only, because `prefer_single_quotes` is enabled in
# analysis_options.yaml and `dart analyze --fatal-infos` makes a double-quoted
# directive a hard error anyway. Gate 2 does not rely on that lint and so
# matches both quote styles.
# ---------------------------------------------------------------------------
echo "Gate 1 — domain purity (no flutter/dio/http in pure-Dart directories)"

readonly DIRECTIVE_RE="^[[:space:]]*(import|export|part)[[:space:]]+'package:(flutter|dio|http)/"

domain_dirs=()
for d in lib/core/domain lib/core/common lib/core/navigation lib/features/*/domain; do
  [[ -d "$d" ]] && domain_dirs+=("$d")
done

if [[ ${#domain_dirs[@]} -eq 0 ]]; then
  skip "no domain directories exist yet — gate is vacuous, not passing"
else
  gate1_hits=0
  for d in "${domain_dirs[@]}"; do
    if ! scan "$DIRECTIVE_RE" "$d"; then
      printf 'FATAL: gate 1 could not scan %s — %s\n' "$d" "$_SCAN_ERR" >&2
      exit 2
    fi
    report_capture
    if [[ -s "$TMP_CAPTURE" ]]; then
      gate1_hits=1
    fi
  done
  [[ $gate1_hits -eq 0 ]] &&
    ok "${#domain_dirs[@]} pure-Dart dir(s) reach no flutter/dio/http"
fi

echo

# ---------------------------------------------------------------------------
# Gate 2 — feature independence.
#
# No feature may import another feature, and lib/core/ may import none. Shared
# code belongs in core/.
#
# The comparison is inherently per-file — it contrasts the importing file's own
# feature with the feature it imports — so it cannot be one regex. An earlier
# attempt used a backreference, `rg -v "features/(\w+)/\1"`: ripgrep has no
# backreferences, so the pattern failed to *compile*, and the failure was silent
# — exit 0, every line "passed". A gate that cannot fail is worse than no gate,
# because it is believed.
#
# `tool/feature_import_check.dart` does the comparison. It exists as Dart
# rather than shell because same-package imports are legal in two syntaxes
# (`package:evangelion/features/…` and `../../…`), and resolving `../..` is
# exactly where hand-rolled shell path arithmetic goes quietly wrong. See that
# file for its own rationale, and run it directly if you need the detail:
#
#   dart run tool/feature_import_check.dart
#
# It exits 0 clean, 1 with violations (one `path:line: directive` line each), or
# 2 if it could not run — and it makes ONE pass over the tree, so a `lib/core/`
# violation is reported once rather than once per feature.
# ---------------------------------------------------------------------------
echo "Gate 2 — feature independence (no cross-feature imports)"

if ! compgen -G "lib/features/*/" >/dev/null; then
  skip "no features exist yet — gate is vacuous, not passing"
elif ! command -v dart >/dev/null 2>&1; then
  printf 'FATAL: Dart SDK not on PATH — gate 2 could not run\n' >&2
  exit 2
else
  gate2_rc=0
  dart run tool/feature_import_check.dart >"$TMP_CAPTURE" || gate2_rc=$?
  case $gate2_rc in
    0)
      ok "no feature imports another feature"
      ;;
    1)
      # Exit 1 means "violations found", so there must be something to report.
      # Nothing printed would mean this gate is claiming a violation it did not
      # show — the same silent-pass shape, one layer down.
      if [[ ! -s "$TMP_CAPTURE" ]]; then
        printf 'FATAL: gate 2 reported violations but printed none\n' >&2
        exit 2
      fi
      report_capture
      ;;
    *)
      printf 'FATAL: gate 2 could not run tool/feature_import_check.dart (dart exit %d)\n' \
        "$gate2_rc" >&2
      exit 2
      ;;
  esac
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

mapfile -t generated < <(find lib -name '*.gr.dart' -o -name '*.config.dart' | sort)

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
  [[ $gate3_hits -eq 0 ]] &&
    ok "${#generated[@]} generated file(s) carry the lint-silent header"
fi

echo

# ---------------------------------------------------------------------------
# Gate 4 — the route inventory is readable.
#
# The six route paths are locked by AGENT_CONTEXT §2, and the structural
# invariants over them (no collisions, no stray whitespace, no uppercase, one
# root, one wildcard) are asserted in `test/core/navigation/app_routes_test.dart`
# over an inventory read from the declaration site. Dart has no reflection, so
# that inventory is parsed, and an invariant applied to the wrong or empty set of
# routes is an invariant that asserts nothing.
#
# This gate checks the *mechanism* the invariants rest on, not the invariants
# themselves — so it is not a second copy of them. It exits 1 when a
# `static const String` declaration exists whose initialiser is not a plain
# string literal, because that route is then invisible to the invariants: it
# fails loudly instead of being skipped. It exits 2 when the file is missing, is
# empty, or holds no declarations at all, because "found nothing to complain
# about" and "found nothing" are different answers.
#
# `tool/route_check.dart` holds the parsing; see that file for the extraction and
# for what it still cannot see. The two share one implementation on purpose.
# ---------------------------------------------------------------------------
echo "Gate 4 — route inventory is parsable (app_routes.dart)"

if ! command -v dart >/dev/null 2>&1; then
  printf 'FATAL: Dart SDK not on PATH — gate 4 could not run\n' >&2
  exit 2
else
  gate4_rc=0
  dart run tool/route_check.dart >"$TMP_CAPTURE" 2>&1 || gate4_rc=$?
  case $gate4_rc in
    0)
      ok "$(tr -d '\n' <"$TMP_CAPTURE")"
      ;;
    1)
      # Exit 1 means "a declaration could not be parsed". Nothing printed would
      # mean this gate claims a violation it did not show — the silent-pass
      # shape again, one layer down.
      if [[ ! -s "$TMP_CAPTURE" ]]; then
        printf 'FATAL: gate 4 reported violations but printed none\n' >&2
        exit 2
      fi
      report_capture
      ;;
    *)
      printf 'FATAL: gate 4 could not run tool/route_check.dart (dart exit %d)\n' \
        "$gate4_rc" >&2
      cat "$TMP_CAPTURE" >&2
      exit 2
      ;;
  esac
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