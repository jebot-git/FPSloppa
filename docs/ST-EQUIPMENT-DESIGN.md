# ST stations, turrets and field equipment redesign

Implemented in `experimental/st-raindance`, 29 September 2026. ST remains
excluded from the current release. This extends the [vehicle artwork pass](ST-VEHICLES.md).

The equipment uses independently modeled forms based on the original manual
and gameplay screenshots, with the same bronze/gunmetal panels, cyan status
lights and red/blue team accents as the vehicles. These are approximations
adapted to the working game's interaction points and solid cover dimensions.

| Family | Revised art |
| --- | --- |
| Fixed stations | Inventory, ammo, command and vehicle terminals: split pylons, central service capsules and role-specific fittings. Stonehenge's existing station backing has matching cladding. |
| Fixed turrets | Fusion, mini-fusion, ELF, missile and mortar: distinct heads, armoured bases, yokes, launch tubes, induction coils and bored barrels. |
| Deployables | Remote turret, inventory, ammo, pulse sensor, motion sensor, jammer and camera: compact stake bases and distinct sensor/weapon/service heads. |
| Base equipment | Generator, portable generator, solar panel, fixed pulse sensor and large pulse sensor. |
| Field marker | Target beacon with armoured capsule and signal panel. |

There are **22 equipment models plus one station-cladding helper**, and seven
matching deployable purchase icons. The existing deployed models also supply
the carried backpack artwork. Body and moving head now receive the same packed
offset, so the head cannot separate when carried. Placement ghosts apply their
translucent material recursively, including nested moving heads. Disabled
stations, turrets and deployables dim their lamps and team panels independently
of neighbouring instances.

The models use one or two meshes each, at most seven material surfaces, and a
single shared 1024×1024 mipmapped atlas. The 23 native scenes and shared texture
occupy about 1.5 MiB. No bones, spring simulation or dynamic lights were added.
The five fixed turret head pivots now line up with the existing authoritative
eye positions; the remote turret's visible barrel height matches its 1.2 m
launch axis. Camera pivot and lens remain clear for the remote video feed.

Station service areas, purchase logic, firing/aiming, deployment limits,
health/power rules, replication and tracked grab controls are retained. Labels
were raised above the consoles. Existing BSP solids and map files are unchanged.
Stonehenge's larger sensor housings wrap its existing BSP plinths and beams,
which limits how closely their silhouettes can match the originals.

Map inspection exposed two equipment alignment issues, corrected here:

- Distant vehicle terminals were included when calculating a base generator's
  facing, rotating Raindance's generator across its BSP housing. The frame now
  follows local inventory/ammo stations; damage traces hit the physical front.
- Raindance's fixed sensors lacked solid native fixtures. Their new 60% scale
  housings have matching collision and damage geometry. The compact footprint
  preserves all original roof spawns; Stonehenge keeps its existing BSP size.

The retained CC0 source parts, original artwork and reference provenance are
listed in [asset credits](../deathmatch/tribes/props/CREDITS.md). No retail mesh
or texture data is shipped. Personal weapons, personal pack controls and
recovery cases were outside this infrastructure-art pass.

## Rebuild and review

1. Ensure the vehicle atlas PNG exists; `vehicle_texture.py` and
   `vehicle_texture.gd` regenerate it if needed.
2. Execute `tools/tribes/prop_models.py` in Blender MCP. Set `PROP_PROJECT` to
   another checkout when needed. It loads the retained CC0 source parts through
   `prop_sources.py` without replacing unrelated Blender objects.
3. Run `godot --headless --xr-mode off --path . --script tools/tribes/import_props.gd`.
4. Run `python3 tools/tribes/prop_icons.py`, then `import_icons.gd` for the seven
   `tribes_remote_*`, `tribes_pulse_sensor` and `tribes_motion_sensor` icons.
5. `props_preview.gd` renders the equipment families, details, offline state and
   icons. `props_live_preview.gd` reviews their actual placement on both maps.
   Use Vulkan with `--xr-mode off --audio-driver Dummy`.

## Validation

**456 checks passed**: base assets 77, fixed-defence/offence parity 94, field
systems parity 77, deployables 55, Vulkan deployable UI 34, native equipment and
map mounts 112, and recorded Raindance obstacle cases 7. The new mount suite
checks all 32 original spawn capsules, station approach areas, damageable sensor
housings, generator alignment, native texture mipmaps, batching, independent
power states and moving-head attachment. Two old compatibility test fixtures
were updated to remove the subsequently added `vehicles` field when constructing
pre-vehicle recordings; production recording/network formats are unchanged.

Vulkan previews cover every asset family and both maps. No script errors remain
in final logs; the existing ObjectDB shutdown warning remains. No physical
headset session or multiplayer soak was run for this pass.

Evidence: `test-results/st-equipment-design`. Tracked receipt:
[st-equipment-design-2026-09-29.json](validation/st-equipment-design-2026-09-29.json).
