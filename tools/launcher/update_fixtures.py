from pathlib import Path
import hashlib,json,zipfile,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from launcher.package_manifest import write_wrapper
base=Path('/tmp/fpsloppa-update-tests');base.mkdir(exist_ok=True)
def digest(b):return hashlib.sha256(b).hexdigest()
def manifest(files,version):return dict(schema=1,repository='jebot-git/FPSloppa',version=version,platform='Linux',files=[dict(path=n,bytes=len(b),sha256=digest(b),mode=493 if n.endswith('.x86_64') else 420) for n,b in files.items()])
old={'FPSloppa.x86_64':b'old exe','FPSloppa.pck':b'old pack','old-library.so':b'obsolete','maps/base.bsp':b'base','maps/edited.bsp':b'original','vrm/base.vrm':b'avatar'}
new={'FPSloppa.x86_64':b'new exe','FPSloppa.pck':b'new pack','maps/base.bsp':b'new base','maps/edited.bsp':b'new official','vrm/base.vrm':b'new avatar','maps/local.bsp':b'new collision','new-library.so':b'new library'}
for case in ['success','rollback','recovery','unsafe','checksum','modified','symlink','http']:
 root=base/case
 import shutil
 if root.exists():shutil.rmtree(root)
 root.mkdir(exist_ok=True)
 for n,b in old.items():
  path=root/n;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b)
 (root/'maps/edited.bsp').write_bytes(b'custom map');(root/'maps/local.bsp').write_bytes(b'custom collision')
 (root/'bgm').mkdir(exist_ok=True);(root/'bgm/global.m3u8').write_text('my song.ogg\n');(root/'client.cfg').write_text('my settings')
 (root/'INSTALL-MANIFEST.json').write_text(json.dumps(manifest(old,'0.21v')))
 work=root/'.launcher-update';work.mkdir(exist_ok=True)
 with zipfile.ZipFile(work/'download.zip','w') as z:
  for n,b in new.items():z.writestr('FPSloppa-Linux/'+n,b)
  z.writestr('FPSloppa-Linux/INSTALL-MANIFEST.json',json.dumps(manifest(new,'0.22v')))
  if case=='unsafe':z.writestr('FPSloppa-Linux/../escape',b'bad')
 release=dict(version='0.22v',bytes=(work/'download.zip').stat().st_size,sha256=digest((work/'download.zip').read_bytes()))
 (root/'release.json').write_text(json.dumps(release))
 if case=='checksum':release['sha256']='0'*64;(root/'release.json').write_text(json.dumps(release))
 if case=='modified':(root/'FPSloppa.pck').write_bytes(b'my pack')
 if case=='symlink':(root/'maps/base.bsp').unlink();(root/'maps/base.bsp').symlink_to(root/'maps/edited.bsp')
write_wrapper(base,'Linux');write_wrapper(base,'Windows')
print(base)
