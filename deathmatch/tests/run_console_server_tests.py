"""Audit the server artifact and exercise maps in an instrumented console-only pack."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_console_server import verify_package


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server',type=Path,default=ROOT/'Builds/ConsoleServer')
    args=parser.parse_args();server=args.server.resolve()
    verify_package(server)
    work=ROOT/'test-results/console-server';work.mkdir(parents=True,exist_ok=True)
    # The audit uses exactly the packaged server resources, with one test scene added.
    manifest=json.loads((ROOT/'test-results/console-server-package/pack.json').read_text())
    receipt=json.loads((server/'server-build.json').read_text())
    for row in manifest['files']:
        if hashlib.sha256(Path(row['source']).read_bytes()).hexdigest()!=receipt['resource_sha256'][row['path'].removeprefix('res://')]:
            raise RuntimeError('Source changed since server packaging; rebuild before running audit: '+row['path'])
    project=next(row for row in manifest['files'] if row['path']=='res://project.godot')
    config=Path(project['source']).read_text().replace('res://deathmatch/arena.tscn','res://deathmatch/tests/console_server.tscn')
    (work/'project.godot').write_text(config);project['source']=str(work/'project.godot')
    scene=work/'audit.tscn'
    scene.write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://deathmatch/tests/console_server.gd" id="1"]\n[node name="Audit" type="Node"]\nscript=ExtResource("1")\n')
    manifest['files'] += [dict(path='res://deathmatch/tests/console_server.gd',source=str(ROOT/'deathmatch/tests/console_server.gd')),dict(path='res://deathmatch/tests/console_server.tscn',source=str(scene))]
    executable=work/'FPSloppaServer.x86_64';shutil.copy2(server/executable.name,executable)
    manifest['output']=str(executable.with_suffix('.pck'))
    (work/'pack.json').write_text(json.dumps(manifest))
    godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
    subprocess.run([godot,'--headless','--xr-mode','off','--log-file',str(work/'packaging.log'),'--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(work/'pack.json')],check=True)
    (work/'server.cfg').write_text('set net_ip 127.0.0.1\nset net_port 27912\nset sv_maxclients 16\n')
    with (work/'runtime.log').open('w') as log:
        result=subprocess.run([str(executable),'--log-file',str(work/'engine.log'),'--','--asset-root',str(server)],cwd='/tmp',stdout=log,stderr=subprocess.STDOUT,timeout=120)
    text=(work/'runtime.log').read_text()
    report=next((json.loads(line.split('CONSOLE_RUNTIME_RESULT ',1)[1]) for line in text.splitlines() if line.startswith('CONSOLE_RUNTIME_RESULT ')),{})
    report['passed']=result.returncode==0 and report.get('passed',False) and 'ERROR:' not in text
    report['exit_code']=result.returncode
    (work/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
