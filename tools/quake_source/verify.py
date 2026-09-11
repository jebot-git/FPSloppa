"""Verify compiled BSPs match the supplied licensed texture dictionary and contain baked light."""
import hashlib,json,struct
from pathlib import Path
def verify(build):
    wad=(build/'sources/adapted/librequake.wad').read_bytes();count,at=struct.unpack_from('<ii',wad,4);donors={}
    for i in range(count):
        offset,size,_,kind,compression,_,name=struct.unpack_from('<iiiBBH16s',wad,at+i*32);assert kind==68 and not compression
        donors[name.split(b'\0')[0].decode().lower()]=wad[offset:offset+size]
    pack=build/'texture-dictionary'
    proof=json.loads((pack/'manifest.json').read_text())
    payload=(pack/'replacement-miptex.lmp').read_bytes()
    assert hashlib.sha256(payload).hexdigest()==proof['pack_sha256']
    for name,tile in donors.items():
        row=proof['textures'][name]
        assert hashlib.sha256(tile).hexdigest()==row['sha256']
        assert tile==payload[row['offset']:row['offset']+row['size']]
        assert row.get('license') and row.get('source_sha256')
    reports=[]
    for row in json.loads((build/'BUILD.json').read_text())['maps']:
        assert row['status']=='compiled';data=(build/'maps'/(row['id']+'.bsp')).read_bytes();assert hashlib.sha256(data).hexdigest()==row['sha256'];assert 124<len(data)<=25_000_000
        lumps=[struct.unpack_from('<II',data,4+8*i) for i in range(15)];assert all(o+n<=len(data) for o,n in lumps)
        o,n=lumps[2];count=struct.unpack_from('<i',data,o)[0];verified=0
        for i in range(count):
            rel=struct.unpack_from('<i',data,o+4+4*i)[0];assert rel>=0;at=o+rel;name=data[at:at+16].split(b'\0')[0].decode().lower();source=donors[name]
            w,h=struct.unpack_from('<II',data,at+16);assert (w,h)==struct.unpack_from('<II',source,16)
            for mip in range(4):
                off=struct.unpack_from('<I',data,at+24+4*mip)[0];src=struct.unpack_from('<I',source,24+4*mip)[0];size=max(1,w>>mip)*max(1,h>>mip)
                assert data[at+off:at+off+size]==source[src:src+size],(row['id'],name,mip)
            verified+=1
        o,n=lumps[0];entities=data[o:o+n];assert b'"_fpsloppa_bake" "1"' in entities;assert b'info_player_deathmatch' in entities;assert lumps[8][1]>0
        end=(max(o+n for o,n in lumps)+3)&~3;assert data[end:end+4]==b'BSPX';count=struct.unpack_from('<I',data,end+4)[0];rgb=False
        for i in range(count):
            name,at,n=struct.unpack_from('<24sII',data,end+8+32*i)
            if name.rstrip(b'\0')==b'RGBLIGHTING':assert n==lumps[8][1]*3 and at+n<=len(data);rgb=True
        assert rgb
        reports.append({'id':row['id'],'sha256':row['sha256'],'textures_verified':verified,'all_mips_match_licensed_dictionary':True,'embedded_rgb_bake':True,'size':len(data)})
    return reports
if __name__=='__main__':
    import sys
    print(json.dumps(verify(Path(sys.argv[1])),indent=2))
