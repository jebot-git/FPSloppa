"""Evaluate Jolt fixes, explicit omissions and test-only stair-ramp authoring.

Requires a configured CQ_WITH_JOLT build (see compare_jolt.py). Keeps the
unchanged Godot parity gate and the independent functional gate separate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
from run import ROOT, compare, traces
from verify_horizontal_cast import verify


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inputs', type=Path, required=True)
    p.add_argument('--build-dir', type=Path, required=True)
    p.add_argument('--output', type=Path, default=Path('/tmp/cq-jolt-blockers-final'))
    p.add_argument('--repeats', type=int, default=24)
    p.add_argument('--godot', default='godot')
    a = p.parse_args()
    if not 1 <= a.repeats <= 1000:
        p.error('repeats must be 1..1000')
    out, inputs, build = a.output.resolve(), a.inputs.resolve(), a.build_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith('CQ_JOLT_')}

    def execute(cmd, stem, extra=None, timeout=180):
        with (out/(stem+'.log')).open('w') as log:
            subprocess.run([str(x) for x in cmd], cwd=ROOT, env=dict(env, **(extra or {})),
                           stdout=log, stderr=subprocess.STDOUT, timeout=timeout, check=True)
        return (out/(stem+'.log')).read_text()

    execute(['cmake', '--build', build, '-j', '4'], 'build')
    execute(['ctest', '--test-dir', build, '--output-on-failure'], 'ctest')
    units = {}
    for name in ['collision_unit', 'collision_jolt_unit', 'collision_jolt_blockers']:
        log = execute([build/name], name)
        units[name] = json.loads(log.splitlines()[-1])
    oracle = json.loads((inputs/'oracle.json').read_text())
    rows = traces(inputs/'traces.bin')
    variants = {
        'legacy': {'CQ_JOLT_RAY_BACKFACES': '1', 'CQ_JOLT_PRECISE_RAYS': '0', 'CQ_JOLT_SWEEP_MARGIN': '.001', 'CQ_JOLT_SWEEP_TOLERANCE': '1e-5'},
        'front-face-rays': {'CQ_JOLT_RAY_BACKFACES': '0', 'CQ_JOLT_PRECISE_RAYS': '0', 'CQ_JOLT_SWEEP_MARGIN': '.001', 'CQ_JOLT_SWEEP_TOLERANCE': '1e-5'},
        'precise-rays': {'CQ_JOLT_RAY_BACKFACES': '0', 'CQ_JOLT_PRECISE_RAYS': '1', 'CQ_JOLT_SWEEP_MARGIN': '.001', 'CQ_JOLT_SWEEP_TOLERANCE': '1e-5'},
        'selected': {},
    }
    results = {}
    for name, policy in variants.items():
        execute([build/'collision_jolt_suite', inputs/'world.bin', inputs/'traces.bin', out/(name+'.csv'), 1, a.repeats, 64], name, policy)
        results[name] = {'environment_overrides': policy, 'parity': compare(rows, out/(name+'.csv'), oracle),
                         'benchmark': json.loads((out/(name+'.log')).read_text())}
        print('JOLT_POLICY', name, results[name]['parity']['failed_cases'], flush=True)
    selected_csv = (out/'selected.csv').read_bytes()
    stable = True
    batches = []
    for batch in [32, 64]:
        for workers in [1, 2, 4]:
            name = f'selected-{batch}-{workers}'
            execute([build/'collision_jolt_suite', inputs/'world.bin', inputs/'traces.bin', out/(name+'.csv'), workers, a.repeats, batch], name)
            stable &= (out/(name+'.csv')).read_bytes() == selected_csv
            batches.append(json.loads((out/(name+'.log')).read_text()))
    cache = out/'user-data/godot/app_userdata/FPSloppa'
    cache.mkdir(parents=True, exist_ok=True)
    source_cache = inputs/'user-data/godot/app_userdata/FPSloppa'
    for source in source_cache.glob('jungle-heightmap-*.res'):
        shutil.copyfile(source, cache/source.name)
    godot_env = {'XDG_DATA_HOME': str(out/'user-data')}
    log = execute([a.godot, '--headless', '--xr-mode', 'off', '--path', ROOT, '--script', 'tools/collision_service/isolated_oracle.gd', '--', ROOT/'tools/collision_service/fixtures/disputed_casts.json', out/'isolated-oracle.json'], 'isolated-oracle', godot_env)
    if 'ERROR:' in log or 'ISOLATED_ORACLE ' not in log:
        raise RuntimeError('Isolated oracle failed')
    ramp = out/'ramp-map'
    ramp.mkdir(exist_ok=True)
    log = execute([a.godot, '--headless', '--xr-mode', 'off', '--path', ROOT, '--script', 'tools/collision_service/export_suite.gd', '--', '--world', ramp/'world.bin', '--traces', ramp/'traces.bin', '--metadata', ramp/'oracle.json', '--stair-ramps'], 'ramp-export', godot_env)
    if 'ERROR:' in log or 'COLLISION_ORACLE ' not in log:
        raise RuntimeError('Ramp map export failed')
    metadata = json.loads((ramp/'oracle.json').read_text())
    flights = metadata['stair_ramps']['flights']
    with (ramp/'flights.bin').open('wb') as stream:
        stream.write(b'CQFLIGHT'+struct.pack('<I', len(flights)))
        for flight in flights:
            stream.write(struct.pack('<6d', *flight['start'], *flight['end']))
    log = execute([build/'collision_jolt_map_traversal', ramp/'world.bin', ramp/'flights.bin'], 'map-traversal')
    traversal = json.loads(log)
    execute([build/'collision_jolt_suite', ramp/'world.bin', ramp/'traces.bin', out/'ramp-results.csv', 1, a.repeats, 64], 'ramp-benchmark')
    ramp_parity = compare(traces(ramp/'traces.bin'), out/'ramp-results.csv', metadata)
    analytic_ramp = []
    for failure in ramp_parity['failures']:
        if failure['scenario'] == 'ordnance':
            analytic_ramp.append(verify(ramp/'world.bin', ramp/'traces.bin', out/'ramp-results.csv', failure['index']))
    metric_rows = []
    for line in (out/'collision_jolt_blockers.log').read_text().splitlines():
        if line.startswith(('RAMP ', 'ISLAND ', 'STAIR ')):
            metric_rows.append(dict(re.findall(r'(\w+)=([^ ]+)', line)))
    classified = all(f['index'] in {1278, 1457, 1470} and f['reason'] == 'fraction'
                     and f['expected_hit'] and f['actual_hit'] for f in results['selected']['parity']['failures'])
    ramp_classified = len(analytic_ramp) == ramp_parity['failed_cases'] and all(x['pass'] for x in analytic_ramp)
    report = {
        'units': units, 'variants': results, 'selected_batches': batches,
        'parallel_results_identical': stable, 'traversal': traversal,
        'ramp_authoring': metadata['stair_ramps'], 'ramp_map_parity': ramp_parity,
        'fixture_metrics': metric_rows, 'ramp_cast_analytic_checks': analytic_ramp,
        'selected_policy': {'terrain_ray_backfaces': False, 'cylinder_ray_precision': 'double analytic interval inside Jolt broadphase',
                            'extra_sweep_radius_m': 0, 'sweep_tolerance_m': 1e-6, 'character_padding_m': .001, 'horizontal_character_pushing': False,
                            'authored_stairs': 'test-only thin ramps; visual treads unchanged', 'stair_assist_on_ramps': False},
        'functional_fixture_pass': classified and ramp_classified and stable and all(b['unresolved'] == 0 for b in batches) and traversal['failed'] == 0 and all(v['failures'] == 0 for v in units.values()),
        'legacy_engine_parity_pass': results['selected']['parity']['pass'], 'production_enabled': False, 'promotion_pass': False,
        'remaining_blockers': ['live server/client collision bindings and identical prediction manifest',
                               'dynamic lifecycle, rotation/compound motion and mixed constrained-island integration',
                               'road/water/runover gameplay integration on Jolt-produced transforms',
                               'off-host 32/64-player combat, networking and VPS tail-latency validation'],
        'limits': ['Independent analytic fixture gate does not erase three remaining Godot parity failures',
                   'Dense islands are serialized; the built-in simple character checker is not thread safe',
                   'Relative-pair stop is a translational proof, not a complete arbitrary island resolver',
                   'Full-map stair traversal feeds existing CS gravity; acceleration/input gameplay is not ported',
                   'Ramp/actor-island timings are local synthetic workloads; no capacity conclusion'],
        'input_sha256': {n: hashlib.sha256((inputs/n).read_bytes()).hexdigest() for n in ['world.bin', 'traces.bin']},
        'ramp_sha256': {n: hashlib.sha256((ramp/n).read_bytes()).hexdigest() for n in ['world.bin', 'traces.bin', 'flights.bin']},
        'source_sha256': {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((ROOT/'tools/collision_service').rglob('*')) if f.is_file() and f.suffix in ['.py', '.gd', '.cpp', '.hpp', '.json']},
    }
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('JOLT_BLOCKER_RESULT', json.dumps({'functional_fixture_pass': report['functional_fixture_pass'], 'legacy_parity_failures': results['selected']['parity']['failed_cases'], 'map_flights': len(flights)}))
    if not report['functional_fixture_pass']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
