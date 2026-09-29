#!/usr/bin/env python3
"""Sample original walkable surfaces for the compiled-physics portal survey."""
import json,math
from build import Katabatic,LOG,game,np

def main():
    arena=Katabatic()
    for row in arena.items:
        if row.get('interiorFile','').removesuffix('.dif') in arena.models:arena.building(row)
    points=[];seen=set()
    for polygon in arena.building_floors:
        centre=polygon.mean(axis=0)
        p=polygon[np.argsort(np.arctan2(polygon[:,1]-centre[1],polygon[:,0]-centre[0]))]
        normal=None
        for b,c in zip(p[1:],p[2:]):
            n=np.cross(b-p[0],c-p[0])
            if abs(n[2])>.001:normal=n;break
        if normal is None:continue
        for x in np.arange(math.ceil(p[:,0].min()/3)*3,p[:,0].max(),3):
            for y in np.arange(math.ceil(p[:,1].min()/3)*3,p[:,1].max(),3):
                signs=[]
                for u,v in zip(p,np.roll(p,-1,axis=0)):
                    a,b=v[:2]-u[:2],np.array([x,y])-u[:2];signs.append(a[0]*b[1]-a[1]*b[0])
                if not (min(signs)>=-.001 or max(signs)<=.001):continue
                z=p[0,2]-(normal[0]*(x-p[0,0])+normal[1]*(y-p[0,1]))/normal[2]+.06
                point=tuple(game((x,y,z)));key=tuple(round(v*2) for v in point)
                if key not in seen:seen.add(key);points.append(point)
    LOG.mkdir(parents=True,exist_ok=True)
    (LOG/'floor-candidates.json').write_text(json.dumps(points))
    print('KATABATIC_FLOOR_CANDIDATES',len(points))
if __name__=='__main__':main()
