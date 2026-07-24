# Comparing Dynamatic vs. Vitis

## 1. List of things to change depending on how you set up Dynamatic and Vitis

### `run_vitis.sh`

Change `VITIS_ENV_SH` (path hardcoded to the default installation path of Vitis).


### `vitis_hls.tcl`

Change `DYNAMATIC_PATH` to where you installed Dynamatic (it should have `llvm-project`, `tools`, `lib`, etc... in that location).


### `run_dynamatic.sh`

Change `DYNAMATIC_PATH` to where you installed Dynamatic (it should have `llvm-project`, `tools`, `lib`, etc... in that location).


## 2. Run simulation and read out the latency

To run the Dynamatic flow:

```
bash run_dynamatic.sh
```

To run the Vitis flow:

```
bash run_vitis2024.sh
```

## 3. Read the performance and resources metrics

We want to report the clock period (target - Slack), latency (clock cycles),
the wall clock time (clock cycles * clock period), the number of LUTs.

### Dynamatic

Latency (logged at the end of the `run_dynamatic.sh` script): Go to the end of `out/sim/report.txt`, there is a line with `# ** Note: Simulation done! Latency = XXX cycles`.
Area (the number of LUTs): Go to `out/synth/utilization_post_pr.rpt`.
Timing (the slack): Go to `out/synth/timing_post_pr.rpt`.

### Vitis HLS

Latency (logged at the end of the `run_vitis2024.sh` script): Go to `using_vitis_hls_2024/hls/sim/report/NAME_cosim.rpt`
Area: Go to `using_vitis_hls_2024/hls/impl/verilog/report/NAME_design_analysis_routed.rpt`
Timing (the slack): Go to `using_vitis_hls_2024/hls/impl/verilog/report/NAME_timing_paths_routed.rpt`


