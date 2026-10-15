# CQ Frontier field audio — 2026-10-15

45 runtime clips replace prototype jungle/weather beds, CQ weapon reports, equipment handling and jetpack sounds; additional cues cover class tools, hull engines and water interactions. [Behavior and build instructions](../../../CQ-FRONTIER-AUDIO.md). [Audition reel](../../../audio/cq-field-20261015/README.md). [Source licenses](../../../../deathmatch/audio/cq_field/SOURCES.md).

Validation on Godot 4.7.2, Intel ADL-N Vulkan Forward+:

- **114 checks:** all clips import with expected duration/mono sample format; silent initialization and new lives; charge/lock, revival, water and cloak edges; automated pack reload/internal charge refresh; voice/loop caps; actual repair/supply transitions; loop teardown; nonempty audio mixer recording.
- **17 checks in the actual CQ client:** all nine reports play through the real spatial backend; Steam Audio loop support; engine start/stop; ballistic versus energy/ordnance impact selection; recorded day/night beds, storm attenuation, submerged-model water sound, authored river proximity and industrial site beds; disconnect mute.
- **16 existing live-audio checks** and **16 existing equipment-audio checks** passed. The live-audio test allows the mixer to release voices before exiting. Graphical client tests use the Dummy device to isolate voice capture/device shutdown from SFX behavior; the new field fixture additionally records the actual mixed signal.
- **45 imported clips** load from an isolated PCK with no loose WAV/Ogg originals. This catches dependencies on source audio paths. The ambient loader now uses imported resources.
- Signal validation verifies hashes, nonzero content, finite samples, headroom, DC offset and loop-boundary continuity for all 45 clips, plus nonzero output from the Godot mixer.
- All 14 downloaded inputs match their pinned hashes. Audacity MCP authoring responses are retained; all operations succeeded.
- Python compile checking and `git diff --check` passed.

This is an asset, mixer and client integration validation. No multiplayer load benchmark, native Windows or headset listening session was performed. The existing weather timing and authority simulation are unchanged. No live service deployment was made.

The source cache and intermediate masters are ignored and excluded from frontier packaging. Runtime source attribution and license notices are retained with the 6.1 MiB sound library. Freesound inputs use public HQ previews; OGA inputs use original downloads.
