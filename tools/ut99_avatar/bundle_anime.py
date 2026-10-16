#!/usr/bin/env python3
"""Rebuild requested Motoko, AsiaBots, Kusanagi and AMS Asuka bundles.
Input: reviewed UE Viewer exports under --exports. Original packages and AMS
scripts stay offline. Existing stock IK is retained for texture-only skins.
"""
import argparse,copy,hashlib,io,json,struct
from pathlib import Path
import numpy as np
from PIL import Image
from convert import read_mesh,write_avatar
from base_models import authored_ik
from skeletal_bake import bake
ROOT=Path(__file__).resolve().parents[2]
SOURCES={
 'motoko':dict(page='https://unrealarchive.org/unreal-tournament/skins/M/motoko_96e3f99a.html',sha1='96e3f99a83d5249f5f33d7de3210bdad3988d07a'),
 'kusanagi':dict(page='https://unrealarchive.org/unreal-tournament/skins/K/kusanagi_9a88ddd6.html',sha1='9a88ddd6a92d590e9c01f6bd9ea6e846e1c73a8d'),
 'asiabots':dict(page='https://unrealarchive.org/unreal-tournament/skins/A/asiabots_ae709677.html',sha1='ae70967723166b6f432c64a72ba1cef800b1b215'),
 'asuka':dict(page='https://unrealarchive.org/unreal-tournament/models/T/team-anime_ea9a8e7c.html',sha1='ea9a8e7c7f26bec417fa470236b586dbabc18653')}
LICENSE='Original model, skin and animation author terms apply; no CC0 claim'
def metadata(path):
 data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0];m=json.loads(data[16:16+n]);return m,data[16+n:16+n+m['position_bytes']]
def rewrite(path,m,positions,png):
 m=copy.deepcopy(m);m['skin_bytes']=len(png);raw=json.dumps(m,separators=(',',':'),allow_nan=False).encode();size=16+len(raw)+len(positions)+len(png);assert size<=25_000_000
 path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(struct.pack('<4sIII',b'UTAV',1,size,len(raw))+raw+positions+png)
def decorate(info,key,model):
 info.update(source=SOURCES[key]['page'],source_sha1=SOURCES[key]['sha1'],source_model=model,bundle='anime',path='res://'+Path(info['path']).relative_to(ROOT).as_posix());return info

def animation_aliases(clips):
    result=list(clips);names={c['name'] for c in result}
    for alias,source in [('JumpLg','JumpLgFr'),('JumpSm','JumpSmFr')]:
        if alias not in names:
            match=next((c for c in result if c['name']==source),None)
            if match:result.append(dict(match,name=alias))
    return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exports',type=Path,required=True);args=p.parse_args();exports=args.exports.resolve();output=ROOT/'deathmatch/avatars/models/anime';rows=[]
 base,positions=metadata(ROOT/'deathmatch/avatars/models/base/fcommando.utavatar');cols=2;cell=base['skin_width']//cols
 def stock(key,slug,title,package,names,author):
  atlas=Image.new('RGBA',(base['skin_width'],base['skin_height']),(0,0,0,255))
  for i,name in enumerate(names):
   im=Image.open(exports/package/'Texture'/(name+'.png')).convert('RGB').convert('RGBA').resize((cell-4,cell-4),Image.Resampling.LANCZOS);padded=np.pad(np.asarray(im),((2,2),(2,2),(0,0)),mode='edge');atlas.paste(Image.fromarray(padded),(i%cols*cell,i//cols*cell))
  buf=io.BytesIO();atlas.save(buf,format='PNG');m=copy.deepcopy(base);m.update(title=title,author=author,license=LICENSE,source_model='FCommando',skin_textures=names);m.pop('base_model',None);path=output/(slug+'.utavatar');rewrite(path,m,positions,buf.getvalue())
  info=dict(path=str(path),hash=hashlib.sha256(path.read_bytes()).hexdigest(),size=path.stat().st_size,title=title,author=author,license=LICENSE,version='UT99 vertex 1',frames=m['frames'],vertices=m['vertices'],triangles=len(m['corners'])//3);rows.append(decorate(info,key,'FCommando'))
 for suffix,label in [('motokokusanagi','Motoko Kusanagi'),('motokokusanagialternate','Alternate'),('motokokusanagijaws','Jaws'),('motokokusanagired','Red')]:
  stock('motoko','motoko-'+suffix.removeprefix('motokokusanagi') if suffix!='motokokusanagi' else 'motoko','Motoko · '+label,'FCommandoSkins_Motoko',['mooo1','mooo2','mooo4'+suffix],'Bongo / Bongoloid (skin); Epic Games / Digital Extremes (Female Commando)')
 for color,team in [('Black',None),('Blue',1),('Red',0),('green',2),('gold',3)]:
  tail='' if team is None else 'T_'+str(team);stock('asiabots','asiabots-'+color.lower(),'AsiaBots · '+color.title(),'FCommandoAsia',['asia1'+tail,'asia2'+tail,'asia4'+color],'Asia Carrera (skin); Epic Games / Digital Extremes (Female Commando)')
 for color,team in [('green',2),('black',None)]:
  tail='T_2' if team==2 else '';stock('asiabots','asiabots2-'+color,'AsiaBots2 · '+color.title(),'FCommandoAsia',['gree1'+tail,'gree2'+tail,'gree4'+color],'Asia Carrera (skin); Epic Games / Digital Extremes (Female Commando)')
 # Rumiko export's All alias says 499 frames, but the animation payload has 498.
 # Only this known aggregate alias is corrected; individual clip bounds stay strict.
 mesh=exports/'6Rmko/VertMesh/Rumiko_d.3d';script=mesh.with_name('Rumiko.uc');text=script.read_text();script.write_text(text.replace('NUMFRAMES=499 RATE=30','NUMFRAMES=498 RATE=30'))
 points,corners,clips,ref=read_mesh(mesh,reference=0)
 assert points.shape==(498,683,3) and len(corners)==2094,'Unexpected Rumiko topology'
 spec=dict(reference=0,title='Rumiko',body=[0,1,3,4,5,6],left=[27,28,29,30,31,34,41],right=[12,13,14,15,16,32,33],head=[22,23,24,25,26],neck=[3,4],landmarks={'left':[[-.18,1.37,0],[-.32,1.15,0],[-.31,.93,-.07]],'right':[[.18,1.37,.04],[.30,1.15,.10],[.33,.86,.10]],'neck':[0,1.445,0],'head':[0,1.535,0],'eye':[0,1.615,-.08]})
 profile,weights,report=authored_ik(points,corners,spec);path=output/'kusanagi.utavatar';skins={0:Image.open(exports/'RumikoSkins_GITS/Texture/gits1moto.png'),1:Image.open(exports/'RumikoSkins_GITS/Texture/gits2.png')}
 info=write_avatar(path,points,corners,skins,animation_aliases(clips),'Kusanagi · Motoko (Rumiko)','Roger [666] Bacon (Rumiko); GITS skin author uncredited',LICENSE,ref,None,(profile,weights));rows.append(decorate(info,'kusanagi','Rumiko'))
 points,corners,clips,ref,ik,report=bake(exports/'Asuka/SkeletalMesh/Asuka.psk',exports/'AdvancedModelSupport/MeshAnimation/EpicUTPS2FemaleAnimation.psa');skins={i:Image.open(exports/'AsukaSkins/Texture'/('Suka'+str(i)+'.png')) for i in range(2)};path=output/'asuka.utavatar';author='Gotham & UDS (Asuka); Tom Woof (base mesh); James Green / James Edwards, Epic Games (PS2 animations); Simon McVittie (AMS)'
 info=write_avatar(path,points,corners,skins,animation_aliases(clips),'Team Anime · Asuka',author,LICENSE,ref,None,ik);info.update(animation_source='AMS 1.10 · EpicUTPS2FemaleAnimation',animation_frames=1152);rows.append(decorate(info,'asuka','Asuka'))
 manifest=ROOT/'deathmatch/avatars/models/manifest.json';existing=json.loads(manifest.read_text());existing=[r for r in existing if r.get('bundle')!='anime'];manifest.write_text(json.dumps(existing+rows,indent=2)+'\n');print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
