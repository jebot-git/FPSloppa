"""Export PC clients + optional dedicated server and package binaries/source."""
from pathlib import Path
import subprocess, shutil, zipfile, json, os, sys

root=Path(__file__).resolve().parents[1]
builds=root.parent/'Builds'
godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
targets=[('Linux PC','Linux','Entryway.x86_64'),('Windows PC','Windows','Entryway.exe'),('Linux Dedicated Server','Server','EntrywayServer.x86_64')]
if '--package-only' not in sys.argv:
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
    for name in ['EYES.md','PERFORMANCE.md','ICON.md','TRACKING.md','AUDIO.md','README.md','VR.md','VOICE.md','SERVER.md','STANDALONE.md','ASSET_CREDITS.md','AVATARS.md','MAPS.md','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']:
        shutil.copy2(root/name,dest/name)
    for source in list((root/'addons').rglob('*'))+list((root/'deathmatch/audio/recorded').rglob('*')):
        if source.is_file() and ('license' in source.name.lower() or 'copying' in source.name.lower() or source.name=='SOURCES.md'):
            out=dest/'licenses'/source.relative_to(root);out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    for source in (root/'deathmatch/maps').glob('LibreQuake-*.txt'):
        out=dest/'licenses'/source.name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,out)
    if folder=='Server':
        shutil.copy2(root/'server.cfg',dest/'server.cfg')
        (dest/'start-server.sh').write_text('#!/usr/bin/env bash\nset -euo pipefail\nserver_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$server_dir/EntrywayServer.x86_64" -- --config "$server_dir/server.cfg" "$@"\n')
        (dest/'start-server.sh').chmod(0o755)
    elif folder=='Linux':
        for label,mode in [('VR','on'),('Desktop','off')]:
            f=dest/f'Play-{label}.sh'
            f.write_text('#!/usr/bin/env bash\nset -euo pipefail\ngame_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec "$game_dir/Entryway.x86_64" --xr-mode '+mode+' "$@"\n');f.chmod(0o755)
    else:
        for label,mode in [('VR','on'),('Desktop','off')]:
            (dest/f'Play-{label}.cmd').write_bytes(('@echo off\r\n"%~dp0Entryway.exe" --xr-mode '+mode+' %*\r\n').encode())

archives=[]
for folder,name in [('Linux','Entryway-Linux.zip'),('Windows','Entryway-Windows.zip'),('Server','Entryway-Dedicated-Server-Linux.zip')]:
    archive=root.parent/name
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for f in sorted((builds/folder).rglob('*')):
            if f.is_file():z.write(f,Path('Entryway-'+folder)/f.relative_to(builds/folder))
    archives.append(archive)
archive=root.parent/'Entryway-Deathmatch.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for f in sorted(root.rglob('*')):
        rel=f.relative_to(root)
        if rel.parts[0] == 'android':continue
        if not f.is_file() or any(x in {'.godot','.git','__pycache__'} for x in rel.parts) or f.suffix in {'.import','.pyc'}:continue
        z.write(f,Path('Godot')/rel)
archives.append(archive)
for archive in archives:
    with zipfile.ZipFile(archive) as z:
        if z.testzip():raise SystemExit(f'Invalid archive: {archive}')
    print('PACKAGED',archive.name,archive.stat().st_size,flush=True)
