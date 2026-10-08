"""File ownership and release identity for transactional launcher updates."""
import hashlib
import json
import subprocess
from pathlib import Path

NAME = 'INSTALL-MANIFEST.json'


def write_manifest(root: Path, destination: Path, selected: set[str], platform: str):
    rows = []
    for name in sorted(selected - {NAME}):
        path = destination / name
        if path.is_symlink():
            raise ValueError(f'Package entry must be a regular file: {name}')
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        rows.append(dict(path=name, bytes=path.stat().st_size, sha256=digest,
                         mode=0o755 if path.stat().st_mode & 0o111 else 0o644))
    data = dict(schema=1, repository='jebot-git/FPSloppa',
                version=(root / 'VERSION').read_text().strip(), platform=platform,
                commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                files=rows)
    (destination / NAME).write_text(json.dumps(data, indent=2)+'\n')
    selected.add(NAME)
    return data


def write_wrapper(destination: Path, platform: str):
    """Recovery is runnable even if a crash interrupted replacing the main exe."""
    if platform == 'Linux':
        name = 'Launch-FPSloppa.sh'
        body = '''#!/usr/bin/env sh
cd -- "$(dirname -- "$0")" || exit 1
if [ -f .launcher-update/pending.json ]; then
    exec ./.launcher-update/runner/FPSloppa.x86_64 --xr-mode off -- --launcher-install --install-job "$PWD/.launcher-update/pending.json"
fi
exec ./FPSloppa.x86_64 --xr-mode off -- --launcher "$@"
'''
    else:
        name = 'Launch-FPSloppa.bat'
        body = '''@echo off
if exist "%~dp0.launcher-update\\pending.json" (
    "%~dp0.launcher-update\\runner\\FPSloppa.exe" --xr-mode off -- --launcher-install --install-job "%~dp0.launcher-update\\pending.json"
    exit /b
)
"%~dp0FPSloppa.exe" --xr-mode off -- --launcher %*
'''
    target = destination / name
    target.write_bytes(body.replace('\n', '\r\n').encode() if platform == 'Windows' else body.encode())
    if platform == 'Linux':
        target.chmod(0o755)
    return name
