#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
case "${1:-}" in
  --server)
    shift
    exec python3 -m tools.district_cluster.local "$@"
    ;;
  --help|-h)
    echo 'CQ: 81 districts, 128 players total, 16 per district.'
    echo 'Server: ./launch-conquest.sh --server [--state-dir PATH] [--districts d13 d40]'
    echo 'Client: ./launch-conquest.sh [private-client.json]'
    ;;
  *)
    if (( $# == 0 )); then set -- "$PWD/test-results/cq-campaign/client.json"; fi
    exec ./start-campaign-client.sh "$@"
    ;;
esac
