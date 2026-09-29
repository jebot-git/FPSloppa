# ST integration with current main

29 September 2026: the checks below were performed on `experimental/st-raindance`
before its promotion into main. ST is now enabled in the main development checkout;
the published release is unchanged. Current network protocol:
`fpsloppa-68-st-native-main`. See [the promotion record](ST-MAIN-PROMOTION.md).

Post-promotion follow-up: [native integration audit and remaining performance opportunities](NATIVE-CURRENT-ST-STUDY.md), with current source/build checks, ST profiles and shared regression results.

Implemented next steps: [query batching, native ST steering and avatar channels](NATIVE-ST-BATCHES.md), with 16/32-avatar render tests and remote server comparisons.

Main and ST share base `8b19bd959e7dbf17cba1b201bb9f55d448f87614`. Main's newer
implementation was uncommitted, so this integration used a three-way comparison
against main's working files, preserving ST's existing committed and uncommitted
changes. Both sides and the common-base files were saved before editing under
`test-results/st-main-sync`. Of 183 incoming paths, 169 copied directly, 11 merged
automatically and three required resolution. The only excluded main file was
`--client-config.json`, a stray test-result document.

## Main changes retained

- Native avatar preparation/pose math, common bot perception/combat/steering,
  projectile processing, compact network codec and rewind helpers, including
  reference switches and platform build/packaging requirements.
- Render-frame pose, weapon and tracer smoothing; lighting, animation and
  frame-time optimisations; shared impact feedback and sound changes.
- Controller settings/preferences, CS offhand recoil compensation, reload and
  defusal posture changes, and their updated tests.
- DE geometry, collision, navigation and penetration updates, map registration,
  and CS map conversion tools. The changed Aztec, Nuke and Train BSP/navigation
  files were copied with their matching manifests.

Conflict resolution preserves ST vehicle damage, pilot weapon hiding,
PDA/remote-control input ownership, inventory refit semantics, armour culling,
mode/map configuration and the later carrier/navigation work.

## Integration corrections

The native common-combat loop now applies ST's jet-energy reserve rule between
weapon-selection ticks as well as during selection. A dedicated differential
test compares 54 armour/energy/weapon/carrier cases against GDScript, including
RNG, player, brain and team state. It passes 49,317 checks.

ST and other modes using the Tribes loadout keep their specialised trace path
for vehicles, equipment and beacons. Native projectile iteration and the shared
candidate grid remain available. The vehicle repair beam carries the owner ID
required by main's new impact RPC.

Uncached navigation baking no longer retains a GDScript lambda after the bot
controller can be freed. Completion is polled during bot ticks. The early-exit
shot-history and arsenal tests exposed a reproducible navigation-server shutdown
double-free; both exit normally after this change, including with native helpers
disabled.

## Targeting laser and beacons

Real weapon traces, field-menu requests, both dominant controller poses,
collision checks, team filtering, energy/cadence, repair/destruction and bot
artillery acquisition are covered by `deathmatch/tests/st_targeting.gd`.
`tools/tribes/test_targeting_network.py` drives one authority and three clients
through laser firing/release, beacon placement and enemy destruction, checking
the actual client models and guidance overlays. Native and reference runs pass.

Corrections found during this check:

- A fresh laser miss immediately removes the previous surface designation.
- Changing team invalidates the old team's designation.
- Target and aim labels maintain a small distance-independent angular size.
  Previously a target label at 100 metres was almost unreadable.
- The aiming symbol is centred separately from its caption, so the visible ring
  points at the calculated ballistic direction regardless of caption length.
- Map changes clear the previous target-selection preference.

The laser is an information tool. It shares the authoritative hit point; it does
not steer projectiles. Mortar and grenade-launcher cues include inherited motion,
arming time and collision-checked low/high trajectories. At short mortar ranges
the arming-time requirement can require a high arc, with its aim cue above the
horizontal view. Vulkan captures of the distant target and upward aim cue were
visually inspected. Beacons remain physical objects visible to both teams;
artillery guidance is restricted to the owning team.

## Validation and limits

The receipt records the 39-suite integration regression, additional ST/native
differential checks, Vulkan inventory/deployable/vehicle/PDA/armour tests, four-
process targeting/command/transport network checks and two 8v8 map runs:
[st-main-sync-2026-09-29.json](validation/st-main-sync-2026-09-29.json).

Native libraries build with matching source receipts for Linux client, Linux
server, Windows and Android arm64. Windows and Android are compile checks, not
device playtests. Linux tests use Godot 4.7.2; graphical checks use Vulkan mobile.
There is no new performance benchmark claim. Automated controller checks do not
establish headset ergonomics. Existing fixture ObjectDB/resource shutdown
warnings are recorded separately from assertion failures and crashes.

The headless map runs enforce both existing 600-second capture/pickup cutoffs.
They validate integrated runtime execution; they do not establish competitive
capture reliability. Both seed-9400 8v8 matches ended at the no-capture cutoff
without script errors:

| Map | Score | Flag pickups | Beacons placed | Laser designation updates | Bot mortar shots |
|---|---|---|---|---|---|
| Stonehenge | 0–0 | 11 | 7 | 0 | 31 |
| Raindance | 0–0 | 6 | 3 | 29 | 27 |

Mortar shots include other support targets; these counters do not prove every
shell was beacon-guided. The focused tests establish the actual shared-target
path. Capture reliability remains unresolved and should not be inferred from
successful integration tests.

The previously running empty Raindance test was refreshed in actual WiVRn v26.9
on Quest Pro with Vulkan. Startup reports `XR_READY OpenXR` and a ready practice
host with no bots. This verifies launch, not a new human interaction test.
