#!/usr/bin/env bash
#
# mayhem/test.sh — RUNS upstream's own gtest suite (ctranslate2_test, built by mayhem/build.sh with the
# project's normal flags). The suite checks known-answer values: tensor ops against reference results,
# and translations of the shipped aren-transliteration models against expected output strings.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


TEST_BIN="$SRC/build-tests/tests/ctranslate2_test"
if [ ! -x "$TEST_BIN" ]; then
  echo "missing $TEST_BIN — mayhem/build.sh should have built it" >&2
  emit_ctrf "gtest" 0 1 0
  exit 1
fi

OUT="$(mktemp)"
"$TEST_BIN" "$SRC/tests/data" > "$OUT" 2>&1
cat "$OUT"

# Parse gtest's own summary lines: a program that exits 0 without running the suite prints none of
# them and is counted as a failure.
total="$(sed -n 's/^\[==========\] \([0-9][0-9]*\) tests\? from .* ran\..*/\1/p' "$OUT" | tail -1)"
passed="$(sed -n 's/^\[  PASSED  \] \([0-9][0-9]*\) tests\?\..*/\1/p' "$OUT" | tail -1)"
skipped="$(sed -n 's/^\[  SKIPPED \] \([0-9][0-9]*\) tests\?, listed below.*/\1/p' "$OUT" | tail -1)"
rm -f "$OUT"
: "${total:=0}" "${passed:=0}" "${skipped:=0}"

if [ "$total" -eq 0 ]; then
  echo "no gtest summary found — the suite did not run" >&2
  emit_ctrf "gtest" 0 1 0
  exit 1
fi
failed=$(( total - passed - skipped ))
[ "$failed" -ge 0 ] || failed=0
emit_ctrf "gtest" "$passed" "$failed" "$skipped"
