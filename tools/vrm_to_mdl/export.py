#!/usr/bin/env python3
"""Write bounded Quake IDPO v6 assets from Blender's baked NPZ intermediates."""
import argparse, hashlib, json, re, struct
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('baked',type=Path);p.add_argument('output',type=Path);p.add_argument('--normals',type=Path,required=True);p.add_argument('--source-dir',type=Path,required=True);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
normals=np.array([[float(v) for v in row] for row in re.findall(r'\{\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\s*\}',a.normals.read_text())],dtype=np.float32)
assert normals.shape==(162,3)
files=sorted(a.baked.glob('*.npz'));assert len(files)==11
atlases=[np.load(f)['atlas'] for f in files]
# A shared custom palette preserves source clothing/skin colours; reserve the
# final 32 Quake fullbright indices. MDL never embeds its own palette.
combined=Image.fromarray(np.concatenate(atlases,axis=0)).quantize(colors=224,method=Image.Quantize.MEDIANCUT)
palette=combined.getpalette()[:224*3]+[0]*96
pal=Image.new('P',(1,1));pal.putpalette(palette)
(a.output/'palette.lmp').write_bytes(bytes(palette))
report=[]
for file,atlas in zip(files,atlases):
    name=file.stem;data=np.load(file);meta=json.loads(file.with_suffix('.json').read_text());frames=data['frames'];faces=data['faces'];uv=data['uv']
    source=a.source_dir/(name+'.vrm');assert hashlib.sha256(source.read_bytes()).hexdigest()==meta['source']['hash']
    lo=frames.min(axis=(0,1));hi=frames.max(axis=(0,1));scale=np.maximum((hi-lo)/255,1e-5)
    xyz=np.clip(np.rint((frames-lo)/scale),0,255).astype(np.uint8)
    skin=Image.fromarray(atlas).quantize(palette=pal,dither=Image.Dither.NONE);skin.save(a.output/(name+'-skin.png'))
    assert int(np.asarray(skin).max())<224
    out=bytearray(struct.pack('<4si3f3ff3f8if',b'IDPO',6,*scale,*lo,float(np.linalg.norm(hi-lo)/2),0,0,48,1,256,256,len(uv),len(faces),len(frames),1,0,10))
    assert len(out)==84
    out+=struct.pack('<i',0)+skin.tobytes()
    for st in uv:out+=struct.pack('<3i',0,*st)
    for face in faces:out+=struct.pack('<4i',1,*face)
    for positions,quantized,label in zip(frames,xyz,meta['frames']):
        accumulated=np.zeros_like(positions)
        tri=positions[faces];n=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
        for corner in range(3):np.add.at(accumulated,faces[:,corner],n)
        lengths=np.linalg.norm(accumulated,axis=1);accumulated/=np.maximum(lengths[:,None],1e-20)
        normal_index=np.argmax(accumulated@normals.T,axis=1).astype(np.uint8)
        out+=struct.pack('<i4B4B16s',0,*quantized.min(axis=0),0,*quantized.max(axis=0),0,label.encode()[:15])
        out+=np.column_stack([quantized,normal_index]).astype(np.uint8).tobytes()
    target=a.output/(name+'.mdl');target.write_bytes(out)
    restored=xyz*scale+lo;error=float(np.max(np.linalg.norm(restored-frames,axis=2))*1.7/56)
    row={**meta,'mdl':target.name,'format':'Quake IDPO version 6','palette':'palette.lmp','height_m':1.7,'quake_height_units':56,'tracking':False,'skeleton':False,'morphs':False,'springs':False,'source_bytes':source.stat().st_size,'mdl_bytes':len(out),'mdl_sha256':hashlib.sha256(out).hexdigest(),'quantization_max_error_m':error,'skin_size':[256,256],'skin':name+'-skin.png','fullbright_indices_used':0}
    (a.output/(name+'.json')).write_text(json.dumps(row,indent=2)+'\n');report.append(row)
    print('MDL',name,'verts',len(uv),'tris',len(faces),'bytes',len(out),'max error mm',round(error*1000,2),flush=True)
(a.output/'manifest.json').write_text(json.dumps({'format':'Quake IDPO version 6','source_branch':'main','models':report,'palette':'Shared custom 224-colour palette; last 32 indices reserved. Supply palette.lmp to the reader. Stock Quake palette requires remapping.','limits':'Baked generic clips, not vanilla player.qc frame ordering; no direct MDL avatar integration in FPSloppa.'},indent=2)+'\n')
(a.output/'LICENSE.txt').write_text('Derived from the 11 bundled historical VRoid Project / pixiv CC0 models.\nOriginal author and title are retained in each JSON sidecar. Geometry, textures\nand baked animation derivatives are provided under CC0 1.0.\nhttps://creativecommons.org/publicdomain/zero/1.0/\nOriginal source records: /vrm/SOURCES.json and /vrm/README.txt in FPSloppa main.\nCanonical Quake normal directions are used only to encode normal indices.\n')
