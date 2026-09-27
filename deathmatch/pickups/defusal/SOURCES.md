# Original DE objective assets

`bomb_chassis.glb` and `cutters.glb` were authored for FPSloppa in Blender 5.2
through Blender MCP. Original geometry and untextured PBR materials; no external
models, photographs, CS/Pavlov assets or third-party material libraries.

Editable source: `tools/defusal/defusal_props.blend`.
Rebuild script: `tools/defusal/build_assets.py` (`build()`, `export_assets()`).
The GLBs export only the named prop from the active workshop scene, in metres.
The bomb has six material surfaces, the cutter four. Chassis key centers and
wire collars follow `deathmatch/counterstrike/bomb_interaction.gd`.

Godot adds the display/digit labels, status lamp, three removable wire loops and
a synthesized short beep. Original shop SVGs are `deathmatch/ui/weapon_icons/de_*.svg`.
These original assets use the same project terms as FPSloppa's authored code.
