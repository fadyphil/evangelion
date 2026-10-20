#!/usr/bin/env bash
#
# nct_selftest.sh — prove the converted-types gate can actually fail, and that
# the two scan fixes Task 5.7 made are the reason it does.
#
# ## WHY THIS EXISTS
#
# AGENT_CONTEXT §7: "a gate that cannot fail is worse than no gate". Task 5.7
# changed the scan in `test/core/common/no_identical_on_converted_types_test.dart`
# twice — the test-declaration boundary and the string-literal rule — and the
# repository's rule is explicit: "When you change a gate, plant a violation and
# prove it fires before you report the gate as fixed."
#
# ## WHAT IS PLANTED
#
#   multi-line  a `testWidgets(` whose NAME IS ON THE NEXT LINE, holding an
#               identity site and with no row in the audited table. The OLD scan
#               matched declarations PER LINE, so it never saw the boundary, and
#               the site was attributed to the PREVIOUS test — which has a row —
#               and the gate passed. The fixed scan must attribute it to the
#               planted test and FAIL.
#
#   in-a-name   a test whose NAME contains the word `identical(` and which
#               holds NO identity site. The OLD scan counted the name as a
#               call, so it reported a live site with no row and FAILED. The
#               fixed scan must not, and the gate must PASS — and the
#               comparison run below shows the old scan's outcome.
#
# ## THE SCRATCH COPY
#
# Under /tmp/opencode/nct-selftest, never the working tree. Planting a
# violation in the real tree and reverting it afterwards works until something
# interrupts the revert, and an interrupted revert is a broken working tree.
# `.dart_tool` and `pubspec.lock` are symlinked rather than copied: the gate
# needs a resolved package config, and a full `flutter pub get` per copy would
# make this script unusable.
#
# ## USAGE
#
#     tool/nct_selftest.sh
#
# Exit:  0 the gate was proven able to fail, and the fix was proven to be why
#        1 the gate could not be made to fail — READ THIS, it is a defect
#        2 the harness itself could not run

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

readonly SCRATCH="/tmp/opencode/nct-selftest"
[[ -d lib ]] || { echo "FATAL: run from the repo root (no lib/ under $ROOT)" >&2; exit 2; }

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; B=''; N=''
fi

make_scratch() {
  local dir="$SCRATCH"
  rm -rf "$dir"; mkdir -p "$dir"
  # Tracked sources AND the working tree's untracked ones: this task's whole
  # point is that the new files are not in `git ls-files` yet, and a copy
  # without them would not compile.
  { git ls-files -z; git ls-files -z --others --exclude-standard; } |
    while IFS= read -r -d '' f; do
      [[ -f "$ROOT/$f" ]] || continue
      mkdir -p "$dir/$(dirname "$f")"
      cp "$ROOT/$f" "$dir/$f"
    done
  ln -s "$ROOT/.dart_tool" "$dir/.dart_tool" 2>/dev/null || true
  cp "$ROOT/pubspec.lock" "$dir/pubspec.lock" 2>/dev/null || true
  printf '%s' "$dir"
}

GATE='test/core/common/no_identical_on_converted_types_test.dart'
FAILED=0

echo "${B}Converted-types gate self-test — it must FAIL against a planted violation${N}"
echo

# --- 1. the multi-line boundary ------------------------------------------------
d=$(make_scratch)
mkdir -p "$d/test/core/common"
cat > "$d/test/core/common/planted_multiline_test.dart" <<'EOF'
// Planted by tool/nct_selftest.sh.
//
// The name is on the NEXT LINE, which is the shape the OLD scan missed: it
// matched test declarations per line, so this declaration was not a boundary
// and the site below was attributed to the PREVIOUS test — one that has a row
// in the audited table — and the gate passed.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a planted group', () {
    testWidgets(
      'a planted name on the next line',
      (WidgetTester tester) async {
        final Object a = Object();
        final Object b = Object();
        expect(identical(a, b), isFalse);
      },
    );
  });
}
EOF
if (cd "$d" && flutter test "$GATE" >/tmp/opencode/nct-multiline.log 2>&1); then
  echo "  ${R}FAIL${N}  planted a site in a multi-line declaration -> the gate PASSED"
  echo "         (the old per-line scan would have missed it; the fix is not working)"
  FAILED=1
else
  if grep -q 'planted name on the next line' /tmp/opencode/nct-multiline.log; then
    echo "  ${G}ok${N}     planted a site in a multi-line declaration -> the gate FAILED,"
    echo "         naming the planted test"
  else
    echo "  ${R}FAIL${N}  the gate failed but did not name the planted test:"
    grep -E 'Actual:|Failing tests' /tmp/opencode/nct-multiline.log | head -4
    FAILED=1
  fi
fi

# --- 2. the string-literal rule, with the old scan for comparison ---------------
d=$(make_scratch)
mkdir -p "$d/test/core/common"
cat > "$d/test/core/common/planted_in_a_name_test.dart" <<'EOF'
// Planted by tool/nct_selftest.sh.
//
// The NAME contains the word `identical(` and the test holds NO identity site.
// The OLD scan counted the name as a call, so it reported a live site that no row
// covered, and the gate FAILED on a file with nothing wrong with it.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a planted group', () {
    test('a planted name mentioning identical() and nothing else', () {
      expect(1 + 1, 2);
    });
  });
}
EOF
if (cd "$d" && flutter test "$GATE" >/tmp/opencode/nct-in-a-name.log 2>&1); then
  echo "  ${G}ok${N}     planted a name containing identical() -> the gate PASSED,"
  echo "         so the name is not counted as a call"
else
  echo "  ${R}FAIL${N}  planted a name containing identical() -> the gate FAILED:"
  grep -E 'Actual:|Failing tests' /tmp/opencode/nct-in-a-name.log | head -4
  FAILED=1
fi

# --- 3. the SAME plant against the OLD scan, to show the fix is what changed -----
d=$(make_scratch)
# Revert the string-literal rule: the old scan took the first match on the line
# without asking whether the match was inside a string.
python3 - "$d/$GATE" <<'PY'
import re
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()
src = src.replace(
    """    if (_insideStringLiteral(line, match.start)) continue;
""",
    '',
)
open(path, 'w', encoding='utf-8').write(src)
PY
cat > "$d/test/core/common/planted_in_a_name_test.dart" <<'EOF'
// Planted by tool/nct_selftest.sh — see the script's header.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a planted group', () {
    test('a planted name mentioning identical() and nothing else', () {
      expect(1 + 1, 2);
    });
  });
}
EOF
if (cd "$d" && flutter test "$GATE" >/tmp/opencode/nct-old-scan.log 2>&1); then
  echo "  ${R}FAIL${N}  the OLD scan on the same plant -> the gate PASSED, so the"
  echo "         comparison proves nothing"
  FAILED=1
else
  echo "  ${G}ok${N}     the OLD scan on the same plant -> the gate FAILED, so the"
  echo "         string-literal rule is what changed the outcome"
fi

echo
if [[ $FAILED -eq 0 ]]; then
  echo "${G}Every planted violation fired.${N}"
  exit 0
fi
echo "${R}A plant did not fire — READ THIS, it is a defect.${N}"
exit 1
