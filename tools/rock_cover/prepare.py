#!/usr/bin/env python3
"""Offline OGA OBJ/atlas conversion. Requires Pillow; source ZIPs stay outside exports."""
import argparse, hashlib, json, zipfile
from pathlib import Path
from PIL import Image, ImageOps
ROOT=Path(__file__).resolve().parents[2]

def obj(data, tile, atlas_size=(2048,1536)):
    positions=[];uvs=[];normals=[];faces=[]
    for line in data.decode().splitlines():
        words=line.split()
        if not words:continue
        if words[0]=='v':positions.append(list(map(float,words[1:4])))
        elif words[0]=='vt':uvs.append(list(map(float,words[1:3])))
        elif words[0]=='vn':normals.append(list(map(float,words[1:4])))
        elif words[0]=='f':faces.append([tuple(int(v) if v else 0 for v in w.split('/')) for w in words[1:]])
    lo=[min(v[i] for v in positions) for i in range(3)];hi=[max(v[i] for v in positions) for i in range(3)]
    origin=[(lo[0]+hi[0])/2,lo[1],(lo[2]+hi[2])/2]
    verts=[];ns=[];tex=[];indices=[];lookup={}
    def corner(key):
        if key not in lookup:
            vi,ti,ni=key;lookup[key]=len(verts)
            verts.append([positions[vi-1][i]-origin[i] for i in range(3)])
            ns.append(normals[ni-1] if ni else [0,1,0]);u,v=uvs[ti-1] if ti else (0,0)
            # 4-pixel duplicated edge gutter, UVs remain inside each 512px tile.
            tex.append([(tile%4*512+4+u*504)/atlas_size[0],(tile//4*512+4+(1-v)*504)/atlas_size[1]])
        return lookup[key]
    for face in faces:
        for j in range(1,len(face)-1):indices.extend(corner(face[i]) for i in (0,j+1,j))
    return dict(vertices=verts,normals=ns,uv=tex,indices=indices,origin=origin,size=[hi[i]-lo[i] for i in range(3)])

def main():
    p=argparse.ArgumentParser();p.add_argument('--sources',type=Path,required=True);args=p.parse_args()
    output=ROOT/'experimental-assets/jungle/rocks';output.mkdir(exist_ok=True,parents=True)
    atlas=Image.new('RGB',(2048,1536));assets=[];sources=[]
    for pack,filename,page in [('style','style.zip','handpainted-style-rocks'),('more','more.zip','more-handpainted-rocks')]:
        path=args.sources/filename;sources.append(dict(url='https://opengameart.org/content/'+page,archive_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),author='rubberduck',license='CC0-1.0'))
        with zipfile.ZipFile(path) as z:
            for i in range(1,6):
                tile=len(assets);base=f'rock{i}/'+(f'OBJ/rock_{i:02}' if pack=='more' else f'rock{i}')
                mesh=obj(z.read(base+'.obj'),tile)
                collision=obj(z.read(base+'_collision.obj'),tile)
                # Align collider to the render mesh origin, not its own bounds.
                mesh['collision']=[[v[k]+collision['origin'][k]-mesh['origin'][k] for k in range(3)] for v in collision['vertices']]
                mesh['collision_faces']=[mesh['collision'][j] for j in collision['indices']]
                mesh.update(id=f'{pack}-{i}',source=pack)
                assets.append(mesh)
                import io
                image=Image.open(io.BytesIO(z.read(f'rock{i}/rock{i}.png'))).convert('RGB').resize((504,504),Image.Resampling.LANCZOS)
                padded=ImageOps.expand(image,4)
                padded.paste(image.resize((512,512)),(0,0));padded.paste(image,(4,4))
                # Fill gutter with duplicated edge pixels, never black bleed.
                padded.paste(image.crop((0,0,1,504)).resize((4,504)),(0,4));padded.paste(image.crop((503,0,504,504)).resize((4,504)),(508,4))
                padded.paste(padded.crop((0,4,512,5)).resize((512,4)),(0,0));padded.paste(padded.crop((0,507,512,508)).resize((512,4)),(0,508))
                atlas.paste(padded,(tile%4*512,tile//4*512))
            if pack=='more':
                tile=10
                import io
                image=Image.open(io.BytesIO(z.read('rocks_small/rocks_small.png'))).convert('RGB').resize((504,504),Image.Resampling.LANCZOS)
                # Same edge extension as large tiles.
                atlas.paste(image.resize((512,512)),(tile%4*512,tile//4*512));atlas.paste(image,(tile%4*512+4,tile//4*512+4))
                for i in (1,3,5,8):
                    mesh=obj(z.read(f'rocks_small/OBJ/rocks_small_{i:02}.obj'),tile);mesh.update(id=f'pebbles-{i}',source=pack,collision=[]);assets.append(mesh)
    atlas.save(output/'albedo.png')
    (output/'source.json').write_text(json.dumps(dict(version=1,sources=sources,assets=assets),separators=(',',':'))+'\n')
    print('ROCK_SOURCE_PREPARED',len(assets),'assets')
if __name__=='__main__':main()
