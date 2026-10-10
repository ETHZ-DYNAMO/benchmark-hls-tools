# Comparing Dynamatic vs. Vitis

## 1. Layout

```
env.sh                     # EDA tool locations (Dynamatic, Vivado, ModelSim, HLS tools)
config.sh                  # CLOCK_PERIOD, PART, per-run limits; sources env.sh
benchmarks/<bench>/        # sources only (<bench>.c [+ <bench>.h] [+ bench.cfg])
scripts/
  run_dynamatic.sh <bench>
  run_vitis_hls_2024.sh <bench>
  run_vivado_hls_2019.sh <bench>
  vitis_hls_2024.tcl, vivado_hls_2019.tcl
  vivado_hls_2019_export.tcl  # export_design step, run under faketime
  run_all.sh               # tools x benchmarks, with timeout + memory cap
  collect_results.py       # reports -> results/summary.csv
  plot_results.py          # summary.csv -> results/plots/
build/<tool>/<bench>/      # generated (gitignored)
results/summary.csv        # one row per (bench, tool)
results/logs/<tool>/       # per-run logs and exit codes (gitignored)
```

## 2. Setup

Edit `env.sh` to point to the EDA tools on your machine (or override from the
environment):

- `DYNAMATIC_PATH`: where Dynamatic is installed (should have `llvm-project`, `tools`, `lib`, etc.).
- `VIVADO_PATH`: the Vivado Dynamatic uses for `synthesize` and for `glbl.v` in
  `simulate` (default 2024.2, the same Vivado that Vitis HLS 2024 uses for implementation).
- `MODELSIM_PATH`: ModelSim/Questa install providing `bin/vsim`.
- `VITIS_HLS_2024_PATH`, `VIVADO_HLS_2019_PATH`: install roots of the HLS tools
  (their `settings64.sh` is sourced by the matching run script).

Experiment parameters live in `config.sh`:

- `CLOCK_PERIOD` (default 6 ns) and `PART` (default `xc7k160tfbg484-2`, the part
  hardcoded in Dynamatic's `synthesize.sh`) apply to every flow.

The benchmarks in `benchmarks/` were copied from Dynamatic's `integration-test/`
(commit `bfcb8bc2a`) and are maintained here; local changes (e.g. HLS pragmas)
are tracked in this repo's history. Changes from the original:

- All benchmarks: `#pragma HLS pipeline II=1` on each innermost loop (in
  `matrix_power`, braces were added around the inner loop body). Dynamatic
  ignores `#pragma HLS`.

To add a benchmark, create `benchmarks/<bench>/<bench>.c` (plus headers) with a
`main` that calls the kernel via `CALL_KERNEL`.

`benchmarks/<bench>/bench.cfg` (optional, sourced by bash) can override `TOP`
when the kernel name differs from the benchmark name, and set
`DYNAMATIC_SPECULATION=1` to compile with Dynamatic's `--speculation` (used by
`backtrack` and `newton_raphson`, which contain `#pragma DYN speculate`).

## 3. Run

One tool, one benchmark:

```
bash scripts/run_dynamatic.sh fir
bash scripts/run_vitis_hls_2024.sh fir
bash scripts/run_vivado_hls_2019.sh fir
```

Everything (or a subset), then collect results:

```
bash scripts/run_all.sh                                   # all tools, all benchmarks
bash scripts/run_all.sh -j 3 -t dynamatic,vitis_hls_2024 fir matvec
python3 scripts/collect_results.py                        # re-collect only
python3 scripts/plot_results.py                           # plots (see below)
```

Each run gets `RUN_TIMEOUT` seconds (default 3600) and `RUN_MEM_MAX` memory
(default 8G).

## 4. Metrics

`results/summary.csv` reports, after place & route:

- `achieved_cp` = target clock period - worst setup slack
- `latency_cycles` from cosimulation
- `exec_time_ns` = latency_cycles * achieved_cp (wall-clock time)
- `LUT`, `FF`, `DSP`, `BRAM`

`scripts/plot_results.py` plots, per baseline (Vitis HLS 2024, Vivado HLS 2019),
Dynamatic's LUTs vs. latency normalized to the baseline (baseline at (1, 1)),
once with latency in cycles and once with wall-clock time (`exec_time_ns`):
`results/plots/dynamatic_vs_<baseline>_LUT_{cycles,wallclock}.{pdf,png}`.
The Dynamatic commit (recorded per run in `build/dynamatic/<bench>/dynamatic_commit.txt`,
column `tool_version`) is shown in the figure.

Where the numbers come from (relative to `build/<tool>/<bench>/`):

| | Dynamatic | Vitis HLS 2024 | Vivado HLS 2019 |
|---|---|---|---|
| Latency | `out/sim/report.txt` (`Latency = N cycles`) | `using_vitis_hls_2024/hls/sim/report/verilog/lat.rpt` | `using_vivado_hls_2019/solution1/sim/report/verilog/lat.rpt` |
| Area | `out/synth/utilization_post_pr.rpt` | `using_vitis_hls_2024/hls/impl/verilog/report/<top>_utilization_routed.rpt` | `using_vivado_hls_2019/solution1/impl/verilog/report/<top>_utilization_routed.rpt` |
| Timing | `out/synth/timing_post_pr.rpt` | `using_vitis_hls_2024/hls/impl/verilog/report/<top>_timing_paths_routed.rpt` | `using_vivado_hls_2019/solution1/impl/verilog/report/<top>_timing_paths_routed.rpt` |

## 5. Known issues

- Vivado HLS 2019.1 `export_design` fails after 2021 with `bad lexical cast ...
  core_revision` (`ERROR: [IMPL 213-28] Failed to generate IP`): the IP
  revision is the current date as YYMMDDHHMM, which overflows a 32-bit int
  (Xilinx AR 76960). `run_vivado_hls_2019.sh` therefore runs `export_design`
  in a second `vivado_hls` call (`vivado_hls_2019_export.tcl`) under
  `faketime "@2021-12-31 00:00:00"`. csim/cosim run with the real clock because
  XSim fails to start under faketime. Override the date with
  `VIVADO_HLS_2019_FAKETIME`, or set it to `""` to disable.
