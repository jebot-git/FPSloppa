"""Translate selected UT99 world meshes, UVs and actor properties into reviewable artifacts.
No source code is executed. Unmapped gameplay/lighting dependencies block installation.
"""
from pathlib import Path
import json,struct,hashlib,gzip,zipfile,io,re,collections,concurrent.futures
from package import Package,Reader
HERE=Path(__file__).resolve().parent;LOCAL=HERE/'local'
def members(data,depth=0):
 if depth>3:raise ValueError("Nested archive depth limit exceeded")
 if len(data)>20 and struct.unpack_from('<I',data,len(data)-20)[0]==0x9fe3c5a3:
  _,at,total,version,crc=struct.unpack_from('<5I',data,len(data)-20)
  if total!=len(data) or version!=1:raise ValueError('Invalid UMOD header')
  r=Reader(data,at);out={}
  for _ in range(r.count()):
   name=r.string();off,size,flags=r.unpack('3i')
   if off<0 or size<0 or off+size>at:raise ValueError('Invalid UMOD file range')
   out[name.replace('\\','/')]=data[off:off+size]
  return out
 out={};total=0
 if zipfile.is_zipfile(io.BytesIO(data)):
  with zipfile.ZipFile(io.BytesIO(data)) as z:
   for e in z.infolist():
    total+=e.file_size
    if total>512*1024*1024:raise ValueError('Archive expansion exceeds 512 MB')
    if not e.is_dir():out[e.filename]=z.read(e)
 else:
  import libarchive
  with libarchive.memory_reader(data) as archive:
   for e in archive:
    total+=e.size
    if total>512*1024*1024:raise ValueError('Archive expansion exceeds 512 MB')
    if e.isfile:out[e.pathname]=b''.join(e.get_blocks())
 for n,b in list(out.items()):
  if n.lower().endswith(('.umod','.zip')):out.update(members(b,depth+1))
 return out

def convert(row):
 result={k:row[k] for k in ['name','mode','players','declared_capacity','page','archive','archive_sha1']};key=row['archive_sha1'][:12];folder=LOCAL/'converted'/key;folder.mkdir(parents=True,exist_ok=True)
 try:
  raw=(LOCAL/'archives'/row['archive_sha1']).read_bytes()
  if hashlib.sha1(raw).hexdigest()!=row['archive_sha1']:raise ValueError('Archive hash mismatch')
  files=members(raw);maps=[n for n in files if n.lower().endswith('.unr')];matching=[n for n in maps if Path(n).stem.casefold()==row['name'].casefold()]
  if not matching and len(maps)==1:matching=maps
  if len(matching)!=1:raise ValueError('Cannot unambiguously select requested map: '+repr(maps))
  member=matching[0];p=Package(files[member]);level=next(e for e in p.exports if p.obj(e['cls'])['name']=='Level');_,r=p.props(level);count,maxcount=r.unpack('2i')
  if not 0<=count<=100000:raise ValueError('Invalid level actor count')
  refs=[r.ci() for _ in range(count)]
  for _ in range(4):r.string()
  for _ in range(r.count()):r.string()
  r.take(8);world=r.ci();model=p.model(p.obj(world))
  if not model['polygons']:raise ValueError('Empty world geometry')
  actors=[];errors=[]
  for ref in refs:
   if ref<=0:continue
   e=p.obj(ref);cls=p.path(e['cls'])
   try:
    props,rr=p.props(e);actors.append(dict(name=e['name'],class_path=cls,properties=props))
   except Exception as ex:errors.append(dict(name=e['name'],class_path=cls,error=str(ex)))
  textures=sorted({face['texture'] for face in model['polygons']});supplied={Path(n).stem.casefold() for n in files if n.lower().endswith(('.utx','.u'))};missing=sorted({t.split('.')[0] for t in textures if '.' in t and t.split('.')[0].casefold() not in supplied})
  with gzip.open(folder/'world.obj.gz','wt') as f:
   f.write('# UT99 source world mesh; geometry review only, no simulated objectives or fake lightmaps.\n');vertex=1
   for face in model['polygons']:
    # UE Z-up -> Godot Y-up, reflect Y and reverse winding. UVs remain texel-space.
    for x,y,z in face['points']:f.write('v %.7g %.7g %.7g\n'%(x*.0254,z*.0254,-y*.0254))
    for u,v in face['uv_texels']:f.write('vt %.7g %.7g\n'%(u,v))
    f.write('usemtl '+re.sub('[^A-Za-z0-9_.-]','_',face['texture'])+'\n')
    f.write('f '+' '.join(f'{i}/{i}' for i in reversed(range(vertex,vertex+len(face['points']))))+'\n');vertex+=len(face['points'])
  with gzip.open(folder/'world.json.gz','wt') as f:json.dump(model,f)
  (folder/'actors.json').write_text(json.dumps(actors,indent=2)+'\n')
  classes=collections.Counter(a['class_path'].split('.')[-1] for a in actors)
  interesting=[a for a in actors if any(t in a['class_path'].lower() for t in ['fortstandard','hill','koth','controlpoint'])]
  (folder/'objectives.json').write_text(json.dumps(interesting,indent=2)+'\n')
  reasons=['UE1 light visibility data requires a real lighting rebuild; no validated Godot bake yet','Imported geometry has no validated runtime collision, spawns or bot navigation yet']
  if missing:reasons.append('Missing texture packages: '+', '.join(missing))
  if classes.get('Mover',0):reasons.append(str(classes['Mover'])+' moving brushes require transformation/trigger conversion')
  if row['mode']=='as':reasons.append('FortStandard damage/touch/trigger chains and attacker/defender respawn changes require an AS adapter')
  else:reasons.append('ChaosUT hill actor semantics require a KOTH adapter')
  if errors:reasons.append(str(len(errors))+' actor property parse failures')
  result.update(status='geometry_converted_held',member=member,package_version=p.version,source_sha256=hashlib.sha256(files[member]).hexdigest(),world_polygons=len(model['polygons']),world_points=model['points'],texture_count=len(textures),missing_texture_packages=missing,actor_classes=dict(classes),actor_parse_errors=errors,objective_actors=len(interesting),player_starts=classes.get('PlayerStart',0),artifacts=str(folder.relative_to(HERE)),blockers=reasons)
 except Exception as e:result.update(status='unsupported',error=str(e))
 (folder/'attempt.json').write_text(json.dumps(result,indent=2)+'\n');print(row['name'],result['status'],result.get('error',''),flush=True);return result

def main():
 rows=json.loads((HERE/'downloads.json').read_text());result=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  for row in pool.map(convert,rows):result.append(row);(HERE/'attempts.tmp').write_text(json.dumps(result,indent=2)+'\n');(HERE/'attempts.tmp').replace(HERE/'attempts.json')
 print(collections.Counter(r['status'] for r in result),flush=True)
if __name__=='__main__':main()
