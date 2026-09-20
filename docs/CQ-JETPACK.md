# CQ jetpack

The experimental CQ client now gives each living player a simple back-mounted twin-thruster jetpack. It works in both the whole-city and separate-district profiles. Ordinary modes have no jetpack.

Double-press the existing jump button within **300 ms**. The first press still performs the ordinary jump. Holding jump does not repeatedly activate the pack.

- With movement input, launch upwards and along that world-space movement direction. The boost has a curved trajectory, about **33 m** of horizontal travel and a **6.7 m** apex above the starting floor in an unobstructed level-ground test. Steering is limited to **18 degrees per second**, with no instant reversal.
- Without movement input, rise for **0.7 seconds**, hover until **1.5 seconds** after activation, then descend. Later movement input does not turn this stationary hover into a travelling boost.
- Cooldown is **8 seconds from activation**. It continues during flight. An active descent must finish before another boost can start. Landing retains at most ordinary running speed.
- Flight tracks actual horizontal path length, including turns, with a **48 m cap**. Launching from a tall ledge does not permit unlimited horizontal flight. Gravity and world/player collision remain active; walls and ceilings stop movement normally.
- Death, respawn and entry into the reinforcement waiting room clear the pack. Menus, prone stance, water, spectators and frozen players cannot initiate it. An already active flight continues through a menu with steering suppressed.

The existing desktop and VR status line shows readiness, flight/hover and remaining cooldown. Both use the existing jump action; there is no additional binding. The original generated model uses shared low-poly meshes, a dark metallic shell, cyan accents and two short exhaust cones. It adds no particles, realtime lights or collision/hit volumes. It is hidden from an ordinary first-person camera and visible on other players and visible local VR bodies.

## Authority and district transfers

Clients predict the same movement routine that the server runs. A life-scoped repeated input event preserves double-tap delivery when individual jump/release packets are lost; the server decides whether activation is legal. Acknowledged snapshots reconcile flight state and cooldown along with movement. Transfers include the trajectory heading, path budget, elapsed boost time and remaining cooldown. A restored life is marked as such before its first worker snapshot, preventing a transfer from being mistaken for a fresh spawn. Flight and cooldown pause during the existing frozen handoff/loading interval.

Update clients, master and workers together. Public CQ protocol is `fpsloppa-cq-experimental-4-jetpack`; the separate-map profile adds `-cq-district-bsp-1`. Actor transfer schema is **4**. Normal main-branch protocol is unchanged.

## Validation

`deathmatch/tests/cq_jetpack.gd` covers activation, cooldown, stationary hover, restricted steering, high-ledge range, wall/ceiling collision, disabled states, dropped input edges, stale-life rejection, prediction and transferred trajectory state. All 38 checks pass. With engine physics configured at 30/60/120 Hz, unobstructed travel measured 32.49/32.77/32.78 m and apex 6.81/6.73/6.72 m. See [physics measurements](validation/cq-jetpack-physics.json).

The existing network delivery, local prediction, landing, obstacle and frozen-gravity fixtures also pass. External-worker identity checks (23) and capacity/gate checks (24) pass. The console-only CQ district package builds and passes its resource audit.

The live fixture uses two real ENet clients, one master and four independently launched workers on loopback, with 30 ms added round-trip delay on each private master/worker connection. It exercises stationary hover, airborne gate transfer, cooldown after transfer, landing/return, suicide/respawn, stale generation rejection, match restart and fail-closed worker loss. All assertions passed; see the [network receipt](validation/cq-jetpack-network.json). Existing Godot ObjectDB/resource-in-use warnings remain at fixture shutdown. This is a local network integration test, not an Internet latency benchmark or a VR headset playtest.

```sh
python3 tools/cq_gateway/external_test.py \
  --binary Builds/CQDistrictMaps/FPSloppaServer.x86_64 \
  --district-maps --latency-ms 30 --name jetpack-final \
  --jetpack --respawn --failure
```

[Backpack and shared status-line render](validation/cq-jetpack.png). Render fixture: `tools/cq_jetpack/views.gd`. Existing map light bakes are unchanged; this feature adds no baked or dynamic lighting. Custom avatar fits and comfort/balance still need human desktop/VR playtesting.
