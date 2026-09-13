"""Run the same combat suite in the stripped console-only server engine."""
from pathlib import Path
import json, os, shutil, subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/weapon-variants/console';SERVER=ROOT/'Builds/WeaponVariantsServer'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    os.environ["XDG_DATA_HOME"]=str(OUT/"user")
    subprocess.run(['python3','tools/build_console_server.py','--template','Builds/ConsoleServer/FPSloppaServer.x86_64','--output',str(SERVER)],cwd=ROOT,check=True)
    manifest=json.loads((ROOT/'test-results/console-server-package/pack.json').read_text())
    source=(ROOT/'deathmatch/tests/weapon_variants.gd').read_text()
    for a,b in [('extends SceneTree','extends Node'),('func _initialize()','func _ready()'),('root.add_child(g)','get_tree().root.add_child(g)'),('await physics_frame','await get_tree().physics_frame'),('await process_frame','await get_tree().process_frame'),(';quit(', ';get_tree().quit('),('g.start_host("Variants",0,100,60,true);g.bots.free();g.bots=null;', 'g.multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();g._add_player(1,"Console shooter");g._add_player(-1,"Target");g._add_player(-2,"Bystander");'),('res://test-results/weapon-variants',str(OUT))]:source=source.replace(a,b)
    (OUT/'test.gd').write_text(source)
    scene='[gd_scene format=3]\n[ext_resource type="Script" path="res://deathmatch/tests/weapon_variants.gd" id="1"]\n[node name="Audit" type="Node"]\nscript=ExtResource("1")\n'
    (OUT/'test.tscn').write_text(scene)
    project=next(r for r in manifest['files'] if r['path']=='res://project.godot')
    (OUT/'project.godot').write_text(Path(project['source']).read_text().replace('res://deathmatch/arena.tscn','res://deathmatch/tests/weapon_variants.tscn'));project['source']=str(OUT/'project.godot')
    manifest['files'] += [dict(path='res://deathmatch/tests/weapon_variants.gd',source=str(OUT/'test.gd')),dict(path='res://deathmatch/tests/weapon_variants.tscn',source=str(OUT/'test.tscn')),dict(path='res://deathmatch/tests/fixture.gd',source=str(ROOT/'deathmatch/tests/fixture.gd'))]
    exe=OUT/'FPSloppaServer.x86_64';shutil.copy2(SERVER/exe.name,exe)
    manifest['output']=str(exe.with_suffix('.pck'));(OUT/'pack.json').write_text(json.dumps(manifest))
    (OUT/'server.cfg').write_text('set net_ip 127.0.0.1\nset net_port 27933\nset sv_gametype dm\nset sv_weapon_rules doom\n')
    with (OUT/'pack.log').open('w') as f:subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(OUT/'pack.json')],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=40)
    with (OUT/'runtime.log').open('w') as f:r=subprocess.run([str(exe),'--','--asset-root',str(SERVER)],cwd=OUT,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    text=(OUT/'runtime.log').read_text();row=next((json.loads(l.split('VARIANTS_RESULT ',1)[1]) for l in text.splitlines() if l.startswith('VARIANTS_RESULT ')),{'passed':False,'failures':['No completed report']})
    row['errors']=[l for l in text.splitlines() if 'ERROR:' in l];row['exit_code']=r.returncode;row['passed']=row['passed'] and r.returncode==0 and not row['errors']
    (OUT/'report.json').write_text(json.dumps(row,indent=2)+'\n');print(json.dumps(row));return 0 if row['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
