"""Contoured shoulder furniture and housed firing assemblies for the remaining ST guns."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import ROOT,load_gltf,bounds,transform_meshes,reduce
from designs import lathe,side_profile,mesh

def refine(parts,slot,mat,z,tip):
 if slot not in [1,2,3,4,5,7]:return parts
 dark=mat('Blued steel',(.048,.059,.064),.55);alloy=mat('Machined alloy',(.20,.23,.25),.55)
 rubber=mat('Rubber shoulder pad',(.025,.028,.028),.01);wood=mat('Walnut stock',(.20,.10,.035),.02);bronze=mat('Heat shield bronze',(.16,.105,.045),.45)
 def remove(names):
  for ob in list(parts):
   if ob.name in names:parts.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
 def donor(name,part,lo,hi,material):
  obs=load_gltf(ROOT/'catalog'/('detail_'+part+'.glb'));meshes=[o for o in obs if o.type=='MESH']
  for ob in obs:
   if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
  a,b=bounds(meshes);lo=Vector(lo);hi=Vector(hi);span=b-a;size=hi-lo
  transform_meshes(meshes,Matrix.Translation(lo)@Matrix.Diagonal((size.x/span.x,size.y/span.y,size.z/span.z,1))@Matrix.Translation(-a))
  for ob in meshes:
   ob.name=name;ob.data.materials.clear();ob.data.materials.append(material);reduce(ob,3800)
  parts.extend(meshes);return meshes
 def panel(name,outline,width,material,x=0):
  ob=side_profile(name,outline,width,material);ob.data.transform(Matrix.Translation(Vector((x,0,0))));parts.append(ob);return ob
 def ring(name,profile,material=dark,n=24):
  ob=lathe(name,profile,(0,z),material,n);parts.append(ob);return ob
 # This operates after the common upper slimming step; no second scaling of
 # the already approved grip, disc or barrel muzzle coordinates.
 if slot==3:
  remove(['RearElectronics'])
  # A sloping cast cover with a curved rear cap and inset access panel.
  panel('DiscRearCastCover',[(-.105,.153),(-.12,.198),(-.096,.244),(-.055,.267),(.095,.267),(.16,.245),(.183,.192),(.156,.151)],.119,dark)
  for side in [-1,1]:
   panel('DiscRearInset',[(-.075,.181),(-.079,.220),(-.050,.238),(.085,.238),(.120,.220),(.128,.184)],.003,alloy,side*.060)
   for y in [-.052,.105]:
    bolt=lathe('DiscCoverBolt',[(0,.005),(.004,.005),(.004,.002),(0,.002)],(0,0),dark,8);bolt.data.transform(Matrix.Translation(Vector((side*.063,y,.209)))@Matrix.Rotation(math.pi/2,4,'Z'));parts.append(bolt)
  return parts
 # Real CC0 stock donor supplies a curved heel, toe, cheek rest and rear ribs.
 rear=-.35 if slot in [2,5,7] else -.26
 donor('SculptedShoulderStock','stock.009',(-.047,rear,-.024),(.047,.015,.158),wood if slot==5 else dark)
 # Shaped side covers break up flat receiver plates and connect to the stock.
 length={1:.43,2:.25,4:.37,5:.49,7:.29}[slot];width={1:.080,2:.089,4:.071,5:.054,7:.104}[slot]
 for side in [-1,1]:
  panel('ReceiverInset', [(-.07,.118),(-.025,.180),(length-.08,.178),(length,.136),(length-.025,.093),(.03,.097)],.007,dark,side*width)
  panel('ReceiverWearEdge',[(-.021,.175),(length-.08,.173),(length-.025,.148),(length-.045,.146),(-.021,.166)],.009,alloy,side*(width+.001))
  for i in range(4):
   y=length-.12-i*.027
   panel('RecessedCoolingSlot',[(y,.127),(y+.013,.135),(y+.013,.155),(y,.147)],.010,rubber,side*(width+.004))
 if slot==5:
  remove(['WalnutLowerStock'])
  # Restore the slim lower furniture, with a flush receiver seam and a
  # relieved nose below the lower focusing barrel. No floating inset decals.
  for ob in parts:
   if ob.name!='LaserReceiverShell':continue
   bm=bmesh.new();bm.from_mesh(ob.data)
   # Plane coordinates are transformed into this already slimmed mesh space.
   for world_co,normal in [(Vector((0,0,.110)),Vector((0,0,1))),(Vector((0,.542,0)),Vector((0,-1,0)))]:
    local_co=ob.matrix_world.inverted()@world_co
    cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=local_co,plane_no=normal,clear_inner=True,dist=.000001)
    edges=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
    if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
   bm.to_mesh(ob.data);bm.free()
  sections=[(-.10,.041,.032,.112),(-.06,.051,.016,.112),(.06,.055,.006,.112),(.22,.055,.013,.112),(.40,.052,.025,.112),(.49,.048,.029,.099),(.525,.045,.034,.098)]
  verts=[]
  # Chamfered rectangular sections keep the metal/wood interface planar.
  for y,w,low,high in sections:
   bevel=min(.012,(high-low)*.24)
   verts.extend([(-w+bevel,y,low), (w-bevel,y,low), (w,y,low+bevel),(w,y,high-bevel),(w-bevel,y,high),(-w+bevel,y,high),(-w,y,high-bevel),(-w,y,low+bevel)])
  n=8;faces=[tuple(reversed(range(n))),tuple(range((len(sections)-1)*n,len(sections)*n))]
  faces +=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(sections)-1) for j in range(n)]
  fore=mesh('CarvedWalnutForeStock',verts,faces,wood);parts.append(fore)
  # One machined breech bridges the paired barrel roots and covers the old
  # donor's exposed cut end. Bored seats surround, rather than intersect, tubes.
  verts=[];sections=[(.482,.094,.043,.214),(.514,.109,.040,.218),(.581,.103,.040,.215),(.625,.090,.044,.211)]
  for y,w,low,high in sections:
   c=.008;w*=.5
   verts.extend([(-w+c,y,low),(w-c,y,low),(w,y,low+c),(w,y,high-c),(w-c,y,high),(-w+c,y,high),(-w,y,high-c),(-w,y,low+c)])
  faces=[tuple(reversed(range(8))),tuple(range(24,32))]+[(i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j) for i in range(3) for j in range(8)]
  housing=mesh('PairedLaserBreech',verts,faces,alloy);parts.append(housing)
  for height in [z,z-.109*.77]:
   cutter=lathe('Bore cutter',[(.46,0),(.46,1),(.65,1),(.65,0)],(0,0),alloy,8)
   cutter.data.transform(Matrix.Translation(Vector((0,0,height)))@Matrix.Diagonal((.0365,1,.039,1)))
   bpy.context.view_layer.objects.active=housing
   mod=housing.modifiers.new('Barrel seat','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  for ob in parts:
   if ob.name=='LaserReady':
    # The indicator seats in the flat side of the new breech.
    lo,hi=bounds([ob]);ob.location+=Vector((.052,.566,.132))-(lo+hi)*.5


 if slot==1:
  # The raised cell and vent leaves need real seats: donor receiver contours
  # do not occupy the full old bounding box. Saddles bridge those clearances.
  panel('PowerCellSaddle',[(-.113,.118),(-.105,.218),(.122,.218),(.155,.190),(.150,.123)],.087,dark)
  panel('PlasmaHoodSeat',[(.174,.104),(.174,.143),(.447,.143),(.478,.115),(.460,.104)],.206,dark)
  for side in [-1,1]:
   panel('PlasmaHoodShoulder',[(.178,.110),(.179,.240),(.235,.266),(.475,.266),(.537,.214),(.523,.113)],.018,dark,side*.097)
  # Transverse arch retainers overlap every vent leaf in both rest and raised
  # positions, while preserving open cooling slots between the leaves.
  for y,r in [(.236,.194),(.467,.195)]:
   verts=[];segments=32
   for dy,radial in [(-.012,r-.018),(-.012,r+.023),(.012,r-.018),(.012,r+.023)]:
    for j in range(segments+1):
     a=.27+j/segments*(math.pi-.54);verts.append((.72*radial*math.cos(a),y+dy,z+.77*radial*math.sin(a)))
   stride=segments+1;faces=[]
   for j in range(segments):
    for a,b in [(0,1),(1,3),(3,2),(2,0)]:faces.append((a*stride+j,b*stride+j,b*stride+j+1,a*stride+j+1))
   faces.extend([(0,stride,3*stride,2*stride),(segments,2*stride-1,4*stride-1,3*stride-1)])
   parts.append(mesh('PlasmaHoodRetainer',verts,faces,dark))
  # Emitter is stepped and socketed, with a recessed dark muzzle crown.
  remove(['PlasmaEmitter'])
  ring('PlasmaEmitter',[(.27,.060),(.32,.076),(tip-.12,.072),(tip-.095,.061),(tip-.04,.061),(tip-.024,.069),(tip,.065),(tip,.043),(.27,.043)],alloy)
  ring('PlasmaMuzzleCrown',[(tip-.035,.069),(tip-.014,.070),(tip-.006,.065),(tip-.006,.056),(tip-.035,.056)],dark)
 elif slot==2:
  for y in [.48,tip-.065]:ring('RotaryOuterBrace',[(y,.119),(y+.015,.126),(y+.030,.126),(y+.042,.119),(y+.042,.117),(y,.117)],dark)
 elif slot==4:
  panel('RangeSightDovetail',[ (.073,.121),(.073,.247),(.103,.257),(.19,.257),(.217,.230),(.217,.121)],.040,dark)
  panel('RangeSightBase',[ (.060,.122),(.060,.151),(.224,.151),(.224,.122)],.074,alloy)
  remove(['FacetedMuzzle'])
  ring('OctagonalMuzzleCasting',[(tip-.18,.103),(tip-.15,.113),(tip-.05,.109),(tip-.025,.098),(tip,.094),(tip,.059),(tip-.18,.059)],dark,8)
  for side in [-1,1]:
   panel('GrenadeBreechShield',[(.33,z-.078),(.42,z-.10),(tip-.12,z-.073),(tip-.08,z+.035),(.43,z+.06),(.33,z+.028)],.016,alloy,side*.083)
 elif slot==7:
  # Close the tube with a dished, solid breech. Elliptical scaling matches the
  # existing slimmed barrel and overlaps its inner and outer rear lip.
  cap=ring('ClosedMortarBreech',[(.150,0),(.150,.065),(.166,.130),(.195,.169),(.235,.169),(.235,0)],dark,32)
  cap.data.transform(Matrix.Translation(Vector((0,0,z)))@Matrix.Diagonal((.72,1,.77,1))@Matrix.Translation(Vector((0,0,-z))))
  panel('MortarBreechSaddle',[(.103,.117),(.133,.255),(.217,.290),(.272,.260),(.292,.119)],.118,dark)
  for ob in parts:
   if ob.name=='HeavyMortarTube':ob.data.materials.clear();ob.data.materials.append(dark)
  for side in [-1,1]:
   panel('MortarThermalCover',[(.26,z-.084),(.34,z-.126),(tip-.11,z-.105),(tip-.06,z-.022),(tip-.10,z+.026),(.34,z+.050),(.26,z+.011)],.026,bronze,side*.096)
   for i in range(6):
    y=.40+i*.064
    panel('MortarVent',[ (y,z-.065),(y+.028,z-.065),(y+.038,z-.010),(y+.010,z-.010)],.004,rubber,side*.111)
 return parts
