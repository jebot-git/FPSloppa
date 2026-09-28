"""Prepare the shared armour atlas and pack the two permitted MEC-VAL textures.
MEC-VAL-derived images retain KEIV's terms; see sources/README.md.
"""
from pathlib import Path
import io, json, struct, random
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/tribes/refined'
raw=(ROOT/'tools/tribes/sources/mec_val_white_fox.vrm').read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);binary=28+length
atlas=Image.new('RGB',(2048,1024),(22,28,31))
for slot,match in enumerate(['Onepiece_00_CLOTH','Tops_01_CLOTH_02']):
    mat=next(m for m in doc['materials'] if match in m['name'])
    tex=mat['pbrMetallicRoughness']['baseColorTexture']['index']
    view=doc['bufferViews'][doc['images'][doc['textures'][tex]['source']]['bufferView']]
    image=Image.open(io.BytesIO(raw[binary+view.get('byteOffset',0):binary+view.get('byteOffset',0)+view['byteLength']])).convert('RGBA')
    image=image.resize((1024,1024),Image.Resampling.LANCZOS)
    # Body selection omits the cutout attachments. Solid dark backing avoids
    # expensive alpha drawing and seals the selected fitted garment surfaces.
    atlas.paste(image,(slot*1024,0),image)
atlas.save(OUT/'armour-suit.png')

colors=['#b6bcbc','#263138','#586770','#c1bfab','#121b20','#66c7d8','#d6ae56','#8d9ca4']
im=Image.new('RGB',(1024,512));d=ImageDraw.Draw(im);rng=random.Random(4126)
for i,c in enumerate(colors):
    x=i%4*256;y=i//4*256;rgb=tuple(bytes.fromhex(c[1:]))
    d.rectangle((x,y,x+255,y+255),fill=rgb)
    for j in range(4800):
        px=x+rng.randrange(256);py=y+rng.randrange(256);v=rng.randint(-5,5)
        d.point((px,py),fill=tuple(max(0,min(255,b+v)) for b in rgb))
    if i in [0,1,2,3,7]:
        dark=tuple(int(b*.56) for b in rgb);light=tuple(min(255,int(b*1.12+6)) for b in rgb)
        # Fine seams and broad edge wear remain readable after mipmapping.
        d.rounded_rectangle((x+14,y+14,x+241,y+241),radius=20,outline=dark,width=3)
        d.line((x+31,y+20,x+221,y+20),fill=light,width=2)
        for yy in [42,210]:
            for xx in [42,210]:
                d.ellipse((x+xx-4,y+yy-4,x+xx+4,y+yy+4),fill=dark)
                d.line((x+xx-2,y+yy,x+xx+2,y+yy),fill=light,width=1)
        for j in range(110):
            xx=x+rng.randrange(22,234);yy=y+rng.randrange(22,234)
            d.line((xx,yy,min(x+234,xx+rng.randrange(1,9)),yy),fill=light,width=1)
    if i==4:
        for y2 in range(y, y+256, 6):d.line((x,y2,x+255,y2),fill=(29,39,44),width=1)
im.save(OUT/'armour-finish.png')
print('Shared armour finish and MEC-VAL suit atlases prepared')
