# rec1 CQ rendering and interaction fixes — 15 October 2026

Branch: `experimental/cq-voxelspace`, worktree `.worktrees/cq-voxelspace`. Inspected Downloads/rec1.mp4, including the 3:37 carry reference, the dark-world sequence from 4:50 onwards, and the end-of-video entrance and ceiling fixtures. Timestamped contact sheets and selected full frames are retained here.

## Rendering diagnosis and changes

The earlier UI exemption moved NVG to the post-sky compositor stage, before transparent UI. That single-sample compute write is overwritten by a later resolve when the live client's 4× MSAA is active. A rendered reproduction with 4× MSAA failed before the change. NVG now temporarily uses single-sample rendering with FXAA, then restores the user's MSAA setting on deactivation. It still runs before transparent UI. New GPU checks test near UI planes at 8 cm, 30 cm and 1.5 m: the panel retains blue UI colours and the surrounding world retains green NVG. The UI plane did not reproduce full-field overwriting in those checks. This is an explicit anti-aliasing tradeoff while NVG is active; native stereo confirmation is deferred.

Local gloves use ORMMaterial3D, which the old baked-light converter skipped. The converter now covers BaseMaterial3D (including ORM) and per-surface overrides. Local hands, carried grenades and shoulder equipment receive the world bake rather than relying on the disabled dynamic lights. Rendered checks verify hand/grenade illumination without ambient or dynamic scene lights.

NVG visor interaction accepts either hand at natural forehead height, with bounded reach and existing authority freshness/cooldown checks. A visor trigger suppresses weapon fire.

## Weapon and equipment changes

- Restored the original support-shoulder radio anchor and placed the grenade at its exact mirrored anchor. Both hands can grip either kit. The grenade uses the main CS held pose.
- Corrected grenade guidance: the free aiming hand supplies launch direction, while the throwing hand supplies power. The native authority already implemented the guided ballistic rule; the client had overwritten the aiming basis with the grenade hand. The held grenade now presents main CS's free-hand aiming line. This line is distinct from the removed gun aiming aids.
- Ported main CS's support latch and smoothing to CQ, including scout primary pistols. The support hand snaps to the authored fore-end/pistol anchor. Primary hand visuals follow the held gun and recoil. Pistol support grip is distinguished from deliberately grabbing the slide.
- Rifles' charging handles now touch their receiver and share physical anchors. Pistols have no separate charging handle: the visible slide moves and locks back. Reload visuals update directly in the local rig; ejected inserted-magazine meshes hide, and duplicate local remote-magazine visuals are suppressed. Coaching labels and all CQ gun aiming-aid lasers are removed; the carried-magazine round readout remains.
- The red dot is fixed at the optical window centre. Rendered checks place the red dot at the optical centre, confirm the pistol front and rear iron tops share a plane within 0.1 mm, and verify that scope axes are parallel to their authored bores. Magazine/slide state checks also pass. Existing muzzle/sight metadata remain aligned to the authored weapon axis; perceived sight comfort remains for the next headset test.
- Chest carry now turns the barrel across the torso to match the 3:37 reference instead of rotating only around the forward axis.
- The actual designator presents its targeting beam immediately while held. Scout cloak/recon use a distinct device and do not equip or fire the designator. Local hands, carried weapons and equipment receive the same cloak dissolve shader family as the avatar.

The scout device reuses [Energy Pipe by musdasch](https://opengameart.org/content/energy-pipe), CC0. Headless Blender 4.5.9 reduced the 638-triangle source (including shine billboard) to 374 triangles, two opaque material surfaces and a 256×256 texture. It is 18 cm tall. Removed the shine billboard, redundant hidden inner cylinder and transparent layering; retained outer profile and UVs. The cyan energy shell remains legible at night. Blender MCP was unavailable; the reproducible conversion script and source archive are in tools/cloak_device, excluded from deployment packages. Runtime provenance is in deathmatch/models/cloak_device/SOURCES.md and manifest.json.

## Movement, buildings and vehicles

The client already had bounded step-up sweeps, but the native movement host only used move-and-slide/floor snapping. Native CQ now ports the up/forward/down step sweeps, including ceiling, landing-slope, actor and maximum-rise rejection. The successful sweep consumes horizontal travel once. This addresses threshold blocking and the corresponding client/server corrections. All 72 authored entrances pass a full-map client traversal probe using a standing 2 m collider without crouching or jumping; existing doorway geometry did not require another scale increase.

Staging players were also entering the on-foot prediction path despite being spectators. They now skip that simulation, addressing an additional initial-deployment jitter source. Physical perceived stability is not claimed as confirmed.

Hanging fixtures were being placed in open stairwells. They now move to intact ceiling slabs. All 220 hanging attachments pass geometric checks. Lighting was rebaked: 154,360 vertices and 384 fixtures.

VR tanks retain the normal world/eye cameras and lighting, with a world-projected bore crosshair. They do not create the desktop SubViewport/screen feed. The local tank hull is hidden from its driver's view and restored on dismount. Desktop vehicle rendering remains available. The automated fixture verifies camera preservation and crosshair geometry; an actual headset drive is deferred.

## Validation and delivery

- Native golden and ASan/UBSan: **910,302 checks** each.
- Existing Jolt authority/VR/entity/terrain/transport fixtures: **33,993 checks**.
- New native Jolt step fixture: **174 checks**, including a 30 cm standing threshold, rejection of an 80 cm obstacle, and rejection below a low ceiling.
- Full-map standing doorway probe: **72 entrances**.
- NVG/MSAA/near-UI render fixture: **20 checks**.
- Lighting, cloak, support grip, cell and ceiling render fixture: **239 checks**.
- Optic/reload/transport render fixture: **56 checks**. Controller/kit/menu fixture: **17 checks**. Stereo-vehicle presentation fixture: **5 checks**.
- 32/64 tracked synthetic network clients completed 301 measured ticks at approximately 30 Hz with zero malformed frames and disconnects. Callback p95: **2.8/7.0 ms**. This ten-second load measurement does not certify sustained 64-player capacity. The native load suite preceded only the cosmetic Energy Pipe integration; the production arena run covers the final source.
- Final production arena: desktop and synthetic tracked clients passed admission/combat/class/squad/death/respawn checks; four real-map bots completed their movement/firing run. See arena.json for authored-navmesh warnings and measured results.
- Portable native package passed build-receipt validation. Candidate: `/home/blux/.cache/cq-rec1-review/release-20261015`. Hashes and native build receipt retained here. Wire protocol stays `fpsloppa-cq-frontier-22-live-fixes`.

The user deferred further VR testing. No new headset session was launched and this candidate was not activated on the remote service. The existing live release remains `20261014-cq-vehicle-respawn`. Further physical reload, ergonomic reach, perceived spawn stability, sight alignment and actual stereo vehicle/NVG confirmation are deferred to the next headset session. Known glove UID fallbacks and the Jolt solver-bias warning remain visible in test logs.
