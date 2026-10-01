"""Create disposable physics projects without changing the production backend."""
from pathlib import Path
import shutil
import re
ROOT=Path(__file__).resolve().parents[2]
ENGINES={'godot':'GodotPhysics3D','jolt':'Jolt Physics','rapier':'Rapier3D'}
def prepare(engine):
 out=Path('/tmp/fps-physics-'+engine);out.mkdir(exist_ok=True)
 for source in ROOT.iterdir():
  if source.name.startswith('.') or source.name in ('project.godot','addons'):continue
  target=out/source.name
  if not target.exists():target.symlink_to(source,target_is_directory=source.is_dir())
 addons=out/'addons';addons.mkdir(exist_ok=True)
 for source in (ROOT/'addons').iterdir():
  target=addons/source.name
  if not target.exists():target.symlink_to(source,target_is_directory=source.is_dir())
 cache=out/'.godot';cache.mkdir(exist_ok=True)
 for name in ('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
  if (ROOT/'.godot'/name).exists():shutil.copy2(ROOT/'.godot'/name,cache/name)
 if not (cache/'imported').exists():(cache/'imported').symlink_to(ROOT/'.godot/imported',target_is_directory=True)
 if engine=='rapier':
  addon=Path('/tmp/fps-rapier-addon/godot-rapier-3d-single/addons/godot-rapier3d')
  target=addons/'godot-rapier3d'
  if not target.exists():target.symlink_to(addon,target_is_directory=True)
  with (cache/'extension_list.cfg').open('a') as file:file.write('res://addons/godot-rapier3d/godot-rapier3d.gdextension\n')
 text=re.sub(r'^3d/physics_engine=.*\n','',(ROOT/'project.godot').read_text(),flags=re.M)
 text=text.replace('[physics]',f'[physics]\n\n3d/physics_engine="{ENGINES[engine]}"')
 (out/'project.godot').write_text(text)
 return out
if __name__=='__main__':
 for engine in ENGINES:print(prepare(engine))
