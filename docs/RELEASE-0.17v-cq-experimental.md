# FPSloppa CQ 0.17 — native VR live test

Game-only experimental CQ release for Linux and Windows x86_64. Extract the complete archive and run `Play-Desktop` or `Play-VR`; the client connects automatically to **87.106.27.237:7777**. The launcher and updater are omitted. OpenXR VR requires a working runtime, such as the running WiVRn-Pro setup on Linux.

The live dedicated server enables destruction and 64 player slots, with adaptive 60 Hz simulation and a 30 Hz fallback under sustained load. CoreCU and competing game servers are stopped with persistent data retained. The separate Linux server archive contains the dedicated runtime.

This update includes the tested medic revival, dragging and deployable boxes; technician repair feedback and cabin repair; physical transport steering and tracked cabin hands; scout device and designator fixes; weapon display, reload and utility interaction fixes; XP unlock progress; jungle ambience; and rain rendering improvements. Shocktroopers carry three HE grenades. Cocking supports the offhand trigger, and NVG activation requires an empty hand.

Portable native Linux client/server and Windows libraries were rebuilt from the CQ voxelspace branch. Packaged Linux desktop, synthetic tracked-controller and Windows-under-Wine clients passed the native multiplayer admission/gameplay checks, including replicated destruction. The uploaded server also passed an isolated VPS smoke test. Windows GPU/OpenXR hardware was not tested. Sustained 64-player load remains experimental; these admission checks are not a 64-player stress qualification.

Each archive includes runtime dependencies, licenses and per-file hashes. `SHA256SUMS` and `BUILD-MANIFEST.json` identify the downloadable artifacts and source commit.
