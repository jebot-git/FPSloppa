# FPSloppa 0.6v

This release makes joining asset-heavy servers clearer and keeps players out of the match until required downloads are verified. It also restores server performance under heavy projectile load.

- Initial connection and map changes show a loading screen with byte progress, a progress bar, estimated time remaining and cancellation. The server waits for the client's map and model readiness acknowledgement before spawning it. Required maps/models are checked by SHA-256; models are prepared before entering rendered gameplay.
- A small download indicator remains visible for models received during play. Latency appears in another corner. VR uses the floating HUD during play and the existing stereo menu surface while loading.
- Server projectile processing skips unused history copies and distant collision candidates while retaining swept hit detection, cover tests and lag compensation. At 16 synthetic players, p95 tick time fell from 17.09 to 4.05 ms in the optimization audit; 32-player support remains experimental. See the server optimization report for methodology and limits.

## Compatibility

Use matching 0.6v clients and servers: protocol `fpsloppa-18-asset-readiness`. Android version code is 11; package IDs and signing identity are retained. Linux/Windows clients, Linux dedicated server, Quest/Pico APKs and external base assets are supplied. No new headset hardware certification is claimed.

## Archived extras

The original forty-map Arena Collection 1 and the ThreeWave, TeamFortress and Arcane Dimensions conversion tools are available **only from the [0.5v release](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v)**. They are removed from this and all future release packages, including source archives. They will not be further revised or worked on. Static map packs and conversion tools do not need redistribution with each game release unless the map loader or format changes. The 0.5v downloads remain unchanged.

Base maps, the optional LibreQuake extra maps and the two original TF arenas remain available. See `docs/ARCHIVED-EXTRAS.md` for the policy and `docs/validation/release-0.6v.json` for validation results.
