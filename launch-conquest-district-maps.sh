#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
engine="${GODOT_BIN:-godot}"
if [[ "${1:-}" == "--server" ]]; then
  shift
  exec "$engine" --headless --xr-mode off --path . -- --experimental-cq --cq-district-maps --server --config "$PWD/conquest-district-maps.cfg" "$@"
else
  address="${1:-127.0.0.1}"
  if (( $# )); then shift; fi
  exec "$engine" --rendering-method mobile --rendering-driver vulkan --path . -- --experimental-cq --cq-district-maps --connect "$address" --port 7787 "$@"
fi
