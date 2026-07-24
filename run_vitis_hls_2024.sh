VITIS_ENV_SH=/tools/Xilinx/Vitis_HLS/2024.2/settings64.sh
source $VITIS_ENV_SH

vitis_hls -f "vitis_hls_2024.tcl"

echo "======================================= "
echo "=== Latency result from simulation: === "
echo "======================================= "
echo ""
grep -E 'MAX_LATENCY = ' "./using_vitis_hls_2024/hls/sim/report/verilog/lat.rpt"
