#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the upstream lwgps test suite (prebuilt by mayhem/build.sh).
#
# Upstream ships four CTest cases (tests/test_parse_standard, _beidou, _ext_time,
# _sat_det), each a known-answer test asserting parsed NMEA field values via RUN_TEST
# assertions — a real behavioral oracle: a neutered exit(0) parser leaves lwgps_t
# zeroed and every assertion fails. build.sh compiled each into tests/<case>/__build__;
# this script only runs ctest there and reports CTRF counts.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

passed=0; failed=0

# emit_ctrf <tool> <passed> <failed> [skipped]
emit_ctrf() {
  local tool="$1" p="$2" f="$3" s="${4:-0}"
  local tests=$(( p + f + s ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": { "tests": $tests, "passed": $p, "failed": $f, "pending": 0, "skipped": $s, "other": 0 }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":0,"skipped":%d,"other":0}}}\n' \
    "$tool" "$tests" "$p" "$f" "$s"
  [ "$f" -eq 0 ]
}

cases=(tests/test_parse_*/cmake.cmake)
if [ "${#cases[@]}" -eq 0 ]; then
  echo "test.sh: no test cases found" >&2
  emit_ctrf cmake-ctest 0 1; exit 1
fi

for cm in "${cases[@]}"; do
  d="$(dirname "$cm")"
  name="$(basename "$d")"
  if [ ! -d "$d/__build__" ]; then
    echo "  FAIL - $name (__build__ missing — build.sh must build it, not rebuilding here)"
    failed=$((failed+1)); continue
  fi
  log="/tmp/lwgps-ctest-$name.log"
  # -VV so the runner's stdout is captured even on pass: the behavioral check below requires
  # the suite's own output markers, so a binary neutered to a silent exit(0) cannot pass.
  if (cd "$d/__build__" && ctest -VV -C Debug) >"$log" 2>&1 \
     && grep -q 'Application running' "$log" && grep -q '^1: Done' "$log"; then
    echo "  ok   - $name"; passed=$((passed+1))
  else
    echo "  FAIL - $name"; tail -20 "$log" | sed 's/^/    /'; failed=$((failed+1))
  fi
done

echo "test.sh: passed=$passed failed=$failed"
emit_ctrf cmake-ctest "$passed" "$failed"
