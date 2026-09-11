# FPSloppa 0.10v

Frigate joins the bundled Assault maps, alongside a revised HiSlop with separated
interior rooms and a working upper-terminal/lower-control-cabin sequence. This
release also addresses VR movement, weapon clearance, body tracking, lobby voting
and TF interactions reported during live testing.

## Maps and gameplay

- Frigate is an independently authored Assault adaptation with a dock approach,
  swimmable intake, destructible compressor, mess deck, locked bridge, two stair
  routes and a final gun-control objective. It uses original geometry and
  LibreQuake textures. Both Assault maps ship with baked lighting and navigation.
- HiSlop's interior layout, sludge escape and lobby transition are improved.
  Leaving Assault clears sentries and returns players inside the lobby.
- TF Spy defaults to disguise; active invisibility consumes cells. Physical melee
  only breaks disguise when it damages a target. VR fists use physical attacks.
- Engineer dispensers replenish ammunition as well as health. Turrets have clearer
  firing feedback, aim their barrel at targets and suppress overlapping pickups.
- Burning players receive visible fire effects. Jump pads have activation effects
  and sound; Hyperborea launch ramps work and teleporters allow telefrags.

## VR, controls and presentation

- Acknowledged client prediction reduces delayed jumps and correction jitter.
  Local avatar transforms follow the rendered VR origin, with limited local spring
  motion. Physical crouching, improved stair contacts and a water-surface escape
  jump complement gesture swimming in the view direction.
- Weapon clearance uses matching client/server checks. Hands through walls block
  firing, while clipped muzzles retract to permit close-wall combat and ground
  rockets. The short aim guide is easier to see past weapon models.
- VR TF/Assault interactions include physical repair, objective presses, offhand
  activation and gesture-based throws. Desktop interaction remains available.
- T-pose calibration accepts relaxed arms, modest head tilt and small tracking
  deviations after about 1.1 seconds, recenters first, then applies new tracker
  corrections with the existing confirmation jingle.
- Available headset face tracking can drive VRM expression presets; the Quest Pro
  WiVRn mirror test confirmed expressions and blinking on the selected avatar.
- Door opening and closing have mechanical SFX. Teleport activation sounds at
  both ends, using reliable feedback replication. Repeated door updates no longer
  restart animation or duplicate sound. Quitting stops active spatial effects
  before audio mixer teardown.
- Lobby boards display current votes and Yes/No choices. Binding dropdowns and
  VRM/BSP file navigation are improved. Microphone switching has additional capture
  safeguards; Windows includes `Diagnose-VR.cmd` for runtime troubleshooting.
- The new SloP application icon follows the GitHub title artwork. The full artwork
  remains GitHub/source documentation rather than an in-game title screen.

## Installation and compatibility

Use matching **0.10v clients and servers**, protocol
`fpsloppa-29-acknowledged-movement`. Android version code is **15**, preserving
the existing package IDs and signing identity. Downloads include Linux, Windows,
Linux dedicated server, Quest/Pico sideload APKs, source, Base Assets and the
maintained optional LibreQuake/author-created TF maps. Standalone users should
update the external Base Assets to receive both revised Assault maps.

The original forty-map Arena Collection and the ThreeWave, TeamFortress and
Arcane Dimensions conversion tools remain available **only in the 0.5v release**.
They are not bundled or maintained in subsequent releases and need no revision
unless the map loader or format changes. Restricted converted maps remain excluded.

## Validation and remaining limits

Source regressions cover both Assault maps, collision and movement, VR interactions,
calibration, environment feedback and independent ENet peers. The wearer confirmed
swimming, reduced jitter, map layout, lobby behavior and gun-wall collisions in the
recorded HiSlop test; the separate face-tracking lobby test was also confirmed.
See `docs/LAST_VR_REVIEW.md` and `docs/validation/release-0.10v.json` for the precise
scope and final build, binary, Android and archive checks.

Frigate still needs human route/balance testing. The latest sound and relaxed
calibration changes have automated coverage but no new wearer confirmation.
A minor HiSlop moving-wall visual inconsistency remains recorded. Existing isolated
Godot shutdown resource/OpenXR cleanup warnings remain. Windows and standalone
Quest/Pico builds have not been physically tested in this publication session.
