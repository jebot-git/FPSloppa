"""Package the standalone Vulkan CQ desktop dependency graph, without arena entry/plugins."""
import argparse,hashlib,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TEXT={'.gd','.tscn','.tres','.gdshader','.gdshaderinc'}
def build(output,templates,godot):
    output=output.resolve();work=output/'pack';work.mkdir(parents=True,exist_ok=True)
    selected={};pending=['tools/district_cluster/client_entry.tscn','tools/district_cluster/desktop.gd','deathmatch/avatars/visual_loader.gd','deathmatch/avatars/models/manifest.json','maps/CampaignDistricts/manifest.json']
    for pattern in ['addons/vrm/**/*','addons/Godot-MToon-Shader/**/*','deathmatch/weapons/**/*','deathmatch/audio/cq/*.ogg','deathmatch/audio/cq/manifest.json','maps/CampaignDistricts/district_*/presentation.scn']:
        pending += [str(p.relative_to(ROOT)) for p in ROOT.glob(pattern) if p.is_file() and p.suffix not in {'.uid','.import','.md','.blend','.wav','.py'} and '.git' not in p.parts]
    while pending:
        path=pending.pop();source=ROOT/path
        if path in selected or not source.is_file():continue
        selected[path]=source
        if source.suffix in TEXT:
            pending+=re.findall(r'res://([A-Za-z0-9_./-]+\.[A-Za-z0-9]+)',source.read_text())
        imported=Path(str(source)+'.import')
        if imported.exists():
            pending.append(path+'.import')
            pending+=re.findall(r'res://([^"\n]+)',imported.read_text())
        # Binary scene dependencies are recovered below by Godot's resource loader.
    scan=work/'scan.json';scan.write_text(json.dumps(list(selected)))
    subprocess.run([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/cq_pack_dependencies.gd','--',str(scan)],check=True)
    for path in json.loads(scan.read_text()):
        if path not in selected and (ROOT/path).is_file():selected[path]=ROOT/path
    version=(ROOT/'VERSION').read_text().strip()
    project=work/'project.godot';project.write_text('''config_version=5
[application]
config/name="FPSloppa Conquest"
config/version="'''+version+'''"
run/main_loop_type="CQDesktop"
run/main_scene="res://tools/district_cluster/client_entry.tscn"
config/features=PackedStringArray("4.7", "Mobile")
[audio]
driver/enable_input=true
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
[rendering]
rendering_device/driver="vulkan"
rendering_device/driver.windows="vulkan"
rendering_device/driver.linuxbsd="vulkan"
rendering_device/fallback_to_d3d12=false
rendering_device/fallback_to_opengl3=false
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
occlusion_culling/use_occlusion_culling=true
[xr]
openxr/enabled=false
''');selected['project.godot']=project
    classes=[]
    for path,source in selected.items():
        if source.suffix!='.gd':continue
        body=source.read_text();name=re.search(r'^class_name (\w+)',body,re.M);base=re.search(r'^extends (\w+)',body,re.M)
        if name and base:classes.append('{"base": &"'+base[1]+'", "class": &"'+name[1]+'", "icon": "", "is_abstract": false, "is_tool": '+str('@tool' in body).lower()+', "language": &"GDScript", "path": "res://'+path+'"}')
    cache=work/'classes.cfg';cache.write_text('list=Array[Dictionary](['+',\n'.join(classes)+'])\n');selected['.godot/global_script_class_cache.cfg']=cache
    # Keep resource UIDs for this graph only; binary GLB scenes retain UID links.
    data=(ROOT/'.godot/uid_cache.bin').read_bytes();count=struct.unpack_from('<I',data)[0];offset=4;uids=[]
    for _ in range(count):
        uid,length=struct.unpack_from('<QI',data,offset);offset+=12;path=data[offset:offset+length];offset+=length
        if path.decode().removeprefix('res://') in selected:uids.append(struct.pack('<QI',uid,length)+path)
    uid_cache=work/'uid_cache.bin';uid_cache.write_bytes(struct.pack('<I',len(uids))+b''.join(uids));selected['.godot/uid_cache.bin']=uid_cache
    # No user profiles, deployment tokens, native plugins or unrelated maps.
    assert not any(p.endswith(('.so','.dll','.gdextension')) for p in selected)
    pack=work/'FPSloppaCQ.pck';manifest=work/'pack.json';manifest.write_text(json.dumps(dict(output=str(pack),files=[dict(path='res://'+p,source=str(s)) for p,s in sorted(selected.items())])))
    subprocess.run([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(manifest)],check=True)
    for platform,template,name in [('Linux','linux_release.x86_64','FPSloppaCQ.x86_64'),('Windows','windows_release_x86_64.exe','FPSloppaCQ.exe')]:
        folder=output/platform;folder.mkdir(exist_ok=True);shutil.copy2(templates/template,folder/name);(folder/name).chmod(0o755);shutil.copy2(pack,folder/'FPSloppaCQ.pck')
        for path in ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt','ASSET_CREDITS.md','docs/CQ-MODERATION.md','docs/CQ-CLIENT.md','docs/CQ-AUDIO.md']:
            shutil.copy2(ROOT/path,folder/Path(path).name)
        for addon in ['vrm','Godot-MToon-Shader']:
            for source in (ROOT/'addons'/addon).rglob('*LICENSE*'):
                target=folder/'licenses'/addon/source.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        for source in (ROOT/'maps/Makkon').glob('*'):
            if source.name in ['README.txt','Makkon_License.txt']:
                target=folder/'licenses/Makkon'/source.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        if platform=='Linux':
            launcher=folder/'launch-conquest.sh';launcher.write_text('#!/bin/sh\nset -eu\nclient_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nif [ "$#" -gt 0 ]; then config=$(realpath -- "$1"); shift; set -- "$config" "$@"; fi\nexec "$client_dir/FPSloppaCQ.x86_64" --rendering-method mobile --rendering-driver vulkan -- "$@"\n');launcher.chmod(0o755)
        else:(folder/'launch-conquest.bat').write_text('@echo off\r\nif "%~1"=="" (\r\n  "%~dp0FPSloppaCQ.exe" --rendering-method mobile --rendering-driver vulkan\r\n) else (\r\n  "%~dp0FPSloppaCQ.exe" --rendering-method mobile --rendering-driver vulkan -- "%~f1"\r\n)\r\n')
    report=dict(version=version,resources=len(selected),maps=sum(p.endswith('/presentation.scn') for p in selected),pack_bytes=pack.stat().st_size,pack_sha256=hashlib.file_digest(pack.open('rb'),'sha256').hexdigest(),files=sorted(selected))
    (output/'client-build.json').write_text(json.dumps(report,indent=2)+'\n');print('CQ_CLIENTS_BUILT',report['maps'],report['pack_bytes'])
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'Builds/CQRelease');p.add_argument('--templates',type=Path,default=Path.home()/'.local/share/godot/export_templates/4.7.2.stable');p.add_argument('--godot',default='godot');a=p.parse_args();build(a.output,a.templates,a.godot)
