#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Source-tree experimental launcher. Engine and assets must be installed.
engine="${GODOT_BIN:-godot}"
if [[ "${1:-}" == "--server" ]]; then
  shift
  exec "$engine" --headless --xr-mode off --path . -- --experimental-cq --server --config "$PWD/conquest.cfg" "$@"
else
  address="${1:-127.0.0.1}"
  if (( $# )); then shift; fi
  exec "$engine" --path . -- --experimental-cq --connect "$address" --port 7787 "$@"
fi
