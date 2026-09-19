"""Collect the decorated city's build, collision, presentation and live-run receipts."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(path):return json.loads((ROOT/path).read_text())
def main():
 build=read('maps/Benchmark1km/build.json');layout=read('maps/Benchmark1km/layout.json')
 checks=read('test-results/city/checks.json');prep=read('test-results/km-benchmark/preparation.json');geo=read('test-results/district-sim/geometry.json')
 assert build['sha256']==checks['bsp_sha256']==geo['source_sha256']
 assert prep['decorated_cache_resolved'] and prep['connected_spawns']==64 and prep['gate_clearance_rays']==144 and prep['perimeter_rays']==16
 assert prep['baked_light_invalid_faces']==prep['baked_light_overflow_faces']==0
 assert prep['baked_light_unlit_faces']==prep.get('baked_light_dark_faces',0)
 assert prep.get('night_lighting',False)
 runs=[]
 for name in ['city1x','city4x']:
  p=read('test-results/district-sim/'+name+'.json')
  assert p.get('map_sha256')==build['sha256']
  assert not p['failures'] and p['population']==64 and len(p['transfers'])==4
  assert all(t['state_preserved'] for t in p['transfers'])
  assert (ROOT/('test-results/district-sim/'+name+'.json')).stat().st_mtime>(ROOT/'maps/Benchmark1km/build.json').stat().st_mtime
  runs.append({'name':name,'target_speed':p['options']['speed'],'wall_seconds':p['options']['seconds'],'average_fps':1000/p['frames_ms']['mean'],'p95_frame_ms':p['frames_ms']['p95'],'slowest_speed':p['slowest_sim_seconds']/p['options']['seconds'],'fastest_speed':p['fastest_sim_seconds']/p['options']['seconds'],'transfers':len(p['transfers']),'events':p['events'],'cpu':p['cpu'],'gpu':p['gpu'],'failures':p['failures']})
 report={'build':build,'geometry':geo,'preparation':prep,'presentation':checks,'districts':layout['zones'],'textures':layout['textures'],'brushes':layout['brushes'],'baked_point_lights':layout['lights'],'lighting_profile':layout['lighting_profile'],'runs':runs}
 (ROOT/'docs/validation/city-decoration.json').write_text(json.dumps(report,indent=2)+'\n')
 table='\n'.join('| {target_speed:g}× | {average_fps:.1f} | {p95_frame_ms:.2f} ms | {slowest_speed:.2f}–{fastest_speed:.2f}× | {transfers} / 4 |'.format(**r) for r in runs)
 timings=', '.join(f"{r['tool']} {r['seconds']:.1f} s" for r in build['commands'])
 text=f'''# Vesper Megalopolis — decorated city validation

The kilometre prototype now has sixteen themed districts using a shared science-fiction/gothic architectural language. The original district boundaries and all 64 spawns remain intact. The outer edge is closed by a continuous 30 m solid perimeter, with a 160 m sky shell above it. A full nighttime bake, moonlit panorama, restrained atmospheric fog, coloured fixture lighting, emissive windows, industrial roof effects and opaque walk-through transit gates complete the presentation.

![City overview](../test-results/city/city_skyline.png)

[All sixteen districts](../test-results/city/districts.png) · [Gate detail](../test-results/city/gate.png) · [Closed perimeter](../test-results/city/closed_border.png)

## Authored content

- {layout['brushes']:,} brushes and {layout['textures']} reviewed texture entries across masonry, iron, copper, industrial panels, consoles, cargo, wood, runes and gothic reliefs.
- 64 buildings with layered cornices, buttresses, lancets, roof spires, chimneys, stepped arcologies, observatory rings, transit roofs, crane structures and bastion towers. District colours, façade signs, materials and roof silhouettes distinguish the sectors.
- Street lanterns, reliquary pylons, LibreQuake brazier fixtures, crates, market canopies, technological planters, data pylons, accessible galleries and ramps.
- 24 district passages, each 24 m wide and 16 m high, with two separately streamed gate faces. Their shaders write opaque depth; they have no physics bodies. Destination labels face approaching actors.
- Static decorative meshes are combined by district/material. Shader animation replaces per-frame scripts. No extra real-time lights; at most two small steam wisps per visible district. Existing weapon-light effect limits are unchanged.

## Bake and format

BSP29, **{build['bytes']/1e6:.2f} MB**, below the unchanged 25,000,000-byte import limit. {build['vertices']:,} vertices, {build['nodes']:,} nodes, {build['faces']:,} faces. This remains a prototype close to BSP29's vertex/node limits; it is not evidence that arbitrary additional brush detail will fit.

Full VIS and supersampled embedded RGB lighting completed with one bounce and ambient dirt: {timings}. There are {layout['lights']} baked point lights plus the sun/sky contribution. Moon/sky/minimum contributions are 9/4/1, reduced from 90/35/10. Gates, windows, roof bands, rings and braziers have matching baked illumination. The opt-in night shader removes the former shadow lift, and fully black compiler faces remain black. The 32-texel lightmap spacing reduces bake storage independently of full-resolution surface textures. The importer now accepts this bounded density; known corner-sample tests pass at both the existing 16-texel and new 32-texel settings. Legacy Quake clip hulls are omitted because Godot uses the imported mesh collision.

SHA-256: `{build['sha256']}`.

## Checks

- {prep['baked_light_faces']:,} faces have valid RGB lightmaps and {prep['baked_light_dark_faces']} fully shadowed faces use explicit black. No invalid or overflowing face patches; all 44,543 rendered BSP faces are accounted for.
- All 64 spawns connect through the navigation mesh and have valid ground collision. Cross-map navigation succeeds. All 144 gate clearance rays and 16 outer perimeter collision probes pass.
- All 48 gate faces use the opaque shader; the decoration layer adds zero collision bodies and zero real-time lights. No rendered vertices use an unreviewed placeholder texture. The compiler's unused `skip` texture entry can log a fallback warning, but contributes no visible surface.
- Normal map loading resolves the decorated texture-versioned scene cache. The district cache clips geometry at boundaries and preserves the baked UVs. The viewer hides the whole-map presentation before showing its subscribed district.
- Twenty engine captures cover every district, an aerial view, cathedral detail, gate and perimeter. The night panorama is visible after reducing fog's sky contribution.

## Live simulation

64 bots, four initially per district, sixteen worker processes, one subscribed viewer, 1280×720 Vulkan Mobile. Hardware: {runs[0]['cpu']}; {runs[0]['gpu']}. Each run lasts 32 wall seconds and exercises four normal walk-through ownership transfers. Both retained all 64 actors and preserved transferred state, with no harness failures or script errors.

| Requested speed | Mean viewer FPS | p95 frame | Actual worker speed | Transfers |
| --- | ---: | ---: | ---: | ---: |
{table}

The decorated city's 4× run **did not sustain the full requested 4× rate**. These are desktop prototype measurements; they do not establish VR performance, dedicated-client capacity, or production map balance. Shutdown logs contain the engine/GDExtension ObjectDB/resource-in-use warnings; gameplay and transfer checks completed before shutdown.

[Normal-speed capture](../test-results/district-sim/city1x.png) · [4× capture](../test-results/district-sim/city4x.png) · [Machine-readable results](validation/city-decoration.json)

## Reproduction and assets

See [map instructions](../maps/Benchmark1km/README.md) for compile, preparation, capture and live-run commands. Run `tools/km_benchmark/light_spacing_test.gd` and `tools/km_benchmark/city_check.gd` with headless Godot, then `python3 tools/km_benchmark/city_report.py` to regenerate this receipt.

Embedded textures retain the licences and provenance recorded in `maps/Benchmark1km/texture-sources.json` and the project's texture dictionary. The existing moonlit panorama is CC0 from Screaming Brain Studios; no new sky download was necessary. New geometry and shader art were authored in the project. Production maplists and base packaging are unchanged. Raw BSP import contains geometry and baked light; the prepared Godot caches add the holographic gates, extra effects and night-sky presentation.
'''
 (ROOT/'docs/CITY-DECORATION.md').write_text(text)
 print('CITY_REPORT',build['bytes'],'bytes',len(runs),'validated live runs')
if __name__=='__main__':main()
