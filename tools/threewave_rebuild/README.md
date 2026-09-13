# Original-series CTF rebuild workflow

Scope confirmed by the user: **original CTF1–CTF6**, not CTF2M1–CTF2M6 and not
the remaster's renumbered selection. The six resulting maps are newly authored
interpretations for FPSloppa movement and CTF rules. They are not BSP conversions
or claims of exact retail reconstruction.

## Reference work

`local/` is ignored by Git and Godot. Original archives, extracted BSPs, video
downloads, video metadata, and sampled screenshots live there only. The builder
does not import `study.py`, read `local/`, or consume original geometry. `study.py`
inspects BSP29 entities, bounds and horizontal faces for local reference diagrams.

The archived [3.0 client](https://github.com/Jason2Brownlee/ThreeWaveCTF/blob/main/bin/3wctfc30.zip)
contains CTF1–CTF8. Its bundled readme unexpectedly identifies itself as beta2;
record archive and BSP hashes rather than treating its filename as proof of a
particular final revision. This study uses the six un-suffixed BSPs in that archive.
The 4.0 client was also obtained to disambiguate the second series, but none of
its maps are in the requested scope.

Downloaded all six deathstalker667 exploration videos at 360p (video track),
read their descriptions, and inspected twenty evenly sampled frames per video.
These are solo map walkthroughs using an older ThreeWave gameplay version, not
competitive timing benchmarks. Black intros, menus and underwater frames reduce
useful sample coverage; BSP plans provide an independent check on connectivity.
The descriptions are commentary, not authoritative metadata: for example the
CTF4 description conflates authors, while the archive credits Brian Wight.

| Original / original designer | Local video ID, duration | Authored map |
|---|---|---|
| CTF1 McKinley Base / Dave “Zoid” Kirsch | [OiweZfnAb9U](https://www.youtube.com/watch?v=OiweZfnAb9U), 1600 s | Tideworks |
| CTF2 The Kiln / Brian Wight | [OdUmoTYkrek](https://www.youtube.com/watch?v=OdUmoTYkrek), 1036 s | Crucible |
| CTF3 DySpHoRiA / Chris “b0rt” Thibodeaux | [UA3ibbotC18](https://www.youtube.com/watch?v=UA3ibbotC18), 1124 s | Confluence |
| CTF4 The Forgotten Mines / Brian Wight | [nOjFCJGCmXE](https://www.youtube.com/watch?v=nOjFCJGCmXE), 2117 s | Deepvault |
| CTF5 Da Ancient War Grounds / Matthew “DaBug” Hooper | [toL37LtHk5E](https://www.youtube.com/watch?v=toL37LtHk5E), 946 s | Crownreach |
| CTF6 Vertigo / Dale “Midiguy” Bertheola | [GNTRAae_lPQ](https://www.youtube.com/watch?v=GNTRAae_lPQ), 1186 s | Skyfracture |

Written room/item guides were available for
[McKinley Base](https://quake.fandom.com/wiki/CTF1%3A_McKinley_Base),
[The Kiln](https://quake.fandom.com/wiki/CTF2%3A_The_Kiln), and
[DySpHoRiA](https://quake.fandom.com/wiki/CTF3%3A_DySpHoRiA).
The corresponding CTF4–6 wiki pages blocked retrieval; those maps use the
downloaded exploration guides and descriptions, original BSP inspection, and
the [official map overview](https://store.steampowered.com/news/posts/?appids=2310)
for the CTF5/6 counterparts. The overview uses remaster numbering, so it is not
used to identify the six original filenames.

## Design observations and adaptations

These notes distinguish observed structure from new design decisions. Dimensions,
brushes, room proportions, trim and architectural motifs in `layouts.py` are newly
specified; no vertex coordinates, brush planes or texture pixels are transferred
from the reference BSPs to the builder.

- **CTF1 → Tideworks.** Original BSP plan: offset opposing bases, a water court,
  long transverse upper routes, elevated flags. Walkthrough sampled around
  600–1160 s shows industrial galleries, red team panels, water and internal
  ramps/stairs. Written guide confirms lower water entrances and side lifts.
  New map keeps offset entries, a low bridge, cross-gallery and separate service
  route; broad ramps serve the elevated flags. Original computer art, emblems,
  secret rooms and exact room dimensions are not reproduced.
- **CTF2 → Crucible.** BSP: compact bases, a divided middle with side loops and
  a substantially lower level. Samples around 383–893 s show close masonry
  corridors, small arches, raised ledges and stairs. The written guide places
  the grenade launcher centrally and omits a rocket launcher. New map uses
  a low grenade approach and two upper flanks, keeps the close-range weapon
  emphasis, and replaces the awkward small entry discussed in the walkthrough
  with a full-height, capsule-clear route.
- **CTF3 → Confluence.** BSP: approximately mirrored ring bases, rear flag rooms,
  bridges and extensive underground space. Samples around 532–980 s show the
  basin, high walkways and base transitions. The written guide describes lifts,
  water tunnels, central teleporters and flags behind bars. New atria use
  horseshoe galleries, ramps and a lower conduit. Teleports supplement walking;
  flags have open entrances instead of requiring the original barred-door logic.
- **CTF4 → Deepvault.** BSP: a long mine with stepped base approaches, separate
  side routes and flag rooms at the ends. Samples around 578–1733 s show timber
  decks, rock-sided chambers, deep liquid and a gridded gate. The exploration
  description criticizes long travel and grapple reliance. New mine retains
  the excavation/galleries/gate/bypass sequence, with timber shoring, shorter
  passages and a permanently open CTF gate. A real upper bypass rejoins the
  flag room by a walkable descent.
- **CTF5 → Crownreach.** BSP: two castle compounds, transverse moat crossings,
  central island structures and flags behind the courtyards. Samples around
  165–870 s show gate arches, parapets, water, drain routes and throne-like
  sanctuaries. The walkthrough describes a castle siege; the official overview
  confirms the moat/throne-room motif. New castles use newly placed buttresses,
  broad battlement approaches, alternate crossings and a central obelisk.
  Castle coats of arms and original stonework are not reused.
- **CTF6 → Skyfracture.** BSP confirms strong vertical asymmetry: original flag
  origins differ by 835 Quake units. Samples around 207–1092 s show large tiered
  bases, balcony rails, stairs and corridors. The official overview describes
  three exits and directional tunnels. New map retains lower/upper bases and
  three approaches, reduces the elevation difference to 512 units, and gives
  both teams continuous ramps plus optional teleport shortcuts. No Quake Q
  monument, original signage, level-exit trigger or proprietary art is copied.

## Build and verify

```sh
python3 tools/threewave_rebuild/build.py
python3 tools/threewave_rebuild/install.py
# Or --only 1 2 to rebuild selected authored maps.
XDG_DATA_HOME=/tmp/fpsloppa-ctf-study-data godot --headless --xr-mode off --path . \
  --script res://tools/threewave_rebuild/bake.gd -- ctf_tideworks
XDG_DATA_HOME=/tmp/fpsloppa-ctf-study-data godot --headless --xr-mode off --path . \
  --script res://tools/threewave_rebuild/acceptance.gd -- \
  ctf_tideworks test-results/threewave/tideworks --walk --bots
```

Use a rendered Godot session (omit `--headless`) for the screenshot pass.
All test-owned processes must exit; errors in logs invalidate a successful exit.
Sources, manifests, licences and audits are in `maps/CTFStudies/`. Full VIS,
supersampled BSPX RGB light, scene caches and navigation meshes follow the
Frigate/HiSlop/Vesper practices. Reference files are excluded from package inputs.

## Provenance

New source geometry is offered under CC0-1.0. Material artwork retains its own
licences: permitted Makkon artwork and BSD-licensed LibreQuake textures. Exact
WAD mip records are verified against per-texture provenance and embedded BSP
records. No ThreeWave textures, models, sounds, music, logos or compiled geometry
are distributed with these maps. This statement concerns the supplied files;
it is not a grant of rights over the original map designs or names.

## Visual direction

Per user review, main walls use natural brick, weathered blocks and rough rock.
Industrial bases use plain Makkon brick with localized iron frames; mine rooms
use LibreQuake rock and timber. Decorative gothic panels are limited to team
markers. Materials are not recoloured or synthesized: brush UV scales select
realistic masonry/rock grain sizes while the WAD pixels remain unchanged.

Run `verify.py routes` to walk the authored alternate routes, `verify.py bots`
for bounded 4v4 production-AI smoke matches, and `verify.py views` for rendered
inspection. `gallery.py` assembles links to unchanged engine screenshots.
`package.py` refuses stale/failing tests or mismatched catalog/navigation hashes.
The local ZIP is a map/source bundle for an existing FPSloppa checkout; the normal
base-assets builder also includes these maps and their licences on the next game
release. It does not publish a release or change the pinned download by itself.
