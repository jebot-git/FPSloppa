# Controls, demos and between-match lobby

Open **BINDINGS…** in the main/pause menu to reassign keyboard, mouse and VR controller actions, choose movement/turning stick roles, or reset bindings. Escape and the controller menu button remain recovery controls. Shared bindings activate both actions; the default support grip also serves push-to-talk.

**Two-handed aim** is enabled by default. Hold the support-hand grip near a non-pistol weapon's fore-end to align the weapon between your hands. Release to return to one-handed aiming. This changes orientation only: damage, spread, firing rate, ammunition and firing origin remain identical. Pistols and fists do not use this assistance.

**Physical jumping** is opt-in in **Settings → Controls → Bindings**. A quick upward headset movement while grounded requests the same jump as the jump button. It is disabled in seated mode, menus and when tracking is unavailable. Recenter after changing your standing height. Headset motion detection and controller comfort still need hardware testing.

## Demos and video

Open **DEMOS…** to record a match, browse recordings, or play one back. Files live in the external `demos/` directory. Recording works during VR play; playback uses desktop mode (`--xr-mode off`). Recordings contain player/VR poses and combat events, but do not contain voice chat, map files or VRM files. Install the same maps locally; unavailable avatars use the fallback model. Use matching game versions.

Playback offers first person, chase and free cameras, player switching, speed adjustment and seeking. Tab switches players; C changes camera; P pauses; Space also pauses outside free camera. Arrow keys seek five seconds. Free camera uses movement controls. Escape opens the menu.

To render a clip, install FFmpeg and use a graphical desktop session:

```sh
python3 tools/demo_video.py demos/match.fpsdemo --output video-output/match.mp4 --view chase --fps 60 --size 1920x1080 --start 10 --end 30
```

Use `--player ID` to follow a particular player, `--godot PATH` to select Godot, or `--client PATH` for an exported client. `--asset-root PATH` locates an external asset installation. The tool renders through Godot Movie Maker and encodes H.264/AAC MP4. Existing output files are not overwritten. Demos are bounded to 1 GiB and 200,000 frames (roughly 2 h 46 min at 20 Hz).

## Optional waiting lobby

In dedicated-server configuration:

```cfg
set sv_lobby "1"
set sv_lobby_seconds "45"
```

After a match's results screen, everyone enters an empty room with movement and voice chat, without weapons, pickups or damage. Use the wall-mounted ballot to select a mode first, then a map from that mode’s server maplist. A camera-based tracking mirror beside it shows your full avatar between matches. Each player has one changeable vote. The highest tally wins; ties favor the next rotation entry when available. With no votes, rotation supplies the next match. Late joiners can vote. The duration accepts 15–180 seconds.

The default is `sv_lobby "0"`, preserving regular menu voting and rotation. Offline practice does not use this lobby. Clients and server must share the updated network protocol.

## Server capacity and avatar browser

Dedicated servers accept `sv_maxclients "32"`; the default remains eight. **More than 16 players is unsupported. Performance, gameplay and maps are not balanced for player limits above 16.** A startup warning and joining-player announcement repeat this limitation. Menu hosting still allows eight players.

The VRM browser lists model metadata without loading previews. Select a model and press **USE THIS MODEL**, or explicitly press **LOAD SELECTED PREVIEW** to inspect it. The first explicit preview may still pause while Godot decodes the VRM; opening or browsing the menu avoids this work.

Demo playback accepts both the original seven-argument damage events and the eight-argument screen-only damage events recorded by 0.7v. This repairs otherwise complete VR recordings without changing the demo file format. Malformed/truncated frames remain rejected.

## Chainsaw contact and BFG splash

CC chainsaw reach on desktop is reduced from 1.2 m to 0.95 m; VR contact follows
the actual held blade with a 4 cm allowance at its tip. Other modes retain the
1.2 m desktop reach and use a 9 cm VR tip allowance. World geometry blocks cuts,
with a retracting local weapon model, sparks and spatial grinding sound. Bringing
two live players' chainsaw blades together before a body hit parries the attack,
deals no damage and imposes a 300 ms recovery on both players. Sparks and grinding
are throttled to one contact cue per player per 180 ms; demos retain the cue.

BFG detonations add a 9 m radial blast (200 damage at the centre, falling off with
distance) alongside the existing direct impact and 40-ray forward spray. Walls,
team damage policy and spawn protection still apply; the radial BFG component
excludes its owner. Rocket self-damage and rocket jumping are unchanged. This
is an arena-game adaptation, not an exact recreation of Doom II's BFG algorithm.
Clients and servers must use matching protocol `fpsloppa-22-saw-contacts` builds.

## Freeze-tag visibility

Frozen players become bright cyan ice statues, with a small ground ring and a
**FROZEN** marker above their heads. Teammate thawing changes the marker to a
percentage. The material replacement works across the bundled VRM shaders and
custom model materials; thawing restores the original override/overlay materials.
Changing avatars while frozen keeps the ice appearance. The effect is cosmetic
and does not alter collision, thaw range or team scoring. Frozen first-person
body parts also receive the ice material; the local ring and overhead label stay
hidden to avoid obstructing the headset view.
