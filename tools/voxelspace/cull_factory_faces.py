"""Drop only box faces provably covered by other solids.
Partially covered quads remain intact: avoids CSG tessellation growth.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/factory-optimization'
boxes=json.loads((OUT/'factory-boxes.json').read_text())

def subtract(rect,cut):
 a,b,c,d=rect;u,v,w,x=cut
 u=max(a,u);v=max(b,v);w=min(c,w);x=min(d,x)
 if u>=w or v>=x:return [rect]
 pieces=[(a,b,u,d),(w,b,c,d),(u,b,w,v),(u,x,w,d)]
 return [p for p in pieces if p[2]-p[0]>1e-7 and p[3]-p[1]>1e-7]

def generate(boxes,variant):
    bounds=[([c[d]-s[d]*.5 for d in range(3)],[c[d]+s[d]*.5 for d in range(3)]) for c,s,_ in boxes]

    points=[];indices=[];removed=0
    for index,(lo,hi) in enumerate(bounds):
     for axis in range(3):
      u,v=(axis+1)%3,(axis+2)%3
      for sign in [-1,1]:
       plane=lo[axis] if sign<0 else hi[axis]
       remains=[(lo[u],lo[v],hi[u],hi[v])]
       for other,(a,b) in enumerate(bounds):
        if index==other:continue
        covers=(a[axis]<=plane+1e-6 and b[axis]>plane+1e-6) if sign>0 else (a[axis]<plane-1e-6 and b[axis]>=plane-1e-6)
        if not covers:continue
        remains=[piece for rect in remains for piece in subtract(rect,(a[u],a[v],b[u],b[v]))]
        if not remains:break
       if not remains:removed+=1;continue
       quad=[]
       for pu,pv in [(lo[u],lo[v]),(hi[u],lo[v]),(hi[u],hi[v]),(lo[u],hi[v])]:
        p=[0.,0.,0.];p[axis]=plane;p[u]=pu;p[v]=pv;quad.append(p)
       if sign<0:quad.reverse()
       offset=len(points);points.extend(quad);indices.extend([offset,offset+1,offset+2,offset,offset+2,offset+3])
    (OUT/("factory_"+variant+".json")).write_text(json.dumps({"vertices":points,"indices":indices},separators=(",",":")))
    return {"variant":variant,"source_triangles":len(boxes)*12,"triangles":len(indices)//3,"fully_hidden_quads_removed":removed}

records=[generate(boxes,"culled")]
medium=[row for row in boxes if not (abs(row[1][0]-3)<1e-5 and abs(row[1][1]-.25)<1e-5) and not (abs(row[1][0]-.55)<1e-5 and abs(row[1][2]-.55)<1e-5)]
records.append(generate(medium,"medium"))
proxy=[[[ -2,10.4,-6],[60,16,48],[.56,.37,.25]],[[38,6.4,-1],[20,8,38],[.56,.37,.25]],[[-42,6.4,1],[20,8,30],[.56,.37,.25]],[[1,20.9,-1],[16,5,14],[.31,.36,.34]]]
for x in [-46,-37]:
 proxy.append([[x,17.4,-24],[4.8,30,4.8],[.52,.34,.26]])
 proxy.append([[x,32.4,-24],[5.4,.7,5.4],[.22,.24,.23]])
records.append(generate(proxy,"proxy"))
(OUT/"culled-faces.json").write_text(json.dumps(records,indent=2)+"\n");print(json.dumps(records))
