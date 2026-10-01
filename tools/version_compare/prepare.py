#!/usr/bin/env python3
"""Prepare read-isolated 0.20/current projects. Requires existing local imports/bindings."""
from pathlib import Path
import hashlib,re,shutil,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE=Path('/tmp/fps-version-020')
CURRENT=Path('/tmp/fps-version-current')
def digest(path):return hashlib.sha256(path.read_bytes()).digest()
def prepare():
 if BASE.exists() or CURRENT.exists():raise RuntimeError('Choose fresh temporary folders; existing captures/projects are not overwritten.')
 BASE.mkdir();CURRENT.mkdir()
 proc=subprocess.Popen(['git','archive','0.20v'],cwd=ROOT,stdout=subprocess.PIPE)
 with tarfile.open(fileobj=proc.stdout,mode='r|') as archive:archive.extractall(BASE,filter='data')
 assert proc.wait()==0
 subprocess.run([sys.executable,str(BASE/'tools/build_gameplay_native.py'),'--target','linux','--bindings',str(ROOT/'external-tools/godot-cpp-native'),'-j','6'],check=True)
 for source in ROOT.iterdir():
  if not source.name.startswith('.') and source.name not in ('project.godot','Builds'):
   (CURRENT/source.name).symlink_to(source,target_is_directory=source.is_dir())
 for project in (BASE,CURRENT):
  cache=project/'.godot';cache.mkdir()
  for name in ('global_script_class_cache.cfg','uid_cache.bin'):shutil.copy2(ROOT/'.godot'/name,cache/name)
  (cache/'extension_list.cfg').write_text('res://addons/fps_native/fps_native.gdextension\n')
  if project==CURRENT:(cache/'imported').symlink_to(ROOT/'.godot/imported',target_is_directory=True)
  else:
   (cache/'imported').mkdir()
   # Reuse derived imports only if source bytes AND import policy match the tag.
   for original in list(BASE.rglob('*')):
    if not original.is_file() or original.suffix=='.import' or 'build-linux' in original.parts:continue
    source=ROOT/original.relative_to(BASE);descriptor=Path(str(source)+'.import')
    if not descriptor.exists():continue
    assert digest(original)==digest(source),f'Reimport changed baseline asset: {original}'
    target=Path(str(original)+'.import')
    if target.exists():assert target.read_bytes()==descriptor.read_bytes(),f'Reimport baseline policy: {target}'
    else:shutil.copy2(descriptor,target)
    for resource in set(re.findall(r'res://\.godot/imported/[^"\n]+',target.read_text())):
     artifact=ROOT/'.godot/imported'/Path(resource).name
     assert artifact.exists(),f'Missing import: {artifact}'
     shutil.copy2(artifact,cache/'imported'/artifact.name)
  source=(BASE/'project.godot' if project==BASE else ROOT/'project.godot').read_text()
  source=re.sub(r'run/main_scene=.*','run/main_scene="res://version_fixture.tscn"',source)
  source=re.sub(r'\[autoload\].*?(?=\[)','',source,flags=re.S)
  (project/'project.godot').write_text(source)
  shutil.copy2(ROOT/'tools/version_compare/fixture.gd',project/'version_fixture.gd')
  (project/'version_fixture.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://version_fixture.gd" id="1"]\n[node name="VersionComparison" type="Node"]\nscript=ExtResource("1")\n')
 sys.path.insert(0,str(ROOT/'tools'))
 from renderer_policy import require_client_template
 runtime=require_client_template('linuxbsd')
 for project in (BASE,CURRENT):shutil.copy2(runtime,project/'FPSloppa')
 print('Prepared:',BASE,CURRENT)
if __name__=='__main__':prepare()
