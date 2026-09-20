"""Build a console-only Godot runtime and a server resource pack without client plugins.

The runtime has only headless/dummy drivers. This deliberately does not fall back
to a standard Godot export template if the dedicated runtime is unavailable.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.7.2-stable'
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
FLAGS = dict(platform='linuxbsd', target='template_release', arch='x86_64',
             production='yes', optimize='speed', lto='none', use_static_cpp='no',
             x11='no', wayland='no', vulkan='no', opengl3='no', openxr='no',
             alsa='no', pulseaudio='no', dbus='no', speechd='no', fontconfig='no',
             udev='no', sdl='no', touch='no', accesskit='no',
             modules_enabled_by_default='no', module_gdscript_enabled='yes',
             module_enet_enabled='yes', module_multiplayer_enabled='yes',
             module_godot_physics_3d_enabled='yes', module_navigation_3d_enabled='yes',
             module_regex_enabled='yes', module_zip_enabled='yes', module_mbedtls_enabled='yes',
             disable_physics_2d='yes', disable_navigation_2d='yes',
             disable_overrides='yes', disable_path_overrides='yes')
CLIENT_PREFIXES = ('deathmatch/ui/', 'deathmatch/tests/', 'deathmatch/pickups/', 'deathmatch/haptics/',
                   'deathmatch/audio/music/', 'deathmatch/performance/', 'deathmatch/maps/texture_replacements/')
CLIENT_FILES = {'deathmatch/lighting/weapon_pool.gd', 'deathmatch/experimental/visuals.gd', 'deathmatch/maps/baked_light.gd', 'deathmatch/maps/palette.lmp', 'deathmatch/interface.gd', 'deathmatch/assets/bootstrap.gd',
                'deathmatch/assets/base_install.gd', 'deathmatch/assets/panel.gd',
                'deathmatch/demos/panel.gd', 'deathmatch/diagnostics.gd',
                'deathmatch/maps/filtering.gd', 'deathmatch/maps/librequake_props.gd',
                'deathmatch/maps/train_motion.gd', 'deathmatch/maps/static_batch.gd',
                'deathmatch/maps/surface_motion.gd', 'deathmatch/maps/atmosphere.gd',
                'deathmatch/modes/lobby_wall.gd', 'deathmatch/modes/lobby_mirror.gd',
                'deathmatch/modes/lobby_results.gd'}
VR_SHARED = {'body_basis.gd', 'poses.gd', 'preferences.gd', 'room_scale.gd', 'weapon_clearance.gd', 'throw_ballistics.gd'}


def allowed(path):
    if path.startswith(CLIENT_PREFIXES) or path in CLIENT_FILES:
        return False
    if path.startswith('addons/') and path not in {'addons/bsp_importer/bsp_reader.gd', 'addons/bsp_importer/gsrc_wad_reader.gd', 'addons/bsp_importer/collision_surface_info.gd', 'addons/bsp_importer/clipper.gd'}:
        return False
    if path.startswith('deathmatch/avatars/') and path not in {'deathmatch/avatars/library.gd', 'deathmatch/avatars/network.gd', 'deathmatch/avatars/hit_body.gd', 'deathmatch/avatars/models/manifest.json'}:
        return False
    if path.startswith('deathmatch/voice/') and Path(path).name not in {'relay.gd', 'external.gd'}:
        return False
    if path.startswith('deathmatch/vr/') and Path(path).name not in VR_SHARED:
        return False
    if path.startswith('deathmatch/audio/') and path != 'deathmatch/audio/announcer.gd':
        return False
    if path == 'deathmatch/server/districts/cache/vesper.scn':return True
    return Path(path).suffix in {'.gd', '.json', '.tscn', '.lmp'}


def runtime_audit(binary):
    # Do not let a template without a PCK discover the developer's project in cwd.
    binary=binary.resolve()
    version=subprocess.check_output([str(binary),'--version'],text=True).strip()
    if not version.startswith('4.7.2.'):
        raise RuntimeError('Console template must use the pinned Godot version: '+version)
    dependencies = subprocess.check_output(['ldd', str(binary)], text=True)
    forbidden = r'lib(?:X11|Xext|Xcursor|Xrandr|wayland|vulkan|GL\.|EGL|asound|pulse|openxr|SDL|speechd|fontconfig|freetype|harfbuzz|dbus|phonon|opus|ogg|vorbis|mp3)'
    if re.search(forbidden, dependencies, re.I):
        raise RuntimeError('Client dependency in dedicated runtime:\n' + dependencies)
    help_text = subprocess.check_output([str(binary), '--help'], text=True)
    plain = re.sub(r'\x1b\[[0-9;]*m', '', help_text)
    if 'Audio driver ["Dummy"]' not in plain or '["headless" ("dummy")]' not in plain:
        raise RuntimeError('Runtime has non-console drivers or an unexpected driver list')
    for args in [('--display-driver', 'x11'), ('--display-driver', 'wayland'), ('--audio-driver', 'PulseAudio'), ('--audio-driver', 'ALSA'), ('--rendering-driver', 'vulkan'), ('--rendering-driver', 'opengl3')]:
        result = subprocess.run([str(binary), *args, '--quit'], cwd='/tmp', capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            raise RuntimeError('Runtime accepted forbidden driver: ' + str(args))
    # Missing project data must not invoke Zenity/KDialog through OS.alert().
    with tempfile.TemporaryDirectory(prefix='fpsloppa-console-audit-') as scratch:
        folder=Path(scratch);probe=folder/'server'
        shutil.copy2(binary,probe)
        for name in ['zenity','kdialog','Xdialog','xmessage','xdg-open','gio']:
            program=folder/name;program.write_text('#!/bin/sh\nprintf invoked > "'+str(folder/'gui-called')+'"\n');program.chmod(0o755)
        env=dict(os.environ,PATH=str(folder))
        result=subprocess.run([str(probe),'--quit'],cwd=folder,env=env,capture_output=True,text=True,timeout=10)
        if result.returncode==0 or (folder/'gui-called').exists():
            raise RuntimeError('Runtime opens desktop helpers or accepts missing project data')
    return dependencies


def patch_console_platform(source):
    path=source/'platform/linuxbsd/os_linuxbsd.cpp'
    content=path.read_text()
    for signature,body in [
        ('void OS_LinuxBSD::alert(const String &p_alert, const String &p_title)', '\tprint_line(p_title + ": " + p_alert);'),
        ('Error OS_LinuxBSD::shell_open(const String &p_uri)', '\treturn ERR_UNAVAILABLE;'),
    ]:
        pattern=re.escape(signature)+r' \{.*?\n\}'
        replacement=signature+' {\n\t// FPSloppa console runtime: never launch desktop helper processes.\n'+body+'\n}'
        content,count=re.subn(pattern,lambda _:replacement,content,flags=re.S)
        if count!=1:raise RuntimeError('Pinned Godot platform function changed: '+signature)
    if content!=path.read_text():path.write_text(content)


def compile_runtime(source, scons, jobs, native=False):
    source.parent.mkdir(parents=True, exist_ok=True)
    if not (source / 'SConstruct').is_file():
        archive = source.parent / ('godot-' + VERSION + '.tar.gz')
        if not archive.exists():
            urllib.request.urlretrieve('https://github.com/godotengine/godot/archive/refs/tags/' + VERSION + '.tar.gz', archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA256:
            raise RuntimeError('Godot source archive digest does not match pinned release')
        with tarfile.open(archive) as tar:
            tar.extractall(source.parent, filter='data')
    patch_console_platform(source)
    options=[f'{k}={v}' for k,v in FLAGS.items()]+[f'-j{jobs}']
    if native:
        command=[scons,*options]
    else:
        if not shutil.which('podman'):
            raise RuntimeError('Install Podman for the Ubuntu 22.04 build, or explicitly choose --native-toolchain')
        tag='localhost/fpsloppa-server-toolchain:godot-4.7.2-jammy'
        subprocess.run(['podman','build','-t',tag,'-f',str(ROOT/'tools/server_runtime/Containerfile'),str(ROOT/'tools/server_runtime')],check=True)
        command=['podman','run','--rm','--network=none','-v',str(source.resolve())+':/src:Z',tag,*options]
    subprocess.run(command, cwd=source, check=True)
    return source / 'bin/godot.linuxbsd.template_release.x86_64'


def package(godot, template, dest, cq_assets=False, district_maps=False, campaign_maps=False):
    dependencies = runtime_audit(template)
    dest.mkdir(parents=True, exist_ok=True)
    # A fresh directory prevents an earlier generic export leaving native plugins behind.
    leftovers = list(dest.rglob('*.so')) + list(dest.rglob('*.gdextension'))
    if leftovers:
        raise RuntimeError('Use an empty server output directory; stale client plugins: ' + str(leftovers))
    work = ROOT / 'test-results/console-server-package'
    work.mkdir(parents=True, exist_ok=True)
    version = re.search(r'config/version="([^"]+)"', (ROOT / 'project.godot').read_text()).group(1)
    (work / 'project.godot').write_text('''config_version=5
_custom_features="dedicated_server"
[application]
config/name="FPSloppa"
config/version="'''+version+'''"
run/main_scene="res://deathmatch/arena.tscn"
run/flush_stdout_on_print=true
[audio]
driver/enable_input=false
[navigation]
3d/default_cell_size=0.2
3d/default_cell_height=0.1
[physics]
common/physics_interpolation=true
[xr]
openxr/enabled=false
''')
    (work / 'arena.tscn').write_text('''[gd_scene format=3]
[ext_resource type="Script" path="res://deathmatch/arena.gd" id="1"]
[node name="Arena" type="Node3D"]
script=ExtResource("1")
[node name="Map" type="Node3D" parent="."]
''')
    if cq_assets:
        subprocess.run([godot, '--headless', '--xr-mode', 'off', '--log-file', str(work/'cq-cache.log'), '--path', str(ROOT), '--script', 'res://tools/cq_gateway/cache.gd'],check=True,stdout=subprocess.DEVNULL)
    selected = {'project.godot': work / 'project.godot', 'deathmatch/arena.tscn': work / 'arena.tscn'}
    if campaign_maps:
        project=work/'project.godot'
        project.write_text(project.read_text().replace('run/main_scene="res://deathmatch/arena.tscn"','run/main_scene="res://deathmatch/server/cluster/entry.tscn"')+'\n[threading]\nworker_pool/max_threads=2\n')
    if cq_assets:selected['deathmatch/server/districts/cache/vesper.scn'] = ROOT/'deathmatch/server/districts/cache/vesper.scn'
    pending = ['deathmatch/arena.gd', 'deathmatch/voice/relay.gd', 'addons/bsp_importer/gsrc_wad_reader.gd', 'addons/bsp_importer/collision_surface_info.gd',
               'deathmatch/maps/manifest.json', 'deathmatch/avatars/models/manifest.json', 'deathmatch/assets/base_manifest.json']
    if campaign_maps:pending += ['deathmatch/server/cluster/entry.tscn']
    while pending:
        path = pending.pop()
        if path in selected or not allowed(path) or not (ROOT / path).is_file():
            continue
        selected[path] = ROOT / path
        if Path(path).suffix not in {'.gd', '.tscn'}:
            continue
        source = (ROOT / path).read_text()
        for hard in re.findall(r'preload\("res://([^"\n]+)"\)', source):
            if not allowed(hard):
                raise RuntimeError(f'Server eagerly imports client dependency: {path} -> {hard}')
        pending += re.findall(r'res://([A-Za-z0-9_./-]+\.(?:gd|tscn|json|lmp))', source)
    # Only the BSP metadata reader uses globally named scripts in the server graph.
    classes = []
    for path, source in selected.items():
        if not path.endswith('.gd'):
            continue
        text = source.read_text()
        name = re.search(r'^class_name (\w+)', text, re.M)
        base = re.search(r'^extends (\w+)', text, re.M)
        if name and base:
            classes.append('{"base": &"'+base[1]+'", "class": &"'+name[1]+'", "icon": "", "is_abstract": false, "is_tool": false, "language": &"GDScript", "path": "res://'+path+'"}')
    cache = work / 'global_script_class_cache.cfg'
    cache.write_text('list=Array[Dictionary](['+',\n'.join(classes)+'])\n')
    selected['.godot/global_script_class_cache.cfg'] = cache
    binary = dest / 'FPSloppaServer.x86_64'
    if template.resolve()!=binary.resolve():shutil.copy2(template, binary)
    binary.chmod(0o755)
    pack = binary.with_suffix('.pck')
    rows = [dict(path='res://'+path, source=str(source)) for path, source in sorted(selected.items())]
    manifest = work / 'pack.json';manifest.write_text(json.dumps(dict(output=str(pack), files=rows), indent=2))
    subprocess.run([godot, '--headless', '--xr-mode', 'off', '--log-file', str(work/'packaging.log'), '--path', str(ROOT), '--script', 'res://deathmatch/server/package.gd', '--', str(manifest)], check=True)
    # Original BSP/VRM bytes are necessary for serving downloads, never rendered here.
    package_files = {'FPSloppaServer.x86_64', 'FPSloppaServer.pck', 'server.cfg', 'start-server.sh', 'server-build.json'}
    assets = json.loads((ROOT / 'deathmatch/assets/base_manifest.json').read_text())['files']
    for row in assets:
        path = Path(row['path'])
        if path.suffix in {'.scn', '.lit'} or 'cache' in path.parts:
            # Remove only generated base-pack copies from an earlier server build.
            (dest/path).unlink(missing_ok=True)
            continue
        package_files.add(path.as_posix())
        target = dest / path;target.parent.mkdir(parents=True, exist_ok=True);shutil.copy2(ROOT / path, target)
    if cq_assets:
        for name in ['maps/Benchmark1km/prototype_km1.bsp', 'maps/navigation/prototype_km1.res', 'conquest.cfg', 'docs/CONQUEST.md']:
            target = dest / name;target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target);package_files.add(name)
    if district_maps:
        for source in [ROOT/'maps/CQDistricts/manifest.json', ROOT/'conquest-district-maps.cfg', *sorted((ROOT/'maps/CQDistricts').glob('district_*/district.bsp')), *sorted((ROOT/'maps/CQDistricts').glob('district_*/collision.scn')), *sorted((ROOT/'maps/CQDistricts').glob('district_*/navigation.res'))]:
            relative=source.relative_to(ROOT);target=dest/relative;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target);package_files.add(relative.as_posix())
    if campaign_maps:
        for source in [ROOT/'maps/CampaignDistricts/manifest.json', *sorted((ROOT/'maps/CampaignDistricts').glob('district_*/district.bsp')), *sorted((ROOT/'maps/CampaignDistricts').glob('district_*/collision.scn')), *sorted((ROOT/'maps/CampaignDistricts').glob('district_*/navigation.res'))]:
            relative=source.relative_to(ROOT);target=dest/relative;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target);package_files.add(relative.as_posix())
    if not (dest / 'server.cfg').exists():shutil.copy2(ROOT / 'server.cfg', dest / 'server.cfg')
    for name in ['SERVER.md', 'VOICE.md', 'TF.md', 'AS.md', 'GAMEMODES.md', 'ASSET_CREDITS.md', 'GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']:
        shutil.copy2(ROOT / name, dest / name);package_files.add(name)
    for source in (ROOT / 'addons/bsp_importer').glob('*LICENSE*'):
        target=dest/'licenses/bsp_importer'/source.name
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        package_files.add(target.relative_to(dest).as_posix())
    launcher = dest / 'start-server.sh'
    default_config='' if campaign_maps else '--config "$server_dir/server.cfg" '
    launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\nserver_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$server_dir/FPSloppaServer.x86_64" --log-file "$server_dir/server-engine.log" -- '+default_config+'"$@"\n')
    launcher.chmod(0o755)
    symbols=subprocess.check_output(['objdump','-T',str(binary)],text=True)
    abi=sorted(set(re.findall(r'\b(?:GLIBC|GLIBCXX|CXXABI)_[0-9.]+',symbols)))
    report = dict(package_files=sorted(package_files), engine=VERSION, source_sha256=SOURCE_SHA256, platform_policy='console-only-alerts-and-shell-v1', flags=FLAGS, dependencies=dependencies, required_abi=abi, resources=sorted(selected),
                  resource_sha256={path:hashlib.sha256(source.read_bytes()).hexdigest() for path,source in selected.items()},
                  executable_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), pack_sha256=hashlib.sha256(pack.read_bytes()).hexdigest())
    (dest / 'server-build.json').write_text(json.dumps(report, indent=2)+'\n')
    print('CONSOLE_SERVER_BUILT', binary, 'resources=', len(selected))


def verify_package(dest):
    binary=dest/'FPSloppaServer.x86_64'
    report=json.loads((dest/'server-build.json').read_text())
    runtime_audit(binary)
    for file,key in [(binary,'executable_sha256'),(binary.with_suffix('.pck'),'pack_sha256')]:
        if hashlib.sha256(file.read_bytes()).hexdigest()!=report[key]:
            raise RuntimeError('Server build receipt does not match '+str(file))
    for name in report['package_files']:
        if not (dest/name).is_file():raise RuntimeError('Missing server package file: '+name)
    if list(dest.rglob('*.so')) or list(dest.rglob('*.gdextension')):
        raise RuntimeError('Unexpected native plugins in server directory')
    if any(not allowed(p) for p in report['resources'] if p not in {'project.godot','.godot/global_script_class_cache.cfg'}):
        raise RuntimeError('Client resources found in server receipt')
    print('CONSOLE_SERVER_VERIFIED',binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cq-district-maps', action='store_true', help='Include independently compiled CQ district BSPs and server caches')
    parser.add_argument('--campaign-maps', action='store_true', help='Include the validated 81-map campaign pack and CQ worker support')
    parser.add_argument('--cq-assets', action='store_true', help='Include experimental CQ collision/navigation assets and configuration')
    parser.add_argument('--verify-only', action='store_true', help='Audit existing package without rebuilding')
    parser.add_argument('--native-toolchain', action='store_true', help='Use host compiler instead of the Ubuntu 22.04 container')
    parser.add_argument('--source', type=Path, default=ROOT / 'Builds/ServerRuntime/godot-4.7.2-stable')
    parser.add_argument('--scons', default=shutil.which('scons') or 'scons')
    parser.add_argument('--jobs', type=int, default=8)
    parser.add_argument('--template', type=Path, help='Previously compiled and audited console-only template')
    parser.add_argument('--output', type=Path, default=ROOT / 'Builds/ConsoleServer')
    args = parser.parse_args()
    if args.verify_only:
        verify_package(args.output.resolve());return
    template = args.template or compile_runtime(args.source, args.scons, args.jobs,args.native_toolchain)
    godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:parser.error('Godot is needed only as a packaging tool')
    package(godot, template.resolve(), args.output.resolve(), args.cq_assets or args.cq_district_maps or args.campaign_maps, args.cq_district_maps or args.campaign_maps, args.campaign_maps)


if __name__ == '__main__':main()
