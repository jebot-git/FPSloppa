# Optional arena jetpacks

Enable the experimental jetpack in a dedicated server configuration, then restart
the server:

```cfg
set sv_jetpacks "1"
```

The default is **0**, disabled. The option applies to **DM, TDM, CTF, IG, IF and
FT**, independently of the selected weapon loadout. It does not enable jetpacks
in KOTH, TF, Titanball, Assault or Chainsaw Circus. IG/IF retain their fixed
railgun loadout and continue to suppress ordinary map supplies and melee.

## Pickups and ownership

- DM/TDM/IG/IF/FT have **one jetpack pickup site per map**.
- CTF has **one site in each flag-base region**, at most two total. Either team
  can collect either pack.
- Collection uses the same respawn function as megahealth: **30 seconds in the
  current project**, counted from collection. This is separate from the pack's
  flight cooldown. Already equipped players cannot consume another pack.
- A pack lasts for the current life. Death, freezing and respawn remove it;
  jetpacks do not create death-drop pickups. Round and map changes reset them.
  Multiple players can own previously collected packs; the cap applies to sites.

The server places these additional sites near existing playable pickup locations,
preferring megahealth areas in non-CTF maps and each base's nearby supplies in CTF.
Floor and standing-capsule checks keep them out of walls, with separation from
other pickups. Authored spawn floors provide a fallback when collision has not
yet registered or no adjacent site fits. Existing BSP files and pickups are
retained. The authority transmits exact positions to clients and late joiners,
so renderer/import differences cannot produce different pickup indices.

## Flying

Double-press the existing **jump** control within **300 ms**: Space on desktop,
or the configured jump button in VR. Holding jump keeps its normal behavior.

With movement input, the pack launches a short arcing boost with limited steering
(18 degrees per second). The open-floor test measures about **33 m** of travel
and a **6.7 m** apex. Without movement input it lifts for 0.7 seconds, hovers until
1.5 seconds after activation, then descends. Hover steering is capped at 2 m/s.

The cooldown is **8 seconds from activation**. A flight must finish before
another can start. Actual horizontal path length is capped at 48 m, including
turns. World/player collision and gravity remain active. Landing limits retained
speed to ordinary running speed. Menus, stale input, prone stance, water, frozen
players and spectators cannot initiate flight. An existing flight continues
through a menu with steering suppressed.

The shared desktop/VR status line shows readiness, flight/hover and cooldown,
alongside CS reload status where applicable. Other players and a visible local
VR body show the back-mounted model; exhaust uses simple meshes, with no added
particles, dynamic lights or collision volumes.

## Implementation and validation

Physics and the original backpack mesh are ported from this repository's
`experimental/cq-districts` branch at `e847b0b`. The port introduces pickup-owned
equipment in the ordinary arena session; it does not import CQ workers, district
maps or transfer protocols. The original movement tuning is retained.

The server owns pickup collection and activation eligibility. Clients predict
the same physics. A life-scoped repeated event recovers double taps when raw
jump/release packets are lost; snapshots reconcile flight state and cooldown.
The event cannot grant ownership. Demo recording, playback and seeking preserve
the option, pickup layout, ownership and flight state; older demos remain readable.
Matching client/server protocol is
**`fpsloppa-44-defusal`**.

- `deathmatch/tests/jetpack_physics.gd`: boost/hover at 30/60/120 Hz, steering,
  cooldown, range, collisions, blocked states, input delivery and prediction.
- `deathmatch/tests/jetpack_pickups.gd`: config validation, all six supported and
  five excluded modes, contested pickups, megahealth timing, ownership and resets.
- `deathmatch/tests/jetpack_maps.gd`: shipped arena and CTF placement/capsule audit.
- `deathmatch/tests/jetpack_demo.gd`: production recording/playback, seeking,
  pickup visibility, old recordings and malformed-state rejection.
- `python3 tools/run_jetpack_network.py`: real ENet pilot plus late spectator,
  dropped press packets, prediction, pickup absence, ownership, death and mode
  transitions.
- `tools/jetpack_preview.gd`: native backpack, exhaust, pickup and shared HUD
  renders in `test-results/jetpacks/`.

Existing input delivery, prediction, stair/landing/obstacle, Instafreeze, ordinary
pickup lifecycle and CS physical-reload regressions are also checked. Physical-headset comfort and
competitive map balance still need human playtesting. No live server was deployed.
