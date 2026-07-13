#!/usr/bin/env bash
#
# mayhem/build.sh — build the lwgps fuzz target and the upstream test suite.
#
# lwgps is a single-file C library (lwgps/src/lwgps/lwgps.c) that parses NMEA sentences
# from a GPS receiver. The fuzz harness (mayhem/fuzz_nmea_parser.c, ported from the
# original integration) feeds arbitrary bytes to lwgps_process().
#
# Builds:
#   /mayhem/fuzz_nmea_parser             sanitized libFuzzer target (project code instrumented)
#   /mayhem/fuzz_nmea_parser-standalone  run-once reproducer (STANDALONE_FUZZ_MAIN driver)
#   tests/<case>/__build__/              the four upstream CTest suites, NORMAL flags,
#                                        prebuilt so mayhem/test.sh only RUNS them.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "${SRC:-/mayhem}"

LWGPS_SRC="lwgps/src/lwgps/lwgps.c"
INC="lwgps/src/include"

# 1) Sanitized libFuzzer target — the PROJECT ITSELF (lwgps.c) is compiled with the
#    sanitizers so ASan/UBSan see bugs inside the parser, not just the harness.
#    -DLWGPS_IGNORE_USER_OPTS matches the original integration (default lib options).
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE -O1 -I"$INC" -DLWGPS_IGNORE_USER_OPTS \
    mayhem/fuzz_nmea_parser.c "$LWGPS_SRC" -o /mayhem/fuzz_nmea_parser

# 2) Standalone run-once reproducer (same harness, non-fuzzer driver).
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -I"$INC" -DLWGPS_IGNORE_USER_OPTS "$STANDALONE_FUZZ_MAIN" \
    mayhem/fuzz_nmea_parser.c "$LWGPS_SRC" -o /mayhem/fuzz_nmea_parser-standalone

# 3) Upstream test suite (all four CTest cases), NORMAL flags — an independent clean
#    build so mayhem/test.sh only RUNS them. Mirrors upstream tests/test.py: one cmake
#    build per tests/<case>/cmake.cmake, each defining its own LWGPS_OPTS_FILE.
#    Configure -S tests directly so the -D cache value of TEST_CMAKE_FILE_NAME is honored
#    (the repo-root CMakeLists shadows it with a hard-coded normal variable).
for cm in tests/test_parse_*/cmake.cmake; do
    d="$(dirname "$cm")"
    rm -rf "$d/__build__"
    cmake -S tests -B "$d/__build__" -G Ninja \
          -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
          -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" \
          -DTEST_CMAKE_FILE_NAME="$(cd "$d" && pwd)/cmake.cmake"
    cmake --build "$d/__build__" -j"$MAYHEM_JOBS"
done

echo "build.sh: built /mayhem/fuzz_nmea_parser (+standalone) and 4 upstream test suites"
