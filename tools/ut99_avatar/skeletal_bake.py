"""Offline ActorX PSK/PSA -> bounded UT vertex animation, including AMS PS2 sets.
UE Viewer mirrors Y on export; child bone quaternions are inverse rotations in
ActorX. Match bones by name (animation sets can contain extra dummy bones).
No UnrealScript or skeletal animation evaluator is shipped to the client.
"""
from pathlib import Path
import struct
import numpy as np


def chunks(path):
    data=Path(path).read_bytes()
    if len(data)>64_000_000:raise ValueError('ActorX input exceeds limit')
    out={};at=0
    while at<len(data):
        if len(data)-at<32:raise ValueError('Truncated ActorX header')
        raw,_,size,count=struct.unpack_from('<20s3i',data,at);at+=32
        if size<0 or count<0 or size*count>len(data)-at:raise ValueError('Truncated ActorX chunk')
        name=raw.split(b'\0')[0].decode('ascii')
        if name in out:raise ValueError('Duplicate ActorX chunk')
        out[name]=(size,count,data[at:at+size*count]);at+=size*count
    return out


def bones(chunk):
    size,count,data=chunk
    if size!=120 or not 1<=count<=256:raise ValueError('Unexpected bone layout')
    names=[];parents=[];poses=[]
    for i in range(count):
        at=i*size;names.append(data[at:at+64].split(b'\0')[0].decode('ascii'))
        parents.append(struct.unpack_from('<i',data,at+72)[0]);q=struct.unpack_from('<4f',data,at+76);p=struct.unpack_from('<3f',data,at+92);poses.append([*p,*q])
        if i and not 0<=parents[-1]<i:raise ValueError('Bone hierarchy must be ordered')
    if len(set(names))!=len(names):raise ValueError('Duplicate bone name')
    return names,parents,np.asarray(poses)


def transforms(poses,parents):
    poses=np.asarray(poses,dtype=float);q=poses[...,3:7].copy()
    q[...,1:,:3]*=-1 # ActorX child orientations are inverse bind/local rotations.
    norm=np.linalg.norm(q,axis=-1,keepdims=True)
    if not np.isfinite(poses).all() or (norm<1e-6).any():raise ValueError('Invalid bone pose')
    x,y,z,w=(q/norm).transpose(2,0,1) if q.ndim==3 else (q/norm).T
    shape=poses.shape[:-1];local=np.zeros((*shape,4,4));local[...,3,3]=1;local[...,:3,3]=poses[...,:3]
    local[...,0,0]=1-2*(y*y+z*z);local[...,0,1]=2*(x*y-z*w);local[...,0,2]=2*(x*z+y*w)
    local[...,1,0]=2*(x*y+z*w);local[...,1,1]=1-2*(x*x+z*z);local[...,1,2]=2*(y*z-x*w)
    local[...,2,0]=2*(x*z-y*w);local[...,2,1]=2*(y*z+x*w);local[...,2,2]=1-2*(x*x+y*y)
    world=local.copy()
    for i,parent in enumerate(parents):
        if i:world[...,i,:,:]=world[...,parent,:,:]@local[...,i,:,:]
    return world


def bake(mesh,animation):
    m=chunks(mesh);a=chunks(animation)
    names,parents,bind=bones(m['REFSKELT']);anim_names,anim_parents,_=bones(a['BONENAMES'])
    mapping=[anim_names.index(n) for n in names]
    p=np.frombuffer(m['PNTS0000'][2],dtype='<f4').reshape(-1,3).astype(float)
    if not 3<=len(p)<=4096:raise ValueError('Vertex limit')
    size,n,raw=a['ANIMKEYS']
    if size!=32 or n%len(anim_names):raise ValueError('Animation key layout')
    keys=np.frombuffer(raw,dtype='<f4').reshape(-1,len(anim_names),8)[...,:7]
    if len(keys)*len(p)>1_048_576:raise ValueError('Animated vertex limit')
    clips=[];size,n,raw=a['ANIMINFO']
    if size!=168 or n>256:raise ValueError('Animation sequence layout')
    for i in range(n):
        at=i*size;name=raw[at:at+64].split(b'\0')[0].decode();values=struct.unpack_from('<4i3f3i',raw,at+128);start,count=values[-2:];fps=values[6]
        if start<0 or count<1 or start+count>len(keys) or not 0<fps<=120:raise ValueError('Invalid animation range')
        clips.append(dict(name=name,start=start,count=count,fps=fps))
    # UE1 PSA BONENAMES commonly has parent 0 for every non-root bone.
    # Animation tracks are local; use the actual PSK hierarchy after name remapping.
    rest=transforms(bind,parents);animated=transforms(keys[:,mapping],parents)
    skin=animated@np.linalg.inv(rest)
    size,n,raw=m['RAWWEIGHTS']
    if size!=12 or n>len(p)*16:raise ValueError('Invalid weights layout')
    weights=np.zeros((len(p),len(names)))
    for i in range(n):
        weight,point,bone=struct.unpack_from('<fii',raw,i*12)
        if not 0<=point<len(p) or not 0<=bone<len(names) or not 0<=weight<=1:raise ValueError('Invalid bone weight')
        weights[point,bone]+=weight
    if (weights.sum(1)<.99).any():raise ValueError('Unweighted vertices')
    weights/=weights.sum(1,keepdims=True)
    points=np.c_[p,np.ones(len(p))];positions=np.zeros((len(keys),len(p),3))
    for bone in range(len(names)):
        ids=np.flatnonzero(weights[:,bone]>0)
        if len(ids):positions[:,ids]+=np.einsum('fij,vj->fvi',skin[:,bone,:3],points[ids])*weights[ids,bone][None,:,None]
    wedges=[];size,n,raw=m['VTXW0000']
    if size!=16:raise ValueError('Unexpected wedge layout')
    for i in range(n):
        index=struct.unpack_from('<I',raw,i*16)[0];uv=struct.unpack_from('<2f',raw,i*16+4)
        if index>=len(p):raise ValueError('Wedge vertex out of bounds')
        wedges.append((index,*uv,raw[i*16+12]))
    corners=[];size,n,raw=m['FACE0000']
    if size!=12 or n>8192:raise ValueError('Triangle layout')
    for i in range(n):
        triangle=struct.unpack_from('<3H',raw,i*12)
        for j in (0,2,1):
            if triangle[j]>=len(wedges):raise ValueError('Triangle wedge out of bounds')
            corners.append(wedges[triangle[j]])
    reference=next(c['start'] for c in clips if c['name']=='Breath1')
    # PSK is already mirrored into right-handed coordinates by UE Viewer.
    matrix=np.array([[1,0,0],[0,0,1],[0,-1,0]],dtype=float)
    positions=positions@matrix.T;joints=animated[...,:3,3]@matrix.T
    low,high=positions[reference].min(0),positions[reference].max(0)
    offset=np.array([(low[0]+high[0])/2,low[1],(low[2]+high[2])/2]);scale=1.7/(high[1]-low[1]);positions=(positions-offset)*scale;joints=(joints-offset)*scale
    if not np.isfinite(positions).all() or abs(positions).max()>10:raise ValueError('Baked coordinates exceed bounds')
    def joint(name):return joints[reference,names.index(name)]
    profile={side:[joint('Bip01 '+letter+' '+part).tolist() for part in ['UpperArm','Forearm','Hand']] for side,letter in [('left','L'),('right','R')]}
    profile.update(neck=joint('Bip01 Neck').tolist(),head=joint('Bip01 Head').tolist());profile['eye']=(joint('Bip01 Head')+np.array([0,.065,-.065])).tolist()
    indices=[names.index('Bip01 L UpperArm'),names.index('Bip01 R UpperArm'),names.index('Bip01 Neck')]
    profile['sockets']=joints[:,indices].reshape(len(keys),9).tolist()
    ik=[]
    for vertex in range(len(p)):
        codes=np.zeros(4);blend=np.zeros(4)
        for bone,name in enumerate(names):
            weight=weights[vertex,bone];code=0;t=0.
            if ' L ' in name and any(k in name for k in ['UpperArm','Forearm','Hand','Finger']):code=1;t=0. if 'UpperArm' in name else 1.
            elif ' R ' in name and any(k in name for k in ['UpperArm','Forearm','Hand','Finger']):code=2;t=0. if 'UpperArm' in name else 1.
            elif any(k in name for k in ['Neck','Head','Ponytail']):code=3;t=0. if 'Neck' in name else 1.
            codes[code]+=weight;blend[code]+=weight*t
        code=int(codes[1:].argmax())+1 if codes[1:].max()>.01 else 0
        ik.append([code,float(blend[code]/codes[code]) if code else 0.,float(codes[code]) if code else 0.])
    return positions,corners,clips,reference,(profile,ik),dict(mesh_bones=len(names),animation_bones=len(anim_names),frames=len(keys),vertices=len(p),triangles=len(corners)//3,profile=profile)
