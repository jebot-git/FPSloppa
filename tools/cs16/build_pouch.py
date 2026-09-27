"""Original CC0 magazine pouch, authored in live Blender through Blender MCP.
Godot coordinates/metres; run build(), then export the MagazinePouch mesh.
"""
from pathlib import Path
import bpy, math, random
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/cs16/pouch'
PREFIX='Pouch_'
def xyz(p):return (p[0],-p[2],p[1])
def mat(name,color,rough=.85,metal=0):
    m=bpy.data.materials.new(PREFIX+name);m.diffuse_color=(*color,1);m.use_nodes=True
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
    return m

def mesh(name,verts,faces,material):
    data=bpy.data.meshes.new(PREFIX+name);data.from_pydata([xyz(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(PREFIX+name,data);bpy.context.scene.collection.objects.link(o);data.materials.append(material)
    uv=data.uv_layers.new(name='Fabric weave')
    for face in data.polygons:
        face.use_smooth=True
        for li in face.loop_indices:
            v=verts[data.loops[li].vertex_index];uv.data[li].uv=(v[0]*9+v[2]*11,v[1]*10)
    return o

def loop(w,d,y,phase=0,fold=0):
    out=[]
    for i in range(40):
        t=2*math.pi*i/40
        x=w*math.copysign(abs(math.cos(t))**.55,math.cos(t));z=d*math.copysign(abs(math.sin(t))**.55,math.sin(t))
        r=1+fold*math.sin(t*7+phase)
        out.append((x*r,y+fold*.015*math.sin(t*5),z*r))
    return out

def band(name,rings,material,reverse=False,cap=False):
    n=len(rings[0]);faces=[]
    for j in range(len(rings)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;c=(j+1)*n+i;d=(j+1)*n+(i+1)%n
            faces.append((a,b,d,c) if reverse else (a,c,d,b))
    if cap=='end':faces.append(tuple(reversed(range((len(rings)-1)*n,len(rings)*n))))
    elif cap:faces.append(tuple(reversed(range(n))) if reverse else tuple(range(n)))
    return mesh(name,[p for ring in rings for p in ring],faces,material)

def cord(name,points,radius,material,sides=6,closed=False):
    verts=[];faces=[];ps=[Vector(p) for p in points]
    for i,p in enumerate(ps):
        direction=(ps[(i+1)%len(ps)]-ps[(i-1)%len(ps)]).normalized() if closed else (ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
        u=direction.cross(Vector((0,1,0)))
        if u.length<.01:u=direction.cross(Vector((1,0,0)))
        u.normalize();v=direction.cross(u)
        for j in range(sides):verts.append(p+radius*(u*math.cos(j*2*math.pi/sides)+v*math.sin(j*2*math.pi/sides)))
    for i in range(len(ps) if closed else len(ps)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%len(ps))*sides+(j+1)%sides,((i+1)%len(ps))*sides+j))
    if not closed:faces.extend([tuple(reversed(range(sides))),tuple((len(ps)-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,material)

def strip(name,x,y,z,w,h,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz((x,y,z)))
    o=bpy.context.object;o.name=PREFIX+name;o.dimensions=(w,.0025,h)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    kinds=bpy.types.Modifier.bl_rna.properties['type'].enum_items
    mod=o.modifiers.new('Soft webbing edges',next(i.identifier for i in kinds if i.identifier=='BEVEL'));mod.width=.0011;mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name);o.data.materials.append(material)
    return o

def build():
    scene=bpy.data.scenes.get('Magazine Pouch Workshop') or bpy.data.scenes.new('Magazine Pouch Workshop');bpy.context.window.scene=scene
    for o in list(scene.objects):
        if o.name.startswith(PREFIX) or o.name=='MagazinePouch':bpy.data.objects.remove(o,do_unlink=True)
    cloth=mat('Olive canvas',(.205,.237,.145));web=mat('Woven binding',(.12,.144,.085));lining=mat('Dark interior',(.062,.076,.043));thread=mat('Stitching',(.39,.39,.25));metal=mat('Blackened eyelets',(.042,.046,.036),.4,.55)
    # A tiny original tile adds woven yarn variation; it is embedded in the GLB.
    img=bpy.data.images.new(PREFIX+'woven cotton',width=128,height=128);rng=random.Random(913)
    pixels=[]
    for y in range(128):
        for x in range(128):
            yarn=.88+.08*math.cos(x*math.pi/2)*math.cos(y*math.pi/2)+rng.uniform(-.035,.035)
            pixels.extend((yarn,yarn,yarn,1))
    img.pixels=pixels;img.pack()
    for m,color in [(cloth,(.205,.237,.145)),(web,(.12,.144,.085))]:
        tile=img.copy();tile.name=m.name+' weave'
        tile.pixels=[pixels[i]*color[i%4] if i%4<3 else 1 for i in range(len(pixels))];tile.pack()
        nodes=m.node_tree.nodes;texture=nodes.new('ShaderNodeTexImage');texture.image=tile
        m.node_tree.links.new(texture.outputs['Color'],next(n for n in nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
    parts=[]
    shell=[loop(.069,.032,-.155),loop(.083,.043,-.14,0,.035),loop(.095,.052,-.07,1,.025),loop(.096,.052,.015,2,.012),loop(.10,.055,.057)]
    parts.append(band('Soft shell',shell,cloth,cap=True))
    parts.append(band('Hollow lining',[loop(.093,.048,.056),loop(.091,.046,-.075),loop(.072,.032,-.137)],lining,cap='end'))
    parts.append(band('Folded mouth binding',[loop(.093,.048,.045),loop(.093,.048,.060),loop(.101,.056,.060),loop(.101,.056,.042)],web))
    for x in [-.057,.057]:
        parts.append(strip('Rear belt loop',x,-.032,.051,.029,.185,web))
        parts.append(strip('Belt loop return',x,.030,.057,.032,.035,web))
    def front_z(x):return -.052*max(0,1-(abs(x)/.096)**(2/.55))**(.55/2)-.0015
    for y in [-.018,-.071]:
        xs=[-.081+i*.162/20 for i in range(21)]
        verts=[(x,yy,front_z(x)) for yy in [y-.0115,y+.0115] for x in xs]
        parts.append(mesh('Front webbing',verts,[(i,21+i,22+i,i+1) for i in range(20)],web))
        for x in [-.072,-.024,.024,.072]:parts.append(cord('Webbing bartack',[(x,y-.01,front_z(x)-.0008),(x,y+.01,front_z(x)-.0008)],.001,thread,4))
    # Sewn edges follow the actual shell profile, including its fabric folds.
    for side,index in [(-1,25),(1,35)]:
        points=[Vector((r[index][0]*1.008,r[index][1],r[index][2]*1.008)) for r in shell[1:]]
        parts.append(cord('Raised panel seam',points,.0014,web))
        for a,b in zip(points,points[1:]):
            count=max(1,round((b-a).length/.010))
            for i in range(count):
                start=a.lerp(b,i/count);end=a.lerp(b,(i+.45)/count)
                start.x+=side*.0015;end.x+=side*.0015
                parts.append(cord('Panel stitch',[start,end],.00065,thread,4))
    rim=loop(.098,.053,.060)
    for i in range(0,len(rim),2):parts.append(cord('Rim stitch',[rim[i],rim[(i+1)%len(rim)]],.00065,thread,4))
    parts.append(cord('Elastic retention lip',loop(.097,.052,.063),.0017,web,6,True))
    for side in [-1,1]:
        parts.append(cord('Retention cord',[(side*.091,.05,-.045),(side*.075,.013,-.056),(side*.057,-.001,-.058)],.0012,metal))
        parts.append(strip('Cord keeper',side*.057,-.001,-.059,.015,.010,metal))
    # Drain grommet on the base/front edge.
    points=[(.005*math.cos(i*2*math.pi/12),-.134+.005*math.sin(i*2*math.pi/12),-.044) for i in range(12)]
    parts.append(cord('Drain eyelet',points,.0012,metal,6,True))
    for o in bpy.context.selected_objects:o.select_set(False)
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='MagazinePouch'
    matrix=o.matrix_world.copy()
    for v in o.data.vertices:v.co=matrix@v.co
    o.matrix_world.identity()
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=.57
            area.spaces.active.region_3d.view_location=Vector(xyz((0,-.04,0)))
            area.spaces.active.region_3d.view_rotation=Vector((.55,.85,.65)).to_track_quat('Z','Y')
    OUT.mkdir(exist_ok=True,parents=True);(OUT/'.gdignore').touch()
    print('POUCH_BUILT',len(o.data.vertices),'vertices',sum(len(p.vertices)-2 for p in o.data.polygons),'triangles')
    return o
if __name__=='__main__':build()
