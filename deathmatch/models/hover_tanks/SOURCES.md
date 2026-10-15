Futuristic Hover Tanks by KillGorack, CC0.
https://opengameart.org/content/futuristic-hover-tanks

lightning.blend is light; aegis2.blend (source Medium Class) is used for heavy.
Original camouflage/metal/stripe colours baked to a single 512 atlas per tank.
Three meshes separate hull, yaw-only turret and pitch-limited barrels.
Showcase floor, HDRI, lights, normals and glass omitted. Godot generates mesh LODs; runtime uses the shared baked lighting, distance and frustum culling.
Rebuild: Blender -b --factory-startup --python tools/hover_tanks/export_tanks.py

2026-10-15 pivot correction: removed a residual source-object translation from the light tank Hull/Turret/Barrel nodes. Vertex coordinates, atlas, mesh count and triangle counts are unchanged. The exporter now clears the joined object transform and uses identity mesh-local transforms below the yaw/pitch pivots, preventing an offset from being rotated around those axes.
