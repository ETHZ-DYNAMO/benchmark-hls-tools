set DYNAMATIC_PATH /data/dynamatic

set SRC .
set DESIGN_NAME fir
set DYNAMATIC_INC_PATH $DYNAMATIC_PATH/include

open_project -reset "using_vivado_hls_2019" 
add_files $SRC/$DESIGN_NAME.c -cflags "-I$DYNAMATIC_INC_PATH"
add_files -tb $SRC/$DESIGN_NAME.c -cflags "-I$DYNAMATIC_INC_PATH"

open_solution -reset "solution1"

set_top $DESIGN_NAME
set_part {xc7k160tfbg484-2}
create_clock -period 6 -name default

if { [catch {csim_design} err] } {
  puts "FAIL: catch error in csim."
  close_project 
  exit 1
} else {
  puts "SUCCESS: csim ok."
}

csynth_design

if { [catch {cosim_design -trace_level all } err] } {
  puts "FAIL: catch error in cosim."
  close_project 
  exit 1
} else {
  puts "SUCCESS: cosim ok."
}

if { [catch {export_design -flow impl -rtl verilog } err] } {
  puts "FAIL: catch error in implementation using vivado."
  close_project 
  exit 1
} else {
  puts "SUCCESS: implementation ok."
}

exit 0
