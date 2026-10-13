#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
godot_bin="${GODOT_BIN:-godot}"
engine_args=(--rendering-method forward_plus --rendering-driver vulkan)
if [[ "${1:-}" == "--headless" ]]; then engine_args=(--headless); shift; fi
exec "$godot_bin" --path . --xr-mode off "${engine_args[@]}" --script tools/voxel_battle/run.gd -- "$@"
