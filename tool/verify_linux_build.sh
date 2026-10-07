#!/usr/bin/env bash
# Proves the Linux bundle is a **real** build of the current sources.
#
# ## WHY THIS EXISTS AT ALL: `flutter build linux --release` CAN PASS WITHOUT BUILDING
#
# Measured on 2026-10-07. `flutter build linux --release` printed
#
#     Building Linux application...
#     ✓ Built build/linux/x64/release/bundle/evangelion
#
# while `build/linux/x64/release/CMakeCache.txt` was dated **2026-10-04** and the
# `libgtk-3-dev` package the toolchain needs was **not installed**. Every native output
# was already present, so CMake was never asked to regenerate, nothing was compiled, and
# the command reported success anyway.
#
# That is a false green, and it was reported as a passing gate in three consecutive
# commit messages before it was noticed. Deleting the cache and rebuilding produced the
# real answer immediately:
#
#     CMake Error at FindPkgConfig.cmake:1093:  - gtk+-3.0
#     flutter/CMakeLists.txt:25 (pkg_check_modules)
#
# ## THE FAILURE IS CACHED, NOT ALWAYS DETECTED
#
# A stale cache is worse than a missing toolchain, because a missing one fails loudly.
# The poisoned cache held `-I/usr/include/webp` — a path no current `.pc` file mentions
# — so CMake refused to *generate* build files for a header that had nothing to do with
# the code. The fix was deleting `build/linux/x64/{debug,release}`, and it worked.
#
# ## WHAT THIS SCRIPT DOES
#
# 1. `flutter doctor` — the one command that names a missing Linux toolchain package
#    in a single line. It was **absent from §7's gate list** for ten phases, which is
#    how three false greens got through.
# 2. Deletes the native build state, so CMake must regenerate rather than reuse.
# 3. Builds release.
# 4. Asserts the bundle is **not older than the newest Dart source**. A build that
#    relinked nothing leaves a stale artifact, and this is the check that would have
#    caught it on 2026-10-06 as well as on the 7th.
#
# Step 4 compares against `lib/**.dart` only, not the whole tree: the bundle embeds the
# Dart kernel, so a `.dart` change is what must force a relink, while a `docs/` edit
# legitimately does not.

# `--check-only` skips steps 2 and 3 and only runs 1 and 4.
#
# ## WHY THAT FLAG EXISTS: STEP 4 WAS **UNREACHABLE**
#
# Step 2 deletes `build/linux/x64/*` and step 3 rebuilds, so by the time step 4 compares
# timestamps the bundle is always fresh — a check that cannot fail is not a check. It
# was proved unreachable the hard way: a mutation test set the bundle's mtime to 2020,
# ran the whole script, and got **PASSED**, because step 3 relinked it first.
#
# So step 4 is separately exercisable, and this flag is what makes its negative control
# mean anything. Running the full script is the real gate; `--check-only` is how you
# demonstrate the assertion can fail.
set -euo pipefail

check_only=0
[[ "${1:-}" == "--check-only" ]] && check_only=1

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

echo "== 1. flutter doctor =="
# Matched on `Linux toolchain`, **not** on `^\[.\]`. The status glyph is `\u2713` /
# `\u2717` — three bytes of UTF-8 — so `.` matches one BYTE under the C locale and the
# bracket-anchored pattern silently never matches. That is exactly the class of bug this
# script exists to catch, committed inside the script that catches it.
toolchain_line="$(grep -m1 'Linux toolchain' /tmp/eva_doctor.log || true)"
if [[ -z "$toolchain_line" ]]; then
  echo "FAIL: flutter doctor did not report a Linux toolchain line at all." >&2
  cat /tmp/eva_doctor.log >&2
  exit 1
fi
# The two glyphs are U+2713 CHECK MARK and U+2717 BALLOT X, each three bytes of UTF-8.
# Spelled as byte escapes so this file stays ASCII and so the comparison cannot depend
# on the shell's locale.
pass_glyph="$(printf '\xe2\x9c\x93')"
fail_glyph="$(printf '\xe2\x9c\x97')"
if ! grep -qF "$pass_glyph" <<<"$toolchain_line"; then
  if grep -qF "$fail_glyph" <<<"$toolchain_line"; then
    echo "FAIL: flutter doctor reports the Linux toolchain as broken:" >&2
  else
    echo "FAIL: unrecognised status glyph on the toolchain line:" >&2
  fi
  echo "      $toolchain_line" >&2
  grep -A2 'Linux toolchain' /tmp/eva_doctor.log >&2
  exit 1
fi
echo "   $toolchain_line"
if grep -qE '^\[.\] Linux toolchain' /tmp/eva_doctor.log && grep -A1 '^\[.\] Linux toolchain' /tmp/eva_doctor.log | grep -q '^\[x\]'; then
  echo "FAIL: flutter doctor reports the Linux toolchain as broken:" >&2
  grep -A2 '^\[.\] Linux toolchain' /tmp/eva_doctor.log >&2
  exit 1
fi
echo "   Linux toolchain present."

# `clang`, `cmake`, `ninja` and `pkg-config` are what the toolchain is made of, and a
# missing one is the same class of failure as a missing GTK — named here because doctor
# does not check all four.
for tool in clang cmake ninja pkg-config; do
  command -v "$tool" >/dev/null || { echo "FAIL: $tool not on PATH." >&2; exit 1; }
done
echo "   clang, cmake, ninja, pkg-config present."

if [[ "$check_only" -eq 1 ]]; then
  echo "== 2-3. skipped (--check-only) =="
  echo "   NOT verifying that CMake can regenerate. Run without the flag for that."
else
  echo "== 2. clearing native build state so CMake must regenerate =="
  # Only build/linux, never `.dart_tool`: the Dart kernel is the expensive part and is
  # unaffected by a stale CMake configure.
  rm -rf build/linux/x64/debug build/linux/x64/release
  echo "   removed."

  echo "== 3. flutter build linux --release =="
  flutter build linux --release
fi

echo "== 4. the bundle must be at least as new as the newest Dart source =="
bundle="build/linux/x64/release/bundle/evangelion"
[[ -f "$bundle" ]] || { echo "FAIL: no bundle at $bundle." >&2; exit 1; }

bundle_mtime="$(python3 -c 'import os,sys; print(int(os.path.getmtime(sys.argv[1])))' "$bundle")"
newest_mtime="$(find lib -name '*.dart' -printf '%T@\n' | sort -rn | head -1 | cut -d. -f1)"
newest_file="$(find lib -name '*.dart' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)"

if [[ "$bundle_mtime" -lt "$newest_mtime" ]]; then
  echo "FAIL: the bundle is OLDER than the newest Dart source." >&2
  echo "      bundle:     $(date -d "@$bundle_mtime" '+%F %T')" >&2
  echo "      newest src: $(date -d "@$newest_mtime" '+%F %T')  $newest_file" >&2
  echo "      A build that reports success without relinking is a false green." >&2
  exit 1
fi

echo "   bundle $(date -d "@$bundle_mtime" '+%F %T')"
echo "   newest  $(date -d "@$newest_mtime" '+%F %T')  $newest_file"
echo
echo "PASSED - the Linux bundle is a real build of the current sources."