#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Explicit legacy 16-district experiment; default CQ uses the campaign cluster.
legacy_flags=()
legacy_config=conquest.cfg
if [[ "${1:-}" == "--district-maps" ]]; then
  shift
  legacy_flags=(--cq-district-maps)
  legacy_config=conquest-district-maps.cfg
fi
engine="${GODOT_BIN:-godot}"
if [[ "${1:-}" == "--server" ]]; then
  shift
  exec "$engine" --headless --xr-mode off --path . -- --experimental-cq "${legacy_flags[@]}" --server --config "$PWD/$legacy_config" "$@"
else
  address="${1:-127.0.0.1}"
  if (( $# )); then shift; fi
  exec "$engine" --rendering-method mobile --rendering-driver vulkan --path . -- --experimental-cq "${legacy_flags[@]}" --connect "$address" --port 7787 "$@"
fi
