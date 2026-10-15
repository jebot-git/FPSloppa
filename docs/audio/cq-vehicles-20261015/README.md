# Vehicle weapons audition

[Play the audition](audition.wav). Order: rocket-tank launch, motor loop excerpt, light tank, heavy tank, turret, shared ordnance explosion. [Timings](timings.json), [recipes](recipes.json), [successful Audacity MCP calls](audacity-mcp-receipt.json).

The rocket tank uses the user-downloaded Katyusha sample, with a quiet cannon attack mixed in; playback repeats the single launch at the game's 150 ms salvo interval. The travel sound uses the separately supplied Rocket Loop recording. A cropped motor bed and 120 ms crossfade avoid repeatedly firing the ignition transient. Travel voices follow live battery projectiles and stop when those projectiles disappear. The offline audition plays one motor cycle rather than an indefinite loop.

Battle at Sea cannon recordings form distinct light/heavy/turret reports. The heavy variant has a lower, longer body; the turret report is tighter and brighter. A layered Battle at Sea explosion replaces the shared ordnance impact used by tank/turret shells, rocket tank missiles, handheld ordnance, airstrikes and hull destruction.

[Full credits and license terms](../../../deathmatch/audio/cq_field/SOURCES.md). OGA source recordings are CC0. The two user-supplied Pixabay recordings retain the Pixabay Content License. Original MP3/Ogg files and working masters are in the ignored `tools/audio-sources/cq-field/vehicle/` cache. [Pinned sources](../../../tools/cq_audio/vehicle_sources.json).

To reproduce, supply the manually downloaded Pixabay files at those cache paths, then run `tools/cq_audio/reauthor_vehicles.py` with Audacity running, mod-script-pipe enabled and a Python environment containing mcp/numpy. `--build` encodes existing masters. Previous exports are backed up before reauthoring. Runtime assets need neither Audacity nor network access.

[Validation results](../../validation/voxel-battle/vehicle-audio-20261015/README.md). Final headset listening and loudness tuning remain hardware checks.
