# Futuristic Grenade

**mrpoly**, [Futuristic Grenade on OpenGameArt](https://opengameart.org/content/futuristic-grenade), **CC0**. Original attachment retained as `tools/healing_grenade/source/futuregrenade.blend`, excluded from Godot import.

`tools/healing_grenade/export_grenade.py` selects the finished mesh (rather than the source cage), collapses 2,754 triangles to **1,000**, centers it at **18 cm height**, and assigns one opaque vertex-painted medical shell material. No textures, runtime lights, collision or shadows are exported. It copies the result into the active scene collection because the legacy source's detailed object belongs to a hidden collection. Godot generates mesh LODs. Runtime enables vertex colour before conversion to the baked jungle lighting shader.

```sh
blender -b --factory-startup tools/healing_grenade/source/futuregrenade.blend --python tools/healing_grenade/export_grenade.py
```
