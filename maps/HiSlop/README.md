# HiSlop release map

The concept is now bundled as **HiSlop** (`as_hislop`) in release 0.9v.
See [AS.md](../../AS.md) for current server setup. The generator now emits
`as_hislop.bsp`; historical test recordings below retain their original filename.

# HiSpeed BSP29 concept

An approximate, newly constructed brush reconstruction of the train-hijack layout
of UT99 **AS-HiSpeed**, originally designed by Juan Pancho “XceptOne” Eekels.
This is an experimental gameplay/layout study, with FPSloppa-native AS rules.
Dimensions and several routes are adapted to FPSloppa's movement. Recommended
initial playtest: 4–10 players; **AS**, seven minutes per opening assault.

## Play

Copy `maps/as_hislop.bsp` into the game's external `maps` directory,
then select **Assault** and this map. It supports both AS and the TF adapter.
From the Godot project:

```sh
./run.sh --xr-mode off -- --import-map ../Builds/HiSpeed-Concept/maps/as_hislop.bsp --practice --mode as
```

For a dedicated server, install the BSP in its maps directory and launch with
`--config` pointing to the included `hispeed-as.cfg`. The config supplies the
separate `as_maplist`. Historical concept guidance was to keep this out of production until
human multiplayer testing is complete. AS requires the updated source/build
(protocol `fpsloppa-25-assault`); an older client can still explore the BSP in TF.

**Red attacks first from the rear helicopter.** Cross the empty flatbed,
containers, beam wagon and acid tanker, then CAR 3 → CAR 2 → CAR 1. Touch the
upper control switch, then descend and touch the lower control console.
The upper switch unlocks the cabin door, persists after death, and is required
before the final console can activate. The passenger, supply, equipment and switch
rooms have offset doorways. Return down CAR 1’s stairs through the lower vestibule
and service passage to the cabin. Its door slides into the bulkhead; sealed side
windows, locomotive end and continuous upper floor prevent entering around or
above the lock. The roof hatch reaches the upper switch room only. Entry
checkpoints advance future spawns outside the locked cabin.

**Blue defends first.** Three map-owned sentries use the existing TF turret
combat, damage and rendering routines. They can be shot and destroyed, never
shoot defenders, and reset for the new defending team after the role swap.
Players have no classes, class abilities, engineer construction or TF resupply.
Everyone starts with the normal pistol, 100 HP and normal movement speed; collect
Doom-style weapons, ammo, armor and health along the train.

After the first assault completes or times out, the teams swap roles after an
8-second break. Team colours and players' frag statistics stay the same. If Red
finished, Blue must beat Red's completion time. If Red failed, Blue gets the full
configured time. Blue completing faster wins; Red holding out after completing
wins; neither team completing is a draw. Map rotation/lobby waits until both
legs finish. The HUD identifies attackers, leg number and the current objective.

Green-lit jump pads replace jump boots. They launch vertically; steer toward the
roof. CAR 1 has a roof hatch. The acid tank damages players; falling onto the
tracks is lethal. The helicopter and locomotive are newly built brush geometry.

TF remains an alternative concept adapter: steal the upper blue access-token
flag and deliver it to the lower red capture console. Blue can counterattack the
helicopter flag. In TF, engineers build their own guns at the mounting pads.

## Moving scenery and VR

The outer cutting textures, track texture and rails scroll backwards. Two
batched, non-solid brush models move the repeating sleepers and wall supports,
creating the moving-train illusion without translating players, the train,
weapons or collision geometry. Speed is 640 Quake units/s (20 game metres/s),
chosen as a visual adaptation rather than the original fiction's train speed.
Static lightmaps stay fixed while the surface texture moves through them.

Settings → Controls → **TRAIN SCENERY MOTION** disables/re-enables it immediately
and persists the preference. Animation is cosmetic and local; it creates no
server simulation, networking traffic or motion of hitboxes. Headless servers
skip the animation component. There is no artificial camera shake or motion blur.

## Concept limitations

- This is not a measured or extracted UE map. Some proportions, scenery,
  supplies, hatch access and turret positions differ from retail HiSpeed.
- AS currently requires two ordered touch objectives. It does not implement
  arbitrary UnrealScript/QuakeC objectives, destructible reactors, or every UT map.
- Jump pads replace carried boots. No original UT weapons, music, rotor damage,
  train ambience, wind physics or textures are included.
- Bot goal selection recognizes AS objectives, but the video uses a scripted
  route driver. This is not a claim that autonomous bots solve the whole map.
- Automated collision, combat and multiplayer tests do not establish human
  balance or 72 FPS on Quest/Pico. No hardware performance claim is made.

## Rebuild

```sh
python3 tools/hispeed_concept/build.py \
  --wad-dir /path/to/LibreQuake/dev/texture-wads \
  --compiler-dir /path/to/ericw-tools/bin
```

For a geometry-only rebuild, the installed map can supply its exact embedded
LibreQuake textures without downloading the original WAD collection:

```sh
python3 tools/hispeed_concept/build.py \
  --reuse-textures maps/as_hislop.bsp \
  --compiler-dir /path/to/ericw-tools/bin \
  --output test-results/hislop-interior/build
```

This verifies every texture against `maps/HiSlop/texture-sources.json` and copies
its existing license files. New textures still require the original WAD inputs.
After installing the new BSP, run `tools/hispeed_concept/bake_base.gd` to replace
both scene caches and bot navigation, and update the map catalog SHA-256.

Output defaults to `../Builds/HiSpeed-Concept`. The package contains editable
Quake `.map` source, a subset WAD, texture provenance, compiler logs, config and a
BSP29 with embedded textures and BSPX RGB lighting. The AS and scenery additions use ordinary Godot scripts; no new plugins are
required. Run full VIS and supersampled lighting; do not substitute BSP2. The iteration-only
`--fast-vis` option preserves conservative visibility but renders more faces.

## References and visual inspection

Research performed 2026-09-11. Descriptions establish the route and objectives;
scale and brush dimensions are inferred rather than measured from UE geometry.

- [Unreal Archive / Liandri Archives: AS-HiSpeed](https://unrealarchive.org/wikis/the-liandri-archives/AS-HiSpeed.html): author, seven-wagon sequence and two-stage objective.
- [GameSpot guide, hosted by PlanetUnreal](https://planetunreal.gamespy.com/View5604.html?id=95&view=UTGameInfo.Detail): roof shortcut, defensive positions and powerup routing.
- [Unreal Wiki](https://unreal.fandom.com/wiki/AS-HiSpeed): PC/console/beta differences; the PC retail version is the reference.
- [PC retail gameplay: Mission 33 Assault High Speed](https://www.youtube.com/watch?v=VFYeff8q-D8): inspected public 320×180 storyboard frames, sheets 0–4, 8 and 12 (approximately 0–220, 360–400 and 540–580 seconds). Observations: alternating cargo obstacles, exposed narrow sides, cool cyan interiors, inset windows, yellow lamps/hazard strips, stairs, stacked crates and a dark cutting. Full video download returned HTTP 403, so this is frame inspection rather than continuous playback analysis.
- [Beta 222 footage](https://www.youtube.com/watch?v=g38WHXmSzrg) and [prototype 221 walkthrough](https://www.youtube.com/watch?v=qZU17hVI5-I): metadata/descriptions only. Beta-specific lifts and wind behavior were not assumed to apply to retail.

AS timing reference: [UT99 manual](https://medor.no-ip.org/UT_Demo/docslide.us_unreal-tournament-game-of-the-year-manual.pdf)
and [original-game strategy guide](https://gamefaqs.gamespot.com/pc/191945-unreal-tournament-1999/faqs/29387),
which describe switching roles and beating the first attack's completion time.

## Playtest and videos

See `PLAYTEST.md` for the final BSP hash, tests, limitations and recording results.
The MP4 files show the same recorded paired assault from first-person, chase and
trackside/interior cameras; the selected player follows the current attacking
team. They contain FPSloppa footage, not copied UT footage. Compare the freight
section, CAR interiors, roof and control-room sequence to the linked retail video.

Reference images and videos are not redistributed with this package. No UT
textures, models, sounds, music or original map data are included. All embedded
textures come from LibreQuake; retain `licenses/` and `texture-sources.json` when
sharing its art. Newly authored generator code is CC0-1.0; that dedication does
not grant rights to Epic's original map design, name or other Unreal IP. This
concept makes no claim to be official or to have Epic's endorsement.
