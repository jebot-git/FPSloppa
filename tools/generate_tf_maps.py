"""Generate two original TF arenas as Quake MAP sources (CC0), using LibreQuake WADs.
Compile with --compiler-dir /path/to/ericw-tools/bin. No original TF geometry is used.
"""
from pathlib import Path
import argparse,subprocess,shutil,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'optional-tf-map-pack'
WAD=Path('librequake.wad')
class Arena:
 def __init__(self,name,title,x=1536,y=768,ceiling=512):
  self.name=name;self.title=title;self.brushes=[];self.entities=[];self.x=x;self.y=y;self.ceiling=ceiling
 def face(self,points,texture):return ' '.join('( %g %g %g )'%p for p in reversed(points))+' '+texture+' 0 0 0 1 1'
 def box(self,a,b,texture='met_brn_block'):
  x,y,z=a;X,Y,Z=b
  assert X>x and Y>y and Z>z,(a,b)
  faces=[[(x,y,z),(x,Y,z),(X,Y,z)],[(x,y,Z),(X,y,Z),(X,Y,Z)],[(x,y,z),(X,y,z),(X,y,Z)],[(X,y,z),(X,Y,z),(X,Y,Z)],[(X,Y,z),(x,Y,z),(x,Y,Z)],[(x,Y,z),(x,y,z),(x,y,Z)]]
  self.brushes.append('{\n'+'\n'.join(self.face(f,texture) for f in faces)+'\n}')
 def ramp_x(self,x0,x1,y0,y1,z0,z1,texture='met_brn_tile2'):
  # Wedge with a sloped upper plane; same outward winding as box faces.
  bottom=min(z0,z1)-32
  faces=[[(x0,y0,bottom),(x0,y1,bottom),(x1,y1,bottom)],[(x0,y0,z0),(x1,y0,z1),(x1,y1,z1)],[(x0,y0,bottom),(x1,y0,bottom),(x1,y0,z1)],[(x1,y0,bottom),(x1,y1,bottom),(x1,y1,z1)],[(x1,y1,bottom),(x0,y1,bottom),(x0,y1,z0)],[(x0,y1,bottom),(x0,y0,bottom),(x0,y0,z0)]]
  self.brushes.append('{\n'+'\n'.join(self.face(f,texture) for f in faces)+'\n}')
 def ent(self,kind,pos,**fields):self.entities.append({'classname':kind,'origin':'%g %g %g'%pos,**{k:str(v) for k,v in fields.items()}})
 def shell(self,floor=True):
  x,y,h=self.x,self.y,self.ceiling
  if floor:self.box((-x,-y,-64),(x,y,0),'met_brn_tile2')
  self.box((-x-32,-y-32,-192),(-x,y+32,h),'med_csl_brk7_2');self.box((x,-y-32,-192),(x+32,y+32,h),'med_csl_brk7_2')
  self.box((-x,-y-32,-192),(x,-y,h),'med_csl_brk7_2');self.box((-x,y,-192),(x,y+32,h),'med_csl_brk7_2')
  self.box((-x-32,-y-32,h),(x+32,y+32,h+32),'sky_star')
 def mirrored_box(self,side,a,b,texture):
  if side<0:a,b=(-b[0],a[1],a[2]),(-a[0],b[1],b[2])
  self.box(a,b,texture)
 def team(self,side,flag,spawns,supply,capture=None):
  color='red' if side<0 else 'blue';number=1 if side<0 else 2
  self.ent('item_flag_team'+str(number),flag)
  for x,y,z in spawns:
   self.ent('info_player_team'+str(number),(x,y,z),angle=0 if side<0 else 180)
   self.ent('info_player_deathmatch',(x,y,z),angle=0 if side<0 else 180)
  self.ent('info_tf_resupply_'+color,supply)
  if capture:self.ent('info_tf_capture_'+color,capture)
 def lights(self):
  for x in range(-self.x+192,self.x,384):
   for y in [-self.y+128,0,self.y-128]:self.ent('light',(x,y,160),light=180,delay=2)
 def write(self):
  world={'classname':'worldspawn','message':self.title,'wad':'librequake.wad','_sunlight':'200','_sun_mangle':'35 -65 0','_minlight':'60','worldtype':'0'}
  def entity(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
  text='{\n'+entity(world)+'\n'+'\n'.join(self.brushes)+'\n}\n'+'\n'.join('{\n'+entity(e)+'\n}' for e in self.entities)+'\n'
  p=OUT/'source'/(self.name+'.map');p.write_text(text);return p

def ironspan():
 a=Arena('tf_ironspan','Ironspan · Twin Foundries');a.shell(False)
 # Bridge, two dry flanks, and a traversable water route under the bridge.
 a.box((-1536,-768,-192),(-640,768,0),'met_brn_tile2');a.box((640,-768,-192),(1536,768,0),'met_brn_tile2')
 for lo,hi in [(-768,-256),(256,768)]:a.box((-640,lo,-192),(640,hi,0),'met_brn_tile2')
 a.box((-640,-256,-192),(640,256,-128),'med_csl_brk7_2');a.box((-640,-256,-128),(640,256,-32),'*water2')
 a.box((-640,-96,-24),(640,96,0),'met_brn_slat')
 for lo,hi in [(-256,-104),(104,256)]:
  a.ramp_x(-640,-384,lo,hi,0,-128);a.ramp_x(384,640,lo,hi,-128,0)
 # Side cover breaks long uninterrupted sniper views.
 for x,y in [(-256,-512),(256,512),(-64,384),(64,-384)]:a.box((x-48,y-64,0),(x+48,y+64,80),'met_brn_block')
 for side in [-1,1]:
  tex='wall_red_a' if side<0 else 'wall_blue_a'
  def box(lo,hi,t=tex):a.mirrored_box(side,lo,hi,t)
  # Three wide front entries, a balcony above, and two rear approaches to it.
  for lo,hi in [(-512,-448),(-288,-80),(80,288),(448,512)]:box((640,lo,0),(688,hi,256))
  box((640,-512,128),(688,512,160));box((640,-512,256),(864,512,280),'met_brn_pan1')
  box((688,-480,112),(928,480,128),'met_brn_slat')
  for y0,y1 in [(-448,-288),(288,448)]:
   if side>0:a.ramp_x(928,1408,y0,y1,128,0)
   else:a.ramp_x(-1408,-928,y0,y1,0,128)
  # Rear flag vault has two entrances and a central shielding partition.
  box((1088,-128,0),(1120,128,176),'met_brn_block')
  box((1120,-288,0),(1504,-256,192));box((1120,256,0),(1504,288,192))
  # Resupply alcoves are screened from all three courtyard sightlines.
  for y0,y1 in [(-768,-544),(544,768)]:box((896,y0,0),(944,y1,224));box((944,y0,192),(1504,y1,224),'met_brn_pan1')
  # Buttresses, light strips and workshop equipment provide readable landmarks.
  for y in [-480,480]:box((616,y-16,0),(640,y+16,224),'met_brn_slat');box((612,y-12,80),(616,y+12,176),'tlight12')
  box((1456,-80,0),(1504,80,96),'compbase')
  a.team(side,(side*1376,0,24),[(side*1280,y,24) for y in [-672,-576,576,672]],(side*1408,608,24))
  a.ent('item_shells',(side*768,352,160));a.ent('item_health',(side*864,-352,32))
 a.ent('info_player_start',(-1280,576,24),angle=0);a.lights();return a

def relayworks():
 a=Arena('tf_relayworks','Relayworks · Signal Towers',1408,832,640);a.shell()
 # Central divider offers a ground tunnel, two flanks and an upper crossing.
 for lo,hi in [(-352,-96),(96,352)]:a.box((-80,lo,0),(80,hi,224),'met_brn_block')
 a.box((-80,-352,128),(80,352,224),'met_brn_pan1')
 for side in [-1,1]:
  tex='wall_red_a' if side<0 else 'wall_blue_a'
  def box(lo,hi,t=tex):a.mirrored_box(side,lo,hi,t)
  for lo,hi in [(-576,-432),(-272,-96),(96,272),(432,576)]:box((512,lo,0),(560,hi,320))
  box((512,-576,128),(560,576,192));box((512,-576,288),(560,576,320))
  # Upper gallery/flag platform, reached by two long shallow ramps.
  box((1120,-448,176),(1344,448,192),'met_brn_slat')
  for lo,hi in [(-448,-288),(288,448)]:
   if side>0:a.ramp_x(608,1120,lo,hi,0,192)
   else:a.ramp_x(-1120,-608,lo,hi,192,0)
   box((1120,lo,176),(1344,hi,192),'met_brn_slat')
  # Partial backstop keeps the flag visible but shields it from the front gate.
  box((976,-112,192),(1008,112,320));box((992,-480,192),(1376,-448,384));box((992,448,192),(1376,480,384))
  box((992,-480,384),(1376,480,408),'met_brn_pan1')
  for xx in [1024,1312]:
   for yy in [-384,384]:box((xx-16,yy-16,0),(xx+16,yy+16,192),'met_brn_slat')
  for y0,y1 in [(-832,-608),(608,832)]:box((768,y0,0),(816,y1,192));box((816,y0,192),(1376,y1,224),'met_brn_pan1')
  for y in [-528,528]:
   box((600,y-32,0),(728,y+32,96),'compbase');box((1360,y-48,0),(1408,y+48,288),'met_brn_slat')
  # A bank of relay housings screens the upper crossing from the flag room.
  for y in [-240,240]:box((256,y-48,0),(352,y+48,96),'compbase')
  if side>0:a.ramp_x(80,464,480,640,224,0)
  else:a.ramp_x(-464,-80,-640,-480,0,224)
  box((0,352 if side>0 else -640,208),(80,640 if side>0 else -352,224),'met_brn_slat')
  a.team(side,(side*1216,0,216),[(side*1120,y,24) for y in [-752,-656,656,752]],(side*1280,704,24),(side*768,0,24))
  a.ent('item_shells',(side*896,0,24));a.ent('item_health',(side*352,576,24))
 a.ent('info_player_start',(-1120,656,24),angle=0);a.lights();return a

def main():
 global WAD
 p=argparse.ArgumentParser();p.add_argument('--compiler-dir',type=Path);p.add_argument('--wad',type=Path,required=True);args=p.parse_args();WAD=args.wad.resolve();OUT.mkdir(exist_ok=True);(OUT/'source').mkdir(exist_ok=True)
 report=[]
 for arena in [ironspan(),relayworks()]:
  source=arena.write()
  if args.compiler_dir:
   compiled=OUT/(arena.name+'.bsp')
   for exe,flags in [('qbsp',['-wadpath',str(WAD.parent),str(source),str(compiled)]),('vis',['-fast',str(compiled)]),('light',['-extra','-lit',str(compiled)])]:
    binary=args.compiler_dir/exe;binary.chmod(0o755)
    log=ROOT/'test-results'/f'{arena.name}-{exe}.log'
    with log.open('w') as out:subprocess.run([str(binary),*flags],stdout=out,stderr=subprocess.STDOUT,check=True)
   report.append({'id':arena.name,'title':arena.title,'sha256':hashlib.sha256(compiled.read_bytes()).hexdigest(),'brushes':len(arena.brushes),'team_spawns':8,'original_geometry':True})
  print('GENERATED',arena.name,len(arena.brushes),'brushes',flush=True)
 (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 (OUT/'tf_maplist.txt').write_text('tf_ironspan\ntf_relayworks\n')
if __name__=='__main__':main()
