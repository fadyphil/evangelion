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
  # **The leading whitespace is OPTIONAL, and it was not.** `dart analyze` prints
  # `error` and `info` indented, but prints **`warning` at column 0** — so a
  # pattern that required the indentation counted the errors and the infos and
  # **never counted a warning**. The gate still FAILED (it is fail-closed, and
  # the count was only ever a report), but the number it reported was wrong:
  # reproduced on a tree with 4 issues, the script's counter printed 1.
  #
  # **A number in a gate is a claim about a specific thing**, so the count has to
  # be the count. The pattern now accepts the message at any indentation, and
  # still requires the ` - ` separator, so an echoed source line that merely
  # *contains* "error - " is not mistaken for a diagnostic any more than it was
  # before.
  n=$(printf '%s' "$out" | grep -cE '^\s*(error|warning|info) - ')
  fail "dart analyze — $n issue(s); first: $(printf '%s' "$out" | grep -E '^\s*(error|warning|info) - ' | head -1 | sed 's/^ *//')"
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

# --- 6. test -----------------------------------------------------------------
# These three markers read 5, 6 and 7 when the script prints 6, 7 and 8.
# Commit 0efb771 inserted the two Python gates at position 4 and updated the
# header prose and every `printf`, but not the markers. A contributor reading
# the source was mis-numbered by three against what the terminal shows, and
# `CONTRIBUTING.md` and ADR-0020 both cite gate numbers. Corrected here rather
# than left, on the same grounds as every other stale figure in docs/DRIFT.md.
#
# ## WHY THE SUMMARY IS PARSED, AND WHY AN UNPARSABLE ONE IS FATAL
#
# Measured failure, on a GitHub runner, not reproduced against the real tool:
#
#     ok     flutter test —
#     ok     coverage 98.36% and  tests meet the recorded floor
#                                                        ^^^^^ empty
#
# `flutter test` exited 0 — every test passed — and the summary it printed could
# not be parsed. ACTUAL_TESTS came back empty, the recorded test-count floor was
# never compared, and gate 7 still reported `ok`. Nothing on screen says a check
# was skipped.
#
# This is ADR-0020's subject reached from the other direction: not a gate that
# could not run, but a gate that ran and reported green over half of what it
# claims to cover.
#
# Measured failure, on a GitHub runner, before the cause above was found:
#
#     ok     flutter test —
#     ok     coverage 98.36% and  tests meet the recorded floor
#                                                        ^^^^^ empty
#
# The old code was `if [[ -n "${ACTUAL_TESTS:-}" ]]; then ... fi`, so an empty
# count SKIPPED the recorded floor and the gate still printed ok. This is
# ADR-0020's subject reached from the other direction: not a gate that could not
# run, but a gate that ran and reported green over half of what it covers.
#
# THE CAUSE, found by running the suite with each candidate variable set, on the
# machine that reported it:
#
#     (unset)              -> +2507: All tests passed!    the default reporter
#     CI=true              -> +2507: All tests passed!    NOT the cause
#     GITHUB_ACTIONS=true  -> 🎉 2507 tests passed.       THE cause
#
# GitHub Actions exports GITHUB_ACTIONS=true in the runner environment, Flutter's
# test runner reads it, and switches to its `github` reporter — `✅` per test and
# `🎉 N tests passed.` at the end. The regex that had read this since the gate was
# written had only ever seen the compact form, so on every runner the count came
# back empty and the floor was never compared.
#
# CI=true is the obvious suspect and it is wrong. That is worth recording, because
# the obvious suspect being wrong is what left this unidentified: three plausible
# causes were ruled out by measurement before the fourth was found, and every
# rule-out was a thing somebody had previously assumed.
#
# Both forms are matched explicitly rather than one being assumed, because the
# reporter is chosen by the environment and the environment differs by design.
#
# Two rules, in order of importance:
#   1. An unparsable summary is FATAL. It means this gate could not report what
#      it checked, which is the same class as a missing tool.
#   2. The pass line never prints an empty description. `flutter test — ` with
#      nothing after the em-dash is the shape this failure wore.
tests_passed() {
  # Strip ANSI, normalise CR progress separators, then try each known form.
  local clean n
  clean=$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr '\r' '\n')
  n=$(printf '%s' "$clean" \
    | grep -oE '\+[0-9]+: *All tests passed' | tail -1 | grep -oE '[0-9]+' | head -1)
  if [[ -n "$n" ]]; then printf '%s' "$n"; return 0; fi
  # The github reporter, selected by GITHUB_ACTIONS=true. The 🎉 is multi-byte;
  # the regex matches around it rather than through it.
  printf '%s' "$clean" \
    | grep -oE '[0-9]+ tests passed' | tail -1 | grep -oE '[0-9]+' | head -1
}

printf '\n%s6. test suite%s\n' "$B" "$N"
if out=$(flutter test 2>&1); then
  ACTUAL_TESTS=$(tests_passed "$out")
  if [[ -z "$ACTUAL_TESTS" ]]; then
    # FATAL, not fail and not pass. The suite passed; this script cannot say how
    # many tests that was, so the recorded floor in gate 7 cannot be enforced.
    fatal "flutter test exited 0 but its summary could not be parsed, so the recorded test-count floor was NOT checked. Treat this run as unknown, not as clean."
    printf '         %s\n' "the summary line looked for is '+N: All tests passed'; nothing in the output matched it."
    printf '         %s\n' "The last lines the suite actually printed, so this is diagnosable rather than a shrug:"
    # The suite's own output is the only evidence of what it printed. Discarding
    # it is what made this undiagnosable on a runner: the first report of this
    # failure arrived with the failing command, the exit code, and nothing else.
    printf '%s' "$out" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr '\r' '\n' \
      | grep -v '^[[:space:]]*$' | tail -12 \
      | sed 's/^/           | /'
    ACTUAL_TESTS=""
  else
    pass "flutter test — $ACTUAL_TESTS tests passed"
  fi
else
  fail "flutter test — $(printf '%s' "$out" | grep -oE '\+[0-9]+ -[0-9]+' | tail -1)"
  printf '         %s\n' "$(printf '%s' "$out" | grep -A2 'Failing tests' | tail -1)"
fi

# --- 7. coverage + baseline --------------------------------------------------
printf '\n%s7. coverage and the recorded floor%s\n' "$B" "$N"
# ## THE MEASUREMENT IS A SAMPLE, AND THE FLOOR IS A BUDGET OF LINES
#
# `flutter test --coverage` does not measure the whole run. It collects from
# **one isolate per isolate group** (`package:coverage` 1.15.1's
# `coveredIsolateGroups`), because the VM shares program counters between the
# isolates of a group and collecting from all of them would count every hit
# twice.
#
# **A `const` CONSTRUCTOR IS NOT A PROGRAM COUNTER.** Materialising a canonical
# constant is a **per-isolate** event, so the line that records a
# materialisation is reported as covered or **not** depending on which isolate
# the collector happened to sample. Measured on one tree, one line, on
# 2026-10-20: 4 on a 16-core machine, 2 at `--concurrency=2`, and **0 on the CI
# runner** — which was the whole of the difference between the runner's
# 8501/8601 and the local 8503/8601.
#
# So the coverage number this gate compares is a measurement with a **±1 line
# of noise**, and a floor compared against it with zero tolerance is a coin
# flip. The floor is therefore a **BUDGET OF UNCOVERED LINES** — an integer —
# and not a percentage:
#
#   * an integer has no rounding, so the comparison is exact;
#   * a budget does not drift as the code grows, where a percentage does: a
#     percentage floor of 98.85% on 8701 lines admits 100 uncovered lines,
#     while the same floor on 8601 lines admits 99, so adding covered code
#     **widens** a percentage floor without anybody deciding to widen it;
#   * and the recorded number is one a run actually produced, which a
#     two-decimal percentage of a sampled measurement is not.
#
# `coverage_pct` is still recorded, because it is the number a human reads, and
# it is still printed — but the **comparison** is the integer. The percentage
# is a rendering of the budget at the tree's current size, not the budget.
#
# **THIS IS NOT A REASON TO WIDEN THE FLOOR.** Widening a floor to make a red
# run green is the thing the baseline file exists to prevent. The fix for a
# genuinely uncovered line is to COVER THE LINE, and the fix for a line that is
# only covered incidentally is to GIVE IT A TEST — which is what `EvaShake`
# got, and its test is what stopped the runner and the local machine from
# disagreeing about whether a `const` had been materialised.
#
# The comparison lives in ONE function, so the self-test can exercise the
# shipped thing rather than a second copy of it.
coverage_floor_met() {
  # $1 covered, $2 total, $3 the floor (uncovered lines allowed).
  [[ $(( $2 - $1 )) -le $3 ]]
}

if [[ ! -f "$BASELINE" ]]; then
  fatal "baseline file missing: $BASELINE"
elif ! grep -qE '^test_count[[:space:]]+[0-9]+' "$BASELINE" || \
  ! grep -qE '^coverage_pct[[:space:]]+[0-9.]+' "$BASELINE" || \
  ! grep -qE '^uncovered_lines[[:space:]]+[0-9]+' "$BASELINE"; then
  fatal "baseline file malformed: $BASELINE (need test_count, coverage_pct and uncovered_lines)"
else
  FLOOR_TESTS=$(grep -E '^test_count[[:space:]]' "$BASELINE" | grep -oE '[0-9]+' | tail -1)
  FLOOR_COV=$(grep -E '^coverage_pct[[:space:]]' "$BASELINE" | grep -oE '[0-9.]+' | tail -1)
  FLOOR_UNCOVERED=$(grep -E '^uncovered_lines[[:space:]]' "$BASELINE" | grep -oE '[0-9]+' | tail -1)

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
        UNCOVERED=$((LF - LH))
        PCT=$(python3 -c "print(f'{100*$LH/$LF:.2f}')" 2>/dev/null || echo "0.00")
        printf '         coverage %s%% (%s/%s) · uncovered %s · floor %s · tests %s · floor %s\n' \
          "$PCT" "$LH" "$LF" "$UNCOVERED" "$FLOOR_UNCOVERED" "${ACTUAL_TESTS:-?}" "$FLOOR_TESTS"

        below=0
        coverage_floor_met "$LH" "$LF" "$FLOOR_UNCOVERED" \
          || { fail "coverage $PCT% leaves $UNCOVERED uncovered line(s), over the recorded floor of $FLOOR_UNCOVERED"; below=1; }
        if [[ -z "${ACTUAL_TESTS:-}" ]]; then
          # Defence in depth. Gate 6 already FATALs on an unparsable summary, so
          # reaching here empty means something reached past it. Skipping is what
          # turned this into a green gate over half its scope; refuse instead.
          fatal "no test count was captured, so the recorded test-count floor ($FLOOR_TESTS) was NOT checked. Treat this run as unknown, not as clean."
          below=1
        elif [[ "$ACTUAL_TESTS" -lt "$FLOOR_TESTS" ]]; then
          fail "test count $ACTUAL_TESTS is BELOW the recorded floor $FLOOR_TESTS"; below=1
        fi
        [[ $below -eq 0 ]] && pass "coverage $PCT% ($UNCOVERED uncovered of $LF) and $ACTUAL_TESTS tests meet the recorded floor"
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
      NEW_UNCOVERED=$((LF - LH))
      NEW_TESTS="${ACTUAL_TESTS:-$(grep -c '' /dev/null || echo 0)}"
      printf '         %s %s -> %s   %s %s -> %s   %s %s -> %s\n' \
        "tests" "$FLOOR_TESTS" "$NEW_TESTS" "coverage" "$FLOOR_COV" "$NEW_PCT" \
        "uncovered" "$FLOOR_UNCOVERED" "$NEW_UNCOVERED"
      [[ "$NEW_TESTS" -eq 0 ]] && fatal "cannot re-record: no test count captured this run"
      # ## THE HISTORY IS KEPT, AND THAT IS THE POINT
      #
      # This used to write the file out with `> "$BASELINE"` and three `printf`s
      # — which **replaced the whole file with three lines** and destroyed every
      # word of the history above them. The file's own comment records that
      # happening and the history being "put back by hand", which is a
      # re-recording that has to be repaired by a person afterwards, and the
      # next re-recording would have wiped it again.
      #
      # The file's rule is that the old and the new values are visible in the
      # commit, and a running history is how a reader tells a **strengthening**
      # from a **lowered** floor. So the three value lines are rewritten **in
      # place** and everything else — the history, the reasons, the caveats — is
      # left exactly as it was.
      awk -v t="$NEW_TESTS" -v c="$NEW_PCT" -v u="$NEW_UNCOVERED" '
        /^test_count[[:space:]]/      { print "test_count      " t;  seen["t"]=1; next }
        /^coverage_pct[[:space:]]/    { print "coverage_pct    " c;  seen["c"]=1; next }
        /^uncovered_lines[[:space:]]/ { print "uncovered_lines " u;  seen["u"]=1; next }
        { print }
        END {
          # A key that was not in the file is appended rather than lost.
          if (!seen["t"]) print "test_count      " t
          if (!seen["c"]) print "coverage_pct    " c
          if (!seen["u"]) print "uncovered_lines " u
        }
      ' "$BASELINE" > "$BASELINE.tmp" && mv "$BASELINE.tmp" "$BASELINE"
      pass "baseline re-recorded (review this diff — the history above it is kept)"
    fi
  fi
fi

# --- 8. linux build (opt-in) -------------------------------------------------
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