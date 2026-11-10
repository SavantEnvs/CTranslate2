#!/usr/bin/env bash
#
# mayhem/build.sh — builds the CTranslate2 fuzz harnesses (sanitized library + harnesses, plus a
# -standalone reproducer for each) and the gtest suite (normal flags). Runs in /mayhem as `mayhem`,
# offline: all dependencies are the git submodules in third_party/ and the apt OpenBLAS.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# The compiler comes from CC/CXX (exported above), not -DCMAKE_C_COMPILER: CMake caches the resolved path and
# wipes the cache (dropping every other -D) when a re-run passes the bare name.
# CPU-only build: OpenBLAS (GEMM) + Ruy (int8/int16 GEMM), no OpenMP, single kernel ISA so a run
# does not depend on the host CPU.
COMMON_CMAKE=(
  -G Ninja
  -DBUILD_SHARED_LIBS=OFF -DBUILD_CLI=OFF
  -DWITH_MKL=OFF -DWITH_OPENBLAS=ON -DWITH_RUY=ON
  -DOPENMP_RUNTIME=NONE -DENABLE_CPU_DISPATCH=OFF
)

# 1) Test suite with the project's NORMAL flags (clean, independent build): build-tests/tests/ctranslate2_test
cmake -S . -B build-tests "${COMMON_CMAKE[@]}" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build-tests -j"$MAYHEM_JOBS" --target ctranslate2_test

# 2) The library itself with sanitizers + DWARF 3. -fsanitize=fuzzer-no-link instruments the library for
#    coverage unconditionally (even for an empty SANITIZER_FLAGS). Build type None keeps upstream's
#    asserts (no -DNDEBUG).
#    Three UBSan checks are relaxed (the rest of UBSan and ASan stay halting):
#      function: the bundled cpuinfo (pulled in by Ruy) calls its parse_line callback through a
#                differently-typed function pointer, aborting every run on its first CPU probe.
#      null:     TransformerDecoderLayer forms `*memory` from a null pointer on every decoding step
#                after the first (the encoder K/V are cached, memory is never read), which would abort
#                every translation. A real null dereference still faults and is reported by ASan.
#      float-cast-overflow: the int8/int16 quantization kernels convert NaN/Inf activations to integers
#                (implementation-defined garbage, never a memory error); any mutated weight turning NaN
#                would otherwise abort every translation that reaches a quantized layer.
RELAX="-fno-sanitize=function,null,float-cast-overflow"
FUZZ_FLAGS="$SANITIZER_FLAGS $RELAX -fsanitize=fuzzer-no-link -O1 $DEBUG_FLAGS"
cmake -S . -B build-fuzz "${COMMON_CMAKE[@]}" -DCMAKE_BUILD_TYPE=None \
      -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS"
cmake --build build-fuzz -j"$MAYHEM_JOBS" --target ctranslate2

# 3) Harnesses: each linked once against libFuzzer and once against the standalone run-once driver.
mapfile -t DEP_LIBS < <(find build-fuzz -name '*.a' | sort)
LINK=(-Wl,--start-group "${DEP_LIBS[@]}" -Wl,--end-group -lopenblas -lpthread -ldl)
CXXFLAGS_H=($SANITIZER_FLAGS $RELAX -fsanitize=fuzzer-no-link -O1 $DEBUG_FLAGS -std=c++17 -I"$SRC/include")

# Leak detection is off at build time for every target (ASan memory checks and UBSan stay on).
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o build-fuzz/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build-fuzz/standalone_main.o

for t in fuzz_model_load fuzz_vocabulary fuzz_vocabulary_map; do
  $CXX "${CXXFLAGS_H[@]}" -I"$SRC/mayhem/$t" -c "$SRC/mayhem/$t/$t.cc" -o "build-fuzz/$t.o"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "build-fuzz/$t.o" build-fuzz/lsan_off.o "${LINK[@]}" -o "/mayhem/$t"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS "build-fuzz/$t.o" build-fuzz/standalone_main.o build-fuzz/lsan_off.o "${LINK[@]}" -o "/mayhem/$t-standalone"
done
