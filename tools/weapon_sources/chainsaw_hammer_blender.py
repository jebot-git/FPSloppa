"""Replace the chainsaw blade with a pneumatic ram; run after refine_blender.py."""
from pathlib import Path
helper=Path(__file__).with_name('refine_blender.py')
exec(compile(helper.read_text().split('# Clip long source handle')[0],str(helper),'exec'))
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.import_scene.gltf(filepath=str(ROOT/'deathmatch/weapons/afps_1.glb'))
parts=[o for o in bpy.context.selected_objects if o.type=='MESH']
for o in parts:
 bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bm=bmesh.new();bm.from_mesh(o.data)
 # Exported Godot -Z is Blender +Y. Trim saw teeth/blade, keep its textured receiver.
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,.22,0),plane_no=(0,1,0),clear_outer=True,clear_inner=False)
 bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 o.name='CC0 AFPS chainsaw receiver'
 finish(o,.002)
# Attach directly to the cut receiver along -Z, with no leftover hammer shaft.
parts.append(lathe('Ram receiver collar',[(1.22,.5),(1.25,.35),(1.05,-.3),(.92,-.5),(.72,-.5),(.7,.3),(0,.3),(0,.5)],steel,(0,0,-.235),.085,.14))
parts.append(cylinder('Pneumatic piston',(0,0,-.43),.064,.29,silver))
parts.append(cylinder('Impact face',(0,0,-.605),.12,.06,steel))
parts.append(cylinder('Impact face rim',(0,0,-.63),.125,.018,silver))
for x in [-.13,.13]:
 parts.append(block('Ram mounting lug',(x,0,-.18),(.06,.08,.14),steel))
 parts.append(cylinder('Piston guide',(x,0,-.37),.018,.31,brass))
parts.append(block('Grip bracket',(0,-.04,.09),(.13,.07,.17),steel))
parts.append(block('Rubber pistol grip',(0,-.17,.09),(.10,.23,.12),rubber))
for y in [-.10,-.15,-.20,-.25]:parts.append(block('Grip rib',(0,y,.09),(.106,.012,.126),steel))
export('impact_hammer',parts)
for o in bpy.context.scene.objects:o.hide_set(True)
for o in parts:o.hide_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'chainsaw_impact_hammer.blend'))
print('CHAINSAW_HAMMER_COMPLETE')
