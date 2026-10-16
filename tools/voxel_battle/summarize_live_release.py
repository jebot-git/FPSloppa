"""Summarize saved release-client/server logs without inventing per-frame percentiles."""
import argparse, collections, hashlib, json, statistics
from pathlib import Path

def describe(values):
    values=sorted(values)
    if not values:return {}
    return {'samples':len(values),'min':values[0],'median':statistics.median(values),'sample_p95':values[min(len(values)-1,int((len(values)-1)*.95))],'max':values[-1]}

def frames_summary(rows):
    return {'windows':len(rows),'frames':sum(r['frames'] for r in rows),'seconds':sum(r['window_seconds'] for r in rows),'weighted_fps':sum(r['frames'] for r in rows)/sum(r['window_seconds'] for r in rows) if rows else 0,'window_fps':describe([r['fps'] for r in rows]),'window_wall_p95_ms':describe([r['frame_ms_p95'] for r in rows]),'window_render_cpu_p95_ms':describe([r['render_cpu_ms_p95'] for r in rows]),'window_render_gpu_p95_ms':describe([r['render_gpu_ms_p95'] for r in rows]),'over_two_budgets_frames':sum(r['over_2budgets'] for r in rows)}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--session',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    src=a.session;out=a.output;out.mkdir(parents=True,exist_ok=True)
    frames=[json.loads(line.split(' ',1)[1]) for line in (src/'client.log').read_text().splitlines() if line.startswith('FRAME_STATS ')]
    start='2026-10-15T18:14:30Z';end='2026-10-15T19:03:00Z'
    events=[r for line in (src/'server-events.jsonl').read_text().splitlines() if line.startswith('{') and start<=(r:=json.loads(line))['utc']<=end]
    health=[r['data'] for r in events if r['event']=='health'];active=[r for r in frames if not r['menu'] and not r['dead'] and not r['map_loading']]
    report={'window_utc':[start,end],'window_local_prague':['2026-10-15 20:14:30','2026-10-15 21:03:00'],'local_headset':'Quest Pro / WiVRn-Pro, 90 Hz','all_windows':frames_summary(frames),'active_windows':frames_summary(active),'by_class':{role:frames_summary([r for r in active if r['class']==role]) for role in sorted({r['class'] for r in active})},'scope_windows':frames_summary([r for r in active if r['scope']]),'nvg_windows':frames_summary([r for r in active if r['nvg']]),'server':{'events':dict(collections.Counter(r['event'] for r in events)),'peak_connected_players':max((len(r['players']) for r in health),default=0),'sampled_physics_ms':describe([r['physics_ms'] for r in health]),'sampled_process_ms':describe([r['process_ms'] for r in health]),'diagnostics':[r['data'] for r in events if r['event']=='engine_diagnostic']},'slowest_windows':[{k:r[k] for k in ['utc','class','fps','frame_ms_p95','frame_ms_max','menu','scope','nvg','vehicle']} for r in sorted(active,key=lambda r:r['fps'])[:10]],'limitations':['Frame percentiles describe separate 10-second windows; a global frame p95 cannot be reconstructed.','Vive Pro 2 was reported at 90 Hz (corrected from the earlier 120 Hz report); these saved frame reports are from the local 90 Hz Quest Pro client, not the Vive client.','No per-frame physics/grass/audio attribution was recorded in this session. New workload grouping is added for subsequent tests.','Legacy server health fields do not represent all native CQ combat state; they cannot establish kills, ammo usage or dropped input from their unchanged counters.','Only a small number of clients participated; this is not a 64-player capacity qualification.']}
    (out/'analytics.json').write_text(json.dumps(report,indent=2)+'\n')
    evidence=[]
    for path in [src/name for name in ['client.log','client-engine.log','client-network.jsonl','server-events.jsonl','server-journal.log','local-runtime-journal.log','local-gpu-kernel.log']]:
        if path.is_file() and path.suffix in ['.log','.jsonl']:
            data=path.read_bytes();evidence.append({'file':path.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
    (out/'evidence.json').write_text(json.dumps({'raw_logs':str(src),'files':evidence},indent=2)+'\n')
    print(json.dumps({'active_fps':report['active_windows']['weighted_fps'],'server':report['server']},indent=2))

if __name__=='__main__':main()
