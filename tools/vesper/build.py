"""Build Vesper Abbey: original CC0 TF geometry with original Makkon artwork."""
from pathlib import Path
import argparse,hashlib,json,math,re,struct,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from generate_tf_maps import Arena
ID='tf_vesper';OUT=ROOT/'maps/VesperAbbey'
GOTHIC_SHA='2ab3bd9b505f87862c03453894a6ac529be7e5db1ca8fc79d6d64cc21df92789'
STONE='grk_ebrick23';FLOOR='med_dbrick6';WALL='stn_gw02_gry1';TRIM='stn_gt01_gry1';IRON='metal_iron1_01'
def sha(b):return hashlib.sha256(b).hexdigest()
class Abbey(Arena):
 def __init__(self):
  super().__init__(ID,'Vesper Abbey | TF 6v6',2048,1280,1024);self.detail=[];self.models=[]
 def face(self,points,texture):
  scale=.5 if texture.startswith('metal_') else 1
  base=super().face(points,texture)
  if texture.startswith('stn_gr'):
   # Fit each rose panel to its own face instead of slicing it at world origin.
   span=[max(p[j] for p in points)-min(p[j] for p in points) for j in range(3)]
   normal=min(range(3),key=lambda j:span[j]);u=1 if normal==0 else 0;v=1 if normal==2 else 2
   us=max(span[u],1)/512;vs=max(span[v],1)/512
   return base.rsplit(' ',5)[0]+f' {-min(p[u] for p in points)/us:g} {max(p[v] for p in points)/vs:g} 0 {us:g} {vs:g}'
  return base.rsplit(' ',2)[0]+f' {scale:g} {scale:g}' 
 def model(self,fields,start):
  self.models.append((fields,self.brushes[start:]));del self.brushes[start:]
 def decorate(self,start):self.detail+=self.brushes[start:];del self.brushes[start:]
def polygon(a,ring,bottom,top,texture,axis='z'):
 def p(u,v,w):return (w,u,v) if axis=='x' else (u,v,w)
 low=[p(u,v,bottom) for u,v in ring];high=[p(u,v,top) for u,v in ring]
 faces=[list(reversed(low[:3])),high[:3]]
 faces += [[low[i],low[(i+1)%len(ring)],high[(i+1)%len(ring)]] for i in range(len(ring))]
 a.brushes.append('{\n'+'\n'.join(a.face(f,texture) for f in faces)+'\n}')
def arch(a,x0,x1,y,width,spring,peak,top,z=0,texture=WALL):
 # Fill above a pointed opening with convex wedges, never an invisible blocker.
 r=width/2;profile=[(-r,spring),(-r*.65,spring+(peak-spring)*.62),(0,peak),(r*.65,spring+(peak-spring)*.62),(r,spring)]
 for (u,v),(U,V) in zip(profile,profile[1:]):polygon(a,[(y+u,z+v),(y+U,z+V),(y+U,z+top),(y+u,z+top)],x0,x1,texture,'x')
def column(a,x,y,r,z0,z1,texture):
 polygon(a,[(x+round(r*math.cos(i*math.pi/4)),y+round(r*math.sin(i*math.pi/4))) for i in range(8)],z0,z1,texture)
def spire(a,x,y,r,z0,z1):
 ring=[(x+round(r*math.cos(i*math.pi/4)),y+round(r*math.sin(i*math.pi/4))) for i in range(8)]
 low=[(*p,z0) for p in ring];high=[(x+(u-x)*.06,y+(v-y)*.06,z1) for u,v in ring]
 faces=[list(reversed(low[:3])),high[:3]]+[[low[i],low[(i+1)%8],high[(i+1)%8]] for i in range(8)]
 a.brushes.append('{\n'+'\n'.join(a.face(f,'stn_gc02_gry1') for f in faces)+'\n}')
def generate():
 a=Abbey()
 a.box((-2048,-1280,-320),(2048,1280,0),FLOOR)
 for p,q in [((-2080,-1312,-320),(-2048,1312,1024)),((2048,-1312,-320),(2080,1312,1024)),((-2048,-1312,-320),(2048,-1280,1024)),((-2048,1280,-320),(2048,1312,1024))]:a.box(p,(q[0],q[1],512),STONE);a.box((p[0],p[1],512),q,'sky_star')
 a.box((-2080,-1312,1024),(2080,1312,1056),'sky_star')
 # A broken cruciform nave splits the centre into dog-leg crossings and cloisters.
 a.box((-112,-416,0),(112,416,256),STONE)
 a.box((-160,-160,256),(160,160,368),'stn_gr02_gry1')
 for side in [-1,1]:
  def pos(p):return (p[0]*side,p[1]*side,p[2])
  def box(p,q,t=STONE):
   p,q=pos(p),pos(q);a.box(tuple(min(v,w) for v,w in zip(p,q)),tuple(max(v,w) for v,w in zip(p,q)),t)
  def arco(x0,x1,y,width,spring,peak,top,z=0,t=WALL):
   first=len(a.brushes);arch(a,x0,x1,y,width,spring,peak,top,z,t)
   if side<0:
    for i in range(first,len(a.brushes)):
     a.brushes[i]=re.sub(r'\( ([^()]+) \)',lambda m:'( %g %g %g )'%tuple(float(v)*(-1 if j<2 else 1) for j,v in enumerate(m.group(1).split())),a.brushes[i])
  color='red1' if side<0 else 'blu1';accent='stn_gw10_'+color;rose='stn_gr01_'+color
  # Nave arcades have real pointed openings and broad protected side lanes.
  box((384,-576,0),(448,-192,512),WALL)
  box((384,192,0),(448,576,512),WALL)
  arco(384,448,0,384,224,400,512)
  box((448,544,0),(896,608,384),WALL)
  box((448,-608,0),(896,-544,384),WALL)
  # Lower cloister: offset tombs interrupt the long perimeter sightline.
  box((96,800,0),(352,992,96),'med_cobstn1_2a')
  box((416,848,0),(608,1024,128),STONE)
  box((224,-1056,0),(416,-880,128),STONE)
  # Three base portals: centre nave and two outer cloisters.
  for y0,y1 in [(-1280,-1088),(-768,-160),(160,768),(1088,1280)]:box((896,y0,0),(960,y1,512),WALL)
  for y,width in [(-928,320),(0,320),(928,320)]:arco(896,960,y,width,224,400,512)
  # Sanctuary at 8 m. Ramp and the two lifts arrive from different directions.
  box((1536,-640,224),(2048,128,256),FLOOR)
  box((1792,128,224),(1984,256,256),FLOOR)
  box((1472,-544,224),(1536,-352,256),FLOOR)
  # Ramp winds along the south cloister and joins a generous upper landing.
  if side>0:a.ramp_x(1024,1792,-992,-736,0,256,FLOOR)
  else:a.ramp_x(-1792,-1024,736,992,256,0,FLOOR)
  box((1792,-992,224),(2048,-640,256),FLOOR)
  # Sanctuary back wall and screen protect flag from direct nave fire.
  box((1728,-128,256),(1760,128,512),WALL)
  box((1536,-640,256),(1760,-608,512),WALL)
  box((2016,-640,256),(2048,128,768),WALL)
  box((1536,96,256),(1792,128,512),WALL)
  # Vault roof has a raised centre and repeated pointed cross arches.
  box((1536,-640,640),(2048,128,672),'stn_gc01_gry1')
  # Spawn chapterhouse: two screened exits and rear resupply.
  box((1568,672,0),(1600,928,288),WALL)
  box((1792,544,0),(1952,576,160),STONE)
  box((1792,1120,0),(1952,1152,160),STONE)
  box((1568,512,288),(2048,1280,320),'stn_gc01_gry1')
  # Capture altar downstairs, separated from the upper enemy flag target.
  box((1056,288,0),(1216,448,4),accent)
  box((1792,-384,256),(1952,-224,260),accent)
  a.team(side,pos((1872,-304,284)),[pos((x,y,24)) for x in (1664,1776,1888,1984) for y in (736,992)],pos((1984,864,24)),pos((1136,368,28)))
  a.ent('item_health',pos((704,1040,24)));a.ent('item_shells',pos((704,-1040,24)))
  # Well6-style trigger-operated, tall door brushes form four solid lift pistons.
  for n,(x,y) in enumerate([(1280,-544),(1792,256)]):
   target=('red' if side<0 else 'blue')+'_bell_lift_'+str(n+1)
   start=len(a.brushes);box((x,y,-270),(x+192,y+192,2),IRON)
   a.model({'classname':'func_door','targetname':target,'angle':'-1','lip':'16','speed':'128','wait':'3','sounds':'1','dmg':'0'},start)
   start=len(a.brushes);box((x+16,y+16,2),(x+176,y+176,74),'trigger')
   a.model({'classname':'trigger_multiple','target':target,'wait':'8'},start)
   # The top call pad is on the fixed landing; it can summon a lowered lift.
   start=len(a.brushes)
   if n==0:box((1472,-528,256),(1528,-368,328),'trigger')
   else:box((1808,176,256),(1968,248,328),'trigger')
   a.model({'classname':'trigger_multiple','target':target,'wait':'8'},start)
   # Four slim guide pillars leave every boarding edge open.
   d=len(a.brushes)
   for dx in (-24,192):
    for dy in (-24,192):box((x+dx,y+dy,0),(x+dx+24,y+dy+24,640),'stn_gs01_gry1')
   box((x-32,y-32,608),(x+224,y+224,640),TRIM)
   column(a,(x+96)*side,(y+96)*side,64,640,720,'metal_brnz_01')
   spire(a,(x+96)*side,(y+96)*side,112,720,944)
   a.decorate(d)
   a.ent('light',pos((x+96,y+96,400)),light=320,_color='1 .72 .45')
  # Gothic ornament follows architectural bays, keeping plain stone underfoot.
  d=len(a.brushes)
  # Lower crenellated enclosure lets the spires read against the sky.
  box((-2048,1248,480),(2048,1280,512),TRIM)
  for x in range(-1984,2048,192):box((x,1248,512),(x+80,1280,576),STONE)
  # A pitched nave roof rests on the arcade walls, with the middle left ruined.
  for ring in [[(-576,512),(0,736),(0,768),(-576,544)],[(0,736),(576,512),(576,544),(0,768)]]:
   first=len(a.brushes);polygon(a,ring,448,896,'stn_gc01_gry1','x')
   if side<0:
    a.brushes[first]=re.sub(r'\( ([^()]+) \)',lambda m:'( %g %g %g )'%tuple(float(v)*(-1 if j<2 else 1) for j,v in enumerate(m.group(1).split())),a.brushes[first])
  for x in (400,912):
   for y in (-576,576):
    box((x-48,y-48,0),(x+80,y+48,48),STONE)
    column(a,x*side,y*side,40,48,608,'stn_gs01_gry1')
    spire(a,x*side,y*side,64,608,832)
  # Tall coloured rose panels mark each base from the central crossing.
  box((880,192,256),(896,704,768),rose)
  box((960,224,0),(992,736,512),accent)
  # Carved stone caskets and caps make lower lane cover legible.
  box((80,784,96),(368,1008,112),TRIM)
  box((400,832,128),(624,1040,144),TRIM)
  for x in (1152,1536,1920):
   box((x,-1280,0),(x+64,-1232,640),'stn_gs01_gry1')
   spire(a,(x+32)*side,-1256*side,56,640,832)
  # The flag rose sits behind the altar, framed by matching buttresses.
  box((2008,-608,256),(2016,-96,768),rose)
  a.decorate(d)
  for x,y,z,power in [(688,0,304,300),(688,944,256,240),(1136,352,304,350),(1824,-384,544,370),(1792,880,224,350),(1440,-864,448,280),(1680,-144,144,220)]:
   a.ent('light',pos((x,y,z)),light=power,_color='1 .78 .6' if side<0 else '.64 .78 1')
 a.ent('info_player_start',(-1776,-736,24),angle=0)
 for y in [-736,736]:a.ent('light',(0,y,320),light=300,_color='.75 .85 1')
 return a

def records(data):
 assert data[:4]==b'WAD2';count,offset=struct.unpack_from('<ii',data,4);out={}
 for i in range(count):
  at,size,_,kind,compressed,_,key=struct.unpack_from('<iiiBBH16s',data,offset+32*i)
  if kind not in (67,68):continue
  assert not compressed and at>=12 and at+size<=len(data)
  raw=data[at:at+size];w,h=struct.unpack_from('<II',raw,16);assert size==40+w*h*85//64
  out[key.split(b'\0')[0].decode().lower()]=raw
 return out

def materials(names):
 textures={};sources={}
 for folder,wad in [(OUT,'vesper.wad'),(ROOT/'maps/Pressureworks','pressureworks.wad')]:
  if not (folder/wad).exists():continue
  known=json.loads((folder/'texture-sources.json').read_text())
  for name,raw in records((folder/wad).read_bytes()).items():
   if name in names and name in known and sha(raw)==known[name]['sha256']:textures[name]=raw;sources[name]=known[name]
 if names<=textures.keys():return textures,sources
 for path,expected,source,license in [
  (ROOT/'tools/vesper/local/makkon_gothic_stone.zip',GOTHIC_SHA,'https://www.slipseer.com/resources/makkon-textures.28/','Makkon_License.txt; existing FPSloppa project permission'),
  (ROOT/'tools/makkon/local/makkon_metal.zip','c0eca6be6984e29a8ac1615c05bbc98409b3bed52a230dc43fc91a4bb3698a85','https://www.slipseer.com/resources/makkon-textures.28/','Makkon_License.txt; existing FPSloppa project permission'),
  (ROOT/'tools/pressureworks/local/librequake-dev.zip',None,'https://github.com/lavenderdotpet/LibreQuake','BSD-3-Clause')]:
  raw=path.read_bytes();archive_sha=sha(raw)
  if expected:assert archive_sha==expected,'Source archive hash mismatch'
  with zipfile.ZipFile(path) as z:
   for member in z.namelist():
    if not member.lower().endswith('.wad'):continue
    data=z.read(member)
    for name,record in records(data).items():
     if name not in names or name in textures:continue
     textures[name]=record;sources[name]={'source':source,'archive':path.name,'archive_sha256':archive_sha,'wad':member,'wad_sha256':sha(data),'sha256':sha(record),'license':license,'format':'original WAD2 miptex; all four mip levels unchanged'}
  if names<=textures.keys():break
 assert names<=textures.keys(),names-textures.keys()
 return textures,sources

def main():
 p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--threads',type=int,default=8);args=p.parse_args()
 OUT.mkdir(parents=True,exist_ok=True);logs=ROOT/'test-results/vesper';logs.mkdir(parents=True,exist_ok=True)
 a=generate()
 def ent(d):return '\n'.join('"%s" "%s"'%v for v in d.items())
 world={'classname':'worldspawn','message':a.title,'wad':'vesper.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_minlight':'32','_sunlight':'100','_sunlight2':'32','_sun_mangle':'35 -65 0','_bounce':'1','worldtype':'0'}
 source='{\n'+ent(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'
 source+='{\n"classname" "func_detail"\n'+'\n'.join(a.detail)+'\n}\n'
 source+='\n'.join('{\n'+ent(fields)+'\n'+'\n'.join(brushes)+'\n}' for fields,brushes in a.models)+'\n'
 source+='\n'.join('{\n'+ent(e)+'\n}' for e in a.entities)+'\n'
 names=set(re.findall(r'\) (\S+) [-\d.e+]+ [-\d.e+]+ 0 [\d.e+]+ [\d.e+]+',source))-{'trigger'}
 donors,provenance=materials(names)
 wad=bytearray(b'WAD2'+bytes(8));directory=[]
 for name in sorted(names):
  raw=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
 at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
 (OUT/'vesper.wad').write_bytes(wad);(OUT/'texture-sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
 (OUT/(ID+'.map')).write_text('// Original CC0 geometry. Texture artwork has separate licences.\n'+source)
 for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','CC0-1.0.txt']:(OUT/name).write_bytes((ROOT/'maps/Pressureworks'/name).read_bytes())
 bsp=ROOT/'maps'/f'{ID}.bsp'
 for exe,flags in [('qbsp',[str(OUT/(ID+'.map')),str(bsp)]),('vis',['-threads',str(args.threads),str(bsp)]),('light',['-threads',str(args.threads),'-extra','-bspxlit',str(bsp)])]:
  with (logs/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler.resolve()/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
 assert not bsp.with_suffix('.pts').exists(),'Map leaked'
 data=bsp.read_bytes();assert struct.unpack_from('<i',data)[0]==29 and len(data)<30_000_000
 texture_at,_=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,texture_at)[0];audit=[]
 for i in range(count):
  offset=struct.unpack_from('<i',data,texture_at+4+i*4)[0]
  if offset<0:continue
  at=texture_at+offset;name=data[at:at+16].split(b'\0')[0].decode()
  if name=='trigger':continue
  assert name in donors and data[at:at+len(donors[name])]==donors[name],name
  audit.append({'texture':name,'unchanged':True,'sha256':sha(donors[name])})
 assert len(audit)==len(names)
 (OUT/'texture-audit.json').write_text(json.dumps({'bsp_sha256':sha(data),'textures':audit},indent=2)+'\n')
 (ROOT/'maps/navigation'/f'{ID}.res').unlink(missing_ok=True)
 report={'id':ID,'title':a.title,'sha256':sha(data),'source_sha256':sha((OUT/(ID+'.map')).read_bytes()),'bytes':len(data),'structural_brushes':len(a.brushes),'detail_brushes':len(a.detail),'moving_platforms':4,'lift_rise_metres':8,'team_spawns':[8,8],'target_players':12,'supported_players':[8,16],'rotational_symmetry':True,'geometry_license':'CC0-1.0','textures':'texture-sources.json'}
 (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
