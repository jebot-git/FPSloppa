#!/usr/bin/env bash
set -euo pipefail
frontier_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "${GODOT_BIN:-godot}" --headless --xr-mode off --path "$frontier_root" res://tools/voxel_battle/class_arena.tscn -- --server --config res://tools/voxel_battle/cq_classes.cfg "$@"
