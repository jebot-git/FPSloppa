"""Export PC clients + optional dedicated server and package binaries/source."""
from pathlib import Path
import subprocess, shutil, zipfile, json, os, sys

root=Path(__file__).resolve().parents[1]
RETIRED={'optional-arena-pack','optional-threewave-tools','optional-tf-tools','optional-ad-tools'}
builds=root.parent/'Builds'
godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not godot: raise SystemExit('Set GODOT_BIN or install Godot on PATH')
(root/'test-results').mkdir(exist_ok=True)
targets=[('Linux PC','Linux','FPSloppa.x86_64'),('Windows PC','Windows','FPSloppa.exe'),('Linux Dedicated Server','Server','FPSloppaServer.x86_64')]
if '--package-only' not in sys.argv and '--stage-only' not in sys.argv:
    for preset,folder,binary in targets:
        dest=builds/folder;dest.mkdir(parents=True,exist_ok=True)
        log=root/'test-results'/('export_'+folder.lower()+'.log')
        with log.open('w') as output:
            result=subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--export-release',preset,str(dest/binary)],stdout=output,stderr=subprocess.STDOUT)
        if result.returncode or not (dest/binary).is_file() or any(marker in log.read_text() for marker in ['SCRIPT ERROR:', 'Cannot export project']):raise SystemExit(f'Export failed: {preset}; see {log}')
        print('EXPORTED',preset,flush=True)

if '--exports-only' in sys.argv:raise SystemExit(0)

for _,folder,_ in targets:
    dest=builds/folder
    asset_manifest=json.loads((root/"deathmatch/assets/base_manifest.json").read_text())
    for row in asset_manifest["files"]:
        source=root/row["path"];destination=dest/row["path"];destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,destination)
    for source in (root/'docs').glob('*.md'):
        out=dest/'docs'/source.name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    for name in ['NETWORK_TESTING.md','SESSION_FEATURES.md','AVATAR_LIGHTING.md','MAP_LIGHTING.md','TF.md','EYES.md','PERFORMANCE.md','ICON.md','TRACKING.md','AUDIO.md','README.md','VR.md','VOICE.md','SERVER.md','GAMEMODES.md','STANDALONE.md','LIVE_VR_TEST.md','client.example.cfg','ASSET_CREDITS.md','AVATARS.md','MAPS.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']:
        shutil.copy2(root/name,dest/name)
    for source in list((root/'addons').rglob('*'))+list((root/'deathmatch/audio/recorded').rglob('*'))+list((root/'deathmatch/audio/announcer').rglob('*'))+list((root/'deathmatch/audio/music').rglob('*'))+list((root/'deathmatch/ui').rglob('*'))+list((root/'deathmatch/movement').rglob('*')):
        if source.is_file() and ('license' in source.name.lower() or 'copying' in source.name.lower() or source.name in {'SOURCES.md','THIRDPARTY.md','OFL.txt'}):
            out=dest/'licenses'/source.relative_to(root);out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    for source in (root/'deathmatch/maps').glob('LibreQuake-*.txt'):
        out=dest/'licenses'/source.name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    for source in (root/'deathmatch/maps/librequake-props').glob('*'):
        if source.name not in {'LICENCE.txt','CREDITS.txt','SOURCES.json'}:continue
        out=dest/'licenses/librequake-props'/source.name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    if folder=='Server':
        shutil.copy2(root/'server.cfg',dest/'server.cfg')
        (dest/'start-server.sh').write_text('#!/usr/bin/env bash\nset -euo pipefail\nserver_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$server_dir/FPSloppaServer.x86_64" -- --config "$server_dir/server.cfg" "$@"\n')
        (dest/'start-server.sh').chmod(0o755)
    elif folder=='Linux':
        for label,mode in [('VR','on'),('Desktop','off')]:
            f=dest/f'Play-{label}.sh'
            f.write_text('#!/usr/bin/env bash\nset -euo pipefail\ngame_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$game_dir/FPSloppa.x86_64" --xr-mode '+mode+' "$@"\n');f.chmod(0o755)
    else:
        for label,mode in [('VR','on'),('Desktop','off')]:
            (dest/f'Play-{label}.cmd').write_bytes(('@echo off\r\n"%~dp0FPSloppa.exe" --xr-mode '+mode+' %*\r\n').encode())

if '--stage-only' in sys.argv:
    print('STAGED binary folders, assets, launchers and license notices',flush=True)
    raise SystemExit(0)

archives=[]
for folder,name in [('Linux','FPSloppa-Linux.zip'),('Windows','FPSloppa-Windows.zip'),('Server','FPSloppa-Dedicated-Server-Linux.zip')]:
    archive=root.parent/name
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for f in sorted((builds/folder).rglob('*')):
            rel=f.relative_to(builds/folder)
            if rel.parts[0] in {'demos','video-output'}:continue
            if rel.name in {'Entryway.x86_64','Entryway.exe','Entryway.pck','EntrywayServer.x86_64','EntrywayServer.pck'}:continue
            if rel.parts[0] in {'maps','vrm'} and rel.as_posix() not in {row['path'] for row in asset_manifest['files']}:continue
            if f.is_file():z.write(f,Path('FPSloppa-'+folder)/rel)
    archives.append(archive)
archive=root.parent/'FPSloppa-Deathmatch.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    # Honor Git exclusions: never ship local tracking captures, build caches,
    # signing files or release archives recursively inside the source archive.
    if (root/'.git').exists():
        files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root).decode().split('\0')
    else:
        files=[str(f.relative_to(root)) for f in root.rglob('*') if f.is_file()]
    for name in sorted(set(files)-{''}):
        rel=Path(name);f=root/rel
        # Local AD derivatives are excluded even when packaging a non-Git checkout.
        if 'AD-NOTICES' in rel.parts or rel.name.startswith('ad_arena_') or rel.name.endswith('_ad_maplist.txt') or rel.name=='ad-maplists.cfg':continue
        if len(rel.parts)>1 and rel.parts[:2]==('optional-ad-tools','local'):continue
        if not f.is_file() or rel.parts[0] in RETIRED | {'android','test-results','release-assets','.agents','.codex'}:continue
        if any(part in {'.godot','.git','__pycache__'} for part in rel.parts):continue
        if f.suffix in {'.import','.pyc','.log','.keystore','.jks','.p12'} or f.name=='.DS_Store' or f.name=='.env' or f.name.startswith('.env.'):continue
        z.write(f,Path('Godot')/rel)
archives.append(archive)
for archive in archives:
    with zipfile.ZipFile(archive) as z:
        if z.testzip():raise SystemExit(f'Invalid archive: {archive}')
    print('PACKAGED',archive.name,archive.stat().st_size,flush=True)
