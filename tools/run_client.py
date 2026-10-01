#!/usr/bin/env python3
"""Run source assets beside the project's verified Linux release runtime."""
import os
from pathlib import Path
import shutil
import sys
import tempfile

from renderer_policy import require_client_template

ROOT = Path(__file__).resolve().parents[1]


def main():
    template = require_client_template('linuxbsd')
    folder = ROOT / 'Builds/LocalClient'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / '.gdignore').touch()
    # Production templates load their adjacent project, not a --path override.
    # Keep the assets live while avoiding copies of build output and private data.
    for source in ROOT.iterdir():
        if source.name in ('Builds', 'test-results') or (source.name.startswith('.') and source.name != '.godot'):
            continue
        dest = folder / source.name
        if not dest.exists() and not dest.is_symlink():
            dest.symlink_to(source, target_is_directory=source.is_dir())
    binary = folder / 'FPSloppa'
    if not binary.exists() or binary.stat().st_mtime_ns != template.stat().st_mtime_ns or binary.stat().st_size != template.stat().st_size:
        with tempfile.TemporaryDirectory(dir=folder) as temp:
            staged = Path(temp) / 'FPSloppa'
            shutil.copy2(template, staged)
            os.replace(staged, binary)
    os.execv(binary, [str(binary), *sys.argv[1:]])


if __name__ == '__main__':
    main()
