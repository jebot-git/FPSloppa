"""Export PC clients + optional dedicated server and package binaries/source."""
from pathlib import Path
import subprocess, shutil, zipfile, json, os, sys

from map_distribution import distributable
root=Path(__file__).resolve().parents[1]
RETIRED={'optional-map-pack','optional-arena-pack','optional-threewave-tools','optional-tf-tools','optional-ad-tools','optional-tf-map-pack'}
builds=root.parent/'Builds'
godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not godot: raise SystemExit('Set GODOT_BIN or install Godot on PATH')
(root/'test-results').mkdir(exist_ok=True)
targets=[('Linux PC','Linux','FPSloppa.x86_64'),('Windows PC','Windows','FPSloppa.exe')]
if '--package-only' not in sys.argv and '--stage-only' not in sys.argv:
    markers=[]
    try:
        for name in ['Builds','dist','external-tools','tools','docs','materials','textures']:
            marker=root/name/'.gdignore'
            if marker.parent.is_dir() and not marker.exists():marker.touch();markers.append(marker)
        for preset,folder,binary in targets:
            dest=builds/folder;dest.mkdir(parents=True,exist_ok=True)
            log=root/'test-results'/('export_'+folder.lower()+'.log')
            with log.open('w') as output:
                result=subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--export-release',preset,str(dest/binary)],stdout=output,stderr=subprocess.STDOUT)
            if result.returncode or not (dest/binary).is_file() or any(marker in log.read_text() for marker in ['SCRIPT ERROR:', 'Cannot export project']):raise SystemExit(f'Export failed: {preset}; see {log}')
            print('EXPORTED',preset,flush=True)
    finally:
        for marker in markers:marker.unlink(missing_ok=True)

# Require the policy when repackaging existing exports too.
for _,folder,_ in targets:
    subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/renderer_export.gd','--',str(builds/folder/'FPSloppa.pck')],check=True)

# Server uses a distinct directory: never mix in plugins from legacy exports.
server_dest=root/'Builds/ConsoleServer'
server_command=[sys.executable,str(root/'tools/build_console_server.py'),'--cq-assets','--output',str(server_dest)]
if '--package-only' in sys.argv:
    server_command.append('--verify-only')
elif os.environ.get('FPSLOPPA_SERVER_TEMPLATE'):
    server_command += ['--template',os.environ['FPSLOPPA_SERVER_TEMPLATE']]
subprocess.run(server_command,check=True)

if '--exports-only' in sys.argv:raise SystemExit(0)

package_files={}
for _,folder,binary in targets:
    dest=builds/folder
    native={'Linux':['libfpsloppa_bhaptics_native.so','libgodot-steam-audio.linux.template_release.x86_64.so','libgodotopenxrvendors.so','libphonon.so','libtwovoip.linux.template_release.x86_64.so'], 'Windows':['fpsloppa_bhaptics_native.dll','libgodot-steam-audio.windows.template_release.x86_64.dll','libgodotopenxrvendors.dll','libtwovoip.windows.template_release.x86_64.dll','libunwind.dll','phonon.dll']}
    selected={binary,'FPSloppa.pck',*native[folder]}
    package_files[folder]=selected
    def stage(source,out):
        out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out);selected.add(out.relative_to(dest).as_posix())
    asset_manifest=json.loads((root/"deathmatch/assets/base_manifest.json").read_text())
    for row in asset_manifest["files"]:
        source=root/row["path"];destination=dest/row["path"];destination.parent.mkdir(parents=True,exist_ok=True);stage(source,destination)
    for name in ['EXTERNAL-ASSETS.md','ARCHIVED-EXTRAS.md','RENDERER-SUPPORT.md']:
        stage(root/'docs'/name,dest/'docs'/name)
    for name in ['AVATAR_LIGHTING.md','MAP_LIGHTING.md','TF.md','AS.md','EYES.md','PERFORMANCE.md','TRACKING.md','AUDIO.md','README.md','VR.md','VOICE.md','SERVER.md','GAMEMODES.md','STANDALONE.md','client.example.cfg','ASSET_CREDITS.md','AVATARS.md','MAPS.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']:
        stage(root/name,dest/name)
    for source in list((root/'addons').rglob('*'))+list((root/'deathmatch/audio').rglob('*'))+list((root/'deathmatch/ui').rglob('*'))+list((root/'deathmatch/movement').rglob('*')):
        if source.is_file() and ('license' in source.name.lower() or 'copying' in source.name.lower() or source.name in {'SOURCES.md','THIRDPARTY.md','OFL.txt','CREDITS.txt'}):
            out=dest/'licenses'/source.relative_to(root);out.parent.mkdir(parents=True,exist_ok=True);stage(source,out)
    for source in (root/'deathmatch/maps').glob('LibreQuake-*.txt'):
        out=dest/'licenses'/source.name;out.parent.mkdir(parents=True,exist_ok=True);stage(source,out)
    for source in (root/'deathmatch/maps/librequake-props').glob('*'):
        if source.name not in {'LICENCE.txt','CREDITS.txt','SOURCES.json'}:continue
        out=dest/'licenses/librequake-props'/source.name;out.parent.mkdir(parents=True,exist_ok=True);stage(source,out)
    for name in ['CONQUEST.md','DISTRICT-SERVER-INTEGRATION.md']:
        stage(root/'docs'/name,dest/'docs'/name)
    stage(root/'conquest.cfg',dest/'conquest.cfg')
    for label,mode in [('Desktop','off'),('VR','on')]:
        if folder=='Linux':
            name=f'Play-Conquest-{label}.sh'
            launcher=dest/name
            launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\ngame_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\naddress="${1:-127.0.0.1}"\nif (( $# )); then shift; fi\nexec "$game_dir/FPSloppa.x86_64" --rendering-method mobile --rendering-driver vulkan --xr-mode '+mode+' -- --experimental-cq --connect "$address" --port 7787 "$@"\n')
            launcher.chmod(0o755)
        else:
            name=f'Play-Conquest-{label}.cmd'
            (dest/name).write_bytes(('@echo off\r\nset "address=%~1"\r\nif "%address%"=="" set "address=127.0.0.1"\r\n"%~dp0FPSloppa.exe" --rendering-method mobile --rendering-driver vulkan --xr-mode '+mode+' -- --experimental-cq --connect "%address%" --port 7787\r\n').encode())
        selected.add(name)
    if folder=='Linux':
        for label,mode in [('VR','on'),('Desktop','off')]:
            selected.add(f'Play-{label}.sh');f=dest/f'Play-{label}.sh'
            f.write_text('#!/usr/bin/env bash\nset -euo pipefail\ngame_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$game_dir/FPSloppa.x86_64" --rendering-method mobile --rendering-driver vulkan --xr-mode '+mode+' "$@"\n');f.chmod(0o755)
    else:
        stage(root/"tools"/"Diagnose-VR.cmd",dest/"Diagnose-VR.cmd")
        for label,mode in [('VR','on'),('Desktop','off')]:
            selected.add(f'Play-{label}.cmd')
            (dest/f'Play-{label}.cmd').write_bytes(('@echo off\r\n"%~dp0FPSloppa.exe" --rendering-method mobile --rendering-driver vulkan --xr-mode '+mode+' %*\r\n').encode())

if '--stage-only' in sys.argv:
    print('STAGED binary folders, assets, launchers and license notices',flush=True)
    raise SystemExit(0)

server_files=set(json.loads((server_dest/'server-build.json').read_text())['package_files'])
server_launcher=server_dest/'start-conquest-server.sh'
server_launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\nserver_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$server_dir/FPSloppaServer.x86_64" --log-file "$server_dir/conquest-engine.log" -- --experimental-cq --config "$server_dir/conquest.cfg" "$@"\n')
server_launcher.chmod(0o755)
server_files.add('start-conquest-server.sh')

archives=[]
for folder,name in [('Linux','FPSloppa-Linux.zip'),('Windows','FPSloppa-Windows.zip'),('Server','FPSloppa-Dedicated-Server-Linux.zip')]:
    archive=root.parent/name
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        package_dir=server_dest if folder=='Server' else builds/folder
        allowed=server_files if folder=='Server' else package_files[folder]
        for name in sorted(allowed):
            rel=Path(name);f=package_dir/rel
            assert f.is_file(),f
            if folder=='Server' and rel.as_posix() not in server_files:continue
            if rel.parts[0] in {'demos','video-output'} or f.suffix=='.log':continue
            if rel.name in {'Entryway.x86_64','Entryway.exe','Entryway.pck','EntrywayServer.x86_64','EntrywayServer.pck'}:continue
            if rel.parts[0] in {'maps','vrm'} and rel.as_posix() not in {row['path'] for row in asset_manifest['files']}:continue
            if f.is_file():z.write(root/'server.cfg' if folder=='Server' and rel.as_posix()=='server.cfg' else f,Path('FPSloppa-'+folder)/rel)
    archives.append(archive)
archive=root.parent/'FPSloppa-Deathmatch.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    # Include versioned sources only: never ship temporary export markers, captures,
    # signing files or release archives recursively inside the source archive.
    if (root/'.git').exists():
        files=subprocess.check_output(['git','ls-files','--cached','-z'],cwd=root).decode().split('\0')
    else:
        files=[str(f.relative_to(root)) for f in root.rglob('*') if f.is_file()]
    # Make the source download self-contained now the asset-only download is retired.
    files += [row['path'] for row in asset_manifest['files']]
    for name in sorted(set(files)-{''}):
        rel=Path(name);f=root/rel
        if not distributable(rel):continue
        # Local AD derivatives are excluded even when packaging a non-Git checkout.
        if rel.name.startswith('tf_fo_') or rel.parts[:3]==('tools','fortressone','local'):continue
        if 'AD-NOTICES' in rel.parts or rel.name.startswith('ad_arena_') or rel.name.endswith('_ad_maplist.txt') or rel.name=='ad-maplists.cfg':continue
        if len(rel.parts)>1 and rel.parts[:2]==('optional-ad-tools','local'):continue
        if not f.is_file() or rel.parts[0] in RETIRED | {'materials','textures','android','test-results','release-assets','.agents','.codex'}:continue
        if any(part in {'.godot','.git','__pycache__'} for part in rel.parts):continue
        if f.suffix=='.import' and rel.parent!=Path('deathmatch/maps/skies') and rel.as_posix()!='deathmatch/maps/texture_replacements/makkon-used.wad.import':continue
        if f.suffix in {'.pyc','.log','.mp4','.bak','.tmp','.keystore','.jks','.p12'} or f.name=='.DS_Store' or f.name=='.env' or f.name.startswith('.env.'):continue
        z.write(f,Path('Godot')/rel)
archives.append(archive)
for archive in archives:
    with zipfile.ZipFile(archive) as z:
        if z.testzip():raise SystemExit(f'Invalid archive: {archive}')
    print('PACKAGED',archive.name,archive.stat().st_size,flush=True)
