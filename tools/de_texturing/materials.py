"""Shared DE art pass. Only face materials/UVs change; brush planes stay intact.

Original donor miptextures (including all mip levels) are copied byte for byte.
Generated source art is converted to the engine palette with filtered mipmaps.
"""
from pathlib import Path
import hashlib, json, re, shutil, struct
import numpy as np
from PIL import Image, ImageDraw
from pressureworks.build import materials as library_materials, wad_records
from texture_replacements.build import miptex

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'maps/DEMaterials'
FACE = re.compile(r'^(\( .*\)) (\S+) ([-\d.e+]+) ([-\d.e+]+) ([-\d.e+]+) ([-\d.e+]+) ([-\d.e+]+)$')
POINT = re.compile(r'\( ([^()]+) \)')
SHA = lambda raw: hashlib.sha256(raw).hexdigest()

# Textures are material roles, not randomized substitutions. World-aligned UVs
# keep adjacent shell brushes continuous; doors/crates use local panel alignment.
PALETTES = {
 'desert': dict(wall='de_plaster',floor='de_paving',ceiling='med_tanwall1',trim='med_tanwall1',crate='ind_wd01_brwn1',wood='med_dr3a_blu',metal='metal_iron1_01',rock='med_rock3_bump'),
 'industrial': dict(wall='ind_w01_grey2',floor='ind_dp01_grey2',ceiling='ind_w04_grey1',trim='metal_iron1_01',crate='ind_wd01_brwn1',wood='ind_door1_grey1',metal='metal_iron1_01',vent='ind_w07_grey1',tank='ind_w08_ylw1'),
 'village': dict(wall='de_plaster',floor='med_cobstn2_1',ceiling='ind_wd04_brwn1',trim='de_paving',crate='ind_wd01_brwn1',wood='med_dr3a_blu',metal='metal_iron1_01',window='ind_win1_blk1a',roof='ind_wdt01_brwn1'),
 'ruins': dict(wall='de_ruins',floor='de_ruins',ceiling='med_rock5_g1',trim='med_tanwall1',crate='ind_wd01_brwn1',wood='med_wood2_plk1',metal='metal_iron1_01',carved='carved',moss='grass1',rope='med_wood2_plk1'),
 'rail': dict(wall='ind_brk01_red1',floor='ind_w02_grey2',ceiling='ind_w04_grey1',trim='metal_iron1_01',crate='ind_wd01_brwn1',wood='ind_wd04_brwn1',metal='metal_iron1_01',wagon='ind_cont1_rst1',wagon2='ind_cont1_grn1',tank='ind_w08_grey1'),
}
ALIASES = {'d2_stone':'wall','d2_floor':'floor','d2_trim':'trim','d2_crate':'crate','d2_door':'wood','d2_iron':'metal','d2_rock':'rock'}

def generated():
    palette = (ROOT/'deathmatch/maps/palette.lmp').read_bytes()
    quant = Image.new('P',(1,1)); quant.putpalette(palette[:224*3]+palette[:3]*32)
    records, sources = {}, {}
    for kind in ['plaster','ruins','paving']:
        name='de_'+kind;path=ART/'source'/(kind+'.png')
        im=Image.open(path).convert('RGB').resize((512,512),Image.Resampling.LANCZOS)
        raw=bytearray(struct.pack('<16s6I',name.encode(),512,512,0,0,0,0))
        for level in range(4):
            struct.pack_into('<I',raw,24+4*level,len(raw))
            indexed=im.resize((512>>level,512>>level),Image.Resampling.BOX).quantize(palette=quant,dither=Image.Dither.NONE)
            assert max(indexed.tobytes())<224
            raw.extend(indexed.tobytes())
        records[name]=bytes(raw)
        sources[name]=dict(source='maps/DEMaterials/source/'+path.name,source_sha256=SHA(path.read_bytes()),sha256=SHA(raw),format='512px palette albedo; four filtered mip levels',license='Original generated artwork; see SOURCES.md',generator='built-in imagegen')
    return records,sources

def style(a, theme):
    """Retexture the complete generated brush list without changing its planes."""
    palette=PALETTES[theme]
    def brush(source):
        rows=[]
        for line in source.splitlines():
            match=FACE.match(line)
            if not match:rows.append(line);continue
            planes,old,*uv=match.groups();role=ALIASES.get(old,old)
            if old.startswith(('sky','*','d2_sign')) or role in ['mark','d2_red','carved']:
                rows.append(line);continue
            points=np.array([list(map(float,p.split())) for p in POINT.findall(planes)])
            lo=points.min(axis=0);hi=points.max(axis=0);center=(lo+hi)/2
            normal=np.cross(points[1]-points[0],points[2]-points[0]);normal/=np.linalg.norm(normal)
            # Downward-facing undersides of the room shell are actual ceilings.
            ceiling=role=='wall' and abs(normal[2])>.9 and normal[2]>0
            name=palette.get('ceiling' if ceiling else role,old)
            if role=='wall' and not ceiling and abs(normal[2])<.1:
                u=400+center[0]/6;v=300-center[1]/6
                # Distinct, stable architectural zones. No per-brush randomness.
                if theme=='desert' and (center[2]<180 and u<410 and v>340):name='med_tanwall1'
                if theme=='village' and (u>575 or u<200):name='ind_brk02_wht1'
                if theme=='industrial' and center[2]<0:name='ind_w02_grey1'
                if theme=='rail' and center[2]<160 and v>390:name='ind_brk02_wht1'
            scale=.5 if name.startswith(('ind_','metal_')) else 1.0
            if name=='de_plaster':scale=.5
            if name in ['de_paving','de_ruins']:scale=.375 if role=='floor' else .5
            if name.startswith('med_rock'):scale=2.0
            if name.startswith('med_cobstn'):scale=.75
            if role=='trim' and name=='de_paving':scale=.25
            shift_u=shift_v=0.0;su=sv=scale
            if role in ['crate','wagon','wagon2','window']:
                axis=int(np.argmax(abs(normal)));ux=1 if axis==0 else 0;vx=1 if axis==2 else 2
                # Select a complete donor panel through sampling only. Pixels and
                # names remain untouched, including the Makkon mip chain.
                tile_u,tile_v=(128,128) if role=='crate' else (512,128) if role.startswith('wagon') else (128,256)
                su=max(hi[ux]-lo[ux],1)/tile_u;sv=max(hi[vx]-lo[vx],1)/tile_v
                shift_u=-lo[ux]/su;shift_v=(hi[vx] if axis!=2 else -lo[vx])/sv
            rows.append(f'{planes} {name} {shift_u:g} {shift_v:g} 0 {su:g} {sv:g}')
        return '\n'.join(rows)
    a.brushes=[brush(b) for b in a.brushes]
    if hasattr(a,'detail_brushes'):a.detail_brushes=[brush(b) for b in a.detail_brushes]

def write_wad(a, folder, filename, originals):
    faces='\n'.join(a.brushes+getattr(a,'detail_brushes',[]))
    names={m.group(2) for line in faces.splitlines() if (m:=FACE.match(line))}
    records,sources=generated()
    # Keep existing source WADs usable offline, with hash-checked provenance.
    known_path=folder/'texture-sources.json'
    if (folder/filename).exists() and known_path.exists():
        known=json.loads(known_path.read_text())
        for name,raw in wad_records(folder/filename).items():
            if name in known and SHA(raw)==known[name]['sha256'] and name not in records:
                records[name]=raw;sources[name]=known[name]
    missing=names-records.keys()-originals.keys()
    if missing:
        donors,provenance=library_materials(missing,ROOT/'tools/pressureworks/local/librequake-dev.zip')
        for name in missing:records[name]=donors[name];sources[name]=provenance[name]
    for name in names & originals.keys():
        records[name]=miptex(name,originals[name]);sources[name]=dict(source='Original DE builder artwork',license='CC0-1.0',sha256=SHA(records[name]))
    wad=bytearray(b'WAD2'+bytes(8));directory=[]
    for name in sorted(names):
        raw=records[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (folder/filename).write_bytes(wad);known_path.write_text(json.dumps({n:sources[n] for n in sorted(names)},indent=2)+'\n')
    for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','CC0-1.0.txt']:
        shutil.copy2(ROOT/'maps/Pressureworks'/name,folder/name)
    sheet=Image.new('RGB',(160*5,184*((len(names)+4)//5)),(28,30,33));draw=ImageDraw.Draw(sheet)
    for i,name in enumerate(sorted(names)):
        raw=records[name];w,h,offset=struct.unpack_from('<III',raw,16)
        im=Image.frombytes('P',(w,h),raw[offset:offset+w*h]);im.putpalette((ROOT/'deathmatch/maps/palette.lmp').read_bytes());im=im.convert('RGB');im.thumbnail((156,156))
        x=i%5*160;y=i//5*184;sheet.paste(im,(x,y));draw.text((x,y+160),name,fill='white')
    sheet.save(folder/'materials.png')

def bind_hash(id, digest):
    path=ROOT/'deathmatch/maps/defusal.json';rules=json.loads(path.read_text())
    if id in rules:rules[id]['sha256']=digest;path.write_text(json.dumps(rules,indent=2)+'\n')
    path=ROOT/'deathmatch/maps/skies/SOURCES.json';data=json.loads(path.read_text())
    data['map_sources'][digest]=id;path.write_text(json.dumps(data,indent=2)+'\n')
