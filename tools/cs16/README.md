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

2. Convert to compact native Godot scenes:

   ```sh
   godot --headless --xr-mode off --path . --script tools/cs16/import_models.gd
   ```

   This writes `deathmatch/weapons/cs16/*.scn` and one shared `finish.res` texture.
   `refined/.gdignore` prevents duplicate source imports. No full editor/BSP
   reimport is needed.

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
   pump and feed-cover captures to `test-results/cs16/reload/`.

Sight landmarks are exported alongside the actual geometry; pistol sights move
with their slides where appropriate. Runtime action transforms and palm anchors
are in `deathmatch/counterstrike/`. The AWP preserves the existing sniper scope
metadata. Changes to that geometry must keep its ocular/objective metadata in
sync and pass the scope and wall-occlusion checks.

Magazines are separate exported meshes, including full internal pistol magazines.
The M249 feed cover includes its rear sight and rotates around a front hinge;
its box has a connected cartridge belt. `reload_state.gd` defines grip/socket
landmarks in the same model coordinates. Keep these landmarks aligned when
changing geometry. VR action progress comes from the authoritative hand sampler;
desktop and bot actions retain timed animation.

After a rebuild, run `python3 tools/cs16/write_manifest.py` to regenerate
`deathmatch/weapons/cs16/sources.json` hashes for the donor, scripts, GLBs,
native scenes and shared texture. See
the runtime [credits](../../deathmatch/weapons/cs16/CREDITS.md) and
[loadout documentation](../../docs/CS16-LOADOUT.md) for provenance and adaptations.
