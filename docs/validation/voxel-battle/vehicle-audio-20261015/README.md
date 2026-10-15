# Vehicle weapons audio validation — 2026-10-15

[Audition and editing details](../../../audio/cq-vehicles-20261015/README.md). Six masters use four original Battle at Sea Ogg recordings and two user-downloaded Pixabay MP3s, all verified against pinned SHA-256 hashes. Source licensing is recorded per input and derivative.

- **96 successful Audacity MCP calls**, including six exports and five layered mixes. All reports were filtered, faded, normalized and exported through the installed Audacity MCP server. Previous masters are backed up before reauthoring, avoiding modal overwrite prompts. The empty scratch project remains open.
- **149 checks passed** in the Godot mixer fixture on Godot 4.7.2, Intel ADL-N Vulkan Forward+: 50 imported assets; original cues and loop/report limits; initial/repeated/out-of-order timestamp suppression; per-class vehicle/turret reports; rocket motor start, position updates, stuck/distant culling, reentry and removal; turret cleanup; nonzero mixer recording.
- **19 actual CQ client integration checks passed**, including spatial playback, a vehicle firing timestamp selecting its new report, silent muzzle-flash RPC to prevent duplicates, and unchanged impact family selection.
- **50 clips loaded from an isolated PCK** without loose source WAV/Ogg assets.
- All 50 runtime signals plus the actual mixed capture passed finite/nonzero/headroom/DC checks. Existing loops and the new motor loop passed seam checks. The new motor loop's sample boundary difference is approximately 0.00317. Eight rocket launches summed at the real 150 ms cadence peak at approximately 0.7063 before in-game attenuation.
- Reencoding the six Audacity masters produced identical runtime hashes. Python compilation and `git diff --check` passed.

Native vehicle/turret state already replicates firing timestamps and battery-projectile identity. The new presentation consumes that state; native C++ gameplay, wire format, damage, projectile range, magazine/reload rules and firing cadence are unchanged. Motor loops share the existing ten-loop limit with engines/injection. Vehicle/turret firing uses the existing 32-report voice pool.

No live deployment, full deployment-package rebuild, headset listening review or multiplayer load benchmark was performed. The package test covers the isolated runtime audio PCK. The Pixabay MP3s were supplied locally by the user after automated requests returned HTTP 403; original inputs and working masters remain outside the deployment package.
