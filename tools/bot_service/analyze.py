#!/usr/bin/env python3
"""Compare fixed-window server callback profiles, not GPU/compositor frametimes."""
from pathlib import Path
import argparse,json

def main():
 p=argparse.ArgumentParser();p.add_argument('--local',type=Path,required=True);p.add_argument('--worker',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 local=json.loads((a.local/'profile.json').read_text());worker=json.loads((a.worker/'profile.json').read_text())
 summary=json.loads((a.worker/'summary.json').read_text())
 assert all(s['bot_worker']['connected'] and s['bot_worker']['leased']==16 and s['bot_worker']['disconnects']==0 for s in summary['samples'])
 result={'scope':'16-bot Katabatic, console release/Jolt, sequential loopback runs; 30 s warmup then a fixed 30 s capture; local AI 60 Hz, delegated AI up to 30 Hz / state up to 20 Hz. Callback wall time excludes engine physics, graphics and compositor; random matches are not deterministic replays.', 'local':local,'delegated':worker,'comparison':{},'worker_stats':json.loads((a.worker/'worker.json').read_text()),'steady_state':summary['samples'][-1]['bot_worker']}
 for label in ['arena._physics_process','arena._server_tick','bots.tick']:
  result['comparison'][label]={key:{'local_ms':local[label][key],'delegated_ms':worker[label][key],'reduction_percent':(1-worker[label][key]/local[label][key])*100} for key in ['mean','median','p95','p99']}
 for name,data in [('local',local),('delegated',worker)]:
  physics=data['arena._physics_process'];service=data['bot_service/server._process']
  # Service runs outside the physics callback, so include its total cost without
  # double-counting consume() (already included in service._process).
  result[name+'_mean_service_ms_per_physics_step']=service['mean']*service['count']/physics['count']
  result[name+'_mean_callback_plus_service_ms']=physics['mean']+result[name+'_mean_service_ms_per_physics_step']
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result['comparison']['arena._physics_process'],indent=2))
if __name__=='__main__':main()
