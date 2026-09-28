# DE — Bomb Defusal

Select **DE — BOMB DEFUSAL** in Host/Practice or set `sv_gametype "de"` on a
server. DE forces the existing CS16 arsenal. Choose Dust2, Nuke, Inferno, Aztec
or Train from the supported BSP29 reconstructions. See [Dust2 notes](../maps/Dust2Rebuilt/README.md)
and [the four additional maps](../maps/ClassicDE/README.md) for fidelity limits.
The [cover, decoration and interaction audit](DE-MAP-FIDELITY.md) records
remaining differences and the implementation path for original doors and wall penetration.
Matching clients and server require **`fpsloppa-52-defuse-snip`**.

```cfg
set sv_gametype "de"
map de_nuke_rebuilt
set sv_de_prepare "15"
set sv_de_roundtime "120"
set sv_de_bombtime "45"
set sv_de_winlimit "16"
```

Timers are in seconds. Preparation accepts 5–60, live rounds 30–600, and the
bomb fuse 10–90. The win limit accepts 1–30. Add `de` to `sv_gametypes` when
allowing mode votes. DE's map/loadout selectors are restricted automatically;
normal arena rotations and the default server mode stay as configured.
All five maps are included in the base-asset selection for subsequent builds. Rebuild
the internal installer with `tools/build_base_assets.py` before packaging.

## Rounds and economy

Both teams must be present. Preparation freezes movement and combat while
players buy at their spawn; weapon reloads remain available. Each round has one life; late arrivals wait for the
next preparation. Dead players return with a knife, Glock (T) or USP (CT), and
60 shared pistol rounds. Survivors retain weapons, ammunition, armor and kits.
Default matches switch roles after 15 rounds, reset pistol-round cash/equipment,
and finish at 16 wins or 30 completed rounds (a 15–15 draw is possible).
RED/BLUE remain the same teams across the role switch.

Killed players and late arrivals can free-fly until the next round: **WASD**
and **Space/Ctrl** on desktop, or movement stick and turn-stick up/down in VR.
This moves only the camera; the corpse, team and next-round spawn stay intact.
The dead cannot fire, interact with objectives, buy, or force a respawn.

Built-in voice separates living players from dead players and spectators in
both directions. All dead players, across both teams, share one non-positional
channel; either PTT control speaks to that channel. Living proximity/team radio
keeps its normal routing among living players. Text chat uses the same boundary
and marks dead messages **[DEAD]**. The server selects recipients, and clients
discard old audio streams and stale life/round packets at transitions.
External Mumble/Discord calls are separate applications and are not controlled
by this routing; use built-in voice for automatic DE separation.

Players start with $800, capped at $16,000. The shop allows one primary, one
sidearm and the knife. Buying a replacement drops the old gun with its loaded
ammunition; ordinary arena supplies and jetpacks are disabled. Press **Use** near
a dropped gun to pick it up. A weapon already in that slot drops on the ground
with its loaded rounds, including when exchanging two guns of the same model.
The other slot stays equipped, and walking over a gun does not collect it.
Both players and bots retain at most one primary and one pistol across purchases,
pickups and surviving round transitions. Surplus guns inherited from older
sessions are dropped at the next round start, keeping the equipped gun first.
Replacement drops share the global 64-gun pool cap.
If the bomb carrier dies, the bomb drops at the body with its arming progress
cleared. Another living terrorist can recover it with **Use** or a tracked-hand
grip in VR. Recovery attaches it to the chest slot without putting it in the hand;
draw it from the chest to arm and plant it normally. A recoverable bomb takes priority
over nearby dropped guns, with a **RECOVER BOMB** prompt. Counter-terrorists,
dead players and spectators cannot collect it; range and wall checks still apply.
Desktop uses **E** by default; VR uses its bound **Use** button. The AK is T-only; M4 and cutters
are CT-only. Weapon prices follow the existing CS counterparts: Glock $400,
USP $500, Deagle $650, M3 $1700, XM1014 $3000, MP5 $1500, AK $2500, M4 $3100,
M249 $5750, AWP $4750, P90 $2350. Kevlar costs $650, vest/helmet $1000 and
cutters $200. Each primary/sidearm ammunition purchase adds one magazine for $60.

The implemented gun distribution follows CS 1.6's normal defusal buy rules:

| Purchase access | Implemented guns |
|---|---|
| Terrorists only | AK-47 |
| Counter-Terrorists only | M4A1 |
| Both teams | Glock-18, USP, Desert Eagle, M3, XM1014, MP5 Navy, P90, M249, AWP |

Glock and USP are both purchasable by either team; starting pistols remain
Glock for T and USP for CT. Defuse cutters are CT-only. The buy wheel, authority
and bots use one explicit policy, which follows the T/CT role at halftime.
Picked-up enemy guns can be used by either side. This table covers the existing
arsenal; the remaining CS 1.6 gun models are not present. Reference:
[ReGameDLL's non-VIP purchase rules](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/weapontype.cpp#L618).

Elimination pays the winning team $3000 per player; explosion pays $3500;
defusal or time expiry pays $3250. Losses pay $1400, increasing $500 per
consecutive loss to $3000. A losing T side that planted gains another $800.
Surviving attackers get no loss payment on unplanted time expiry. Kills pay
$300; team kills deduct $3300 if friendly fire is enabled. The planter/defuser
gets $300. Rewards and purchases are server-owned and capped.

T wins by eliminating CT or detonating. CT wins by eliminating T before a plant,
letting an unplanted round expire, or defusing. Eliminating T after planting
leaves the fuse running. The result stays visible for five seconds before the
next preparation. Disconnects and deaths release a recoverable bomb.

The rules use [ReGameDLL_CS reward constants](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/gamerules.h)
and a [Pavlov-inspired keypad/cutter interaction](https://pavlovwiki.com/index.php/Gamemodes#Search_and_Destroy).
This is a hybrid using FPSloppa movement, damage/armor, shared ammo pools, the
existing twelve CS weapons, and its melee/reload/scope systems. It does not add
exact per-caliber reserve prices or CS armor/headshot behavior.

HE, flash and smoke are available in the GRENADES buy category. Desktop uses
**4** to select, hold/release Fire to throw and **Q** to holster; VR uses the weapon
wheel and TF-style offhand Grip + Trigger, swing and Grip release. See [grenade behavior and controls](CS16-GRENADES.md).

## Buying and bomb controls

In VR, press the right stick during preparation to open the purchase wheel.
The compact panel follows the dominant hand and faces the player, including
while navigating purchase categories.
Tilt and release to select a category or buy an affordable item; the shop stays
open for further purchases. **BACK** returns to categories; pressing the stick
again closes it. Live rounds restore the ordinary weapon-selection wheel.
Desktop uses **B**, then a mouse click or the shown radial order with **1–9**;
**B/Esc** closes it. Cash and purchase notices are visible in the wheel/HUD.

Each round announces the local player's **terrorist** or **counter-terrorist**
role, including side swaps and players joining a live round. Spectators receive
no team assignment. Completing a plant broadcasts a short confirmation chirp
and **“The bomb has been planted.”** to both teams. Every round outcome announces
**“Terrorists win”** or **“Counter terrorists win”**, using the current roles
rather than fixed red/blue teams. Dead players and spectators hear the global
plant/result calls too; these bypass distance attenuation and take priority over
kill awards. The existing announcer volume and `sv_announcer` switch apply.
The bomb's nearby countdown beep remains positional. Global calls are recorded
in demos, and team calls follow the selected replay player's role. Generated
voice assets and regeneration details: [DE audio sources](../deathmatch/audio/announcer/DE-SOURCES.md).

The bomb sits at 40% scale on the carrier's chest, with its keypad facing outward.
Grab it with the gun-hand grip to stash the gun and draw the full-size bomb,
offset above and beside the gripping hand so all keys remain accessible.
Keep holding grip and press the displayed digit four times with the free hand's
visible index fingertip; a wrong digit resets the sequence. Each key uses its
actual keycap bounds with a 5 mm fingertip radius. Withdraw the finger before
pressing again; brushing sideways or squeezing a controller trigger cannot type.
Once armed, there are five seconds to press the
**back of the bomb** against a floor, crate, or wall within A or B. The whole
backing must fit on one solid surface within reach. It attaches with the keypad
facing outward; there are no stands or fixed planting sockets. Releasing grip
returns the bomb to the chest and restores the gun. **Press Use while holding
the bomb to drop it explicitly.** Recovery equips the chest slot. The server
derives placement and keypad contacts from validated tracking and world
collision, including left-handed controls.

All five DE maps identify A/B using wall and floor markings. No floating letters
or guide text mark a plant point. The bomb also has no floating instruction text.
Its physical keypad/display and valid-surface outline remain available.

A CT can touch the displayed eight-digit sequence to defuse. A purchased kit
attaches tweezers to the gun-hand side of the chest. Grab them with that hand's
grip to stash the gun, put the tip on an exposed wire loop, then press the
trigger to cut. Each wire requires a fresh trigger press while touching it.
Every fresh squeeze closes and reopens the tweezer jaws with a short mechanical
snip, including practice squeezes away from a wire. Holding the trigger does not
repeat it. Accepted cuts and dry snips replicate to other players and demos;
desktop and bot wire cuts produce the same feedback.
Releasing grip returns the tweezers to the chest and restores the gun. Leaving
reach, dying, opening a menu, losing fresh input or abandoning contact interrupts
the attempt. Only one
player can work on the bomb at a time. Both chest attachments use the pouch's
tracked hip heading and follow torso lean toward the head. Both mount points sit
8 cm lower along that torso frame to keep them away from normal aiming grips; without hip tracking
they use the existing inferred hip frame. The fuse beeps faster as it expires.

Desktop **E/Use** draws the carried bomb; type displayed digits using **0–9**.
Use again while armed to mount it on the nearby aimed surface, or on the floor
in front if no surface is aimed at. **G** drops a held bomb. Near a planted bomb,
Use starts defusal/equips purchased cutters; type displayed digits or use
**J/K/L** for the three wires. These are accessibility equivalents using the
same authoritative reach, phase, timing and equipment checks.

## Optional CS virtual stock

**Settings → Controls → VR Controls → CS VIRTUAL STOCK** toggles a saved option,
off by default. Hold a CS long gun with two hands and bring the firing hand near
the inferred shoulder to stabilize its direction. Knife and pistols bypass it.
The existing two-hand support grip is required; release, physical reload,
tracking loss, menus, the weapon wheel and bomb interaction disengage it.
The muzzle position is unchanged. This is a basic shoulder constraint. On
2026-09-27 the user reported that the empty Quest Pro/WiVRn virtual-stock test
passed; this does not establish calibration or comfort for every headset.
See [the test receipt](validation/virtual-stock-2026-09-27.json).

## Assets and validation

DE plays **Copper Fuse**, an original 102.4-second orchestral action loop at 150 BPM
with strings, brass, timpani and orchestral percussion, editable in MilkyTracker.
Its 24-channel XM source renders to 44.1 kHz stereo playback. It follows the
existing music volume control; [score, sources and regeneration](audio/copper-fuse/README.md).

The bomb chassis and cutters are original Blender-authored props; runtime
labels, keys and wire contacts share the same measured coordinates. See
[asset sources](../deathmatch/pickups/defusal/SOURCES.md). No CS or Pavlov retail
models, textures or sounds are included. The beep is synthesized locally.

Regression scripts are `deathmatch/tests/defusal*.gd`. They cover round rules,
buy authority, stale requests, floor/wall placement, invalid surfaces, chest
attachment, tracked-hand contacts, left-handed cutting, menu interruption,
virtual stock, bot purchases/navigation/objectives, and replay validation.
`python3 tools/run_defusal_network.py` runs a real local ENet server, two players
and a late spectator through both sites and both defusal methods; run
`defusal_demo.gd` afterward to validate that recording and seeking. Native
renders use `tools/defusal_preview.gd`.

`python3 tools/run_defusal_voice.py` tests dead/living routing over real ENet
with Opus audio, including an explicit spectator. `defusal_observer.gd` covers
camera movement, VR flight, the communication matrix and queued-audio cleanup.

`godot --headless --xr-mode off --path . --script tools/record_defusal_match.gd`
runs a real-time, first-to-16 6v6 bot match on local port 28986 and writes a
timestamped `recordings/de-6v6-*/match.fpsdemo` plus a JSON round/score receipt.
Spectators can connect to `127.0.0.1:28986` without replacing a bot. Open the
finished recording in the in-game replay browser, or use
`godot --path . -- --demo /absolute/path/to/match.fpsdemo`.

The completed 2026-09-26 recording is
`recordings/de-6v6-2026-09-26T17-25-40/match.fpsdemo`: Blue won 16–13 in
29 rounds over 25:21.55. All 30,432 frames passed production validation with
six bots on each team; replay opening and seeking also passed. A native
spectator client was attached during play. This match started before the later
Use-to-swap pickup change; that behavior was verified separately by the pickup
regression suite.

The [validation receipt](validation/defusal-2026-09-26.json) records 416 DE checks,
25 gameplay and 17 voice local ENet checks, plus related regression and
master-directory tests.
Results and renders are under `test-results/defusal/`. These checks do not replace
real-headset playtesting or full-match multiplayer balancing. No deployment is
performed by the tests.

The [classic DE expansion receipt](validation/classic-de-2026-09-26.json) records
the four-map route/objective audits, grenade network/replay checks and XM revision.

The later [five-map live series](../recordings/de-map-series-2026-09-26/index.html)
tests the current expanded maps and gameplay with twelve autonomous bots and a
native ENet spectator. Each map ran six rounds in real time, switching roles
after round three. Videos contain the game viewport and its own audio at
1280×720/30 fps. Red:Blue scores were Dust2 3:3, Nuke 2:4, Inferno 3:3, Aztec 4:2
and Train 5:1. Production DE still defaults to first-to-16; the shorter format
is isolated in the test tools.

All 26,770 recorded states passed roster, round, role-switch and replay checks;
all five MP4 audio/video streams decoded successfully. Both bomb sites saw
plants on every map, with HE and flash usage captured. Bots did not throw smoke
in these sessions, so these recordings provide no live smoke coverage. Native
logs retain interpolation warnings and exit cleanup diagnostics, including two
resources still in use at Inferno shutdown; no GDScript errors occurred.
The [live-series receipt](validation/de-live-series-2026-09-26.json) includes
map/video checksums, round outcomes, capture metrics and limitations. These local
desktop bot runs do not measure headset performance or human multiplayer balance.

Map-specific bot lanes, entrance holds, bomb recovery/defuse roles and their
CS 1.6 references are documented in the [map and tactics study](CS16-MAP-TACTICS-STUDY.md).
