"""Blender helper: extract and normalize the authorised MEC-VAL fitted suit.
No donor heads, hands, garment physics or avatar identity are exported.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

def source(root):
    existing=bpy.data.objects.get('4746773052303664305')
    if existing:
        rig=next(o for o in bpy.data.objects if o.parent==existing and o.type=='ARMATURE')
    else:
        current=bpy.context.window.scene
        stage=bpy.data.scenes.get('Tribes MEC Source') or bpy.data.scenes.new('Tribes MEC Source')
        bpy.context.window.scene=stage
        rig=next((o for o in stage.objects if o.type=='ARMATURE'),None)
        if rig is None:
            bpy.ops.import_scene.vrm(filepath=str(root/'tools/tribes/sources/mec_val_white_fox.vrm'),use_addon_preferences=False,extract_textures_into_folder=False,enable_mtoon_outline_preview=False,set_shading_type_to_material_on_import=False)
            rig=next(o for o in stage.objects if o.type=='ARMATURE')
        bpy.context.window.scene=current
    body=next(o for o in rig.children if o.type=='MESH' and o.name.startswith('Body'))
    return rig,body

def extract(root,scene,rig,bones,xyz,material,level,keep_feet=False):
    src,body=source(root)
    human={b.bone[0].upper()+b.bone[1:]:b.node.bone_name for b in src.data.vrm_addon_extension.vrm0.humanoid.human_bones if b.node.bone_name}
    names={v:k for k,v in human.items()}
    # Source was imported through the official add-on. Convert its rest pose
    # into the manual VRM 0 export frame used by the project's canonical rig.
    flip=Matrix.Rotation(math.pi,4,'Z')
    mesh_to_rig=src.matrix_world.inverted()@body.matrix_world
    joint={k:flip@src.data.bones[v].head_local for k,v in human.items()}
    next_bone={'Hips':'Spine','Spine':'Chest','Chest':'Neck','Neck':'Head'}
    for side in ['Left','Right']:
        for a,b in [('Shoulder','UpperArm'),('UpperArm','LowerArm'),('LowerArm','Hand'),('UpperLeg','LowerLeg'),('LowerLeg','Foot'),('Foot','Toes')]:next_bone[side+a]=side+b
    def mapped(group):
        bone=src.data.bones.get(group)
        while bone:
            key=names.get(bone.name)
            if key=='UpperChest':return 'Chest'
            if key in bones:return key
            bone=bone.parent
        return 'Hips'
    mapping={g.index:mapped(g.name) for g in body.vertex_groups}
    transforms={}
    for key,(start,end,parent) in bones.items():
        a=joint[key];b=joint.get(next_bone.get(key),a+Vector((0,0,.12)))
        c=Vector(xyz(start));d=Vector(xyz(end));axis=(b-a).normalized();target=(d-c).normalized()
        rotation=axis.rotation_difference(target)
        along=(d-c).length/max(.01,(b-a).length)
        # Keep human cross-sections; additional protection supplies class bulk.
        radial=1.03 if 'Arm' in key else 1.06 if 'Leg' in key else 1.02
        transforms[key]=(a,c,axis,rotation,along,radial)
    weights=[];positions=[]
    for v in body.data.vertices:
        w={}
        for g in v.groups:
            key=mapping[g.group];w[key]=w.get(key,0)+g.weight
        w={k:v for k,v in sorted(w.items(),key=lambda p:-p[1])[:4] if v>.001}
        total=sum(w.values());w={k:v/total for k,v in w.items()} if total else {'Hips':1.0}
        p=flip@(mesh_to_rig@v.co);out=Vector()
        for key,weight in w.items():
            a,c,axis,q,along,radial=transforms[key];rel=p-a;long=axis*rel.dot(axis)
            out+=(c+q@(long*along+(rel-long)*radial))*weight
        weights.append(w);positions.append(out)
    selected=[]
    for p in body.data.polygons:
        # Onepiece fitted torso/legs and one sleeve layer only. The source's
        # two tops overlap. Neck/head/hand regions use the original avatar.
        if p.material_index not in [2,4]:continue
        center=sum((mesh_to_rig@body.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        if p.material_index==4 and abs(center.x)<.13:continue
        # Crop the donor neck locally: a global height cut would also remove
        # the upper sleeve in its T pose and leave holes when arms bend.
        if (center.z<.15 and not keep_feet) or (center.z>1.51 and abs(center.x)<.17):continue
        if any(any(weights[i].get(k,0)>.15 for k in ['Head','Neck','LeftHand','RightHand']) for i in p.vertices):continue
        # The large upper classes have enclosed greaves and breastplates.
        # Omit only regions fully underneath them; retain all joint seams.
        cooked=sum((positions[i] for i in p.vertices),Vector())/len(p.vertices)
        x,y,z=cooked
        if level>0 and .18<z<.38:continue
        if level>0 and 1.19<z<1.34 and abs(x)<.15 and abs(y)<.09:continue
        selected.append(p)
    used=sorted({i for p in selected for i in p.vertices});indices={old:new for new,old in enumerate(used)}
    data=bpy.data.meshes.new('MEC-VAL fitted suit');data.from_pydata([positions[i] for i in used],[],[[indices[i] for i in p.vertices] for p in selected]);data.update()
    uv=data.uv_layers.new(name='Finish')
    for dst,p in zip(data.polygons,selected):
        for di,si in zip(dst.loop_indices,p.loop_indices):
            value=body.data.uv_layers.active.data[si].uv
            uv.data[di].uv=((value.x+(1 if p.material_index==4 else 0))*.5,value.y)
        dst.use_smooth=True
    data.materials.append(material)
    ob=bpy.data.objects.new('MEC-VAL shared undersuit',data);scene.collection.objects.link(ob);ob.parent=rig
    for key in bones:
        vg=ob.vertex_groups.new(name=key)
        for old,new in indices.items():
            if key in weights[old]:vg.add([new],weights[old][key],'REPLACE')
    mod=ob.modifiers.new('Humanoid skin','ARMATURE');mod.object=rig
    return ob
