#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ "${1:-}" == "--legacy" ]]; then
  shift
  exec ./launch-conquest-legacy.sh --district-maps "$@"
fi
exec ./launch-conquest.sh "$@"
