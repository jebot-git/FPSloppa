"""Weapon-specific silhouettes for model_weapons.py (executed in its namespace).
Original game art; dimensions are stylized model units, not manufacturing data.
"""
SIGHT_POINTS={}

def cut_opening(body,outline,width=.30):
 cutter=profile('Temporary aperture',outline,width,1,bevel=0)
 bpy.context.view_layer.objects.active=body;body.select_set(True)
 mod=body.modifiers.new('Through opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name)
 PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
 for face in body.data.polygons:face.use_smooth=False

def loft(name,sections,mat=0):
 # Eight-sided cross sections (Z, bottom, top, width), joined along the barrel.
 verts=[]
 for z,low,high,width in sections:
  x=width/2;b=min(width*.18,(high-low)*.20)
  verts.extend([(u,v,z) for u,v in [(-x+b,low),(x-b,low),(x,low+b),(x,high-b),(x-b,high),(-x+b,high),(-x,high-b),(-x,low+b)]])
 faces=[tuple(range(7,-1,-1))]
 for k in range(len(sections)-1):
  for i in range(8):faces.append((k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i))
 faces.append(tuple(range((len(sections)-1)*8,len(sections)*8)))
 return obj(name,verts,faces,mat,0)

def line_bar(name,a,b,r=.009,mat=0):
 delta=Vector(xyz(b))-Vector(xyz(a));mid=(Vector(a)+Vector(b))*.5
 ob=tube(name,mid,r,delta.length,mat,0,10)
 # Rotate the mesh about its own centre, keeping the exported action origin.
 center=Vector(xyz(mid));rot=Vector((0,1,0)).rotation_difference(delta.normalized())
 for v in ob.data.vertices:v.co=center+rot@(v.co-center)
 return ob

def finish_barrel(end,start=.34,r=.020):
 tube('Barrel',(0,.085,-(end+start)/2),r,end-start,0,.012,16)
 tube('Muzzle crown',(0,.085,-end+.012),r+.004,.026,0,.012,16)
 tube('Bore shadow',(0,.085,-end+.032),.0118,.003,1,0,12)

def aligned_sights(slot,y,rear,front,style='aperture',rear_base=.145,front_base=.105):
 SIGHT_POINTS[slot]=[(0,y,rear),(0,y,front)]
 if style in ['notch','ak']:
  block('Rear sight base',(0,y-.026,rear),(.067,.028,.023),0,.001)
  for side in [-1,1]:block('Rear sight',(side*.023,y-.0125,rear),(.020,.025,.023),0,.001)
 elif style=='hk':
  block('Diopter mounting saddle',(0,(rear_base+y-.024)/2,rear),(.055,y-.024-rear_base+.012,.050),0,.002)
  drum=tube('HK diopter drum',(0,y-.008,rear),.025,.040,0,0,20,'y')
  cutter=tube('Temporary diopter aperture',(0,y,rear),.010,.10,0,0,20)
  bpy.context.view_layer.objects.active=drum;drum.select_set(True)
  mod=drum.modifiers.new('Open diopter','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
 else:
  block('Rear sight pedestal',(0,(rear_base+y-.012)/2,rear),(.047,y-.012-rear_base,.035),0,.002)
  tube('Rear sight aperture',(0,y,rear),.019,.015,0,.011,20)
  for side in [-1,1]:block('Rear sight protector',(side*.027,y-.004,rear),(.009,.048,.035),0,.001)
 # The actual aiming point is the top of the front post, not its centre.
 block('Front sight pedestal',(0,(front_base+y-.028)/2,front),(.033,y-.028-front_base,.035),0,.002)
 block('Front sight post',(0,y-.014,front),(.008,.028,.013),0,.0005)
 if style in ['hood','hk','ak']:tube('Front sight hood',(0,y,front),.032,.023,0,.027,20)
 elif style!='notch':
  for side in [-1,1]:
   profile('Front sight wing',[(front-.02,y-.027),(front+.02,y-.027),(front+.012,y+.023),(front-.012,y+.023)],.008,0,x=side*.026,bevel=.001)
   block('Front sight wing foot',(side*.016,y-.03,front),(.033,.009,.034),0,.001)

def sculpt_grip(kind='service',mat=1):
 # Independent contours keep the USP, Glock, AR and HK lower silhouettes distinct.
 outlines={
 'glock':[(-.030,.060),(.058,.060),(.063,.012),(.121,-.133),(.040,-.142),(.018,-.10),(-.006,-.041),(-.030,-.026)],
 'usp':[(-.026,.061),(.060,.061),(.052,.003),(.095,-.131),(.016,-.141),(-.012,-.034)],
 'deagle':[(-.017,.065),(.070,.065),(.076,.01),(.120,-.15),(.024,-.165),(-.009,-.032)],
 'ar':[(-.022,.036),(.045,.036),(.053,-.026),(.109,-.154),(.032,-.176),(-.008,-.047)],
 'hk':[(-.026,.04),(.051,.04),(.055,-.024),(.099,-.155),(.021,-.170),(-.018,-.061)],
 'service':[(-.026,.042),(.049,.042),(.060,-.029),(.100,-.151),(.025,-.167),(-.016,-.046)]}
 outline=outlines[kind];width=.080 if kind in ['deagle','hk'] else .073
 body=profile('Contoured pistol grip',outline,width,mat,bevel=.005)
 if kind in ['glock','usp','deagle']:
  rear=.115 if kind in ['glock','deagle'] else .09
  cut_opening(body,[(.018,-.005),(.050,-.005),(rear,-.19),(rear-.048,-.19)],.046)
 # Recessed-looking textured side panels follow the backstrap, never float.
 for side in [-1,1]:
  panel=[(.015,-.018),(.051,-.014),(.088,-.118),(.041,-.13)]
  profile('Grip texture panel',panel,.002,1,x=side*width*.5,bevel=.001)
  tube('Grip panel screw',(side*(width*.5+.001),-.080,.046),.005,.003,0,0,8,'x')
 guard()

def pistol_v2(slot):
 end=LENGTHS[slot];kind={1:'glock',2:'usp',10:'deagle'}[slot];metal=4 if slot==10 else 0
 sculpt_grip(kind,metal if slot==10 else 1)
 lower=.107 if slot in [1,10] else .082;bottom=-.170 if slot==10 else -.149
 profile('Pistol magazine',[(.023,-.009),(.046,-.009),(lower,bottom),(lower-.040,bottom-.004)],.041,0,bevel=.001)
 profile('Magazine floorplate',[(lower+.014,bottom+.001),(lower-.061,bottom-.010),(lower-.061,bottom-.021),(lower+.014,bottom-.011)],.080,1,bevel=.002)
 if slot==1:
  frame=[(-end+.031,.048),(-end+.031,.090),(.042,.090),(.055,.053),(.033,.02),(-.025,.023),(-.044,.048)]
  slide=[(-end,.087),(.043,.087),(.043,.147),(.031,.157),(-end+.01,.157),(-end,.145)]
 elif slot==2:
  frame=[(-end+.075,.034),(-end+.045,.052),(-end+.045,.086),(.061,.086),(.068,.061),(.035,.018),(-.035,.026),(-.17,.026),(-.187,.034)]
  slide=[(-end,.085),(.048,.085),(.060,.112),(.041,.164),(-end+.014,.164),(-end,.145)]
 else:
  frame=[(-end+.03,.033),(-end+.03,.086),(.065,.086),(.083,.050),(.050,.012),(-.03,.021),(-.175,.022),(-.189,.034)]
  slide=[(-.187,.082),(.065,.082),(.078,.132),(.044,.174),(-.167,.174),(-.187,.145)]
 profile('Sculpted frame',frame,.083 if slot!=10 else .108,metal if slot==10 else 1,bevel=.002)
 if slot==1:block('Trigger guard frame seat',(0,.043,-.105),(.059,.018,.112),1,.001)
 profile('Faceted slide',slide,.092 if slot!=10 else .116,metal,bevel=.002)
 if slot==10:
  loft('Fixed polygonal barrel',[(-end,.078,.174,.077),(-.20,.078,.174,.115),(-.177,.078,.174,.115)],4)
  block('Barrel rail spine',(0,.180,-.28),(.037,.012,.23),4,.001)
  for z in [-.35,-.25]:block('Barrel rail slot',(0,.187,z),(.038,.002,.009),1,.0003)
 tube('Recessed pistol muzzle',(0,.113,-end-.002),.019,.012,4,.012,20)
 tube('Pistol barrel',(0,.113,(-end-.095)/2),.017,end-.095,4,.012,20)
 tube('Recoil guide',(0,.08,(-end-.095)/2),.010,end-.095,0,0,12)
 tube('Bore shadow',(0,.113,-end+.018),.012,.005,1,0,12)
 for side in [-1,1]:
  for i in range(7):
   z=.020-i*.010
   profile('Slide serrations',[(z,.101),(z-.004,.101),(z-.012,.149),(z-.008,.149)],.0018,1,x=side*(.047 if slot!=10 else .059),bevel=0)
 block('Ejection cutout',(.047 if slot!=10 else .059,.131,-.118),(.002,.035,.065),1,.001)
 block('Chamber hood',(0,.158 if slot==1 else .165 if slot==2 else .175,-.118),(.053,.002,.065),4,.001)
 block('Slide release',(-.047,.063,-.042),(.009,.012,.040),0,.001)
 block('Magazine catch',(-.042,-.012,-.014),(.007,.014,.017),0,.001)
 if slot==1:
  block('Glock selector',(-.049,.125,.023),(.006,.020,.018),0,.001)
  block('Trigger safety tab',(0,-.006,-.095),(.005,.03,.005),1,.0005)
 else:
  profile('Hammer spur',[(.057,.133),(.087,.143),(.094,.12),(.068,.101)],.03,0,bevel=.001)
  block('Safety lever',(-.055,.12,.032),(.009,.019,.033),0,.001)
 if slot==2:
  block('USP accessory rail',(0,.037,-.23),(.091,.019,.091),1,.001)
  for z in [-.19,-.27]:block('USP rail lug',(0,.028,z),(.095,.012,.016),0,.001)
 y=.181 if slot==1 else .197 if slot==2 else .209
 aligned_sights(slot,y,.019,-end+.031,'notch',y-.025,y-.04)

def shotgun(slot):
 end=LENGTHS[slot];sculpt_grip()
 loft('Shotgun receiver',[(-.355,.021,.13,.093),(-.310,.021,.148,.112),(.033,.021,.145,.104),(.071,.025,.107,.083)])
 block('Loading gate',(0,.020,-.235),(.06,.005,.14),4,.001)
 block('Ejection port',(.057,.101,-.21),(.003,.049,.126),1,.002)
 block('Bolt face',(.060,.105,-.21),(.003,.028,.111),4,.001)
 if slot==4:tube('Bolt handle',(.079,.101,-.19),.010,.045,0,0,10,'x')
 for z in [-.027,-.301]:pin(z,.072,.11)
 if slot==3:
  loft('M3 fixed stock',[(.043,-.015,.103,.069),(.14,-.038,.09,.083),(.37,-.145,.058,.113),(.41,-.145,.046,.119)],1)
  block('M3 recoil pad',(0,-.05,.412),(.124,.196,.025),1,.005)
 else:
  tube('XM recoil tube',(0,.077,.21),.027,.33,0,0,12)
  loft('XM adjustable cheekpiece',[(.19,.037,.115,.063),(.29,.029,.115,.09),(.389,.015,.09,.087)],1)
  profile('XM skeleton stock',[(.275,.060),(.406,.071),(.409,-.137),(.347,-.138),(.348,-.04),(.292,-.029)],.074,1,bevel=.005)
  block('XM recoil pad',(0,-.035,.411),(.112,.220,.023),1,.004)
 finish_barrel(end,.32,.023)
 tube('Magazine tube',(0,.025,-.58),.022,.48 if slot==3 else .53,0,0,16)
 loft('Contoured fore-end',[(-.64,-.004,.113,.091),(-.61,-.011,.119,.119),(-.43,-.011,.119,.121),(-.37,.002,.114,.099)],1)
 for j in range(9):
  z=-.405-j*.024
  loft('Pump ribs' if slot==3 else 'XM fore-end rib',[(z-.004,-.013,.121,.123),(z+.004,-.013,.121,.123)],1)
 tube('Fore-end retaining collar',(0,.025,-.663),.032,.026,0,0,14)
 if slot==4:
  for side in [-1,1]:tube('Gas piston',(side*.029,.06,-.68),.012,.15,0,0,12)
  for z in [-.08,-.12,-.16,-.20]:block('XM rail tooth',(0,.16,z),(.057,.019,.026),0,.001)
 aligned_sights(slot,.200,-.05,-end+.06,'aperture',.14,.104)

def mp5():
 sculpt_grip('hk')
 profile('HK polymer lower',[(-.19,.012),(-.19,.060),(.037,.061),(.064,.018),(.039,-.026),(-.025,-.029),(-.045,.004)],.091,1,bevel=.004)
 loft('MP5 stamped receiver',[(-.383,.038,.135,.073),(-.34,.030,.144,.097),(.057,.030,.144,.097),(.075,.047,.126,.083)])
 for side in [-1,1]:block('Receiver pressed channel',(side*.049,.067,-.116),(.005,.017,.33),0,.001)
 block('MP5 magazine socket',(0,.017,-.243),(.075,.069,.089),0,.003);mp5_magazine()
 block('MP5 paddle magazine catch',(0,-.029,-.195),(.04,.036,.014),0,.002)
 block('Ejection port',(.049,.100,-.184),(.003,.036,.098),1,.002)
 block('Bolt face',(.051,.103,-.184),(.003,.020,.087),4,.001)
 # Navy A3: two sliding stock rails and a slim curved end plate.
 for side in [-1,1]:block('Retractable stock rail',(side*.060,.091,.17),(.014,.022,.35),0,.002)
 profile('MP5 shoulder plate',[(.322,.131),(.362,.122),(.370,.079),(.345,-.125),(.319,-.117),(.333,.071)],.125,1,bevel=.005)
 block('MP5 stock end cap',(0,.086,.073),(.119,.112,.035),0,.003)
 loft('MP5 tapered wide fore-end',[(-.56,.011,.102,.083),(-.52,-.003,.119,.115),(-.391,.003,.125,.107),(-.366,.024,.126,.096)],1)
 tube('MP5 cocking tube',(0,.142,-.452),.017,.27,0,0,16)
 block('Cocking handle',(-.044,.144,-.445),(.08,.017,.022),0,.002)
 finish_barrel(.63,.36,.019)
 tube('MP5 front sight collar',(0,.103,-.561),.033,.035,0,.016,16)
 for side in [-1,1]:tube('HK push pin',(side*.051,.054,.045),.008,.009,4,0,10,'x')
 tube('HK selector',(-.049,.035,.012),.012,.006,0,0,12,'x')
 aligned_sights(5,.185,.003,-.561,'hk',.139,.125)

def ak47():
 sculpt_grip('service',2)
 profile('AK milled lower',[(-.368,.01),(.06,.01),(.06,.107),(-.368,.107)],.093,0,bevel=.002)
 loft('AK rounded dust cover',[(-.365,.102,.154,.083),(-.31,.102,.16,.097),(.038,.102,.16,.097),(.065,.102,.133,.083)],0)
 block('Ejection port',(.049,.114,-.18),(.003,.032,.14),1,.001)
 block('Bolt face',(.052,.119,-.18),(.004,.019,.12),4,.001)
 for z in [-.07,-.29,-.33]:pin(z,.068,.098)
 profile('AK safety lever',[(-.024,.116),(-.267,.09),(-.288,.064),(-.244,.063),(-.025,.095)],.004,0,x=.051,bevel=.001)
 for side in [-1,1]:profile('Receiver lightening recess',[(-.327,.085),(-.181,.085),(-.181,.042),(-.327,.042)],.002,1,x=side*.047,bevel=.002)
 loft('AK wooden stock',[(.055,.005,.109,.071),(.126,-.025,.11,.091),(.365,-.145,.048,.120),(.404,-.14,.032,.116)],2)
 block('AK steel buttplate',(0,-.054,.408),(.12,.186,.014),0,.003)
 magazine(True)
 loft('AK lower wood handguard',[(-.613,.012,.088,.082),(-.580,-.005,.098,.106),(-.404,-.005,.098,.106),(-.366,.015,.099,.086)],2)
 loft('AK upper wood handguard',[(-.59,.106,.157,.074),(-.57,.10,.169,.083),(-.419,.10,.169,.083),(-.402,.105,.155,.074)],2)
 for z in [-.60,-.399]:block('Handguard retaining band',(0,.085,z),(.111,.161,.018),0,.002)
 tube('AK gas tube',(0,.133,-.676),.017,.18,0,0,14)
 profile('AK angled gas block',[(-.752,.066),(-.706,.066),(-.706,.138),(-.73,.154),(-.752,.132)],.047,0,bevel=.002)
 finish_barrel(.92,.36)
 block('AK rear sight ramp',(0,.16,-.351),(.057,.031,.057),0,.002)
 aligned_sights(6,.205,-.351,-.841,'ak',.173,.102)

def m4a1():
 sculpt_grip('ar')
 profile('AR lower receiver',[(-.321,.007),(-.321,.086),(.057,.086),(.055,.011),(-.035,.008),(-.052,.031),(-.16,.031),(-.169,.004)],.087,0,bevel=.003)
 loft('AR upper receiver',[(-.351,.077,.153,.091),(-.31,.074,.163,.101),(.039,.074,.163,.101),(.068,.078,.136,.083)],0)
 block('Ejection port',(.053,.118,-.17),(.004,.035,.129),1,.001)
 block('Bolt face',(.056,.124,-.17),(.003,.020,.111),4,.001)
 block('Ejection dust cover',(.057,.097,-.17),(.012,.010,.130),0,.001)
 profile('Brass deflector',[(-.092,.149),(-.064,.149),(-.059,.105),(-.077,.101)],.031,0,x=.055,bevel=.002)
 tube('Forward assist',(.065,.126,.015),.015,.056,0,0,12)
 stanag_magazine()
 tube('Buffer tube',(0,.105,.20),.031,.32,0,0,16)
 # Distinct retractable CAR stock, with a real triangular opening.
 body=profile('CAR telescoping stock',[(.158,.143),(.370,.143),(.405,.100),(.411,-.145),(.366,-.147),(.328,-.047),(.165,.038)],.095,1,bevel=.004)
 cut_opening(body,[(.225,.05),(.35,.05),(.374,-.09),(.349,-.063)])
 block('CAR recoil pad',(0,-.018,.412),(.103,.25,.014),1,.003)
 profile('Stock adjustment lever',[(.187,.042),(.288,-.008),(.32,-.018),(.308,-.033),(.21,.008)],.065,0,bevel=.002)
 loft('M4 oval handguard',[(-.66,.026,.129,.075),(-.64,.017,.139,.091),(-.399,.007,.151,.121),(-.368,.031,.128,.089)],1)
 for j in range(10):
  z=-.403-j*.023;width=.119-j*.003
  loft('M4 fore-end rib',[(z-.004,.012,.146,width),(z+.004,.012,.146,width)],1)
 tube('Delta ring',(0,.085,-.369),.061,.030,0,0,16)
 finish_barrel(.86,.34,.018)
 tube('M4 flash hider',(0,.085,-.843),.025,.048,0,.013,16)
 for side in [-1,1]:
  for z in [-.857,-.841]:block('Flash hider slot',(side*.024,.085,z),(.002,.016,.008),1,.001)
 for z in [-.04,-.286]:block('Carry handle riser',(0,.195,z),(.041,.065,.033),0,.002)
 profile('M4 carry handle',[(-.32,.203),(-.298,.243),(-.062,.243),(-.017,.208),(-.038,.2),(-.077,.223),(-.278,.223),(-.297,.2)],.043,0,bevel=.002)
 # Front A-frame feet wrap the barrel and join above it.
 for z in [-.680,-.717]:line_bar('A-frame leg',(0,.085,z),(0,.210,-.700),.012)
 tube('A-frame barrel collar',(0,.085,-.70),.028,.050,0,.017,14)
 aligned_sights(7,.265,-.047,-.700,'aperture',.223,.205)
 for z in [-.048,-.317]:pin(z,.059,.094)

def m249():
 sculpt_grip()
 loft('M249 receiver',[(-.425,.004,.153,.128),(-.393,-.014,.165,.147),(.068,-.014,.165,.147)],0)
 loft('M249 feed cover',[(-.424,.145,.205,.145),(-.359,.146,.229,.161),(-.085,.147,.229,.158),(-.047,.145,.202,.143)],0)
 block('Exposed feed tray',(0,.168,-.30),(.132,.006,.17),4,.001)
 block('Feed tray channel',(0,.172,-.30),(.074,.003,.157),1,.001)
 block('M249 ejection port',(.075,.058,-.271),(.003,.055,.135),1,.002)
 block('Bolt face',(.079,.064,-.271),(.003,.023,.12),4,.001)
 loft('M249 fixed stock',[(.062,.0,.144,.096),(.137,-.04,.138,.08),(.36,-.162,.07,.121),(.415,-.159,.048,.13)],1)
 block('M249 recoil pad',(0,-.055,.423),(.138,.228,.024),1,.004)
 loft('M249 ventilated fore-end',[(-.719,.015,.101,.094),(-.67,-.011,.125,.141),(-.458,-.011,.127,.155),(-.42,.015,.139,.134)],1)
 for side in [-1,1]:
  for z in [-.477,-.518,-.559,-.60,-.641]:block('Fore-end cooling slots',(side*.074,.08,z),(.003,.046,.023),1,.003)
 finish_barrel(1.02,.4,.022)
 tube('M249 gas cylinder',(0,.034,-.792),.020,.245,0,0,14)
 block('M249 gas regulator',(0,.066,-.891),(.05,.103,.043),0,.002)
 block('Ammunition box',(-.027,-.136,-.335),(.228,.234,.260),3,.014)
 block('Ammunition box lid',(-.027,-.019,-.335),(.245,.033,.276),0,.004)
 block('Ammunition box attachment saddle',(0,.008,-.335),(.14,.035,.17),0,.002)
 for side in [-1,1]:
  for z in [-.25,-.34,-.42]:block('Ammo box strengthening rib',(-.027+side*.115,-.14,z),(.005,.19,.012),3,.001)
 # The belt remains physically connected to the detachable box when held.
 belt=[(-.130,-.004,-.30),(-.178,.027,-.30),(-.197,.063,-.30),(-.197,.105,-.30),(-.178,.147,-.30),(-.059,.147,-.30)]
 for a,b in zip(belt,belt[1:]):
  for z in [-.314,-.287]:line_bar('Feed belt links',(a[0],a[1],z),(b[0],b[1],z),.004,0)
  count=max(1,round((Vector(b)-Vector(a)).length/.017))
  for j in range(count):tube('Linked cartridges',Vector(a).lerp(Vector(b),j/count),.008,.083,5,0,10)
 tube('Linked cartridges',belt[-1],.008,.083,5,0,10)
 block('Feed tray edge',(-.09,.124,-.30),(.07,.026,.13),0,.002)
 block('Bipod hinge',(0,.027,-.74),(.176,.048,.046),0,.002)
 for side in [-1,1]:
  line_bar('Folded bipod',(side*.075,.021,-.731),(side*.08,.004,-.983),.012)
  block('Bipod foot',(side*.08,.002,-.975),(.047,.016,.037),0,.002)
 block('Carry handle mounting foot',(.05,.133,-.461),(.048,.07,.037),0,.002)
 line_bar('Carry handle stem',(.062,.151,-.461),(.062,.273,-.461),.013)
 tube('Carry handle grip',(.062,.271,-.396),.021,.149,1,0,12)
 aligned_sights(8,.271,-.089,-.89,'aperture',.224,.112)

def awp():
 # The AW's defining thumbhole is part of the stock, not a separate AR grip.
 outline=[(-.683,.055),(-.642,-.036),(-.189,-.044),(-.156,-.023),(-.035,-.029),(.031,-.168),(.124,-.171),(.166,-.102),(.332,-.130),(.432,-.130),(.443,.048),(.350,.086),(.116,.088),(.073,.064)]
 body=profile('AW thumbhole chassis',outline,.127,3,bevel=.006)
 cut_opening(body,[(.055,.033),(.158,.052),(.238,.013),(.221,-.066),(.149,-.084),(.113,-.052),(.093,-.008)])
 cut_opening(body,[(-.137,.023),(-.151,.008),(-.151,-.032),(-.137,-.044),(-.059,-.044),(-.047,-.029),(-.047,.008),(-.057,.023)])
 # Grip insert reinforces the front wall of the thumbhole.
 profile('AW grip insert',[(-.009,.025),(.043,.027),(.09,-.133),(.035,-.15)],.130,1,bevel=.003)
 guard()
 loft('AW cheek rest',[(.171,.067,.112,.127),(.203,.056,.119,.144),(.382,.057,.11,.144),(.414,.05,.089,.129)],3)
 for z in [.405,.42,.435]:block('AW stock spacer',(0,-.034,z),(.133,.174,.010),0,.002)
 block('AW recoil pad',(0,-.034,.451),(.14,.188,.02),1,.004)
 for side in [-1,1]:
  for z,y in [(-.60,.007),(-.44,.008),(-.20,.008),(.32,-.018),(.129,-.12)]:tube('AW stock fastener',(side*.064,y,z),.007,.004,0,0,10,'x')
 tube('AW receiver sleeve',(0,.085,-.14),.041,.30,0,.031,16)
 tube('Bolt',(0,.085,-.14),.030,.29,4,0,16)
 # Downturned short handle fits the receiver's right rear corner.
 line_bar('Bolt handle',(.022,.085,-.015),(.073,.082,-.008),.010)
 line_bar('Bolt handle',(.073,.082,-.008),(.077,.043,.006),.010)
 tube('Bolt knob',(.077,.035,.006),.019,.030,1,0,14,'y')
 block('AWP magazine',(0,-.091,-.291),(.091,.132,.128),0,.003)
 for side in [-1,1]:
  for z in [-.259,-.291,-.323]:block('AW magazine rib',(side*.046,-.098,z),(.003,.102,.006),0,.001)
 finish_barrel(1.12,.28,.022)
 # The front support sits above the narrower barrel, beyond the receiver
 # sleeve. Extend its foot into that surface while keeping the scope fixed.
 for z,bottom in [(-.12,.1175),(-.39,.0975)]:
  top=.2285
  block('Optic mount',(0,(bottom+top)/2,z),(.049,top-bottom,.035),0,.002)
 tube('Scope tube',(0,.244,-.27),.039,.37,0,.029,24)
 tube('Scope ocular',(0,.244,-.065),.052,.077,0,.038,24)
 tube('Scope objective',(0,.244,-.478),.060,.075,0,.044,24)
 for z in [-.11,-.39]:tube('Scope rings',(0,.244,z),.045,.03,1,.037,20)
 tube('Elevation turret',(0,.297,-.24),.031,.049,0,0,16,'y')
 tube('Windage turret',(.045,.244,-.24),.029,.05,0,0,16,'x')
 for z in [-.078,-.060,-.044]:tube('Ocular grip rib',(0,.244,z),.054,.005,0,.038,24)
 block('Sniper bipod hinge',(0,-.036,-.596),(.166,.043,.052),0,.002)
 for side in [-1,1]:
  line_bar('Folded sniper bipod',(side*.075,-.035,-.587),(side*.079,-.052,-.81),.011)
  block('Sniper bipod foot',(side*.079,-.052,-.805),(.038,.018,.035),1,.002)
 SIGHT_POINTS[9]=[(0,.244,-.0265),(0,.244,-.5155)]

def knife_v2():
 # Faceted blade bevel is real geometry and catches light from either side.
 outline=[(-.124,.027),(-.295,.033),(-.343,.014),(-.44,-.004),(-.347,-.032),(-.165,-.039),(-.124,-.026)]
 n=len(outline);verts=[(0,y,z) for z,y in outline]
 for side in [-1,1]:verts.extend((side*.009,y*.62,z+.008 if z<-.33 else z) for z,y in outline)
 faces=[]
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,n+j,n+i),(j,i,2*n+i,2*n+j)])
 faces.extend([tuple(range(n,2*n)),tuple(range(3*n-1,2*n-1,-1))]);obj('Bevelled clip-point blade',verts,faces,4,0)
 for side in [-1,1]:profile('Blade fuller',[(-.153,.012),(-.295,.016),(-.333,.002),(-.153,-.001)],.001,0,x=side*.009,bevel=.0005)
 block('Knife cross guard',(0,0,-.126),(.108,.09,.022),0,.003)
 tube('Knife handle',(0,0,-.032),.033,.172,1,0,14)
 for z in [.039,.014,-.012,-.038,-.064,-.09]:tube('Handle checkering ring',(0,0,z),.035,.012,0,0,14)
 tube('Knife pommel',(0,0,.062),.037,.02,0,0,12)

def rebuild(slot):
 if slot==0:knife_v2()
 elif slot in [1,2,10]:pistol_v2(slot)
 elif slot in [3,4]:shotgun(slot)
 else:{5:mp5,6:ak47,7:m4a1,8:m249,9:awp}[slot]()
