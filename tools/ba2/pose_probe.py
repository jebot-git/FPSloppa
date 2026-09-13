"""Isolated BA-2 articulation checks and three preview poses; no game integration.
Run Blender --background --factory-startup --disable-autoexec --python this_file.
"""
import bpy, json, math
from mathutils import Vector, Matrix
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/ba2'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/ba2/source/extracted/Quandtum_BA-2_v1_1.blend'),load_ui=False,use_scripts=False)
arm=bpy.data.objects['Bot.Armature']; mesh=bpy.data.objects['Bot.Mesh']
arm.animation_data_clear()
for b in arm.pose.bones:
    b.matrix_basis=Matrix.Identity(4)
    for c in b.constraints:
        if c.type=='COPY_TRANSFORMS': c.influence=1
# EdgeSplit changes evaluated vertex indices; omit it only for numerical checks.
edge=next(m for m in mesh.modifiers if m.type=='EDGE_SPLIT'); edge.show_viewport=False
def positions():
    bpy.context.view_layer.update()
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [obj.matrix_world@v.co for v in obj.data.vertices]
base=positions()
groups={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>0 for w in v.groups)] for g in mesh.vertex_groups}
checks=[]
for name in ['Cannon.L','Cannon.R']:
    b=arm.pose.bones[name]; b.rotation_mode='XYZ'; b.rotation_euler=(math.radians(15),0,math.radians(25))
    changed=positions(); selected=set(groups[name])
    own=max((changed[i]-base[i]).length for i in selected)
    other=max((changed[i]-base[i]).length for i in range(len(base)) if i not in selected)
    checks.append({'bone':name,'pitch_degrees':15,'yaw_degrees':25,'own_max_displacement':own,'other_max_displacement':other,'pass':own>.1 and other<1e-5})
    b.matrix_basis=Matrix.Identity(4)
    positions()
for front in ['Front','Rear']:
    for side in ['L','R']:
        suffix=f'{front}.IK.{side}'; target=arm.pose.bones['Target.Leg.3.'+suffix]
        rest=target.matrix.copy(); delta=Vector((0,-.3,.25))
        moved=rest.copy(); moved.translation+=delta; target.matrix=moved
        changed=positions()
        end=arm.pose.bones['Leg.3.'+suffix].tail
        error=(end-target.head).length
        affected=set().union(*(set(groups[f'Leg.{n}.{front}.FK.{side}']) for n in [1,2,3]))
        other=max((changed[i]-base[i]).length for i in range(len(base)) if i not in affected)
        own=max((changed[i]-base[i]).length for i in affected)
        checks.append({'foot':suffix,'target_delta':list(delta),'ik_endpoint_error':error,'own_max_displacement':own,'other_max_displacement':other,'pass':error<.02 and own>.1 and other<1e-5})
        target.matrix=rest; positions()
report={'checks':checks,'passed':all(c['pass'] for c in checks),'note':'Pose checks only; no authored walk, collision validation or runtime performance claim.'}
(OUT/'pose-checks.json').write_text(json.dumps(report,indent=2)+'\n')
print('BA2_POSE_CHECKS',json.dumps(report),flush=True)
edge.show_viewport=True
# Reconstruct a simple material from the actual packed source maps. The original
# uses an unavailable Octane renderer. No source file is overwritten.
mat=bpy.data.materials.new('BA2 inspection diffuse and emission'); mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.6
for image_name,input_name in [('Turret-Diffuse.jpg','Base Color'),('Turret-Emission.jpg','Emission Color')]:
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images[image_name]
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs[input_name])
bs.inputs['Emission Strength'].default_value=.5
mesh.data.materials.clear();mesh.data.materials.append(mat)
for o in list(bpy.data.objects):
    if o not in [arm,mesh]:bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.use_nodes=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('Inspection world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.1,.13,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
low=min(v.z for v in base);high=max(v.z for v in base);center=Vector((0,0,(low+high)/2))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,low-.03))
floor=bpy.context.object;floor.name='Inspection ground'
floor_mat=bpy.data.materials.new('Ground');floor_mat.use_nodes=True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.075,.09,.105,1)
floor.data.materials.append(floor_mat)
camdata=bpy.data.cameras.new('Inspection camera');cam=bpy.data.objects.new('Inspection camera',camdata);scene.collection.objects.link(cam);scene.camera=cam
cam.location=center+Vector((7,-10,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=6
for loc,power,size in [((3,-5,8),1700,5),((-5,-2,4),1000,4),((1,5,6),2000,4)]:
    data=bpy.data.lights.new('Inspection area','AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new('Inspection area',data);scene.collection.objects.link(o);o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
rests={b.name:b.matrix.copy() for b in arm.pose.bones if b.name.startswith('Target.')}
for phase in [0,1,2]:
    for name,m in rests.items():arm.pose.bones[name].matrix=m
    for name in ['Cannon.L','Cannon.R']:arm.pose.bones[name].matrix_basis=Matrix.Identity(4)
    positions()
    if phase:
        for name,rest in rests.items():
            lift=('Front' in name)==name.endswith('.L')
            if phase==2:lift=not lift
            delta=Vector((0,-.3 if lift else .3,.25 if lift else 0))
            m=rest.copy();m.translation+=delta;arm.pose.bones[name].matrix=m
        for name,sign in [('Cannon.L',1),('Cannon.R',-1)]:
            arm.pose.bones[name].rotation_euler=(math.radians(15 if phase==1 else -10),0,math.radians(sign*(25 if phase==1 else -25)))
    bpy.context.view_layer.update()
    scene.render.filepath=str(OUT/f'pose-{phase}.png');bpy.ops.render.render(write_still=True)
print('BA2_POSE_PREVIEWS_COMPLETE',flush=True)
