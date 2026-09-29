# ST inventory and remote views in VR

29 September 2026, experimental Raindance branch only.

Inventory purchases, refits, repair kits and field actions keep the inventory
wheel open. Only **Carried Weapons** switches it to the weapon wheel. Camera and
base-turret selections close the wheel and hand control to the remote view.
The VR Use binding closes either remote view without also activating a pack.
Turret aiming uses the dominant controller's aim pose, with firing suppressed
while menus, tracking loss or headset focus prevent interaction.

Vehicle, command and portable-inventory terminals remain accessible while menu
input blocks firing. Vehicle purchases use ordinary station, power, proximity,
team-energy, limit and spawn-clearance checks. Portable inventory keeps its local
reserve and armour restrictions. It no longer falls back to team energy when the
wheel opens. Repair-kit menu requests retain server-side life and eligibility
checks. Disabled menu entries keep the current page instead of closing it.

Refit snapshots reset physical weapon state while preserving a living player's
inventory page; deaths and normal respawns still dismiss it. Automatic station
opening respects the current joystick deflection and requires recentering before
selection.

24 original SVG pictograms cover inventory actions, remote-view controls and the
five fixed-turret types. Existing ST weapon, armour, backpack and deployable icon
mappings have been restored; they previously fell through to the pistol icon.
Purchase and beacon labels remain visible beneath their icons. The native
textures are compressed and include mipmaps.

Regenerate new artwork:

```sh
python3 tools/tribes/menu_icons.py
godot --headless --xr-mode off --path . --script res://tools/tribes/import_menu_icons.gd
```

Focused regression:

```sh
godot --xr-mode off --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --path . --script res://deathmatch/tests/st_vr_inventory.gd -- --vr-test --no-bots
```

This drives the real VR wheel with simulated controllers on Raindance, checks the
production input and snapshot paths, and exercises inventory, vehicle, portable
inventory and command terminals. A borrowed station fixture covers the command
terminal because Raindance does not contain one. It also verifies all menu-icon
mappings/mipmaps and renders menu previews. Human headset interaction remains the
next usability check; simulated inputs do not establish hand comfort or readability
at every headset resolution.

Evidence and known harness limitations are recorded in
[the validation receipt](validation/st-vr-inventory-2026-09-29.json).

Held deployable packs now accept **Use** as well as the offhand trigger. Both use
the validated offhand pose and the same placement preview. Failed placement keeps
the pack held and permits a fresh press to retry; success consumes it once. Use
without a held pack retains the existing weapon-aim deployment fallback. Closing
a remote view retains priority over deploying a pack.

`deathmatch/tests/st_vr_deploy_use.gd` checks chest grabs, Use/trigger equivalence,
both dominant hands, rebound Use, failed placement/retry, preview agreement and
single-use consumption (43 checks). Receipt:
[ST VR deploy Use](validation/st-vr-deploy-use-2026-09-29.json).

## Held deployable pointing correction

Held packs, the placement ghost and the authoritative deployment ray now use the
validated offhand **aim** orientation at the grip/palm position. OpenXR grip axes
can point upward when the controller aim points forward; using the grip basis
caused both the pack and placement direction to tilt incorrectly. Chest mounts,
throw/reach positions and older recordings without an aim pose retain their
existing transforms. The Use/trigger tests now deliberately separate grip, aim
and gun directions, and check the displayed model, ghost and deployed position
for both dominant hands (57 checks).
