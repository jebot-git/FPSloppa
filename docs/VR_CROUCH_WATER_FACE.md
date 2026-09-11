# VR crouch, swimming and expression update

Based on 0.9v / `5105fb8`, alongside pending stair and physical-interaction fixes.
Current source protocol is `fpsloppa-29-acknowledged-movement`. Matching updated clients
and servers are required. No release has been built or published for these changes.

## Movement

Tracked crouch uses a standing calibration with 30/20 cm enter/exit hysteresis.
It defaults on, is disabled in seated mode, and is recalibrated by recentering.
The authoritative collider height is clamped to 0.80–1.65 m and cannot contradict
the supplied headset height. Shrinking preserves the feet; growing checks the
new upper volume against the world and other players. Hitscan rewind retains
historical height, swept projectiles cover height transitions, and grenade/melee
checks follow the shortened body. Snapshots and demos restore the collider.
Old recordings without height retain the standing capsule.

Arm strokes now supply thrust along the current headset forward axis. Looking
level does not cancel gravity; looking down dives and looking up ascends. Held
jump retains swimming-up behavior. One 7.4 m/s surface boost clears banks, with
0.18 s exit grace and 0.25 s protection against swim steering cancelling the boost.
Surface bobbing does not repeatedly rearm it; sustained deep immersion or a dry
landing does. The AS display name is simply **Assault**.

## Expressions

A small heuristic maps available native smile, frown, brow, eye-wide and jaw
weights onto one VRM preset at a time. Neutral input and jaw opening alone do not
invent an expression. Presets fade smoothly, peak at 0.65, and combine with the
existing eye and viseme morph writer to avoid overwriting shared shapes.
VRM 0.x joy/sorrow/fun aliases are supported. Missing presets are skipped;
material-only expressions are not implemented. Runtime availability and actual
headset behavior still need live verification.

Both `physical_crouch` and `face_expressions` persist under `[control_options]`.
Implementation follows the [Godot XRFaceTracker API](https://docs.godotengine.org/en/latest/classes/class_xrfacetracker.html)
and [VRM preset definitions](https://vrm.dev/vrm1/expression/).

## Validation

[Machine-readable results](validation/vr-crouch-water-face.json) include real
collision tunnels and overhead clearance, rewind and projectile equivalence,
a bank-exit A/B test, stroke direction and sinking, recorded/demo playback poses,
all three bundled avatar models, simulated full-rig input, and real two-process
ENet replication. These are automated tests, not a live headset acceptance test.

The local 16-player VR-plasma stress run measured 360 ticks after warmup: p50
4.464 ms, p95 5.320 ms, maximum 6.358 ms; snapshot p95 0.784 ms. Up to 562
projectiles were active. Sampled and post-cleanup orphan-node counts were zero.
This short synthetic run does not establish long-term leak freedom. Godot's
previously observed ObjectDB shutdown warning remains.
