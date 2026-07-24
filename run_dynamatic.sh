#!/bin/bash
DYNAMATIC_PATH="/data/dynamatic"

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

benchmark_name="fir"

s_source_file="./$benchmark_name.c"

[ -f "$s_source_file" ] || \
  { echo "Source file $s_source_file does not exist!"; exit 1; }

echo "set-dynamatic-path $DYNAMATIC_PATH; \
  set-src $s_source_file; \
  set-fp-units-generator flopoco; \
  set-clock-period 6; \
  compile $FAST_TOKEN $SHARING $BUFFER_ALGORITHM $MILP_SOLVER $DISABLE_LSQ; \
  write-hdl --hdl $HDL; \
  simulate $SIMULATOR --timeout 20000000; \
  synthesize; \
  exit" \
  | $DYNAMATIC_PATH/bin/dynamatic --exit-on-failure --debug

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'Latency = ' "./out/sim/report.txt"

exit
