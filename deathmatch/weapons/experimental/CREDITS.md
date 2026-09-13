# Experimental weapon models

- **Stylized Woodcutting Axe**, Price: [OpenGameArt](https://opengameart.org/content/stylized-woodcutting-axe), CC0 1.0. 266 triangles. Original 1024px diffuse and UVs retained, with mipmaps. Grip centered and cutting edge oriented forward.
- **Flamethrower**, TheJosh: [OpenGameArt](https://opengameart.org/content/flamethrower-0), CC0 1.0. 2,932 triangles. Original mesh and UVs, with baked diffuse reduced to 1024px and mipmapped. TF Pyro only; grip and muzzle aligned for desktop and either VR gun hand.
- **Low Poly Stylized Sniper**, FFMStudios / Fernando Ferreira (zisongbr): [OpenGameArt](https://opengameart.org/content/low-poly-stylized-sniper), CC0 1.0. 890 triangles, from a 910-triangle source. Original olive palette, body and hollow scope retained; opaque lens caps replaced by the runtime VR optic. Used for UT99 and TF Sniper.
- **Gatling/Mini Gun**, Tech Knight: [OpenGameArt](https://opengameart.org/content/gatlingmini-gun), CC0 1.0. 2,198 triangles. Original metal colours and mesh retained, with barrel axis aligned to the sentry aiming pivot. TF and Assault turrets only.
- **Impact hammer**, adapted from **Oldschool AFPS Weapons** by Drummyfish / tastyfish: [OpenGameArt](https://opengameart.org/content/oldschool-afps-weapons), CC0 1.0. Uses the existing textured chainsaw receiver with a new pneumatic ram, impact plate and pistol grip. The blade is removed and the cut is closed.
- Barrel collars and hollow scope housing are original project geometry, built with bevelled, stepped profiles in Blender.

JamesWhite’s CC0 [Axe](https://opengameart.org/content/axe-0) was previously used; its source is retained under `tools/weapon_sources/oga/axe/`, but the current axe uses Price’s model above.

Jerd's CC0 [Power Hammer](https://opengameart.org/content/power-hammer) was evaluated; its original OBJ remains under `tools/weapon_sources/oga/` for provenance, but the current in-game hammer uses the chainsaw derivative above.

Source/output hashes and detailed modifications are in `sources.json`. Source OBJ/GLB/Blender files and tools are excluded from client/server exports. No proprietary Quake/UT model data is used.

Rebuild the axe GLB with Blender’s `--background --disable-autoexec --python tools/weapon_sources/woodcutting_axe_blender.py`, and the flamethrower with `tools/weapon_sources/flamethrower_blender.py`. Both scripts open the supplied source blend without executing embedded scripts. They preserve the original source files.
For the fittings, run `tools/weapon_sources/refine_blender.py` in an empty Blender session, then run `tools/weapon_sources/chainsaw_hammer_blender.py` to build the current hammer. These scripts replace the working Blender scene. Import the resulting GLBs using `godot --headless --xr-mode off --path . --script res://tools/weapon_sources/import_refined.gd`. Editable `.blend` sources are in `tools/weapon_sources/refined/`.

Import all current exports with `godot --headless --xr-mode off --path . --script res://tools/weapon_sources/build.gd`, or pass names after `--` to `import_refined.gd` to rebuild only selected scenes. Importing generates texture mipmaps and preserves axe alignment metadata.

Rebuild the sniper and turret GLBs using `tools/weapon_sources/sniper_turret_blender.py` with Blender `--background --disable-autoexec`, then import `-- sniper sentry_gatling` with `import_refined.gd`. The converter opens both legacy blends with embedded scripts disabled and preserves the original archive, blend files and palette.
