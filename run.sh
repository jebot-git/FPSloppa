#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Normal play uses the verified patched runtime when built. Editor/script tools
# and an explicit GODOT_BIN retain the existing development entry point.
use_client=true
for arg in "$@"; do
    case "$arg" in
        --editor|-e|--project-manager|-p|--script|-s|--check-only|--headless|--path|--import|--export-*|--doctool|--dump-*|--build-solutions) use_client=false ;;
    esac
done
if [[ -z "${GODOT_BIN:-}" && "$use_client" == true && "$(uname -s)" == Linux && -x "$project_dir/Builds/ClientTemplates/linux.x86_64" ]]; then
    exec python3 "$project_dir/tools/run_client.py" "$@"
fi
godot_bin="${GODOT_BIN:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    if command -v godot4 >/dev/null 2>&1; then
        godot_bin=godot4
    elif [[ -x /home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64 ]]; then
        godot_bin=/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64
    else
        echo "Install Godot 4.7 or set GODOT_BIN to the Godot executable."
        exit 1
    fi
fi
exec "$godot_bin" --path "$project_dir" "$@"
