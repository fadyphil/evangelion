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
#   citation  a broken citation, a missing reference   FAIL(1) and FATAL(2) — not the same
#   orphan    a bogus page, a renamed router, a missing router, an orphan
#             outside `*/widgets/`                   FAIL(1) and FATAL(2), and the
#                                                     GREEN direction is asserted too
#   blur      a block comment, a real site, a hand-built filter
#                                                     a comment is not a site, a site
#                                                     is, and the two halves agree
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
  # Same reasoning for the redesigned reference: `eva/redesign.html` is added by
  # a later commit than this harness and is therefore untracked on the branch
  # that introduces it. `git ls-files` would skip it and the citation negative
  # control would have neither a file to resolve against nor a file to remove.
  mkdir -p "$dir/eva"
  cp "$ROOT/eva/redesign.html" "$dir/eva/redesign.html" 2>/dev/null || true
  # **The brief is the second named reference**, and the same reasoning applies:
  # it is renamed by a `git mv`, so on the branch that introduces the rename it
  # can be untracked in the scratch copy's window. The citation gate FATALs
  # without it, and a FATAL is not a FAIL — the two are not the same, and the
  # control below asserts them separately.
  cp "$ROOT/eva/brief.txt" "$dir/eva/brief.txt" 2>/dev/null || true
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
#
# **AND THE COMPARISON IS THE SHIPPED ONE**, read out of verify_all.sh rather
# than reimplemented here — the same treatment `tests_passed` gets above, and
# for the same reason: two implementations of one comparison are two things to
# keep in step, and the one that drifts is the one that stops firing. The
# previous version of this case reimplemented the comparison in Python, so it
# was testing a formula that verify_all.sh did not use.
#
# **THE GREEN DIRECTION IS ASSERTED TOO.** A floor the measurement MEETS must
# pass, and one line tighter must fail. A comparison that failed everything
# would satisfy "the gate can fail" and mean nothing.
d=$(make_scratch baseline)
real_lh=$(awk -F: '/^LH:/{lh+=$2} END{print lh+0}' "$ROOT/coverage/lcov.info" 2>/dev/null || echo "")
real_lf=$(awk -F: '/^LF:/{lf+=$2} END{print lf+0}' "$ROOT/coverage/lcov.info" 2>/dev/null || echo "")
if [[ -z "$real_lf" || "$real_lf" -eq 0 ]]; then
  # **NO COVERAGE FILE IS NOT A REASON TO SKIP THE CASE.** The comparison is a
  # function of two numbers, so it can be exercised without a measurement —
  # and a case that only runs when some *other* job has already run is a case
  # that silently stops being a case. The synthetic pair below has the same
  # shape as a real one (a few uncovered lines out of many), which is all the
  # comparison needs.
  #
  # The real measurement is still preferred when it is there, so the case keeps
  # exercising the tree's actual numbers locally.
  real_lh=8503
  real_lf=8601
  source_of_the_numbers="a synthetic pair (no coverage/lcov.info to read)"
else
  source_of_the_numbers="the tree's own coverage/lcov.info"
fi
extract_floor=$(sed -n '/^coverage_floor_met()/,/^}/p' "$ROOT/tool/verify_all.sh")
if [[ -z "$extract_floor" ]]; then
  record "baseline" "COULD-NOT-FAIL"
  printf '  %-10s %scould not extract coverage_floor_met() from verify_all.sh%s\n' "FAIL" "$R" "$N"
else
  eval "$extract_floor"
  real_uncovered=$((real_lf - real_lh))
  # The planted floor: zero uncovered lines allowed, which a real measurement
  # cannot meet. It is the negative control, and it is written into the scratch
  # copy's baseline so the shape of the file is exercised too.
  printf 'test_count      1\ncoverage_pct    99.99\nuncovered_lines 0\n' > "$d/tool/baseline/gates.txt"
  green=0
  red=0
  coverage_floor_met "$real_lh" "$real_lf" "$real_uncovered" && green=1
  coverage_floor_met "$real_lh" "$real_lf" $((real_uncovered - 1)) || red=1
  if coverage_floor_met "$real_lh" "$real_lf" 0; then
    record "baseline" "COULD-NOT-FAIL"
    printf '  %-10s %sfloor 0 uncovered lines vs real %s — comparison passed anyway%s\n' \
      "FAIL" "$R" "$N" "$real_uncovered"
  elif [[ $green -eq 1 && $red -eq 1 ]]; then
    record "baseline" "fired"
    printf '  %-10s floor 0 uncovered lines vs real %s -> comparison failed as it must; the floor at %s passes and one line tighter fails (%s)\n' \
      "$G" "$real_uncovered" "$real_uncovered" "$source_of_the_numbers"
  else
    record "baseline" "COULD-NOT-FAIL"
    printf '  %-10s %sthe floor at the measurement passed=%s, one line tighter failed=%s — one is wrong%s\n' \
      "FAIL" "$R" "$green" "$red" "$N"
  fi
fi

# --- 7. unparsable test summary ----------------------------------------------
# Not a planted file. The failure this guards was MEASURED on a GitHub runner on
# 2026-10-12: `flutter test` exited 0, every test passed, and no line matched
# '+N: All tests passed' — because GITHUB_ACTIONS=true makes Flutter select its
# `github` reporter, which ends with '🎉 N tests passed.' instead. ACTUAL_TESTS
# came back empty, and the old code was
#
#     if [[ -n "${ACTUAL_TESTS:-}" ]]; then ... fi
#
# so the recorded test-count floor was skipped while the gate printed ok.
#
# What is asserted here is the shipped `tests_passed` function, read out of
# verify_all.sh rather than reimplemented — two implementations of one parse is
# two things to keep in step, and this harness exists to test the real thing.
# Both reporter forms are asserted, because the reporter is chosen by the
# environment and a local-only suite would never see the second one again.
extract_fn=$(sed -n '/^tests_passed()/,/^}/p' "$ROOT/tool/verify_all.sh")
if [[ -z "$extract_fn" ]]; then
  record "parse" "COULD-NOT-FAIL"
  printf '  %-10s %scould not extract tests_passed() from verify_all.sh%s\n' "FAIL" "$R" "$N"
else
  eval "$extract_fn"
  ok_parse=1
  # Form 1: the default compact reporter, and the ANSI and CR variants of it.
  for variant in '00:59 +2507: All tests passed!' \
                 $'\r+2507: All tests passed!\r' \
                 $'\x1b[32m+2507: All tests passed!\x1b[0m' \
                 $'\r\x1b[2K+2507: All tests passed!'; do
    [[ "$(tests_passed "$variant")" == "2507" ]] || ok_parse=0
  done
  # Form 2: what GITHUB_ACTIONS=true selects, captured verbatim from the runner
  # log that first reported the failure.
  for variant in '🎉 2507 tests passed.' \
                 $'✅ some test\n🎉 2507 tests passed.\n' \
                 $'\r🎉 2507 tests passed.\r'; do
    [[ "$(tests_passed "$variant")" == "2507" ]] || ok_parse=0
  done
  # Output with NO summary must NOT produce a number. That is the whole point:
  # it has to come back empty so the caller can make it FATAL, rather than
  # inventing a count and passing on it.
  empty_refused=0
  [[ -z "$(tests_passed 'the suite produced no machine-readable summary')" ]] && empty_refused=1
  if [[ $ok_parse -eq 1 && $empty_refused -eq 1 ]]; then
    record "parse" "fired"
    printf '  %-10s both reporter forms -> 2507; no-summary -> empty, so the caller makes it FATAL\n' "$G"
  else
    record "parse" "COULD-NOT-FAIL"
    printf '  %-10s %svariants parsed=%s empty-refused=%s — one is wrong%s\n' \
      "FAIL" "$R" "$ok_parse" "$empty_refused" "$N"
  fi
fi

# --- 8. citation reference must be present ------------------------------------
# citation_check resolves every `X.tsx:NNN` and `redesign.html:NNN` claim against
# a reference under eva/. It had NO negative control until the redesigned reference
# was added, which is the gap this case fills.
#
# Two distinct outcomes are asserted, because conflating them is the defect:
#   - a citation that cannot resolve is FAIL (exit 1) — the claim is wrong
#   - a required reference that is ABSENT is FATAL (exit 2) — the surface being
#     checked is not there, which is not the same as finding nothing in it
#
# The second was found by planting the first and reading the wrong reason. With
# redesign.html removed and nothing citing it yet, 12 .tsx files still resolved
# and the gate reported a green run over a reference that no longer existed. The
# check that would have noticed was the one doing the checking.
d=$(make_scratch citation)
cite_fired=0; ref_fired=0; tsx_fired=0
if [[ -f "$d/eva/redesign.html" && -f "$d/eva/brief.txt" ]]; then
  # A citation past the end of the file: it exists, the line does not.
  printf '// plant: see redesign.html:999999\nconst _ = 0;\n' > "$d/lib/plant_citation.dart"
  ( cd "$d" && python3 tool/gates/citation_check.py >/dev/null 2>&1 )
  rc=$?
  rm -f "$d/lib/plant_citation.dart"
  [[ $rc -eq 1 ]] && cite_fired=1
  # Now remove the reference entirely. Nothing cites it, so only the required-
  # reference check can catch this.
  mv "$d/eva/redesign.html" "$d/eva/redesign.html.removed"
  ( cd "$d" && python3 tool/gates/citation_check.py >/dev/null 2>&1 )
  rc=$?
  mv "$d/eva/redesign.html.removed" "$d/eva/redesign.html"
  [[ $rc -eq 2 ]] && ref_fired=1
  # **A `.tsx` citation is now a BROKEN citation, and that is the retirement
  # being ENFORCED.** The React prototype is retired, so a citation that names
  # one must be reported by name. **The pattern still matches `.tsx` on
  # purpose** — a pattern that stopped matching would report a clean run over a
  # surface it no longer examines, which is the ADR-0020 defect this gate
  # exists to prevent. This control plants one and requires the FAIL.
  # **The gate's output goes to a FILE and the grep reads the file** — not a
  # pipe. `set -o pipefail` is on in this harness, so `gate | grep -q` returns
  # the GATE's exit code (1, because the planted citation is broken) and the
  # control reads that as "the message was not found". The first version of this
  # control did exactly that and reported `retired-tsx=0` against a gate that
  # was firing correctly — **a control that measures the wrong thing is the
  # same defect as a gate that cannot fail**, and it was caught only because
  # the summary is read by a human.
  printf '// plant: see ds.tsx:245\nconst _ = 0;\n' > "$d/lib/plant_tsx_citation.dart"
  ( cd "$d" && python3 tool/gates/citation_check.py > "$d/gate_output.txt" 2>/dev/null )
  grep -q 'no such reference file' "$d/gate_output.txt" && tsx_fired=1
  rm -f "$d/lib/plant_tsx_citation.dart" "$d/gate_output.txt"
else
  printf '  %-10s %sno eva/redesign.html or eva/brief.txt in the scratch copy — cannot run this control%s\n' "FAIL" "$R" "$N"
fi
if [[ $cite_fired -eq 1 && $ref_fired -eq 1 && $tsx_fired -eq 1 ]]; then
  record "citation" "fired"
  printf '  %-10s bad citation -> FAIL(1); reference removed -> FATAL(2); a .tsx citation -> named BROKEN. The three are not the same.\n' "$G"
else
  record "citation" "COULD-NOT-FAIL"
  printf '  %-10s %sbad-citation=%s missing-reference=%s retired-tsx=%s — one is wrong%s\n' \
    "FAIL" "$R" "$cite_fired" "$ref_fired" "$tsx_fired" "$N"
fi

# --- 9. orphan gate — the tree's reachability, and decision 144 ------------
# The orphan gate answers "does any screen's tree contain this widget", and
# AGENT_CONTEXT decision 144 is the defect it exists to make impossible. It
# had NO negative control until now, which is the gap this section fills.
#
# **A MINIMAL TREE, not a copy of the real one**, and that is deliberate. The
# real tree is RED right now — three widgets are built, tested and not yet
# placed — so a control that said "the gate must be green" would be a
# statement about the tree rather than about the gate. A three-file tree with
# one router, one app root and one page makes every expectation exact, and it
# makes them independent of whatever else is in flight.
#
# Six controls, and they are the six directions the gate can be wrong in:
#
#   green        a real page is reachable            (the gate CAN pass)
#   bogus        `@RoutePage()` on a plain class     -> FAIL(1)
#   unregistered `@RoutePage()` on an orphan page   -> FAIL(1)
#   renamed      the router file is RENAMED         -> still green (derived)
#   missing      the router file is GONE            -> FATAL(2), never a pass
#   orphan       a widget outside `*/widgets/`       -> FAIL(1), and named
#
# The last two are the two halves of "the gate must not be able to pass
# vacuously", and the middle two are the two halves of "a bogus annotation is
# a failure, not a diagnostic".
make_mini_scratch() {
  local dir="$SCRATCH/mini"
  rm -rf "$dir"
  mkdir -p "$dir/tool/gates" \
           "$dir/lib/app/router" \
           "$dir/lib/app" \
           "$dir/lib/features/home/presentation/pages"
  cp "$ROOT/tool/gates/orphan_widget_check.py" "$dir/tool/gates/"

  cat > "$dir/lib/app/router/app_router.dart" <<'EOF'
// A minimal router: one route, one page.
import 'package:auto_route/auto_route.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
        AutoRoute(path: '/', page: HomeRoute.page),
      ];
}
EOF

  cat > "$dir/lib/app/app.dart" <<'EOF'
// A minimal app root: it installs the tree.
import 'package:flutter/material.dart';

class EvangelionApp extends StatelessWidget {
  const EvangelionApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp.router();
}
EOF

  cat > "$dir/lib/features/home/presentation/pages/home_page.dart" <<'EOF'
// A minimal page: the annotation is on a widget, and the route is registered.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
EOF
  printf '%s' "$dir"
}

mini=$(make_mini_scratch)
mini_run() { ( cd "$mini" && python3 tool/gates/orphan_widget_check.py 2>&1 ); }

# 9a. green — a real page is reachable and the gate passes.
out=$(mini_run); rc=$?
green_ok=0
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -qF 'PASSED'; then
  green_ok=1
fi
if [[ $green_ok -eq 1 ]]; then
  record "orphan (green)" "fired"
  printf '  %-10s a real page -> green (exit 0, PASSED). The gate CAN pass.\n' "$G"
else
  record "orphan (green)" "COULD-NOT-FAIL"
  printf '  %-10s %sa real page -> exit %d; the gate cannot pass at all\n' \
    "FAIL" "$R" "$rc" "$N"
fi

# 9b. a bogus `@RoutePage()` — on a plain class, which is not a page widget.
cat > "$mini/lib/features/probe_holder.dart" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: the annotation on a plain class.
import 'package:auto_route/auto_route.dart';

/// Not a widget, and its route is not registered.
@RoutePage()
class ProbeHolder {
  const ProbeHolder();
}
EOF
out=$(mini_run); rc=$?
if [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -qF 'NOT A ROOT'; then
  record "orphan (bogus page)" "fired"
  printf '  %-10s a bogus @RoutePage() -> FAIL(1) with the NOT A ROOT diagnostic\n' "$G"
else
  record "orphan (bogus page)" "COULD-NOT-FAIL"
  printf '  %-10s %sa bogus @RoutePage() -> exit %d; the diagnostic is not a failure\n' \
    "FAIL" "$R" "$rc" "$N"
fi
rm -f "$mini/lib/features/probe_holder.dart"

# 9c. a `@RoutePage()` on a widget whose route the router never registers.
cat > "$mini/lib/features/probe_page.dart" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a page nobody can navigate to.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// A page the router does not register.
@RoutePage()
class ProbePage extends StatelessWidget {
  const ProbePage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
EOF
out=$(mini_run); rc=$?
if [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -qF 'NOT A ROOT'; then
  record "orphan (unregistered)" "fired"
  printf '  %-10s an unregistered @RoutePage() -> FAIL(1) with the NOT A ROOT diagnostic\n' "$G"
else
  record "orphan (unregistered)" "COULD-NOT-FAIL"
  printf '  %-10s %san unregistered @RoutePage() -> exit %d; the diagnostic is not a failure\n' \
    "FAIL" "$R" "$rc" "$N"
fi
rm -f "$mini/lib/features/probe_page.dart"

# 9d. the router file is RENAMED — the router is DERIVED, so the gate still
# works. A literal path would have made this tree have no route table at all.
mv "$mini/lib/app/router/app_router.dart" "$mini/lib/app/router/the_router.dart"
out=$(mini_run); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -qF 'PASSED'; then
  record "orphan (renamed router)" "fired"
  printf '  %-10s the router RENAMED -> still green. The router is derived, not named.\n' "$G"
else
  record "orphan (renamed router)" "COULD-NOT-FAIL"
  printf '  %-10s %sthe router RENAMED -> exit %d; the gate depends on a file NAME\n' \
    "FAIL" "$R" "$rc" "$N"
fi

# 9e. the router file is GONE — FATAL(2), never a silent pass. This is the
# failure mode the literal path had: "no route is registered anywhere" reads
# as a clean tree and answers the registration clause for every page.
mv "$mini/lib/app/router/the_router.dart" "$mini/lib/app/router/the_router.dart.gone"
out=$(mini_run); rc=$?
if [[ $rc -eq 2 ]] && printf '%s' "$out" | grep -qi 'fatal'; then
  record "orphan (no router)" "fired"
  printf '  %-10s the router GONE -> FATAL(2). The gate cannot pass without it.\n' "$G"
else
  record "orphan (no router)" "COULD-NOT-FAIL"
  printf '  %-10s %sthe router GONE -> exit %d; a missing surface must be FATAL\n' \
    "FAIL" "$R" "$rc" "$N"
fi
mv "$mini/lib/app/router/the_router.dart.gone" "$mini/lib/app/router/app_router.dart"

# 9f. a real orphan OUTSIDE `*/widgets/` — the widened inventory. Before the
# widening this file was invisible to the gate, which is the whole of
# decision 144's shape. It goes in `effects/`, which is where the three
# widgets the real tree was missing live.
mkdir -p "$mini/lib/core/design_system/effects"
cat > "$mini/lib/core/design_system/effects/planted_orphan.dart" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a widget nothing constructs.
import 'package:flutter/material.dart';

/// Built, and on no screen.
class PlantedOrphan extends StatelessWidget {
  const PlantedOrphan({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
EOF
out=$(mini_run); rc=$?
if [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -qF 'PlantedOrphan'; then
  record "orphan (widened)" "fired"
  printf '  %-10s an orphan outside */widgets/ -> FAIL(1) and named. The inventory is all of lib/.\n' "$G"
else
  record "orphan (widened)" "COULD-NOT-FAIL"
  printf '  %-10s %san orphan outside */widgets/ -> exit %d; the inventory is still narrow\n' \
    "FAIL" "$R" "$rc" "$N"
fi
rm -f "$mini/lib/core/design_system/effects/planted_orphan.dart"

# --- 10. blur budget gate ---------------------------------------------------
# The blur gate bounds §13.4's budget of per-frame `saveLayer`s. It is a Dart
# test, so its negative control is a file planted in a scratch copy of the
# tree — and the assertions are about the PLANTED PATH, not about the tree's
# other state, so they hold whatever else is in flight.
#
#   comment    `/* GlassTier.blur */` in a feature -> NOT reported (a comment
#              is not a site; the old scan counted block comments)
#   real site  a `GlassTier.blur` in a feature     -> reported
#   both halves a hand-built `ImageFiltered(ImageFilter.blur(…))` -> reported by
#              the COUNT **and** by the direct check. The two halves used to
#              have two definitions of "a site", so the count could say the
#              tree was within budget while the gate was red.
d=$(make_scratch blur)
blur_target="$d/lib/features/reading/presentation/widgets/planted_blur.dart"
blur_run() { ( cd "$d" && flutter test test/core/design_system/widgets/glass_blur_budget_test.dart 2>&1 ); }

# 10a. a block comment naming the enum is not a site.
cat > "$blur_target" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a comment, not a call site.
/* GlassTier.blur */
class PlantedComment {
  const PlantedComment();
}
EOF
out=$(blur_run); rc=$?
if printf '%s' "$out" | grep -qF 'planted_blur.dart'; then
  record "blur (block comment)" "COULD-NOT-FAIL"
  printf '  %-10s %sa /* GlassTier.blur */ comment was counted as a site\n' \
    "FAIL" "$R" "$N"
else
  record "blur (block comment)" "fired"
  printf '  %-10s a /* GlassTier.blur */ comment -> not reported. A comment is not a site.\n' "$G"
fi
rm -f "$blur_target"

# 10b. a REAL site in a feature is reported — the gate can fail.
cat > "$blur_target" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a real site.
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// Spends a blur.
class PlantedSite extends StatelessWidget {
  const PlantedSite({super.key});

  @override
  Widget build(BuildContext context) =>
      const GlassSurface(tier: GlassTier.blur, child: SizedBox.shrink());
}
EOF
out=$(blur_run); rc=$?
if [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -qF 'planted_blur.dart'; then
  record "blur (real site)" "fired"
  printf '  %-10s a real GlassTier.blur -> reported and the gate is red\n' "$G"
else
  record "blur (real site)" "COULD-NOT-FAIL"
  printf '  %-10s %sa real GlassTier.blur -> exit %d and not reported\n' \
    "FAIL" "$R" "$rc" "$N"
fi
rm -f "$blur_target"

# 10c. the two halves must AGREE: a hand-built filter is reported by the
# count as well as by the direct check.
cat > "$blur_target" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a filter the old count could not see.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Spends a blur without naming the enum.
class PlantedDirect extends StatelessWidget {
  const PlantedDirect({super.key});

  @override
  Widget build(BuildContext context) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: const SizedBox.shrink(),
      );
}
EOF
out=$(blur_run); rc=$?
count_fired=0
direct_fired=0
printf '%s' "$out" | grep -qF 'The over-budget sites' && count_fired=1
printf '%s' "$out" | grep -qF 'which is what the budget above counts' && direct_fired=1
if [[ $rc -ne 0 && $count_fired -eq 1 && $direct_fired -eq 1 ]] \
   && printf '%s' "$out" | grep -qF 'planted_blur.dart'; then
  record "blur (one definition)" "fired"
  printf '  %-10s a hand-built filter -> the COUNT and the direct check BOTH report it\n' "$G"
else
  record "blur (one definition)" "COULD-NOT-FAIL"
  printf '  %-10s %sa hand-built filter -> exit %d count-fired=%s direct-fired=%s; the halves disagree\n' \
    "FAIL" "$R" "$rc" "$count_fired" "$direct_fired" "$N"
fi
rm -f "$blur_target"

# --- 11. setState budget gate -----------------------------------------------
# The `setState` gate enforces §13 rule 1 — "no `setState` per frame" — as an
# allowlist of the sites whose `State.build` output IS the state. It is a Dart
# test, so its negative control is a file planted in a scratch copy of the tree
# — and the assertions are about the PLANTED PATH, so they hold whatever else
# is in flight.
#
#   real site  a `setState` in a planted file        -> reported
#   comment    a `setState` inside a doc comment     -> NOT reported (a
#              comment is not a site; the scan strips comments first)
#   stale row  a real site REMOVED                   -> reported (a stale
#              allowlist row is an amnesty nobody re-read)
d=$(make_scratch setstate)
setstate_target="$d/lib/features/reading/presentation/widgets/planted_setstate.dart"
setstate_run() { ( cd "$d" && flutter test test/setstate_budget_test.dart 2>&1 ); }

# 11a. a real `setState` outside the allowlist is reported.
cat > "$setstate_target" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a site, not a comment.
class PlantedSetState {
  bool _pressed = false;

  void press() {
    setState(() {
      _pressed = true;
    });
  }
}
EOF
out=$(setstate_run); rc=$?
if [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -qF 'planted_setstate.dart'; then
  record "setState (new site)" "fired"
  printf '  %-10s a planted `setState` -> reported, and the gate exited %d\n' "$G" "$rc"
else
  record "setState (new site)" "COULD-NOT-FAIL"
  printf '  %-10s %sa planted `setState` -> exit %d; the gate did not report it\n' \
    "FAIL" "$R" "$rc"
fi
rm -f "$setstate_target"

# 11b. a `setState` inside a doc comment is NOT a site.
cat > "$setstate_target" <<'EOF'
// Planted by tool/verify_gates_selftest.sh: a comment, not a call site.
///
/// A doc comment that says `setState(() { ... })` must not be counted.
class PlantedComment {
  const PlantedComment();
}
EOF
out=$(setstate_run); rc=$?
if [[ $rc -eq 0 ]] && ! printf '%s' "$out" | grep -qF 'planted_setstate.dart'; then
  record "setState (comment)" "fired"
  printf '  %-10s a /* setState */ comment -> not reported. A comment is not a site.\n' "$G"
else
  record "setState (comment)" "COULD-NOT-FAIL"
  printf '  %-10s %sa `setState` inside a comment was counted as a site; exit %d\n' \
    "FAIL" "$R" "$rc"
fi
rm -f "$setstate_target"

# 11c. a STALE allowlist row is a failure, not a note.
#
# The site is removed from the scratch copy, so the allowlist's row for that
# file no longer matches anything — and a stale row is an amnesty nobody
# re-read, so the gate has to be red about it.
stale_file="$d/lib/core/design_system/widgets/settings_tile.dart"
if [[ -f "$stale_file" ]]; then
  # **The hovered `setState` and its guard**, dropped by a line filter rather
  # than a regex: a regex over Dart source has to know about the source's own
  # punctuation, and this one only has to drop two lines.
  grep -v -e 'if (_hovered == value) return;' \
          -e 'setState(() => _hovered = value);' \
    "$stale_file" > "$stale_file.tmp" && mv "$stale_file.tmp" "$stale_file"
  out=$(setstate_run); rc=$?
  if [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -qF 'no longer matches the tree'; then
    record "setState (stale row)" "fired"
    printf '  %-10s a removed site -> the stale allowlist row is reported\n' "$G"
  else
    record "setState (stale row)" "COULD-NOT-FAIL"
    printf '  %-10s %sa removed site -> exit %d; the stale row was not reported\n' \
      "FAIL" "$R" "$rc"
  fi
else
  record "setState (stale row)" "COULD-NOT-FAIL"
  printf '  %-10s %sthe file to stale is not in the scratch copy\n' "FAIL" "$R"
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