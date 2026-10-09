# Inputs come from the environment (set by config.sh / load_bench).
set DYNAMATIC_PATH $::env(DYNAMATIC_PATH)

set SRC $::env(SRC_DIR)
set BENCH $::env(BENCH)
set DESIGN_NAME $::env(TOP)
set DYNAMATIC_INC_PATH $DYNAMATIC_PATH/include

open_component -reset using_vitis_hls_2024 -flow_target vivado
add_files $SRC/$BENCH.c -cflags "-I$DYNAMATIC_INC_PATH"
add_files -tb $SRC/$BENCH.c -cflags "-I$DYNAMATIC_INC_PATH"


set_top $DESIGN_NAME
set_part $::env(PART)
create_clock -period $::env(CLOCK_PERIOD) -name default

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
