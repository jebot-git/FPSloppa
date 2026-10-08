"""Bounded UE1 (UT99 version 62–69) package/actor/world geometry reader.
Format reference: dpjudas/SurrealEngine UModel::Load and PropertyData::Load.
No UnrealScript or package native code is loaded or executed.
"""
import math,struct
class Reader:
 def __init__(self,data,pos=0):self.data=data;self.pos=pos
 def take(self,n):
  if n<0 or self.pos+n>len(self.data):raise ValueError('Truncated package at '+str(self.pos))
  b=self.data[self.pos:self.pos+n];self.pos+=n;return b
 def unpack(self,f):return struct.unpack('<'+f,self.take(struct.calcsize('<'+f)))
 def num(self,f):return self.unpack(f)[0]
 def ci(self):
  b=self.num('B');neg=b&128;v=b&63;more=b&64
  for i in range(1,5):
   if not more:break
   b=self.num('B');v|=(b&(255 if i==4 else 127))<<(6+7*(i-1));more=b&128
  return -v if neg else v
 def count(self):
  n=self.ci()
  if not 0<=n<=2000000:raise ValueError('Invalid array count '+str(n))
  return n
 def string(self):
  n=self.ci()
  if abs(n)>65536:raise ValueError('Oversized string')
  return self.take(abs(n)*(2 if n<0 else 1)).decode('utf-16-le' if n<0 else 'cp1252',errors='replace').rstrip('\0')
 def vec(self):
  v=self.unpack('3f')
  if not all(math.isfinite(x) and abs(x)<1e9 for x in v):raise ValueError('Invalid vector')
  return v
class Package:
 def __init__(self,data):
  self.data=data;r=Reader(data)
  magic,self.version,license,flags,nc,no,ec,eo,ic,io=r.unpack('IHHI6i')
  if magic!=0x9e2a83c1 or not 61<=self.version<=69:raise ValueError('Unsupported UE package magic/version')
  if any(not 0<=n<=2000000 for n in (nc,ec,ic)):raise ValueError('Invalid table counts')
  self.names=[];r=Reader(data,no)
  for _ in range(nc):
   if self.version>=64:name=r.string()
   else:
    end=data.find(b'\0',r.pos,r.pos+65536)
    if end<0:raise ValueError('Unterminated legacy name')
    name=r.take(end-r.pos+1)[:-1].decode('cp1252',errors='replace')
   self.names.append(name);r.take(4)
  self.imports=[];r=Reader(data,io)
  for _ in range(ic):self.imports.append(dict(package=self.name(r.ci()),cls=self.name(r.ci()),outer=r.num('i'),name=self.name(r.ci())))
  self.exports=[];r=Reader(data,eo)
  for _ in range(ec):
   e=dict(cls=r.ci(),super=r.ci(),outer=r.num('i'),name=self.name(r.ci()),flags=r.num('I'),size=r.ci());e['offset']=r.ci() if e['size'] else 0
   if e['size']<0 or e['offset']<0 or e['offset']+e['size']>len(data):raise ValueError('Export outside package')
   self.exports.append(e)
 def name(self,i):
  if not 0<=i<len(self.names):raise ValueError('Invalid name index '+str(i))
  return self.names[i]
 def obj(self,i):
  if i==0:return dict(name='None',outer=0)
  table=self.exports if i>0 else self.imports;j=i-1 if i>0 else -i-1
  if not 0<=j<len(table):raise ValueError('Invalid object index')
  return table[j]
 def path(self,i):
  names=[];seen=set()
  while i:
   if i in seen:raise ValueError('Cyclic object path')
   seen.add(i);e=self.obj(i);names.append(e['name']);i=e['outer']
  return '.'.join(reversed(names))
 def reader(self,e):return Reader(self.data[e['offset']:e['offset']+e['size']])
 def props(self,e):
  r=self.reader(e)
  if e['flags']&0x02000000:
   node=r.ci();r.ci();r.take(12)
   if node:r.ci()
  props={}
  for _ in range(65536):
   name=self.name(r.ci())
   if name=='None':return props,r
   info=r.num('B');typ=info&15;sub=self.name(r.ci()) if typ==10 else None;sz=(info>>4)&7
   size=[1,2,4,12,16][sz] if sz<5 else r.num(['B','H','I'][sz-5])
   idx=0
   if info&128 and typ!=3:
    b=r.num('B')
    if b<128:idx=b
    elif b<192:idx=((b&127)<<8)+r.num('B')
    else:idx=((b&63)<<24)+(r.num('B')<<16)+(r.num('B')<<8)+r.num('B')
   if typ==3:value=bool(info&128)
   else:
    raw=r.take(size);v=Reader(raw);value={'raw':raw.hex(),'type':typ,'struct':sub}
    if typ==1 and size==1:value=v.num('B')
    elif typ==2 and size==4:value=v.num('i')
    elif typ==4 and size==4:value=v.num('f')
    elif typ in (5,8):value={'object':v.ci()}
    elif typ==6:value=self.name(v.ci())
    elif typ in (10,11) and (sub=='Vector' or typ==11) and size==12:value=v.vec()
    elif typ in (10,12) and (sub=='Rotator' or typ==12) and size==12:value=v.unpack('3i')
    elif typ==13:value=v.string()
   props[name if idx==0 else name+'['+str(idx)+']']=value
  raise ValueError('Unterminated property stream')
 def model(self,e):
  if self.version<=61:raise ValueError("Legacy model subobjects require separate decoder")
  props,r=self.props(e);bounds=(r.vec(),r.vec(),r.num('B'));sphere=(*r.vec(),r.num('f'))
  vectors=[r.vec() for _ in range(r.count())];points=[r.vec() for _ in range(r.count())];nodes=[]
  for _ in range(r.count()):
   plane=r.unpack('4f');mask=r.num('Q');flags=r.num('B');indices=[r.ci() for _ in range(9)];nv=r.num('B');leaves=r.unpack('2i');nodes.append(dict(plane=plane,flags=flags,pool=indices[0],surface=indices[1],vertices=nv))
  surfaces=[]
  for _ in range(r.count()):
   texture=r.ci();flags=r.num('I');idx=[r.ci() for _ in range(6)];pan=r.unpack('2h');actor=r.ci();surfaces.append(dict(texture=self.path(texture),flags=flags,base=idx[0],normal=idx[1],u=idx[2],v=idx[3],lightmap=idx[4],pan=pan))
  verts=[(r.ci(),r.ci()) for _ in range(r.count())];polys=[]
  r.take(4);zones=r.num('i')
  if not 0<=zones<=64:raise ValueError('Invalid zone count')
  for _ in range(zones):r.ci();r.take(16)
  brush_ref=r.ci()
  for n in nodes:
   if n['vertices']<3:continue
   s=surfaces[n['surface']]
   if s['flags']&1:continue # invisible portal/collision-only surface
   if n['pool']<0 or n['pool']+n['vertices']>len(verts):raise ValueError('Vertex pool outside model')
   ps=[points[verts[n['pool']+i][0]] for i in range(n['vertices'])];base=points[s['base']];u=vectors[s['u']];v=vectors[s['v']]
   uv=[(sum((p[j]-base[j])*u[j] for j in range(3))+s['pan'][0],sum((p[j]-base[j])*v[j] for j in range(3))+s['pan'][1]) for p in ps]
   polys.append(dict(points=ps,uv_texels=uv,normal=vectors[s['normal']],texture=s['texture'],flags=s['flags'],lightmap=s['lightmap']))
  return dict(bounds=bounds,nodes=len(nodes),surfaces=len(surfaces),points=len(points),polygons=polys,brush_ref=brush_ref)

 def brush_polygons(self,model_ref):
  model=self.model(self.obj(model_ref));ref=model['brush_ref']
  if ref<=0:return model['polygons']
  _,r=self.props(self.obj(ref));count,maximum=r.unpack('2i');result=[]
  if not 0<=count<=100000:raise ValueError('Invalid brush polygon count')
  for _ in range(count):
   nv=r.count();base=r.vec();normal=r.vec();u=r.vec();v=r.vec();points=[r.vec() for _ in range(nv)]
   flags=r.num('I');r.ci();tex=r.ci();r.ci();r.ci();r.ci();pan=r.unpack('2h')
   uv=[(sum((p[j]-base[j])*u[j] for j in range(3))+pan[0],sum((p[j]-base[j])*v[j] for j in range(3))+pan[1]) for p in points]
   result.append(dict(points=points,normal=normal,uv_texels=uv,texture=self.path(tex),flags=flags))
  return result
