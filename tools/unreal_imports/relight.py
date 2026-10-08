"""Refresh UT-adapted light falloff and remove unused Quake PVS data."""
from build_candidate import *
sys.path.insert(0,str(ROOT/'tools/arena_imports'));from build import unpack,pack
import re
for folder in sorted((LOCAL/'candidates').iterdir()):
 name=folder.name;p=folder/(name+'.map')
 if not p.exists():continue
 text=p.read_text().replace('"_minlight" "24"','"_minlight" "64"')
 # Existing prototype lights were 2x UT brightness. Preserve source colour.
 text=re.sub(r'"light" "([0-9.]+)"',lambda m:'"light" "'+str(max(160,float(m[1])*2))+'"\n"wait" "0.2"',text)
 p.write_text(text)
 for stage,args in [('qbsp',['-onlyents']),('light',['-extra','-bspxlit','-threads','2'])]:
  with (folder/('relight-'+stage+'.log')).open('w') as log:
   run=subprocess.run([str(COMPILER/stage),*args,str(folder/(name+('.map' if stage=='qbsp' else '.bsp')))],cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=300)
   if run.returncode:raise RuntimeError(name+' '+stage)
 bsp=folder/(name+'.bsp');data=bsp.read_bytes();parts,extra=unpack(data);parts[4]=b'';leaves=bytearray(parts[10])
 for offset in range(4,len(leaves),28):struct.pack_into('<i',leaves,offset,-1)
 parts[10]=bytes(leaves);bsp.write_bytes(pack(parts,extra,data[:4]));print(name,'relit',bsp.stat().st_size,flush=True)
