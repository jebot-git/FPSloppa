"""Experimental static UT world -> sealed Quake brushes; retained source textures/UVs.
Output stays in staging until runtime spawn, hill and route validation succeeds.
"""
import sys,json,gzip,struct,hashlib,subprocess,colorsys,math
from pathlib import Path
import numpy as np
from PIL import Image
from attempt import members,LOCAL,HERE
from package import Package
ROOT=HERE.parents[1];sys.path.insert(0,str(ROOT/'tools'));from makkon.theme import wad_textures
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'));from make_fixture import wad,box
COMPILER=Path('/tmp/st-toolchain/ericw-tools-v0.18.1-Linux/bin')
def ent(d):return '{\n'+'\n'.join('"'+k+'" "'+str(v).replace('"',"'")+'"' for k,v in d.items())+'\n}'
def point(p):return ' '.join('%.12g'%x for x in p)
def texture(pkg,e,alias):
 props,r=pkg.props(e)
 if props.get('Format',0)!=0:raise ValueError('Unsupported texture format')
 count=r.num('B')
 if not count:raise ValueError('No texture mips')
 if pkg.version>=63:r.take(4)
 raw=r.take(r.count());w,h=r.unpack('2I');r.take(2)
 if w*h!=len(raw) or w%16 or h%16:raise ValueError('Invalid palettized texture')
 pe=pkg.obj(props['Palette']['object']);_,pr=pkg.props(pe);n=pr.count();palette=pr.take(n*4)
 if n!=256:raise ValueError('Palette requires 256 entries')
 im=Image.frombytes('P',(w,h),raw);im.putpalette(bytes(palette[i+j] for i in range(0,1024,4) for j in (0,1,2)));im=im.convert('RGB')
 pal=Image.new('P',(1,1));pal.putpalette((ROOT/'deathmatch/maps/palette.lmp').read_bytes());out=bytearray(struct.pack('<16s6I',alias.encode(),w,h,0,0,0,0))
 for level in range(4):
  mip=im.resize((w>>level,h>>level),Image.Resampling.LANCZOS).quantize(palette=pal,dither=Image.Dither.NONE);struct.pack_into('<I',out,24+4*level,len(out));out.extend(mip.tobytes())
 return bytes(out)
def face(points,normal,name,axes=None):
 a=points[0];b=points[1];c=points[2]
 for i in range(1,len(points)-1):
  b=points[i];c=points[i+1]
  if np.linalg.norm(np.cross(b-a,c-a))>.0001:break
 else:raise ValueError("Degenerate polygon")
 if np.dot(np.cross(b-a,c-a),normal)>0:b,c=c,b
 coords=' '.join('( '+point(p)+' )' for p in (a,b,c))
 return coords+' '+name+(' '+axes if axes else ' 0 0 0 1 1')
def prism(poly,name,depth=4):
 ps=np.array(poly['points'])*.8;n=np.array(poly['normal']);n=n/np.linalg.norm(n)
 # BSP cuts contain near-duplicate vertices. They form unbounded slivers after
 # decimal plane reconstruction unless collapsed together with their UVs.
 keep=list(range(len(ps)))
 changed=True
 while changed and len(keep)>3:
  changed=False
  for j in range(len(keep)):
   a,b,c=ps[keep[j-1]],ps[keep[j]],ps[keep[(j+1)%len(keep)]]
   if np.linalg.norm(b-a)<.02 or np.linalg.norm(np.cross(b-a,c-b))<.01:
    keep.pop(j);changed=True;break
 ps=ps[keep];uv=np.array(poly['uv_texels'])[keep]
 if np.linalg.norm(np.cross(ps[1]-ps[0],ps[2]-ps[0]))<.01:raise ValueError('Degenerate polygon')
 # Project tiny BSP rounding errors back onto the authored face plane.
 ps-=np.outer((ps-ps[0])@n,n);bottom=ps-n*depth
 # Fit authored texel-space coordinates to world coordinates, preserving arbitrary UV axes.
 xyz=np.column_stack((ps,np.ones(len(ps))));ax=np.linalg.lstsq(xyz,uv,rcond=None)[0].T
 axes='[ '+point(ax[0])+' ] [ '+point(ax[1])+' ] 0 1 1'
 surfaces=[face(ps,n,name,axes),face(bottom,-n,'skip')]
 for i in range(len(ps)):
  a=ps[i];b=ps[(i+1)%len(ps)];side=np.cross(b-a,n)
  center=ps.mean(axis=0)-n*(depth*.5)
  if np.dot(side,center-a)>0:side=-side
  if np.linalg.norm(side)<.0001:continue
  surfaces.append(face(np.array([a,b,b-n*depth]),side,'skip'))
 return '{\n'+'\n'.join(surfaces)+'\n}'
def main():
 row=next(r for r in json.loads((HERE/'downloads.json').read_text()) if r['name']=='KOTH-(WTF)TryTitan');files=members((LOCAL/'archives'/row['archive_sha1']).read_bytes());source=LOCAL/'converted'/row['archive_sha1'][:12]
 model=json.load(gzip.open(source/'world.json.gz'));actors=json.loads((source/'actors.json').read_text());out=LOCAL/'candidates/koth_ut_trytitan';out.mkdir(parents=True,exist_ok=True)
 packs={Path(n).stem.lower():Package(b) for n,b in files.items() if n.lower().endswith(('.utx','.unr'))};bank=wad_textures((ROOT/'tools/fortressone/librequake.wad').read_bytes());bank['skip']=bank['met_brn_pan1'];raw=bytearray(bank['skip']);raw[:16]=b'skip'.ljust(16,b'\0');bank['skip']=bytes(raw)
 textures={};sources={}
 for name in sorted({p['texture'] for p in model['polygons']}):
  key,local=name.split('.',1);pkg=packs[key.lower()];e=next(e for i,e in enumerate(pkg.exports) if pkg.path(i+1).lower()==local.lower());alias='ut'+hashlib.sha256(name.encode()).hexdigest()[:12];bank[alias]=texture(pkg,e,alias);textures[name]=alias;sources[alias]=name
 brushes=[prism(p,textures[p['texture']]) for p in model['polygons']]
 points=np.array([p for f in model['polygons'] for p in f['points']])*.8;lo=points.min(axis=0)-64;hi=points.max(axis=0)+64
 for axis in range(3):
  for side in range(2):
   a=lo.copy();b=hi.copy()
   if side==0:b[axis]=lo[axis]+16
   else:a[axis]=hi[axis]-16
   brushes.append(box(a,b,'skip'))
 world=ent({'classname':'worldspawn','wad':'textures.wad','message':'TryTitan — ChaosUT KOTH adaptation','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_fpsloppa_light_response':'quake','_minlight':'16','_bounce':'1'})[:-1]+'\n'+'\n'.join(brushes)+'\n}'
 entities=[];hills=[];starts=[]
 for actor in actors:
  c=actor['class_path'].split('.')[-1];p=actor['properties'];loc=np.array(p.get('Location',[0,0,0]))*.8
  if c=='PlayerStart':starts.append((loc,p))
  pickup={'UT_Eightball':'weapon_rocketlauncher','UT_FlakCannon':'weapon_grenadelauncher','minigun2':'weapon_supernailgun','Armor':'item_armor2','SuperHealth':'item_health','ShieldBelt':'item_armorInv','Miniammo':'item_spikes','FlakAmmo':'item_rockets','RocketPack':'item_rockets','WarheadLauncher':'weapon_lightning'}.get(c)
  if pickup:entities.append(ent({'classname':pickup,'origin':point(loc),'spawnflags':2 if c=='SuperHealth' else 0}))
  if c=='ChaosKOTHHill':hills.append(loc)
  if c=='Light':
   h=p.get('LightHue',0)/255;s=1-p.get('LightSaturation',255)/255;colour=colorsys.hsv_to_rgb(h,s,1)
   entities.append(ent({'classname':'light','origin':point(loc),'light':max(80,p.get('LightBrightness',64)*2),'_color':point(colour)}))
 for i,(loc,p) in enumerate(starts):
  loc[2]+=9.6 # UT starts in this source sit 16 UU above the floor; Quake runtime subtracts .70m.
  entities.append(ent({'classname':'info_player_deathmatch','origin':point(loc),'angle':p.get('Rotation',[0,0,0])[1]*360/65536}))
  entities.append(ent({'classname':'info_player_team'+str(1+i%2),'origin':point(loc)}))
 for i,hill in enumerate(hills):entities.append(ent({'classname':'info_koth_control','origin':point(hill),'hill_index':i,'hill_authored':1}))
 entities.append(ent({'classname':'info_player_start','origin':point(starts[0][0])}))
 (out/'koth_ut_trytitan.map').write_text(world+'\n'+'\n'.join(entities));(out/'textures.wad').write_bytes(wad(bank))
 (out/'conversion.json').write_text(json.dumps(dict(source=row,texture_sources=sources,source_faces=len(brushes)-6,spawns=len(starts),hill_points=len(hills),adaptations=['Static polygon shells four Quake units thick','Authored texture pixels quantized to Quake palette; new full mips','All authored hill actors retained; one is fixed, multiple rotate with existing KOTH rules','UTDMT scripted Titan omitted; source pickups mapped to classic arena equivalents'],status='staging'),indent=2)+'\n')
 for stage,args in [('qbsp',['-noclip']),('vis',['-fast','-threads','2']),('light',['-extra','-bspxlit','-threads','2'])]:
  with (out/(stage+'.log')).open('w') as log:run=subprocess.run([str(COMPILER/stage),*args,str(out/('koth_ut_trytitan.map' if stage=='qbsp' else 'koth_ut_trytitan.bsp'))],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=300)
  if run.returncode:raise RuntimeError(stage+' failed: '+(out/(stage+'.log')).read_text()[-1500:])
 print(out,flush=True)
if __name__=='__main__':main()
