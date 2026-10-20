#!/usr/bin/env bash
#
# arabic_tofu_selftest.sh — prove the shared Arabic tofu gate can still fail, and
# that Task 5.7's change to it is what moved the outcome.
#
# ## WHY THIS EXISTS
#
# AGENT_CONTEXT §7: "a gate that cannot fail is worse than no gate". Task 5.7
# changed `test/support/arabic_typography_gate.dart` so that a run's **fallbacks**
# are read alongside its family — because Flutter falls back PER GLYPH, and the
# gate was reporting a **correctly rendered** character as tofu.
#
# The case is the `↺` (U+21BA) of the Workshop's restore row: it is drawn in
# `JetBrainsMono` with `fontFamilyFallback: [Inter]`, and U+21BA is in **no**
# bundled mono or scripture face.
#
# ## WHAT IS PLANTED
#
#   fallback  a run whose glyph is in the FALLBACK and not in the primary
#             family. The NEW gate must PASS it (it is rendered), and the OLD
#             gate must FAIL it (it asked only the primary family).
#
#   tofu      a run whose glyph is in NO family at all. **Both** gates must
#             FAIL it — the control that proves the change did not weaken the
#             gate into a hole.
#
# ## THE SCRATCH COPY
#
# Under /tmp/opencode/arabic-tofu-selftest, never the working tree. `.dart_tool`
# and `pubspec.lock` are symlinked rather than copied: the gate needs a resolved
# package config, and a full `flutter pub get` per copy would make this script
# unusable.
#
# ## USAGE
#
#     tool/arabic_tofu_selftest.sh
#
# Exit:  0 the gate was proven able to fail, and the fix was proven to be why
#        1 the gate could not be made to fail — READ THIS, it is a defect
#        2 the harness itself could not run

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

readonly SCRATCH="/tmp/opencode/arabic-tofu-selftest"
[[ -d lib ]] || { echo "FATAL: run from the repo root (no lib/ under $ROOT)" >&2; exit 2; }

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; G=''; B=''; N=''
fi

make_scratch() {
  local dir="$SCRATCH"
  rm -rf "$dir"; mkdir -p "$dir"
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

# The plant: a run in the mono face with the arrow in the UI face's fallback.
PLANT='import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "support/arabic_typography_gate.dart";

void main() {
  testWidgets("a glyph the FALLBACK carries is rendered, not tofu", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text(
          "↺",
          style: TextStyle(
            fontFamily: "JetBrainsMono",
            fontFamilyFallback: <String>["Inter"],
          ),
        ),
      ),
    );
    await expectNoTofuInAnyRun(tester, screen: "the planted run");
  });
}
'

# The control: a glyph in no family at all. Both gates must fail on it.
CONTROL='import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "support/arabic_typography_gate.dart";

void main() {
  testWidgets("a glyph NO family carries is tofu", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text(
          "一",
          style: TextStyle(fontFamily: "JetBrainsMono"),
        ),
      ),
    );
    await expectNoTofuInAnyRun(tester, screen: "the planted run");
  });
}
'

FAILED=0

# --- 1. the fallback plant, against the NEW gate ------------------------------
d=$(make_scratch)
printf '%s' "$PLANT" > "$d/test/planted_fallback_test.dart"
if (cd "$d" && flutter test test/planted_fallback_test.dart >/tmp/opencode/arabic-fallback-new.log 2>&1); then
  echo "  ${G}ok${N}     a glyph the FALLBACK carries -> the gate PASSED, so it is"
  echo "         not reported as tofu"
else
  echo "  ${R}FAIL${N}  a glyph the FALLBACK carries -> the gate FAILED:"
  grep -E 'Actual:|Failing tests' /tmp/opencode/arabic-fallback-new.log | head -4
  FAILED=1
fi

# --- 2. the SAME plant against the OLD gate, to show the fix is what changed ---
d=$(make_scratch)
# Revert the change: the coverage is the primary family's again.
python3 - "$d/test/support/arabic_typography_gate.dart" <<'PY'
import sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()
old = """    final Set<int> available = <int>{
      ...codepointsForFamily(run.family),
      for (final String candidate in run.fallbacks)
        if (kBundledFontFamilies.contains(candidate))
          ...codepointsForFamily(candidate),
    };"""
new = """    final Set<int> available = codepointsForFamily(run.family);"""
if old not in src:
    raise SystemExit('the coverage union was not found in the scratch copy')
open(path, 'w', encoding='utf-8').write(src.replace(old, new))
PY
printf '%s' "$PLANT" > "$d/test/planted_fallback_test.dart"
if (cd "$d" && flutter test test/planted_fallback_test.dart >/tmp/opencode/arabic-fallback-old.log 2>&1); then
  echo "  ${R}FAIL${N}  the OLD gate on the same plant -> the gate PASSED, so the"
  echo "         comparison proves nothing"
  FAILED=1
else
  echo "  ${G}ok${N}     the OLD gate on the same plant -> the gate FAILED, so the"
  echo "         fallback rule is what changed the outcome"
fi

# --- 3. the control: a real tofu, on the NEW gate ----------------------------
d=$(make_scratch)
printf '%s' "$CONTROL" > "$d/test/planted_tofu_test.dart"
if (cd "$d" && flutter test test/planted_tofu_test.dart >/tmp/opencode/arabic-tofu-control.log 2>&1); then
  echo "  ${R}FAIL${N}  a glyph NO family carries -> the gate PASSED, so the change"
  echo "         turned the gate into a hole"
  FAILED=1
else
  echo "  ${G}ok${N}     a glyph NO family carries -> the gate FAILED, so it still bites"
fi

echo
if [[ $FAILED -eq 0 ]]; then
  echo "${G}Every planted violation fired.${N}"
  exit 0
fi
echo "${R}A plant did not fire — READ THIS, it is a defect.${N}"
exit 1
