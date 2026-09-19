"""Original CC0 one-square-kilometre BSP29 stress map. No production maplists modified."""
import argparse, hashlib, json, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'maps/Benchmark1km'
sys.path.insert(0,str(ROOT/'tools'))
from generate_tf_maps import Arena
ID='prototype_km1'
def q(p):return (-p[2]*32,-p[0]*32,p[1]*32)
class World(Arena):
 def __init__(self):super().__init__(ID,'Kilometre Test District');self.solids=[];self.spawns=[];self.zones=[]
 def face(self,points,texture):return super().face(points,texture).rsplit(' ',2)[0]+' 8 8'
 def block(self,lo,hi,tex='km_concrete',occlude=True):
  a=q(lo);b=q(hi);self.box(tuple(min(x,y) for x,y in zip(a,b)),tuple(max(x,y) for x,y in zip(a,b)),tex)
  if occlude:self.solids.append({'minimum':lo,'maximum':hi})
 def point(self,kind,p,**kw):self.ent(kind,q((p[0],p[1]+.7,p[2])),**kw)
def wad():
 palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes()
 colors={'km_grass':(85,100,57),'km_concrete':(130,132,128),'km_brick':(147,99,72),'km_blue':(72,108,128),'km_road':(58,65,68),'km_crate':(141,120,72),'sky_km':(120,150,180)}
 blob=bytearray(b'WAD2'+bytes(8));directory=[]
 for name,rgb in colors.items():
  indices=[]
  for shade in [.8,1,1.12]:indices.append(min(range(224),key=lambda i:sum((palette[i*3+c]-rgb[c]*shade)**2 for c in range(3))))
  pixels=bytes(indices[0 if x%16==0 or y%16==0 else 2 if (x+y)%19==0 else 1] for y in range(64) for x in range(64))
  mips=[pixels]+[bytes(pixels[(y*(2**m))*64+x*(2**m)] for y in range(64>>m) for x in range(64>>m)) for m in range(1,4)]
  starts=[];offset=40
  for mip in mips:starts.append(offset);offset+=len(mip)
  record=struct.pack('<16s6I',name.encode(),64,64,*starts)+b''.join(mips)
  directory.append(struct.pack('<iiiBBH16s',len(blob),len(record),len(record),68,0,0,name.encode()));blob.extend(record)
 at=len(blob);blob.extend(b''.join(directory));struct.pack_into('<ii',blob,4,len(directory),at);(OUT/'benchmark.wad').write_bytes(blob)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--compiler',type=Path,required=True);args=ap.parse_args();OUT.mkdir(exist_ok=True)
 wad();w=World();w.block((-500,-2,-500),(500,0,500),'km_grass',False)
 for lo,hi in [((-502,-2,-502),(-500,72,502)),((500,-2,-502),(502,72,502)),((-500,-2,-502),(500,72,-500)),((-500,-2,500),(500,72,502))]:w.block(lo,hi)
 w.block((-502,72,-502),(502,74,502),'sky_km',False)
 centers=[-375,-125,125,375]
 # Solid 30m dividers create sixteen occlusion districts, with 24m portals.
 for edge in [-250,0,250]:
  cursor=-500
  for opening in centers:
   for axis in [0,2]:
    lo=[cursor,0,edge-2];hi=[opening-12,30,edge+2]
    if axis==0:lo[0],lo[2]=lo[2],lo[0];hi[0],hi[2]=hi[2],hi[0]
    w.block(tuple(lo),tuple(hi))
   cursor=opening+12
  w.block((cursor,0,edge-2),(500,30,edge+2));w.block((edge-2,0,cursor),(edge+2,30,500))
 for iz,z in enumerate(centers):
  for ix,x in enumerate(centers):
   zone=iz*4+ix;w.zones.append({'id':zone,'center':[x,0,z],'bounds':[x-125,z-125,x+125,z+125]})
   # Broad streets; surface is 5cm above grass, below movement step threshold.
   w.block((x-122,0,z-8),(x+122,.05,z+8),'km_road',False)
   w.block((x-8,0,z-122),(x+8,.05,z+122),'km_road',False)
   for dx,dz in [(-68,-65),(68,-65),(-68,65),(68,65)]:
    height=12+(zone%4)*3
    w.block((x+dx-18,0,z+dz-16),(x+dx+18,height,z+dz+16),'km_blue' if zone%2 else 'km_brick')
    w.block((x+dx-20,height,z+dz-18),(x+dx+20,height+1,z+dz+18),'km_concrete',False)
   # Accessible low terraces and broad ramps (all dimensions in metres).
   w.block((x+25,0,z+40),(x+50,3,z+62),'km_concrete')
   # Use the source helper's Q-x ramp, aligned along world Z instead.
   w.ramp_x(-32*(z+80),-32*(z+62),-32*(x+50),-32*(x+25),0,96,'km_concrete')
   for dx,dz in [(-12,-14),(12,14),(-28,8),(28,-8),(-15,30),(15,-30)]:w.block((x+dx-1.5,0,z+dz-1.5),(x+dx+1.5,1.6,z+dz+1.5),'km_crate',False)
   for dx,dz in [(-20,-20),(20,-20),(-20,20),(20,20)]:
    pos=(x+dx,.1,z+dz);w.point('info_player_deathmatch',pos,angle=(zone*90)%360);w.spawns.append(list(pos))
   for weapon,dx,dz in [('weapon_rocketlauncher',-7,0),('weapon_lightning',7,0),('weapon_supernailgun',0,7),('weapon_supershotgun',0,-7)]:w.point(weapon,(x+dx,.1,z+dz))
   for kind,dx,dz in [('item_health',10,10),('item_armor2',-10,-10),('item_rockets',-10,10),('item_cells',10,-10)]:w.point(kind,(x+dx,.1,z+dz))
 world={'classname':'worldspawn','message':'Kilometre Test District | 64-bot prototype','wad':'benchmark.wad','_sunlight':'180','_sun_mangle':'35 -65 0','_minlight':'30','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096'}
 def ent(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
 text='{\n'+ent(world)+'\n'+'\n'.join(w.brushes)+'\n}\n'+'\n'.join('{\n'+ent(e)+'\n}' for e in w.entities)+'\n'
 source=OUT/(ID+'.map');source.write_text('// Original CC0 prototype geometry and procedural textures.\n'+text)
 (OUT/'layout.json').write_text(json.dumps({'id':ID,'playable_metres':[1000,1000],'area_km2':1,'zones':w.zones,'spawns':w.spawns,'occluder_boxes':w.solids,'brushes':len(w.brushes)},indent=2)+'\n')
 bsp=OUT/(ID+'.bsp');commands=[('qbsp',['-leaktest','-subdivide','2048',str(source),str(bsp)]),('vis',['-threads','8','-fast',str(bsp)]),('light',['-threads','4','-bspxlit',str(bsp)])];receipts=[]
 for binary,flags in commands:
  start=time.monotonic();print('BUILD',binary,flush=True)
  with (OUT/(binary+'.log')).open('w') as log:subprocess.run([str(args.compiler/binary),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
  receipts.append({'tool':binary,'seconds':time.monotonic()-start,'args':flags})
 data=bsp.read_bytes();assert struct.unpack_from('<I',data)[0]==29 and len(data)<25000000
 (OUT/'build.json').write_text(json.dumps({'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'format':'BSP29','commands':receipts},indent=2)+'\n');print('BUILT',len(data),'bytes',flush=True)
if __name__=='__main__':main()
