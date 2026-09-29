"""Add benchmark entry scenes to an existing console package resource manifest.

The production console runtime disables CLI path/script overrides. Keep its
runtime/library unchanged and select the test harness through the packaged scene.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',type=Path,required=True,help='pack.json from build_console_server.py')
    p.add_argument('--output',type=Path,required=True,help='Existing fresh console package directory')
    p.add_argument('--freeze-ui',help='Optional git revision for unrelated command/turret UI scripts')
    a=p.parse_args();a.output=a.output.resolve();stage=a.output.parent/'package-fixtures';stage.mkdir(parents=True,exist_ok=True)
    d=json.loads(a.manifest.read_text());rows={row['path']:row['source'] for row in d['files']}
    target=stage/'project.godot'
    target.write_text(Path(rows['res://project.godot']).read_text().replace('res://deathmatch/arena.tscn','res://tools/native_study/st_batch_entry.tscn'))
    rows['res://project.godot']=str(target)
    for name in ['st_batch_server','st_batch_projectiles']:
        source=(ROOT/'tools/native_study'/ (name+'.gd')).read_text().replace('extends SceneTree','extends Node').replace('func _initialize():','func _ready():')
        source+='\nvar root:Window:\n\tget:return get_tree().root\nvar physics_frame:Signal:\n\tget:return get_tree().physics_frame\nvar process_frame:Signal:\n\tget:return get_tree().process_frame\nfunc quit(code:int=0):get_tree().quit(code)\n'
        target=stage/(name+'.gd');target.write_text(source);rows['res://tools/native_study/'+target.name]=str(target)
    script=stage/'st_batch_entry.gd';script.write_text('extends Node\nfunc _ready():\n\tvar runner:=Node.new()\n\trunner.set_script(load("res://tools/native_study/st_batch_projectiles.gd" if OS.get_cmdline_user_args().has("--projectile-benchmark") else "res://tools/native_study/st_batch_server.gd"))\n\tadd_child(runner)\n')
    scene=stage/'st_batch_entry.tscn';scene.write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://tools/native_study/st_batch_entry.gd" id="1"]\n[node name="Benchmark" type="Node"]\nscript=ExtResource("1")\n')
    for target in [script,scene,ROOT/'tools/native_study/st_batch_arena.gd']:rows['res://tools/native_study/'+target.name]=str(target)
    if a.freeze_ui:
        for name in ['command_view.gd','turret_view.gd']:
            path='deathmatch/tribes/'+name;target=stage/name;target.write_bytes(subprocess.check_output(['git','show',a.freeze_ui+':'+path],cwd=ROOT));rows['res://'+path]=str(target)
    d={'output':str(a.output/'FPSloppaServer.pck'),'files':[{'path':key,'source':value} for key,value in sorted(rows.items())]}
    manifest=stage/'benchmark-pack.json';manifest.write_text(json.dumps(d,indent=2)+'\n')
    subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(manifest)],check=True)
    for name in ['ctf_stonehenge','ctf_raindance','qsrc_dm1']:
        for path in ['maps/'+name+'.bsp','maps/navigation/'+name+'.res']:
            dest=a.output/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/path,dest)
    shutil.copy2(ROOT/'tools/native_study/compare_st_batch.py',a.output/'compare_st_batch.py')
    receipt={'freeze_ui':a.freeze_ui,'resource_sha256':{key:hashlib.sha256(Path(value).read_bytes()).hexdigest() for key,value in rows.items()},'file_sha256':{str(file.relative_to(a.output)):hashlib.sha256(file.read_bytes()).hexdigest() for file in a.output.rglob('*') if file.is_file() and file.name!='benchmark-build.json'}}
    (a.output/'benchmark-build.json').write_text(json.dumps(receipt,indent=2)+'\n')
if __name__=='__main__':main()
