set DYNAMATIC_PATH /data/dynamatic

set SRC .
set DESIGN_NAME fir
set DYNAMATIC_INC_PATH $DYNAMATIC_PATH/include

open_component -reset solution1 -flow_target vivado
add_files $SRC/$DESIGN_NAME.c -cflags "-I$DYNAMATIC_INC_PATH"
add_files -tb $SRC/$DESIGN_NAME.c -cflags "-I$DYNAMATIC_INC_PATH"


set_top $DESIGN_NAME
set_part {xc7k160tfbg484-2}
create_clock -period 4 -name default

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

if { [catch {export_design -flow impl } err] } {
  puts "FAIL: catch error in implementation using vivado."
  close_project 
  exit 1
} else {
  puts "SUCCESS: implementation ok."
}

exit 0
