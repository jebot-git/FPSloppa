# Physical TF/AS interactions and VR muzzle clearance

Implemented against 0.9v / `5105fb8`, preserving the pending stair-contact fixes.
The initial interaction change used protocol `fpsloppa-27-vr-interactions`.
Current source uses `fpsloppa-29-acknowledged-movement` after the subsequent crouch and
expression work; older clients and servers cannot mix with it. No release binaries were built or published for this change.

## Behavior

- TF repair and healing use fresh hand-contact strokes. Both hands work; withdrawing
  re-arms contact. First poses, tracking discontinuities, stale samples and passive
  contact do not activate abilities. Head-relative motion avoids adding locomotion,
  recentering or turn velocity to a slap.
- Support grip + offhand trigger activates TF abilities. Explosive classes get a
  visible held grenade, released by grip release or trigger release during a throw.
  Recent hand displacement over roughly 100 ms supplies velocity, capped at 12 m/s.
  Dropping produces zero initial velocity. Holding expires after ten seconds;
  gameplay interruptions cancel it. Existing Use controls remain available.
- AS consoles use visible caps centered on the same positions tested for hand
  contact. Stage, team, range and line-of-sight checks remain authoritative. VR uses
  a press or Use; desktop proximity activation stays available. Checkpoints and TF
  flag/capture zones keep their existing interaction rules.
- The server validates discrete requests against sender identity, map epoch, spawn
  serial, increasing request sequence, pose bounds, world visibility, ammo and
  cooldown. Grenades use the existing swept server simulation and replicated FX.
- Muzzle clearance first checks torso-to-hand visibility, then sweeps a
  projectile-sized sphere toward the hand and muzzle. A clear hand with a clipped
  barrel gets a near-side firing point; a hand beyond geometry is blocked. The local
  gun and aim guide use the same correction without altering tracked poses.
  Clearance is computed once per ready shot and reused for projectile launch.
- Only engineer/medic and AS hand contacts need continuous server pose sampling;
  other TF abilities validate their discrete requests. Per-player interaction state
  is cleared on spawn, departure and reset. The setting persists in
  `[control_options] physical_interactions` in the client configuration.

## Validation

Automated checks cover the gesture detector at 30/60/90/144 Hz, full simulated rig
input through authoritative grenade creation, preview visibility, cancellation,
PTT/dual-pistol behavior, saved preferences, repairs/healing, AS presses, obstruction,
request replay, stale life/map, expiry, handedness, real downward rocket launch and
self-damage/knockback. A real two-process ENet test exercises arm, throw, replication
and pipe detonation. HiSlop tests verify both authored button locations and press
the actual upper switch. Existing TF, combat, VR menu, movement and stair tests also
run. Machine-readable results are in
[validation/vr-physical-interactions.json](validation/vr-physical-interactions.json).

The 16-player continuous VR-plasma stress run measured 360 ticks after warmup:
p50 4.258 ms, p95 5.046 ms, maximum 8.379 ms; snapshot p95 0.710 ms, with up to 562
projectiles. Sampled and post-cleanup orphan-node counts were zero. These are local
synthetic combat measurements, not an extended memory-leak or live-headset test.
Godot still reports the previously observed single ObjectDB shutdown warning.
The older combat test still expected a chainsaw hit at 1.8 m, beyond the shortened
blade range; the baseline firing code fails it too. Its close-contact fixture now
uses 0.9 m. The dedicated out-of-range and parry tests pass.

Manual headset testing remains needed for gesture thresholds, button presentation,
haptic feel, and rocket-jump comfort on native SteamVR and WiVRn. No live headset
result is claimed by the automated controller simulation.

## Reproduce

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr_interactions.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/physical_rig.gd -- --client-config /tmp/physical-rig.cfg
python3 deathmatch/tests/run_physical_network_tests.py
godot --headless --xr-mode off --path . --script res://deathmatch/tests/assault.gd -- res://maps/as_hislop.bsp
godot --headless --xr-mode off --path . --script res://deathmatch/tests/server_load_audit.gd -- 16 --ticks 480 --memory --vr
```
