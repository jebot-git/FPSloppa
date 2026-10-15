# Grass concealment and combat ranges — 2026-10-15

[Gameplay rules and ranges](../../../CQ-COVER-RANGES.md).

- **77 script checks passed:** canonical render-generator tuft agreement, absence on pads/water/above-ground structures, posture, enemy LOS/range, ten-second memory, 100 m allied icons, darkness/NVG/glare composition and weapon/vehicle range definitions. Sample tile contains 906 tufts. Warm classifier cost: 640 queries in approximately 3.4 ms on this desktop; this is not a server load benchmark.
- **263,887 native checks passed**, including the existing deterministic 64-player, 3,600-tick replay and protocol/collision/gameplay coverage. New cases verify reduced spotting and expiry, standing restoration, a real simulated launcher arc crossing 200 m above ground, guided acquisition/hull impact at 499 m, tank projectile lifetimes, turret acquisition at 149 m, and grass concealment excluding turret acquisition at 40 m but allowing it at 35 m.
- Recon regression places a prone, grass-concealed target 80 m across the flight route, outside a hypothetical reduced 25 m corridor. The aircraft still reveals it and alerts once per life. Recon production code is unchanged.
- **147 client GDExtension/Jolt checks passed** with a clean process exit: actual rendered-source grass contact reaches the native world callback and prevents refreshing a 20 m prone target, then standing restores spotting. Both 30 and 60 Hz are exercised, including the full ten-second memory interval.
- Existing launcher physical-reload tests passed; script parse checking and `git diff --check` passed.
- Linux client and dedicated-server modules were rebuilt; their source/library hashes match their build receipts. The dedicated-server binary also passes the same 147 real Jolt checks at 30/60 Hz and exits cleanly (`server-functional.json`).

Native standalone tests were compiled with Zig 0.15.2's C++ compiler and CMake/Ninja installed in the user environment because the standard C++ build tools and container engine were absent. The local shared-library link uses `-z nodelete`: this prevents static compiler-runtime exit callbacks from referring to an unloaded extension after Godot shutdown. A zero-error assertion run initially exposed that local shutdown problem; the final client run exits cleanly. This linker setting is local build configuration, not a change to game rules or the standard build scripts. Windows, Android, headset rendering and a new network load run were not tested. No VPS deployment or live service action was performed.

Reproduce with a normal C++ toolchain:

```sh
cmake -S tools/authority_core -B /tmp/cq-authority -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/cq-authority -j 4
ctest --test-dir /tmp/cq-authority --output-on-failure
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_grass_concealment.gd
# Rebuild the native extension first, then run its real Jolt fixture:
godot --headless --xr-mode off --path . --script tools/authority_core/grass_functional.gd
```
