# Autonomous turret model

**PolygonDan**, [3D Turret PBR texture + Flat Diff Texture](https://opengameart.org/content/3d-turret-pbr-texture-flat-diff-texture), **CC0**. The archive includes the author's license note and original OBJ/FBX plus 2048² PBR and flat diffuse maps. Original archive is retained at `tools/turret/source/Turret_final_PolygonDan.zip`, excluded from Godot import.

`tools/turret/export_turret.py` extracts the OBJ in a temporary directory and simplifies **2,400 → 1,440 triangles**. It exports a **1.4 m tall** turret with its source base centered at ground origin, barrel facing Godot -Z, and an independent `Aim` gun pivot at 1.15 m. Feet/base remain static while the gun rotates and elevates. The two mesh parts share one opaque material and one **512² diffuse atlas**; PBR normal/roughness/metalness maps are omitted. Godot generates mesh LODs. Runtime uses the existing baked jungle shader, no dynamic lights or runtime shadows, shared aircraft geometry range/frustum policy, and a separate simple authoritative stationary collider.

```sh
blender -b --factory-startup --python tools/turret/export_turret.py
```

The GLB embeds its texture; Godot extracts `turret_diffuse.png`. Retain its import policy for mipmaps and compression. The source atlas is 2048²; the output has 1/16 as many texels.
