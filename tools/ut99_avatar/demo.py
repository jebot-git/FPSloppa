"""Original CC0 low-poly test avatar; no Epic assets redistributed."""
from pathlib import Path
import math, json
import numpy as np
from PIL import Image, ImageDraw
from convert import write_avatar
points=[]; corners=[]; parts=[]
for center, size, part in [((0,1.08,0),(.43,.52,.25),'torso'),((0,1.53,0),(.29,.34,.29),'head'),((-.31,1.03,0),(.16,.6,.17),'arm_l'),((.31,1.03,0),(.16,.6,.17),'arm_r'),((-.13,.4,0),(.2,.8,.22),'leg_l'),((.13,.4,0),(.2,.8,.22),'leg_r')]:
    base=len(points)
    for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
        points.append([center[0]+x*size[0]/2,center[1]+y*size[1]/2,center[2]+z*size[2]/2]); parts.append(part)
    for face in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:
        for a,b,c in [(0,1,2),(0,2,3)]:
            for j in [a,b,c]: corners.append((base+face[j], [0,1,1,0][j], [1,1,0,0][j], 0))
positions=[]; clips=[]
for name in ['Idle','Walk','Run','Fire','Jump','Crouch','Death']:
    start=len(positions)
    for frame in range(8):
        pose=np.array(points); phase=math.sin(frame*math.tau/8)
        for i,part in enumerate(parts):
            if name in ['Walk','Run'] and part.startswith('leg'):pose[i,2]+=phase*(.2 if name=='Walk' else .35)*(1 if part.endswith('l') else -1)*max(0,1-pose[i,1]/.8)
            if name=='Idle':pose[i,1]+=.012*phase
            if name=='Fire' and part.startswith('arm'):pose[i,2]-=.12+.025*phase
            if name=='Jump':pose[i,1]+=.2*max(0,phase)
            if name=='Crouch':pose[i,1]*=.7
            if name=='Death':pose[i,1]*=1-frame/9;pose[i,2]+=.06*frame
        positions.append(pose)
    clips.append(dict(name=name,start=start,count=8,fps=12))
skin=Image.new('RGB',(64,64),(65,89,51));draw=ImageDraw.Draw(skin)
for x in range(0,64,8):
 for y in range(0,64,8):draw.rectangle((x,y,x+3,y+5),fill=(32+(x%3)*7,52+(y%3)*6,30))
root=Path(__file__).resolve().parents[2];out=root/'deathmatch/avatars/models/field_marine.utavatar'
info=write_avatar(out,positions,corners,{0:skin},clips,'Field Marine','FPSloppa contributors','CC0')
info['path']='res://deathmatch/avatars/models/field_marine.utavatar'
(root/'deathmatch/avatars/models/manifest.json').write_text(json.dumps([info],indent=2)+'\n')
print(json.dumps(info))
