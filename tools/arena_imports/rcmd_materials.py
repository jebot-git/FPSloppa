"""Semantic replacements for unavailable retail textures, preserving supplied images."""
from pathlib import Path
import hashlib,struct,io,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
class Materials:
 def __init__(self,bank,files):
  from makkon.theme import wad_textures
  self.bank=dict(bank);self.sources={};self.files={n.lower():b for n,b in files.items()};self.images={}
  for path in ['maps/Quake/texture-dictionary/makkon-used.wad','maps/CTFStudies/materials.wad']:
   self.bank.update(wad_textures((ROOT/path).read_bytes()))
  self.palette=Image.new('P',(1,1));self.palette.putpalette((ROOT/'deathmatch/maps/palette.lmp').read_bytes())
 def supplied(self,name):
  key=name.lower().removeprefix('textures/')
  for ext in ['.tga','.png','.jpg','.jpeg']:
   for path in [key+ext,'textures/'+key+ext]:
    if path not in self.files:continue
    im=Image.open(io.BytesIO(self.files[path])).convert('RGB')
    # Preserve tiling dimensions (Quake miptextures require multiples of 16).
    w,h=im.size
    if w%16 or h%16 or w>2048 or h>2048:continue
    alias='rc'+hashlib.sha256(name.encode()).hexdigest()[:12]
    raw=bytearray(struct.pack('<16s6I',alias.encode(),w,h,0,0,0,0))
    for level in range(4):
     mip=im.resize((w>>level,h>>level),Image.Resampling.LANCZOS).quantize(palette=self.palette,dither=Image.Dither.NONE)
     struct.pack_into('<I',raw,24+level*4,len(raw));raw.extend(mip.tobytes())
    self.bank[alias]=bytes(raw);self.sources[alias]=dict(kind='packaged image',member=path,sha256=hashlib.sha256(self.files[path]).hexdigest(),conversion='Quake palette, Lanczos mipmaps',width=w,height=h)
    return alias
  return None
 def material(self,name):
  if name in self.images:return self.images[name]
  n=name.lower();pick=None
  for token,texture in [('sky','sky_star'),('clip','clip'),('trigger','trigger'),('nodraw','skip'),('caulk','skip'),('lava','*lava1'),('slime','*slime1'),('water','*water2')]:
   if token in n:pick=texture;break
  if pick is None:pick=self.supplied(name)
  if pick is None:
   groups=[(r'tele', ['ind_dp01_prpl1','ind_dp01_blu1']),
    (r'light|ceil1_1|ceil1_2', ['tlight12']),
    (r'wood|timber',['med_wood4']),
    (r'crate|box|cont', ['ind_cont1_ylw1','ind_cont2_blk1']),
    (r'rock|stone|grnd|ground|dirt|sand', ['med_rock3','med_rock5','med_cobstn1_2']),
    (r'brick|block|wall.*stone', ['ind_brk01_brwn','ind_brk02_gry1','med_csl_brk11','med_csl_brk15']),
    (r'floor|flr|clang|grate|grid|step|stair', ['met_brn_tile2','metal_iron1_07','metal_iron1_10','med_flat5a']),
    (r'trim|border|beam|girder|support|edge', ['metal_iron1_04','metal_iron1_06','metal_iron1_08','met_brn_slat']),
    (r'door|dr[0-9]', ['ind_dp01_grey1','ind_dp01_rst1','ind_dp01_blk1']),
    (r'ceil|roof', ['metal_iron1_02','metal_iron1_13','ind_w04_grey1']),
    (r'comp|tech|base|panel', ['compbase','ind_w02_grey1','ind_w04_blk1']),
    (r'metal|mtl|rust|plate', ['metal_iron1_01','metal_iron1_05','metal_copp_04','met_brn_block'])]
   category='wall';choices=['ind_w02_grey1','ind_w04_grey1','ind_w04_rst1','met_brn_pan1','met_brn_block','ind_brk02_gry1','ind_w06_rst1','metal_iron1_09']
   for pattern,options in groups:
    if re.search(pattern,n):choices=options;category=pattern;break
   # Retain explicit colour conventions, especially team-coloured route landmarks.
   if re.search(r'(^|[/_])red([/_0-9]|$)',n):choices=['ind_w02_red1','ind_dp01_red1','stn_gw10_red1']
   elif re.search(r'(^|[/_])blu(e)?([/_0-9]|$)',n):choices=['ind_w02_blu1','ind_dp01_blu1','stn_gw10_blu1']
   choices=[x for x in choices if x in self.bank];pick=choices[int(hashlib.sha256(n.encode()).hexdigest()[:8],16)%len(choices)]
   self.sources[pick]=dict(kind='existing project donor',category=category,license='Existing LibreQuake/Makkon project notices; original donor pixels and four mip levels retained')
  self.images[name]=pick;return pick
