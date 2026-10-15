"""Build game-only Linux/Windows CQ and a portable native server from the working tree.

Generated build folders are isolated; authoring sources, launcher, profiles and tests
are excluded from the runtime pack. CLI connection arguments override the live preset.
"""
import argparse, hashlib, importlib.util, json, re, shutil, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TEXT={'.gd','.tscn','.tres','.gdshader','.gdshaderinc'}
EXCLUDED={'.git','__pycache__','tests','launcher','build-scons','build-linux','build-linux-server','build-windows'}
AUTHORING={'.py','.cpp','.h','.o','.os','.a','.blend','.blend1','.kra','.zip','.mp4','.log','.pyc','.so','.dll','.exe','.aar','.framework'}
EXTENSIONS=['addons/fps_native/fps_native.gdextension','addons/twovoip/twovoip.gdextension','addons/godot-steam-audio/bin/libgodot-steam-audio.gdextension','addons/godotopenxrvendors/plugin.gdextension']
LIBRARIES={
 'Linux':['addons/fps_native/bin/libfpsloppa_native.so','addons/twovoip/libs/libtwovoip.linux.template_release.x86_64.so','addons/godot-steam-audio/bin/libgodot-steam-audio.linux.template_release.x86_64.so','addons/godot-steam-audio/bin/libphonon.so','addons/godotopenxrvendors/.bin/linux/template_release/x86_64/libgodotopenxrvendors.so'],
 'Windows':['addons/fps_native/bin/libfpsloppa_native.dll','addons/twovoip/libs/libtwovoip.windows.template_release.x86_64.dll','addons/godot-steam-audio/bin/libgodot-steam-audio.windows.template_release.x86_64.dll','addons/godot-steam-audio/bin/phonon.dll','addons/godotopenxrvendors/.bin/windows/template_release/x86_64/libgodotopenxrvendors.dll'],
 'Server':['addons/fps_native/bin/libfpsloppa_native.server.so','addons/twovoip/libs/libtwovoip.linux.template_release.x86_64.so']}
def digest(path):
 with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def allowed(path):
 return not set(path.parts)&EXCLUDED and path.suffix not in AUTHORING and not path.name.startswith('.env')
def stage_graph(stage):
 selected={}
 folders=['deathmatch','addons','experimental-assets','tools/voxel_battle','tools/streamed_heightfield','tools/voxelspace','tools/frontier_vps','tools/authority_core']
 pending=[]
 for folder in folders:
  for source in (ROOT/folder).rglob('*'):
   relative=source.relative_to(ROOT)
   if source.is_file() and allowed(relative):pending.append(relative.as_posix())
 # Keep the server's small packaged admission probe, never local interactive fixtures.
 for name in ['authority_core','frontier_vps']:
  for source in (ROOT/'tools'/name).glob('*.gd'):pending.append(source.relative_to(ROOT).as_posix())
 while pending:
  name=pending.pop();source=ROOT/name
  if name in selected or not source.is_file():continue
  if not allowed(Path(name)) or '/launcher/' in name or name in ['deathmatch/entry.gd','deathmatch/entry.tscn']:continue
  if name.startswith('tools/voxel_battle/') and Path(name).name.startswith(('preview_','benchmark_','test_','compare_','evaluate_','profile_','medic_test','scout_test','shocktroop_test','technician_test')):continue
  selected[name]=source
  if source.suffix in TEXT:
   pending.extend(re.findall(r'res://([A-Za-z0-9_./-]+\.[A-Za-z0-9]+)',source.read_text()))
  if source.suffix=='.import':pending.extend(re.findall(r'res://(\.godot/imported/[^"\r\n]+)',source.read_text()))
  imported=Path(str(source)+'.import')
  if imported.is_file():pending.append(name+'.import')
 for name,source in selected.items():
  target=stage/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
 # Eliminate editor-time global classes that were excluded with tools/launcher.
 classes=[]
 for name,source in selected.items():
  if source.suffix!='.gd':continue
  text=source.read_text();kind=re.search(r'^class_name\s+(\w+)',text,re.M);base=re.search(r'^extends\s+(\w+)',text,re.M)
  if kind and base:classes.append('{"base": &"'+base[1]+'", "class": &"'+kind[1]+'", "icon": "", "is_abstract": false, "is_tool": '+str('@tool' in text).lower()+', "language": &"GDScript", "path": "res://'+name+'"}')
 (stage/'.godot').mkdir(exist_ok=True)
 (stage/'.godot/global_script_class_cache.cfg').write_text('list=Array[Dictionary](['+',\n'.join(classes)+'])\n')
 shutil.copy2(ROOT/'.godot/uid_cache.bin',stage/'.godot/uid_cache.bin')
 return selected
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--templates',type=Path,default=Path.home()/'.local/share/godot/export_templates/4.7.2.stable');parser.add_argument('--address',default='87.106.27.237');parser.add_argument('--port',type=int,default=7777);args=parser.parse_args()
 out=args.output.resolve()
 if out.exists() and any(out.iterdir()):parser.error('Output must be new or empty')
 out.mkdir(parents=True,exist_ok=True)
 spec=importlib.util.spec_from_file_location('native_build',ROOT/'tools/build_gameplay_native.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
 native.require_portable_linux(native.require_build('linux',True));native.require_portable_linux(native.require_build('linux'));native.require_build('windows')
 version=(ROOT/'VERSION').read_text().strip();stage=out/'stage';stage.mkdir();selected=stage_graph(stage)
 # Runtime extension descriptors reference only the separately staged platform libraries.
 extension=(ROOT/'addons/fps_native/fps_native.gdextension.in').read_text()
 receipt={'version':version,'address':args.address,'port':args.port,'launcher':False,'platforms':{},'resources':len(selected)}
 project=(ROOT/'project.godot').read_text()
 for platform,template,binary in [('Server','linux_release.x86_64','cq-server'),('Linux','linux_release.x86_64','FPSloppaCQ.x86_64'),('Windows','windows_release_x86_64.exe','FPSloppaCQ.exe')]:
  folder=out/platform;folder.mkdir();server=platform=='Server'
  config=project.replace('run/main_scene="res://deathmatch/entry.tscn"','run/main_scene="res://tools/frontier_vps/'+('entry' if server else 'client_entry')+'.tscn"')
  config+='\n[cq]\ndefault_server="'+args.address+'"\ndefault_port='+str(args.port)+'\n'
  if server:config=config.replace('openxr/enabled=true','openxr/enabled=false')
  (stage/'project.godot').write_text(config)
  (stage/'addons/fps_native/fps_native.gdextension').write_text(extension.replace('bin/libfpsloppa_native.so','bin/libfpsloppa_native.server.so') if server else extension)
  (stage/'.godot/extension_list.cfg').write_text('\n'.join('res://'+s for s in EXTENSIONS[:2])+'\n' if server else '\n'.join('res://'+s for s in EXTENSIONS)+'\n')
  pack=folder/Path(binary).with_suffix('.pck') if platform=='Windows' else folder/('cq-server.pck' if server else 'FPSloppaCQ.pck')
  rows=[{'path':'res://'+p.relative_to(stage).as_posix(),'source':str(p)} for p in sorted(stage.rglob('*')) if p.is_file()]
  assert not any('/launcher/' in row['path'] for row in rows)
  manifest=out/'pack-manifest.json';manifest.write_text(json.dumps({'output':str(pack),'files':rows}))
  subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(manifest)],check=True)
  shutil.copy2(args.templates/template,folder/binary);(folder/binary).chmod(0o755)
  for name in LIBRARIES[platform]:
   target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
  # Steam Audio's dependency lookup is by soname/DLL name beside the plugin.
  for name in ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt','ASSET_CREDITS.md']:
   shutil.copy2(ROOT/name,folder/name)
  for source in ROOT.rglob('SOURCES.md'):
   if source.relative_to(ROOT).parts[0] not in ['deathmatch','addons']:continue
   target=folder/'licenses'/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
  for source in (ROOT/'addons').rglob('*'):
   if source.is_file() and source.name.lower() in ['license','license.txt','license.md','copying','copying.txt','ofl.txt'] and 'build' not in str(source.relative_to(ROOT)):
    target=folder/'licenses'/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
  if not server:
   for label,mode in [('Desktop','off'),('VR','on')]:
    if platform=='Linux':
     script=folder/('Play-'+label+'.sh');script.write_text('#!/bin/sh\nset -eu\ncd -- "$(dirname -- "$0")"\nexec ./'+binary+' --xr-mode '+mode+' --rendering-method forward_plus "$@"\n');script.chmod(0o755)
    else:(folder/('Play-'+label+'.cmd')).write_bytes(('@echo off\r\n"%~dp0'+binary+'" --xr-mode '+mode+' --rendering-method forward_plus %*\r\n').encode())
   (folder/'README.txt').write_text('FPSloppa CQ '+version+'\nStart Play-Desktop or Play-VR. The game connects to '+args.address+':'+str(args.port)+' automatically.\nUse -- --connect HOST --port PORT after engine arguments to override.\nNo launcher or updater is included.\n')
  hashes={p.relative_to(folder).as_posix():digest(p) for p in sorted(folder.rglob('*')) if p.is_file()}
  (folder/'release-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n');receipt['platforms'][platform]={'files':len(hashes),'pack_bytes':pack.stat().st_size,'pack_sha256':digest(pack),'binary':binary}
  print('CQ_RELEASE_BUILT',platform,pack.stat().st_size,flush=True)
 (out/'build.json').write_text(json.dumps(receipt,indent=2)+'\n')
 shutil.rmtree(stage);(out/'pack-manifest.json').unlink()
if __name__=='__main__':main()
