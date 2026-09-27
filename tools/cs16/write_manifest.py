"""Record provenance after model export and native Godot conversion."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
files = [ROOT / "deathmatch/weapons/afps_2.glb"]
for folder, patterns in {
    "tools/cs16": ["model_weapons.py", "weapon_shapes.py", "import_models.gd", "build_pouch.py", "import_pouch.gd"],
    "tools/cs16/refined": ["*.glb", "cs16_arsenal.blend", "afps-metal-donor.png"],
    "tools/cs16/pouch": ["magazine_pouch.blend", "magazine_pouch.glb"],
    "deathmatch/weapons/cs16": ["*.scn", "finish.res"],
}.items():
    for pattern in patterns:
        files.extend(sorted((ROOT / folder).glob(pattern)))
manifest = {
    "description": "Original Blender game geometry; shared CC0 AFPS metal finish",
    "texture_author": "Drummyfish / tastyfish",
    "texture_license": "CC0-1.0",
    "texture_source": "https://opengameart.org/content/oldschool-afps-weapons",
    "files": [
        {"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "bytes": p.stat().st_size}
        for p in files
    ],
}
(ROOT / "deathmatch/weapons/cs16/sources.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Recorded {len(files)} asset/source hashes")
