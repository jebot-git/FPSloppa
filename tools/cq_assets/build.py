"""Blender 4.5 batch bake. Run with --python build.py -- SOURCE_DIR OUTPUT_DIR."""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector, Matrix
args=sys.argv[sys.argv.index('--')+1:];src=Path(args[0]).resolve();out=Path(args[1]).resolve();out.mkdir(parents=True,exist_ok=True)
report={}
finish=bpy.data.images.load(str(Path(__file__).with_name('finish_master.png').resolve()))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1);return m
def import_file(path):
    old=set(bpy.data.objects)
    if path.suffix=='.blend':
        with bpy.data.libraries.load(str(path),link=False) as (a,b):b.objects=a.objects
        for o in b.objects:
            if o and o.type=='MESH':bpy.context.collection.objects.link(o)
    elif path.suffix.lower() in ('.glb','.gltf'):bpy.ops.import_scene.gltf(filepath=str(path))
    elif path.suffix.lower()=='.obj':bpy.ops.wm.obj_import(filepath=str(path))
    else:bpy.ops.import_scene.fbx(filepath=str(path))
    bpy.context.view_layer.update()
    return [o for o in bpy.data.objects if o not in old and o.type=='MESH' and o.name in bpy.context.scene.objects]
def evaluated(objects):
    for o in objects:
        deps=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(o.evaluated_get(deps),depsgraph=deps)
        o.modifiers.clear();o.data=mesh
        o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
def normalize(objects,length,grip=None,rotation=None):
    evaluated(objects)
    if rotation:
        for o in objects:o.data.transform(rotation)
    vertices=[v.co for o in objects for v in o.data.vertices]
    lo=Vector([min(v[i] for v in vertices) for i in range(3)]);hi=Vector([max(v[i] for v in vertices) for i in range(3)])
    scale=length/(hi.y-lo.y)
    center=Vector(grip) if grip else Vector((0,lo.y+(hi.y-lo.y)*.3,lo.z+(hi.z-lo.z)*.45))
    for o in objects:
        for v in o.data.vertices:v.co=(v.co-center)*scale
    return scale,center
metal=mat('painted metal',(.16,.22,.25));accent=mat('signal teal',(.05,.55,.48));dark=mat('rubber',(.035,.045,.055));white=mat('ivory',(.82,.85,.78));red=mat('medical red',(.7,.035,.025));gold=mat('ammunition yellow',(.65,.4,.03));blue=mat('medical blue',(.05,.25,.65))
def cube(name,pos,size,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(material);return o
def cut_opening(obj,center,size):
    # Local polygon subtraction preserves disconnected/non-manifold source shells.
    # Exact CSG on a joined source can discard unrelated islands.
    lo=Vector(center)-Vector(size)*.5;hi=Vector(center)+Vector(size)*.5
    points=[];faces=[]
    def clip(poly,axis,value,inside):
        result=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            da=(a[axis]-value)*inside;db=(b[axis]-value)*inside
            if da>=0:result.append(a)
            if (da>=0)!=(db>=0):result.append(a+(b-a)*(da/(da-db)))
        return result
    for face in obj.data.polygons:
        poly=[obj.data.vertices[i].co.copy() for i in face.vertices]
        if any(max(v[a] for v in poly)<lo[a] or min(v[a] for v in poly)>hi[a] for a in range(3)):
            fragments=[poly]
        else:
            fragments=[]
            for axis,value,sign in [(a,v,k) for a in range(3) for v,k in [(lo[a],1),(hi[a],-1)]]:
                outside=clip(poly,axis,value,-sign)
                if len(outside)>=3:fragments.append(outside)
                poly=clip(poly,axis,value,sign)
                if len(poly)<3:break
        for part in fragments:
            start=len(points);points.extend(part);faces.append(tuple(range(start,start+len(part))))
    mesh=bpy.data.meshes.new('open_well');mesh.from_pydata(points,[],faces);mesh.update();obj.data=mesh
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.calc_loop_triangles()
    if len(obj.data.loop_triangles)>820:
        dec=obj.modifiers.new('Opening budget','DECIMATE');dec.ratio=820/len(obj.data.loop_triangles);bpy.ops.object.modifier_apply(modifier=dec.name)
def cylinder(name,pos,radius,depth,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name;o.data.materials.append(material);return o
def tool(name):
    assert name=='injector'
    objects=[cylinder('autoinjector body',(0,0,0),.014,.14,white),cylinder('safety cap',(0,0,-.08),.015,.025,blue),cylinder('contact tip',(0,0,.08),.014,.025,gold),cube('medical band',(0,-.014,0),(.019,.002,.06),accent),cube('medical cross',(0,-.016,0),(.012,.002,.004),red),cube('medical cross',(0,-.016,0),(.004,.002,.012),red)]
    evaluated(objects)
    for o in objects:o.data.transform(Matrix.Rotation(-math.pi/2,4,'X'))
    return objects
jobs=[('pistol',src/'pistol/Base.obj',.46,(0,.3,-.6)),('scout_pistol',src/'pistol/pistol.obj',.9,(0,.3,-.6)),('carbine',src/'rifle/rifle.blend',.8,None),('designator',src/'laser/FS_Laser_Pistol.FBX',.38,None),('massacre',src/'massacre/Massacre.obj',.75,None),('repair_kit',src/'drill/cordless_drill.glb',.3,(0,.04,0)),('ammo_box',src/'ammo/ammo_box.obj',.4,(0,0,0)),('health_box',src/'medibox/weapon_box.obj',.4*84/206,(0,0,0)),('grenade',src/'Grenade.blend',.13,(0,0,.04))]
for name,path,length,grip in jobs+[(n,None,0,None) for n in ('injector',)]:
    clear()
    objects=import_file(path) if path else tool(name)
    if path:
        rotation=Matrix.Rotation(-math.pi/2,4,'Z') if name=='designator' else Matrix.Rotation(math.pi,4,'Z') if name=='repair_kit' else None
        scale,center=normalize(objects,length,grip,rotation)
        if name in ('carbine','designator'):
            sight=import_file(src/'red_dot.blend');normalize(sight,.09,None)
            for o in sight:
                for v in o.data.vertices:v.co+=Vector((0,.09,.22 if name=='carbine' else .15))
            objects+=sight
    if name=='repair_kit':
        bit=cylinder('repair bit',(0,.195,.134),.006,.065,metal);bit.rotation_euler.x=math.pi/2;evaluated([bit]);objects.append(bit)
    if name=='health_box':
        for o in objects:o.data.materials.clear();o.data.materials.append(white)
        objects += [cube('medical cross',(0,-.085,.065),(.045,.003,.014),red),cube('medical cross',(0,-.087,.065),(.014,.003,.045),red)]
        evaluated(objects)
    for i,o in enumerate(objects):
        if not o.data.materials:o.data.materials.append(accent if i%3==1 else metal)
        for index,m in enumerate(o.data.materials):
            if m is None:o.data.materials[index]=metal
        for m in o.data.materials:
            if not m:continue
            m.use_nodes=True
            original=m.diffuse_color
            tile=9 if 'medical blue' in m.name else 8 if 'ivory' in m.name else 6 if 'yellow' in m.name else 7 if 'medical red' in m.name else 4 if original[1]>original[0]*1.4 else 7 if original[0]>original[1]*1.5 else 2 if sum(original[:3])<.3 else 1 if sum(original[:3])>2 else 0
            tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=finish
            coord=m.node_tree.nodes.new('ShaderNodeTexCoord')
            scale_node=m.node_tree.nodes.new('ShaderNodeVectorMath');scale_node.operation='SCALE';scale_node.inputs[3].default_value=.23
            offset=m.node_tree.nodes.new('ShaderNodeVectorMath');offset.operation='ADD';offset.inputs[1].default_value=(tile%4*.25+.01,(3-tile//4)*.25+.01,0)
            m.node_tree.links.new(coord.outputs['Generated'],scale_node.inputs[0]);m.node_tree.links.new(scale_node.outputs[0],offset.inputs[0]);m.node_tree.links.new(offset.outputs[0],tex.inputs['Vector'])
            m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
            for node in list(m.node_tree.nodes):
                if node.type=='TEX_IMAGE' and (node.image is None or node.image.size[0]==0):m.node_tree.nodes.remove(node)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();high=bpy.context.object;high.name=name+'_source'
    high.data.calc_loop_triangles();source_tri=len(high.data.loop_triangles)
    # Keep the source geometry distinct from the target atlas.
    low=high.copy();low.data=high.data.copy();bpy.context.collection.objects.link(low);low.name=name
    bpy.context.view_layer.objects.active=low;high.select_set(False);low.select_set(True)
    if source_tri>950:
        dec=low.modifiers.new('Budget','DECIMATE');dec.ratio=780/source_tri;bpy.ops.object.modifier_apply(modifier=dec.name)
    if name=='massacre':
        # Cut into the grip/body so the insertion well is an actual opening.
        cut_opening(low,(-.06,-.02,.015),(.12,.055,.065))
        hardware=[cube('pack rim',(-.05,y,.015),(.018,.009,.08),dark) for y in (-.0525,.0125)]
        hardware += [cube('pack rim',(-.05,-.02,z),(.018,.065,.009),dark) for z in (-.0225,.0525)]
        hardware += [cube('charging handle',(.04,-.055,.09),(.055,.025,.015),gold)]
        evaluated(hardware)
        bpy.ops.object.select_all(action='DESELECT')
        for item in hardware:
            copy=item.copy();copy.data=item.data.copy();bpy.context.collection.objects.link(copy);copy.select_set(True)
        high.select_set(True);bpy.context.view_layer.objects.active=high;bpy.ops.object.join()
        bpy.ops.object.select_all(action='DESELECT')
        for o in hardware:o.select_set(True)
        low.select_set(True);bpy.context.view_layer.objects.active=low;bpy.ops.object.join()
        # Source copies ensure the additions receive the same baked finish.
        # Keep original high detail for selected-to-active baking.
    tri=low.modifiers.new('Triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
    image=bpy.data.images.new(name+'_albedo',width=512,height=512,alpha=False)
    baked=mat(name+'_baked',(.5,.5,.5));node=baked.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;baked.node_tree.links.new(node.outputs['Color'],baked.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);baked.node_tree.nodes.active=node
    low.data.materials.clear();low.data.materials.append(baked)
    for f in low.data.polygons:f.material_index=0
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1
    scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03;scene.render.bake.max_ray_distance=.15;scene.render.bake.margin=8;scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
    high.select_set(True);bpy.context.view_layer.objects.active=low
    bpy.ops.object.bake(type='DIFFUSE')
    image.filepath_raw=str(out/(name+'.png'));image.file_format='PNG';image.save();image.pack()
    bpy.data.objects.remove(high,do_unlink=True);low.select_set(True)
    low.data.calc_loop_triangles();triangles=len(low.data.loop_triangles);assert triangles<1000,(name,triangles)
    if name=='massacre':
        # Last eight vertices form the handle; preserve the baked UVs on a movable mesh.
        for f in low.data.polygons:f.select=False
        for e in low.data.edges:e.select=False
        for v in low.data.vertices:v.select=v.index>=len(low.data.vertices)-8
        bpy.context.view_layer.objects.active=low
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
        handle=next(o for o in bpy.context.selected_objects if o!=low);handle.name='ChargingHandle'
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
    verts=[v.co for o in bpy.context.selected_objects if o.type=='MESH' for v in o.data.vertices];bounds=[[min(v[i] for v in verts),max(v[i] for v in verts)] for i in range(3)]
    report[name]={'triangles':triangles,'source_triangles':source_tri,'materials':1,'textures':1,'bounds_blender':bounds,'muzzle':[0,(1.0-center.z)*scale if name in ('pistol','scout_pistol') else .083 if name=='carbine' else bounds[2][1]*.55,-bounds[1][1]]}
    if name=='injector':report[name]['muzzle']=[0,0,-bounds[1][1]]
    if name=='repair_kit':report[name]['muzzle']=[0,.134,-bounds[1][1]]
    if name=='massacre':report[name].update(pack_entry=[-.07,.015,.02],pack_direction=[-1,0,0])
    if name=='scout_pistol':report[name].update(scope_rear=[0,(1.68-center.z)*scale,-(-1.99-center.y)*scale],scope_front=[0,(1.68-center.z)*scale,-(3.62-center.y)*scale],scope_radius=.48*scale)
    print('CQ_ASSET',name,triangles,flush=True)
(out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
