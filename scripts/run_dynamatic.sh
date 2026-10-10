#!/bin/bash
# Usage: scripts/run_dynamatic.sh <bench>
# Output: build/dynamatic/<bench>/out/{sim,synth,...}
source "$(dirname "$0")/../config.sh"
load_bench "$1" || exit 1

# Options: on-merges,fpga20,fpl22
BUFFER_ALGORITHM="--buffer-algorithm fpga20"
SHARING="--sharing"
SHARING=""
# Options: vhdl,verilog
HDL="vhdl"
FAST_TOKEN="--fast-token-delivery"
FAST_TOKEN=""

MILP_SOLVER="--milp-solver cbc"
# Options: gurobi,cbc (default value is "gurobi")
MILP_SOLVER=""

# Options: vsim,verilator,xsim,ghdl
SIMULATOR="--simulator vsim"

DISABLE_LSQ="--disable-lsq"
DISABLE_LSQ=""

# Set DYNAMATIC_SPECULATION=1 in a benchmark's bench.cfg to honor its
# "#pragma DYN speculate".
SPECULATION=""
[ "${DYNAMATIC_SPECULATION:-0}" = 1 ] && SPECULATION="--speculation"

# Dynamatic writes out/ next to the source file, so run on a copy of the
# benchmark inside the build directory.
WORK_DIR="$BUILD_DIR/dynamatic/$BENCH"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -r "$SRC_DIR"/. "$WORK_DIR"/
cd "$WORK_DIR" || exit 1

# Record the Dynamatic commit used ("-dirty" if tracked files are modified).
{
  git -C "$DYNAMATIC_PATH" rev-parse --short HEAD | tr -d '\n'
  git -C "$DYNAMATIC_PATH" diff --quiet HEAD || printf -- '-dirty'
  echo
} > dynamatic_commit.txt

# synthesize.sh calls `vivado` and simulate.sh calls `vsim` from PATH.
export PATH="$VIVADO_PATH/bin:$MODELSIM_PATH/bin:$PATH"

echo "set-dynamatic-path $DYNAMATIC_PATH; \
  set-vivado-path $VIVADO_PATH; \
  set-src ./$BENCH.c; \
  set-fp-units-generator flopoco; \
  set-clock-period $CLOCK_PERIOD; \
  compile $FAST_TOKEN $SHARING $SPECULATION $BUFFER_ALGORITHM $MILP_SOLVER $DISABLE_LSQ; \
  write-hdl --hdl $HDL; \
  simulate $SIMULATOR --timeout $DYNAMATIC_SIM_TIMEOUT; \
  synthesize; \
  exit" \
  | "$DYNAMATIC_PATH/bin/dynamatic" --exit-on-failure --debug
status=${PIPESTATUS[1]}

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'Latency = ' "./out/sim/report.txt"

exit "$status"
