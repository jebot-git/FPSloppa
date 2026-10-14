#!/usr/bin/env python3
"""Enable missing texture mipmaps in existing Godot import sidecars.

project.godot supplies the default for textures imported without a sidecar.
Run before Godot --editor --import to refresh an existing checkout.
"""
from pathlib import Path
from collections import Counter
import json

root = Path(__file__).resolve().parents[2]
changed = Counter()
for path in root.rglob('*.import'):
    if '.godot' in path.relative_to(root).parts:
        continue
    content = path.read_text()
    if 'importer="texture"' not in content or 'mipmaps/generate=false' not in content:
        continue
    path.write_text(content.replace('mipmaps/generate=false', 'mipmaps/generate=true'))
    changed[path.relative_to(root).parts[0]] += 1
print(json.dumps({'enabled': sum(changed.values()), 'by_directory': dict(changed)}))
