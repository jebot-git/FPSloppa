# Classic DE map fidelity and interaction audit

Baseline reviewed 2026-09-27, before the restoration described in
[CS shoot-through cover and DE map restoration](CS16-PENETRATION.md).
That follow-up implements cover/layout revisions, Nuke's sliding glass doors
and CS-only penetration across all five maps. The tables and feasibility
recommendations below preserve the **pre-restoration audit**, not the current
feature inventory. The maps remain independently authored approximations.

## Evidence and confidence

Compared the editable generators and installed BSP29 geometry with five classic
BSP30 reference files, overview images and existing native Godot captures after
the DE material pass. The reference files come from a
[pinned community mirror](https://github.com/phamvanhiepvn/cs/tree/2e3c25596baeb6781a9d274cef7e25f42413ab3f/cstrike/maps),
not an authenticated Steam depot extraction. Their hashes, entity counts and
the installed-map hashes are retained in the
[audit receipt](validation/de-map-fidelity-2026-09-27.json). Findings about exact
original entity counts refer to these particular reference files.

The [Dust2 creator's CS 1.6 overview and design account](https://www.johnsto.co.uk/design/making-dust2/)
provides an independent primary reference. It explicitly describes the angled B
crates, raised platform and window. Later Source/GO/CS2 prop arrangements are
not the target. The overview images used when authoring the other maps are
linked from [the map sources](../maps/ClassicDE/README.md).

The new [read-only survey tool](../tools/classic_de/audit.py) reads both BSP
versions and generates geometry diagrams and an entity inventory:

```sh
MPLCONFIGDIR=/tmp/fpsloppa-map-audit-mpl python3 tools/classic_de/audit.py \
  --references /path/to/classic-cs16/maps
```

Local results: [full survey](../test-results/de-fidelity/bsp-survey.json),
[Dust2](../test-results/de-fidelity/dust2-plan.png),
[Nuke upper](../test-results/de-fidelity/nuke-plan.png),
[Nuke lower](../test-results/de-fidelity/nuke-lower-plan.png),
[Inferno](../test-results/de-fidelity/inferno-plan.png),
[Aztec](../test-results/de-fidelity/aztec-plan.png),
[Train](../test-results/de-fidelity/train-plan.png).
These generated results and reference files are ignored local test artifacts;
the tool and compact receipt are retained in the repository. References are
not installed into the game or packaged.

Diagrams show upward-facing polygons below stated height cutoffs. Each panel
has its own coordinates and scale; they are not registered overlays. Gold
highlighting is a texture-name heuristic, not an object count. Higher structures
and overlapping floors can be hidden. This audit establishes substantial
differences, not a numerical placement tolerance or complete prop inventory.

## Cover and decoration by map

| Map | Present in the rebuild | Material differences from the reference | Next geometry priority |
|---|---|---|---|
| Dust2 | Long, short, mid, tunnels, both sites, fixed double-door leaves, B window/platform and crate groups | Mostly axis-aligned, regular crate masses replace more varied and angled cover. B cover/platform relationships and doorway proportions are approximate. Broad plaster/trim surfaces omit much of the original architectural variation. | Re-author site cover footprints, heights and angles first, then door apertures and approach sightlines. |
| Nuke | Outside, lobby/radio, ramp, stacked A/B, tank props and vent connection | Sparse generic outside crates and simplified tank/room geometry; vent travel uses a broad crouch-height ramp instead of the original ladder/vent arrangement. Moving doors and shootable vent covers/glass are absent. Industrial panels and roof beams convey the theme but do not reproduce the original detail placement. | Restore upper/lower room relationships, vent dimensions and doorway positions before adding the original moving assemblies. |
| Inferno | Mid, banana, apartments/balcony, arch/library and both sites | Rectangular rooms and a small set of generic crates lose street recesses, irregular corners and site cover detail. Windows, shutters, roof bands and balcony rails are decorative approximations. The original hinged door and breakable window brush are absent. | Correct lane widths, apartment/balcony/pit geometry and site cover, then house-front detail and interactions. |
| Aztec | Ruin courts, fixed doors, bridge, canal and CT connection | Largest qualitative plan divergence: the rectangular courts and bridge/canal approaches retain landmarks but differ substantially in spatial arrangement. Repeated wooden crates substitute for varied ruin cover. Stone relief, broken masonry and vegetation detail are sparse; the reference contains many sprite decorations and a rain entity. | Re-establish the courts, bridge and canal plan/elevations, then replace generic cover with accurately placed ruin masses. |
| Train | Outer/inner yards, main, ivy, Z connector, upper/lower halls, rails and freight cars | Nine simplified cars (six outer, three inner) do not reproduce the reference arrangement. The inner yard is less densely occupied. Box bodies, support blocks and end stairs alter cover gaps, under-car sightlines and access; the original has 16 ladder entities. Roof, platform and industrial detailing is simplified. | Correct car footprints, spacing, height, underbody clearance and access together; assess ladder support before treating the end stairs as final. |

The differences are visible in the post-texturing native captures:
[Dust2 B](../test-results/de-texturing/de_dust2_rebuilt-b-site.png),
[Nuke A](../test-results/de-texturing/de_nuke_rebuilt-nuke-upper.png),
[Inferno A](../test-results/de-texturing/de_inferno_rebuilt-inferno-a.png),
[Aztec A](../test-results/de-texturing/de_aztec_rebuilt-aztec-a.png),
[Train inner](../test-results/de-texturing/de_train_rebuilt-train-inner.png).
Textures alone cannot correct these cover and sightline differences.

## Which original doors actually move?

| Reference map | Sliding door brush entities | Hinged door entities | Brushes accepting shooting damage | Installed rebuild |
|---|---:|---:|---:|---|
| Dust2 | 0 | 0 | 0 | No moving doors or breakables |
| Nuke | 16, in four named assemblies | 1 | 9 | No moving doors or breakables |
| Inferno | 0 | 1 | 1 | No moving doors or breakables |
| Aztec | 0 | 0 | 0 | No moving doors or breakables |
| Train | 0 | 0 | 0 | No moving doors or breakables |

Nuke's `GlassDoor1` through `GlassDoor4` each contain four brush entities:
two translucent panes and two frame sections. Thus **16 is a part count, not
16 separate doorways**. They specify speed 50 and wait 10 in GoldSrc units.
Its hinged upper-site door specifies a 90-degree turn, speed 100 and wait 4.
Inferno's hinged door also specifies 90 degrees, speed 100 and wait 4.
The full survey preserves origins, bounds and key/value data for reconstruction.

Dust2, Aztec and Train contain respectively 10, 8 and 2 `func_breakable`
entities, but those are marked trigger-only. They must not automatically become
shootable destructible cover. Valve's
[breakable implementation](https://github.com/ValveSoftware/halflife/blob/master/dlls/func_break.cpp)
disables shooting damage for that flag. Nuke's nine damageable brushes are
three glass panes and six vent covers; Inferno's one uses a window texture.
Breaking a panel and shooting through an intact wall are separate mechanics.

The static double doors on Dust2 and Aztec should remain fixed if matching these
references. They can still participate in material-dependent penetration.

## Runtime feasibility

| Feature | Existing foundation | Required work |
|---|---|---|
| Sliding assemblies | Loader maps `func_door` to a separate brush scene; map runtime/triggers animate and replicate translations. | Author separate leaves/frames, convert GoldSrc angles/flags into an explicit door profile, synchronize groups, match travel/speed/wait and restore state each round. Existing Quake spawnflags are not interchangeable with GoldSrc flags. |
| Hinged doors | BSP brush submodels and entity metadata can carry a hinge and angle. | Add a rotating-door entity/template, hinge transform, moving collision, blocked-motion policy and rotation/progress replication. Current mover snapshots contain positions only. Match activation semantics against [Valve's door code](https://github.com/ValveSoftware/halflife/blob/master/dlls/doors.cpp). |
| Breakable vents/windows | Server-owned map damage dispatch already exists. | Add breakable brush entities with health, collision/visibility removal, limited debris/SFX, replication, late-join state and round reset. Current damageable Quake buttons/doors are activation logic, not breakables. |
| Shoot-through cover | Shared CS hitscan, rewind-aware player hit tests and a world BSP contents tree already exist. | Add a CS-only penetration trace, material metadata, bounded solid traversal and weapon-specific penetration rules. The present trace stops at the first world surface. |

Relevant implementation:
[loader](../deathmatch/maps/loader.gd),
[map runtime](../deathmatch/maps/runtime.gd),
[map triggers](../deathmatch/maps/triggers.gd),
[world contents](../deathmatch/maps/contents.gd),
[CS/shared combat](../deathmatch/experimental/combat.gd),
[world hit test](../deathmatch/hit_detection.gd) and
[arena traces/mover snapshots](../deathmatch/arena.gd).

For doors, compile independent brush entities rather than cutting a dynamic
opening out of the merged world mesh. Validate pivot handling in the BSP29
compiler/importer with a small fixture before rebuilding a map. Keep mover
collision authoritative, coordinate bot traversal with door state, and preserve
VR hand/use reach checks. BSP29 format capacity is sufficient; this has been
assessed from the code, not proven with a new moving-door prototype.

For penetration, use
[ReGameDLL_CS `FireBullets3` at a pinned revision](https://github.com/rehlds/ReGameDLL_CS/blob/4a50c42e85fd3778c2b7d24731c7d30c83bbab01/regamedll/dlls/cbase.cpp#L1268)
as a compatibility reference. It combines a weapon-supplied penetration count,
calibre power/range, range damage loss and material modifiers. Wood retains more
damage than metal, and concrete reduces penetration power. Calibre alone does
not determine whether a weapon can penetrate. This is reverse-engineered CS
server behavior, not an official retail source release. Its forward stepping
is not a physically exact thickness simulation.

Recommended adaptation:

1. Give each CS weapon explicit penetration data; audit its original firing
   call as well as the shared bullet routine. Keep other loadouts on their
   existing trace and keep buckshot behavior explicit.
2. Preserve physical material roles per BSP face/brush, independently of the
   render atlas and texture replacements. Use solid-leaf intervals or bounded
   entry/exit searches for the world; transformed local hulls for moving doors.
   Reject sky, void and unknown surfaces conservatively.
3. Continue the existing rewind-aware player trace after a valid exit, preserving
   headshot/armor handling and ammunition accounting. Apply finite per-shot
   surface/query budgets and thickness/angle limits. Do not exclude the entire
   world collider to get past a wall: that would also skip later walls.
4. Replicate authoritative damage, breakage and impact effects. Limit debris
   and decals; no per-frame wall scanning is needed. Bots should not acquire
   hidden enemies simply because a wall can be penetrated.

At the project's 32 BSP units per metre, explicitly convert source distances
and tune against each reconstructed wall's actual thickness. Exact CS wallbang
spots also require faithful geometry and texture-material assignments. A
material-aware adaptation is achievable sooner than exact GoldSrc parity.

## Recommended implementation order and acceptance

Start with a small door/glass/wood/metal fixture and shared runtime support.
Then restore Nuke's doors and vents, Inferno's door/window, and test fixed-door
penetration on Dust2. Correct Aztec's major layout and Train's car geometry
before spending time on small decorations; finish site cover and facade detail
across all maps.

Validate sliding/hinged doors with blocked players, grouped leaves, bots,
late joins, demo playback and DE round resets. Penetration tests should include
thin wood/metal, thick masonry, angled and consecutive walls, exhausted
penetration counts, intact/broken glass, moving doors and rewound headshots.
Confirm non-CS weapons retain current behavior. Rebuild navigation, objective
hashes, map caches and the base-asset archive after geometry changes, then run
route checks and 6v6 tests. Those implementation and gameplay tests remain
future work; this audit makes no performance or competitive-parity claim.


## Placement follow-up — 2026-09-27

Aztec cover now uses explicit floor heights. Cover was moved clear of the CT
ramp, A gallery wall and east canal exit; the T-spawn moss patch rests at its
actual floor height. Both gate arches have full supporting jambs to the corridor
boundaries, and their open leaves meet the hinge masonry.

Inferno's three upper crates now sit wholly on their supporting crates. Three
wall/corner conflicts were corrected. Nine windows and eight door decorations
are mounted against verified solid room boundaries, with non-overlapping facade
rectangles; the generator rejects unsupported or overlapping decorations.

Dust2's central double doors now have two partly open, arched timber leaves,
metal bands and ring handles, attached to masonry jambs. Their centre gap is
walkable and their thin timber participates in the existing CS penetration rules.
These remain fixed architectural doors, like the previous test geometry.

Compiled-geometry checks sample cover-floor contact and wall clearance, gate
attachment and the centre gap; all existing bot routes are walked both ways.
See `docs/validation/de-placement-2026-09-27.json` for the new map hashes and
validation. Earlier restoration receipts describe earlier BSP revisions.
