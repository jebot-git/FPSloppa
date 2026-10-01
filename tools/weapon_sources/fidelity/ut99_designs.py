"""Slim industrial UT receivers, with distinct bio, pulse and rocket assemblies."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import ROOT,load_gltf,transform_meshes
from designs import lathe,side_profile,mesh

def build(key,anchors,mat):
 grip=Vector((0,-anchors[key]['grip'][2],anchors[key]['grip'][1]));m=anchors[key]['muzzle'];z=m[1];tip=-m[2]-.015
 rocket=key=='ut99_6';bio=key=='ut99_1'
 steel=mat('Blued steel',(.045,.056,.067),.65);alloy=mat('Machined alloy',(.25,.28,.30),.6)
 shell=mat('Blue enamel shell',(.035,.06,.095),.35);rubber=mat('Rubber grip',(.025,.028,.03),.04);bronze=mat('Breech bronze',(.24,.14,.045),.5)
 objects=load_gltf(ROOT/'catalog/new_sci-fi-rifle.glb');parts=[o for o in objects if o.type=='MESH'];transform_meshes(parts,Matrix.Identity(4))
 for ob in objects:
  if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 for ob in list(parts):
  if 'Clip' in ob.name:
   parts.remove(ob);bpy.data.objects.remove(ob,do_unlink=True);continue
  # Preserve the donor's sculpted grip and sloping receiver. Remove its front
  # chamber cleanly; each weapon gets its own purpose-built firing assembly.
  bm=bmesh.new();bm.from_mesh(ob.data)
  cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,.57,0),plane_no=(0,1,0),clear_outer=True,dist=.00001)
  edges=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
  if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
  bm.to_mesh(ob.data);bm.free();ob.data.update();ob.name='TaperedReceiver'
  ob.data.materials.clear()
  for material in [shell,steel,rubber]:ob.data.materials.append(material)
  for polygon in ob.data.polygons:polygon.material_index=2 if polygon.center.z<-.025 else 1 if polygon.normal.z<-.6 else 0
  sz=(z-grip.z)/.207
  transform_meshes([ob],Matrix.Translation(grip)@Matrix.Diagonal((.85,.82,sz,1))@Matrix.Translation(Vector((0,-.14,.12))))
 breech=grip.y+(.57-.14)*.82-.012
 def ring(name,profile,center=(0,z),material=steel,n=24):
  ob=lathe(name,profile,center,material,n);parts.append(ob);return ob
 def panel(name,outline,width,material=shell):
  ob=side_profile(name,outline,width,material);parts.append(ob);return ob
 def lamp(ob,color):ob['lamp']=color
 if bio:
  # Slender injector tube, caged fluid reservoir and curved rear saddle.
  ring('InjectorNozzle',[(breech-.025,.065),(tip-.11,.056),(tip-.038,.045),(tip,.045),(tip,.032),(breech-.025,.032)])
  ring('InjectorLock',[(breech-.025,.069),(breech+.005,.073),(breech+.025,.066),(breech+.025,.06),(breech-.025,.06)],material=alloy)
  y0=grip.y+.015;y1=breech-.04;h=z+.112
  flask=ring('BioReservoir',[(y0,.052),(y0+.015,.06),(y1-.012,.06),(y1,.052),(y1,.001),(y0,.001)],(0,h),mat('Bio fluid',(.1,.3,.025),.08));lamp(flask,[.13,.36,.03])
  for y in [y0,y1-.014]:ring('ReservoirEndCap',[(y,.064),(y+.016,.064),(y+.016,.052),(y,.052)],(0,h),steel)
  for side in [-1,1]:
   ob=panel('ReservoirCage',[(y0-.01,h-.038),(y0+.02,h-.059),(y1-.005,h-.059),(y1+.019,h-.025),(y1+.005,h-.017),(y1-.016,h-.038),(y0+.025,h-.038)],.013,alloy);ob.data.transform(Matrix.Translation(Vector((side*.056,0,0))))
  valve=ring('PressureValve',[(0,.023),(.025,.023),(.025,.006),(0,.006)],(0,0),bronze,8);valve.data.transform(Matrix.Translation(Vector((.088,grip.y+.13,z+.025)))@Matrix.Rotation(math.pi/2,4,'Z'));valve['motion']='slide';valve['amount']=[-.003,0,0]
 elif not rocket:
  # Pulse is a single energy accelerator, not a smaller six-tube launcher.
  # An exposed core, three cage rails and a focusing iris distinguish it at
  # silhouette scale as well as through its charge/emission behavior.
  ring('PulseReactorSeat',[(breech-.06,.072),(breech-.02,.082),(breech+.025,.072),(breech+.025,.032),(breech-.06,.032)],material=steel)
  core=ring('PulseEnergyCore',[(breech,.033),(tip-.045,.033),(tip-.045,.001),(breech,.001)],material=mat('Pulse core',(.035,.22,.075),.05));lamp(core,[.035,.28,.085])
  for y in [breech+.022,(breech+tip)*.5,tip-.045]:
   ring('PulseFocusingCoil',[(y,.055),(y+.013,.060),(y+.025,.055),(y+.025,.038),(y,.038)],material=bronze)
  for i in range(3):
   a=math.tau*i/3+math.pi/2
   center=(.067*math.cos(a),z+.067*math.sin(a))
   rail=ring('PulseCageRail',[(breech-.02,.014),(tip-.025,.014),(tip-.009,.011),(tip-.009,.006),(breech-.02,.006)],center,steel,12)
   rail['motion']='slide';rail['amount']=[0,0,.013]
  iris=ring('PulseIris',[(tip-.033,.076),(tip-.018,.080),(tip,.062),(tip,.027),(tip-.033,.027)],material=alloy)
  pivot=Vector((0,0,z));iris.data.transform(Matrix.Translation(-pivot));iris.location=pivot;iris['motion']='spin';iris['amount']=[0,0,1]
  panel('PulseDorsalSpine',[(grip.y-.025,z+.055),(grip.y+.005,z+.112),(breech-.04,z+.112),(breech+.025,z+.064),(breech-.004,z+.048),(grip.y+.02,z+.078)],.040,shell)
  cell=panel('PulseCapacitor',[(grip.y+.125,z-.038),(grip.y+.14,z-.16),(breech-.04,z-.16),(breech-.016,z-.035)],.082,steel);cell['motion']='slide';cell['amount']=[0,-.009,0]
  for side in [-1,1]:
   lens=panel('PulseChargeGauge',[(grip.y+.17,z-.12),(grip.y+.17,z-.06),(grip.y+.185,z-.06),(grip.y+.185,z-.12)],.003,alloy);lens.data.transform(Matrix.Translation(Vector((side*.042,0,0))));lamp(lens,[.035,.28,.085])
 else:
  radius=.102
  ring('FiringBlock',[(breech-.07,radius*.85),(breech-.055,radius),(breech+.025,radius),(breech+.04,radius*.91),(breech+.04,.027),(breech-.07,.027)],material=steel)
  orbit=.067;barrel=.032
  for i in range(6):
   a=math.tau*i/6+math.pi/6;center=(math.cos(a)*orbit,z+math.sin(a)*orbit)
   ring('RocketBore',[(breech,barrel),(tip-.025,barrel),(tip,barrel*.94),(tip,barrel*.66),(breech,barrel*.66)],center,steel)
  ring('MuzzleRetainer',[(tip-.07,radius*.99),(tip-.048,radius*.99),(tip-.048,radius*.88),(tip-.07,radius*.88)],material=steel)
  # Two tapered side guards retain the cluster without a full cylindrical shell.
  for side in [-1,1]:
   outline=[(breech-.06,z-.06),(breech-.025,z-.091),(tip-.10,z-.075),(tip-.07,z-.03),(tip-.11,z-.018),(breech-.03,z-.035)]
   ob=panel('ClusterSideGuard',outline,.014,shell);ob.data.transform(Matrix.Translation(Vector((side*(radius-.008),0,0))))
  y0=grip.y-.018;y1=breech-.012
  panel('IntegratedCarryHandle',[(y0,z+.065),(y0+.025,z+.173),(y1-.055,z+.173),(y1,z+.071),(y1-.023,z+.063),(y1-.071,z+.146),(y0+.049,z+.146),(y0+.025,z+.062)],.032,steel)
  catch=panel('LoadingCatch',[(grip.y+.08,z+.012),(grip.y+.10,z+.045),(grip.y+.22,z+.04),(grip.y+.23,z+.005)],.006,alloy);catch.data.transform(Matrix.Translation(Vector((.075,0,0))));catch['motion']='slide';catch['amount']=[0,0,.023]
 if bio:
  # Add modest upper-body volume without enlarging the palm or shifting the
  # shot origin: 12% wider, 10% taller about the bore, unchanged length.
  for ob in parts:
   for vertex in ob.data.vertices:
    weight=max(0,min(1,(vertex.co.z-grip.z-.045)/.10)) if ob.name=='TaperedReceiver' else 1
    vertex.co.x*=1+.12*weight
    vertex.co.z=z+(vertex.co.z-z)*(1+.10*weight)
   ob.data.update()
 return parts
