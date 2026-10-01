"""Build a local audit PCK using the real stripped server resource graph."""
from pathlib import Path
import json,shutil,subprocess,os
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/jolt-default'
project=OUT/'console-probe';project.mkdir(exist_ok=True);(project/'.gdignore').touch()
source=ROOT/'Builds/JoltValidationServer'
shutil.copy2(source/'FPSloppaServer.x86_64',project/'FPSloppaServer.x86_64')
lib=Path('addons/fps_native/bin/libfpsloppa_native.server.so');(project/lib).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/lib,project/lib)
manifest=json.loads((ROOT/'test-results/console-server-package/pack.json').read_text())
settings=(ROOT/'test-results/console-server-package/project.godot').read_text().replace('res://deathmatch/arena.tscn','res://console_probe.tscn')
(project/'project.godot').write_text(settings)
script=(ROOT/'deathmatch/tests/console_server.gd').read_text()
script=script.replace('for row in game.map_catalog:','for row in game.map_catalog.filter(func(r):return r.id in ["qsrc_dm6","ctf_katabatic","de_dust2_rebuilt","tf_vesper","as_hislop"]):')
(project/'console_probe.gd').write_text(script)
(project/'console_probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://console_probe.gd" id="1"]\n[node name="ConsoleAudit" type="Node"]\nscript=ExtResource("1")\n')
rows=[r for r in manifest['files'] if r['path']!='res://project.godot']
for name in ['project.godot','console_probe.gd','console_probe.tscn']:rows.append(dict(path='res://'+name,source=str(project/name)))
pack=dict(output=str(project/'FPSloppaServer.pck'),files=rows);(project/'manifest.json').write_text(json.dumps(pack,indent=2))
subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(project/'manifest.json')],check=True,env={**os.environ,'XDG_DATA_HOME':'/tmp/fps-jolt-pack-probe'})
(project/'server.cfg').write_text('set net_ip "127.0.0.1"\nset net_port "29871"\nset sv_public "0"\nset sv_query_port "0"\nset sv_bot_fill "0"\nset sv_log_level "off"\nmap "qsrc_dm6"\n')
print(project/'FPSloppaServer.x86_64')
