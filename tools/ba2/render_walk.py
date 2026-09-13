"""Render the baked BA-2 animation on a metre grid, with a 1.8m scale figure.
Pass -- --stills for a quick contact sheet source, otherwise render the video.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/ba2/walk'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/ba2/animated/BA2-10m-walk.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene;arm=bpy.data.objects['Bot.Armature'];arm.animation_data.action=bpy.data.actions['RoutePreview']
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=640;scene.render.resolution_y=400;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('Walk preview world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.13,.18,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
def material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color;return m
floor_mat=material('Two metre floor tiles',(.1,.12,.15,1))
nodes=floor_mat.node_tree.nodes;links=floor_mat.node_tree.links
checker=nodes.new('ShaderNodeTexChecker');checker.inputs['Color1'].default_value=(.095,.11,.13,1);checker.inputs['Color2'].default_value=(.16,.18,.20,1);checker.inputs['Scale'].default_value=.5
geo=nodes.new('ShaderNodeNewGeometry');links.new(geo.outputs['Position'],checker.inputs['Vector']);links.new(checker.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
bpy.ops.mesh.primitive_plane_add(size=400,location=(0,0,-.012));bpy.context.object.data.materials.append(floor_mat)
human=material('1.8m scale mannequin',(.75,.25,.06,1))
def sphere(loc,scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=loc)
    bpy.context.object.scale=scale;bpy.context.object.data.materials.append(human)
def rod(a,b,r):
    a=Vector(a);b=Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
    bpy.context.object.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();bpy.context.object.data.materials.append(human)
hx,hy=-7,-3
sphere((hx,hy,1.66),(.12,.12,.14));sphere((hx,hy,1.2),(.24,.13,.36))
for sign in [-1,1]:
    rod((hx+sign*.13,hy,.94),(hx+sign*.15,hy,.12),.075)
    rod((hx+sign*.26,hy,1.40),(hx+sign*.32,hy,.9),.055)
camdata=bpy.data.cameras.new('Preview camera');cam=bpy.data.objects.new('Preview camera',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=24
for loc,power,size in [((8,-12,23),10000,12),((-12,-5,12),7000,10),((3,12,19),12000,10)]:
    data=bpy.data.lights.new('Preview area','AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new('Preview area',data);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,-3,4))-o.location).to_track_quat('-Z','Y').to_euler()
def distance(t):
    if t<2:
        u=t/2;return .45*2*(u**3-.5*u**4)
    return .45*(t-1)
stills='--stills' in sys.argv
start=int(sys.argv[sys.argv.index('--start')+1]) if '--start' in sys.argv else 0
stop=int(sys.argv[sys.argv.index('--stop')+1]) if '--stop' in sys.argv else 357
times=[0,2,4,6.6,9.4,12.2,15,17.8] if stills else [i/20 for i in range(start,stop)]
if not stills:(OUT/'frames').mkdir(exist_ok=True)
for i,t in enumerate(times):
    f=t*30;scene.frame_set(int(f),subframe=f-int(f))
    target=Vector((0,-distance(t),4.4))
    cam.location=target+Vector((18,-26,14));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    if stills:scene.cycles.samples=24;scene.render.resolution_x=960;scene.render.resolution_y=600
    scene.render.filepath=str(OUT/(f'still-{i}.png' if stills else f'frames/{start+i:04d}.png'))
    bpy.ops.render.render(write_still=True)
    if i%20==0:print('BA2_RENDER_PROGRESS',i,len(times),flush=True)
print('BA2_WALK_RENDER_COMPLETE',flush=True)
