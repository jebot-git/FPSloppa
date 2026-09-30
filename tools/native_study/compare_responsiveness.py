"""Compare fallback, existing native codec, and fused C++ packing in ABCCBA order."""
import argparse, hashlib, json, os, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--out', type=pathlib.Path, default=ROOT/'test-results/native-responsiveness')
    args = parser.parse_args(); args.out.mkdir(parents=True, exist_ok=True)
    options = {'fallback': ['--gdscript-codec'], 'codec_only': ['--gdscript-network-packing'], 'fused': []}
    reports = []
    for index, variant in enumerate(['fallback', 'codec_only', 'fused', 'fused', 'codec_only', 'fallback']):
        log = args.out/f'{index}-{variant}.log'
        with log.open('w') as output:
            process = subprocess.run([args.godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                '--log-file', str(args.out/f'{index}-engine.log'), '--script', 'res://tools/native_study/responsiveness.gd', '--', *options[variant]],
                cwd=ROOT, env={**os.environ, 'XDG_DATA_HOME': str(args.out/'user')}, stdout=output, stderr=subprocess.STDOUT, timeout=90)
        lines = log.read_text().splitlines()
        errors = [line for line in lines if line.startswith(('SCRIPT ERROR:', 'ERROR:'))]
        results = [json.loads(line.removeprefix('RESPONSIVENESS_PERF_RESULT ')) for line in lines if line.startswith('RESPONSIVENESS_PERF_RESULT ')]
        if process.returncode or errors or not results: raise RuntimeError(f'{variant}: {errors}, see {log}')
        result = results[-1]
        if result['native_packing'] != (variant == 'fused'): raise RuntimeError(f'Wrong packing path active: {variant}')
        if result['native_codec'] != (variant != 'fallback'): raise RuntimeError(f'Wrong codec active: {variant}')
        reports.append({'variant': variant, 'result': result}); print(variant, json.dumps(result), flush=True)
    baseline = reports[0]['result']
    for report in reports[1:]:
        for before, after in zip(baseline['snapshots'], report['result']['snapshots']):
            assert before['bytes'] == after['bytes'] and before['oversized_records'] == after['oversized_records']
        for before, after in zip(baseline['inputs'], report['result']['inputs']):
            assert before['bytes'] == after['bytes'] and before['max_bytes'] == after['max_bytes']
    library = ROOT/'addons/fps_native/bin/libfpsloppa_native.so'
    receipt = {'reports': reports, 'library_sha256': hashlib.sha256(library.read_bytes()).hexdigest(),
        'scope': 'Sequential ABCCBA, no rendering or ENet; assert identical payload sizes. Linux library is a local host build, not a portable release.'}
    (args.out/'summary.json').write_text(json.dumps(receipt, indent=2)+'\n')
if __name__ == '__main__': main()
