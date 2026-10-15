# Allied LPMAC ground transports — 14 October 2026

Branch: `experimental/cq-voxelspace`. Candidate protocol:
`fpsloppa-cq-frontier-20-transports`. Client and server must be updated together.
This implementation did not replace the running live-test release.

## Asset and optimization

Procured asset 29498 / file 25729 through **BlendSwap remote MCP**, using the
configured account's free download allowance: **zero credits spent**.

- [LPMAC_military truck](https://blendswap.com/blend/29498) by
  [Britdawgmasterfunk](https://blendswap.com/profile/1312781).
- [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), uploader-declared.
- The original 54,064,660-byte Blender source and sanitized procurement metadata
  remain in `tools/ground_transport/source`. No credential or signed URL is saved
  in the repository.
- Local Blender removed the complete turret/gun/mantlet/sensor/antenna assembly
  and showcase, welded coincident cab shells, reduced dense hardware and baked
  original colours to a 1024² atlas.
- **31,854 triangles**, down from roughly 620,126 in the source scene; two mesh
  surfaces/materials: hull plus transparent windows. Automatic Godot mesh LODs
  remain enabled. Approximate size: 3.51 m × 2.82 m × 8 m.
- The six existing side pods have authored `Entry0`–`Entry5` / `Seat0`–`Seat5`
  markers, three per side. The JSON manifest generates matching native constants.
- Authoring files are excluded by the frontier packager; runtime assets and
  licensing live under `deathmatch/models/ground_transport`.

## Behavior

Four carriers are placed alongside the eight existing combat tanks: two for
team 0 at the town/port approaches, two for team 1 at factory/military approaches.
All four spawn areas passed a hull-clearance check against the authored map.

Use beside a free side pod boards an allied player. Each pod holds one occupant,
for six total including the driver. The first aboard drives. If the driver exits
or disconnects, the first remaining ally takes over in their existing seat. Enemy
boarding and a seventh occupant are rejected.

The passenger's normal world/stereo camera looks through the pod window. The
tank scope screen and isolated black background are bypassed. Handheld firing,
vehicle firing, grenade throws and combat tools are blocked aboard by the native
authority. There is no turret collider, weapon or ammunition pool.

Jump dismounts at the current pod's collision-tested exit, with clear ground
fallbacks. A blocked exit retains the rider safely. The exit consumes its jump
edge and clears queued jetpack boosts. Use can also dismount.

Movement matches the rocket tank: 10 m/s forward, 5 m/s reverse, 0.65 rad/s turn,
4 m/s² acceleration, and 1.25× road mobility. Ground clearance is zero rather than
hover-tank clearance. The transport has 100 HP and uses existing vehicle
damage/repair/water rules. Destruction releases and kills all remaining occupants;
round reset restores the original team, vehicle and empty seats.

The C++ core owns fixed-capacity, life-bound seats. Positions follow the vehicle's
supporting basis; stale/dead/disconnected/team-changed riders are removed. CQA2
class flags bits 5–7 carry `seat + 1`, and vehicle kind 3 identifies the carrier.
Packet row sizes are unchanged. Script fallback boarding and controls use the same
manifest. A client rebuilds a collider/model when an incoming native vehicle ID
replaces a local placeholder of another type.

## Validation

- `native-checks.json`: **909,764** passing host-independent checks, including all
  six entries, capacity, team restrictions with a free pod, motion, firing
  suppression, blocked exits, jump exits, driver handover, disconnect cleanup,
  destruction, restart, grip/reload/recoil and deterministic 64-player replay.
- `sanitizers.log`: the same **909,764** checks under ASan/UBSan, including 100 HP,
  infantry immunity, friendly ordnance protection, half grenade and full ordnance damage.
- `transport-functional.log`: **373** passing real Godot/Jolt checks, covering
  six seated actors, disabled/restored colliders, native binary seat decoding,
  client projection, moving-hull attachment, jump dismount and restart.
- `render-transport.log`: **51** passing checks covering four balanced placements,
  authored GLB anchors, fallback boarding/driver handover/jump, direct passenger
  camera, transparent windows and native-ID collider replacement. For every pod,
  a geometric sight ray hits its window first and a rendered view shows outside.
- `vr-regression.log`: **49** passing earlier VR/calibration/holster checks.
- `placements.log`: all four authored-map upper hull-clearance probes found no
  obstruction.
- `arena-results.json`: actual desktop/tracked clients passed shooting, grenade,
  NVG, prone death/gib/respawn, team and jetpack checks. Four bots traversed the
  authored map for 600 ticks. This run preceded the final dismount input
  consumption guard and 100 HP correction, checked by the final native and Jolt suites.
- `transport-smokes.json` and `functional-results.json`: final standalone,
  five-suite Godot/Jolt and 32/64-client jungle/ENet regression evidence.
  The final cab surface cleanup changed only visual geometry/atlas; the rendered
  transport checks were repeated on that export. Anchors/dimensions stayed identical.
  The 100 HP correction followed the transport-population smokes; it was checked
  by the final native/sanitizer, Jolt and rendered suites.
- `native-build-receipt.json`: final portable Linux library/source hashes.

The first full-arena attempt exposed the native-ID/local-placeholder type mismatch
and was rejected because it logged missing turret-collider errors. The client
rebuild fix and explicit regression checks preceded the accepted arena run.
The first isolated Jolt fixture also accidentally allowed its unseated enemy to
fire; its global shot assertion failed. That fixture now holds the enemy's trigger
off and asserts firing attempts from all six seated occupants instead.

Existing authored navigation warnings and native compiler warnings are retained
in evidence. No live headset fit, passenger comfort, WAN capacity, or speedup is
claimed. Interactive multiplayer/headset testing remains necessary before judging
those. The existing live server/client were not restarted by this work.

## Reproduce

Visual evidence: [Blender view](blender-optimized.png),
[Godot exterior](transport-exterior.png), [left pod](transport-left-pod.png),
[right pod](transport-right-pod.png).

See `tools/ground_transport/README.md` for asset rebuilding and controls. Run:

```sh
python3 tools/ground_transport/generate_geometry.py --check
python3 tools/build_gameplay_native.py --server --container -j8
python3 tools/authority_core/run_suite.py --seconds 10 --players 32 64 --cq-core --tracked --jungle-map --output /new/results
python3 tools/authority_core/run_arena_suite.py --output /new/arena-results
godot --headless --xr-mode off --path . --script res://tools/authority_core/transport_functional.gd
godot --xr-mode off --audio-driver Dummy --path . --script res://deathmatch/tests/cq_transport.gd
```
