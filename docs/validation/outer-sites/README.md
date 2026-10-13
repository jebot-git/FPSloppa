# Additional landmarks and swimmable rivers

Six formerly empty named pads are occupied: relay mast/control buildings, crossing
truss/guard offices, expedition lab/tents, canopy watchtower, summit observatory,
and open ruins. All eleven sites share render LODs and authoritative near geometry.

- Structures: 8,352 checks, including real doorway, stair and crossing traversal,
  road clearance and decreasing triangle counts at three LODs.
- Terrain: 12,968 checks, including deterministic generation, seams, dry road
  earthworks, occupied pads and finite river/estuary beds.
- Full world physics: 59 checks across 2,030,625 height samples, 90,928 vegetation
  colliders and eleven river road bridge sections. No water surface collider.
- Swimming: 1,485 checks. Level strokes lift the physical head above water;
  releasing strokes sinks the body, with twelve seconds of air before drowning.
  Stick/jump cannot propel swimmers. Shore restores normal walking and jumping.
  Comfort camera height leaves authoritative XR head/hands/weapon poses unchanged.

Structure and river screenshots use Vulkan Forward+ on Intel ADL-N at 1440×900,
with settled streamed terrain, hybrid forest and undergrowth. These are design
captures, not benchmarks. Full navigation, real headset comfort and multiplayer
underwater combat have not been validated for this revision.

The older general VR/crouch suite passed its stroke and shore cases but failed its
existing demo-frame validation check. The older BSP water suite reached all
successful assertions, then encountered an unset trigger fixture and an engine
shutdown abort. Neither is included in the passing counts above.

Run the four `tools/voxel_battle/validate_{outer_sites,jungle,jungle_physics,water}.gd`
scripts with Godot 4.7.2, `--headless --xr-mode off --path . --script SCRIPT`.
Render with `preview_outer_sites.gd` / `preview_water.gd`, Vulkan Forward+.
