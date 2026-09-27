# CS arsenal authoring

1. Run `model_weapons.py` in Blender. Through Blender MCP, execute the file with
   `__file__` set to its absolute path and `__name__` set to `__main__`. For a
   separate batch process:

   ```sh
   blender --background --factory-startup --disable-autoexec --python tools/cs16/model_weapons.py
   ```

   Only the `CS16_Workbench` collection is replaced. Other scene objects are
   hidden, not deleted. The script writes twelve GLBs, an editable `.blend` and
   `mesh-report.json` under `refined/`. Original geometry is in `weapon_shapes.py`;
   P90 geometry and shared extrusion/UV/export helpers are in `model_weapons.py`.
   `refine_profiles.py` trims the bulky receiver, stock and fore-end envelopes
   without moving sights, magazines, controls or palm anchors.

   `surface_finish.py` creates the original padded 1024×512 base atlas. The
   editable painted finish is `refined/cs16-finish.kra`; save a flattened copy as
   `cs16-finish-painted.png` before rebuilding. Blender prefers this painted
   export and packs it into the workbench and GLBs. To recreate the wear layers,
   launch Krita with its MCP bridge and run `python3 tools/cs16/paint_finish.py`
   (optional `--server /path/to/mcp_server.py`), then rebuild the models. This
   recreates the KRA, so save any manual texture edits separately first.

2. Convert to compact native Godot scenes:

   ```sh
   godot --headless --xr-mode off --path . --script tools/cs16/import_models.gd
   ```

   This writes `deathmatch/weapons/cs16/*.scn` and one shared `finish.res` texture.
   `refined/.gdignore` prevents duplicate source imports. No full editor/BSP
   reimport is needed. To import only the M249, append `-- m249`. The editable
   `refined/m249_feed.blend` contains its separated box, belt and cover; a full
   `model_weapons.py` rebuild also reproduces these parts.

3. Run `deathmatch/tests/cs16_art.gd` and `cs16_sights.gd` with the same headless
   command. Native renderer checks use `preview.gd` (arsenal),
   `inspect_models.gd` (left/right/sight/open-action cards), and `game_preview.gd`
   (Host menu and all weapons on Dust2). For example:

   ```sh
   godot --display-driver x11 --rendering-method mobile --audio-driver Dummy --xr-mode off --path . --script tools/cs16/inspect_models.gd
   ```

   Output goes to `test-results/cs16/`. Run the combat, bot and wheel scripts
   headlessly; `python3 tools/cs16/run_network.py` runs the server/client ENet
   scenario on local UDP port 28978. Give test processes separate temporary
   XDG config/data directories so they do not change the user's saved settings.

   `cs16_vr_reload.gd` checks server-side controller gestures and interruptions.
   `cs16_reload_ui.gd` checks the real VR rig with simulated controllers; run
   with native rendering and `-- --render` to write pouch, magazine, slide,
   pump, feed-cover and attached-belt captures to `test-results/cs16/reload/`.

`cs16_actions.gd` covers the CS-specific gesture states. `preview_actions.gd`
renders separate AWP bolt stages, the MP5 locking notch and M249 held belt.
Run it with the same native-renderer command; its output directory is
`test-results/cs16/actions/`.

Sight landmarks are exported alongside the actual geometry; pistol sights move
with their slides where appropriate. Runtime action transforms and palm anchors
are in `deathmatch/counterstrike/`. The AWP preserves the existing sniper scope
metadata. Changes to that geometry must keep its ocular/objective metadata in
sync and pass the scope and wall-occlusion checks.

Magazines are separate exported meshes, including full internal pistol magazines.
The M249 feed cover includes its rear sight and rotates around a front hinge;
its box and static cartridge belt are separate parts. Physical VR reloads hide
the static belt and use `feed_belt.gd` to connect the box to the held leader
with two instanced meshes. Both use the shared mipmapped finish. Detached
ammunition boxes retain their static belt. `reload_state.gd` defines grip/socket
landmarks in the same model coordinates. Keep these landmarks aligned when
changing geometry. VR action progress comes from the authoritative hand sampler;
desktop and bot actions retain timed animation.

After a rebuild, run `python3 tools/cs16/write_manifest.py` to regenerate
`deathmatch/weapons/cs16/sources.json` hashes for the scripts, layered textures, GLBs,
native scenes and shared texture. See
the runtime [credits](../../deathmatch/weapons/cs16/CREDITS.md) and
[loadout documentation](../../docs/CS16-LOADOUT.md) for provenance and adaptations.

Reload and defusal Foley (including the tweezer snip) is synthesized from original code in `build_reload_sounds.py`. Run
it with Python, then `godot --headless --xr-mode off --path . --script
tools/cs16/import_reload_sounds.gd` to convert the source WAVs into six compressed
native streams under `deathmatch/audio/cs16/`. Sources are CC0; no external
recordings are used.
