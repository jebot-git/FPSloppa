#!/usr/bin/env bash
set -euo pipefail
frontier_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$frontier_root/native_server/build/cq-server" --world "$frontier_root/native_server/cooked" --config "$frontier_root/native_server/server.cfg" --state "$frontier_root/native_server/state" "$@"
