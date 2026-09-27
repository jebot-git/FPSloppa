"""Original DE props, authored through Blender MCP. Godot coordinates in metres.
Run in Blender's Python console or MCP execute_blender_code; export with export_assets().
The keypad and wire contact anchors are deliberately unchanged from bomb_interaction.gd.
"""
import bpy, math
from mathutils import Vector
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'DE_'

def coords(v):
    return (v[0], -v[2], v[1])

def material(name, color, metal=0, rough=.5):
    m = bpy.data.materials.new(PREFIX+name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    node = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metal
    node.inputs['Roughness'].default_value = rough
    return m

def bevel(o, width):
    # Read the live enum instead of assuming a Blender version's enum values.
    kinds = bpy.types.Modifier.bl_rna.properties['type'].enum_items
    bevel_type = next(v.identifier for v in kinds if v.identifier == 'BEVEL')
    mod = o.modifiers.new('Machined edges', bevel_type)
    mod.width = width
    mod.segments = 2
    mod.limit_method = next(v.identifier for v in mod.bl_rna.properties['limit_method'].enum_items if v.identifier == 'ANGLE')
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name, center, size, mat, width=.002):
    bpy.ops.mesh.primitive_cube_add(size=1, location=coords(center))
    o = bpy.context.object
    o.name = PREFIX+name
    o.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if width: bevel(o,min(width,min(size)*.3))
    o.data.materials.append(mat)
    return o

def cylinder(name, center, radius, depth, mat, axis=(0,0,1), vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=coords(center))
    o=bpy.context.object
    o.name=PREFIX+name
    o.rotation_mode=next(v.identifier for v in o.bl_rna.properties['rotation_mode'].enum_items if v.identifier=='QUATERNION')
    o.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector(coords(axis)))
    o.data.materials.append(mat)
    bevel(o,min(.0008,depth*.15))
    return o

def rod(name, a, b, width, mat):
    a,b=Vector(a),Vector(b)
    return cylinder(name,(a+b)*.5,width*.5,(b-a).length,mat,(b-a).normalized(),10)

def plate(name, outline, thickness, mat):
    verts=[coords((x,y,z)) for y in [-thickness*.5,thickness*.5] for x,z in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(PREFIX+name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(PREFIX+name,mesh);bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat);bpy.ops.object.select_all(action=next(v.identifier for v in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if v.identifier=='DESELECT'))
    o.select_set(True);bevel(o,.0012)
    return o

def combine(name, parts):
    for obj in bpy.context.selected_objects: obj.select_set(False)
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    # Set the exported origin through vertex coordinates, without a context enum.
    matrix=obj.matrix_world.copy()
    for vertex in obj.data.vertices: vertex.co=matrix@vertex.co
    obj.matrix_world.identity()
    return obj

def build():
    scene=bpy.data.scenes.get('DE Asset Workshop') or bpy.data.scenes.new('DE Asset Workshop')
    bpy.context.window.scene=scene
    # Only replace our own generated objects; all other scenes remain untouched.
    for obj in list(scene.objects):
        if obj.name.startswith(PREFIX):bpy.data.objects.remove(obj,do_unlink=True)
    olive=material('Ceramic olive',(.16,.20,.15),.35,.54)
    dark=material('Graphite',(.035,.048,.05),.28,.43)
    rubber=material('Grip rubber',(.024,.030,.028),0,.85)
    sand=material('Amber webbing',(.47,.27,.09),0,.82)
    steel=material('Brushed alloy',(.39,.44,.44),.82,.31)
    keys=material('Key caps',(.11,.14,.135),.15,.52)
    parts=[]
    parts.append(box('Pressure case',(0,0,-.017),(.282,.345,.14),olive,.008))
    parts.append(box('Rear bumper',(0,0,-.08),(.291,.352,.030),rubber,.006))
    for x in [-.119,.119]:
        for y in [-.144,.144]:
            parts.append(box('Mount foot',(x,y,-.098),(.045,.044,.008),rubber,.002))
        parts.append(box('Retention strap',(x,0,-.014),(.023,.357,.158),sand,.003))
        for y in [-.148,.147]:
            parts.append(box('Strap buckle',(x,y,.066),(.035,.030,.013),steel,.002))
            parts.append(box('Buckle inset',(x,y,.074),(.019,.015,.004),dark,.001))
    parts.append(box('Keypad bevel',(0,-.030,.061),(.226,.238,.026),dark,.006))
    parts.append(box('Screen bezel',(0,.112,.063),(.220,.067,.027),steel,.004))
    parts.append(box('Inset LCD',(0,.112,.078),(.198,.048,.008),dark,.002))
    for n in range(10):
        p=(0,-.119,.077) if n==0 else (((n-1)%3-1)*.067,.034-((n-1)//3)*.051,.077)
        parts.append(box('Key '+str(n),p,(.054,.040,.015),keys,.003))
    for x in [-.095,.095]:
        for y in [-.143,.151]:
            parts.append(cylinder('Captive screw',(x,y,.066),.004,.005,steel))
            parts.append(box('Screw slot',(x,y,.069),(.005,.001,.001),dark,.0002))
    for x in [-.075,0,.075]:
        for offset in [-.021,.021]:
            parts.append(cylinder('Wire collar',(x+offset,.161,.029),.008,.015,dark,axis=(0,1,0)))
    for i in range(5):
        parts.append(box('Side vent',(.142,-.06+i*.025,-.015),(.003,.010,.056),dark,.001))
    parts.append(box('Data plate',(0,-.156,.071),(.127,.022,.008),steel,.001))
    bomb=combine('DE_BombChassis',parts)
    # Compact flush cutters: continuous tangs, curved grips, overlapping pivot,
    # broad tapered jaws. Their tip remains exactly 18cm along -Z in Godot.
    arms=[]
    for side in [-1,1]:
        parts=[]
        points=[(side*.030,.018),(side*.040,-.018),(side*.034,-.067),(side*.013,-.112)]
        for a,b in zip(points,points[1:]):parts.append(rod('Insulated grip',(a[0],0,a[1]),(b[0],0,b[1]),.024,sand))
        for t in range(4):
            z=-.02-t*.014;x=side*(.040-t*.002)
            parts.append(box('Grip ridge',(x,0,z),(.026,.026,.003),rubber,.001))
        outline=[(side*.018,-.078),(side*.012,-.112),(-side*.028,-.151),(-side*.018,-.173),(-side*.002,-.180),(-side*.005,-.154),(side*.025,-.114)]
        parts.append(plate('Forged jaw',outline,.013,steel))
        arm=combine('DE_CutterLeft' if side<0 else 'DE_CutterRight',parts)
        pivot=Vector(coords((0,0,-.111)))
        for vertex in arm.data.vertices:vertex.co-=pivot
        arm.location=pivot;arms.append(arm)
    parts=[]
    parts.append(cylinder('Hinge',(0,0,-.111),.017,.023,steel,axis=(0,1,0)))
    parts.append(cylinder('Hinge cap',(0,.013,-.111),.009,.004,dark,axis=(0,1,0)))
    hinge=combine('DE_CutterHinge',parts)
    cutters=bpy.data.objects.new('DE_Cutters',None);scene.collection.objects.link(cutters)
    for part in [hinge]+arms:part.parent=cutters
    for obj in scene.objects:obj.select_set(False)
    bomb.select_set(True);bpy.context.view_layer.objects.active=bomb
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=.78
            area.spaces.active.region_3d.view_location=(0,0,0)
            area.spaces.active.region_3d.view_rotation=Vector((.4,-1,.3)).to_track_quat('Z','Y')
    print('DE_ASSETS',[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in [bomb,hinge]+arms])
    return bomb,cutters

def export_assets():
    import io_scene_gltf2
    fmt=next(row[0] for row in io_scene_gltf2.get_format_items(None,bpy.context) if '.glb' in row[1])
    for name,filename in [('DE_BombChassis','bomb_chassis.glb'),('DE_Cutters','cutters.glb')]:
        for obj in bpy.context.selected_objects:obj.select_set(False)
        obj=bpy.data.objects[name];obj.hide_set(False);obj.select_set(True);bpy.context.view_layer.objects.active=obj
        for child in obj.children_recursive:child.hide_set(False);child.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(ROOT/'deathmatch/pickups/defusal'/filename),export_format=fmt,use_selection=True,use_active_scene=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)

if __name__=='__main__':build()
