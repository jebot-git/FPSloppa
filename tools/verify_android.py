"""Inspect built APK manifests, native ABIs and transferable asset checksums."""
from pathlib import Path
import hashlib, json, os, subprocess, zipfile
root = Path(__file__).resolve().parents[1]
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
reports = []
for target in ['Quest', 'Pico']:
    apk = root.parent / 'Builds/Android' / f'Entryway-{target}.apk'
    manifest = subprocess.check_output([str(sdk / 'build-tools/36.1.0/aapt2'), 'dump', 'xmltree', str(apk), '--file', 'AndroidManifest.xml'], text=True)
    (root / 'test-results' / f'android_{target.lower()}_manifest.txt').write_text(manifest)
    required = ['android.permission.INTERNET', 'android.permission.RECORD_AUDIO', 'org.khronos.openxr.intent.category.IMMERSIVE_HMD', 'org.godotengine.openxr.vendors.GodotOpenXR']
    if target == 'Quest':
        required += ['com.oculus.intent.category.VR', 'com.oculus.supportedDevices']
    else:
        required += ['org.entryway.arena.pico', 'pvr.app.type']
    for marker in required:
        assert marker in manifest, (target, marker)
    assert 'debuggable(0x0101000f)=true' not in manifest
    with zipfile.ZipFile(apk) as z:
        assert {n.split('/')[1] for n in z.namelist() if n.startswith('lib/')} == {'arm64-v8a'}
        for name in ['libgodot_android.so', 'libopenxr_loader.so', 'libgodotopenxrvendors.so']:
            assert 'lib/arm64-v8a/' + name in z.namelist()
        checked = []
        for group, key in [('deathmatch/maps/manifest.json', 'sha256'), ('deathmatch/avatars/models/manifest.json', 'hash')]:
            for entry in json.loads((root / group).read_text()):
                path = entry['path'].removeprefix('res://')
                assert hashlib.sha256(z.read('assets/' + path)).hexdigest() == entry[key], path
                checked.append(path)
        assert not any(n.startswith('assets/entryway/') or n=='assets/deathmatch/arena.glb' for n in z.namelist())
        for entry in json.loads((root/'deathmatch/maps/manifest.json').read_text()):
            assert 'assets/deathmatch/maps/navigation/'+entry['id']+'.res' in z.namelist()
        assert 'assets/deathmatch/avatars/eyes.gd' in z.namelist()
        assert b'entryway-dm-7-eyes' in z.read('assets/deathmatch/arena.gd')
    reports.append({'target': target, 'bytes': apk.stat().st_size, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'assets_verified': checked, 'arm64_only': True, 'vendor_manifest': True})
(root / 'test-results/android_artifacts.json').write_text(json.dumps(reports, indent=2) + '\n')
print('Verified both ARM64 APKs, vendor manifests, protocol and eight raw assets per APK.')
