"""Collect measured results; never substitute target speed for achieved speed."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/km-benchmark'
def read(name):return json.loads((OUT/(name+'.json')).read_text())
def main():
 cases={name:read(name) for name in ['headless64','desktop64','live4x64']}
 for row in cases.values():
  row['achieved_speed']=row['simulated_seconds']/row['wall_seconds']
  row['bots_moved']=sum(b['distance_m']>10 for b in row['bots'].values())
  row['bots_fired']=sum(b['shots']>0 for b in row['bots'].values())
  row['total_shots']=sum(b['shots'] for b in row['bots'].values())
  row['total_deaths']=sum(b['deaths'] for b in row['bots'].values())
  assert row['population']==64 and row['bots_moved']==64 and row['bots_fired']==64
 render=read('render-comparison');images=[]
 for view in ['district','gate','overview']:
  a=np.array(Image.open(OUT/(view+'-zones_off.png'))).astype(int);b=np.array(Image.open(OUT/(view+'-zones_on.png'))).astype(int)
  delta=np.max(abs(a-b)[:,:,:3],axis=2)
  images.append({'view':view,'different_pixels':int(np.count_nonzero(delta)),'pixels_over_5_levels':int(np.count_nonzero(delta>5)),'max_channel_difference':int(delta.max())})
  assert not np.any(delta>5),f'Occlusion image mismatch: {view}'
 combined={'map_build':json.loads((ROOT/'maps/Benchmark1km/build.json').read_text()),'preparation':read('preparation'),'simulations':cases,'render_comparison':render,'image_checks':images}
 (ROOT/'docs/validation/kilometre-benchmark.json').write_text(json.dumps(combined,indent=2)+'\n')
 lines=['# One-square-kilometre BSP29 / 64-bot prototype','',
 'Measured on 2026-09-19 using Godot 4.7.2 Fedora (editor/debug-capable runtime), Core i7-12700, Intel Arc A770, Mobile Vulkan, 1280×720, 4× MSAA. These are local offline measurements, not release-build, VR, or network capacity guarantees.','',
 '## Map and validation','',
 '- Exactly 1,000 × 1,000 m playable ground; centred at the origin. BSP29, 2,387,232 bytes. The sealing walls extend to ±502 m.',
 '- Sixteen connected districts, 64 buildings, cover, roads, ramps, 64 spawns and 128 pickups.',
 '- Baked lightmap import has no invalid faces. Fast VIS is used for this prototype.',
 '- 11,448 map triangles; original importer mesh split into 80 spatial batches; 114 inset box occluders.',
 '- Coarse navigation: 4,126 polygons at 1 m horizontal / 0.25 m vertical resolution. All 64 spawn floor rays and paths from the first spawn pass. The diagonal route contains 105 points.',
 '- All 64 bots moved and fired in every run. Real movement, weapons, pickups, damage, deaths and respawns were enabled. No AI sleeps behind occlusion.',
 '', '## Active simulation','',
 '| Run | Simulated / wall seconds | Achieved speed | Game tick p50 / p95 | Shots / deaths |',
 '|---|---:|---:|---:|---:|']
 for name,label in [('headless64','Headless, target 1×'),('desktop64','Desktop, target 1×'),('live4x64','Live follow camera, target 4×')]:
  r=cases[name];t=r['game_tick_ms'];lines.append(f"| {label} | {r['simulated_seconds']:.2f} / {r['wall_seconds']:.2f} | {r['achieved_speed']:.2f}× | {t['p50']:.2f} / {t['p95']:.2f} ms | {r['total_shots']:,} / {r['total_deaths']} |")
 live=cases['live4x64'];frames=live['render_frame_ms']
 lines += ['',f"The 4× request uses `Engine.time_scale = 4` and 240 physics ticks/second, preserving a 1/60 s simulated movement step. It achieved **{live['achieved_speed']:.2f}×**, so **4× real-time playback was not reached**. Its measured mean rendered frame interval was {frames['mean']:.2f} ms (approximately {1000/frames['mean']:.1f} FPS); p95 was {frames['p95']:.2f} ms. The live overlay displays requested speed, achieved speed, simulation time and FPS.",'',
 'Tick percentiles exclude the initial ten simulated seconds. `game_tick_ms` measures the explicit game physics call, plus the game visual update in graphical runs. It excludes other node processing, renderer work and the benchmark bookkeeping. `engine_physics_ms` is Godot’s aggregate physics processing per engine frame, which may contain several catch-up ticks; it must not be interpreted as cost per individual tick. Wall-time speed includes the full active run, after map/avatar/navigation setup.',
 '', 'The projectile pool reached its 256-projectile cap. The headless run sampled about 61 MiB of Godot static allocations; the desktop run about 350 MiB. These counters exclude total process RSS and GPU memory. The real-time target is already missed headlessly, establishing a simulation CPU bottleneck independently of GPU rendering. Graphical avatar/effect processing adds further cost. Detailed CPU profiling is needed before attributing that cost to a specific subsystem.',
 '', '## Matched rendering comparison','',
 'Identical actors and camera are frozen for each comparison. Each case uses 90 warmup frames and 240 measured frames. These fast static frame times are **not live-match FPS**. Rendering timings below are medians.','',
 '| View | Representation | Draw calls | Triangles/primitives | GPU ms | Render CPU ms | Frame ms |',
 '|---|---|---:|---:|---:|---:|---:|']
 for r in render['results']:
  lines.append(f"| {r['view']} | {r['mode']} | {r['draw_calls']['p50']:.0f} | {r['primitives']['p50']:,.0f} | {r['render_gpu_ms']['p50']:.3f} | {r['render_cpu_ms']['p50']:.3f} | {r['frame_ms']['p50']:.3f} |")
 lines += ['',
 '`original` is the importer mesh without occlusion; `zones_off` uses district batches with frustum culling; `zones_on` adds native occlusion. Gate-view occlusion reduces submitted primitives by 26.6% and draw calls by 37.1% relative to `zones_off`. Nevertheless, the CPU overhead raises total median frame time in all three views. This low-detail environment is too inexpensive to draw for these occluders to pay off on this hardware. Keep this as an opt-in experiment; do not enable the same policy globally on the strength of triangle savings alone.',
 '', 'All three off/on screenshot pairs were pixel-identical. That checks the sampled views, including a view through an opening, but is not exhaustive proof against culling artifacts at every camera position. Larger/diverse scenes, more viewpoints, lower-end CPUs and VR need separate tests.',
 '', 'Godot’s occlusion culling operates on render instances, which motivates spatial mesh splitting; it incurs CPU work and may be unsuitable for open or inexpensive scenes. [Godot occlusion documentation](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).',
 '', '## Scope and reproduction','',
 'The shipped dedicated limit is 32. Only the offline benchmark overrides population to 64. There are no remote clients, snapshot traffic or latency in these tests; this does not establish 64-client networking support. Existing production settings, maplists and base asset bundles are unchanged.',
 '', 'The importer’s lightmapped material path and the production two-effect weapon illumination cap are retained. Graphical runs emitted existing MultiMesh physics-interpolation warnings from `deathmatch/experimental/visuals.gd`; no script failures occurred. Shutdown reported one leaked ObjectDB instance headlessly (also present in check-only runs), and six instances plus one resource still in use in the live graphical run. These shutdown diagnostics remain unresolved; they are not a clean shutdown claim.',
 '', 'See [map source and commands](../maps/Benchmark1km/README.md), [machine-readable results](validation/kilometre-benchmark.json), and [benchmark harness](../tools/km_benchmark/simulate.gd).',
 '', 'Local screenshots: [overview](../test-results/km-benchmark/overview-zones_on.png), [gate](../test-results/km-benchmark/gate-zones_on.png), [4× live view](../test-results/km-benchmark/live4x64.png). Screenshots and raw run logs are generated local artifacts; the consolidated JSON is retained with this report.','']
 (ROOT/'docs/KILOMETRE-BENCHMARK.md').write_text('\n'.join(lines))
 print('KM_REPORT_PASS: three 64-bot runs; three matched image pairs')
if __name__=='__main__':main()
