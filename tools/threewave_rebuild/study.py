"""Local reference inspection only. This module is never imported by the map builder."""
from pathlib import Path
import struct, re, json, hashlib
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

LOCAL=Path(__file__).resolve().parent/'local/references'
def inspect(path):
    data=path.read_bytes()
    lumps=[struct.unpack_from('<ii',data,4+8*i) for i in range(15)]
    def rows(n,fmt):
        at,size=lumps[n];return list(struct.iter_unpack(fmt,data[at:at+size]))
    vertices=rows(3,'<3f');edges=rows(12,'<2H');surf=rows(13,'<i');planes=rows(1,'<4fi')
    entities=[dict(re.findall(r'"([^\"]+)"\s*"([^\"]*)"',s)) for s in data[lumps[0][0]:sum(lumps[0])].decode('latin1').split('}') if '"classname"' in s]
    polygons=[];heights=[]
    for face in rows(7,'<Hhihh4Bi'):
        normal=planes[face[0]][2]*(-1 if face[1] else 1)
        if normal<.65:continue
        poly=[vertices[edges[surf[i][0]][0] if surf[i][0]>=0 else edges[-surf[i][0]][1]] for i in range(face[2],face[2]+face[3])]
        polygons.append([(v[0],v[1]) for v in poly]);heights.append(sum(v[2] for v in poly)/len(poly))
    fig,ax=plt.subplots(figsize=(12,10));collection=PolyCollection(polygons,array=heights,cmap='terrain',edgecolors='#242424',linewidths=.18)
    ax.add_collection(collection);ax.autoscale();ax.set_aspect('equal');fig.colorbar(collection,ax=ax,label='Quake elevation (units)')
    flags=[]
    for e in entities:
        c=e.get('classname','');p=list(map(float,e.get('origin','0 0 0').split()))
        if c.startswith('item_flag_team'):
            ax.scatter(*p[:2],s=120,c='red' if c.endswith('1') else 'blue',marker='*',edgecolors='white');flags.append(e)
        elif c.startswith('info_player_team'):ax.scatter(*p[:2],s=9,c='red' if c.endswith('1') else 'blue')
    ax.set_title(path.stem+' · ORIGINAL reference, not build geometry');fig.savefig(LOCAL/(path.stem+'-plan.png'),dpi=130);plt.close(fig)
    return {'map':path.stem,'sha256':hashlib.sha256(data).hexdigest(),'bounds':[list(map(min,zip(*vertices))),list(map(max,zip(*vertices)))],
            'faces':len(rows(7,'<Hhihh4Bi')),'flags':flags,'entities':{k:sum(e.get('classname')==k for e in entities) for k in sorted(set(e.get('classname','') for e in entities))}}
if __name__=='__main__':
    report=[inspect(LOCAL/'3wctfc30/maps'/f'ctf{i}.bsp') for i in range(1,7)]
    (LOCAL/'bsp-study.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
