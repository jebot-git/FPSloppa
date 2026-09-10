"""Read pinned AD ZIP/PAK content without executing mod code or unsafe extraction."""
from pathlib import Path,PurePosixPath
import gzip,struct,zipfile

def entries(path):
 result={}
 with zipfile.ZipFile(path) as archive:
  for info in sorted(archive.infolist(),key=lambda i:i.filename):
   if info.file_size>900_000_000:raise ValueError('Oversized archive entry')
   name=info.filename
   if PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts:raise ValueError('Unsafe path')
   data=archive.read(info)
   if name.endswith('.pak'):
    if data[:4]!=b'PACK':raise ValueError('Invalid PAK')
    offset,length=struct.unpack_from('<II',data,4)
    if length%64 or offset+length>len(data):raise ValueError('Invalid PAK directory')
    for at in range(offset,offset+length,64):
     item=data[at:at+56].split(b'\0')[0].decode('ascii');start,size=struct.unpack_from('<II',data,at+56)
     if start+size>len(data) or size>150_000_000:raise ValueError('Invalid PAK entry')
     if PurePosixPath(item).is_absolute() or '..' in PurePosixPath(item).parts:raise ValueError('Unsafe PAK path')
     result[item]=data[start:start+size]
   else:result[name]=data
 for name in list(result):
  if name.endswith('.bsp.gz'):
   raw=gzip.decompress(result.pop(name))
   if len(raw)>150_000_000:raise ValueError('Oversized BSP')
   result[name[:-3]]=raw
 return result
if __name__=='__main__':
 import sys,collections,re
 content=entries(Path(sys.argv[1]));out=Path(sys.argv[1]).parent/'source';out.mkdir(exist_ok=True)
 for name,data in content.items():
  if name.endswith('.txt') and not name.startswith(('sound/','progs/')):
   dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  if name.startswith('maps/') and name.count('/')==1 and name.endswith('.bsp'):
   off,size=struct.unpack_from('<II',data,4);entities=data[off:off+size].decode('latin1');classes=collections.Counter(re.findall(r'"classname"\s*"([^"]+)"',entities))
   print(Path(name).stem,len(data),data[:4],classes.get('info_player_deathmatch',0),classes.most_common(5))
 print('other map entries',[(n,len(d)) for n,d in content.items() if n.startswith('maps/') and n.count('/')==1 and not n.endswith(('.bsp','.lit'))][:40])
