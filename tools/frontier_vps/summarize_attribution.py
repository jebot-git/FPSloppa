"""Summarize scoped tick attribution without adding overlapping percentiles."""
import argparse, json, statistics
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--report', type=Path, required=True)
p.add_argument('--ticks', type=Path, required=True)
p.add_argument('--baseline', type=Path)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
report = json.loads(a.report.read_text())
lines = a.ticks.read_text().splitlines()
header = json.loads(lines[0]); names = header['scope_names']
ticks = [json.loads(line) for line in lines[1:]]
assert report['attribution']['scope_errors'] == 0
assert len(ticks) == report['attribution']['ticks']
cutoff = sorted(t['callback_us'] for t in ticks)[int(len(ticks) * .95)]
hot = [t for t in ticks if t['callback_us'] >= cutoff]
rows = []
for i, name in enumerate(names):
    values = [t['scopes'][i] if i < len(t['scopes']) else [0, 0, 0, 0] for t in ticks]
    hot_values = [t['scopes'][i] if i < len(t['scopes']) else [0, 0, 0, 0] for t in hot]
    calls = sum(v[0] for v in values)
    inclusive = sum(v[1] for v in values); own = sum(v[2] for v in values)
    rows.append({'scope': name, 'calls': calls, 'mean_calls_per_tick': calls / len(ticks),
                 'mean_inclusive_ms_per_tick': inclusive / 1000 / len(ticks),
                 'mean_self_ms_per_tick': own / 1000 / len(ticks),
                 'mean_call_ms': inclusive / 1000 / max(1, calls),
                 'mean_hot_tick_self_ms': sum(v[2] for v in hot_values) / 1000 / len(hot)})
rows.sort(key=lambda r: r['mean_self_ms_per_tick'], reverse=True)
query_ids = [i for i, name in enumerate(names) if name.startswith('query.')]
query_tick_ms = [sum(t['scopes'][i][2] for i in query_ids if i < len(t['scopes'])) / 1000 for t in ticks]
query_tick_calls = [sum(t['scopes'][i][0] for i in query_ids if i < len(t['scopes'])) for t in ticks]
def distribution(values):
    values = sorted(values)
    return {'mean': statistics.mean(values), 'p50': values[len(values)//2],
            'p95': values[int(len(values)*.95)], 'p99': values[int(len(values)*.99)], 'max': values[-1]}

result = {'ticks': len(ticks), 'players_min': min(t['players'] for t in ticks),
          'players_max': max(t['players'] for t in ticks), 'scope_errors': report['attribution']['scope_errors'],
          'achieved_hz': report['achieved_tick_hz'], 'hot_tick_cutoff_ms': cutoff / 1000,
          'hot_ticks': len(hot), 'scopes_by_exclusive_mean': rows,
          'queries': [r for r in rows if r['scope'].startswith('query.')],
          'query_total_ms_per_tick': distribution(query_tick_ms),
          'query_calls_per_tick': distribution(query_tick_calls),
          'mean_query_calls_per_tick': sum(r['mean_calls_per_tick'] for r in rows if r['scope'].startswith('query.')),
          'mean_query_self_ms_per_tick': sum(r['mean_self_ms_per_tick'] for r in rows if r['scope'].startswith('query.')),
          'mean_hot_tick_query_self_ms': sum(r['mean_hot_tick_self_ms'] for r in rows if r['scope'].startswith('query.')),
          'note': 'Query counts are engine API calls, not internal broadphase/narrowphase operations. Self time excludes instrumented children; inclusive categories overlap. Idle inputs carry into the following tick.'}
if a.baseline:
    baseline = json.loads(a.baseline.read_text())
    result['recording_disabled_hz'] = baseline['achieved_tick_hz']
    result['enabled_vs_disabled_wall_interval_change_percent'] = 100 * (baseline['achieved_tick_hz'] / report['achieved_tick_hz'] - 1)
    result['control_note'] = 'Consecutive shared-VPS runs, enabled first. Difference includes host/workload variation and is not a calibrated profiler overhead measurement. Both use the instrumented source; disabled still has wrapper branches.'
a.output.write_text(json.dumps(result, indent=2) + '\n')
for r in rows[:14]:
    print(f"{r['scope']:48} self {r['mean_self_ms_per_tick']:8.3f} inclusive {r['mean_inclusive_ms_per_tick']:8.3f} ms/tick calls {r['mean_calls_per_tick']:8.2f}")
print('Query API calls/tick:', round(result['mean_query_calls_per_tick'], 2), 'query ms/tick:', round(result['mean_query_self_ms_per_tick'], 3))
