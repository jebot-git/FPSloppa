# Q1 triggers and authored lighting

DM1–DM7 retain their authored light entities and now use full VIS and a four-sample-per-axis light bake. The conversion adds no minimum light, sunlight, or bounce light. Embedded RGB lightmaps travel with the BSP. The Quake-specific material applies the original display-space light multiplication, without the shared shader's square-root brightness lift or global ambient/directional fill. Ordinary faces without light samples stay black; sky/liquid special surfaces retain their separate fallback. Local weapon lights still illuminate surfaces. Replacement textures remain in use, so these are not pixel-identical retail screenshots.

The original light response and mover conventions were checked against id Software's [renderer](https://github.com/id-Software/Quake/blob/master/WinQuake/gl_rsurf.c), [buttons](https://github.com/id-Software/Quake/blob/master/qw-qc/buttons.qc), and [doors](https://github.com/id-Software/Quake/blob/master/qw-qc/doors.qc). The material keeps authored lighting when the game's general Contrast setting changes.

## Entity support

Shared BSP runtime support covers touch/shootable buttons, shootable doors, one-shot/repeating triggers, relays, counters, delayed target chains, killtargets, linked door panels, start-open/toggle doors, two-stage secret doors, and cyclic trains. Existing teleport, push, hurt, and platform behavior remains available. The server owns activation and distributes mover positions, including to joining clients.

This is support for common Quake entities, not an interpreter for arbitrary QuakeC mods. Custom scripted entities and switchable light-style programs remain outside this runtime. The multiplayer conversion keeps switched lights baked on, removes campaign exits, and unlocks key doors. DM1–DM7 use the supported common entities; their buttons and target chains are no longer stripped during conversion.

DM1 has two contact buttons and one shootable secret door; DM2 has eight contact buttons, one shootable button, linked trap doors, and three moving trains; DM5 has a contact button and trigger volume; DM6 has its shootable secret door. DM3, DM4, and DM7 retain their existing platforms, teleports, and push volumes.

Bots now resolve upstream controls, press buttons and shoot secrets through normal input; they check crusher safety and stop after activation.

Protocol `fpsloppa-36-bsp-triggers` requires matching clients and servers because restored buttons/trains add replicated mover indices.

## Validation

- `deathmatch/tests/bot_map_triggers.gd`: actual bot-fired DM6 secret, DM2 contact button and upstream/linked/crusher checks.
- `deathmatch/tests/requested_changes.gd`: live RCON bot count, Titan weapon eligibility and rendered avatar body orientation.
- `deathmatch/tests/quake_triggers.gd`: all seven real BSPs, contact buttons, shot traces, target resolution, linked/start-open doors and train movement.
- `deathmatch/tests/run_quake_mover_network.py`: one ENet server and two clients; shot/contact switches, moving doors and all three DM2 trains.
- `tools/validate_converted_traversal.py`: spawn clearance, swimming, doors, lifts, teleports and push volumes.
- `deathmatch/tests/quake_light.gd`: packed dark/special-face sentinels and exact rendered sample values under strong ambient/directional light.
- `tools/quake_source/verify.py`: exact licensed texture mip data and embedded RGB lightmaps.
- `tools/quake_source/bake_caches.gd`: raw/BC7/ASTC scene caches, source hashes, lightmap allocation and bot navigation.

Run GDScript tests with `godot --headless --xr-mode off --path . --log-file /tmp/test.log --script <script>`. Set `GODOT_BIN=godot` for the older Python traversal/preview tools. Final receipts are in `docs/validation/quake-restored.json`; detailed logs and previews are in `test-results/`.
