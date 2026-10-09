# shellcheck shell=bash
# Shared settings for all flows. Sourced by scripts/*.sh.
# Override any variable from the environment, e.g. CLOCK_PERIOD=4 scripts/run_all.sh

# --- Tool installations: see env.sh ---
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# --- Common experiment parameters ---
: "${CLOCK_PERIOD:=6}"                 # ns, used by every flow
: "${PART:=xc7k160tfbg484-2}"          # must match Dynamatic's synthesize.sh part
: "${DYNAMATIC_SIM_TIMEOUT:=20000000}" # simulation timeout passed to `simulate`

# --- Resource limits for run_all.sh ---
: "${RUN_TIMEOUT:=3600}"  # seconds per (tool, benchmark) run
: "${RUN_MEM_MAX:=8G}"    # memory cap per run (systemd-run MemoryMax)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"
BUILD_DIR="$REPO_ROOT/build"

export DYNAMATIC_PATH CLOCK_PERIOD PART REPO_ROOT BENCH_DIR BUILD_DIR

# Load benchmarks/<bench>/bench.cfg if present (per-benchmark overrides).
# Usage: load_bench <bench>; sets BENCH, SRC_DIR, TOP.
load_bench() {
  BENCH="$1"
  SRC_DIR="$BENCH_DIR/$BENCH"
  TOP="$BENCH"
  if [ -z "$BENCH" ] || [ ! -f "$SRC_DIR/$BENCH.c" ]; then
    echo "Benchmark source $SRC_DIR/$BENCH.c does not exist!" >&2
    return 1
  fi
  # shellcheck disable=SC1091
  [ -f "$SRC_DIR/bench.cfg" ] && source "$SRC_DIR/bench.cfg"
  export BENCH SRC_DIR TOP
}
