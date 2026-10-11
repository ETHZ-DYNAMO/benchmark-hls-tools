#!/usr/bin/env python3
"""Plot Dynamatic's resources vs. latency, normalized to an HLS baseline.

Usage: scripts/plot_results.py [--latency cycles|wallclock|both]
                               [--resource LUT|FF|DSP]
                               [--summary FILE] [--out-dir DIR]

One figure per baseline (Vitis HLS 2024, Vivado HLS 2019) and latency metric.
For each benchmark, Dynamatic's point is
(latency_dyn / latency_base, resource_dyn / resource_base), so the baseline is
always at (1, 1).

Latency metrics:
  cycles     latency in clock cycles (cosimulation)
  wallclock  cycles * achievable clock period, where
             achievable clock period = target period - worst-case slack
"""
import argparse
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter, LogLocator, NullFormatter  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
BASELINES = {"vitis_hls_2024": "Vitis HLS 2024",
             "vivado_hls_2019": "Vivado HLS 2019"}
LATENCY_COLUMNS = {"cycles": ("latency_cycles", "latency (cycles)"),
                   "wallclock": ("exec_time_ns", "wall-clock time")}

# Reference palette (dataviz skill): categorical slots 1-4 in fixed order, text
# and grid tokens. Each category also has its own marker, so identity never
# relies on color alone.
CATEGORIES = [  # (legend label, benchmarks, color, marker)
    ("Dynamatic, memory dependencies", {"matrix_power", "histogram"},
     "#2a78d6", "o"),
    ("Dynamatic, control dependencies", {"if_loop_add", "if_loop_mul"},
     "#eb6834", "D"),
    ("Dynamatic, speculative", {"newton_raphson", "backtrack", "subdiag"},
     "#1baf7a", "^"),
    ("Dynamatic, no dependencies", {"matvec", "fir"}, "#eda100", "v"),
]
OTHER = ("Dynamatic, other", "#e87ba4", "P")  # slot 5, unlisted benchmarks
# Benchmarks that are run but left out of the plots (still in summary.csv).
EXCLUDED = {"newton_raphson"}
REFERENCE = "#e34948"  # baseline marker (palette red)
SURFACE = "#fcfcfb"
TEXT_PRIMARY = "#0b0b0b"
TEXT_SECONDARY = "#52514e"
TEXT_MUTED = "#8a8984"
GRID = "#e4e3df"


def load(path):
    rows = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows[(r["bench"], r["tool"])] = r
    return rows


def dynamatic_commits(rows):
    return sorted({r["tool_version"] for (_, tool), r in rows.items()
                   if tool == "dynamatic" and r.get("tool_version")})


def ratios(rows, baseline, lat_col, res_col):
    points = []
    for bench in sorted({b for b, _ in rows} - EXCLUDED):
        dyn, base = rows.get((bench, "dynamatic")), rows.get((bench, baseline))
        if not dyn or not base:
            continue
        try:
            x = float(dyn[lat_col]) / float(base[lat_col])
            y = float(dyn[res_col]) / float(base[res_col])
        except (ValueError, ZeroDivisionError):
            print(f"skip {bench}: missing or zero {lat_col}/{res_col}")
            continue
        points.append((bench, x, y))
    return points


def fmt_ratio(v, _=None):
    return f"{v:g}×"


def plot(points, baseline_label, lat_label, res_col, out_base, dyn_label):
    fig, ax = plt.subplots(figsize=(6.4, 5.2), dpi=150)
    fig.patch.set_facecolor(SURFACE)
    ax.set_facecolor(SURFACE)
    ax.set_xscale("log")
    ax.set_yscale("log")

    xs = [p[1] for p in points] + [1.0]
    ys = [p[2] for p in points] + [1.0]
    # Symmetric-ish padding in log space so (1, 1) and every label fit.
    ax.set_xlim(min(xs) / 1.8, max(xs) * 2.2)
    ax.set_ylim(min(ys) / 1.8, max(ys) * 1.8)

    # Guides through the baseline point; recessive.
    ax.axvline(1, color=TEXT_MUTED, lw=1, ls=(0, (4, 3)), zorder=1)
    ax.axhline(1, color=TEXT_MUTED, lw=1, ls=(0, (4, 3)), zorder=1)
    ax.grid(True, which="major", color=GRID, lw=0.8, zorder=0)

    def category(bench):
        for label, benches, color, marker in CATEGORIES:
            if bench in benches:
                return label, color, marker
        return OTHER

    groups = [(label, color, marker) for label, _, color, marker in CATEGORIES]
    for label, color, marker in groups + [OTHER]:
        group = [p for p in points if category(p[0])[0] == label]
        if group:
            ax.scatter([p[1] for p in group], [p[2] for p in group], s=64,
                       marker=marker, color=color, edgecolor=SURFACE,
                       linewidth=2, zorder=3, label=label)
    ax.scatter([1], [1], s=70, marker="s", color=REFERENCE,
               edgecolor=SURFACE, linewidth=2, zorder=4,
               label=f"{baseline_label} (reference)")

    # Direct labels: right of the point by default; left when another point
    # sits where the label would go (or it would leave the axes); above when
    # both sides are taken.
    xmax = ax.get_xlim()[1]

    def neighbor(x, y, lo, hi):
        return any(lo < ox / x < hi and 1 / 1.15 < oy / y < 1.15
                   for _, ox, oy in points if (ox, oy) != (x, y))

    for bench, x, y in points:
        right_free = not neighbor(x, y, 1, 2.5) and x * 2.0 < xmax
        if right_free:
            offset, ha, va = (7, 0), "left", "center"
        elif not neighbor(x, y, 1 / 2.5, 1):
            offset, ha, va = (-7, 0), "right", "center"
        else:
            offset, ha, va = (0, 7), "center", "bottom"
        ax.annotate(bench, (x, y), xytext=offset, textcoords="offset points",
                    ha=ha, va=va, fontsize=8.5, color=TEXT_SECONDARY,
                    zorder=5)

    # Quadrant hint: lower-left is where Dynamatic wins on both axes.
    ax.text(0.02, 0.03, "← Dynamatic faster, smaller ↓", transform=ax.transAxes,
            fontsize=8, color=TEXT_MUTED, va="bottom", ha="left")

    for axis in (ax.xaxis, ax.yaxis):
        axis.set_major_locator(LogLocator(base=10, subs=(1.0, 2.0, 5.0)))
        axis.set_major_formatter(FuncFormatter(fmt_ratio))
        axis.set_minor_formatter(NullFormatter())
    ax.tick_params(colors=TEXT_SECONDARY, labelsize=8.5)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(TEXT_MUTED)

    ax.set_xlabel(f"Dynamatic {lat_label} / {baseline_label}",
                  color=TEXT_PRIMARY, fontsize=9.5)
    ax.set_ylabel(f"Dynamatic {res_col} / {baseline_label}",
                  color=TEXT_PRIMARY, fontsize=9.5)
    ax.set_title(f"{dyn_label} vs. {baseline_label}: {res_col} vs. {lat_label}",
                 color=TEXT_PRIMARY, fontsize=11, loc="left")
    # Below the axes so it never covers a point or label.
    leg = ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=2,
                    fontsize=8, frameon=False)
    for t in leg.get_texts():
        t.set_color(TEXT_SECONDARY)

    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(f"{out_base}.{ext}", facecolor=SURFACE)
    plt.close(fig)
    print(f"-> {out_base}.{{pdf,png}}")


def main():
    ap = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    ap.add_argument("--latency", choices=[*LATENCY_COLUMNS, "both"],
                    default="both")
    ap.add_argument("--resource", choices=["LUT", "FF", "DSP"], default="LUT")
    ap.add_argument("--summary", type=Path, default=REPO / "results/summary.csv")
    ap.add_argument("--out-dir", type=Path, default=REPO / "results/plots")
    args = ap.parse_args()

    rows = load(args.summary)
    commits = dynamatic_commits(rows)
    if len(commits) > 1:
        print(f"warning: results mix Dynamatic commits {', '.join(commits)}")
    dyn_label = (f"Dynamatic ({', '.join(commits)})" if commits
                 else "Dynamatic (commit unknown)")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    metrics = (list(LATENCY_COLUMNS) if args.latency == "both"
               else [args.latency])
    for metric in metrics:
        lat_col, lat_label = LATENCY_COLUMNS[metric]
        for tool, label in BASELINES.items():
            points = ratios(rows, tool, lat_col, args.resource)
            for bench, x, y in points:
                print(f"  {tool:16} {bench:15} {metric:9} {x:6.3f}x  "
                      f"{args.resource} {y:7.2f}x")
            out = args.out_dir / f"dynamatic_vs_{tool}_{args.resource}_{metric}"
            plot(points, label, lat_label, args.resource, out, dyn_label)


if __name__ == "__main__":
    main()
