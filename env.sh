# shellcheck shell=bash
# EDA tool locations on this machine. Sourced by config.sh; edit these when
# moving to another machine. Any variable can be overridden from the
# environment.
#
# This only exports install roots. Each run script puts the tools it needs on
# PATH, so different Xilinx versions never end up on the same PATH.

# Dynamatic (should have bin/, tools/, include/, integration-test/, ...)
: "${DYNAMATIC_PATH:=/data/dynamatic}"

# Vivado used by Dynamatic: `synthesize` runs $VIVADO_PATH/bin/vivado and
# `simulate` takes glbl.v from it (set-vivado-path). Same Vivado that
# Vitis HLS 2024.2 uses for export_design -flow impl.
: "${VIVADO_PATH:=/tools/Xilinx/Vivado/2024.2}"

# ModelSim/Questa for Dynamatic's `simulate --simulator vsim`
: "${MODELSIM_PATH:=/opt/intelFPGA/20.1/modelsim_ase}"

# HLS tools (their settings64.sh is sourced by the matching run script)
: "${VITIS_HLS_2024_PATH:=/tools/Xilinx/Vitis_HLS/2024.2}"
: "${VIVADO_HLS_2019_PATH:=/tools/Xilinx/Vivado/2019.1}"

export DYNAMATIC_PATH VIVADO_PATH MODELSIM_PATH VITIS_HLS_2024_PATH \
  VIVADO_HLS_2019_PATH
