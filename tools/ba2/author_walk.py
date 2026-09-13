"""Author and bake a slow BA-2 crawl. Original source remains untouched.
Blender --background --factory-startup --disable-autoexec --python this_file
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix, Euler
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/ba2/animated'; RESULTS=ROOT/'test-results/ba2/walk'
FPS=30; SPEED=.45; PERIOD=5.6; RAMP=2.; START=6.6; DURATION=17.8
STRIDE=SPEED*PERIOD; SWING=.20; LIFT=.38; BODY_DROP=.15
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/ba2/source/extracted/Quandtum_BA-2_v1_1.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene; arm=bpy.data.objects['Bot.Armature']; mesh=bpy.data.objects['Bot.Mesh']
arm.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
for b in arm.pose.bones:
    for c in list(b.constraints): b.constraints.remove(c)
    b.matrix_basis=Matrix.Identity(4);b.rotation_mode='QUATERNION'
for o in list(bpy.data.objects):
    if o not in [arm,mesh]:bpy.data.objects.remove(o,do_unlink=True)
# Remove unused IK controls after replacing them with a deterministic two-link
# solve. Keep the existing weighted FK bones, rigid weights and original mesh.
bpy.context.view_layer.objects.active=arm;arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for b in list(arm.data.edit_bones):
    if '.IK.' in b.name or b.name.startswith('Switch.'):arm.data.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
rest={b.name:b.matrix_local.copy() for b in arm.data.bones}
for b in arm.data.bones:b.use_deform=True
groups={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>0 for w in v.groups)] for g in mesh.vertex_groups}
ground=min(v.co.z for v in mesh.data.vertices)
top=max(mesh.data.vertices[i].co.z for i in groups['Body'])-BODY_DROP
SCALE=10/(top-ground)
root=bpy.data.objects.new('BA2_10m',None);scene.collection.objects.link(root)
root.scale=(SCALE,)*3;root.location.z=-ground*SCALE
arm.parent=root;mesh.parent=arm
root['height_m']=10.;root['cruise_speed_mps']=SPEED;root['stride_m']=STRIDE
root['acceleration_seconds']=RAMP;root['walk_loop_seconds']=PERIOD
root['cannon_local_axis']='X';root['cannon_pitch_limit_degrees']=4.
root['body_yaw_axis']='Godot Y / Blender Z';root['body_yaw_limit_degrees']=3.
legs=[]
for front,side,offset in [('Front','L',0),('Rear','R',.25),('Front','R',.5),('Rear','L',.75)]:
    names=[f'Leg.{n}.{front}.FK.{side}' for n in [1,2,3]]
    a,b,c=[arm.data.bones[n] for n in names]
    ids=groups[names[2]]
    toe=mesh.data.vertices[min(ids,key=lambda i:mesh.data.vertices[i].co.z)].co.copy()
    # Move rear feet slightly under the body to leave reach for the long stance.
    nominal=toe.copy();nominal.y+=.08 if front=='Front' else -.20
    nominal.z=ground
    legs.append(dict(name=front+'.'+side,names=names,offset=offset,toe=toe,nominal=nominal,
                     hip=a.head_local.copy(),knee=b.head_local.copy(),ankle=c.head_local.copy(),
                     l1=(b.head_local-a.head_local).length,l2=(c.head_local-b.head_local).length))
def smooth(u):return u*u*u*(10+u*(-15+6*u))
def distance(t):
    if t<RAMP:
        u=max(0,t/RAMP);return SPEED*RAMP*(u**3-.5*u**4)
    return SPEED*(t-RAMP/2)
def speed(t):
    u=min(1,max(0,t/RAMP));return SPEED*u*u*(3-2*u)
def matrix_for(name,head,tail):
    old=arm.data.bones[name]
    q=(old.tail_local-old.head_local).rotation_difference(tail-head)
    m=(q.to_matrix()@rest[name].to_3x3()).to_4x4();m.translation=head
    return m
def set_pose(travel,root_motion=False,turret_time=None):
    phase=travel/STRIDE; route=Vector((0,-travel/SCALE if root_motion else 0,0))
    arm.pose.bones['Root'].matrix=Matrix.Translation(route)@rest['Root']
    bpy.context.view_layer.update()
    # Small motion from the gait, already present in the start pose: ramping
    # phase from rest avoids sudden bobbing when acceleration begins.
    w=phase*2*math.pi
    delta=Vector((.018*math.sin(w),0,-BODY_DROP+.008*(1-math.cos(w*4))))
    # Source Blender Z is vertical (Godot Y); Body's own local Y also points up.
    body_rot=Euler((0,0,math.radians(3)*math.sin(w)),'XYZ').to_matrix().to_4x4()
    body=Matrix.Translation(route+delta)@body_rot
    arm.pose.bones['Body'].matrix=body@rest['Body']
    bpy.context.view_layer.update()
    rows=[]
    for leg in legs:
        q=(phase-leg['offset'])%1
        amplitude=STRIDE*(1-SWING)/2
        if q<SWING:
            u=q/SWING
            forward=-amplitude-STRIDE*q+STRIDE*smooth(u)
            height=LIFT*math.sin(math.pi*u)**2
        else:
            forward=amplitude-STRIDE*(q-SWING);height=0
        toe=leg['nominal']+route+Vector((0,-forward/SCALE,height/SCALE))
        ankle=toe-(leg['toe']-leg['ankle'])
        hip=body@leg['hip'];v=ankle-hip;length=v.length
        direction=v.normalized();l1=leg['l1'];l2=leg['l2']
        safe=min(l1+l2-1e-5,max(abs(l1-l2)+1e-5,length))
        along=(l1*l1-l2*l2+safe*safe)/(2*safe)
        bend=body@leg['knee']-hip;bend-=direction*bend.dot(direction);bend.normalize()
        knee=hip+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))
        arm.pose.bones[leg['names'][0]].matrix=matrix_for(leg['names'][0],hip,knee)
        bpy.context.view_layer.update()
        arm.pose.bones[leg['names'][1]].matrix=matrix_for(leg['names'][1],knee,ankle)
        bpy.context.view_layer.update()
        foot=rest[leg['names'][2]].copy();foot.translation=ankle
        arm.pose.bones[leg['names'][2]].matrix=foot
        rows.append({'leg':leg['name'],'phase':q,'swing':q<SWING,'target_m':list((toe*SCALE)+root.location),
                     'reach_excess_m':max(0,length-l1-l2)*SCALE})
    for side,offset in [('L',0),('R',.8)]:
        pb=arm.pose.bones['Cannon.'+side]
        if turret_time is None:pb.matrix_basis=Matrix.Identity(4)
        else:
            fade=smooth(min(1,turret_time/4))
            pitch=math.radians(4)*math.sin(2*math.pi*turret_time/16-offset)*fade
            pb.rotation_quaternion=Euler((pitch,0,0),'XYZ').to_quaternion()
    bpy.context.view_layer.update()
    return rows
def key(b,frame):
    for prop in ['location','rotation_quaternion','scale']:b.keyframe_insert(prop,frame=frame,group=b.name)
def curves(a):
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves
walk_bones=['Root','Body']+[n for leg in legs for n in leg['names']]
clips={}
for name,length in [('WalkStart',START),('WalkLoop',PERIOD),('TurretSweep',16),('RoutePreview',DURATION)]:
    arm.animation_data_create();arm.animation_data.action=None
    action=bpy.data.actions.new(name);action.use_fake_user=True;arm.animation_data.action=action
    for i in range(round(length*FPS)+1):
        t=i/FPS;frame=i
        if name=='TurretSweep':
            set_pose(0)
            for side,offset in [('L',0),('R',.8)]:
                pb=arm.pose.bones['Cannon.'+side]
                pb.rotation_quaternion=Euler((math.radians(4)*math.sin(2*math.pi*t/16-offset),0,0),'XYZ').to_quaternion()
                key(pb,frame)
        else:
            set_pose(SPEED*t if name=='WalkLoop' else distance(t),name=='RoutePreview',t if name=='RoutePreview' else None)
            for n in walk_bones+(['Cannon.L','Cannon.R'] if name=='RoutePreview' else []):key(arm.pose.bones[n],frame)
    for fc in curves(action):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    clips[name]={'duration_s':length,'frames':round(length*FPS)+1,'root_motion':name=='RoutePreview'}
# Rebuild the legacy Octane material using the actual packed maps.
mat=bpy.data.materials.new('BA2 diffuse and emission');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.6
for image_name,input_name in [('Turret-Diffuse.jpg','Base Color'),('Turret-Emission.jpg','Emission Color')]:
    n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images[image_name];mat.node_tree.links.new(n.outputs['Color'],bs.inputs[input_name])
bs.inputs['Emission Strength'].default_value=.5
mesh.data.materials.clear();mesh.data.materials.append(mat)
scene.render.fps=FPS;scene.frame_start=0;scene.frame_end=round(DURATION*FPS)
scene.render.engine='CYCLES';scene.use_nodes=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
arm.animation_data.action=bpy.data.actions['RoutePreview'];scene.frame_set(0)
# Validate the baked animation, including rigid toe contacts in world space.
edge=next(m for m in mesh.modifiers if m.type=='EDGE_SPLIT');edge.show_viewport=False
metrics={'max_stance_slip_m':0.,'max_floor_penetration_m':0.,'max_toe_target_error_m':0.,'max_reach_excess_m':0.,'max_airborne_feet':0,'max_cannon_speed_deg_s':0.,'max_cannon_non_x_degrees':0.,'max_cannon_pitch_degrees':0.,'max_body_yaw_degrees':0.,'max_body_non_yaw_degrees':0.}
last={};last_aim={};samples=[]
for i in range(round(DURATION*FPS)+1):
    t=i/FPS;scene.frame_set(i)
    # Read targets without modifying the baked pose.
    phase=distance(t)/STRIDE;expected=[]
    for leg in legs:
        q=(phase-leg['offset'])%1;amplitude=STRIDE*(1-SWING)/2
        if q<SWING:
            u=q/SWING;forward=-amplitude-STRIDE*q+STRIDE*smooth(u);h=LIFT*math.sin(math.pi*u)**2
        else:forward=amplitude-STRIDE*(q-SWING);h=0
        target=(leg['nominal']+Vector((0,-(distance(t)+forward)/SCALE,h/SCALE)))*SCALE+root.location
        foot=arm.pose.bones[leg['names'][2]].matrix@rest[leg['names'][2]].inverted()@leg['toe']
        world=arm.matrix_world@foot
        metrics['max_toe_target_error_m']=max(metrics['max_toe_target_error_m'],(world-target).length)
        stance=q>=SWING or q<1e-8
        if stance and leg['name'] in last and last[leg['name']][0]:
            metrics['max_stance_slip_m']=max(metrics['max_stance_slip_m'],(world-last[leg['name']][1]).length)
        last[leg['name']]=(stance,world.copy());expected.append({'leg':leg['name'],'toe':list(world),'swing':not stance})
        hip=arm.pose.bones[leg['names'][0]].head;ankle=arm.pose.bones[leg['names'][2]].head
        metrics['max_reach_excess_m']=max(metrics['max_reach_excess_m'],max(0,(ankle-hip).length-leg['l1']-leg['l2'])*SCALE)
    metrics['max_airborne_feet']=max(metrics['max_airborne_feet'],sum(e['swing'] for e in expected))
    dg=bpy.context.evaluated_depsgraph_get();evaluated=mesh.evaluated_get(dg)
    minimum=min((evaluated.matrix_world@v.co).z for v in evaluated.data.vertices)
    metrics['max_floor_penetration_m']=max(metrics['max_floor_penetration_m'],-minimum)
    for side in ['L','R']:
        quat=arm.pose.bones['Cannon.'+side].rotation_quaternion.copy()
        e=quat.to_euler('XYZ')
        metrics['max_cannon_non_x_degrees']=max(metrics['max_cannon_non_x_degrees'],abs(math.degrees(e.y)),abs(math.degrees(e.z)))
        metrics['max_cannon_pitch_degrees']=max(metrics['max_cannon_pitch_degrees'],abs(math.degrees(e.x)))
        if side in last_aim:metrics['max_cannon_speed_deg_s']=max(metrics['max_cannon_speed_deg_s'],math.degrees(last_aim[side].rotation_difference(quat).angle)*FPS)
        last_aim[side]=quat
    e=arm.pose.bones['Body'].rotation_quaternion.to_euler('XYZ')
    metrics['max_body_yaw_degrees']=max(metrics['max_body_yaw_degrees'],abs(math.degrees(e.y)))
    metrics['max_body_non_yaw_degrees']=max(metrics['max_body_non_yaw_degrees'],abs(math.degrees(e.x)),abs(math.degrees(e.z)))
    if i%15==0:samples.append({'t':t,'distance_m':distance(t),'speed_mps':speed(t),'feet':expected})
edge.show_viewport=True
boundaries={}
for name in ['WalkLoop','TurretSweep']:
    arm.animation_data.action=bpy.data.actions[name];scene.frame_set(0)
    first={b.name:b.matrix.copy() for b in arm.pose.bones}
    scene.frame_set(clips[name]['frames']-1)
    boundaries[name]=max(abs(b.matrix[r][c]-first[b.name][r][c]) for b in arm.pose.bones for r in range(4) for c in range(4))
arm.animation_data.action=bpy.data.actions['WalkStart'];scene.frame_set(clips['WalkStart']['frames']-1)
start_end={n:arm.pose.bones[n].matrix.copy() for n in walk_bones}
arm.animation_data.action=bpy.data.actions['WalkLoop'];scene.frame_set(0)
boundaries['start_to_loop']=max(abs(arm.pose.bones[n].matrix[r][c]-start_end[n][r][c]) for n in walk_bones for r in range(4) for c in range(4))
arm.animation_data.action=bpy.data.actions['RoutePreview'];scene.frame_set(0)
bpy.context.view_layer.update()
evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
verts=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
dimensions=[max(v[k] for v in verts)-min(v[k] for v in verts) for k in range(3)]
report={'height_target_m':10,'start_dimensions_m':dimensions,'scale':SCALE,'speed_mps':SPEED,'acceleration_s':RAMP,'cycle_s':PERIOD,'stride_m':STRIDE,'foot_lift_m':LIFT,'clips':clips,'metrics':metrics,'boundary_max_matrix_error':boundaries,'samples':samples,
        'pass':metrics['max_stance_slip_m']<.002 and metrics['max_floor_penetration_m']<.005 and metrics['max_toe_target_error_m']<.002 and metrics['max_reach_excess_m']<.001 and metrics['max_airborne_feet']<=1 and max(boundaries.values())<1e-4 and metrics['max_cannon_non_x_degrees']<1e-4 and metrics['max_cannon_pitch_degrees']<4.001 and metrics['max_body_yaw_degrees']<3.001 and metrics['max_body_non_yaw_degrees']<1e-4}
(RESULTS/'animation-checks.json').write_text(json.dumps(report,indent=2)+'\n')
print('BA2_WALK_CHECKS',json.dumps({k:v for k,v in report.items() if k!='samples'}),flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'BA2-10m-walk.blend'))
for o in scene.objects:o.select_set(o in [root,arm,mesh])
bpy.ops.export_scene.gltf(filepath=str(OUT/'BA2-10m-walk.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,export_force_sampling=False,export_frame_range=False,export_anim_slide_to_zero=True,export_yup=True)
print('BA2_WALK_AUTHOR_COMPLETE',flush=True)
