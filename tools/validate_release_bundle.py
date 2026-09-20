"""Audit final archives independently of staging folders and local user files."""
from pathlib import Path
import hashlib, json, zipfile
ROOT=Path(__file__).resolve().parents[1]
base=json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text())
rows=[]
for label,filename,prefix in [('Linux','FPSloppa-Linux.zip','FPSloppa-Linux/'),('Windows','FPSloppa-Windows.zip','FPSloppa-Windows/'),('Server','FPSloppa-Dedicated-Server-Linux.zip','FPSloppa-Server/'),('Source','FPSloppa-Deathmatch.zip','Godot/')]:
    archive=ROOT.parent/filename
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, filename
        names=set(z.namelist())
        assert len(names)==len(z.infolist()), 'Duplicate archive entries'
        for name in names:
            p=Path(name)
            assert name.startswith(prefix) and '..' not in p.parts and not name.startswith('/'), name
            assert not set(p.parts)&{'.git','.codex','.agents','test-results','release-assets','__pycache__','optional-map-pack','optional-tf-map-pack','optional-arena-pack'}, name
            assert p.parts[1] not in {'demos','video-output'}, name
            assert p.suffix.lower() not in {'.log','.mp4','.bak','.tmp','.pyc','.keystore','.jks','.p12'}, name
            assert p.name not in {'Entryway.pck','Entryway.exe','Entryway.x86_64'}, name
            assert p.parts[1:3]!=('maps','Community'), name
        assets=[row for row in base['files'] if label!='Server' or Path(row['path']).suffix not in {'.scn','.lit'} and 'cache' not in Path(row['path']).parts]
        for row in assets:
            data=z.read(prefix+row['path'])
            assert len(data)==row['size'] and hashlib.sha256(data).hexdigest()==row['sha256'], (label,row['path'])
        if label!='Source':
            assert {n for n in names if n.startswith((prefix+'maps/',prefix+'vrm/'))}=={prefix+row['path'] for row in assets}, ('Orphaned installed asset',label)
            assert not any(Path(n).suffix in {'.wad','.map','.png'} for n in names if n.startswith(prefix+'maps/'))
            assert prefix+'client.cfg' not in names
        else:
            for source in ['maps/Pressureworks/tf_pressureworks.map','maps/VesperAbbey/tf_vesper.map','maps/Quake/sources/adapted/qsrc_dm7.map','deathmatch/maps/texture_replacements/makkon-used.wad.import']:
                assert prefix+source in names,source
            for source in ['tools/master_server/server.py','tools/master_server/issue_token.py','deathmatch/ui/server_browser.gd','deathmatch/ui/server_directory.gd','deathmatch/server/discovery.gd','deathmatch/server/discovery_protocol.gd']:
                assert z.read(prefix+source)==(ROOT/source).read_bytes(),('Missing or stale discovery source',source)
        assert z.read(prefix+'docs/SERVER-BROWSER.md')==(ROOT/'docs/SERVER-BROWSER.md').read_bytes(),('Missing or stale browser guide',label)
        rows.append({'archive':filename,'bytes':archive.stat().st_size,'files':len(names),'verified_assets':len(assets),'maps':sum(row['path'].endswith('.bsp') for row in assets),'passed':True})
        print(label,'passed',len(names),'files',flush=True)
archive=ROOT.parent/'FPSloppa-Master-Server.zip'
with zipfile.ZipFile(archive) as z:
    expected={name:ROOT/'tools/master_server'/name for name in ['server.py','issue_token.py','README.md']}
    expected.update({'VERSION':ROOT/'VERSION','docs/SERVER-BROWSER.md':ROOT/'docs/SERVER-BROWSER.md'})
    assert z.testzip() is None
    assert len(z.infolist())==len(expected) and set(z.namelist())=={'FPSloppa-Master-Server/'+name for name in expected}
    for name,source in expected.items():assert z.read('FPSloppa-Master-Server/'+name)==source.read_bytes(),name
    rows.append({'archive':archive.name,'bytes':archive.stat().st_size,'files':len(expected),'passed':True})
    print('Master service passed',len(expected),'files',flush=True)
(ROOT/'test-results/release-bundle-audit.json').write_text(json.dumps(rows,indent=2)+'\n')
