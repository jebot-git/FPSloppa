# CQ Frontier audio

The voxelspace class mode uses 50 edited OGA/Freesound/Pixabay clips in `deathmatch/audio/cq_field/`. [Audition reel and timestamps](audio/cq-field-20261015/README.md). [Full credits and license terms](../deathmatch/audio/cq_field/SOURCES.md).

Forest birds and night insects crossfade with the day cycle. Storm cloud cover lowers the wildlife bed, and radio transmission ducks ambience. Industrial and waterside locations have quiet mechanical/water beds. River audio follows the closest authored river segment within 45 m. Submerged player models hear a filtered water bed even though their viewpoint remains above the surface. Rain and delayed thunder use field recordings through the existing weather system.

Each of the nine firearm/energy/ordnance slots has its own report. The scout pistol remains suppressed with an 18 m audible limit. The SMG retains ballistic impacts; beams and energy/ordnance projectiles use separate impact sounds in both native and scripted presentation paths. Grenades, airstrikes and hull destruction use the edited explosion.

Jetpack ignition and thrust, NVG/cloak switches and physical magazine/bolt handling use edited effects. Thrust loops use their complete sample length. Desktop reloads have ejection/insertion cues, while the guided launcher's internal charge refresh uses an electrical cue without a cocking sound.

Additional state-derived cues cover charge ramp-up, local target acquisition/lock readiness, local empty clip, cloak exit, incapacitation/revival, injection contact/sustain, dispenser deployment/transfer, hull repair, water entry/exit and swimming. Initial snapshots and new player lives prime silently. Confirmed hull health restoration produces repair feedback; ordinary damage does not. Nearby occupied/moving vehicles have speed-pitched engines; parking, destruction, map changes and disconnect stop loops.

Gameplay cues use `ArenaEffects`; environment/weather beds use `ArenaAmbience`. Field reports and cues are capped at 32 voices, with 10 combined vehicle/injector loops. Vehicle engines have a 100 m range; quiet tool/activation cues use 8–18 m. Engine selection prioritizes nearby hulls. These additions use existing accepted state and effect events, with no additional network messages or authority simulation changes.

## Editing and reproduction

Audacity MCP 0.1.24 (xDarkzx/Audacity-MCP) was installed and registered as `audacity`, using Audacity 3.7.7 with `mod-script-pipe` enabled. The editor's previous configuration was backed up before enabling scripting. Six masters were authored through actual MCP calls; the [receipt](validation/voxel-battle/field-audio-20261015/audacity-mcp-receipt.json) records operations and responses. The host may need to reload MCP connections to expose its tools in a later session; the authoring script connects through stdio directly.

```sh
python3 tools/cq_audio/fetch_field_sources.py
# Audacity 3.x must be running with mod-script-pipe enabled.
/path/to/audacity-mcp-python tools/cq_audio/edit_field_sources.py
/path/to/python-with-numpy tools/cq_audio/build_field_audio.py
/path/to/python-with-numpy tools/cq_audio/validate_field_audio.py
/path/to/python-with-numpy tools/cq_audio/audition_field_audio.py
python3 tools/cq_audio/test_field_pack.py --godot /path/to/godot
```

The authoring script refuses to overwrite masters; move a previous `tools/audio-sources/cq-field/edited/` directory aside before rerunning it. Downloads are verified against pinned SHA-256 values. The source cache has `.gdignore`, is ignored by Git, and is excluded from the frontier deployment pack. Runtime files and notices are self-contained; none depend on Audacity or network downloads during play.

The Freesound recordings use public HQ MP3 previews; lossless originals were not obtained. OGA sources use original downloads. Asset signal checks and mixer/integration tests do not replace final listening and loudness tuning on the intended headset. No live service deployment was performed.

## Updated energy/projectile reports

The [weapon reauthoring pass](audio/cq-weapons-20261015/README.md) replaces seven reports and the energy impact using the eight user-supplied Freesound CC0 sources. Fourteen extra takes are edited for future tiers without adding weapon assignments. To regenerate the full library, run `tools/cq_audio/reauthor_weapons.py` through the Audacity MCP Python environment before `build_field_audio.py`; the full builder reapplies these latest masters at the end. The offline reserve has `.gdignore` and stays outside the runtime resource graph.

## Vehicle weapons

[Vehicle audition and source details](audio/cq-vehicles-20261015/README.md). The rocket tank uses a single Katyusha launch excerpt per round and a positional motor loop following each live battery rocket. Light/heavy tanks and the autonomous turret have distinct Battle at Sea cannon mixes. The Battle at Sea explosion mix replaces the shared ordnance impact (also used by launchers, airstrikes and hull destruction).

Firing audio follows the existing replicated `shot_at` timestamp, supporting native and script authority without new RPCs. Initial/repeated/stale snapshots stay silent; script muzzle-flash RPCs no longer duplicate the sound. Rocket loops stop on disappearance, distance culling, disconnect and map reset. All loops share the existing ten-source limit with engines/injection; report voices retain the 32-source cap. The rocket motor can be heard within 90 m, and vehicle/turret reports within 110 m.

To reproduce, place the two manually downloaded Pixabay MP3s at the cache paths in `tools/cq_audio/vehicle_sources.json`, then run `tools/cq_audio/reauthor_vehicles.py` with Audacity MCP's Python environment. Existing masters are backed up before exporting to avoid overwrite dialogs. `build_field_audio.py` reapplies this pass after the earlier weapon edits.
