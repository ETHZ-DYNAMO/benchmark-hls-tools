#!/usr/bin/env python3
"""Parse each tool's reports under build/ into results/summary.csv.

Usage: scripts/collect_results.py [--build DIR] [--out FILE]

achieved_cp = target_cp - worst setup slack (post place & route)
exec_time_ns = latency_cycles * achieved_cp
"""
import argparse
import csv
import os
import re
import sys
from pathlib import Path
from typing import Any, Callable

REPO = Path(__file__).resolve().parent.parent
TOOLS = ["dynamatic", "vitis_hls_2024", "vivado_hls_2019"]
FIELDS = ["bench", "tool", "tool_version", "status", "target_cp", "achieved_cp",
          "latency_cycles", "exec_time_ns", "LUT", "FF", "DSP", "BRAM",
          "Slice"]


def read(path):
    try:
        return Path(path).read_text(errors="replace")
    except OSError:
        return None


def search(pattern, text, cast: Callable[[str], Any] = float):
    m = re.search(pattern, text or "", re.M)
    return cast(m.group(1)) if m else None


def parse_utilization(text):
    """Vivado report_utilization (7-series naming)."""
    def row(name):
        return search(r"^\|\s*" + re.escape(name) + r"\s*\|\s*([\d.]+)\s*\|",
                      text)
    return {"LUT": row("Slice LUTs"), "FF": row("Slice Registers"),
            "DSP": row("DSPs"), "BRAM": row("Block RAM Tile"),
            "Slice": row("Slice")}


def parse_slack(text):
    """First (worst) path of a Vivado report_timing."""
    return search(r"^Slack \((?:MET|VIOLATED)\)\s*:\s*(-?[\d.]+)ns", text)


def report_paths(tool, bench_dir, top):
    if tool == "dynamatic":
        out = bench_dir / "out"
        return (out / "sim/report.txt", out / "synth/utilization_post_pr.rpt",
                out / "synth/timing_post_pr.rpt")
    if tool == "vitis_hls_2024":
        sol = bench_dir / "using_vitis_hls_2024/hls"
    else:
        sol = bench_dir / "using_vivado_hls_2019/solution1"
    rpt = sol / "impl/verilog/report"
    return (sol / "sim/report/verilog/lat.rpt",
            rpt / f"{top}_utilization_routed.rpt",
            rpt / f"{top}_timing_paths_routed.rpt")


def bench_top(bench):
    """TOP override from benchmarks/<bench>/bench.cfg, else the bench name."""
    cfg = read(REPO / "benchmarks" / bench / "bench.cfg")
    return search(r'^\s*TOP="?([\w]+)"?', cfg, str) or bench


def tool_version(tool, bench_dir):
    """Dynamatic: commit recorded by run_dynamatic.sh; others: tool release."""
    if tool == "dynamatic":
        commit = read(bench_dir / "dynamatic_commit.txt")
        return commit.strip() if commit else None
    return {"vitis_hls_2024": "2024.2", "vivado_hls_2019": "2019.1"}[tool]


def status_of(tool, bench):
    rc = read(REPO / "results/logs" / tool / f"{bench}.status")
    if rc is None:
        return "not_run"
    rc = rc.strip()
    if rc == "0":
        return "ok"
    if rc == "124":
        return "timeout"
    log = read(REPO / "results/logs" / tool / f"{bench}.log") or ""
    for marker, name in [("error in csim", "csim_fail"),
                         ("error in cosim", "cosim_fail"),
                         ("error in implementation", "impl_fail"),
                         ("Logic synthesis failed", "synth_fail"),
                         ("Simulation failed", "sim_fail")]:
        if marker in log:
            return name
    return f"fail(exit {rc})"


def collect(build, target_cp):
    rows = []
    for tool in TOOLS:
        tool_dir = build / tool
        if not tool_dir.is_dir():
            continue
        for bench_dir in sorted(p for p in tool_dir.iterdir() if p.is_dir()):
            bench = bench_dir.name
            lat_f, util_f, timing_f = report_paths(tool, bench_dir,
                                                   bench_top(bench))
            if tool == "dynamatic":
                latency = search(r"Latency = (\d+) cycles", read(lat_f), int)
            else:
                latency = search(r'MAX_LATENCY = "(\d+)"', read(lat_f), int)
            slack = parse_slack(read(timing_f))
            achieved = round(target_cp - slack, 3) if slack is not None else None
            row = {"bench": bench, "tool": tool,
                   "tool_version": tool_version(tool, bench_dir),
                   "status": status_of(tool, bench), "target_cp": target_cp,
                   "achieved_cp": achieved, "latency_cycles": latency,
                   "exec_time_ns": (round(latency * achieved, 1)
                                    if latency is not None and achieved
                                    else None)}
            util = parse_utilization(read(util_f))
            row.update({k: int(v) if v is not None else None
                        for k, v in util.items()})
            rows.append(row)
    return rows


def main():
    ap = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    ap.add_argument("--build", type=Path, default=REPO / "build")
    ap.add_argument("--out", type=Path, default=REPO / "results/summary.csv")
    args = ap.parse_args()
    target_cp = float(os.environ.get("CLOCK_PERIOD", 6))

    rows = collect(args.build, target_cp)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)

    w = csv.DictWriter(sys.stdout, fieldnames=FIELDS)
    w.writeheader()
    w.writerows(rows)
    print(f"-> {args.out.relative_to(REPO) if args.out.is_relative_to(REPO) else args.out}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
