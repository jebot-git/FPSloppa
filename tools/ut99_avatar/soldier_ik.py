"""Authored hybrid IK for stock BotPack Soldier topology; no body/finger rig.
Components are identified by original vertex IDs, not height/capsule guesses.
Every coincident seam uses identical weights, including torso copies.
"""
import numpy as np

def build(positions, corners):
    p=positions[25];faces=np.asarray([c[0] for c in corners]).reshape(-1,3)
    adjacency=[set() for _ in p]
    for tri in faces:
        for i in tri:adjacency[i].update(int(v) for v in tri)
    seen=set();parts=[]
    for i in range(len(p)):
        if i in seen:continue
        todo=[i];part=set()
        while todo:
            n=todo.pop()
            if n in part:continue
            part.add(n);todo.extend(adjacency[n]-part)
        seen|=part
        if len(part)>1:parts.append(sorted(part))
    assert len(p)==504 and len(faces)==595 and [len(c) for c in parts]==[35,25,38,16,35,16,28,6,28,32,26,16,22,22,19,6,19,15,19,19,15,9,9], 'Unexpected Soldier topology; author a new profile rather than guess.'
    _,inverse=np.unique(np.round(p,5),axis=0,return_inverse=True)
    groups=[np.flatnonzero(inverse==n) for n in range(inverse.max()+1)]
    labels=[set() for _ in p]
    for part,ids in enumerate(parts):
        for i in ids:labels[i].add(part)
    # Isolated copies are intentionally resolved through the seam group too.
    for ids in groups:
        merged=set().union(*(labels[int(i)] for i in ids))
        for i in ids:labels[int(i)]=merged
    def common(a,b):
        ids=sorted({i for i in range(len(p)) if labels[i]&set(a) and labels[i]&set(b)})
        # One contribution per welded position, so UV duplicates cannot bias a socket.
        unique={int(inverse[i]):i for i in ids};return list(unique.values())
    body=[1,2]
    sockets={
        'left':common([5,13],body), 'right':common([3,12],body),
        'neck':common([11],body),
    }
    profile={}
    for side,upper,fore,glove in [('left',13,14,[16,17]),('right',12,18,[19,20])]:
        shoulder=p[sockets[side]].mean(0)
        elbow=p[common([upper],[fore])].mean(0)
        hand=p[common([fore],glove)].mean(0)
        profile[side]=[shoulder.tolist(),elbow.tolist(),hand.tolist()]
    profile['neck']=p[sockets['neck']].mean(0).tolist()
    profile['head']=p[common([11],[9,10])].mean(0).tolist()
    # Eye centre authored on the face. Keep native head/neck proportions.
    profile['eye']=[.070,1.610,-.250]
    profile['sockets']=[np.concatenate([frame[sockets[k]].mean(0) for k in ['left','right','neck']]).tolist() for frame in positions]
    weights=[]
    for point,regions in zip(p,labels):
        code=0;blend=0.;influence=0.
        for side,number,part_ids,upper,fore in [('left',1,{5,13,14,16,17},13,14),('right',2,{3,12,18,19,20},12,18)]:
            if not regions & part_ids:continue
            code=number;influence=1.
            shoulder,elbow,hand=map(np.asarray,profile[side])
            if regions & set(body):influence=0.
            # Shoulder shell blends away from the seam; upper arm is fully IK.
            elif regions & ({5} if side=='left' else {3}):
                distance=np.linalg.norm(point-p[sockets[side]],axis=1).min()
                influence=min(1.,float(distance/.055))
            if upper in regions and fore in regions:blend=.5
            elif fore in regions:
                blend=.5+.5*min(1.,float(np.linalg.norm(point-elbow)/.055))
            elif upper in regions:
                blend=.5*max(0.,1.-float(np.linalg.norm(point-elbow)/.055))
            elif regions & ({16,17} if side=='left' else {19,20}):blend=1.
            break
        if regions & {9,10,11,21,22}:
            code=3;influence=0. if regions & set(body) else 1.
            neck=np.asarray(profile['neck']);head=np.asarray(profile['head'])
            if regions & {9,10,21,22}:blend=1.
            else:blend=float(np.clip(np.dot(point-neck,head-neck)/np.dot(head-neck,head-neck),0,1))
        weights.append([code,blend,influence])
    # Check the complete arm/head coverage and identical seam treatment.
    assert sum(w[0]==1 for w in weights)>70 and sum(w[0]==2 for w in weights)>70
    for ids in groups:assert all(weights[i]==weights[ids[0]] for i in ids)
    return profile,weights
