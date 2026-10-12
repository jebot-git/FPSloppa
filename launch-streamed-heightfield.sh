#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
godot_bin="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.7.2-stable_linux.x86_64}"
mode_args=(--interactive)
if [[ "${1:-}" == "--benchmark" || "${1:-}" == "--smoke" || "${1:-}" == "--paced" || "${1:-}" == "--static" || "${1:-}" == "--cold" || "${1:-}" == "--gpu-shader" ]]; then
  mode_args=()
  if [[ "$1" == "--smoke" ]]; then mode_args=(--smoke); fi
  if [[ "$1" == "--paced" ]]; then mode_args=(--paced); fi
  if [[ "$1" == "--static" ]]; then mode_args=(--static); fi
  if [[ "$1" == "--cold" ]]; then mode_args=(--cold); fi
  if [[ "$1" == "--gpu-shader" ]]; then mode_args=(--gpu-shader); fi
  shift
fi
exec "$godot_bin" --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --script tools/streamed_heightfield/run.gd -- "${mode_args[@]}" "$@"
