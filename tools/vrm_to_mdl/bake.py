"""Blender batch stage: simplify imported source geometry and bake vertex poses.
Run through Blender --background --python bake.py -- SOURCE OUTPUT MANIFEST.
"""
import bpy, json, math, sys, struct, shutil
from pathlib import Path
import numpy as np
from mathutils import Vector, Quaternion
source_dir, output_dir, manifest_path = map(Path, sys.argv[sys.argv.index('--')+1:])
output_dir.mkdir(parents=True,exist_ok=True)
manifest=json.loads(manifest_path.read_text())
CLIPS=[('idle',6,6,True),('walk',8,10,True),('run',8,14,True),('attack',6,12,False),('pain',4,12,False),('death',8,10,False)]
def doc(path):
    data=path.read_bytes();size,kind=struct.unpack_from('<II',data,12)
    return json.loads(data[20:20+size])
def material_pixels(material,size=64):
    pixels=np.ones((size,size,4),dtype=np.float32)
    if not material:return pixels
    # Read glTF material data directly: VRM's unlit nodes are not Principled.
    definition=next((m for m in gltf['materials'] if m['name']==material.name),None)
    if definition is None:
        definition=next((m for m in gltf['materials'] if material.name.startswith(m['name']+'.')),None)
    if definition is None:raise RuntimeError('Missing source material '+material.name)
    pbr=definition.get('pbrMetallicRoughness',{})
    color=np.array(pbr.get('baseColorFactor',[1,1,1,1]))
    image=None
    if 'baseColorTexture' in pbr:
        image_index=gltf['textures'][pbr['baseColorTexture']['index']]['source']
        image=source_images[image_index]
    if image:
        w,h=image.size;raw=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(raw);raw=raw.reshape(h,w,4)
        pixels=raw[(np.arange(size)*h//size)[:,None],(np.arange(size)*w//size)[None,:]].copy()
        pixels[:,:,:3]*=color[:3]
    else:pixels*=color
    # Palette MDL has no alpha. Sparse overlays become opaque stylised details.
    pixels[:,:,:3]=pixels[:,:,:3]*pixels[:,:,3:4]+color[:3]*(1-pixels[:,:,3:4])
    return np.clip(pixels[:,:,:3]*255,0,255).astype(np.uint8)
def bone_rot(arm,bone,axis,angle):
    if bone not in arm.pose.bones:return
    pb=arm.pose.bones[bone];rest=(arm.matrix_world@pb.bone.matrix_local).to_quaternion()
    local=rest.inverted()@Quaternion(Vector(axis),angle)@rest
    pb.rotation_quaternion=pb.rotation_quaternion@local
for entry in manifest:
    name=Path(entry['path']).stem
    if (output_dir/(name+'.npz')).exists():print('BAKE_SKIP',name,flush=True);continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src=source_dir/(name+'.vrm');gltf=doc(src)
    tmp=output_dir/'input.glb';shutil.copyfile(src,tmp)
    bpy.ops.import_scene.gltf(filepath=str(tmp),import_pack_images=True)
    # Embedded images are loaded explicitly so unlit material node layouts do not matter.
    data=src.read_bytes();json_size=struct.unpack_from('<I',data,12)[0];binary=data[28+json_size:]
    source_images={}
    for index,image_def in enumerate(gltf['images']):
        view=gltf['bufferViews'][image_def['bufferView']];offset=view.get('byteOffset',0)
        image_path=output_dir/('source-image-'+str(index)+('.jpg' if image_def.get('mimeType')=='image/jpeg' else '.png'))
        image_path.write_bytes(binary[offset:offset+view['byteLength']])
        source_images[index]=bpy.data.images.load(str(image_path),check_existing=False)
        source_images[index].pack()
    for image_path in output_dir.glob('source-image-*'):image_path.unlink()

    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    humanoid={b['bone']:gltf['nodes'][b['node']]['name'] for b in gltf['extensions']['VRM']['humanoid']['humanBones'] if b.get('node',-1)>=0}
    for obj in bpy.data.objects:
        if obj.animation_data:obj.animation_data_clear()
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    original_faces=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    for obj in meshes:
        if obj.data.shape_keys:obj.shape_key_clear()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();obj=meshes[0]
    # Collapse modifiers run before skinning. UVs, materials and source weights stay.
    def collapse(ratio):
        m=obj.modifiers.new('MDL Low Polygon','DECIMATE');m.ratio=ratio;m.use_collapse_triangulate=True
        bpy.ops.object.modifier_move_up(modifier=m.name)
        while list(obj.modifiers).index(m)>0:bpy.ops.object.modifier_move_up(modifier=m.name)
        bpy.ops.object.modifier_apply(modifier=m.name)
    collapse(min(1,900/max(1,original_faces)))
    tri=obj.modifiers.new('Triangles','TRIANGULATE')
    while list(obj.modifiers).index(tri)>0:bpy.ops.object.modifier_move_up(modifier=tri.name)
    bpy.ops.object.modifier_apply(modifier=tri.name)
    # Allocate one 256-square skin atlas; same layout in every animation frame.
    def topology():
        used=sorted({p.material_index for p in obj.data.polygons});cols=math.ceil(math.sqrt(len(used)));tile=256//cols
        tiles={m:(i%cols,i//cols) for i,m in enumerate(used)}
        atlas=np.zeros((256,256,3),dtype=np.uint8)
        for mat,(tx,ty) in tiles.items():atlas[ty*tile:(ty+1)*tile,tx*tile:(tx+1)*tile]=material_pixels(obj.data.materials[mat],tile)[::-1]
        ids=[];uv=[];faces=[];lookup={};uvlayer=obj.data.uv_layers.active.data
        for poly in obj.data.polygons:
            corners=[];tx,ty=tiles[poly.material_index]
            for li in poly.loop_indices:
                loop=obj.data.loops[li];u,v=uvlayer[li].uv
                # Keep seams; clamp each material's UV inside its atlas rectangle.
                st=(tx*tile+int(np.clip(u,0,1)*(tile-3))+1,ty*tile+int(np.clip(1-v,0,1)*(tile-3))+1)
                key=(loop.vertex_index,st)
                if key not in lookup:lookup[key]=len(ids);ids.append(loop.vertex_index);uv.append(st)
                corners.append(lookup[key])
            faces.append([corners[0],corners[2],corners[1]])
        return ids,uv,faces,atlas
    for retry in range(8):
        ids,uv,faces,atlas=topology()
        if len(ids)<=1024 and len(faces)<=2048:break
        collapse(.75)
    if len(ids)>1024:raise RuntimeError('MDL vertex budget exceeded '+name)
    # Frozen face/eyes/fingers; only baked coarse whole-body actions survive.
    bpy.context.view_layer.update();frames=[];frame_names=[];clips=[]
    def pose(kind,phase,progress):
        for pb in arm.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion();pb.location=(0,0,0);pb.scale=(1,1,1)
        for side in ['left','right']:
            upper=humanoid[side+'UpperArm'];lower=humanoid[side+'LowerArm']
            head=(arm.matrix_world@arm.data.bones[upper].head_local)
            tail=(arm.matrix_world@arm.data.bones[lower].head_local)
            desired=Vector((.15 if side=='left' else -.15,-.2,-.9)).normalized()
            q=(tail-head).normalized().rotation_difference(desired)
            basis=(arm.matrix_world@arm.data.bones[upper].matrix_local).to_quaternion()
            arm.pose.bones[upper].rotation_quaternion=basis.inverted()@q@basis
            bone_rot(arm,lower,(1,0,0),-.35)
            for digit in ['Thumb','Index','Middle','Ring','Little']:
                for segment in ['Proximal','Intermediate','Distal']:
                    if side+digit+segment in humanoid:bone_rot(arm,humanoid[side+digit+segment],(1,0,0),.35)
        stride=.45 if kind=='walk' else .7 if kind=='run' else 0
        for side,sign in [('left',1),('right',-1)]:
            swing=math.sin(phase)*sign*stride
            bone_rot(arm,humanoid[side+'UpperLeg'],(1,0,0),swing)
            bone_rot(arm,humanoid[side+'LowerLeg'],(1,0,0),max(0,-swing)*1.4)
            bone_rot(arm,humanoid[side+'UpperArm'],(1,0,0),-swing*.35)
        if kind=='idle':bone_rot(arm,humanoid['spine'],(1,0,0),math.sin(phase)*.018)
        if kind=='attack':bone_rot(arm,humanoid['chest'] if 'chest' in humanoid else humanoid['spine'],(1,0,0),-.16*math.sin(math.pi*progress))
        if kind=='pain':bone_rot(arm,humanoid['spine'],(1,0,0),.25*math.sin(math.pi*progress))
        if kind=='death':bone_rot(arm,humanoid['hips'],(1,0,0),min(1,progress)*math.pi*.48)
        bpy.context.view_layer.update()
    for kind,count,fps,loop in CLIPS:
        start=len(frames)
        for i in range(count):
            pose(kind,2*math.pi*i/count,i/max(1,count-1))
            dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
            if len(mesh.vertices)!=len(obj.data.vertices):raise RuntimeError('Animated topology changed')
            coords=np.array([(ev.matrix_world@mesh.vertices[v].co)[:] for v in ids],dtype=np.float32)
            ev.to_mesh_clear();frames.append(coords);frame_names.append(f'{kind}{i+1:02d}')
        clips.append({'name':kind,'start':start,'count':count,'fps':fps,'loop':loop})
    frames=np.array(frames);neutral=frames[0];minimum=neutral.min(axis=0);maximum=neutral.max(axis=0)
    offset=np.array([(minimum[0]+maximum[0])/2,(minimum[1]+maximum[1])/2,minimum[2]])
    frames=(frames-offset)*(1.7/(maximum[2]-minimum[2]))
    # Quake forward X, left Y, up Z; scale 56 Quake units to 1.70 metres.
    frames=frames[:,:,[1,0,2]]*np.array([-1,-1,1])*(56/1.7)
    for kind in clips:
        if kind['name']=='death':
            f=frames[kind['start']:kind['start']+kind['count']]
            f[:,:,2]-=f[:,:,2].min(axis=1)[:,None]
    np.savez_compressed(output_dir/(name+'.npz'),frames=frames,faces=np.array(faces,dtype=np.int32),uv=np.array(uv,dtype=np.int32),atlas=atlas)
    (output_dir/(name+'.json')).write_text(json.dumps({'source':entry,'original_triangles':original_faces,'triangles':len(faces),'vertices':len(ids),'frames':frame_names,'clips':clips},indent=2))
    print('BAKED',name,'triangles',len(faces),'vertices',len(ids),'frames',len(frames),flush=True)
tmp.unlink(missing_ok=True)
