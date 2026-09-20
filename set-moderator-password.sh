#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export PYTHONPATH="$root${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m tools.district_cluster.set_moderator_password "$@"
