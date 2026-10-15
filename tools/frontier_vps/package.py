"""Package the current frontier working tree without changing normal export presets."""
import argparse,hashlib,json,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--template',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--godot',default='godot');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='cq-frontier-package-') as tmp:
 stage=Path(tmp)
 for folder in ['deathmatch','addons','experimental-assets','tools']:
  shutil.copytree(ROOT/folder,stage/folder,ignore=shutil.ignore_patterns('__pycache__','*.log','offline-base.zip','*.os','.sconsign.*','build-scons','build-linux','build-linux-server','cq-field'))
 # LPMAC authoring/source files are not runtime assets; ship its optimized GLB/manifest only.
 shutil.rmtree(stage/'tools/ground_transport',ignore_errors=True)
 shutil.rmtree(stage/'tools/cloak_device',ignore_errors=True)
 (stage/'.godot/imported').mkdir(parents=True)
 for imp in stage.rglob('*.import'):
  for resource in re.findall(r'res://\.godot/imported/[^"\r\n]+',imp.read_text()):
   src=ROOT/resource[6:];dest=stage/resource[6:]
   if not src.is_file():raise RuntimeError(f'Missing imported resource: {src}; import with XR off first')
   shutil.copy2(src,dest)
 for name in ['uid_cache.bin','global_script_class_cache.cfg']:
  shutil.copy2(ROOT/'.godot'/name,stage/'.godot'/name)
 native_addon=ROOT/'addons/fps_native'
 # A stale or ABI-incompatible native binary must fail packaging explicitly.
 import importlib.util
 spec=importlib.util.spec_from_file_location('native_build',ROOT/'tools/build_gameplay_native.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
 gameplay=build.require_build('linux',server=True);build.require_portable_linux(gameplay)
 extension=(native_addon/'fps_native.gdextension.in').read_text().replace('bin/libfpsloppa_native.so','bin/libfpsloppa_native.server.so')
 (stage/'addons/fps_native/fps_native.gdextension').write_text(extension)
 (stage/'.godot/extension_list.cfg').write_text('res://addons/twovoip/twovoip.gdextension\nres://addons/fps_native/fps_native.gdextension\n')
 project=(ROOT/'project.godot').read_text().replace('run/main_scene="res://deathmatch/entry.tscn"','run/main_scene="res://tools/frontier_vps/entry.tscn"')
 (stage/'project.godot').write_text(project)
 rows=[{'path':'res://'+str(f.relative_to(stage)),'source':str(f)} for f in sorted(stage.rglob('*')) if f.is_file()]
 manifest=stage/'pack-manifest.json';manifest.write_text(json.dumps({'output':str((a.output/'cq-server.pck').resolve()),'files':rows}))
 subprocess.run([a.godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(manifest)],check=True)
 shutil.copy2(a.template,a.output/'cq-server');(a.output/'cq-server').chmod(0o755)
 native=Path('addons/twovoip/libs/libtwovoip.linux.template_release.x86_64.so');(a.output/native).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/native,a.output/native)
 gameplay_path=Path('addons/fps_native/bin/libfpsloppa_native.server.so');(a.output/gameplay_path).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(gameplay,a.output/gameplay_path)
 files=[Path('cq-server'),Path('cq-server.pck'),native,gameplay_path]
 (a.output/'release-sha256.json').write_text(json.dumps({str(f):hashlib.sha256((a.output/f).read_bytes()).hexdigest() for f in files},indent=2))
print('CQ_FRONTIER_PACKAGE',a.output.resolve())
