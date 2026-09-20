#!/usr/bin/env bash
set -euo pipefail
campaign_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $# != 1 ]]; then
  echo 'Usage: ./start-campaign-client.sh /path/to/private-client.json' >&2
  exit 2
fi
if [[ ! -f "$1" ]]; then
  echo "CQ client configuration missing: $1. Start ./launch-conquest.sh --server or generate a client-config for the remote cluster." >&2
  exit 2
fi
exec "${GODOT_BIN:-godot}" --path "$campaign_root" --xr-mode off --rendering-method mobile --rendering-driver vulkan --script tools/district_cluster/desktop.gd -- "$1"
