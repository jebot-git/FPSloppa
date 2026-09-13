"""Exercise the actual packaged installer and import all maps in isolated Godot runs."""
from pathlib import Path
import argparse
import concurrent.futures
import importlib.util
import json
import os
import subprocess
import tempfile
import zipfile
from package import ROOT, sha


def verify(archive, godot):
    output = ROOT / 'test-results/optional-map-pack'
    output.mkdir(parents=True, exist_ok=True)
    checks = []
    def check(value, label):
        if not value:
            raise AssertionError(label)
        checks.append(label)
    with tempfile.TemporaryDirectory(prefix='fpsloppa-optional-pack-', dir=output) as folder:
        work = Path(folder)
        package = work / 'package'
        with zipfile.ZipFile(archive) as source:
            check(source.testzip() is None, 'Archive CRC')
            check(all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in source.namelist()), 'Archive paths')
            source.extractall(package)
        manifest = json.loads((package / 'PACK.json').read_text())
        for row in manifest['files']:
            check(sha((package / row['path']).read_bytes()) == row['sha256'], 'Payload hash: ' + row['path'])
        spec = importlib.util.spec_from_file_location('packaged_installer', package / 'install.py')
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        installed = work / 'installed'
        dry = installer.install(package, installed, dry_run=True)
        check(dry['maps'] == 53 and not installed.exists(), 'Dry run writes nothing')
        installed.mkdir()
        (installed / 'maps').mkdir()
        sentinels = {'server.cfg': b'set dm_maplist "personal_arena"\n', 'maps/dm_maplist.txt': b'personal_arena\n', 'maps/personal_arena.bsp': b'custom sentinel'}
        for name, data in sentinels.items():
            (installed / name).write_bytes(data)
        result = installer.install(package, installed)
        check(result['maps'] == 53, 'All 53 maps installed')
        check(installer.install(package, installed) == result, 'Repeat installation is idempotent')
        for name, data in sentinels.items():
            check((installed / name).read_bytes() == data, 'Preserved user file: ' + name)
        # Remove only this test's deliberately invalid BSP before engine discovery.
        (installed / 'maps/personal_arena.bsp').unlink()
        for category in manifest['categories']:
            dest = work / ('category-' + category)
            chosen = installer.install(package, dest, [category])
            expected = {r['id'] for r in manifest['maps'] if r['category'] == category}
            check({p.stem for p in (dest / 'maps').glob('*.bsp')} == expected and chosen['maps'] == len(expected), 'Selective install: ' + category)
            check(not list((dest / 'maps').glob('*_maplist.txt')), 'Selective install preserves rotations: ' + category)
        first = next(r for r in manifest['files'] if r['path'].endswith('.bsp'))
        conflict = work / 'conflict'
        target = conflict / first['install_path']
        target.parent.mkdir(parents=True)
        target.write_bytes(b'user-edited-map')
        try:
            installer.install(package, conflict)
            raise AssertionError('Conflict accepted')
        except ValueError as error:
            check('Preserving different' in str(error), 'Existing modified map refused')
        check(list(conflict.rglob('*.bsp')) == [target] and target.read_bytes() == b'user-edited-map', 'Conflict preflight leaves entire destination untouched')
        source = package / first['path']
        original = source.read_bytes()
        source.write_bytes(b'corrupt')
        try:
            installer.install(package, work / 'corrupt')
            raise AssertionError('Corrupt map accepted')
        except ValueError as error:
            check('checksum mismatch' in str(error) and not (work / 'corrupt').exists(), 'Corrupt payload refused before writes')
        source.write_bytes(original)
        for unsafe in ['../escape', '/absolute', 'maps/../../escape', 'maps\\escape']:
            try:
                installer.contained(installed, unsafe)
                raise AssertionError('Unsafe path accepted')
            except ValueError:
                checks.append('Unsafe path refused: ' + unsafe)
        (work / 'outside').mkdir()
        (installed / 'escape').symlink_to(work / 'outside', target_is_directory=True)
        try:
            installer.contained(installed, 'escape/map.bsp')
            raise AssertionError('Symlink escape accepted')
        except ValueError:
            checks.append('Symlink escape refused')

        def run(row):
            key = row['id']
            report = output / (key + '.json')
            command = [godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script',
                       'res://tools/optional_maps/smoke.gd', '--', key, str(report), '--asset-root', str(installed)]
            env = dict(os.environ, XDG_DATA_HOME=str(work / 'userdata' / key))
            with (output / (key + '.log')).open('w') as log:
                try:
                    code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120).returncode
                except subprocess.TimeoutExpired:
                    code = 124
            errors = [line for line in (output / (key + '.log')).read_text().splitlines() if 'ERROR:' in line]
            data = json.loads(report.read_text()) if code == 0 and report.exists() else {'id': key, 'failures': ['Process failed or report absent']}
            data.update(exit_code=code, errors=errors)
            data['passed'] = code == 0 and not errors and not data['failures'] and data.get('sha256') == row['sha256']
            print(key, 'PASS' if data['passed'] else 'FAIL', flush=True)
            return data
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(run, manifest['maps']))
    report = {'archive': str(archive.relative_to(ROOT)) if archive.is_relative_to(ROOT) else str(archive),
              'archive_sha256': sha(archive.read_bytes()), 'installer_checks': checks, 'maps': results,
              'passed': all(r['passed'] for r in results),
              'limitations': 'Fresh headless runtime imports and objective metadata checks; no new multiplayer balance, route coverage or headset rendering/performance tests.'}
    (ROOT / 'docs/validation/optional-map-pack.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'maps': len(results), 'installer_checks': len(checks), 'passed': report['passed']}))
    return report['passed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, default=ROOT / 'dist' / ('FPSloppa-' + (ROOT / 'VERSION').read_text().strip() + '-Optional-Community-Maps.zip'))
    parser.add_argument('--godot', default='/tmp/fpsloppa-godot-official/Godot_v4.7.2-stable_linux.x86_64')
    args = parser.parse_args()
    raise SystemExit(0 if verify(args.archive, args.godot) else 1)
