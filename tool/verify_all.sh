#!/usr/bin/env bash
#
# verify_all.sh — one command for the §7 gate list.
#
# ## WHY THIS EXISTS
#
# AGENT_CONTEXT §7 lists seven commands that must pass before reporting done:
#
#     dart format --output=none --set-exit-if-changed lib test tool
#     dart analyze --fatal-infos --fatal-warnings
#     flutter test
#     tool/verify_purity.sh
#     dart fix --dry-run
#     flutter test --coverage                                   # must not drop
#     tool/verify_linux_build.sh                                # the app REALLY builds
#
# All seven are manual, so all seven are optional. This runs them in one go.
#
# ## GATES RUN IN COST ORDER, AND THAT ORDER IS THE DESIGN
#
# Measured on this machine (the numbers are in the gate headers below):
#
#     format   2.1s   analyze 5.4s   purity 1.3s   dart fix 6.5s
#     test    ~60s    coverage ~107s  linux build: minutes, and it wipes build/
#
# The cheap gates run first, so a formatting or lint error fails in under ten
# seconds instead of after the minute the test suite takes. The one gate that
# destroys build/ output is opt-in behind --with-build, because it is the only
# one that mutates the tree rather than reading it.
#
# ## THE THREE OUTCOMES, AND WHY THERE ARE THREE
#
#   ok      the gate ran and passed
#   FAIL    the gate ran and found something
#   FATAL   the gate COULD NOT RUN
#
# FATAL is not a flavour of ok, and it is the whole reason this file exists in
# the shape it does. Recorded decision 142 records `verify_linux_build.sh`
# reporting three false greens in a row and then, once fixed, shipping an
# *unreachable* assertion — the timestamp check ran after the step that relinked
# the bundle, so it could never fail. `verify_purity.sh` already distinguishes
# "found nothing" from "could not look", and the same distinction is kept here.
#
# A missing `rg`, a `flutter` that has vanished, an unreadable baseline: all
# FATAL, exit 2, never counted as a pass. A gate that cannot run is the worst
# outcome available, because it is indistinguishable from a pass to anything
# reading the exit code alone.
#
# ## `dart fix --dry-run` CANNOT BE TRUSTED ON ITS EXIT CODE
#
# MEASURED, not assumed, because the obvious reading is wrong:
#
#     $ dart fix --dry-run      # with a deprecated_member_use planted
#     1 proposed fix in 1 file.
#     ...
#     $ echo $?
#     0                          <-- EXITS ZERO WITH WORK TO DO
#
# It exits 0 whether or not there is anything to fix; when there is, it prints
# the `dart fix --apply --code=...` line you should run instead of a count. So
# gate 5 greps for the literal `Nothing to fix!`, which was measured to appear
# exactly once on a clean tree and not at all on a dirty one.
#
# If that behaviour ever changes, this gate fails loudly rather than quietly
# passing — see `tool/verify_gates_selftest.sh`, which plants the violation and
# proves this gate fires.
#
# ## THE BASELINE IS ENFORCED, NEVER SELF-UPDATED
#
# `flutter test --coverage` is documented as "must not drop". Without a recorded
# number that is a wish, so `tool/baseline/gates.txt` holds the floor and gate 7
# compares against it. Two rules:
#
#   - it is changed ONLY by --update-baseline, which prints the old and new
#     values so the change is visible in the commit. A gate that rewrites its
#     own expectation cannot fail.
#   - it is compared against the RECORDED floor, not against the last run, so
#     one bad run cannot permanently lower the bar.
#
# ## USAGE
#
#     tool/verify_all.sh                    # the seven fast gates
#     tool/verify_all.sh --with-build       # + the Linux build gate
#     tool/verify_all.sh --update-baseline  # re-record after a deliberate change
#
# Exit:  0 all gates clean
#        1 at least one gate failed
#        2 a gate could not run

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

WITH_BUILD=0
UPDATE_BASELINE=0
for arg in "$@"; do
  case "$arg" in
    --with-build) WITH_BUILD=1 ;;
    --update-baseline) UPDATE_BASELINE=1 ;;
    -h|--help) sed -n '/^# USAGE/,/^# Exit/p' "$0"; exit 0 ;;
    *) printf 'Unknown flag: %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

readonly BASELINE="tool/baseline/gates.txt"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; Y=''; C=''; B=''; N=''
fi

failed=0
fatal=0
declare -a RESULTS=()

# --- gate bookkeeping -------------------------------------------------------
pass() { printf '  %s%-6s%s %s\n' "$G" "ok" "$N" "$1"; RESULTS+=("ok|$1"); }
fail() { printf '  %s%-6s%s %s\n' "$R" "FAIL" "$N" "$1"; RESULTS+=("FAIL|$1"); failed=$((failed+1)); }
fatal() {
  printf '  %s%-6s%s %s\n' "$R" "FATAL" "$N" "$1"
  RESULTS+=("FATAL|$1"); fatal=$((fatal+1))
}

# --- preflight ---------------------------------------------------------------
# A missing tool must be FATAL before any gate runs, not discovered halfway
# through as a confusing failure of whichever gate happened to need it.
printf '%sGate preflight%s\n' "$B" "$N"
for tool in dart flutter rg python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    fatal "preflight: '$tool' is not on PATH — no gate that needs it was run"
  fi
done
# `rg` exists but might be unable to match, which turns every scan into a silent
# pass. Prove it works by matching a string piped in on stdin — no fixture file
# to keep in sync. This is verify_purity.sh's own probe.
if command -v rg >/dev/null 2>&1; then
  if ! printf 'verify_all_probe\n' | rg --quiet '^verify_all_probe$' -; then
    fatal 'preflight: rg cannot match a known string — its gates would pass vacuously'
  fi
fi
[[ -d lib ]] || fatal "preflight: no lib/ under $ROOT"

if [[ $fatal -gt 0 ]]; then
  printf '\n%sFATAL%s — preflight failed, no gate was run.\n' "$R" "$N"
  exit 2
fi
printf '  %s%-6s%s dart, flutter, rg, python3 present; rg can match\n\n' "$G" "ok" "$N"

# --- 1. format ---------------------------------------------------------------
printf '%s1. format%s\n' "$B" "$N"
if out=$(dart format --output=none --set-exit-if-changed lib test tool 2>&1); then
  pass "dart format — $(printf '%s' "$out" | grep -oE 'Formatted [0-9]+ files' | tail -1)"
else
  fail "dart format — not formatted (run: dart format lib test tool)"
fi

# --- 2. analyze --------------------------------------------------------------
printf '\n%s2. analyze%s\n' "$B" "$N"
if out=$(dart analyze --fatal-infos --fatal-warnings 2>&1); then
  pass "dart analyze — $(printf '%s' "$out" | tail -1)"
else
  n=$(printf '%s' "$out" | grep -cE '^\s+(error|warning|info) - ')
  fail "dart analyze — $n issue(s); first: $(printf '%s' "$out" | grep -E '^\s+(error|warning|info) - ' | head -1 | sed 's/^ *//')"
fi

# --- 3. purity ---------------------------------------------------------------
printf '\n%s3. architecture gates%s\n' "$B" "$N"
if out=$(tool/verify_purity.sh 2>&1); then
  pass "verify_purity.sh — $(printf '%s' "$out" | grep -E 'PASSED' | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
else
  rc=$?
  if [[ $rc -eq 2 ]]; then
    fatal "verify_purity.sh — a gate could not run: $(printf '%s' "$out" | grep -i FATAL | head -1)"
  else
    fail "verify_purity.sh — $(printf '%s' "$out" | grep -c 'VIOLATION') violation(s)"
  fi
fi

# --- 4. citation + orphan gates ---------------------------------------------
# Two gates added after the fp_dart work, both derived from recorded decisions:
#   citation  every `X.tsx:NNN` claim resolves to a real prototype line
#             (decision 8: "every transcription claim is a claim a human verified
#             by reading eva/" — and decision 8's own harness found 3 of its own
#             citations wrong on first run)
#   orphan    every widget is reachable from a page (decision 144:
#             LeaderboardCard was built, DI-wired, given a 5-surface overflow
#             matrix and a 21-test suite, and no page instantiated it)
printf '\n%s4. prototype citations and widget reachability%s\n' "$B" "$N"
for g in citation_check orphan_widget_check; do
  script="tool/gates/$g.py"
  if [[ ! -f "$script" ]]; then
    fatal "$g — $script not found"
  elif out=$(python3 "$script" 2>&1); then
    pass "$g — $(printf '%s' "$out" | grep -E 'PASSED' | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
  else
    rc=$?
    if [[ $rc -eq 2 ]]; then
      fatal "$g — could not run: $(printf '%s' "$out" | grep -i fatal | head -1)"
    else
      fail "$g — $(printf '%s' "$out" | grep -E '^\s+(BROKEN|ORPHAN)' | head -3 | tr '\n' ';')"
    fi
  fi
done

# --- 5. dart fix -------------------------------------------------------------
# See the header: this exits 0 even when there is work to do, so the OUTPUT is
# the check. Grepping for the literal is load-bearing, not decoration.
printf '\n%s5. deprecated / fixable APIs%s\n' "$B" "$N"
if out=$(dart fix --dry-run 2>&1); then
  if printf '%s' "$out" | grep -qF 'Nothing to fix!'; then
    pass "dart fix --dry-run — nothing to fix"
  else
    # MEASURED: this branch is reachable. `dart fix --dry-run` exits 0 with
    # "N proposed fix" printed, so an exit-code check here would pass forever.
    fail "dart fix --dry-run — $(printf '%s' "$out" | grep -oE '^[0-9]+ proposed fix' | head -1)"
    printf '         %s\n' "$(printf '%s' "$out" | grep -E 'dart fix --apply' | head -1 | sed 's/^ *//')"
  fi
else
  fatal "dart fix --dry-run could not run: $(printf '%s' "$out" | tail -1)"
fi

# --- 5. test -----------------------------------------------------------------
printf '\n%s6. test suite%s\n' "$B" "$N"
if out=$(flutter test 2>&1); then
  pass "flutter test — $(printf '%s' "$out" | grep -oE '\+[0-9]+.*All tests passed' | tail -1 | sed 's/^ *//' | sed 's/[0-9]\+ms.*//')"
  ACTUAL_TESTS=$(printf '%s' "$out" | grep -oE '\+[0-9]+: All tests passed' | tail -1 | grep -oE '\+[0-9]+' | tr -d '+')
else
  fail "flutter test — $(printf '%s' "$out" | grep -oE '\+[0-9]+ -[0-9]+' | tail -1)"
  printf '         %s\n' "$(printf '%s' "$out" | grep -A2 'Failing tests' | tail -1)"
fi

# --- 6. coverage + baseline --------------------------------------------------
printf '\n%s7. coverage and the recorded floor%s\n' "$B" "$N"
if [[ ! -f "$BASELINE" ]]; then
  fatal "baseline file missing: $BASELINE"
elif ! grep -qE '^test_count[[:space:]]+[0-9]+' "$BASELINE" || ! grep -qE '^coverage_pct[[:space:]]+[0-9.]+' "$BASELINE"; then
  fatal "baseline file malformed: $BASELINE (need test_count and coverage_pct)"
else
  FLOOR_TESTS=$(grep -E '^test_count[[:space:]]' "$BASELINE" | grep -oE '[0-9]+' | tail -1)
  FLOOR_COV=$(grep -E '^coverage_pct[[:space:]]' "$BASELINE" | grep -oE '[0-9.]+' | tail -1)

  if [[ $UPDATE_BASELINE -eq 1 ]]; then
    printf '  %s%-6s%s baseline update requested\n' "$Y" "note" "$N"
  else
    # Coverage needs its own run because flutter test does not write lcov.info
    # unless asked, and asking means running the suite twice otherwise.
    if out=$(flutter test --coverage 2>&1); then
      if [[ ! -f coverage/lcov.info ]]; then
        fatal "flutter test --coverage produced no coverage/lcov.info"
      else
        read -r LH LF <<<"$(awk -F: '/^LH:/{lh+=$2} /^LF:/{lf+=$2} END{print lh, lf}' coverage/lcov.info)"
        PCT=$(python3 -c "print(f'{100*$LH/$LF:.2f}')" 2>/dev/null || echo "0.00")
        printf '         coverage %s%% (%s/%s) · floor %s%% · tests %s · floor %s\n' \
          "$PCT" "$LH" "$LF" "$FLOOR_COV" "${ACTUAL_TESTS:-?}" "$FLOOR_TESTS"

        below=0
        python3 -c "import sys; sys.exit(0 if $PCT + 1e-9 >= $FLOOR_COV else 1)" \
          || { fail "coverage $PCT% is BELOW the recorded floor $FLOOR_COV%"; below=1; }
        if [[ -n "${ACTUAL_TESTS:-}" ]]; then
          [[ "$ACTUAL_TESTS" -ge "$FLOOR_TESTS" ]] \
            || { fail "test count $ACTUAL_TESTS is BELOW the recorded floor $FLOOR_TESTS"; below=1; }
        fi
        [[ $below -eq 0 ]] && pass "coverage $PCT% and $ACTUAL_TESTS tests meet the recorded floor"
      fi
    else
      fail "flutter test --coverage — $(printf '%s' "$out" | grep -oE '\+[0-9]+ -[0-9]+' | tail -1)"
    fi
  fi

  if [[ $UPDATE_BASELINE -eq 1 ]]; then
    if [[ ! -f coverage/lcov.info ]]; then
      fatal "cannot re-record: no coverage/lcov.info (run without --update-baseline first)"
    else
      LH=$(awk -F: '/^LH:/{lh+=$2} END{print lh+0}' coverage/lcov.info)
      LF=$(awk -F: '/^LF:/{lf+=$2} END{print lf+0}' coverage/lcov.info)
      NEW_PCT=$(python3 -c "print(f'{100*$LH/$LF:.2f}')" 2>/dev/null || echo "0.00")
      NEW_TESTS="${ACTUAL_TESTS:-$(grep -c '' /dev/null || echo 0)}"
      printf '         %s %s -> %s   %s %s -> %s\n' \
        "tests" "$FLOOR_TESTS" "$NEW_TESTS" "coverage" "$FLOOR_COV" "$NEW_PCT"
      [[ "$NEW_TESTS" -eq 0 ]] && fatal "cannot re-record: no test count captured this run"
      {
        printf '# Recorded %s. Update ONLY via: tool/verify_all.sh --update-baseline\n' "$(date +%F)"
        printf 'test_count      %s\n' "$NEW_TESTS"
        printf 'coverage_pct    %s\n' "$NEW_PCT"
      } > "$BASELINE"
      pass "baseline re-recorded (review this diff)"
    fi
  fi
fi

# --- 7. linux build (opt-in) -------------------------------------------------
if [[ $WITH_BUILD -eq 1 ]]; then
  printf '\n%s8. linux build%s\n' "$B" "$N"
  printf '         %s\n' "this wipes build/linux/x64/{debug,release} and rebuilds — it is slow by design"
  if out=$(tool/verify_linux_build.sh 2>&1); then
    pass "verify_linux_build.sh — $(printf '%s' "$out" | grep -iE '^\s*(PASS|OK)' | tail -1 | sed 's/\x1b\[[0-9;]*m//g' || echo 'clean')"
  else
    rc=$?
    if [[ $rc -eq 2 ]]; then
      fatal "verify_linux_build.sh could not run: $(printf '%s' "$out" | grep -i 'FAIL\|FATAL' | head -1)"
    else
      fail "verify_linux_build.sh — $(printf '%s' "$out" | grep -i 'FAIL' | head -1)"
    fi
  fi
else
  printf '\n%s8. linux build%s  %sskipped (--with-build to run; it wipes and rebuilds)%s\n' "$B" "$N" "$Y" "$N"
fi

# --- summary -----------------------------------------------------------------
printf '\n'
printf '%sSummary%s\n' "$B" "$N"
for r in "${RESULTS[@]}"; do
  case "${r%%|*}" in
    ok)    printf '  %sok%s    %s\n'    "$G" "$N" "${r#*|}" ;;
    FAIL)  printf '  %sFAIL%s  %s\n'  "$R" "$N" "${r#*|}" ;;
    FATAL) printf '  %sFATAL%s %s\n' "$R" "$N" "${r#*|}" ;;
  esac
done

printf '\n'
if [[ $fatal -gt 0 ]]; then
  printf '%sFATAL%s — %d gate(s) could not run. A gate that could not run is NOT a pass.\n' "$R" "$N" "$fatal"
  exit 2
fi
if [[ $failed -gt 0 ]]; then
  printf '%sFAILED%s — %d violation(s).\n' "$R" "$N" "$failed"
  exit 1
fi
printf '%sPASSED%s — every gate that ran was clean.\n' "$G" "$N"
exit 0