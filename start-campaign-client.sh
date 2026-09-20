#!/usr/bin/env bash
set -euo pipefail
campaign_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $# != 1 ]]; then
  echo 'Usage: ./start-campaign-client.sh /path/to/private-client.json' >&2
  exit 2
fi
exec godot --path "$campaign_root" --xr-mode off --rendering-method mobile --rendering-driver vulkan --script tools/district_cluster/desktop.gd -- "$1"
