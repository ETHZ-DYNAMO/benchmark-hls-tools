#!/bin/bash
# Usage: scripts/run_all.sh [-t tool[,tool...]] [-j jobs] [bench...]
#   tools: dynamatic, vitis_hls_2024, vivado_hls_2019 (default: all)
#   bench: names under benchmarks/ (default: all)
#   jobs:  number of runs in parallel (default: 1)
# Each run is capped at RUN_TIMEOUT seconds and RUN_MEM_MAX memory (config.sh).
# Logs go to results/logs/<tool>/<bench>.log, exit codes to <bench>.status.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

TOOLS="dynamatic,vitis_hls_2024,vivado_hls_2019"
JOBS=1
while getopts "t:j:" opt; do
  case $opt in
    t) TOOLS="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    *) sed -n 2,8p "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
  BENCHES=("$@")
else
  mapfile -t BENCHES < <(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi

run_one() {
  local tool="$1" bench="$2"
  local log_dir="$REPO_ROOT/results/logs/$tool"
  mkdir -p "$log_dir"
  echo "[$(date +%T)] start  $tool $bench"
  systemd-run --user --scope -q -p MemoryMax="$RUN_MEM_MAX" \
    timeout "$RUN_TIMEOUT" bash "$SCRIPT_DIR/run_$tool.sh" "$bench" \
    > "$log_dir/$bench.log" 2>&1
  local rc=$?
  echo "$rc" > "$log_dir/$bench.status"
  echo "[$(date +%T)] done   $tool $bench (exit $rc$([ $rc -eq 124 ] && echo ', timeout'))"
}
export -f run_one
export SCRIPT_DIR RUN_MEM_MAX RUN_TIMEOUT

for tool in ${TOOLS//,/ }; do
  [ -f "$SCRIPT_DIR/run_$tool.sh" ] || { echo "Unknown tool: $tool" >&2; exit 1; }
  for bench in "${BENCHES[@]}"; do
    printf '%s\0%s\0' "$tool" "$bench"
  done
done | xargs -0 -n 2 -P "$JOBS" bash -c 'run_one "$@"' _

python3 "$SCRIPT_DIR/collect_results.py"
