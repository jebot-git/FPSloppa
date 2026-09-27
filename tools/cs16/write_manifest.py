"""Record provenance after model export and native Godot conversion."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
files = []
for folder, patterns in {
    "tools/cs16": ["model_weapons.py", "weapon_shapes.py", "refine_profiles.py", "surface_finish.py", "paint_finish.py", "import_models.gd", "build_pouch.py", "import_pouch.gd", "build_reload_sounds.py", "import_reload_sounds.gd"],
    "tools/cs16/refined": ["*.glb", "cs16_arsenal.blend", "m249_feed.blend", "cs16-finish*.png", "cs16-finish.kra"],
    "tools/cs16/pouch": ["magazine_pouch.blend", "magazine_pouch.glb"],
    "deathmatch/weapons/cs16": ["*.scn", "finish.res"],
    "deathmatch/counterstrike": ["feed_belt.gd"],
    "tools/cs16/reload_audio": ["*.wav"],
    "deathmatch/audio/cs16": ["*.res"],
}.items():
    for pattern in patterns:
        files.extend(sorted((ROOT / folder).glob(pattern)))
manifest = {
    "description": "Original Blender game geometry; original material atlas finished in Krita",
    "texture_author": "FPSloppa contributors",
    "texture_license": "CC0-1.0",
    "texture_source": "tools/cs16/refined/cs16-finish.kra",
    "files": [
        {"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "bytes": p.stat().st_size}
        for p in files
    ],
}
(ROOT / "deathmatch/weapons/cs16/sources.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Recorded {len(files)} asset/source hashes")
