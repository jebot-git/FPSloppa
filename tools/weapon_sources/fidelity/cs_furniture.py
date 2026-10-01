"""Replace flat pistol furniture; contour only the P90 lower chassis, preserving controls/sights."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import ROOT,load_gltf,bounds,transform_meshes,activate
from designs import mesh,lathe
from finishes import finish

def islands(bm):
 remaining=set(bm.verts)
 while remaining:
  seed=remaining.pop();component={seed};todo=[seed]
  while todo:
   v=todo.pop()
   for edge in v.link_edges:
    other=edge.other_vert(v)
    if other in remaining:remaining.remove(other);component.add(other);todo.append(other)
  yield component

def refine(meshes,key,mat):
 slot=int(key.split('_')[1])
 if slot not in [1,2,10,11]:return
 body=next(o for o in meshes if o.name=='Body');bm=bmesh.new();bm.from_mesh(body.data)
 # glTF seams split vertices; reconnect coincident positions before identifying
 # whole furniture components. UV coordinates remain on face corners.
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
 grip_bounds=None
 for group in list(islands(bm)):
  lo=Vector([min(v.co[i] for v in group) for i in range(3)]);hi=Vector([max(v.co[i] for v in group) for i in range(3)])
  if slot==11:
   if hi.z<=.175:
    for v in group:
     # Taper and round the lower polymer shell without touching optic supports,
     # the horizontal magazine, charging handles or muzzle attachments.
     weight=max(0,min(1,(.143-v.co.z)/.04))
     longitudinal=.78+.05*math.cos((v.co.y-.16)*9)
     v.co.x*=1-weight*(1-longitudinal)
   continue
  is_grip=lo.y>=-.145 and hi.y<=.035 and hi.z<=.079 and lo.z<=-.025
  is_guard=lo.y>.025 and hi.y<.175 and lo.z<-.052 and hi.z<.050 and hi.x-lo.x>.045
  if is_grip:
   if hi.x-lo.x>.05 and hi.z-lo.z>.16:grip_bounds=(lo,hi)
   bmesh.ops.delete(bm,geom=list(group),context='VERTS')
  elif is_guard:bmesh.ops.delete(bm,geom=list(group),context='VERTS')
 bm.to_mesh(body.data);bm.free();body.data.update()
 if slot==11:return
 assert grip_bounds is not None,key+' grip selection failed'
 lo,hi=grip_bounds;lo.z-=.023;lo.x=-.037 if slot==10 else -.032;hi.x=-lo.x
 obs=load_gltf(ROOT/'catalog/detail_grip.001.glb');new=[o for o in obs if o.type=='MESH']
 for ob in obs:
  if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 a,b=bounds(new);span=b-a;size=hi-lo
 transform_meshes(new,Matrix.Translation(lo)@Matrix.Diagonal((size.x/span.x,size.y/span.y,size.z/span.z,1))@Matrix.Translation(-a))
 polymer=mat('Rubber grip checkering',(.033,.035,.037),.02);steel=mat('Blued steel',(.065,.074,.081),.65)
 for ob in new:
  ob.name='SculptedPistolGrip';ob.data.materials.clear();ob.data.materials.append(polymer)
  # Cut the real magazine volume, including a small insertion clearance.
  magazine=next(o for o in meshes if o.name=='Magazine');cutter=bpy.data.objects.new('Magazine clearance',magazine.data.copy());bpy.context.scene.collection.objects.link(cutter);cutter.matrix_world=magazine.matrix_world.copy()
  for v in cutter.data.vertices:v.co.x*=1.12
  activate(ob);mod=ob.modifiers.new('Magazine well','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 # A swept rounded section gives the guard depth and smoothly shaped corners.
 outline=[(.039,.033),(.134,.033),(.157,.014),(.157,-.028),(.137,-.049),(.061,-.049),(.042,-.030),(.039,.014)]
 if slot==1:outline=[(.041,.033),(.143,.033),(.157,.021),(.157,-.030),(.140,-.049),(.058,-.049),(.040,-.032),(.040,.017)]
 points=[]
 for i in range(len(outline)):
  a=Vector(outline[i-1]);b=Vector(outline[i]);c=Vector(outline[(i+1)%len(outline)]);d=Vector(outline[(i+2)%len(outline)])
  for j in range(5):
   t=j/5;points.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 verts=[];n=len(points);cross=10;half=.024 if slot!=10 else .027
 for i,p in enumerate(points):
  tangent=(points[(i+1)%n]-points[i-1]).normalized();normal=Vector((-tangent.y,tangent.x))
  for j in range(cross):
   angle=j*math.tau/cross;v=p+normal*(.0085*math.sin(angle));verts.append((half*math.cos(angle),v.x,v.y))
 faces=[(i*cross+j,i*cross+(j+1)%cross,((i+1)%n)*cross+(j+1)%cross,((i+1)%n)*cross+j) for i in range(n) for j in range(cross)]
 guard=mesh('RoundedTriggerGuard',verts,faces,steel if slot==10 else polymer);new.append(guard)
 # Flush grip fasteners and tactile backstrap ribs catch light at hand scale.
 for side in [-1,1]:
  for y,z in [(-.030,-.025),(-.066,-.100)]:
   r=lathe('GripPanelFastener',[(0,.0045),(.0015,.0045),(.0015,.002),(0,.002)],(0,0),steel,12)
   r.data.transform(Matrix.Translation(Vector((side*(hi.x-.003),y,z)))@Matrix.Rotation(math.pi/2,4,'Z'));new.append(r)
 finish(new,key);meshes.extend(new)
