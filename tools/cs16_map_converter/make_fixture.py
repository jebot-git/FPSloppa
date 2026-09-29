"""Author a tiny original room, compile it, then encode GoldSrc palettes/RGB.

No retail map or texture is used. The BSP30 fixture exercises embedded and
external WAD3 textures, trigger brush sites, team spawns and a sliding door.
"""
import argparse
import struct
import subprocess
from pathlib import Path
from bsp import BSP, entity_bytes, pack


def tile(name, index):
    raw = bytearray(struct.pack('<16s6I', name.encode(), 32, 32, 0, 0, 0, 0))
    for mip in range(4):
        struct.pack_into('<I', raw, 24+mip*4, len(raw)); raw.extend(bytes([index])*(32 >> mip)**2)
    return bytes(raw)


def wad(tiles, magic=b'WAD2'):
    result = bytearray(12); rows = []
    for name, data in tiles.items():
        rows.append(struct.pack('<iiiBBH16s', len(result), len(data), len(data), 0x43 if magic == b'WAD3' else 0x44, 0, 0, name.encode()))
        result.extend(data)
    struct.pack_into('<4sii', result, 0, magic, len(rows), len(result)); result.extend(b''.join(rows))
    return bytes(result)


def box(lo, hi, texture):
    x,y,z=lo;X,Y,Z=hi
    faces=[[(x,y,z),(x,Y,z),(X,Y,z)],[(x,y,Z),(X,y,Z),(X,Y,Z)],[(x,y,z),(X,y,z),(X,y,Z)],[(X,y,z),(X,Y,z),(X,Y,Z)],[(X,Y,z),(x,Y,z),(x,Y,Z)],[(x,Y,z),(x,y,z),(x,y,Z)]]
    return '{\n'+'\n'.join(' '.join('( %g %g %g )'%p for p in reversed(face))+' '+texture+' 0 0 0 1 1' for face in faces)+'\n}'


def make(output, compiler):
    output.mkdir(parents=True, exist_ok=True)
    texture_tiles = {'testfloor': tile('testfloor', 230), 'testwall': tile('testwall', 17), 'aaatrigger': tile('aaatrigger', 2), '{testfence': tile('{testfence', 255)}
    (output/'fixture.wad').write_bytes(wad(texture_tiles))
    shell = [box(a,b,t) for a,b,t in [((-272,-272,-16),(272,272,0),'testfloor'),((-272,-272,192),(272,272,208),'testwall'),((-272,-272,0),(-256,272,192),'testwall'),((256,-272,0),(272,272,192),'testwall'),((-256,-272,0),(256,-256,192),'testwall'),((-256,256,0),(256,272,192),'testwall')]]
    text = '{\n"classname" "worldspawn"\n"wad" "fixture.wad"\n'+'\n'.join(shell)+'\n}\n'
    text += entity_bytes([{'classname':'light','origin':'0 0 140','light':'400'},{'classname':'info_player_start','origin':'180 160 36','angles':'0 180 0'},{'classname':'info_player_start','origin':'180 -160 36','angles':'0 90 0'},{'classname':'info_player_deathmatch','origin':'-180 -160 36','angles':'0 0 0'},{'classname':'info_player_deathmatch','origin':'-180 160 36','angles':'0 270 0'}]).rstrip(b'\0').decode()
    for a,b in [((-100,-210,0),(40,-70,100)),((-100,70,0),(40,210,100))]:
        text += '{\n"classname" "func_bomb_target"\n'+box(a,b,'aaatrigger')+'\n}\n'
    text += '{\n"classname" "func_door"\n"angles" "0 90 0"\n"speed" "100"\n'+box((-8,-48,0),(8,48,100),'testwall')+'\n}\n'
    text += '{\n"classname" "func_wall"\n'+box((224,-32,0),(228,32,64),'{testfence')+'\n}\n'
    source = output/'fixture.map'; source.write_text(text)
    bsp_path = output/'fixture.bsp'
    for tool, flags in [('qbsp',['-wadpath',str(output),str(source),str(bsp_path)]),('vis',['-fast',str(bsp_path)]),('light',['-extra',str(bsp_path)])]:
        with (output/(tool+'.log')).open('w') as log:
            subprocess.run([str(compiler/tool),*flags], stdout=log, stderr=subprocess.STDOUT, check=True)
    raw = bsp_path.read_bytes(); bsp = BSP(raw,29); lumps=bsp.lumps.copy()
    palettes = {name: bytes(v for i in range(256) for v in ((37,149,231) if name=='testfloor' else (173,41,98) if name=='testwall' else (0,0,255))) for name in texture_tiles}
    gold_tiles = {name: data+struct.pack('<H',256)+palettes[name] for name,data in texture_tiles.items()}
    (output/'external.wad').write_bytes(wad({'testwall':gold_tiles['testwall']},b'WAD3'))
    count=struct.unpack_from('<i',lumps[2])[0]; tex=bytearray(struct.pack('<i',count)+bytes(4*count))
    for i in range(count):
        at=struct.unpack_from('<i',lumps[2],4+4*i)[0];name=lumps[2][at:at+16].split(b'\0')[0].decode()
        data=gold_tiles[name]
        if name=='testwall':data=data[:24]+bytes(16)
        struct.pack_into('<i',tex,4+4*i,len(tex));tex.extend(data)
    lumps[2]=bytes(tex)
    faces=bytearray(lumps[7])
    for i in range(len(faces)//20):
        at=struct.unpack_from('<i',faces,i*20+16)[0]
        if at>=0:struct.pack_into('<i',faces,i*20+16,at*3)
    lumps[7]=bytes(faces);lumps[8]=bytes(c for v in lumps[8] for c in (v,v//2,v//3))
    rows=bsp.entities;rows[0]['wad']='C:\\old-editor\\external.wad';lumps[0]=entity_bytes(rows)
    output_bytes=bytearray(pack(lumps,{}));struct.pack_into('<i',output_bytes,0,30)
    path=output/'de_fixture.bsp';path.write_bytes(output_bytes)
    print(path)
    return path


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler-dir',type=Path,required=True);a=p.parse_args();make(a.output.resolve(),a.compiler_dir.resolve())
