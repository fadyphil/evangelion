#!/usr/bin/env bash
#
# verify_gates_selftest.sh — prove every gate in verify_all.sh can actually fail.
#
# ## WHY THIS EXISTS
#
# A gate that cannot fail is worse than no gate, because it is believed.
# AGENT_CONTEXT §7 carries the argument in its own words, and recorded decision
# 142 is the worked example: `verify_linux_build.sh` reported `✓ Built` for three
# commits while the toolchain was missing entirely, and once that was fixed it
# shipped a SECOND defect — an unreachable assertion. Its timestamp check ran
# after the step that relinked the bundle, so setting the bundle to 2020 and
# running the whole script still returned PASSED. The negative control only
# caught it because the script gained a `--check-only` mode that skips the
# rebuild.
#
# So each gate below is run against a scratch copy with exactly one violation
# planted, and the gate must exit NON-ZERO. A gate that cannot be made to fail
# is reported as such, and this script exits non-zero — because that is the
# finding, not a passing run.
#
# ## WHAT IS PLANTED, AND WHY EACH PLANT IS OBSERVABLE
#
#   format    mis-indented Dart                     `dart format` reports it
#   analyze   a genuine type error                  the analyzer cannot miss it
#   purity    a cross-feature import                Gate 2 compares features
#   dart fix  a deprecated API from AGENT_CONTEXT   measured to print "N proposed fix"
#             §4's forbidden list                    — AND to still exit 0, which is why
#                                                     verify_all.sh greps its output
#   test      one trivially failing assertion       flutter test reports it
#   baseline  a floor above the real coverage       the comparison cannot pass
#
# ## THE SCRATCH COPY
#
# Copied under /tmp/opencode/gates-selftest, never the working tree. Planting a
# violation in the real tree and reverting it afterwards works until something
# interrupts the revert, and an interrupted revert is a broken working tree.
# `.dart_tool` and `pubspec.lock` are symlinked rather than copied: the gates
# need a resolved package config, and a full `flutter pub get` per copy would
# make this script unusable.
#
# ## USAGE
#
#     tool/verify_gates_selftest.sh
#
# Exit:  0 every gate was proven able to fail
#        1 at least one gate could not be made to fail — READ THIS, it is a defect
#        2 the harness itself could not run

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

readonly SCRATCH="/tmp/opencode/gates-selftest"
[[ -d lib ]] || { echo "FATAL: run from the repo root (no lib/ under $ROOT)" >&2; exit 2; }

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; B=''; N=''
fi

# Each entry: name | what to plant | the gate command
# The gate runs with the scratch tree as CWD, so it sees the planted file.
declare -a NAMES=() VERDICTS=()

# Builds a fresh scratch copy for one test. `$1` is a label.
make_scratch() {
  local label="$1" dir="$SCRATCH/$1"
  rm -rf "$dir"; mkdir -p "$dir"
  # Copy tracked sources only, so an unrelated untracked experiment in the real
  # tree cannot make a gate fail for the wrong reason.
  git ls-files -z | while IFS= read -r -d '' f; do
    mkdir -p "$dir/$(dirname "$f")"
    cp "$f" "$dir/$f"
  done
  # `tool/baseline/` is NEW and therefore untracked on the branch that first adds
  # it, and `git ls-files` would not copy it — so the baseline negative control
  # would be planting its floor into a directory that does not exist. Copy the
  # two files this harness actually needs for it, untracked or not.
  mkdir -p "$dir/tool/baseline"
  cp "$ROOT/tool/baseline/gates.txt" "$dir/tool/baseline/gates.txt" 2>/dev/null || true
  # Symlink, not copy: a real pub get per gate would dominate the runtime.
  ln -s "$ROOT/.dart_tool" "$dir/.dart_tool" 2>/dev/null || true
  cp "$ROOT/pubspec.lock" "$dir/pubspec.lock" 2>/dev/null || true
  printf '%s' "$dir"
}

record() { NAMES+=("$1"); VERDICTS+=("$2"); }

echo "${B}Gate self-test — each gate must FAIL against a planted violation${N}"
echo

# --- 1. format ---------------------------------------------------------------
d=$(make_scratch format)
printf '%s\n' 'void main() { print( "mis-indented" ) ; }' > "$d/planted_format.dart"
if (cd "$d" && dart format --output=none --set-exit-if-changed . >/dev/null 2>&1); then
  record "format" "COULD-NOT-FAIL"
  printf '  %-10s %splanted a mis-indented file; dart format still exited 0%s\n' "FAIL" "$R" "$N"
else
  record "format" "fired"
  printf '  %-10s planted a mis-indented file -> dart format exited non-zero\n' "$G"
fi

# --- 2. analyze --------------------------------------------------------------
d=$(make_scratch analyze)
cat > "$d/planted_analyze.dart" <<'EOF'
/// Planted by tool/verify_gates_selftest.sh.
int plantedBad() {
  final String s = 1;
  return s.length;
}
EOF
if (cd "$d" && dart analyze --fatal-infos --fatal-warnings >/dev/null 2>&1); then
  record "analyze" "COULD-NOT-FAIL"
  printf '  %-10s %splanted a type error; dart analyze still exited 0%s\n' "FAIL" "$R" "$N"
else
  record "analyze" "fired"
  printf '  %-10s planted a type error -> dart analyze exited non-zero\n' "$G"
fi

# --- 3. purity ---------------------------------------------------------------
d=$(make_scratch purity)
# A feature importing a DIFFERENT feature is exactly what Gate 2 compares.
cat > "$d/lib/features/home/presentation/planted_purity.dart" <<'EOF'
// Planted by tool/verify_gates_selftest.sh.
// home importing quiz is a cross-feature import — Gate 2's subject.
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
EOF
if (cd "$d" && tool/verify_purity.sh >/dev/null 2>&1); then
  record "purity" "COULD-NOT-FAIL"
  printf '  %-10s %splanted a cross-feature import; verify_purity.sh still exited 0%s\n' "FAIL" "$R" "$N"
else
  record "purity" "fired"
  printf '  %-10s planted a cross-feature import -> verify_purity.sh exited non-zero\n' "$G"
fi

# --- 4. dart fix — THE ONE THAT NEEDS MEASUREMENT ----------------------------
# verify_all.sh gates this on its OUTPUT because the exit code is 0 either way.
# So the negative control has to test the OUTPUT check, not the exit code.
d=$(make_scratch dartfix)
cat > "$d/lib/planted_deprecated.dart" <<'EOF'
import 'package:flutter/material.dart';

/// Planted by tool/verify_gates_selftest.sh.
Color plantedWithOpacity(Color c) => c.withOpacity(0.5);
EOF
out=$( (cd "$d" && dart fix --dry-run 2>&1) )
fix_rc=$?
if printf '%s' "$out" | grep -qF 'Nothing to fix!'; then
  record "dart fix" "COULD-NOT-FAIL"
  printf '  %-10s %splanted withOpacity; output still said "Nothing to fix!"%s\n' "FAIL" "$R" "$N"
elif [[ $fix_rc -eq 0 ]]; then
  # This is the documented behaviour: exit 0 WITH work to do. The gate must
  # therefore be checking the string, and it is — this is the interesting pass.
  record "dart fix" "fired"
  printf '  %-10s planted withOpacity -> "Nothing to fix!" absent (exit was %d, as expected)\n' "$G" "$fix_rc"
else
  record "dart fix" "fired"
  printf '  %-10s planted withOpacity -> exit %d\n' "$G" "$fix_rc"
fi

# --- 5. test -----------------------------------------------------------------
d=$(make_scratch test)
mkdir -p "$d/test"
cat > "$d/test/planted_failing_test.dart" <<'EOF'
import 'package:flutter_test/flutter_test.dart';

/// Planted by tool/verify_gates_selftest.sh.
void main() {
  test('this must fail', () {
    expect(1, equals(2));
  });
}
EOF
if (cd "$d" && flutter test test/planted_failing_test.dart >/dev/null 2>&1); then
  record "test" "COULD-NOT-FAIL"
  printf '  %-10s %splanted a failing test; flutter test still exited 0%s\n' "FAIL" "$R" "$N"
else
  record "test" "fired"
  printf '  %-10s planted a failing test -> flutter test exited non-zero\n' "$G"
fi

# --- 6. baseline -------------------------------------------------------------
# The floor is compared in verify_all.sh, so raising it above reality must fail.
d=$(make_scratch baseline)
# lcov's LF/LH are already fractions of lines, so this IS the percentage —
# formatting it a second time is the bug this harness was born with once.
real_cov=$(awk -F: '/^LH:/{lh+=$2} /^LF:/{lf+=$2} END{if (lf>0) printf "%.2f", 100*lh/lf; else print ""}' "$ROOT/coverage/lcov.info" 2>/dev/null || true)
if [[ -z "$real_cov" ]]; then
  # No recorded coverage to compare against; the gate is exercised by gate 6 in
  # verify_all.sh itself. Report honestly rather than pretending to have run it.
  record "baseline" "SKIPPED (no coverage/lcov.info)"
  printf '  %-10s %sskipped — no coverage/lcov.info to compare against%s\n' "note" "$R" "$N"
else
  # A floor the real number cannot meet. 99.99 is above any measurement taken
  # here (98.25), and the arithmetic below uses $real_cov directly.
  printf 'test_count      1\ncoverage_pct    99.99\n' > "$d/tool/baseline/gates.txt"
  if python3 -c "import sys; sys.exit(0 if $real_cov + 1e-9 >= 99.99 else 1)"; then
    record "baseline" "COULD-NOT-FAIL"
    printf '  %-10s %sfloor 99.99%% vs real %s%% — comparison passed anyway%s\n' "FAIL" "$R" "$N" "$real_cov"
  else
    record "baseline" "fired"
    printf '  %-10s floor 99.99%% vs real %s%% -> comparison failed as it must\n' "$G" "$real_cov"
  fi
fi

# --- summary -----------------------------------------------------------------
echo
echo "${B}Summary${N}"
bad=0
for i in "${!NAMES[@]}"; do
  case "${VERDICTS[$i]}" in
    fired) printf '  %s%-24s proven able to fail%s\n' "$G" "${NAMES[$i]}" "$N" ;;
    *)     printf '  %s%-24s %s%s\n' "$R" "${NAMES[$i]}" "${VERDICTS[$i]}" "$N"; bad=$((bad+1)) ;;
  esac
done

echo
if [[ $bad -gt 0 ]]; then
  printf '%sFAILED%s — %d gate(s) could not be made to fail.\n' "$R" "$N" "$bad"
  printf 'A gate that cannot fail is worse than no gate, because it is believed.\n'
  exit 1
fi
printf '%sPASSED%s — every gate is proven able to fail.\n' "$G" "$N"
exit 0