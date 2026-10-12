#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
godot_bin="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.7.2-stable_linux.x86_64}"
mode_args=(--interactive)
if [[ "${1:-}" == "--benchmark" ]]; then
  mode_args=()
  shift
fi
exec "$godot_bin" --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --script tools/voxelspace/optimization.gd -- "${mode_args[@]}" "$@"
