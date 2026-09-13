#!/usr/bin/env python3
"""Experimental landmark/capsule rig for the frame-0, 1.7m Rumiko GLB.

Weights are newly estimated, not recovered from UT. This deliberately supports
only prepare_rumiko.py's default frame and height. Inspect joint deformation.
"""
import argparse
import json
from pathlib import Path
import struct
import numpy as np


def rig(source, output):
    raw=source.read_bytes();jslen=struct.unpack_from("<I",raw,12)[0]
    doc=json.loads(raw[20:20+jslen]);blob=bytearray(raw[28+jslen:])
    if doc['extras']['source_frame']!=0 or doc['extras']['height_assumption_m']!=1.7:
        raise ValueError("Landmarks require frame 0 at 1.7 metres")
    bones=[];names={}
    def bone(name,parent,start,end):
        names[name]=len(bones)
        bones.append({'name':name,'parent':names.get(parent),'old':np.array(start,float),
                      'end':np.array(end,float),'new':np.array(start,float),'rot':np.eye(3)})
    bone('hips',None,[0,.94,0],[0,1.06,0])
    bone('spine','hips',[0,1.06,0],[0,1.22,0])
    bone('chest','spine',[0,1.22,0],[0,1.40,0])
    bone('neck','chest',[0,1.40,0],[0,1.49,0])
    bone('head','neck',[0,1.49,0],[0,1.70,0])
    for side,sign in [('left',1),('right',-1)]:
        def pos(x,y,z=0):return [sign*x,y,z]
        bone(side+'Shoulder','chest',pos(.09,1.36),pos(.19,1.36))
        bone(side+'UpperArm',side+'Shoulder',pos(.19,1.36),pos(.29,1.14,-.015))
        bone(side+'LowerArm',side+'UpperArm',pos(.29,1.14,-.015),pos(.325,.94,-.025))
        bone(side+'Hand',side+'LowerArm',pos(.325,.94,-.025),pos(.34,.82,-.025))
        bone(side+'UpperLeg','hips',pos(.115,.94),pos(.18,.55,.015))
        bone(side+'LowerLeg',side+'UpperLeg',pos(.18,.55,.015),pos(.245,.10,.005))
        bone(side+'Foot',side+'LowerLeg',pos(.245,.10,.005),pos(.245,.055,.18))

    def rotation_between(a,b):
        a=a/np.linalg.norm(a);b=b/np.linalg.norm(b)
        v=np.cross(a,b);c=np.dot(a,b)
        if c>1-1e-9:return np.eye(3)
        if c<-.999:raise ValueError('Antiparallel segment')
        skew=np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])
        return np.eye(3)+skew+skew@skew/(1+c)
    for side,sign in [('left',1),('right',-1)]:
        for suffix in ['UpperArm','LowerArm','UpperLeg','LowerLeg']:
            b=bones[names[side+suffix]]
            b['rot']=rotation_between(b['end']-b['old'],np.array([sign,0,0]) if 'Arm' in suffix else np.array([0,-1,0]))
        for suffix in ['LowerArm','Hand','LowerLeg','Foot']:
            b=bones[names[side+suffix]];parent=bones[b['parent']]
            b['new']=parent['new']+parent['rot']@(b['old']-parent['old'])
            if suffix=='Hand':b['rot']=parent['rot']

    def read_accessor(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        return np.frombuffer(blob,dtype='<f4',offset=v.get('byteOffset',0)+a.get('byteOffset',0),count=a['count']*{'VEC3':3,'VEC2':2}[a['type']]).reshape(a['count'],-1).copy()
    def add_accessor(values,kind,component=5126):
        values=np.asarray(values,dtype='<f4' if component==5126 else '<u2')
        blob.extend(b'\0'*((-len(blob))%4))
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':values.nbytes})
        blob.extend(values.tobytes())
        a={'bufferView':len(doc['bufferViews'])-1,'componentType':component,'count':len(values),'type':kind}
        if kind=='VEC3':a.update(min=values.min(0).tolist(),max=values.max(0).tolist())
        doc['accessors'].append(a);return len(doc['accessors'])-1

    reports=[]
    for primitive in doc['meshes'][0]['primitives']:
        attrs=primitive['attributes'];p=read_accessor(attrs['POSITION']);n=read_accessor(attrs['NORMAL'])
        distances=[]
        for b in bones:
            direction=b['end']-b['old']
            t=np.clip((p-b['old'])@direction/np.dot(direction,direction),0,1)
            closest=b['old']+t[:,None]*direction
            distance=np.linalg.norm(p-closest,axis=1)
            # Head/hair need a rigid head assignment instead of shoulder influence.
            if b['name']!='head':distance[p[:,1]>1.48]=1e3
            # Keep hand, arm and leg weights on their own anatomical side.
            if b['name'].startswith('left'):distance[p[:,0]<-.025]=1e3
            if b['name'].startswith('right'):distance[p[:,0]>.025]=1e3
            if 'Arm' in b['name'] or 'Hand' in b['name'] or 'Shoulder' in b['name']:
                distance[(np.abs(p[:,0])<.15)|(p[:,1]<.76)]=1e3
            elif b['name'] not in ['head','neck']:
                distance[(np.abs(p[:,0])>.25)&(p[:,1]>.78)]=1e3
            distances.append(distance)
        distances=np.stack(distances,axis=1)
        joints=np.argsort(distances,axis=1)[:,:4]
        nearest=np.take_along_axis(distances,joints,axis=1)
        weights=np.exp(-(nearest-nearest[:,0,None])*45)
        # Blend only adjacent bones, avoiding long-range cross-limb influences.
        for row in range(len(p)):
            first=int(joints[row,0])
            for k in range(1,4):
                other=int(joints[row,k])
                if bones[other]['parent']!=first and bones[first]['parent']!=other:weights[row,k]=0
        weights/=weights.sum(axis=1,keepdims=True)
        newp=np.zeros_like(p);newn=np.zeros_like(n)
        for k in range(4):
            for j,b in enumerate(bones):
                mask=joints[:,k]==j
                newp[mask]+=weights[mask,k,None]*((p[mask]-b['old'])@b['rot'].T+b['new'])
                newn[mask]+=weights[mask,k,None]*(n[mask]@b['rot'].T)
        newn/=np.maximum(np.linalg.norm(newn,axis=1,keepdims=True),1e-8)
        attrs.update(POSITION=add_accessor(newp,'VEC3'),NORMAL=add_accessor(newn,'VEC3'),
                     JOINTS_0=add_accessor(joints,'VEC4',5123),WEIGHTS_0=add_accessor(weights,'VEC4'))
        reports.append({'vertices':len(p),'min_weight_sum':float(weights.sum(1).min()),'max_weight_sum':float(weights.sum(1).max())})
    matrices=[]
    for i,b in enumerate(bones):
        parent=b['parent'];translation=b['new']-(bones[parent]['new'] if parent is not None else 0)
        node={'name':b['name'],'translation':translation.tolist()}
        children=[j+1 for j,x in enumerate(bones) if x['parent']==i]
        if children:node['children']=children
        doc['nodes'].append(node)
        matrix=np.eye(4);matrix[:3,3]=-b['new'];matrices.append(matrix.T.reshape(-1))
    doc['scenes'][0]['nodes'].append(1)
    doc['nodes'][0].update(name='AsiaRumiko_ExperimentalRig',skin=0)
    doc['skins']=[{'joints':list(range(1,len(bones)+1)),'skeleton':1,'inverseBindMatrices':add_accessor(matrices,'MAT4')}]
    doc['extras'].update(status='EXPERIMENTAL RIG: newly estimated weights; deformation and live VR not approved',rig_method='manual landmarks, nearest capsule weights, T-pose conversion')
    doc['buffers']=[{'byteLength':len(blob)}]
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob.extend(b'\0'*((-len(blob))%4))
    with output.open('xb') as stream:
        stream.write(struct.pack('<III',0x46546C67,2,28+len(js)+len(blob)))
        stream.write(struct.pack('<II',len(js),0x4E4F534A)+js)
        stream.write(struct.pack('<II',len(blob),0x004E4942)+blob)
    report={'bones':len(bones),'primitives':reports,'experimental':True,'output':str(output)}
    output.with_suffix('.rig.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('output',type=Path)
    a=p.parse_args();rig(a.source,a.output)
