"""Validate and summarize real district-worker runs, retaining raw receipts."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/district-sim'
def read(name):return json.loads((OUT/(name+'.json')).read_text())
def main():
 runs={name:read(name) for name in ['districts1x','districts4x','rollback2']}
 for name,r in runs.items():
  assert not r['failures'],(name,r['failures'])
  assert r['stale_view_checks'] and all(t['state_preserved'] and t['commit_sequence']>t['prepared_sequence'] for t in r['transfers'])
  workers=r['worker_stats'];ids=[i for w in workers.values() for i in w['active']]
  assert len(ids)==len(set(ids))==r['population'] and all(w['escrow']==0 for w in workers.values())
  r['achieved_speeds']=[w['clock']/w['wall_seconds'] for w in workers.values()]
  r['mean_render_fps']=1000/r['frames_ms']['mean']
  if name!='rollback2':
   assert r['population']==64 and len(workers)==16 and len(set(r['worker_pids'].values()))==16
   assert [(t['source'],t['target']) for t in r['transfers'] if t['id']==-1]==[(0,1),(1,5),(5,4),(4,0)]
   assert r['viewer_peak_actors']<=5
   assert all(w['snapshots']==0 for zone,w in workers.items() if int(zone) not in [0,1,4,5])
   assert r['duplicate_acknowledgements']>=8
   assert len(set(i for w in workers.values() for i,distance in w['movement'].items() if distance>1))==64
 assert len(runs['rollback2']['rollbacks'])==1 and len(runs['rollback2']['transfers'])==1
 combined={'geometry':read('geometry'),'runs':runs,'validation':'Actor conservation, four physical gate crossings per full run, state/timer preservation, idempotent replay, rejection/rollback/retry, stale/wrong-district viewer rejection, independent progress and off-district snapshot isolation all passed.'}
 (ROOT/'docs/validation/district-simulation.json').write_text(json.dumps(combined,indent=2)+'\n')
 lines=['# Independent district simulation: prototype results','',
 'The kilometre map runs as sixteen independent Quake DM authorities, with four bots initially assigned to each. A separate observer renders only its current district. **This is a process-based prototype, not shared-scene multithreading or production multiplayer integration.**','',
 'Measured on 2026-09-19: Core i7-12700, Intel Arc A770, Godot 4.7.2 Fedora, Mobile Vulkan, 1280×720, 4× MSAA, observer capped at 120 FPS. Each full run lasts 32 wall-clock seconds after all workers are ready; the first five seconds are excluded from observer frame statistics.','',
 '| Requested speed | Achieved district speeds | Observer mean FPS | Frame p95 | Transfer latency | Worker memory |',
 '|---|---:|---:|---:|---:|---:|']
 for name in ['districts1x','districts4x']:
  r=runs[name];lat=[t['latency_ms'] for t in r['transfers']]
  lines.append(f"| {r['options']['speed']:.0f}× | {min(r['achieved_speeds']):.3f}–{max(r['achieved_speeds']):.3f}× | {r['mean_render_fps']:.1f} | {r['frames_ms']['p95']:.2f} ms | {min(lat)}–{max(lat)} ms | {r['workers_static_bytes']/1048576:.0f} MiB |")
 r=runs['districts4x'];clocks=[w['clock'] for w in r['worker_stats'].values()]
 lines += ['',f"At the 4× request, workers completed {min(clocks):.2f}–{max(clocks):.2f} simulated seconds in approximately 32 wall seconds. Their clock spread was {max(clocks)-min(clocks):.2f} simulated seconds: clocks are independent, not globally synchronized. Relative actor timers are rebased on transfer. The active observer's snapshot-age p95 was {r['snapshot_age_ms']['p95']:.0f} ms; this is time since the last received snapshot, not measured end-to-end packet latency.",'',
 f"The final 4× run recorded {r['events'].get('damage',0):,} damage events, {r['events'].get('match_event',0):,} match events and {r['events'].get('spawn',0):,} spawns. All 64 actors moved, all districts advanced, and the observer held no more than {r['viewer_peak_actors']} actors. Unvisited districts sent zero continuous scene snapshots. One statistics update per second from each district remains available to the broker.",'',
 f"The observer tracked approximately {r['viewer_static_bytes']/1048576:.0f} MiB of static Godot allocations separately from the workers. The broker received {r['transport_received_bytes']/1048576:.2f} MiB across all connections during the run/setup/stop sequence. These counters are not total process RSS or GPU memory. Each process retains the static full-map physics/navigation caches; that memory duplication can be reduced in a later implementation.",'',
 '## What was exercised','',
 '- Real production bot decisions, capsule movement, collision queries, Quake weapons, damage, pickups and respawns inside each authority. No background district was paused or approximated.',
 '- Four scripted gate crossings: district 0 → 1 → 5 → 4 → 0. The harness stages bot -1 near each gate, then ordinary movement triggers export. This bot has controlled health/inventory and temporary invulnerability for the transfer assertions.',
 '- Source escrow, staged destination admission, destination-state snapshot, commit acknowledgement, owner change and subscription switch. No two active authorities own the actor simultaneously.',
 '- Health, armour, ammunition, owned/current weapon, scores/deaths, life serial, velocity, stance/body state, cooldowns and clock-relative deadlines preserved at commit.',
 '- Every prepare and commit is deliberately sent twice. Replays produce acknowledgements without duplicate bodies. Final ownership is audited across all stopped workers: 64 active actors, zero escrow, matching the broker directory.',
 '- A separate eight-actor test rejects the first destination admission, restores the source actor just inside the gate, then retries successfully. Duplicate, stale and wrong-district viewer snapshots are rejected.',
 '- Render triangles are clipped to district rectangles, with lightmap/texture coordinates retained. Only the active district is visible. The observer uses normal avatar rigs and local projectile visuals, including the production two-effect surface illumination budget.','',
 '## Interpretation and limitations','',
 'The previous monolithic 64-bot run achieved about 0.55× headlessly. Its live 4× request achieved only 0.28× and about 2.1 FPS. This prototype demonstrates that local ownership and parallel authorities can remove that particular monolithic bottleneck. It is **not a controlled measurement of threading alone**: collision/AI target sets are local, only local avatars are animated, game interactions change, and the observer does not reproduce the full hitscan/audio/event stream or player prediction.',
 '', 'Each district still has the existing 256-projectile limit rather than sharing the old global 256 cap. Projectile counts and combat outcomes differ. Independent district DM timers/rounds are not a global match; team objectives, global scoring, late source-district hit credit, sound and remote-player admission are not integrated.',
 '', 'Boundaries are hard partitions. Actors across a gate cannot see or hit each other through the boundary, and outgoing projectiles terminate. An open gate can reveal empty space until the viewer switches districts. A production map needs transition rooms/opaque portals, or overlapping visibility and coordinated cross-border combat. A crowded district still costs one authority; this test does not solve 64 actors gathering in the same district.',
 '', 'The actor pauses briefly during handoff. The destination accepts its current local timeline; no global catch-up occurs. A failed prepare can roll back, but worker crashes or an ambiguous commit timeout stop the experiment. There is no persistent transaction journal, reconnect recovery, trust boundary for public clients, or dynamic load balancing.',
 '', 'Godot’s active scene tree is not safe to manipulate from arbitrary threads, which is why this experiment uses independent engine processes. A thread-based version would require worker-owned data/physics server state and message passing, without concurrent access to the existing arena nodes. [Godot thread-safe API documentation](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).',
 '', 'The runs completed their functional checks without script errors. Godot reported ObjectDB/resource-in-use diagnostics at shutdown, as in the earlier graphical benchmark; those cleanup diagnostics remain unresolved. Performance figures describe a short local test, not release-build, VR or internet capacity guarantees.','',
 'See [implementation and launch commands](../tools/district_sim/README.md), [raw consolidated measurements](validation/district-simulation.json), [1× screenshot](../test-results/district-sim/districts1x.png), and [4× screenshot](../test-results/district-sim/districts4x.png). Production servers, player limits and maplists are unchanged.','']
 (ROOT/'docs/DISTRICT-SIMULATION-PROTOTYPE.md').write_text('\n'.join(lines))
 print('DISTRICT_REPORT_PASS: two full 64-actor runs plus rejection/rollback/retry')
if __name__=='__main__':main()
