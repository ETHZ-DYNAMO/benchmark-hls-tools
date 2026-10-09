#!/bin/bash
# Usage: scripts/run_vivado_hls_2019.sh <bench>
# Output: build/vivado_hls_2019/<bench>/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
load_bench "$1" || exit 1

WORK_DIR="$BUILD_DIR/vivado_hls_2019/$BENCH"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# shellcheck disable=SC1091  # Xilinx script
source "$VIVADO_HLS_2019_PATH/settings64.sh"

vivado_hls -f "$SCRIPT_DIR/vivado_hls_2019.tcl"
status=$?

# Vivado HLS 2019.1 writes the current date as YYMMDDHHMM into the IP's
# core_revision, which overflows a 32-bit int from 2022 on and makes
# export_design fail (Xilinx AR 76960). Run only export_design with a pre-2022
# clock that keeps ticking ("@"); XSim fails to start under faketime, so
# csim/cosim above use the real clock. Set VIVADO_HLS_2019_FAKETIME="" to
# disable.
FAKETIME_DATE="${VIVADO_HLS_2019_FAKETIME-@2021-12-31 00:00:00}"
FAKETIME_CMD=()
[ -n "$FAKETIME_DATE" ] && FAKETIME_CMD=(faketime -f "$FAKETIME_DATE")

if [ "$status" -eq 0 ]; then
  "${FAKETIME_CMD[@]}" vivado_hls -f "$SCRIPT_DIR/vivado_hls_2019_export.tcl"
  status=$?
fi

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'MAX_LATENCY = ' "./using_vivado_hls_2019/solution1/sim/report/verilog/lat.rpt"

exit "$status"
