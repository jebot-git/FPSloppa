# X-001 bomber

X-001 by **Karmabub**, [OpenGameArt source](https://opengameart.org/content/x-001), licensed **CC0**. Original attachment retained at `tools/airstrike/source/x-001.blend` (excluded from Godot import).

`tools/airstrike/export_bomber.py` exports an opaque 20 m span, -Z-forward GLB with vertex-painted metal/canopy/trim, one material, no textures, no lights, no collision and no runtime shadows. Decimation reduces 11,988 source triangles to **1,438** (88% reduction). Godot generates additional mesh LODs on import; the aircraft uses shared frustum/range culling at 1,600 m.

Rebuild from repository root:

```sh
blender -b --factory-startup tools/airstrike/source/x-001.blend --python tools/airstrike/export_bomber.py
```

Payload bomblets are bounded collision-free procedural visuals. Server impacts use downward traces and the existing rocket splash/LOS logic; they do not create projectile rigid bodies.
