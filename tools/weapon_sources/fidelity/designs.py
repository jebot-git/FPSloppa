"""Weapon-specific proportions and connected mechanisms for the arena arsenals."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import ROOT,load_gltf,load_blend,load_blend_path,transform_meshes,bounds,canonical

def mesh(name,verts,faces,mat):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(mat);data.update()
 ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob);return ob

def lathe(name,profile,center,mat,n=32):
 # Closed radial section: exterior, muzzle lip, inner bore, rear annulus.
 verts=[(center[0]+r*math.cos(i*math.tau/n),y,center[1]+r*math.sin(i*math.tau/n)) for y,r in profile for i in range(n)]
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i) for j in range(len(profile)) for i in range(n)]
 return mesh(name,verts,faces,mat)

def side_profile(name,outline,width,mat):
 verts=[(x,y,z) for x in [-width/2,width/2] for y,z in outline];n=len(outline)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,verts,faces,mat)

def arena_pistol(key,anchors):
 source='cs16_1' if key=='doom_2' else 'cs16_10'
 objects=load_gltf(ROOT/'bases'/(source+'.glb'));meshes=[o for o in objects if o.type=='MESH']
 transform_meshes(meshes,Matrix.Identity(4))
 for ob in objects:
  if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 def xyz(v):return Vector((v[0],-v[2],v[1]))
 oldg,oldm=[xyz(anchors[source][a]) for a in ['grip','muzzle']]
 grip,muzzle=[xyz(anchors[key][a]) for a in ['grip','muzzle']]
 scale=Matrix.Diagonal((1.05,(muzzle.y-grip.y)/(oldm.y-oldg.y),(muzzle.z-grip.z)/(oldm.z-oldg.z),1))
 transform_meshes(meshes,Matrix.Translation(grip)@scale@Matrix.Translation(-oldg))
 for ob in list(meshes):
  if ob.name=='Suppressor':meshes.remove(ob);bpy.data.objects.remove(ob,do_unlink=True);continue
  if ob.name=='Slide':ob['motion']='slide';ob['amount']=[0,0,.04]
 return meshes

def double_barrel(key,anchors):
 objects=load_blend_path(ROOT/'sources/low-poly-guns-pack/unpacked/Ultimate Gun Pack - July 2019/Blends/Shotgun_SawedOff.blend')
 canonical(objects,'+X');ob=objects[0]
 # Split the donor's actual bored barrels and wood fore-end. They share one
 # hinge at the breech; no replacement tubes or intersecting pump receiver.
 groups={'TwinBoreLeft':[],'TwinBoreRight':[],'HingedForeEnd':[],'DoubleBarrelReceiver':[]}
 for p in ob.data.polygons:
  c=p.center
  name=('TwinBoreLeft' if c.x<0 else 'TwinBoreRight') if c.y>.332 and c.z>.079 else 'HingedForeEnd' if c.y>.53 else 'DoubleBarrelReceiver'
  groups[name].append(p)
 meshes=[];pivot=Vector((0,.318,.01))
 muzzle=Vector((anchors[key]['muzzle'][0],-anchors[key]['muzzle'][2],anchors[key]['muzzle'][1]));grip=Vector((0,-anchors[key]['grip'][2],anchors[key]['grip'][1]))
 scale=(muzzle.y-grip.y-.015)/.82;offset=Vector((0,muzzle.y-.015-scale,muzzle.z-.0946*scale))
 for name,polygons in groups.items():
  if not polygons:continue
  ids=sorted({i for p in polygons for i in p.vertices});mapping={v:i for i,v in enumerate(ids)}
  part=mesh(name,[ob.data.vertices[i].co[:] for i in ids],[[mapping[i] for i in p.vertices] for p in polygons],ob.data.materials[0])
  part.data.materials.clear()
  for mat in ob.data.materials:part.data.materials.append(mat)
  for dest,src in zip(part.data.polygons,polygons):dest.material_index=src.material_index
  transform_meshes([part],Matrix.Translation(offset)@Matrix.Scale(scale,4))
  if name!='DoubleBarrelReceiver':
   point=pivot*scale+offset;part.data.transform(Matrix.Translation(-point));part.location=point;part['motion']='hinge';part['amount']=[-.25,0,0]
  meshes.append(part)
 bpy.data.objects.remove(ob,do_unlink=True)
 return meshes

def launcher(key,anchors,make_material):
 rules=key.split('_')[0];redeemer=key=='ut99_8';multi=key in ['ut99_6','ut99_7'];pulse=key=='ut99_7';grenade=key=='quake_4'
 muzzle=Vector((anchors[key]['muzzle'][0],-anchors[key]['muzzle'][2],anchors[key]['muzzle'][1]));grip=Vector((0,-anchors[key]['grip'][2],anchors[key]['grip'][1]));tip=muzzle.y-.015;z=muzzle.z
 paint={'doom':(.11,.15,.065),'quake':(.17,.115,.06),'ut99':(.20,.215,.23)}[rules]
 shell=make_material('Ceramic enamel shell',paint,.38);steel=make_material('Blued steel',(.055,.065,.073),.65);edge=make_material('Machined collar',(.22,.24,.25),.7);rubber=make_material('Rubber grip',(.027,.03,.032),.05);brass=make_material('Breech bronze',(.22,.14,.045),.55)
 objects=[];radius=.115 if pulse else .155 if redeemer else .165 if multi else .115 if grenade else .105
 start=grip.y-.13;end=tip-(.26 if pulse else .43 if multi else .19 if redeemer else .40)
 # Forged lower saddle wraps into the tube. Rounded multi-point profile gives
 # the trigger group a continuous load path into the barrel housing.
 objects.append(side_profile('ForgedReceiver',[(grip.y-.09,z-.04),(grip.y-.11,z-.105),(grip.y-.025,grip.z+.055),(grip.y+.095,grip.z+.055),(grip.y+.18,z-.10),(end-.035,z-.08),(end,z-.035)],.11 if redeemer else .085,steel))
 donated=load_blend('28872',['grip.001']);transform_meshes(donated,Matrix.Rotation(math.pi/2,4,'Z'))
 lo,hi=bounds(donated);scale=.23/(hi.z-lo.z)
 transform_meshes(donated,Matrix.Translation(grip)@Matrix.Scale(scale,4)@Matrix.Translation(-(lo+hi)*.5))
 for ob in donated:ob.name='ContouredPistolGrip';ob.data.materials.clear();ob.data.materials.append(rubber)
 objects+=donated
 profile=[(start,radius*.77),(start+.025,radius*.95),(start+.055,radius),(end-.11,radius),(end-.065,radius*.95),(end-.015,radius*.77),(end,radius*.74),(end,radius*.56),(start,radius*.56)]
 objects.append(lathe('LauncherHousing',profile,(0,z),shell))
 if multi:
  # Six separate bored launch chambers around the original firing axis.
  for i in range(6):
   a=i*math.tau/6;radial=.068 if pulse else .105;center=(radial*math.cos(a),z+radial*math.sin(a));r=.038 if pulse else .051
   objects.append(lathe('LaunchChamber%02d'%i,[(end-.06,r),(tip-.018,r),(tip,r*.92),(tip,r*.69),(end-.06,r*.69)],center,steel,24))
  collar=lathe('RotatingChamberCarrier',[(end-.045,radius*1.03),(end-.025,radius*1.04),(end,radius),(end,radius*.9),(end-.045,radius*.9)],(0,z),brass)
  pivot=Vector((0,0,z));collar.data.transform(Matrix.Translation(-pivot));collar.location=pivot;collar['motion']='spin';collar['amount']=[0,0,1];objects.append(collar)
 else:
  bore=radius*(.66 if redeemer else .48 if grenade else .52)
  outer=radius*(.78 if redeemer else .64)
  objects.append(lathe('BoredLaunchTube',[(end-.075,outer),(tip-.035,outer),(tip-.018,outer*1.16),(tip,outer*1.16),(tip,bore),(end-.075,bore)],(0,z),steel))
  collar=lathe('BreechLock',[(start+.045,radius*1.015),(start+.065,radius*1.05),(start+.09,radius*1.05),(start+.105,radius*1.015),(start+.105,radius*.99),(start+.045,radius*.99)],(0,z),brass if rules=='quake' else edge)
  collar['motion']='slide';collar['amount']=[0,0,.018];objects.append(collar)
 # Narrow retaining bands sit on the housing; long vents follow its curvature.
 for y in [start+.14,end-.075]:objects.append(lathe('HousingBand',[(y,radius*1.006),(y+.009,radius*1.025),(y+.026,radius*1.025),(y+.033,radius*1.006),(y+.033,radius*.99),(y,radius*.99)],(0,z),steel))
 if not multi and not redeemer:
  # Ventilated heat shield: six curved ribs with actual open gaps around the
  # narrower launch tube, retained by machined collars at both ends.
  r=radius*.83;a0=end+.018;a1=tip-.075
  for k in range(6):
   verts=[];n=5
   for y,rr in [(a0,r),(a1,r),(a1,r-.009),(a0,r-.009)]:
    for j in range(n):
     a=k*math.tau/6+(j/(n-1)-.5)*.70;verts.append((rr*math.cos(a),y,z+rr*math.sin(a)))
   faces=[(q*n+j,q*n+j+1,((q+1)%4)*n+j+1,((q+1)%4)*n+j) for q in range(4) for j in range(n-1)]+[(0,n,2*n,3*n),(n-1,2*n-1,3*n-1,4*n-1)]
   objects.append(mesh('VentedHeatShield',verts,faces,shell if rules=='doom' else brass))
  for y in [a0-.012,a1-.014]:objects.append(lathe('HeatShieldRetainer',[(y,r+.003),(y+.018,r+.003),(y+.018,r-.014),(y,r-.014)],(0,z),steel))
 # Shallow forged side cheeks taper into the housing; inset fasteners sit on
 # those cheeks, rather than floating above the receiver on generic plates.
 panel_start=start+.065;panel_end=end-.11
 for side in [-1,1]:
  outline=[(panel_start,z-.035),(panel_start+.035,z-.065),(panel_end-.035,z-.055),(panel_end,z+.02),(panel_end-.03,z+.058),(panel_start+.035,z+.066)]
  cheek=side_profile('ForgedSideCheek',outline,.020,brass if rules=='quake' else shell)
  cheek.data.transform(Matrix.Translation(Vector((side*radius*.925,0,0))));objects.append(cheek)
  for y in [panel_start+.045,panel_end-.05]:
   bolt=lathe('RecessedHexFastener',[(0,.009),(.003,.009),(.003,.004),(0,.004)],(0,0),edge,6)
   bolt.data.transform(Matrix.Translation(Vector((side*(radius*.925+.011),y,z)))@Matrix.Rotation(-side*math.pi/2,4,'Z'));objects.append(bolt)
 for side in [-1,1]:
  # Recess-like dark ventilation slots seated on the curved upper flanks.
  for i in range(5):
   y=start+.20+i*.038
   if y+.018>end-.10:continue
   verts=[]
   for yy in [y,y+.015]:
    for a in [side*.35,side*.85]:verts.append((radius*1.003*math.cos(a)*side,yy,z+radius*1.003*math.sin(abs(a))))
   objects.append(mesh('InsetCoolingVent',verts,[(0,1,3,2)],rubber))
 # Raised iron sight is attached along the spine; no floating plate overlay.
 for y in [start+.11,tip-.11]:
  objects.append(side_profile('LauncherSight',[(y-.018,z+radius*.91),(y-.015,z+radius+.038),(y+.012,z+radius+.038),(y+.018,z+radius*.91)],.017,steel))
 if grenade:
  # Long lower walnut fore-end visually distinguishes the grenade launcher.
  wood=make_material('Walnut fore-end',(.17,.073,.024),.02)
  objects.append(side_profile('GrenadeForeEnd',[(grip.y+.17,z-.075),(grip.y+.19,z-.16),(tip-.23,z-.15),(tip-.18,z-.10),(tip-.19,z-.075)],.115,wood))
 if redeemer:
  # Compact sight unit seated into a raised longitudinal saddle.
  objects.append(side_profile('GuidanceSightMount',[(start+.11,z+radius-.012),(start+.13,z+radius+.025),(start+.36,z+radius+.025),(start+.38,z+radius-.012)],.065,steel))
  objects.append(lathe('GuidanceSight',[(start+.14,.028),(start+.36,.028),(start+.38,.024),(start+.38,.017),(start+.14,.017)],(0,z+radius+.048),steel,20))
 return objects

def ripper(key,anchors,mat):
 grip=Vector((0,-anchors[key]['grip'][2],anchors[key]['grip'][1]));tip=-anchors[key]['muzzle'][2]-.015;z=anchors[key]['muzzle'][1]
 blue=mat('Blue enamel shell',(.045,.072,.12),.4);steel=mat('Blued steel',(.07,.082,.095),.6);alloy=mat('Machined alloy',(.22,.25,.28),.65)
 parts=[]
 def profile(name,outline,width,material):
  ob=side_profile(name,outline,width,material);parts.append(ob);return ob
 profile('RipperReceiver',[(grip.y-.12,z-.04),(grip.y-.15,z+.06),(grip.y-.09,z+.12),(.35,z+.11),(.40,z+.045),(.36,z-.04)],.18,blue)
 donated=load_blend('28872',['grip.001']);transform_meshes(donated,Matrix.Rotation(math.pi/2,4,'Z'));lo,hi=bounds(donated)
 transform_meshes(donated,Matrix.Translation(grip)@Matrix.Scale(.23/(hi.z-lo.z),4)@Matrix.Translation(-(lo+hi)*.5));parts+=donated
 for ob in donated:ob.name='RipperGrip';ob.data.materials.clear();ob.data.materials.append(steel)
 profile('LowerDiscTrack',[(.28,z-.075),(tip-.04,z-.06),(tip,z-.015),(tip,z+.01),(.29,z+.01)],.23,blue)
 profile('UpperFork',[(.18,z+.10),(.20,z+.25),(.28,z+.29),(tip,z+.27),(tip,z+.235),(.30,z+.245),(.25,z+.10)],.105,blue)
 for side in [-1,1]:
  rail=profile('DiscGuide',[(.30,z+.015),(tip,z+.015),(tip,z+.038),(.30,z+.038)],.022,alloy);rail.data.transform(Matrix.Translation(Vector((side*.115,0,0))))
 disc=lathe('RipperBlade',[(0,.105),(.012,.117),(.022,.105),(.022,.026),(0,.026)],(0,0),alloy,32)
 disc.data.transform(Matrix.Rotation(math.pi/2,4,'X'));disc.location=(0,.43,z+.04);disc['motion']='spin';disc['amount']=[0,1,0];parts.append(disc)
 for i in range(5):
  y=.28+i*.073;bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.012,radius2=0,depth=.04,location=(0,y,z+.30));ob=bpy.context.object;ob.name='ForkSpine';ob.data.materials.append(alloy);parts.append(ob)
 return parts
