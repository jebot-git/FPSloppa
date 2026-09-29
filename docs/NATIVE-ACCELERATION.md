# Native avatar/projectile acceleration and packet packing

Follow-ups: [native compact codec and shared historical hitscan tracing](NATIVE-NETWORK-REWIND.md), and [native avatar preparation and bot AI](NATIVE-AVATAR-BOTS.md). The measurements and original implementation boundaries below precede that follow-up.

Implemented after the [native performance study](NATIVE-PERFORMANCE-STUDY.md). Avatar math and projectile processing now use an optional C++ GDExtension. Snapshot grouping avoids repeatedly compressing a growing batch after every record. The game retains GDScript reference paths. LOD thresholds, animation solve cadence, local tracking latency, physics tick rate and the networking protocol remain unchanged.

## Integrated results

Measurements used the installed Godot 4.7.2 Fedora runtime on the i7-12700 / Arc A770, with portable release native libraries. Full results and build hashes are in [the receipt](validation/native-implementation-2026-09-28.json).

| Workload | Reference | New implementation | Change |
| --- | ---: | ---: | ---: |
| Nearby avatar pose CPU, 16 avatars | 1.944 ms/frame | 1.431 ms/frame | 26% less |
| Distant avatars, current XR policy, pose CPU | 0.777 ms/frame | 0.597 ms/frame | 23% less |
| Server projectile helper, 16 plasma-firing actors | 3.77 ms/tick | 1.35 ms/tick | 64% less |
| Server simulation + snapshot computation, mean | 8.80 ms/tick | 4.95 ms/tick | 44% less |
| Server simulation + snapshot computation, p95 | 14.68–14.98 ms | 8.65–8.88 ms | About 41% lower |
| Packet generation, 16 actors + 523 projectiles, median | 4.554 ms/snapshot | 2.515 ms/snapshot | 45% less |

The server comparison brackets two native runs with two reference runs. Each has 120 warmup ticks and 240 measured ticks; the combined timing includes packet construction every third tick. It excludes the engine's separate physics-frame work and actual remote transport. The fixture has no bots and reaches 523 simultaneous projectiles; it is a stress case, not a normal DE match. Helper averages include warmup.

The rendered client comparison uses 16 avatars across three VRMs, half full-body tracked, half head/hands tracked, with springs off. Each scenario runs twice in reversed order. Nearby average wall-frame time changed only from 8.61 to 8.46 ms; nearby p95 varied from 9.39/10.39 ms to 10.98/8.88 ms. **There is no demonstrated consistent nearby p95 or overall FPS improvement.** The measured pose CPU saving is real in this fixture, but headset timing and Windows/Android runtime behavior still need device testing. The XR-policy scene uses an ordinary synthetic XRCamera3D without a headset runtime.

## Implementation boundaries

[Avatar acceleration](../addons/fps_native/src/poses.cpp) handles analytical two-bone IK, bone orientation, cached finger updates, pose capture and render-frame interpolation. GDScript still chooses animation targets, samples floor contact, manages cadence and handles state transitions. This is a selective port of repeated work, not a replacement animation system. Cached finger indices/rest rotations avoid rebuilding their inputs every frame. Local first-person poses stay immediate, while remote interpolation, death transitions, missing bones and teleport resets retain the existing behavior.

[Projectile acceleration](../addons/fps_native/src/projectiles.cpp) runs the standard projectile loop in C++, rebuilds the existing conservative spatial grid, and performs zero-rewind body/world traces. It reuses query resources and precomputes the stance-volume inverses. Damage, explosions and gameplay callbacks remain ordered and synchronous in GDScript. Projectile insertion/removal still follows a snapshot of IDs, preventing newly spawned shots or deleted shots from being processed incorrectly mid-loop.

Special arsenal projectile behaviors still run their existing callbacks with the native candidate grid. Rewound traces and modes with structures, mounted hulls or Tribes-specific tracing keep the complete reference trace path. Both paths preserve relative-motion sweeps, serial checks, fresh-shot semantics, thin-wall cover, headshots, surface normals and map-trigger contacts. All work remains on the calling game thread.

[Packet grouping](../deathmatch/network/replication.gd) searches for a checked, packet-sized prefix: it grows candidate groups, then narrows the range when a candidate exceeds the budget. Every emitted ordinary packet is explicitly checked against 1,100 bytes; correctness does not assume compression size is monotonic. Oversized individual records retain the reliable channel. Independent records, sequence numbers, membership tombstones, control-state resends and decoder limits are unchanged. Godot still performs bulk serialization and FastLZ compression natively.

In the three measured packet workloads, new and reference grouping produced identical total bytes and packet counts. The test includes independent-record equality, reordering, oversized payload delivery and bounded datagrams. Other input distributions can produce different grouping; the protocol allows this.

## Build and release

The extension sources live in [addons/fps_native](../addons/fps_native). Official godot-cpp is pinned to commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`; downloads are checksum-verified. Bindings and compiler output stay in ignored directories. The Godot API target is 4.7; `--api` accepts an engine-generated custom `extension_api.json` when required. All builds use the standard float-vector precision expected by this project.

```sh
# Portable release libraries, using the existing project build containers:
python3 tools/build_gameplay_native.py --target linux --container
python3 tools/build_gameplay_native.py --target linux --server --container
python3 tools/build_gameplay_native.py --target windows --container

# Android ARM64, using the installed NDK (or supply --ndk):
python3 tools/build_gameplay_native.py --target android

# Local Linux development, CMake + Ninja + C++ compiler:
python3 tools/build_gameplay_native.py --target linux
```

Container builds reuse the project's existing Ubuntu images and disable container networking. The builder needs network only when the pinned bindings are absent. The Windows container uses MinGW; Windows host builds use CMake/Ninja with an available host compiler. Shared libraries are installed by replacing their inode, allowing an already-running game to keep using its mapped version safely. Restart the game to load a new build.

Linux client, Linux server, Windows x86-64 and Android ARM64 libraries were built successfully. The portable server library links only standard C/math system libraries, and Windows imports only KERNEL32 and msvcrt. Android load segments have 16 KiB alignment. Cross-compilation and ELF/PE inspection do not replace Windows or Android device tests.

The dedicated server uses a separate extension entry point and binding profile without avatar/Skeleton3D code. Its package includes only that gameplay library, its descriptor and license, while retaining the existing exclusion of client plugins. A separate console-server package was built, hash-audited and started successfully on loopback with the native library mapped. Desktop and Android release builders now require current native build receipts; Android verification checks the gameplay library and its page alignment. These changes do not publish or replace an existing release.

The generated `fps_native.gdextension` descriptor and binaries are not source-controlled. Fresh source checkouts without the extension use the reference paths. Build receipts detect missing, changed or stale libraries before release packaging.

## Verification and fallback

```sh
# Native parity and focused regression suite:
python3 tools/native_study/validate_implementation.py

# Also repeat sequential server and rendered-client A/B measurements:
python3 tools/native_study/validate_implementation.py --bench

# Reference paths for development comparisons (after Godot's -- separator):
# --gdscript-poses --gdscript-projectiles
```

Validation completed:

- **51,311 differential checks:** rounded-box/body sweeps, all stance heights sampled across the supported range, candidate order/overflow, world/cover/relative-motion traces, native/reference bone transforms, local/remote tracking and teleport changes.
- **6,335 packet checks:** unchanged records, datagram size limits, reliable oversized records and reordered reconstruction, plus the existing replication protocol test.
- Existing frame-smoothness, animation, projectile ordering, hit detection, broad-phase, DE cover, rocket jump, combat, fortress, grenade and lag-compensation fixtures passed.
- Real ENet server, shooter, target and spectator completed the multiplayer regression scenario with no failures.
- Console-only server package started the map and listened on loopback successfully with the new library.

Existing fixture ObjectDB/resource shutdown warnings remain in both reference and native runs. No final validation run reports a script error. Native acceleration is optional during development; command-line reference switches keep behavior comparisons reproducible. Release packaging requires the selected native builds so a missing binary cannot silently erase the intended performance benefit.
