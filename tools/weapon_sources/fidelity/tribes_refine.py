"""Replace slab receivers and grips with fitted, contoured CC0 mechanical parts."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import load_blend,canonical,bounds,transform_meshes,reduce
from designs import lathe

def refine(parts,slot,mat,z):
 receivers=['InstrumentReceiver','LaserReceiver','GrenadeReceiver','RotaryReceiver','PlasmaReceiver','MortarBreech']
 for old in list(parts):
  if old.name not in receivers:continue
  lo,hi=bounds([old]);parts.remove(old);name=old.name;bpy.data.objects.remove(old,do_unlink=True)
  obs=load_blend('28872',['body.001' if slot in [0,6,8,11] else 'body.003']);canonical(obs,'+X');ob=obs[0]
  bm=bmesh.new();bm.from_mesh(ob.data)
  cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,-.034),plane_no=(0,0,1),clear_inner=True,dist=.00001)
  edges=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
  if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
  bm.to_mesh(ob.data);bm.free();low,high=bounds(obs);size=hi-lo;span=high-low
  transform_meshes(obs,Matrix.Translation(lo)@Matrix.Diagonal((size.x/span.x,size.y/span.y,size.z/span.z,1))@Matrix.Translation(-low))
  ob.name=name+'Shell';ob.data.materials.clear();ob.data.materials.append(mat('ST blued steel' if slot in [0,1,4,6,7,8,11] else 'ST machined alloy',(.08,.09,.10),.65));parts+=obs
 # Slim the entire upper assembly coherently, including collars, forks, lamps
 # and motion pivots. The dedicated grip below is sized directly to the hand.
 scale=Matrix.Diagonal((.72,1,.77,1));around=Matrix.Translation(Vector((0,0,z)))@scale@Matrix.Translation(Vector((0,0,-z)))
 for ob in parts:
  ob.data.transform(scale);ob.location=around@ob.location
 # More detailed CC0 lower receiver: curved backstrap, finger relief, closed
 # trigger guard and trigger, instead of the old repeated extruded rectangle.
 grip=load_blend('28872',['grip.006']);canonical(grip,'+X');ob=grip[0]
 # Anatomical palm point sits in the grip itself, behind the guard.
 transform_meshes(grip,Matrix.Diagonal((.27,.29,.28,1))@Matrix.Translation(Vector((-.009,-.29,.10))))
 ob.name='ContouredLowerReceiver';ob.data.materials.clear()
 polymer=mat('Stippled rubber',(.032,.035,.039),.02);frame=mat('Blued steel',(.052,.061,.068),.6)
 ob.data.materials.append(polymer);ob.data.materials.append(frame)
 for polygon in ob.data.polygons:polygon.material_index=0 if polygon.center.z<.035 and polygon.center.y<.045 else 1
 reduce(ob,3500);parts+=grip
 # Small fasteners follow the shaped receiver flank rather than being a painted
 # rectangle. A short axial shoulder joins the receiver to each firing assembly.
 if slot in [0,4,6,8,11]:
  y=.30 if slot!=4 else .42;r=.043 if slot in [0,11] else .057
  collar=lathe('FiringAssemblySeat',[(y-.014,r),(y+.018,r),(y+.018,r*.76),(y-.014,r*.76)],(0,z),frame,24);parts.append(collar)
 return parts
