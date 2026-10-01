"""Starsiege-inspired authored silhouettes, following the user's Josh Buck reference."""
import math,bpy
from mathutils import Vector,Matrix
from designs import mesh,lathe,side_profile
from tribes_refine import refine
from tribes_detail import refine as detail

def build_tribes(slot,anchors,mat):
 key='tribes_'+str(slot);m=anchors[key]['muzzle'];tip=-m[2]-.012;z=m[1]
 steel=mat('ST machined alloy',(.29,.32,.34),.7);dark=mat('ST blued steel',(.043,.052,.064),.6);black=mat('ST stippled rubber',(.025,.03,.035),.03)
 bronze=mat('ST heat shield bronze',(.20,.14,.085),.5);wood=mat('ST walnut furniture',(.20,.082,.030),.04);cyan=mat('ST cyan emitter',(.018,.26,.36),.2);red=mat('ST safety enamel',(.3,.035,.018),.2)
 parts=[]
 def profile(name,outline,width,material):
  ob=side_profile(name,outline,width,material);parts.append(ob);return ob
 def ring(name,section,center=(0,z),material=steel,n=24):
  ob=lathe(name,section,center,material,n);parts.append(ob);return ob
 def loft(name,sections,material):
  # Chamfered cross sections vary in all three dimensions; sloping shoulders
  # and waists are authored into the shell instead of stacked boxes.
  vertices=[]
  shape=[(-1,-.6),(-.6,-1),(.6,-1),(1,-.6),(1,.6),(.6,1),(-.6,1),(-1,.6)]
  for y,w,h,c in sections:vertices.extend((a*w/2,y,c+b*h/2) for a,b in shape)
  faces=[tuple(reversed(range(8))),tuple(range((len(sections)-1)*8,len(sections)*8))]
  faces +=[(s*8+i,s*8+(i+1)%8,(s+1)*8+(i+1)%8,(s+1)*8+i) for s in range(len(sections)-1) for i in range(8)]
  ob=mesh(name,vertices,faces,material);parts.append(ob);return ob
 def tube(name,start,end,r,bore,center=(0,z),material=steel):
  section=[(start,r*.9),(start+.012,r),(end-.014,r),(end,r*.94),(end,bore),(start,bore)]
  if name in ['HeavyRotaryBarrel','LaserFocusingBarrel']:
   section=[(start,r),(start+.05,r),(start+.073,r*.78),(end-.09,r*.78),(end-.07,r*.92),(end-.035,r*.92),(end-.02,r),(end,r),(end,bore),(start,bore)]
  return ring(name,section,center,material,8 if name in ['HeavyRotaryBarrel','LaserFocusingBarrel'] else 12 if name=='HeavyMortarTube' else 24)
 def lamp(name,pos,color=(.05,.65,1)):
  x,y,h=pos;ob=profile(name,[(y-.014,h-.010),(y-.014,h+.010),(y+.014,h+.010),(y+.014,h-.010)],.003,cyan);ob.data.transform(Matrix.Translation(Vector((x,0,0))));ob['lamp']=list(color)
 def grip(wooden=False):
  profile('ContouredGrip',[(-.075,.065),(.036,.076),(.078,.012),(.050,-.115),(.012,-.155),(-.067,-.143),(-.087,-.090)],.084,wood if wooden else dark)
  for side in [-1,1]:
   ob=profile('GripInset',[(-.063,.025),(.015,.031),(.036,-.085),(.012,-.125),(-.052,-.116)],.004,black);ob.data.transform(Matrix.Translation(Vector((side*.043,0,0))))
  profile('TriggerGuard',[(.015,.035),(.135,.033),(.158,.012),(.15,-.060),(.125,-.079),(.029,-.072),(.029,-.056),(.126,-.061),(.136,-.047),(.139,.012),(.12,.019),(.015,.021)],.025,dark)
  profile('CurvedTrigger',[(.068,.029),(.08,.024),(.065,-.025),(.050,-.039),(.047,-.028),(.058,-.01)],.010,steel)
 def seams(y0,y1,width,height):
  for side in [-1,1]:
   for y in [y0,y1]:
    bolt=lathe('InsetFastener',[(0,.007),(.002,.007),(.002,.003),(0,.003)],(0,0),steel,8)
    bolt.data.transform(Matrix.Translation(Vector((side*width,y,height)))@Matrix.Rotation(-side*math.pi/2,4,'Z'));parts.append(bolt)
 # Contoured donor lower receiver is fitted after the upper assembly.
 if slot==3:
  # Flat spinfusor deck, exposed energy disc, sloped rear electronics and rail.
  loft('DiscLaunchDeck',[(-.12,.12,.11,.11),(-.06,.18,.14,.105),(tip-.09,.22,.10,.105),(tip,.20,.10,.105)],steel)
  loft('RearElectronics',[(-.10,.15,.14,.20),(-.02,.18,.16,.21),(.18,.18,.16,.21),(.23,.13,.08,.17)],dark)
  center_y=tip*.58;disc=ring('ExposedMagneticDisc',[(0,.165),(.012,.184),(.027,.185),(.047,.151),(.047,.055),(0,.055)],(0,0),cyan,40)
  disc.data.transform(Matrix.Translation(Vector((0,center_y,.192)))@Matrix.Rotation(math.pi/2,4,'X'));pivot=Vector((0,center_y,.215));disc.data.transform(Matrix.Translation(-pivot));disc.location=pivot;disc['motion']='spin';disc['amount']=[0,1,0];disc['lamp']=[.05,.6,1]
  profile('OverheadSightRail',[(-.10,.225),(-.01,.34),(.43,.34),(.45,.315),(.035,.305),(-.07,.21)],.05,steel)
  for side in [-1,1]:
   ob=profile('DiscGuideRail',[(.22,.10),(.22,.155),(tip,.155),(tip,.10)],.025,dark);ob.data.transform(Matrix.Translation(Vector((side*.105,0,0))))
   lamp('DiscReady',(side*.092,.12,.22))
 elif slot==2:
  loft('RotaryReceiver',[(-.15,.16,.20,.16),(-.10,.23,.26,.16),(.25,.25,.25,.16),(.34,.22,.22,.16)],steel)
  loft('RotaryCollar',[(.25,.25,.25,z),(.29,.29,.29,z),(.36,.29,.29,z),(.38,.26,.26,z)],dark)
  for i in range(4):
   a=math.pi/4+i*math.pi/2;c=(.090*math.cos(a),z+.090*math.sin(a))
   ob=tube('HeavyRotaryBarrel',.30,tip,.064,.040,c,steel);pivot=Vector((0,0,z));ob.data.transform(Matrix.Translation(-pivot));ob.location=pivot;ob['motion']='spin';ob['amount']=[0,0,1]
  tube('RotarySpindle',.31,tip-.04,.025,.008)
  # Rails follow the corners of the four-barrel head.
  for side in [-1,1]:
   ob=profile('ClusterGuide',[(.30,z-.015),(.34,z+.02),(tip-.015,z+.02),(tip,z-.015)],.027,dark);ob.data.transform(Matrix.Translation(Vector((side*.16,0,0))))
  seams(-.065,.18,.117,.16)
 elif slot==5:
  # Stacked focusing barrels and integrated wood stock; no modern telescopic
  # sight, because the original uses the player's image enhancer.
  loft('LaserReceiver',[(-.12,.11,.18,.12),(-.07,.15,.20,.14),(.57,.15,.20,.14),(.69,.14,.17,.15)],steel)
  profile('WalnutLowerStock',[(-.12,.105),(.64,.105),(.66,.01),(.51,-.016),(.12,.017),(-.09,-.08)],.153,wood)
  for height,r in [(z,.049),(z-.109,.049)]:tube('LaserFocusingBarrel',.53,tip if height==z else tip-.015,r,.025,(0,height),steel)
  loft('UpperHeatGuard',[(.24,.161,.105,.223),(.29,.17,.105,.223),(.53,.17,.105,.223),(.59,.15,.105,.223)],dark)
  for i in range(8):
   y=.28+i*.032;profile('HeatGuardRib',[(y,.246),(y+.018,.28),(y+.027,.278),(y+.010,.244)],.166,black)
  lamp('LaserReady',(.078,.60,.12),(.1,1,.2))
 elif slot==1:
  loft('PlasmaReceiver',[(-.13,.13,.12,.105),(-.08,.19,.15,.11),(.41,.22,.16,.105),(.49,.18,.14,.11)],steel)
  profile('WalnutBelly',[(-.13,.06),(.44,.06),(.40,.009),(.10,-.008),(-.09,.008)],.19,wood)
  tube('PlasmaEmitter',.28,tip,.090,.060)
  # Eight shaped armor strips form the broad vented hood, with actual slots.
  for k in range(8):
   a=math.pi*.12+k*math.pi*.76/7;n=4;verts=[]
   for y,r in [(.18,.15),(.24,.195),(.47,.195),(.54,.13)]:
    for j in range(n):
     angle=a+(j/(n-1)-.5)*.23;verts.append((r*math.cos(angle),y,z+r*math.sin(angle)))
   faces=[(s*n+j,s*n+j+1,(s+1)*n+j+1,(s+1)*n+j) for s in range(3) for j in range(n-1)]
   ob=mesh('VentedPlasmaHood',verts,faces,bronze);parts.append(ob);solid=ob.modifiers.new('Cast armor thickness','SOLIDIFY');solid.thickness=.007
  loft('RearPowerCell',[(-.12,.16,.10,.22),(-.08,.18,.13,.235),(.13,.18,.13,.235),(.16,.15,.10,.22)],dark)
  loft('OrangeCellBand',[(-.065,.181,.132,.235),(-.035,.181,.132,.235)],red)
  profile('PlasmaForeGrip',[(.22,.055),(.30,.055),(.40,-.12),(.33,-.14)],.067,dark);lamp('PlasmaReady',(.102,.06,.14),(.2,1,.1))
 elif slot==4:
  loft('GrenadeReceiver',[(-.13,.12,.20,.16),(-.07,.20,.22,.16),(.38,.20,.22,.16),(.44,.14,.16,.17)],dark)
  tube('GrenadeBreech',.38,tip,.119,.077,(0,z),steel)
  # Front housing keeps the characteristic faceted ST muzzle.
  tube('FacetedMuzzle',tip-.19,tip,.145,.079,(0,z),dark).data.transform(Matrix.Identity(4))
  profile('LowerForeStock',[(.06,.085),(.46,.085),(.43,-.025),(.33,-.04),(.10,-.01)],.12,bronze)
  profile('RedRangeSight',[(.10,.27),(.12,.32),(.17,.32),(.19,.27)],.05,red)
  lamp('GrenadeReady',(.137,tip-.09,z+.03),(.2,1,.1));seams(-.055,.31,.101,.18)
 elif slot==7:
  loft('MortarBreech',[(-.15,.16,.21,.13),(-.09,.28,.27,.16),(.29,.29,.27,.17),(.39,.24,.24,.20)],dark)
  tube('HeavyMortarTube',.22,tip,.17,.135,(0,z),bronze)
  for y in [.29,.63,tip-.06]:ring('MortarCollar',[(y,.173),(y+.014,.183),(y+.039,.183),(y+.05,.173),(y+.05,.167),(y,.167)],(0,z),steel)
  for side in [-1,1]:
   ob=profile('MortarCarryRail',[(.14,.20),(.20,.12),(.69,.12),(.73,.18),(.70,.19),(.66,.16),(.23,.16),(.20,.21)],.03,dark);ob.data.transform(Matrix.Translation(Vector((side*.185,0,0))))
  lamp('MortarArmed',(.147,.13,.19),(.8,.3,.02))
 else:
  # Compact blaster / dual ELF fork / service probe / target designator.
  loft('InstrumentReceiver',[(-.12,.10,.15,.13),(-.06,.16,.21,.16),(.26,.17,.20,.16),(.34,.12,.15,.17)],steel)
  if slot==0:
   for x in [-.047,.047]:tube('BlasterEmitter',.24,tip,.041,.024,(x,z),dark)
   lamp('BlasterReady',(.085,.18,.18))
  elif slot in [6,8]:
   for side in [-1,1]:
    ob=profile('CurvedEmitterFork',[(.21,.11),(.28,.21),(tip-.05,.23),(tip,.19),(tip,.145),(tip-.025,.14),(.32,.15),(.28,.10)],.045,steel);ob.data.transform(Matrix.Translation(Vector((side*.085,0,0))))
    tube('FieldCoil',tip-.19,tip-.06,.038,.027,(side*.085,z),dark)
    lamp('ProbeEnergy',(side*.11,tip-.06,.18),(.1,1,.45) if slot==8 else (.1,.4,1))
   tube('ServiceCell',.035,.23,.084,.065,(0,.19),red if slot==8 else bronze)
  else:tube('TargetingLens',.22,tip,.054,.035,(0,z),dark);lamp('TargetingReady',(.085,.18,.19))
  seams(-.015,.21,.085,.17)
 return detail(refine(parts,slot,mat,z),slot,mat,z,tip)
