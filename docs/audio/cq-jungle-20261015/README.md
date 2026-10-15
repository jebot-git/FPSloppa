# CQ jungle ambience — 15 October 2026

[Play day then night](audition.ogg): 0:00 daytime, 0:21 nighttime, twenty-second excerpts. The review reel uses a common +8 dB audition gain; the game files and existing -8 dB runtime ambience gain remain quiet.

[Full daytime loop](../../../deathmatch/audio/cq_field/forest_day.ogg) · [Full nighttime loop](../../../deathmatch/audio/cq_field/forest_night.ogg)

Both are 120-second stereo 24 kHz Vorbis loops, about 1 MB each, mixed from the five user-provided CC0 WAVs. Daytime emphasizes Peruvian/Costa Rican birds; night emphasizes the Peruvian frog/insect bed. Lacandon and jungleathmo provide lower background layers. The originals in Downloads were not modified.

Four daytime and three nighttime stems were mixed and exported through Audacity MCP. Gain was applied to the selected audio using `effect_amplify`, because the connector's track-properties gain parameter did not change actual track volume. [Audacity receipt](audacity-receipt.json), [pinned source/recipe data](../../../tools/cq_audio/jungle_mix.json), and [credits/rebuild instructions](../../../deathmatch/audio/cq_field/SOURCES.md).

Verification includes original-file hashes, exported-master correlation with the intended layer gains, finite samples, stereo loop-boundary continuity, DC offset, clipping headroom, and imported Godot streams loaded from an isolated PCK. [Stereo quality](quality-stereo.json) and [pack check](pack.log). The complete field-audio quality check passed 51 assets. No new headset playback or remote deployment was performed for this audio pass; the new beds take effect on the next client launch.
