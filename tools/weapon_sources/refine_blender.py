"""Run in Blender 5.x. Rebuild CC0 hammer and reusable, bevelled gun fittings."""
import bpy, bmesh, math
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/weapon_sources/refined'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def xyz(v): return (v[0],-v[2],v[1]) # Godot Y-up to Blender Z-up, rotation (no reflection).
def mat(name,color,metal=.65):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.42
 return m
steel=mat('Hammer brushed steel',(.25,.31,.34));brass=mat('Hammer brass',(.62,.40,.12));silver=mat('Piston steel',(.60,.66,.70));rubber=mat('Rubber grip',(.07,.08,.085),.1)
neutral=mat('Tintable housing',(.7,.7,.7))
def mesh(name,verts,faces,material):
 m=bpy.data.meshes.new(name);m.from_pydata([xyz(v) for v in verts],[],faces);m.update()
 bm=bmesh.new();bm.from_mesh(m);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(m);bm.free()
 o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.data.materials.append(material);return o
def finish(o,width=.004):
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 b=o.modifiers.new('Machined edges','BEVEL');b.width=width;b.segments=2
 bpy.ops.object.modifier_apply(modifier=b.name)
 for p in o.data.polygons:p.use_smooth=True
 n=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');n.keep_sharp=True
 bpy.ops.object.modifier_apply(modifier=n.name);o.select_set(False)
def lathe(name,profile,material,center=(0,0,0),radius=1,length=1,segments=24):
 # Closed radial cross section, ordered around the shell; open bore remains visible.
 v=[];f=[]
 for r,z in profile:
  for j in range(segments):
   a=j*math.tau/segments;v.append((center[0]+math.cos(a)*r*radius,center[1]+math.sin(a)*r*radius,center[2]+z*length))
 for i in range(len(profile)):
  for j in range(segments):f.append((i*segments+j,i*segments+(j+1)%segments,((i+1)%len(profile))*segments+(j+1)%segments,((i+1)%len(profile))*segments+j))
 return mesh(name,v,f,material)
def cylinder(name,center,radius,length,material):
 o=lathe(name,[(0,.5),(1,.5),(1,-.5),(0,-.5)],material,center,radius,length);finish(o,min(.006,radius*.1));return o
def block(name,center,size,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(center));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);finish(o);return o
def export(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 for o in objects:o.hide_set(True);o.select_set(False)
# Clip long source handle on an actual plane, close the cut, weld, recalculate normals.
v=[];f=[]
for line in (ROOT/'tools/weapon_sources/oga/Power_Hammer.obj').read_text().splitlines():
 s=line.split()
 if s and s[0]=='v':v.append(tuple(map(float,s[1:4])))
 if s and s[0]=='f':f.append([int(x.split('/')[0])-1 for x in s[1:]])
m=bpy.data.meshes.new('PowerHammer cleaned');m.from_pydata(v,[],f);m.update()
bm=bmesh.new();bm.from_mesh(m)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,1,0),plane_no=(0,1,0),clear_inner=True,clear_outer=False)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
for vtx in bm.verts:
 x,y,z=vtx.co;vtx.co=xyz(((x+.70)*.066,(y-2.5)*.066,-(z-.3)*.066-.28))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(m);bm.free()
o=bpy.data.objects.new('CC0 Jerd hammer head repaired',m);bpy.context.collection.objects.link(o);m.materials.append(steel);m.materials.append(brass)
for p in m.polygons:p.material_index=1 if abs(p.center.y-.28)>.21 else 0
finish(o,.002)
parts=[o,cylinder('Piston',(0,.095,-.55),.09,.17,silver),cylinder('Impact plate',(0,.095,-.655),.135,.035,steel)]
for x in [-.18,.18]:parts.append(cylinder('Hydraulic rail',(x,.095,-.37),.025,.27,brass))
parts.append(block('Grip mount',(0,-.015,-.065),(.17,.08,.21),steel))
parts.append(block('Rubber pistol grip',(0,-.165,-.065),(.105,.25,.12),rubber))
for y in [-.07,-.12,-.17,-.22]:parts.append(block('Grip rib',(0,y,-.065),(.112,.014,.125),steel))
export('impact_hammer',parts)
# Integrated flared receiver collar, stepped tube and recessed muzzle. Unit scales in Godot.
profile=[(1.27,.5),(1.33,.43),(1.33,.29),(1.1,.22),(1,.13),(1,-.40),(.94,-.5),(.69,-.5),(.64,-.42),(.64,.22),(0,.22),(0,.5)]
sleeve=lathe('Flared barrel and receiver collar',profile,neutral);finish(sleeve,.025);export('barrel_sleeve',[sleeve])
# Fully hollow optic, flared ends, no opaque cap across the optical path.
scope=lathe('Hollow scope housing',[(1.14,.5),(1.2,.45),(1.2,.29),(.9,.23),(.84,-.2),(1.12,-.30),(1.18,-.44),(1.1,-.5),(.79,-.5),(.70,-.4),(.61,.20),(.84,.32),(.86,.5)],neutral)
finish(scope,.015);export('scope_housing',[scope])
for o in parts:o.hide_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'weapon_fittings.blend'))
print('REFINED_WEAPONS_COMPLETE')
