#!/bin/bash
# Usage: scripts/run_vitis_hls_2024.sh <bench>
# Output: build/vitis_hls_2024/<bench>/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
load_bench "$1" || exit 1

WORK_DIR="$BUILD_DIR/vitis_hls_2024/$BENCH"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# shellcheck disable=SC1091  # Xilinx script
source "$VITIS_HLS_2024_PATH/settings64.sh"

vitis_hls -f "$SCRIPT_DIR/vitis_hls_2024.tcl"
status=$?

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'MAX_LATENCY = ' "./using_vitis_hls_2024/hls/sim/report/verilog/lat.rpt"

exit "$status"
