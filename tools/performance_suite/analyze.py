"""Analyze raw frames, never medians of window medians. No third-party packages."""
import json
import math
import statistics
from pathlib import Path


def distribution(values):
    values = sorted(x for x in values if isinstance(x, (int, float)) and math.isfinite(x))
    if not values:
        return None
    return {'n': len(values), 'p50': statistics.median(values),
            'p95': values[math.ceil(.95*len(values))-1],
            'p99': values[math.ceil(.99*len(values))-1], 'max': values[-1]}


def summarize(folder):
    meta = json.loads((folder/'metadata.json').read_text())
    console=folder/'console.log'
    if console.exists() and ('SCRIPT ERROR:' in console.read_text() or '\nERROR:' in console.read_text()):
        raise ValueError(f'Engine errors invalidate capture: {folder}')
    if not meta['complete']:
        raise ValueError(f'Incomplete capture: {folder}')
    frames = [json.loads(line) for line in (folder/'frames.jsonl').read_text().splitlines()]
    if not frames or len(frames) != meta['frames']:
        raise ValueError(f'Missing/truncated frames: {folder}')
    if any(b['ticks_us'] <= a['ticks_us'] for a, b in zip(frames, frames[1:])):
        raise ValueError('Nonmonotonic frame timestamps')
    hz = meta['budget_hz']
    if not math.isfinite(hz) or hz <= 0:
        raise ValueError('Invalid frame budget')
    if meta.get('xr') is True and meta.get('refresh_hz',0)>0 and abs(meta['refresh_hz']-hz)>.5:
        raise ValueError('Requested frame budget does not match headset refresh rate')
    report = {'path': str(folder), 'metadata': meta, 'timings': {}, 'weapons': {}, 'scopes': {}}
    for key in ('frame_ms','process_ms','physics_ms','render_cpu_ms','render_gpu_ms','previous_capture_ms'):
        values = [f[key] for f in frames]
        # Godot's unsupported GPU timer reports zero; do not call that perfect performance.
        report['timings'][key] = None if key.startswith('render_') and not any(values) else distribution(values)
    report['over_budget_pct'] = sum(f['frame_ms'] > 1000/hz for f in frames)*100/len(frames)
    report['menu_frames'] = sum(f['menu'] for f in frames)
    report['inactive_frames'] = sum(not f['active'] for f in frames)
    report['unfocused_frames'] = sum(not f.get('focused',True) for f in frames)
    for rules, weapon in sorted({(f['rules'], f['weapon']) for f in frames}):
        report['weapons'][f'{rules}:{weapon}'] = distribution([f['frame_ms'] for f in frames if (f['rules'],f['weapon']) == (rules,weapon)])
    for key in sorted({k for f in frames for k in f.get('scopes',{})}):
        values = [f.get('scopes',{}).get(key,[0,0]) for f in frames]
        report['scopes'][key] = {'ms_per_frame':distribution([v[0]/1000 for v in values]),'calls':sum(v[1] for v in values)}
    events = [json.loads(line) for line in (folder/'events.jsonl').read_text().splitlines()]
    report['events'] = {kind:sum(e['type']==kind for e in events) for kind in sorted({e['type'] for e in events})}
    if meta['config']['variant'] in ('frozen','hidden') and any(report['scopes'].get(k,{}).get('calls',0) for k in ('rig','pose')):
        raise ValueError('Avatar isolation failed: animation/IK still ran')
    report['compositor_measured'] = False
    return report


def compatibility(report):
    m = report['metadata']; c = m['config']
    return [m.get(k) for k in ('map','msaa','scale3d','tracking','engine','renderer','gpu','viewport','xr','refresh_hz','render_size','presentation','haptics','avatar_hashes')] + [c[k] for k in ('source_hash','rules','seconds','warmup','live')]


def compare(reports):
    if not reports:
        raise ValueError('No captures')
    if any(compatibility(r) != compatibility(reports[0]) for r in reports[1:]):
        raise ValueError('Incompatible source, hardware, settings or workload; comparison refused')
    groups = {}
    for r in reports:
        c = r['metadata']['config']; key = c['stage']+':'+c['capture']+':'+c['variant']
        groups.setdefault(key, []).append(r)
    summary = {}
    for key, runs in groups.items():
        summary[key] = {'runs': len(runs), 'median_run_p50_ms': statistics.median(r['timings']['frame_ms']['p50'] for r in runs),
                        'run_p95_ms': [r['timings']['frame_ms']['p95'] for r in runs],
                        'over_budget_pct': [r['over_budget_pct'] for r in runs]}
    return summary


def write_report(folder):
    reports = [summarize(p.parent) for p in sorted(folder.glob('*/metadata.json'))]
    result = {'runs':reports,'comparison':compare(reports),
        'limitations':['Viewport GPU queries are delayed; CPU and GPU overlap and must not be added.',
        'Script scopes are inclusive, not engine skinning or compositor timing.',
        'Live motion is not deterministic; inspect menu/focus and weapon exposure before comparing.',
        'Over-budget application intervals are not compositor missed-frame or reprojection counts.']}
    (folder/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
