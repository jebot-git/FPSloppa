"""Test a locally supplied Well6 BSP; optionally use a freshly built console engine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('map',type=Path)
    parser.add_argument('--server',type=Path,help='Fresh tools/build_console_server.py output')
    args=parser.parse_args();map_path=args.map.resolve()
    work=ROOT/'test-results/well6'/('console' if args.server else 'desktop');work.mkdir(parents=True,exist_ok=True)
    godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:parser.error('Godot packaging/test executable is required')
    if args.server:
        server=args.server.resolve()
        manifest=json.loads((ROOT/'test-results/console-server-package/pack.json').read_text())
        receipt=json.loads((server/'server-build.json').read_text())
        for row in manifest['files']:
            if hashlib.sha256(Path(row['source']).read_bytes()).hexdigest()!=receipt['resource_sha256'][row['path'].removeprefix('res://')]:
                raise RuntimeError('Rebuild the server before auditing changed resources: '+row['path'])
        # Release templates run a main scene, not --script. Inject only the test
        # scene into the otherwise unchanged console resource graph.
        test=(ROOT/'deathmatch/tests/well6.gd').read_text()
        for a,b in [('extends SceneTree','extends Node'),('func _initialize()','func _ready()'),('root.add_child(game)','get_tree().root.add_child(game)'),('await physics_frame','await get_tree().physics_frame'),('await process_frame','await get_tree().process_frame'),('\n\tquit(','\n\tget_tree().quit(')]:test=test.replace(a,b)
        (work/'test.gd').write_text(test)
        (work/'test.tscn').write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://deathmatch/tests/well6.gd" id="1"]\n[node name="Audit" type="Node"]\nscript=ExtResource("1")\n')
        project=next(row for row in manifest['files'] if row['path']=='res://project.godot')
        (work/'project.godot').write_text(Path(project['source']).read_text().replace('res://deathmatch/arena.tscn','res://deathmatch/tests/well6.tscn'))
        project['source']=str(work/'project.godot')
        manifest['files'] += [dict(path='res://deathmatch/tests/well6.gd',source=str(work/'test.gd')),dict(path='res://deathmatch/tests/well6.tscn',source=str(work/'test.tscn'))]
        exe=work/'FPSloppaServer.x86_64';shutil.copy2(server/exe.name,exe)
        manifest['output']=str(exe.with_suffix('.pck'));(work/'pack.json').write_text(json.dumps(manifest))
        with (work/'pack.log').open('w') as log:
            subprocess.run([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--log-file',str(work/'pack-engine.log'),'--script','res://deathmatch/server/package.gd','--',str(work/'pack.json')],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
        (work/'server.cfg').write_text('set net_ip 127.0.0.1\nset net_port 27921\nset sv_maxclients 16\n')
        command=[str(exe),'--log-file',str(work/'engine.log'),'--',str(map_path),str(work/'result.json'),'--asset-root',str(server)]
    else:
        command=[godot,'--headless','--xr-mode','off','--path',str(ROOT),'--log-file',str(work/'engine.log'),'--script','res://deathmatch/tests/well6.gd','--',str(map_path),str(work/'result.json')]
    (work/'result.json').unlink(missing_ok=True)
    with (work/'runtime.log').open('w') as log:
        result=subprocess.run(command,cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=100)
    report=json.loads((work/'result.json').read_text()) if (work/'result.json').exists() else {'passed':False,'failures':['No completed report']}
    report['engine_errors']=[line for line in (work/'runtime.log').read_text().splitlines() if 'ERROR:' in line]
    report['passed']=report['passed'] and result.returncode==0 and not report['engine_errors']
    (work/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
    return 0 if report['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
