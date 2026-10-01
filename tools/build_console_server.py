"""Build a console-only Godot runtime and a server resource pack without client plugins.

The runtime has only headless/dummy drivers. This deliberately does not fall back
to a standard Godot export template if the dedicated runtime is unavailable.
"""
import argparse
import hashlib
import json
import os
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

from build_gameplay_native import require_build
ROOT = Path(__file__).resolve().parents[1]
NATIVE_LIBRARY = "addons/fps_native/bin/libfpsloppa_native.server.so"
NATIVE_DESCRIPTOR = "addons/fps_native/fps_native.gdextension"
VERSION = '4.7.2-stable'
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
FLAGS = dict(platform='linuxbsd', target='template_release', arch='x86_64',
             production='yes', optimize='speed', lto='none', use_static_cpp='no',
             x11='no', wayland='no', vulkan='no', opengl3='no', openxr='no',
             alsa='no', pulseaudio='no', dbus='no', speechd='no', fontconfig='no',
             udev='no', sdl='no', touch='no', accesskit='no',
             modules_enabled_by_default='no', module_gdscript_enabled='yes',
             module_enet_enabled='yes', module_multiplayer_enabled='yes',
             module_godot_physics_3d_enabled='yes', module_jolt_physics_enabled='yes', module_navigation_3d_enabled='yes',
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
VR_SHARED = {'body_basis.gd', 'poses.gd', 'preferences.gd', 'room_scale.gd', 'weapon_clearance.gd', 'throw_ballistics.gd', 'hip_mount.gd', 'pump_hold.gd', 'weapon_kick.gd'}
CLIENT_FILES.add('deathmatch/counterstrike/grenade_visuals.gd')
CLIENT_FILES.add('deathmatch/counterstrike/feed_belt.gd')
CLIENT_FILES.add('deathmatch/effects/bullet_marks.gd')
CLIENT_FILES.add('deathmatch/tribes/armour_visual.gd')
CLIENT_FILES.update({'deathmatch/tribes/command_view.gd', 'deathmatch/tribes/turret_view.gd',
                     'deathmatch/tribes/wrist_display.gd'})


def allowed(path):
    if path == NATIVE_DESCRIPTOR: return True
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
    return Path(path).suffix in {'.gd', '.json', '.tscn', '.lmp'}


def native_dependencies(library):
    dependencies = subprocess.check_output(['ldd', str(library)], text=True)
    if re.search(r'lib(?:X11|Xext|Xcursor|Xrandr|wayland|vulkan|GL\.|EGL|asound|pulse|openxr|SDL|speechd|fontconfig|freetype|harfbuzz|dbus|phonon|opus|ogg|vorbis|mp3)', dependencies, re.I):
        raise RuntimeError('Client dependency in server gameplay extension:\n'+dependencies)
    if 'not found' in dependencies:raise RuntimeError('Unresolved server extension dependency:\n'+dependencies)
    return dependencies


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
        # Old stripped templates contain only Godot Physics. Require Jolt to
        # actually start, rather than silently accepting a fallback backend.
        (folder/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://probe.tscn"\n[physics]\n3d/physics_engine="Jolt Physics"\n')
        (folder/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node3D"]\nscript=ExtResource("1")\n')
        (folder/'probe.gd').write_text('extends Node3D\nfunc _ready():\n\tvar backend=get_world_3d().direct_space_state.get_class()\n\tprint("CONSOLE_PHYSICS_BACKEND ",backend)\n\tget_tree().quit(0 if backend.begins_with("Jolt") else 2)\n')
        (folder/'.godot').mkdir()
        (folder/'.godot/global_script_class_cache.cfg').write_text('list=Array[Dictionary]([])\n')
        result=subprocess.run([str(probe)],cwd=folder,env={**os.environ,'XDG_DATA_HOME':str(folder/'user')},capture_output=True,text=True,timeout=10)
        if result.returncode or 'CONSOLE_PHYSICS_BACKEND Jolt' not in result.stdout:
            raise RuntimeError('Rebuild console runtime with Jolt Physics support:\n'+result.stdout+result.stderr)
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


def package(godot, template, dest):
    dependencies = runtime_audit(template)
    native_library = require_build("linux", server=True)
    dependencies += "\nGameplay extension:\n" + native_dependencies(native_library)
    dest.mkdir(parents=True, exist_ok=True)
    # A fresh directory prevents an earlier generic export leaving native plugins behind.
    leftovers = [p for p in list(dest.rglob('*.so')) + list(dest.rglob('*.gdextension')) if p.relative_to(dest).as_posix() != NATIVE_LIBRARY]
    if leftovers:
        raise RuntimeError('Use an empty server output directory; stale client plugins: ' + str(leftovers))
    work = ROOT / 'test-results/console-server-package'
    work.mkdir(parents=True, exist_ok=True)
    version = re.search(r'config/version="([^"]+)"', (ROOT / 'project.godot').read_text()).group(1)
    physics = re.search(r'^3d/physics_engine="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M)
    physics_engine = physics.group(1) if physics else 'GodotPhysics3D'
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
3d/physics_engine="'''+physics_engine+'''"
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
    selected = {'project.godot': work / 'project.godot', 'deathmatch/arena.tscn': work / 'arena.tscn'}
    descriptor = work / 'fps_native.gdextension'
    descriptor.write_text('[configuration]\nentry_symbol="fpsloppa_native_init"\ncompatibility_minimum="4.7"\n\n[libraries]\nlinux.x86_64="res://'+NATIVE_LIBRARY+'"\n')
    selected[NATIVE_DESCRIPTOR] = descriptor
    pending = ['deathmatch/arena.gd', 'deathmatch/voice/relay.gd', 'addons/bsp_importer/gsrc_wad_reader.gd', 'addons/bsp_importer/collision_surface_info.gd',
               'deathmatch/maps/manifest.json', 'deathmatch/avatars/models/manifest.json', 'deathmatch/assets/base_manifest.json']
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
    if template.resolve()!=binary.resolve() and (not binary.exists() or hashlib.sha256(template.read_bytes()).digest()!=hashlib.sha256(binary.read_bytes()).digest()):
        shutil.copy2(template, binary)
    binary.chmod(0o755)
    pack = binary.with_suffix('.pck')
    rows = [dict(path='res://'+path, source=str(source)) for path, source in sorted(selected.items())]
    manifest = work / 'pack.json';manifest.write_text(json.dumps(dict(output=str(pack), files=rows), indent=2))
    subprocess.run([godot, '--headless', '--xr-mode', 'off', '--log-file', str(work/'packaging.log'), '--path', str(ROOT), '--script', 'res://deathmatch/server/package.gd', '--', str(manifest)], check=True)
    # Original BSP/VRM bytes are necessary for serving downloads, never rendered here.
    package_files = {'FPSloppaServer.x86_64', 'FPSloppaServer.pck', 'server.cfg', 'start-server.sh', 'server-build.json'}
    target = dest / NATIVE_LIBRARY
    target.parent.mkdir(parents=True, exist_ok=True)
    staged = target.with_suffix('.new')
    shutil.copy2(native_library, staged); os.replace(staged, target)
    package_files.add(NATIVE_LIBRARY)
    license_target = dest / 'licenses/fps_native/GODOT-CPP-LICENSE.md'
    license_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT/'addons/fps_native/GODOT-CPP-LICENSE.md', license_target)
    package_files.add(license_target.relative_to(dest).as_posix())
    assets = json.loads((ROOT / 'deathmatch/assets/base_manifest.json').read_text())['files']
    for row in assets:
        path = Path(row['path'])
        if path.suffix in {'.scn', '.lit'} or 'cache' in path.parts:
            # Remove only generated base-pack copies from an earlier server build.
            (dest/path).unlink(missing_ok=True)
            continue
        package_files.add(path.as_posix())
        target = dest / path;target.parent.mkdir(parents=True, exist_ok=True);shutil.copy2(ROOT / path, target)
    if not (dest / 'server.cfg').exists():shutil.copy2(ROOT / 'server.cfg', dest / 'server.cfg')
    for name in ['docs/ST-TRIBES.md', 'docs/ST-VEHICLES.md', 'docs/ST-COMMAND.md', 'docs/SERVER-BROWSER.md', 'docs/BOMB-DEFUSAL.md', 'docs/CS16-LOADOUT.md', 'docs/CS16-GRENADES.md', 'docs/ARENA-JETPACKS.md', 'docs/WEAPON-RESPAWNS.md', 'docs/TITANBALL.md', 'SERVER.md', 'VOICE.md', 'TF.md', 'AS.md', 'GAMEMODES.md', 'ASSET_CREDITS.md', 'GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']:
        (dest / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, dest / name);package_files.add(name)
    for name in ['server.py','issue_token.py','README.md','static/index.html','static/dashboard.css','static/dashboard.js']:
        target=dest/'master'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/'tools/master_server'/name,target);package_files.add('master/'+name)
    for source in (ROOT / 'addons/bsp_importer').glob('*LICENSE*'):
        target=dest/'licenses/bsp_importer'/source.name
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        package_files.add(target.relative_to(dest).as_posix())
    launcher = dest / 'start-server.sh'
    launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\nserver_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$server_dir/FPSloppaServer.x86_64" --log-file "$server_dir/server-engine.log" -- --config "$server_dir/server.cfg" "$@"\n')
    launcher.chmod(0o755)
    worker_launcher = dest / 'start-bot-worker.sh'
    worker_launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\nworker_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$worker_dir/FPSloppaServer.x86_64" --log-file "$worker_dir/bot-worker-engine.log" -- --bot-worker "$@"\n')
    worker_launcher.chmod(0o755)
    package_files.add('start-bot-worker.sh')
    shutil.copy2(ROOT/'tools/bot_service/fpsloppa-bot-worker.service', dest/'fpsloppa-bot-worker.service')
    package_files.add('fpsloppa-bot-worker.service')
    shutil.copy2(ROOT/'tools/bot_service/server-worker.example.cfg', dest/'server-worker.example.cfg')
    package_files.add('server-worker.example.cfg')
    symbols=subprocess.check_output(['objdump','-T',str(binary)],text=True)
    abi=sorted(set(re.findall(r'\b(?:GLIBC|GLIBCXX|CXXABI)_[0-9.]+',symbols)))
    report = dict(package_files=sorted(package_files), engine=VERSION, source_sha256=SOURCE_SHA256, platform_policy='console-only-alerts-and-shell-v1', flags=FLAGS, dependencies=dependencies, required_abi=abi, resources=sorted(selected),
                  resource_sha256={path:hashlib.sha256(source.read_bytes()).hexdigest() for path,source in selected.items()},
                  executable_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), pack_sha256=hashlib.sha256(pack.read_bytes()).hexdigest(), native_sha256=hashlib.sha256(native_library.read_bytes()).hexdigest())
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
    unexpected = [p for p in list(dest.rglob('*.so')) + list(dest.rglob('*.gdextension')) if p.relative_to(dest).as_posix() != NATIVE_LIBRARY]
    if unexpected: raise RuntimeError('Unexpected native plugins in server directory: '+str(unexpected))
    native_dependencies(dest/NATIVE_LIBRARY)
    if hashlib.sha256((dest/NATIVE_LIBRARY).read_bytes()).hexdigest()!=report.get('native_sha256'):
        raise RuntimeError('Server native library differs from receipt')
    if any(not allowed(p) for p in report['resources'] if p not in {'project.godot','.godot/global_script_class_cache.cfg'}):
        raise RuntimeError('Client resources found in server receipt')
    print('CONSOLE_SERVER_VERIFIED',binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
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
    package(godot, template.resolve(), args.output.resolve())


if __name__ == '__main__':main()
