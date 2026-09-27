"""Verify BSP29 surface markings and solid backing at all ten DE sites."""
from pathlib import Path
import json, struct

ROOT = Path(__file__).resolve().parents[2]

def layout(map_id):
    folder = ROOT / ('maps/Dust2Rebuilt' if map_id == 'de_dust2_rebuilt' else 'maps/ClassicDE/' + map_id)
    data = json.loads((folder / 'manifest.json').read_text())
    if 'site_markings' in data:
        return data['site_markings']
    return [dict(site='A', cross=[184,132,224], wall=[150,127,301], normal=[1,0]),
            dict(site='B', cross=[184,531,64], wall=[135,489,148], normal=[1,0])]

def quake(point):
    u,v,z = point
    return [(u-400)*6, (300-v)*6, z]

def main():
    results = []
    for map_id in json.loads((ROOT/'deathmatch/maps/defusal.json').read_text()):
        raw = (ROOT/'maps'/(map_id+'.bsp')).read_bytes()
        assert struct.unpack_from('<i', raw)[0] == 29
        lumps = [raw[offset:offset+size] for offset,size in struct.iter_unpack('<ii',raw[4:124])]
        vertices = list(struct.iter_unpack('<3f',lumps[3]))
        edges = list(struct.iter_unpack('<2H',lumps[12]))
        surfedges = [r[0] for r in struct.iter_unpack('<i',lumps[13])]
        planes = list(struct.iter_unpack('<4fi',lumps[1]))
        texinfo = list(struct.iter_unpack('<8fii',lumps[6]))
        textures = []; palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes()
        for (offset,) in struct.iter_unpack('<i',lumps[2][4:4+4*struct.unpack_from('<i',lumps[2])[0]]):
            textures.append(lumps[2][offset:offset+16].split(b'\0')[0].decode() if offset >= 0 else '')
            if textures[-1] in ['d2_red','d2_signa','d2_signb']:
                width,height,start=struct.unpack_from('<3i',lumps[2],offset+16)
                pixels=lumps[2][offset+start:offset+start+width*height]
                red=sum(palette[i*3]>70 and palette[i*3+1]<palette[i*3]*.2 and palette[i*3+2]<palette[i*3]*.2 for i in pixels)
                assert max(pixels)<224, (map_id,textures[-1],'emissive paint')
                assert red/len(pixels)>(.9 if textures[-1]=='d2_red' else .1), (map_id,textures[-1],'paint is not red in the engine palette')
        faces = []
        for plane,side,first,count,texture,*_ in struct.iter_unpack('<Hhihh4Bi',lumps[7]):
            points = [vertices[edges[abs(edge)][0 if edge>=0 else 1]] for edge in surfedges[first:first+count]]
            faces.append(dict(texture=textures[texinfo[texture][8]], points=points, u_axis=texinfo[texture][:3],
                              normal=[n*(-1 if side else 1) for n in planes[plane][:3]]))
        nodes = list(struct.iter_unpack('<i2h6h2H',lumps[5]))
        leaves = list(struct.iter_unpack('<ii6h2H4B',lumps[10]))
        def contents(point):
            node = struct.unpack_from('<i',lumps[14],36)[0]
            while node>=0:
                row=nodes[node];plane=planes[row[0]]
                node=row[1 if sum(point[i]*plane[i] for i in range(3))>=plane[3] else 2]
            return leaves[-node-1][0]
        for mark in layout(map_id):
            cross=quake(mark['cross']);wall=quake(mark['wall']);normal=[mark['normal'][0],-mark['normal'][1],0]
            def near(face,point,tolerance):
                return all(min(p[i] for p in face['points'])-tolerance<=point[i]<=max(p[i] for p in face['points'])+tolerance for i in range(3))
            ground=[f for f in faces if f['texture']=='d2_red' and f['normal'][2]>.9 and near(f,cross,1)]
            letter=[f for f in faces if f['texture']=='d2_sign'+mark['site'].lower() and sum(f['normal'][i]*normal[i] for i in range(3))>.9 and near(f,wall,1)]
            # Some shells (Train's back platform) are only six units thick.
            # Probe just behind the paint, below its brush as well, so a
            # floating sign cannot supply its own "wall" for this check.
            behind=[wall[i]-normal[i]*3 for i in range(3)]
            below=behind.copy();below[2]=cross[2]+20
            backing=contents(behind)==-2 and contents(below)==-2
            assert ground, (map_id,mark['site'],'missing ground cross')
            assert letter, (map_id,mark['site'],'missing wall letter')
            assert backing, (map_id,mark['site'],'letter is not backed by a solid wall')
            right=[-normal[1],normal[0],0]
            assert all(sum(f['u_axis'][i]*right[i] for i in range(3))>0 for f in letter), (map_id,mark['site'],'mirrored glyph UVs')
            results.append(dict(map=map_id,site=mark['site'],red_ground_cross=True,red_wall_letter=True,solid_wall_backing=True,glyph_reads_left_to_right=True))
            print('DE_SITE_MARKINGS_PASS',map_id,mark['site'])
    (ROOT/'test-results/de-site-markings/surface-audit.json').write_text(json.dumps(results,indent=2)+'\n')

if __name__=='__main__':main()
