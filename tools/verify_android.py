"""Inspect built APK manifests, native ABIs and transferable asset checksums."""
from pathlib import Path
import io, hashlib, json, os, re, struct, subprocess, zipfile
from renderer_policy import verify_android_renderer
root = Path(__file__).resolve().parents[1]
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
reports = []
def allocated_sections(binary):
    # Gradle strips non-runtime symbols; compare the actual loaded sections.
    offset=struct.unpack_from('<Q',binary,40)[0]
    size,count,names_index=struct.unpack_from('<HHH',binary,58)
    headers=[struct.unpack_from('<IIQQQQIIQQ',binary,offset+i*size) for i in range(count)]
    names=headers[names_index];strings=binary[names[4]:names[4]+names[5]]
    result={}
    for row in headers:
        if row[2]&2 and row[1]!=8:
            name=strings[row[0]:].split(b'\0',1)[0].decode()
            result[name]=(row[3],binary[row[4]:row[4]+row[5]])
    return result
(root / 'test-results').mkdir(exist_ok=True)
version = re.search(r'config/version="([^"]+)"', (root / 'project.godot').read_text()).group(1)
protocol = re.search(r'const PROTOCOL := "([^"]+)"', (root / 'deathmatch/arena.gd').read_text()).group(1)
for target in ['Quest', 'Pico']:
    apk = root.parent / 'Builds/Android' / f'FPSloppa-{target}.apk'
    manifest = subprocess.check_output([str(sdk / 'build-tools/36.1.0/aapt2'), 'dump', 'xmltree', str(apk), '--file', 'AndroidManifest.xml'], text=True)
    (root / 'test-results' / f'android_{target.lower()}_manifest.txt').write_text(manifest)
    required = ['android.permission.INTERNET', 'android.permission.RECORD_AUDIO', 'org.khronos.openxr.intent.category.IMMERSIVE_HMD', 'org.godotengine.openxr.vendors.GodotOpenXR']
    if target == 'Quest':
        required += ['com.oculus.intent.category.VR', 'com.oculus.supportedDevices']
        required += ['com.oculus.permission.' + name for name in ['BODY_TRACKING', 'HAND_TRACKING', 'EYE_TRACKING', 'FACE_TRACKING']]
    else:
        required += ['org.entryway.arena.pico', 'pvr.app.type', 'com.picovr.permission.EYE_TRACKING']
    for marker in required:
        assert marker in manifest, (target, marker)
    vulkan_feature = re.search(r'android\.hardware\.vulkan\.version[^\n]*\n((?:\s+A:[^\n]*\n)+)', manifest)
    assert vulkan_feature and 'required(0x0101028e)=true' in vulkan_feature.group(1), (target, 'Vulkan must be required')
    assert 'debuggable(0x0101000f)=true' not in manifest
    assert 'versionName(0x0101021c)="' + version + '"' in manifest
    expected_code=re.search(r'version/code=(\d+)',(root/'export_presets.cfg').read_text()).group(1)
    assert 'versionCode(0x0101021b)='+expected_code in manifest
    with zipfile.ZipFile(apk) as z:
        renderer = verify_android_renderer(z)
        assert {n.split('/')[1] for n in z.namelist() if n.startswith('lib/')} == {'arm64-v8a'}
        for name in ['libgodot_android.so', 'libopenxr_loader.so', 'libgodotopenxrvendors.so']:
            assert 'lib/arm64-v8a/' + name in z.namelist()
        for name, local in [('libgodot-steam-audio.android.template_release.arm64.so','addons/godot-steam-audio/bin/libgodot-steam-audio.android.template_release.arm64.so'),('libphonon.so','addons/godot-steam-audio/bin/android/arm64/libphonon.so'),('libtwovoip.android.template_release.arm64.so','addons/twovoip/libs/libtwovoip.android.template_release.arm64.so')]:
            binary=z.read('lib/arm64-v8a/'+name)
            assert binary[:6]==b'\x7fELF\x02\x01', (target,name,'expected ELF64 little endian')
            assert allocated_sections(binary)==allocated_sections((root/local).read_bytes()), ('Outdated native audio library',target,name)
            offset=struct.unpack_from('<Q',binary,32)[0]
            size,count=struct.unpack_from('<HH',binary,54)
            loads=[struct.unpack_from('<IIQQQQQQ',binary,offset+i*size) for i in range(count)]
            assert all(row[7]>=16384 for row in loads if row[0]==1), (target,name,'16 KiB page alignment')
        assert z.read('assets/deathmatch/maps/texture_replacements/makkon-used.wad') == (root/'deathmatch/maps/texture_replacements/makkon-used.wad').read_bytes()
        assert not any('makkon-used.wad-' in name for name in z.namelist()), 'Unused dictionary scene'
        assert not any(name in z.namelist() for name in ['assets/export_presets.cfg','assets/LIVE_VR_TEST.md','assets/NETWORK_TESTING.md']), 'Development payload'
        assert z.getinfo('assets/deathmatch/assets/offline-base.zip').compress_type == zipfile.ZIP_STORED, 'Nested compression makes Android ZIP seeks expensive'
        embedded = z.read('assets/deathmatch/assets/offline-base.zip')
        base = json.loads((root/'deathmatch/assets/base_manifest.json').read_text())
        assert hashlib.sha256(embedded).hexdigest() == base['sha256'], 'Stale unified base archive'
        with zipfile.ZipFile(io.BytesIO(embedded)) as bundle:
            bundled_hashes = {}
            assert set(bundle.namelist()) == {row['path'] for row in base['files']}
            for row in base['files']:
                payload = bundle.read(row['path'])
                assert len(payload) == row['size'] and hashlib.sha256(payload).hexdigest() == row['sha256'], row['path']
                bundled_hashes[row['path']] = row['sha256']
        checked = []
        for group, key in [('deathmatch/maps/manifest.json', 'sha256'), ('deathmatch/avatars/models/manifest.json', 'hash')]:
            assert z.read('assets/'+group) == (root/group).read_bytes(), ('Outdated APK catalog', target, group)
            for entry in json.loads((root / group).read_text()):
                path = entry['path'].removeprefix('res://')
                assert 'assets/'+path not in z.namelist(), ('Map/VRM unexpectedly bundled',path)
                # Catalogs also describe optional/retired assets. Verify the
                # actual embedded distribution, not absent workspace extras.
                if path in bundled_hashes:
                    assert bundled_hashes[path] == entry[key], path
                    checked.append(path)
        assert not any(n.startswith('assets/entryway/') or n=='assets/deathmatch/arena.glb' for n in z.namelist())
        for entry in json.loads((root/'deathmatch/maps/manifest.json').read_text()):
            assert not any(n.startswith('assets/maps/') or n.startswith('assets/vrm/') for n in z.namelist())
        assert 'assets/deathmatch/avatars/eyes.gd' in z.namelist()
        assert protocol.encode() in z.read('assets/deathmatch/arena.gd')
        for script in ['vehicles/ba2/controller.gd', 'server/bot_population.gd', 'bot_ai/navigation.gd', 'bots.gd', 'modes/fortress.gd', 'experimental/combat.gd', 'ui/player_status.gd', 'audio/round_clock.gd', 'assets/bootstrap.gd', 'assets/base_install.gd', 'ui/drag_list.gd', 'ui/scoreboard.gd', 'modes/lobby_results.gd', 'avatars/picker.gd', 'movement/prediction.gd', 'vr/physical_crouch.gd', 'vr/physical_actions.gd', 'vr/weapon_clearance.gd', 'vr/face_expressions.gd', 'vr/ability_gesture.gd', 'modes/vr_interactions.gd', 'ui/file_browser.gd', 'settings/bindings_panel.gd', 'voice/chat.gd', 'voice/panel.gd', 'modes/assault.gd', 'modes/fortress_fx.gd', 'maps/train_motion.gd', 'chainsaw.gd', 'vr/swim_strokes.gd', 'vr/t_pose.gd', 'audio/announcer.gd', 'network/disk_worker.gd', 'network/asset_jobs.gd', 'maps/contents.gd', 'maps/filtering.gd', 'ui/drag_scroll.gd', 'voice/preferences.gd', 'movement/quake.gd', 'voice/microphone.gd', 'voice/visemes.gd', 'modes/lobby_mirror.gd', 'modes/lobby_wall.gd', 'modes/match_selector.gd', 'ui/choice.gd', 'network/loading.gd', 'network/loading_overlay.gd', 'projectile_targets.gd', 'maps/network.gd', 'interface.gd', 'arena.gd', 'assets/paths.gd', 'assets/panel.gd', 'maps/uploads.gd', 'modes/special.gd', 'melee.gd', 'server/config.gd', 'server/log.gd', 'modes/match.gd', 'modes/votes.gd', 'audio/steam_backend.gd', 'avatars/network.gd', 'vr/preferences.gd', 'vr/tracking.gd', 'vr/status_hud.gd', 'vr/permissions.gd', 'vr/rig.gd', 'voice/chat.gd', 'voice/panel.gd', 'avatars/library.gd', 'avatars/rig.gd', 'avatars/pose.gd', 'fighter.gd', 'effects/combat.gd', 'audio/spatial.gd', 'audio/music/player.gd', 'pickups/models.gd', 'settings/preferences.gd', 'settings/panel.gd']:
            path = 'deathmatch/' + script
            assert z.read('assets/' + path) == (root / path).read_bytes(), ('Outdated APK script', target, path)
        audio_files=[root/'deathmatch/icon-final.png']+list((root/'deathmatch/audio/music').glob('*.ogg'))
        audio_files += [root/'deathmatch/audio'/(name+'.wav') for name in ['round_tick','door_open','door_close','teleport','jump_pad','calibration_complete','saw_grind','flag_capture','spawn','power_spawn','pickup_health','pickup_armor','pickup_ammo','pickup_weapon','pickup_mega']]
        audio_files += list((root/'deathmatch/audio/recorded').glob('pain_*.wav'))
        audio_files += list((root/'deathmatch/audio/announcer').glob('*.ogg'))
        for notice in ['LICENSE.txt','SOURCES.md']:
            assert z.read('assets/deathmatch/audio/announcer/'+notice)==(root/'deathmatch/audio/announcer'/notice).read_bytes()
        assert not any(n.startswith('assets/docs/audio/') for n in z.namelist()), 'Audition archives must not inflate APKs'
        for source in audio_files:
            remap=re.search(r'^path="res://([^"]+)"',Path(str(source)+'.import').read_text(),re.M).group(1)
            assert z.read('assets/'+remap)==(root/remap).read_bytes(), ('Outdated APK audio',target,source.name)
        assert not any(n.startswith('assets/deathmatch/audio/music/samples/') for n in z.namelist()), 'Source sample bank should not inflate APKs'
    reports.append({'target': target, 'bytes': apk.stat().st_size, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'assets_verified': checked, 'unified_base_assets': len(base['files']), 'arm64_only': True, 'vendor_manifest': True, 'twovoip_current':True,'twovoip_16k_pages':True,'steam_audio_current':True, 'steam_audio_16k_pages':True,'current_feedback_and_music':True,'current_icon':True,'current_vr_interactions':True})
    reports[-1]['renderer'] = renderer
    reports[-1]['vulkan_required'] = True
    reports[-1]['seekable_embedded_zip'] = True
(root / 'test-results/android_artifacts.json').write_text(json.dumps(reports, indent=2) + '\n')
print('Verified both ARM64 APKs, vendor manifests, protocol, current scripts/assets and 16 KiB-aligned Steam Audio and TwoVoIP libraries.')
