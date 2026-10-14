"""Compare direct Jolt and the custom backend using identical frozen engine traces.

Builds optional Jolt targets, runs both native backends, checks the existing
Godot oracle, and retains failed gates. No gameplay or VPS deployment.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess

from run import ROOT, compare, distribution, traces

JOLT_REVISION = 'e77f175595e64cb44218cc9d9d56fc365ad0e36a'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inputs', type=Path, required=True, help='Existing run.py output with world.bin, traces.bin and oracle.json/log')
    parser.add_argument('--output', type=Path, default=Path('/tmp/cq-jolt-comparison'))
    parser.add_argument('--jolt-source', type=Path, help='Local pinned Jolt source; otherwise CMake fetches it')
    parser.add_argument('--build-dir', type=Path, help='Reusable CMake build directory')
    parser.add_argument('--repeats', type=int, default=12)
    parser.add_argument('--jobs', type=int, default=6)
    parser.add_argument('--require-parity', action='store_true')
    args = parser.parse_args()
    if not 1 <= args.repeats <= 1000 or not 1 <= args.jobs <= 32:
        parser.error('repeats must be 1..1000; jobs must be 1..32')
    source = args.inputs.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    build = (args.build_dir or out/'build').resolve()

    def execute(command, log, timeout=180):
        with (out/log).open('w') as stream:
            subprocess.run([str(x) for x in command], cwd=ROOT, stdout=stream,
                           stderr=subprocess.STDOUT, check=True, timeout=timeout)

    metadata = json.loads((source/'oracle.json').read_text())
    oracle_log = (source/'oracle.log').read_text()
    if 'ERROR:' in oracle_log or 'COLLISION_ORACLE ' not in oracle_log:
        raise RuntimeError('Input oracle contains errors or did not complete')
    if len(metadata.get('movement_tick_deltas', [])) != 64 or any(abs(x-1/30)>1e-6 for x in metadata['movement_tick_deltas']):
        raise RuntimeError('Input must contain 64 real 30 Hz movement steps')
    query_rows = traces(source/'traces.bin')
    cmake = ['cmake', '-S', ROOT/'tools/collision_service/native', '-B', build,
             '-DCMAKE_BUILD_TYPE=Release', '-DCQ_WITH_JOLT=ON']
    if args.jolt_source:
        cmake.append('-DCQ_JOLT_SOURCE_DIR='+str(args.jolt_source.resolve()))
    # A local dependency must have the same provenance as the pinned fetch.
    if args.jolt_source:
        dependency = args.jolt_source.resolve()
        manifest_path = dependency/'cq-source-manifest.json'
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text())
            if manifest['revision'] != JOLT_REVISION:
                raise RuntimeError('Local Jolt manifest revision differs from pinned revision')
            for item in manifest['files']:
                relative = Path(item['path'])
                if relative.is_absolute() or '..' in relative.parts:
                    raise RuntimeError('Invalid dependency manifest path')
                data = (dependency/relative).read_bytes()
                digest = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
                if digest != item['sha']:
                    raise RuntimeError('Jolt source differs from manifest: '+item['path'])
            provenance = {'method': 'verified Git blob SHA-1 manifest', 'files': len(manifest['files']), 'revision': manifest['revision']}
            shutil.copyfile(manifest_path, out/'jolt-source-manifest.json')
        else:
            revision = subprocess.check_output(['git', '-C', str(dependency), 'rev-parse', 'HEAD'], text=True).strip()
            dirty = subprocess.run(['git', '-C', str(dependency), 'diff', '--quiet', 'HEAD']).returncode
            if revision != JOLT_REVISION or dirty:
                raise RuntimeError('Local Jolt must be an unmodified checkout of '+JOLT_REVISION)
            provenance = {'method': 'pinned clean Git checkout', 'revision': revision}
    else:
        provenance = {'method': 'CMake FetchContent pinned Git revision', 'revision': JOLT_REVISION}
    execute(cmake, 'configure.log')
    execute(['cmake', '--build', build, '-j', args.jobs], 'build.log', 900)
    execute(['ctest', '--test-dir', build, '--output-on-failure'], 'ctest.log')
    execute([build/'collision_unit'], 'custom-unit.json')
    execute([build/'collision_jolt_unit'], 'jolt-unit.json')

    backends = {'custom': build/'collision_suite', 'jolt': build/'collision_jolt_suite'}
    evidence = {name: {'benchmarks': [], 'parallel_results_identical': True} for name in backends}
    reference = {}
    schedule = []
    for batch in [32, 64]:
        for worker in [1, 2, 4]:
            # Alternate which backend runs first; never run timed backends together.
            order = list(backends) if len(schedule)%2 == 0 else list(reversed(backends))
            schedule.append({'batch': batch, 'workers': worker, 'order': order})
            for name in order:
                stem = f'{name}-batch-{batch}-workers-{worker}'
                result_path = out/(stem+'.csv')
                execute([backends[name], source/'world.bin', source/'traces.bin', result_path,
                         worker, args.repeats, batch], stem+'.json')
                timing = json.loads((out/(stem+'.json')).read_text())
                evidence[name]['benchmarks'].append(timing)
                data = result_path.read_bytes()
                if name not in reference:
                    reference[name] = data
                    evidence[name]['parity'] = compare(query_rows, result_path, metadata)
                else:
                    evidence[name]['parallel_results_identical'] &= data == reference[name]
                print('DIRECT_COLLISION_BATCH', name, batch, worker, timing['by_kind'], flush=True)

    # Loader validation is shared; make sure both linked executables reject it.
    for name, binary in backends.items():
        malformed = []
        for label, data in [('bad-magic', b'notworld'), ('truncated', b'CQCOLL1\0')]:
            path = out/(label+'.bin')
            path.write_bytes(data)
            proc = subprocess.run([str(binary), str(path), str(source/'traces.bin'), str(out/'invalid.csv'), '1', '1', '64'], capture_output=True, timeout=10)
            malformed.append({'case': label, 'rejected': proc.returncode == 2})
        evidence[name]['malformed_input'] = malformed

    oracle_groups = {}
    for batch in [32, 64]:
        oracle_groups[str(batch)] = {kind: distribution([sum(values['per_query_ms'][i:i+batch]) for i in range(0, len(values['per_query_ms'])-batch+1, batch)]) for kind, values in metadata['timings'].items()}
    inputs = {name: hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ['world.bin', 'traces.bin', 'oracle.json']}
    report = {
        'jolt_version': '5.6.0', 'jolt_revision': JOLT_REVISION, 'dependency_provenance': provenance,
        'environment': {'platform': platform.platform(), 'cpu_count': os.cpu_count(),
                        'cpu_model': next((x.split(':', 1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')), 'unknown'),
                        'compiler': subprocess.check_output(['c++', '--version'], text=True).splitlines()[0],
                        'engine_oracle': oracle_log.splitlines()[0]},
        'units': {name: json.loads((out/(name+'-unit.json')).read_text()) for name in backends},
        'input_sha256': inputs, 'input_counts': {key: metadata[key] for key in ['height_samples', 'primitives', 'queries']},
        'backends': evidence, 'schedule': schedule, 'repeats': args.repeats,
        'oracle_serial_batch_sums_ms': oracle_groups,
        'cmake_cache_sha256': hashlib.sha256((build/'CMakeCache.txt').read_bytes()).hexdigest(),
        'source_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'tools/collision_service').rglob('*')) if p.is_file() and p.suffix in ['.py', '.cpp', '.hpp', '.gd']},
        'production_enabled': False, 'promotion_pass': False,
        'tolerances': {'ray_distance_m': .01, 'ray_normal_vector_distance': .02, 'sweep_bracket_slack_m': .01,
                       'movement_position_m': .03, 'movement_velocity_m_s': .05, 'movement_support': 'exact'},
        'limitations': ['Local frozen-scene queries, not VPS/server frametimes or combat capacity',
                        'Godot timings retained from the input oracle; not a fresh Godot benchmark',
                        'Jolt SIMD/double precision/assertions enabled; custom uses default compiler ISA; see CMakeCache.txt',
                        'Jolt uses a reflected 16-bit compressed heightfield to preserve the exported diagonal; not bit-exact samples',
                        'Jolt controller adapter refreshes contacts, captures solver velocity, updates and snaps if unsupported; no stairs in the engine oracle',
                        'No coupled dynamic actors, moving supports, road/water gameplay, or prediction integration',
                        'Jolt does not expose GJK convergence or per-query narrow-phase iteration counters here; zero counters mean uninstrumented',
                        'Jolt unresolved count detects character contact-buffer overflow only, not every possible solver iteration limit',
                        'Allocation counts include operator new and Jolt allocator hooks, excluding reserved scratch use',
                        'Timings include pool dispatch/wait and query execution; preparation/world setup excluded',
                        'Compatibility tolerances are unchanged from run.py; all failures remain failed gates']}
    (out/'comparison.json').write_text(json.dumps(report, indent=2)+'\n')
    shutil.copyfile(build/'CMakeCache.txt', out/'CMakeCache.txt')
    print('JOLT_COMPARISON_RESULT', json.dumps({name: {'failed': values['parity']['failed_cases'], 'stable': values['parallel_results_identical']} for name, values in evidence.items()}))
    if args.require_parity and any(not x['parity']['pass'] or not x['parallel_results_identical'] or not all(y['rejected'] for y in x['malformed_input']) for x in evidence.values()):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
