# Reopens the project created by vivado_hls_2019.tcl and runs place & route.
# Run under faketime by run_vivado_hls_2019.sh (see there for why).
open_project "using_vivado_hls_2019"
open_solution "solution1"

if { [catch {export_design -flow impl -rtl verilog } err] } {
  puts "FAIL: catch error in implementation using vivado."
  close_project 
  exit 1
} else {
  puts "SUCCESS: implementation ok."
}

exit 0
