"""Build the shared licensed Quake texture dictionary. Python 3 + Pillow; CC0 tool."""
from pathlib import Path
import argparse, hashlib, json, shutil, struct
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DEST = ROOT / 'deathmatch/maps/texture_replacements'
def sha(data): return hashlib.sha256(data).hexdigest()
def wad_read(path):
    data=path.read_bytes(); count,offset=struct.unpack_from('<ii',data,4); result={}
    for i in range(count):
        at,size,_,kind,compression,_,raw=struct.unpack_from('<iiiBBH16s',data,offset+i*32)
        if kind==68 and not compression: result[raw.split(b'\0')[0].decode().lower()]=data[at:at+size]
    return result
def miptex(name, image):
    width,height=image.size; out=bytearray(struct.pack('<16s6I',name.encode(),width,height,0,0,0,0))
    for mip in range(4):
        struct.pack_into('<I',out,24+4*mip,len(out))
        out.extend(image.resize((max(1,width>>mip),max(1,height>>mip)),Image.Resampling.NEAREST).tobytes())
    return bytes(out)
def main(a):
    rules=json.loads((HERE/'rules.json').read_text()); donors={}; origins={}
    for path in sorted(a.librequake.glob('*.wad')):
        for name,data in wad_read(path).items():
            donors[name]=data; origins[name]={'wad':path.name,'wad_sha256':sha(path.read_bytes()),'source_sha256':sha(data),'license':'BSD-3-Clause'}
    palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes()
    # Avoid palette indices 224..255 (fullbright) when quantizing non-emissive relief art.
    quant=Image.new('P',(1,1)); quant.putpalette(palette[:224*3]+palette[:3]*32)
    source=Image.open(HERE/'gothic-reliefs-source.png').convert('RGB'); half=source.width//2
    art={name:source.crop((x*half,y*half,(x+1)*half,(y+1)*half)) for name,x,y in [('ossuary',0,0),('guardian',1,0),('sentinel',0,1),('gargoyle',1,1)]}
    # Unrecognized names get an explicit neutral stone, never a random/hash-selected material.
    rules['textures']['_fallback']={'librequake':'med_flat9','width':64,'height':64,'rotation':0,'match':'neutral fallback; original identity unavailable'}
    # Exact LibreQuake donor names used by the table are also resolvable in imported maps.
    for name in sorted({v['librequake'] for v in rules['textures'].values() if 'librequake' in v}):
        if name not in rules['textures']:
            w,h=struct.unpack_from('<II',donors[name],16);rules['textures'][name]={'librequake':name,'width':w,'height':h,'rotation':0,'match':'exact LibreQuake name'}
    out=bytearray(b'WAD2'+bytes(8)); directory=[]; entries={}
    for name,row in sorted(rules['textures'].items()):
        if 'librequake' in row:
            donor=row['librequake']; raw=donors[donor]; w,h,at=struct.unpack_from('<III',raw,16)
            image=Image.frombytes('P',(w,h),raw[at:at+w*h]);image.putpalette(palette)
            origin=dict(origins[donor],donor=donor)
        else:
            image=art[row['generated']].resize((row['width'],row['height']),Image.Resampling.LANCZOS).quantize(palette=quant,dither=Image.Dither.NONE)
            origin={'generated':row['generated'],'source_sha256':sha((HERE/'gothic-reliefs-source.png').read_bytes()),'license':'generated original art; see SOURCES.md'}
        if row.get('rotation'): image=image.rotate(row['rotation'],expand=True)
        image=image.resize((row['width'],row['height']),Image.Resampling.NEAREST)
        tile=miptex(name,image);offset=len(out);out.extend(tile)
        directory.append(struct.pack('<iiiBBH16s',offset,len(tile),len(tile),68,0,0,name.encode()))
        entries[name]=dict(row,**origin,offset=offset,size=len(tile),sha256=sha(tile))
    at=len(out);out.extend(b''.join(directory));struct.pack_into('<ii',out,4,len(directory),at)
    DEST.mkdir(parents=True,exist_ok=True)
    # .lmp is intentional: already included by all target export presets.
    (DEST/'replacement-miptex.lmp').write_bytes(out)
    (DEST/'manifest.json').write_text(json.dumps({'version':sha(out)[:16],'pack_sha256':sha(out),'textures':entries},indent=2)+'\n')
    for name in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO']:
        shutil.copy2(a.librequake.parent/'docs'/name,DEST/('LibreQuake-'+name+'.txt'))
    print(len(entries),'named replacements;',len(out),'bytes;',sha(out))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--librequake',required=True,type=Path);main(p.parse_args())
