"""Summarize grass headset A/B takes; incomplete takes are kept but not ranked."""
import argparse,csv,json,math,statistics
from pathlib import Path

def distribution(values):
    v=sorted(values)
    if not v:return {}
    return {'samples':len(v),'mean':statistics.mean(v),'p50':statistics.median(v),'p95':v[math.ceil((len(v)-1)*.95)],'p99':v[math.ceil((len(v)-1)*.99)],'max':v[-1]}

def summarize(meta):
    path=Path(meta['csv'])
    with path.open() as f:rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader(f)]
    result={'drawing_control':{k:meta[k] for k in ['selection_only','seed_instances','seed_drawing_sha256','end_drawing_sha256','drawing_unchanged','measurement'] if k in meta},'stage':meta['stage'],'take':meta['take'],'condition':meta['condition'],'reason':meta['reason'],'xr':meta['xr'],'target_hz':meta.get('target_hz',90),'phases':{},'quality_flags':[]}
    elapsed=0;groups={'all':[],'still_head_turn':[],'walk':[],'run':[]}
    for r in rows:
        elapsed+=r['interval_us']/1e6
        groups['all'].append(r);groups['still_head_turn' if elapsed<=20 else 'walk' if elapsed<=40 else 'run'].append(r)
    for phase,rs in groups.items():
        if not rs:continue
        duration=sum(r['interval_us'] for r in rs)/1e6;budget=1000/result['target_hz']
        result['phases'][phase]={'seconds':duration,'fps':len(rs)/duration,'wall_ms':distribution([r['interval_us']/1000 for r in rs]),'over_budget_5pct':sum(r['interval_us']/1000>budget*1.05 for r in rs),'over_2budgets':sum(r['interval_us']/1000>budget*2 for r in rs),'environment_selection_ms':distribution([r.get('environment_ms',0) for r in rs]),'grass_selection_ms':distribution([r['grass_ms'] for r in rs]),'grass_audio_ms':distribution([r['grass_audio_us']/1000 for r in rs]),'gpu_ms':distribution([r['render_gpu_ms'] for r in rs]),'audio_scans':sum(r['audio_scans'] for r in rs),'audio_cell_builds':sum(r['audio_cell_builds'] for r in rs),'audio_emissions':sum(r['audio_emissions'] for r in rs),'speed':distribution([r['speed'] for r in rs])}
    if meta.get('selection_only') and (not meta.get('drawing_unchanged') or meta.get('seed_instances',0)<256):
        result['quality_flags'].append('Selection-only drawing control failed; discard this take.')
    if meta['condition']['draw'] and not meta['condition']['selection'] and rows and all(r['grass_instances']==0 for r in rows):
        result['quality_flags'].append('Frozen grass retained zero instances: this take does not isolate selection from drawing cost.')
    first=result['phases'].get('still_head_turn',{})
    if first.get('speed',{}).get('mean',0)>.3:
        result['quality_flags'].append('The first 20 seconds contain movement; the still/head-turn label describes the prompt, not observed stillness.')
    if meta['condition']['audio'] and meta['condition']['play'] and rows and not any(r['audio_emissions']>0 for r in rows):
        result['quality_flags'].append('No grass audio emitted; playback effect is untested.')
    return result

def load_take(path):
    meta=json.loads(path.read_text());meta['csv']=str(path.with_suffix('.csv'))
    return summarize(meta)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);a=p.parse_args()
    takes=[load_take(f) for f in sorted(a.directory.rglob('stage-*-take-*.json'))]
    report={'takes':takes,'limitations':['Frame intervals include CPU work, waits and runtime pacing; they are not pure CPU duration.','Renderer GPU timestamps can lag; direct selection/audio durations are measured on the sample callback frame.','Do not sum independent percentiles. Compare repeated matched routes and phases, including reversed condition order.','Frozen selection deliberately holds stale geometry while moving; this condition is diagnostic only.','Desktop smoke captures do not qualify headset performance.']}
    (a.directory/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    for t in takes:
        r=t['phases'].get('all',{});w=r.get('wall_ms',{})
        print(f"{t['condition']['name']}: {t['reason']}, {r.get('fps',0):.1f} FPS, p95 {w.get('p95',0):.2f} ms, n={w.get('samples',0)}")
if __name__=='__main__':main()
