# CQ jungle ambience — 15 October 2026

[Play day then night](audition.ogg): 0:00 daytime, 0:20 nighttime, twenty-second excerpts. The review reel uses a common +8 dB audition gain; the game files and existing -8 dB runtime ambience gain remain quiet.

[Full daytime loop](../../../deathmatch/audio/cq_field/forest_day.ogg) · [Full nighttime loop](../../../deathmatch/audio/cq_field/forest_night.ogg)

Both are 120-second stereo 24 kHz Vorbis loops, about 1 MB each, mixed from the user-provided CC0 WAVs. Daytime emphasizes Peruvian birds; night emphasizes the Peruvian frog/insect bed. Lacandon and jungleathmo provide lower background layers. The originals in Downloads were not modified. The Costa Rican layer was subsequently excluded after the live rooster report; the current recipe uses four of the five originals.

Initially, four daytime and three nighttime stems were mixed and exported through Audacity MCP. Gain was applied to the selected audio using `effect_amplify`, because the connector's track-properties gain parameter did not change actual track volume. [Audacity receipt](audacity-receipt.json), [pinned source/recipe data](../../../tools/cq_audio/jungle_mix.json), and [credits/rebuild instructions](../../../deathmatch/audio/cq_field/SOURCES.md).

Verification includes original-file hashes, exported-master correlation with the intended layer gains, finite samples, stereo loop-boundary continuity, DC offset, clipping headroom, and imported Godot streams loaded from an isolated PCK. [Stereo quality](quality-stereo.json) and [pack check](pack.log). The complete field-audio quality check passed 51 assets. No new headset playback or remote deployment was performed for this audio pass; the new beds take effect on the next client launch.

The rooster correction rebuilds the runtime beds directly from the pinned gains, excluding the entire Costa Rican layer rather than suppressing a frequency band shared with wildlife. Automated [source and final-loop scans](../../validation/voxel-battle/live-release-20261015/audio/) support that choice but are not a listening guarantee. Both loops pass the 51-asset quality check. The earlier Audacity receipt describes the initial five-source pass; current recipe and manifest hashes identify the revised mixes.


2026-10-16: The daytime bird mix described above has been superseded after the user still heard rooster calls. [Current insect-focused daytime replacement](../cq-jungle-20261016/README.md). Nighttime remains as described here.
