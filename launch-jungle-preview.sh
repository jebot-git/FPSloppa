#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec "${GODOT_BIN:-godot}" --path . --xr-mode off --rendering-method forward_plus --rendering-driver vulkan tools/voxel_battle/jungle_preview.tscn "$@"
