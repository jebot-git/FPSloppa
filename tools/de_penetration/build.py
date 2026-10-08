"""Hash-bound solid BSP trees and explicit surface roles for converted DE maps."""
import hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'))
from bsp import BSP,engine
OUT=ROOT/'deathmatch/maps/penetration'
def role(name):
 n=name.lower();n=n[2:] if n.startswith(('+','-')) else n;n=n.lstrip('{!~ ')
 if n.startswith(('sky','*','water')) or n in ['skip','clip','origin','null','aaatrigger','invisible']:return 'stop'
 if any(t in n for t in ['vent','grate','grating','grille','grillage']):return 'vent'
 if any(t in n for t in ['glass','vitre']):return 'glass'
 if any(t in n for t in ['metal','met_','_met','mtlt','container','cont1','contab','tank','tnk','turbine','pipe','conduit','manhole','galv','elbox','elshitok','boitier','stovetop','barberpole','ladder','railing','rail3','razor','wire','rustyrungs','fence','gate','drum']):return 'metal'
 if any(t in n for t in ['wood','crate','crte','crt','_wd','floorwd','oldwd','wbarrel','cais1','portebois','poutre','wicker','chestdrawers','table0','dsk','book','door','dool','porte','cudr','cxdr','tk_doorpanel','cabanon','nmww_wall','nmww_floor','nmww_sign','nmww_roof','nmww_flatroof','nmcf_fence']):return 'wood'
 return 'concrete'
def profile(raw,material_for):
 b=BSP(raw,29);digest=hashlib.sha256(raw).hexdigest();textures=[]
 for i in range(struct.unpack_from('<i',b.lumps[2])[0]):
  at=struct.unpack_from('<i',b.lumps[2],4+i*4)[0];textures.append(b.lumps[2][at:at+16].split(b'\0')[0].decode('latin1') if at>=0 else 'unknown')
 faces=[];counts={};roles={}
 for f in b.faces:
  name=textures[b.texinfo[f[4]][8]];material=material_for(name);roles[name]=material;counts[material]=counts.get(material,0)+1
  faces.append([f[0],f[1],material,[[round(v,7) for v in engine(p)] for p in b.polygon(f)]])
 nodes=[[n[0],n[1],n[2],n[-2],n[-1]] for n in struct.iter_unpack('<i2h6h2H',b.lumps[5])]
 leaves=[n[0] for n in struct.iter_unpack('<ii6h2H4B',b.lumps[10])]
 models=[]
 for i,m in enumerate(b.models):
  a,c=engine(m[:3]),engine(m[3:6]);models.append({'id':i,'head':m[9],'bounds':[[min(x,y) for x,y in zip(a,c)],[max(x,y) for x,y in zip(a,c)]],'faces':[m[14],m[15]]})
 return {'version':2,'source_sha256':digest,'planes':[[-p[1],p[2],-p[0],p[3]/32] for p in b.planes],'nodes':nodes,'leaves':leaves,'faces':faces,'models':models},counts,roles

def main():
 OUT.mkdir(parents=True,exist_ok=True);index={};reports=[];roles={}
 overrides={'mltrycrtesd':'wood','mltrycrtesd2':'wood','mltrycrtetp':'wood','box_drum':'metal','p_dr_metal2':'metal','ngin_door':'metal','coupfeu':'metal','babtech_dr1c':'metal','babtech_dr4c':'metal','fifties_dr1':'metal','fog_door4':'metal','hype_door4a':'metal','sandwlldoor':'concrete','sandwlldoor2':'concrete','sandwlldoorbta':'concrete','sandwlldoorbtb':'concrete','sandwlldoordj1':'concrete','sandwlldoordj2':'concrete','walldoor':'concrete','nmcf_fence_b':'wood','box01':'wood','box02':'wood','br_bk-box01':'wood','br_bk-box02':'wood','cudre':'wood','cudrf':'wood','cudrh':'wood','cudri':'wood','cudrj':'wood'}
 for r in json.loads((ROOT/'tools/expansions/catalog.json').read_text()):
  if r['mode']!='de':continue
  raw=(ROOT/'maps'/f"{r['id']}.bsp").read_bytes();digest=hashlib.sha256(raw).hexdigest()
  data,counts,used=profile(raw,lambda name:overrides.get(name,role(name)));roles.update(used)
  file=OUT/(r['id']+'.json');payload=json.dumps(data,separators=(',',':'),allow_nan=False).encode();assert len(payload)<16_000_000;file.write_bytes(payload)
  index[digest]={'path':'res://'+str(file.relative_to(ROOT)),'sha256':hashlib.sha256(payload).hexdigest()}
  reports.append({'id':r['id'],'bsp_sha256':digest,'profile_sha256':index[digest]['sha256'],'nodes':len(data['nodes']),'faces':len(data['faces']),'materials':counts,'bytes':len(payload)})
 (OUT/'index.json').write_text(json.dumps(index,indent=2)+'\n')
 (ROOT/'tools/de_penetration/materials.json').write_text(json.dumps(dict(sorted(roles.items())),indent=2)+'\n')
 (ROOT/'tools/de_penetration/build.json').write_text(json.dumps(reports,indent=2)+'\n')
 print('Prepared',len(reports),'BSP profiles;',len(roles),'texture roles')
if __name__=='__main__':main()
