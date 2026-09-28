# Tribes-style skiing on BSP29

Assessed 2026-09-27 against the current working tree. This is a feasibility assessment, not an implemented movement mode or a claim of matching the original Tribes physics exactly.

**Viable with BSP29. The substantial work is the movement controller, network prediction and terrain design, rather than a map-format conversion.** Per the requested scope, bundle skiing and the energy jetpack into a separate Tribes loadout. Selecting that loadout enables its movement; other loadouts keep their existing rules. Start with a dedicated ski test map.

The existing loadout selector is a good integration point. `deathmatch/experimental/weapon_rules.gd` owns the server's loadout IDs, preferred/effective rules, spawn inventory and BSP pickup remapping. `deathmatch/interface.gd` builds the host selector from those IDs, and `deathmatch/modes/votes.gd` already changes a loadout by restarting the map and remapping pickups. A new **TRIBES · experimental** entry could therefore select both its arsenal and its movement as a single coherent ruleset. An independent global skiing checkbox is unnecessary for this scope.

Use an explicit movement-profile resolver keyed by `armory.effective() == "tribes"`, rather than tying movement to the current gun slot or altering the existing Quake movement implementation for everyone. Apply the resolved profile to fighters on spawn, mode/loadout change and snapshot restoration. Current code sets `actor.quake_movement = true` for every loadout in `arena.gd`; that assignment needs dispatching to the appropriate controller. Desktop, VR and authoritative bots must all use the resolved profile.

Add `tribes` to configuration validation (`sv_weapon_rules`), loadout names/IDs, discovery and RCON presentation, snapshot/demo validation, and the relevant asset/weapon dispatch paths. The existing snapshot already carries `weapon_rules`; movement can derive from it, while ski input, fuel and active contact state need their own prediction/reset handling. Existing clients must reject the new network version. Adding only an ID is insufficient: `select()` currently starts from a DOOM weapon table, and several rendering, projectile, pickup and bot choices branch on specific ruleset names. Those paths need a deliberate Tribes implementation; a movement prototype could use explicitly temporary weapons without claiming a finished Tribes arsenal.

Initially expose the new loadout through the existing selectable modes: DM, TDM, CTF, KOTH and FT. CTF is the best first complete experience. Keep the current mode overrides: DE forces CS16, TF/TB force Quake, Assault forces UT99, and IG/IF/Chainsaw Circus use fixed equipment. Cindercoil can still be loaded as geometry in the isolated test harness without changing live TB rules. These are rollout recommendations, not a requirement to balance other loadouts against Tribes.

Give the Tribes loadout its own spawn-equipped jet energy/thrust state. Do not require the existing rare arena jetpack pickup or route its recharge through `sv_jetpacks`: that system limits availability and intentionally cancels landing momentum. Leaving it separate preserves all existing loadouts, bindings and pickup timers. A loadout switch should reset ski/fuel state, velocity, prediction history and stale held inputs through the existing match restart, so switching cannot transfer accumulated Tribes speed into another loadout. Test the switch in both directions, including late joins and demos.

The project imports BSP draw surfaces into Godot triangle collision (`deathmatch/maps/loader.gd`, `addons/bsp_importer/bsp_reader.gd`). It does not use Quake's expanded player clip hulls for normal player movement. BSP29 can describe inclined, piecewise-planar terrain; convex wedge/triangular-prism brushes are already used by the Cindercoil generator. The original [Quake format definitions](https://github.com/id-Software/Quake/blob/master/WinQuake/bspfile.h) describe the relevant planes, vertices and bounded indices. There is no need to change to BSP2 for a first ski arena.

Native collision was checked with the production importer in headless Godot 4.7.2. Cindercoil produced two concave triangle collision shapes. All 71 road-centre ray samples at 5 m intervals hit the road, with at most 2.9 cm difference from the authored route. A capsule sweep stopped at a 2 cm fixture wall at both 60 and 100 m/s. These are floor-presence and simple sweep checks, not proof of reliable high-speed traversal through valleys, seams or multiple contacts.

The existing controller, given 20 m/s downhill speed and no input on Cindercoil, reached zero horizontal speed within one second, travelling 2.25 m. The relevant obstacles are concrete:

| Existing behavior | Required skiing behavior |
| --- | --- |
| Ground friction 6; grounded blast velocity decays rapidly | Preserve momentum while ski input is active |
| Grounded vertical velocity forced to -0.2 m/s | Preserve motion along the slope and integrate gravity into its tangent plane |
| 0.6 m floor snap and automatic step-up | Deliberate contact policy: detach over crests; avoid stair-induced boosts |
| Existing jetpack replaces velocity and clamps landing speed to 9.4 m/s | A separate thrust/fuel profile that adds to velocity and preserves landing momentum |
| Position/velocity correction against an acknowledged prediction sample | Validate ski state and high-speed contact behavior under latency; consider replay if correction testing warrants it |

These behaviors live in `deathmatch/fighter.gd`, `deathmatch/movement/quake.gd`, `deathmatch/movement/jetpack.gd` and `deathmatch/movement/prediction.gd`. Simply disabling friction would leave the other restrictions intact. Merely setting `floor_stop_on_slope = false` is also insufficient: [Godot's grounded movement policies](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) are designed around floor classification, snapping and sliding, not this game's desired momentum rules.

Implement a shared ski movement helper used by authority and client prediction. Start with explicit held/toggle ski input, nearly zero ground friction, limited steering and ground-tangent gravity (`g - normal * g.dot(normal)`). Handle landing normal velocity, small slope transitions, sharp collisions and crest detachment deliberately. Avoid renormalizing velocity after every collision: that could preserve speed into walls or inject energy at seams. Keep the full capsule collision and use [Godot's body sweeps](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html), with explicit response if `move_and_slide` cannot provide the required contact behavior. Do not globally switch the existing character to floating motion without replacing all grounded-state consumers.

For a Tribes-inspired ski/jet loop, introduce sustained additive thrust, energy consumption and recharge as part of the Tribes loadout's profile. The current short boost pickup is not sufficient unchanged. Its normal arena behavior and pickup rules remain separate. Ski input should not imply crouching, grant crouch accuracy bonuses or conflict with the current jump/jetpack bindings.

Eight authored BSP29 maps were audited. Surface areas include roofs and inaccessible faces; they are not a connectivity or navigability analysis.

| Maps | Finding | Suitability |
| --- | --- | --- |
| Cindercoil | About 228 × 236 m; 350 m road rises 14 m with maximum route grade about 3.3° | Useful long seam/contact stress test, but too gentle and directionally biased for representative ski-and-jet routes |
| Ironspan / Relayworks | About 98 × 50 m / 90 × 54 m; some inclined surfaces | Small integration tests; limited run-up and route space |
| Five DE maps | Roughly 117–155 m by 80–122 m; mostly flat architectural surfaces | Poor candidates for the main skiing experience without substantial redesign |

Build a modest BSP29 test course with continuous downhill/uphill pairs, bowls, crests, banks, seams, stairs, walls and landing platforms, followed by an open CTF map with deliberate momentum routes. Use coarse planar brush terrain with shared boundary vertices; keep decorative collision out of travel lanes. Standard invisible Quake `clip` brushes must not be assumed to smooth stairs here: triangle collision bypasses the brush/clip-hull paths. Any invisible smoothing geometry needs explicit importer support or supported collision entities on both client and server.

The loader currently limits BSP files to 25 MB and scales 32 Quake units to one metre. Cindercoil already occupies 17.93 MB with 31,292 faces. BSP29 has bounded indices and node bounds, so terrain tessellation, extent and compiler budgets should be checked early. Original Quake engine constants are not all necessarily limits enforced by this importer. The existing Cindercoil pipeline uses `qbsp -noclip`; [the compiler documentation](https://ericw-tools.readthedocs.io/en/latest/qbsp.html) covers its format and collision-hull options. Broad open views may cost more VR rendering time than the additional movement arithmetic; profile the new map rather than assuming the current indoor rendering budget transfers.

The main production risks and acceptance work are:

- **Contact stability:** test alternating slopes, glancing walls, crest launches and valley landings at increasing speeds. Begin tuning around 30–40 m/s as an experimental target, not a recovered Tribes constant. Stress contacts to 60–100 m/s. Use bounded substeps only where measurements justify them.
- **Networking:** at 40 m/s a 60 Hz physics step covers 0.67 m and a 30 Hz input period covers 1.33 m. Existing reconciliation starts correcting errors above 0.20 m. Add ski/energy state to relevant inputs, snapshots, replay/reset paths and tests; check latency, jitter, loss and server/client slope transitions rather than merely increasing the correction threshold.
- **Interactions:** ordinary pickups currently test distance at the current position. Audit or sweep pickups, flag contacts and other thin trigger volumes so high-speed traversal cannot skip them.
- **Bots:** current ground navigation does not plan momentum routes or jet timing. A human prototype is considerably smaller work than useful competitive ski bots; route links need entry-speed and thrust guidance.
- **VR:** preserve a stable world horizon without pitching or rolling the HMD to terrain. Test comfort, turning and correction smoothness in a headset. Any comfort options must leave server movement unchanged.

Recommended sequence: isolated controller and BSP29 course; contact and energy validation; shared multiplayer prediction and interaction tests; headset testing; then a purpose-built CTF map and bot routing. Prototype feasibility is high. Shipping a polished multiplayer VR implementation is a substantial movement feature, not a small friction adjustment. No gameplay, map geometry or running VR session was changed by this assessment.

Raw audit and probe results are retained in `docs/validation/tribes-skiing-feasibility-2026-09-27.json`; the exploratory probe and log are under `test-results/skiing-feasibility/`. The importer emitted existing texture warnings and an ObjectDB exit warning. A full ski controller, high-speed terrain routes, multiplayer behavior, bot behavior and VR comfort have not yet been tested.

Follow-up, 2026-09-27: an optional [Stonehenge BSP29 terrain study](../maps/Stonehenge/README.md)
now provides a 704 × 704 m CTF environment with reconstructed bases and reference
terrain. Native CTF and swept capsule checks passed. It has no Tribes movement
implementation; the 16 m terrain grid and approximate architecture require
route and headset evaluation once that controller exists.

## Playable follow-up, 2026-09-27

The separate Tribes movement loadout and Stonehenge test build are now implemented.
See [the movement test](TRIBES-MOVEMENT.md) for controls, energy, validation and
remaining differences from the original game. This document records the initial assessment.
