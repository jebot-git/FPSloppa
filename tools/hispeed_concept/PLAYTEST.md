# HiSpeed concept — local playtest, 2026-09-11

> These are historical concept-build results. The subsequent HiSlop multiroom
> rebuild, locked-cabin collision tests, sentry cleanup and live VR follow-up are
> documented in [HISLOP_VR_FOLLOWUP.md](../../docs/HISLOP_VR_FOLLOWUP.md).

Final BSP: `tf_hispeed_concept.bsp`, 2,027,812 bytes, BSP29.
SHA-256: `af9d23ae64f764b4ed768b6f297797665fbe707c8483a3d6d43ba1c3f2a1a495`.
Requires the current source version with protocol `fpsloppa-25-assault`.

## Results

- Full VIS: completed in 103.4 seconds. QBSP: no leak or discarded brush faces.
- Supersampled RGB bake: completed in 8.3 seconds; embedded BSPX RGBLIGHTING.
  Godot applied the bake to 5,800 faces, with **zero malformed face lightmaps
  and zero atlas overflow**. Compiler reports 380 empty lightmaps; this is not
  a claim that every brush side is illuminated. Sky/non-lit surfaces and hidden
  decorative geometry do not need a visible surface lightmap.
- Production collision traversal: all 21 spawn capsules clear, grounded and
  able to jump; jump-pad and control-door checks pass. No traversal failures or
  engine errors. The map has acid, but no swimming water, lifts or teleporters.
- Roof route: normal jump-pad launch, steering onto CAR 3, crossing roofs and
  dropping through CAR 1 hatch pass. No health or movement cheats.
- AS rule suite: ordered objectives; dead/spectator/defender restrictions;
  persistent cabin opening; checkpoints; pistol-only spawning; no TF classes;
  timed role swap; reset of sentries/door; win, loss and draw cases pass.
- Real ENet authority plus two clients: objective, role, time budget and sentry
  state replication pass. These are localhost functional tests, not WAN latency
  measurements or a full player-count load test.
- Current MToon: the chase review reproduced speckled hair/clothing highlights.
  Arena lighting disabled RIM but still included rim/matcap in its emission
  value. The fix keeps only authored emissive textures plus the arena fill;
  local direct lights still illuminate the model. A second fix prepares mipmaps
  for VRM colour/emission textures and samples them with anisotropic mip filtering.
  The final chase frames show smooth hair highlights and clean clothing shading.
- Rendered emission regression: changing rim/matcap produced mean RGB difference
  0.0000475 on Forward Mobile and 0 on Compatibility, while authored emission
  still changed output by more than 0.003. Tests allow <0.0001 for the former
  and require >0.001 for the latter. All sample_d/f/g dim/bright/warm/cool tests
  and texture mip-level checks pass. In-map stills cover deck, lower CAR 3 and
  upper CAR 1, using Forward Mobile on Intel ADL-N. No headset test was performed.
- Helicopter: rebuilt as convex BSP brushes with a sloping cockpit, long tapered
  tail, vertical/horizontal stabilizers, main/tail rotors, engine housing and
  landing skids. The troop bay and ramp retain the validated spawning route.
- Moving scenery: three scrolling materials and two non-colliding batched
  movers. The earlier motion test passed collision stability and the persisted
  disable/resume setting. Final playback retains that animation.

## Every static turret

Each emplacement was tested independently using the real targeting and damage
routine. Target positions were sampled on map floors with a clear player
capsule; no target was embedded in a wall to manufacture a successful hit.

| Turret | Location | Visible positions hit | Covered positions protected |
|---|---|---:|---:|
| 100000 | CAR 1 roof | 41/41 | 1/1 |
| 100001 | CAR 1 lower deck | 59/59 | 47/47 |
| 100002 | CAR 3 upper deck | 19/19 | 14/14 |

All visible probes received exactly 12 damage per shot. All three guns passed
friendly-team, spectator, dead-player, spawn-protection, 0.5-second cooldown and
opposite-attacker-team checks. None shot through the tested map solids. The
shared weapon trace/destruction checks also pass. Source:
`deathmatch/tests/assault.gd`; raw results: `test-results/hispeed-sentries.json`.

## Recorded paired assault

`playthrough-05.fpsdemo`: 105.07 seconds. A scripted driver supplies normal
movement/aim/fire input through the production server simulation. Players start
with the pistol and obtain other weapons, armor and ammunition from real map
pickups. Turrets remain active and damage the players; no god mode or weapon
injection is used. The non-attacking player is passive. This tests a playable
route with real combat, not autonomous bot competence or human team balance.

Red completed both objectives in 47.02 seconds. Roles swapped at recording time
55.05 seconds. Blue activated the upper switch but timed out before completing
the lower console: **Red wins 1–0**. Neither player died; Red fired 53 shots and
Blue 69. Blue ended with 34 HP; Red's reported 100 HP is its fresh defending
spawn after the swap, not proof that Red took no damage during the attack.

The three main MP4s show this same recorded match at 1440×900 / 30 FPS, following the
current attacker: first-person, chase, and trackside/interior director cameras.
Open `index.html` to compare the videos and helicopter/VRM stills. MovieMaker
rendering speed is not a headset performance benchmark. Earlier failed or
superseded recordings/renders remain under `test-results/hispeed-video` and are
not included as final comparison videos.

## Additional VRM chase recording

The mode picker now reads **Assault**. `playthrough-vrm-06.fpsdemo` is a
separate 110.08-second paired assault with explicitly selected **VRoid Sample D**
for Red and **VRoid Sample F** for Blue. This recording retains model hashes;
playback logs confirm both full VRM rigs load, rather than fallback marines.
Red finishes in 50.18 seconds; Blue finishes its return attack faster and wins
0–1. Both have zero deaths; Blue ends with 40 HP. Weapon damage and sentries
remain active. VRM files stay in the game's external `vrm` folder and are not
copied into this map addon.

The additional `videos/vrm-final/hispeed-as-vrm-chase.mp4` uses Forward Mobile,
a 55-degree chase-camera FOV, and records the same route after both shading
fixes. Inspection stills at 10, 25, 40, 60, 75 and 90 seconds cover both avatars,
the freight section, map-light transitions and cabins. Camera occlusion still
shortens the chase distance near obstacles; this is existing chase behavior.
No camera shake or artificial lighting is introduced for this review.

## Limits

No Quest/Pico or stereo PCVR test was performed for this revision. Desktop
screenshots cannot establish that every imported VRM renders correctly. No
72-FPS or multiplayer balance claim is made. Existing Godot ObjectDB cleanup
warnings remain at test shutdown; there were no gameplay script errors in the
passing tests. This is a local experimental concept, not a published release.
