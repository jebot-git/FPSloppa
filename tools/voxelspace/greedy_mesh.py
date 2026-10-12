"""Offline exposed-face greedy meshing of integer material volumes.
Factory uses exact compressed box coordinates; terrain uses regular voxel chunks.
Run with numpy after export_factory.gd. No voxel objects are created at runtime.
"""
import json,struct,time,zlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/factory-optimization'
ASSETS=ROOT/'tools/voxelspace/assets'

def greedy(volume, axes):
    points=[]; normals=[]; indices=[]; naive_faces=0
    for d in range(3):
        u,v=(d+1)%3,(d+2)%3
        remaining=[axis for axis in range(3) if axis!=d]
        shape=(volume.shape[u],volume.shape[v])
        zero=np.zeros(shape,dtype=np.int16)
        for k in range(volume.shape[d]+1):
            left=np.take(volume,k-1,axis=d) if k else None
            right=np.take(volume,k,axis=d) if k<volume.shape[d] else None
            if remaining!=[u,v]:
                if left is not None:left=left.T
                if right is not None:right=right.T
            left=zero if left is None else left;right=zero if right is None else right
            mask=np.where((left!=0)&(right==0),left,np.where((right!=0)&(left==0),-right,0))
            naive_faces+=int(np.count_nonzero(mask))
            for a in range(shape[0]):
                b=0
                while b<shape[1]:
                    key=int(mask[a,b])
                    if not key:b+=1;continue
                    width=1
                    while b+width<shape[1] and mask[a,b+width]==key:width+=1
                    height=1
                    while a+height<shape[0] and np.all(mask[a+height,b:b+width]==key):height+=1
                    # u x v points along +d. Reverse the empty-to-solid boundary.
                    quad=[]
                    for aa,bb in [(a,b),(a+height,b),(a+height,b+width),(a,b+width)]:
                        p=[0.,0.,0.];p[d]=float(axes[d][k]);p[u]=float(axes[u][aa]);p[v]=float(axes[v][bb]);quad.append(p)
                    if key<0:quad.reverse()
                    normal=[0.,0.,0.];normal[d]=1. if key>0 else -1.
                    base=len(points);points.extend(quad);normals.extend([normal]*4);indices.extend([base,base+1,base+2,base,base+2,base+3])
                    mask[a:a+height,b:b+width]=0;b+=width
    return np.asarray(points,dtype='<f4').reshape(-1,3),np.asarray(normals,dtype='<f4').reshape(-1,3),np.asarray(indices,dtype='<u4'),naive_faces

def write_mesh(file,points,normals,indices):
    file.write(struct.pack('<II',len(points),len(indices)));file.write(points.tobytes());file.write(normals.tobytes());file.write(indices.tobytes())

def factory():
    boxes=json.loads((OUT/'factory-boxes.json').read_text())
    axes=[np.unique(np.round([c[d]+sign*s[d]*.5 for c,s,_ in boxes for sign in [-1,1]],6)) for d in range(3)]
    volume=np.zeros(tuple(len(axis)-1 for axis in axes),dtype=np.int16)
    colors=[]
    for center,size,color in boxes:
        key=tuple(round(value,6) for value in color)
        if key not in colors:colors.append(key)
        start=[int(np.searchsorted(axes[d],round(center[d]-size[d]*.5,6))) for d in range(3)]
        end=[int(np.searchsorted(axes[d],round(center[d]+size[d]*.5,6))) for d in range(3)]
        volume[tuple(slice(a,b) for a,b in zip(start,end))]=colors.index(key)+1
    points,normals,indices,naive=greedy(volume,axes)
    (OUT/'factory_greedy.json').write_text(json.dumps({'vertices':points.tolist(),'indices':indices.tolist()},separators=(',',':')))
    return {'triangles':len(indices)//3,'unmerged_exposed_faces':naive,'greedy_quads':len(indices)//6,'coordinate_cells':list(volume.shape),'source_boxes':len(boxes)}

def sample_height(heights,x,z):
    gx=np.clip((x+125)/250*512,0,512);gz=np.clip((z+125)/250*512,0,512)
    ix=np.floor(gx).astype(int);iz=np.floor(gz).astype(int);jx=np.minimum(ix+1,512);jz=np.minimum(iz+1,512)
    tx=gx-ix;tz=gz-iz
    return (heights[ix[:,None],iz[None,:]]*(1-tx[:,None])*(1-tz[None,:])+heights[jx[:,None],iz[None,:]]*tx[:,None]*(1-tz[None,:])+heights[ix[:,None],jz[None,:]]*(1-tx[:,None])*tz[None,:]+heights[jx[:,None],jz[None,:]]*tx[:,None]*tz[None,:])

def terrain():
    heights=np.fromfile(OUT/'terrain-heights.bin',dtype='<f4').reshape(513,513).T
    results=[];merged=[([],[],[]) for _ in range(3)];merged_offsets=[0,0,0]
    with (ASSETS/'terrain-voxels.bin').open('wb') as file:
        file.write(b'VXCH');file.write(struct.pack('<II',64,3))
        for z in range(8):
            for x in range(8):
                ox=x*31.25-125;oz=z*31.25-125;file.write(struct.pack('<ff',ox,oz));counts=[]
                for lod in range(3):
                    n=32>>lod;cell=31.25/n
                    bottom=2.4-np.ceil(8.4/cell)*cell
                    ys=np.arange(int(np.ceil((20-bottom)/cell))+1)*cell+bottom
                    heights_sample=sample_height(heights,ox+(np.arange(n)+.5)*cell,oz+(np.arange(n)+.5)*cell)
                    filled=np.ceil((heights_sample-bottom)/cell-1e-6).astype(int)
                    volume=(np.arange(len(ys)-1)[None,:,None]<filled[:,None,:]).astype(np.int16)
                    axes=[np.arange(n+1)*cell,ys,np.arange(n+1)*cell]
                    points,normals,indices,naive=greedy(volume,axes)
                    write_mesh(file,points,normals,indices)
                    counts.append({'lod':lod,'cell_m':cell,'triangles':len(indices)//3,'exposed_voxel_faces':naive})
                    # A monolithic draw compares batching against chunk placement overhead.
                    shifted=points+np.array([ox,0,oz],dtype='<f4');merged[lod][0].append(shifted);merged[lod][1].append(normals);merged[lod][2].append(indices+merged_offsets[lod]);merged_offsets[lod]+=len(points)
                results.append({'origin':[ox,oz],'levels':counts})
    with (ASSETS/'terrain-voxels-merged.bin').open('wb') as file:
        file.write(b'VXMG');file.write(struct.pack('<I',3))
        for parts in merged:write_mesh(file,*[np.concatenate(part) for part in parts])
    return results

def validate_mesher():
    # A solid box must become six quads; a cavity adds inward surfaces.
    axes=[np.arange(4,dtype=float)]*3
    solid=np.ones((3,3,3),dtype=np.int16)
    p,n,i,naive=greedy(solid,axes)
    assert len(i)==36 and naive==54
    solid[1,1,1]=0
    p,n,i,naive=greedy(solid,axes)
    assert len(i)==72 and naive==60
    # Directed surface divergence gives the represented solid volume.
    a=p[i.reshape(-1,3)[:,0]];b=p[i.reshape(-1,3)[:,1]];c=p[i.reshape(-1,3)[:,2]]
    represented=float(np.einsum('ij,ij->i',a,np.cross(b,c)).sum()/6)
    assert abs(represented-26)<1e-5
    return {'solid_box_quads':6,'cavity_quads':12,'cavity_volume':represented}
if __name__=='__main__':
    started=time.monotonic();checks=validate_mesher();f=factory();t=terrain()
    for name in ['terrain-voxels','terrain-voxels-merged']:
        path=ASSETS/(name+'.bin');raw=path.read_bytes()
        (ASSETS/(name+'.vxz')).write_bytes(struct.pack('<I',len(raw))+zlib.compress(raw,9));path.unlink()
    result={'factory':f,'chunks':t,'mesher_checks':checks,'generation_seconds':time.monotonic()-started}
    (OUT/'greedy-generation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'factory':f,'checks':checks,'generation_seconds':result['generation_seconds']}))
