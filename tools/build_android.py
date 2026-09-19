"""Build locally signed release-runtime Quest sideload APKs (Godot 4.7.2)."""
from pathlib import Path
import os, subprocess, secrets, json, zipfile, hashlib, argparse, re, shutil

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--thin', action='store_true', help=argparse.SUPPRESS)
parser.add_argument('--target', choices=['Quest'], default='Quest')
args = parser.parse_args()
if args.thin:parser.error('Thin APKs are retired; all builds include offline assets.')
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
jdk = Path(os.environ.get('JAVA_HOME', str(Path.home() / '.local/share/entryway-toolchains/jdk-17.0.20.1+1')))
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
if not godot: raise SystemExit('Set GODOT_BIN or install Godot on PATH')
env = dict(os.environ, JAVA_HOME=str(jdk), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
env['PATH'] = str(jdk / 'bin') + os.pathsep + env['PATH']
signing = Path.home() / '.local/share/entryway-toolchains/signing'
signing.mkdir(parents=True, exist_ok=True, mode=0o700)
credentials = signing / 'entryway-test.json'
if not credentials.exists():
    credentials.write_text(json.dumps({'password': secrets.token_urlsafe(32)}))
    credentials.chmod(0o600)
password = json.loads(credentials.read_text())['password']
key = signing / 'entryway-test.keystore'
env['ENTRYWAY_SIGNING_PASSWORD'] = password
if not key.exists():
    subprocess.run([str(jdk / 'bin/keytool'), '-genkeypair', '-keystore', str(key), '-alias', 'entryway-test', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '3650', '-dname', 'CN=Entryway Development Testing', '-storepass:env', 'ENTRYWAY_SIGNING_PASSWORD', '-keypass:env', 'ENTRYWAY_SIGNING_PASSWORD'], env=env, check=True)
    key.chmod(0o600)
env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(key), GODOT_ANDROID_KEYSTORE_RELEASE_USER='entryway-test', GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
if not (root / 'android/build/gradlew').exists():
    template = Path.home() / '.local/share/godot/export_templates/4.7.2.stable/android_source.zip'
    with zipfile.ZipFile(template) as z:
        z.extractall(root / 'android/build')
    (root / 'android/.build_version').write_text('4.7.2.stable')
    (root / 'android/.gdignore').touch()
    (root / 'android/build/gradlew').chmod(0o755)
# ZIPReader seeks within the included base archive. Deflating that ZIP again
# inside the APK makes Android asset seeks repeatedly decompress its prefix.
# Store ZIP assets directly; their contents are already compressed.
gradle = root / 'android/build/build.gradle'
gradle_text = gradle.read_text()
if "noCompress 'zip'" not in gradle_text:
    marker = 'aaptOptions {'
    if marker not in gradle_text:
        raise SystemExit('Android template has no aaptOptions block; cannot configure seekable ZIP assets')
    gradle.write_text(gradle_text.replace(marker, marker+"\n            noCompress 'zip'", 1))
settings = Path.home() / '.config/godot/editor_settings-4.7.tres'
if settings.exists():
    contents = settings.read_text()
    for name, value in [('java_sdk_path', jdk), ('android_sdk_path', sdk)]:
        line = 'export/android/' + name + ' = ' + json.dumps(str(value))
        pattern = r'export/android/' + name + r'\s*=.*'
        contents = re.sub(pattern, lambda _: line, contents) if re.search(pattern, contents) else contents.rstrip() + '\n' + line + '\n'
    settings.write_text(contents)
logs = root / 'test-results'
logs.mkdir(exist_ok=True)
out = root.parent / 'Builds/Android'
out.mkdir(parents=True, exist_ok=True)
embedded = root / 'deathmatch/assets/offline-base.zip'
if embedded.exists():
    raise SystemExit(f'Remove or relocate unexpected build input first: {embedded}')
ignore_markers = []
try:
    # Export filters do not stop the editor's pre-export import scan. These
    # directories are excluded by both Android presets and contain generated
    # engine/build trees or authoring sources, not APK resources.
    for name in ['Builds', 'dist', 'tools', 'docs', 'materials', 'textures']:
        folder = root/name
        marker = folder/'.gdignore'
        if folder.is_dir() and not marker.exists():
            marker.touch()
            ignore_markers.append(marker)
    if not args.thin:
        manifest = json.loads((root / 'deathmatch/assets/base_manifest.json').read_text())
        archive = root.parent / 'Builds' / f"FPSloppa-{manifest['version']}-Base-Assets.zip"
        if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest['sha256']:
            raise SystemExit('Base assets are stale; run tools/build_base_assets.py')
        with zipfile.ZipFile(archive) as bundle:
            for row in manifest['files']:
                data = bundle.read(row['path'])
                assert len(data) == row['size'] and hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
        shutil.copyfile(archive, embedded)
    for target in [args.target]:
        apk = out / f'FPSloppa-{target}.apk'
        log = logs / f'export_android_{target.lower()}.log'
        with log.open('w') as f:
            result = subprocess.run([godot, '--headless', '--path', str(root), '--xr-mode', 'off', '--export-release', f'{target} (experimental)', str(apk)], env=env, stdout=f, stderr=subprocess.STDOUT)
        if result.returncode or not apk.exists() or any(s in log.read_text() for s in ['SCRIPT ERROR:', 'Cannot export project', 'Export failed']):
            raise SystemExit(f'{target} export failed; inspect {log}')
        if not args.thin:
            with zipfile.ZipFile(apk) as package:
                if package.getinfo('assets/deathmatch/assets/offline-base.zip').compress_type != zipfile.ZIP_STORED:
                    raise SystemExit(f'{target}: base ZIP must be stored uncompressed for Android random access')
        check = subprocess.run([str(sdk / 'build-tools/36.1.0/apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], env=env, text=True, capture_output=True, check=True)
        (logs / f'android_{target.lower()}_signature.txt').write_text(check.stdout + check.stderr)
        subprocess.run([str(sdk / 'build-tools/36.1.0/zipalign'), '-c', '-P', '16', '4', str(apk)], check=True)
        digest = hashlib.sha256(apk.read_bytes()).hexdigest()
        apk.with_suffix('.apk.sha256').write_text(f'{digest}  {apk.name}\n')
        print(f'BUILT {apk} ({apk.stat().st_size} bytes) SHA256 {digest}', flush=True)
finally:
    if embedded.exists(): embedded.unlink()
    for marker in ignore_markers:
        marker.unlink(missing_ok=True)
