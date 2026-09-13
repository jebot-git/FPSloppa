"""Explicitly experimental height/normal companions; never infer production PBR data."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/candidates1011'
records=[]
for row in json.loads((OUT/'sources.json').read_text()):
 name=row['map']+'-'+row['texture'];source=Image.open(OUT/'sources'/f'{name}.png').convert('RGB');size=source.size
 # A restrained, low-frequency height hypothesis from painted relief. This is
 # not a measured normal map; colour/shadow ambiguity remains a review limitation.
 grey=source.convert('L').filter(ImageFilter.GaussianBlur(1.4 if size[0]<=128 else 3.0));height=np.asarray(grey,dtype=float)/255
 lo,hi=np.percentile(height,[8,92]);height=np.clip((height-lo)/max(hi-lo,.08),0,1)
 if row['texture']=='metal_brnz_01':
  # Authored broad panel bevel instead of turning the metal's colour noise into relief.
  y,x=np.mgrid[0:size[1],0:size[0]];u=(x+.5)/size[0];v=(y+.5)/size[1]
  edge=np.minimum.reduce([u,1-u,v,1-v]);height=np.clip(edge/.035,0,1)*.7
 dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.5
 dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.5
 # +S and -T agree with ericw v0.18 LUX. Scale bounds the steepest slopes.
 normal=np.stack([-dx*4,dy*4,np.ones_like(height)],axis=2);normal/=np.linalg.norm(normal,axis=2,keepdims=True)
 alpha=np.clip((height-.15)/.65,0,1)
 rgba=np.concatenate([normal*.5+.5,alpha[...,None]],axis=2)
 Image.fromarray(np.rint(rgba*255).astype('uint8'),'RGBA').save(OUT/'sources'/f'{name}-detail.png')
 Image.fromarray(np.rint(height*255).astype('uint8')).save(OUT/'sources'/f'{name}-height.png')
 records.append({**row,'normal_convention':'+S,-T,N','height_source':'authored panel bevel' if row['texture']=='metal_brnz_01' else 'blurred painted luminance; experimental height hypothesis','reflection_mask':'broad raised regions; normal alpha','slope_limit_degrees':float(np.degrees(np.arccos(normal[:,:,2])).max()),'normal_dimensions':size})
(OUT/'materials.json').write_text(json.dumps(records,indent=2)+'\n')
