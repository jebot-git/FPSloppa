Futuristic Hover Tanks by KillGorack, CC0.
https://opengameart.org/content/futuristic-hover-tanks

lightning.blend is light; aegis2.blend (source Medium Class) is used for heavy.
Original camouflage/metal/stripe colours baked to a single 512 atlas per tank.
Three meshes separate hull, yaw-only turret and pitch-limited barrels.
Showcase floor, HDRI, lights, normals and glass omitted. Godot generates mesh LODs; runtime uses the shared baked lighting, distance and frustum culling.
Rebuild: Blender -b --factory-startup --python tools/hover_tanks/export_tanks.py
