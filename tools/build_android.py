"""Build locally signed release-runtime Quest/Pico sideload APKs (Godot 4.7.2)."""
from pathlib import Path
import os, subprocess, secrets, json, zipfile, hashlib, argparse, re

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--target', choices=['Quest', 'Pico', 'both'], default='both')
args = parser.parse_args()
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
jdk = Path(os.environ.get('JAVA_HOME', str(Path.home() / '.local/share/entryway-toolchains/jdk-17.0.20.1+1')))
godot = os.environ.get('GODOT_BIN', str(Path.home() / '.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
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
settings = Path.home() / '.config/godot/editor_settings-4.7.tres'
if settings.exists():
    contents = settings.read_text()
    for name, value in [('java_sdk_path', jdk), ('android_sdk_path', sdk)]:
        line = 'export/android/' + name + ' = ' + json.dumps(str(value))
        contents = re.sub(r'export/android/' + name + r'\s*=.*', lambda _: line, contents)
    settings.write_text(contents)
logs = root / 'test-results'
logs.mkdir(exist_ok=True)
out = root.parent / 'Builds/Android'
out.mkdir(parents=True, exist_ok=True)
for target in (['Quest', 'Pico'] if args.target == 'both' else [args.target]):
    apk = out / f'Entryway-{target}.apk'
    log = logs / f'export_android_{target.lower()}.log'
    with log.open('w') as f:
        result = subprocess.run([godot, '--headless', '--path', str(root), '--xr-mode', 'off', '--export-release', f'{target} (experimental)', str(apk)], env=env, stdout=f, stderr=subprocess.STDOUT)
    if result.returncode or not apk.exists() or any(s in log.read_text() for s in ['SCRIPT ERROR:', 'Cannot export project', 'Export failed']):
        raise SystemExit(f'{target} export failed; inspect {log}')
    check = subprocess.run([str(sdk / 'build-tools/36.1.0/apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], env=env, text=True, capture_output=True, check=True)
    (logs / f'android_{target.lower()}_signature.txt').write_text(check.stdout + check.stderr)
    subprocess.run([str(sdk / 'build-tools/36.1.0/zipalign'), '-c', '-P', '16', '4', str(apk)], check=True)
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    apk.with_suffix('.apk.sha256').write_text(f'{digest}  {apk.name}\n')
    print(f'BUILT {apk} ({apk.stat().st_size} bytes) SHA256 {digest}', flush=True)
