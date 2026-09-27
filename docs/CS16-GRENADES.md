# DE grenades

DE has server-owned HE, flashbang and smoke equipment, available to both teams
in the preparation buy wheel's **GRENADES** category.

| Equipment | Price | Carry limit | Effect |
|---|---:|---:|---|
| HE | $300 | 1 | Up to 100 base damage, fading across 350 Quake units (10.94 m); walls shield players |
| Flashbang | $200 | 2 | Line-of-sight flash within 1500 units (46.88 m); looking away reduces intensity and duration |
| Smoke | $300 | 1 | Expanding 3.6 m cloud lasting 20 seconds, fading over the last three; blocks bot vision |

On desktop, press **4** during the live round to cycle owned grenades. Hold
**Fire** and release to throw; **Q** holsters it. In VR with physical interactions
enabled, reach beside/above the offhand shoulder and hold **offhand Grip + Trigger**
to draw the selected grenade. Selecting a type does not unequip the gun; the
actual shoulder grab draws it. Point the
free weapon hand along the aiming line, swing the grenade hand, then
**release Grip**. Releasing the trigger during a deliberate stroke also throws.
The free hand selects direction; the grenade-hand swing sets power. The
trajectory preview uses the same guidance calculation as the server. A gentle
stationary release drops the grenade without steering it. Both hands
are mirrored for left-handed players. No arm-mounted pouch is required.

Turn-stick **up/down** cycles forward/backward through owned HE/flash/smoke,
skipping empty slots. Return the stick to center for each selection. A primed
grenade cannot be changed mid-throw. The wheel also selects HE/flash/smoke
explicitly. Both controls set the preferred shoulder grenade while leaving the
gun equipped. Accepted changes show the grenade icon and name for 1.6 seconds
and update the persistent **SHOULDER** status entry, including while carrying
the bomb. The popup uses the replicated selection, so rejected requests do not
announce an unavailable type. Without a selection, the first owned type is used.
Grab the radio at its existing front shoulder position to use voice; the grenade
Grip + Trigger chord takes priority while drawing or holding utility.
Holding the gun's handguard or manipulating a reload prevents accidental grenade
arming from the same grip/trigger inputs. DE uses the line and trajectory arc,
without floating grenade instructions. Held grenades align their top with the
controller thumb axis and mirror the lever toward the palm, including remote
VR players and the primary-hand fallback.
Disabling physical interactions retains the primary trigger hold/release fallback.
The existing reliable TF action channel validates life/map/sequence, hand pose,
wall clearance and bounded stroke velocity. Selecting a gun holsters in-hand
utility without clearing the preferred shoulder type.

Desktop and the trigger fallback use a half-second pin delay. The TF gesture
uses its existing arm/release cadence. HE and flash use a 1.5-second
fuse starting on release; holding cannot cook a grenade. Smoke waits for the fuse
and landing. Grenades bounce against map collision. Opening a menu, death, stale
input or lost tracking cancels an in-hand throw without emitting a projectile.
Survivors retain unused utility; death and halftime clear it. New rounds clear
projectiles and effects. Bots buy utility, throw at visible enemies, avoid nearby
teammates, and respect flash/smoke visibility.

Flash affects the thrower and teammates. Headset orientation is used when
tracking is available. Desktop and per-eye XR overlays render flash and dense
smoke; outside clouds use soft animated billboards. These are affordable raster
effects, not volumetric fluid simulation. Physical headset comfort and stereo
occlusion still need hardware testing. The TF-style VR release gesture is implemented;
pulling an actual pin with the offhand is not.

The free-hand guide is an ExfilZone-inspired adaptation based on first-hand
[player descriptions of its aiming hand](https://steamcommunity.com/app/2719160/eventcomments/603028370888942328/?ctp=4)
and [motion-controlled throw strength](https://www.reddit.com/r/intotheradius/comments/1q1y7t2/small_compliant_about_grenades_in_itr_1_that_i/).
These are community observations, not an official mechanics specification.

Timers, prices, limits and directional flash behavior follow
[ReGameDLL_CS grenade code](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/ggrenade.cpp)
and [flash damage behavior](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/combat.cpp).
This uses FPSloppa's armor/friendly-fire rules and movement scale, so it is not an
exact GoldSrc damage/physics reproduction. Grenades do not yet drop as collectible
utility when killed. Grenade meshes, shaders and SVG shop icons are original.

Matching builds require protocol `fpsloppa-52-defuse-snip`. Utility snapshots are
optional in older recordings; new recordings preserve inventory, projectiles,
flash, smoke and burst events. Invalid snapshot positions, excessive inventory
and unknown burst kinds are rejected.

Validation: `defusal_grenades.gd`, `defusal_grenade_vr.gd`, `defusal_grenade_demo.gd`,
`python3 tools/run_defusal_grenades.py` (real local ENet server, two players,
late spectator; add `--tracked` for the TF-style VR RPC path), and `tools/classic_de/grenade_preview.gd` (native renders).
