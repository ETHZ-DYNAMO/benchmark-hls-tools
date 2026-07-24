VITIS_ENV_SH=/tools/Xilinx/Vivado/2019.1/settings64.sh
source $VITIS_ENV_SH

vivado_hls -f "vivado_hls_2019.tcl"

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'MAX_LATENCY = ' "./solution1/hls/sim/report/verilog/lat.rpt"
