#!/usr/bin/env python3
"""Prepare a static, textured Rumiko GLB from UE Viewer .3d/PNG exports.

This is a rigging intermediate, not a VRM or an automatic rigging tool.
Layout reference: gildor2/UEViewer Exporters/Export3D.cpp and UnMesh2.h.
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import struct
import numpy as np


def read_mesh(root, frame):
    folder = root / "6Rmko/VertMesh"
    data = (folder / "Rumiko_d.3d").read_bytes()
    anim = (folder / "Rumiko_a.3d").read_bytes()
    faces, vertices = struct.unpack_from("<HH", data)
    frames, stride = struct.unpack_from("<HH", anim)
    if len(data) != 48+faces*16 or stride != vertices*4 or len(anim) != 4+frames*stride:
        raise ValueError("Unexpected .3d layout")
    if not 0 <= frame < frames:
        raise ValueError(f"Frame must be between 0 and {frames-1}")
    packed = np.frombuffer(anim, dtype="<u4", count=vertices, offset=4+frame*stride)
    def signed(shift, bits):
        v = ((packed >> shift) & ((1 << bits)-1)).astype(np.int32)
        return (v ^ (1 << (bits-1))) - (1 << (bits-1))
    # UE .uc scale is X=.1, Y=.1, Z=.2. Convert forward +X/up +Z
    # to glTF forward +Z/up +Y, keeping the source proportions.
    positions = np.stack((-signed(11,11), 2*signed(22,10), signed(0,11)), axis=1).astype(float)
    triangles = defaultdict(list)
    for i in range(faces):
        row = struct.unpack_from("<3H10B", data, 48+16*i)
        if max(row[:3]) >= vertices:
            raise ValueError("Triangle vertex out of bounds")
        # Reflection requires winding reversal; byte UVs follow UModel's /255 convention.
        triangles[row[11]].append([(row[j], (row[5+2*j]/255, row[6+2*j]/255)) for j in (0,2,1)])
    return positions, triangles, {"source_vertices":vertices,"triangles":faces,"frames":frames,"frame":frame}


def build(root, output, frame=0, height=1.7, variant="purple"):
    positions, triangles, info = read_mesh(root, frame)
    positions[:,1] -= positions[:,1].min()
    positions *= height / np.ptp(positions[:,1])
    positions[:,[0,2]] -= (positions[:,[0,2]].min(axis=0)+positions[:,[0,2]].max(axis=0))/2
    blob = bytearray()
    doc = {"asset":{"version":"2.0","generator":"FPSloppa UT rigging preparation"},
           "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":"AsiaRumiko_RiggingIntermediate","mesh":0}],
           "meshes":[{"primitives":[]}],"buffers":[],"bufferViews":[],"accessors":[],
           "materials":[],"images":[],"textures":[],"samplers":[{"magFilter":9729,"minFilter":9729,"wrapS":10497,"wrapT":10497}],
           "extras":{"status":"UNRIGGED: requires rest-pose preparation, humanoid bones and skin weights",
                     "skin_credit":"AsiaRumiko package (archive author Unknown)","mesh_credit":"Roger [666] Bacon",
                     "source_frame":frame,"height_assumption_m":height}}
    def view(payload):
        blob.extend(b"\0"*((-len(blob))%4))
        doc["bufferViews"].append({"buffer":0,"byteOffset":len(blob),"byteLength":len(payload)})
        blob.extend(payload)
        return len(doc["bufferViews"])-1
    def accessor(values, kind):
        values = np.asarray(values,dtype="<f4")
        entry={"bufferView":view(values.tobytes()),"componentType":5126,"count":len(values),"type":kind}
        if kind=="VEC3":entry.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
        doc["accessors"].append(entry)
        return len(doc["accessors"])-1
    # Smooth across duplicated source wedges while retaining UV seams.
    normals = defaultdict(lambda:np.zeros(3))
    for group in triangles.values():
        for triangle in group:
            p = positions[[v for v,uv in triangle]]
            normal = np.cross(p[1]-p[0],p[2]-p[0])
            for point in p:normals[tuple(point)] += normal
    if set(triangles) != {0,1}:raise ValueError("Unexpected Rumiko material slots")
    trousers={"purple":"asia2.png","tiger":"asia2T_2.png","spots":"asia2T_0.png","latex":"asia2T_3.png"}
    originals={"original-purple":["asia1silver.png","asia2.png"],"original-black":["asia1black.png","asia2.png"],"original-fur":["furi1tiger.png","furi2.png"]}
    package="Rumikoasia" if variant in originals else "Rumikoskinsasia"
    selected=originals[variant] if variant in originals else [f"asia1{variant}.png",trousers[variant]]
    if variant in originals:doc['extras']['skin_credit']='Asia Carrera (original RumikoAsia readme)'
    for slot, texture in enumerate(selected):
        png=(root/package/"Texture"/texture).read_bytes()
        doc["images"].append({"bufferView":view(png),"mimeType":"image/png","name":texture})
        doc["textures"].append({"source":slot,"sampler":0})
        doc["materials"].append({"name":texture,"doubleSided":True,"pbrMetallicRoughness":{"baseColorTexture":{"index":slot},"metallicFactor":0,"roughnessFactor":1}})
        points=[];uvs=[];ns=[]
        for triangle in triangles[slot]:
            for vertex,uv in triangle:
                p=positions[vertex];n=normals[tuple(p)];length=np.linalg.norm(n)
                points.append(p);uvs.append(uv);ns.append(n/length if length else [0,1,0])
        doc["meshes"][0]["primitives"].append({"attributes":{"POSITION":accessor(points,"VEC3"),"NORMAL":accessor(ns,"VEC3"),"TEXCOORD_0":accessor(uvs,"VEC2")},"material":slot,"mode":4})
    doc["buffers"]=[{"byteLength":len(blob)}]
    js=json.dumps(doc,separators=(",",":")).encode();js+=b" "*((-len(js))%4)
    blob.extend(b"\0"*((-len(blob))%4))
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open("xb") as stream:
        stream.write(struct.pack("<III",0x46546C67,2,12+8+len(js)+8+len(blob)))
        stream.write(struct.pack("<II",len(js),0x4E4F534A)+js)
        stream.write(struct.pack("<II",len(blob),0x004E4942)+blob)
    info.update(output=str(output),bytes=output.stat().st_size,rigged=False,variant=variant,height_assumption_m=height)
    output.with_suffix(".json").write_text(json.dumps(info,indent=2)+"\n")
    print(json.dumps(info))


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("export_root",type=Path);p.add_argument("output",type=Path)
    p.add_argument("--frame",type=int,default=0);p.add_argument("--height",type=float,default=1.7)
    p.add_argument("--variant",choices=["purple","tiger","spots","latex","original-purple","original-black","original-fur"],default="purple")
    a=p.parse_args()
    if a.height<=0:p.error("Height must be positive")
    build(a.export_root,a.output,a.frame,a.height,a.variant)
