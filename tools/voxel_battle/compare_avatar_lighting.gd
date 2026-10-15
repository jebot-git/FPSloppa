extends SceneTree
## Isolated identical-geometry comparison of the shipped and vertex-baked UT99 shaders.
const Library=preload("res://deathmatch/avatars/library.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const BASE=preload("res://deathmatch/avatars/vertex_animation.gdshader")
const OPTIMIZED=preload("res://deathmatch/avatars/vertex_lighting.gdshader")
const HASH="20016c75fa136a32fd180fec93b3c7274f8ae2c851560691a0bc3b8a39e916f2"
var world:Node3D
var avatars:Array=[]
var frames:Array=[]
var label:=""
var previous:=0
func _initialize():run.call_deferred()
func tick():
 await process_frame;await RenderingServer.frame_post_draw
 var now:=Time.get_ticks_usec()
 if not label.is_empty():frames.append({"label":label,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"wall_ms":(now-previous)/1000.,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 previous=now
func warm(n:int):
 label=""
 for i in n:await tick()
func run():
 assert(DisplayServer.get_name()!="headless")
 var output:="res://test-results/avatar-headlights";DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,720);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 world=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.015,.02,.03);world.add_child(env)
 var lighting:=Lighting.new();world.add_child(lighting);lighting.setup(world,true);lighting.phase_override=0.;lighting.apply();lighting.process_mode=Node.PROCESS_MODE_DISABLED
 var library:=Library.new();world.add_child(library)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(774,111.1,-717);camera.look_at(Vector3(774,111,-721));camera.fov=45;camera.make_current()
 for i in 32:
  var avatar=library.create_avatar(HASH);assert(avatar!=null);world.add_child(avatar);avatar.set_process(false);avatar.rotation.y=PI
  avatar.position=Vector3(774,110,-721)+Vector3((i%8-3.5)*.65,0,-float(i/8)*.8) if i>0 else Vector3(774,110,-721)
  avatar.visual.material_override=avatar.visual.mesh.surface_get_material(0).duplicate();avatars.append(avatar)
 for side in [-1,1]:
  var position:=Vector3(774+side*1.2,111.15,-714);RenderingServer.global_shader_parameter_set("cq_lamp_position"+str((side+1)/2),Vector4(position.x,position.y,position.z,60))
  RenderingServer.global_shader_parameter_set("cq_lamp_axis"+str((side+1)/2),Vector4(0,-.025,-.9996876,6))
 for count in [1,32]:
  for i in 32:avatars[i].visible=i<count
  for repeat in 2:
   var modes:=["pixel_bake","vertex_bake"] if repeat==0 else ["vertex_bake","pixel_bake"]
   for mode in modes:
    for avatar in avatars:avatar.visual.material_override.shader=BASE if mode=="pixel_bake" else OPTIMIZED
    await warm(90);label=str(count)+":"+mode+":"+str(repeat)
    for i in 180:await tick()
    label=""
    if repeat==0:root.get_texture().get_image().save_png(output+"/"+str(count)+"-"+mode+".png")
    print("AVATAR_SHADER_CASE ",count," ",mode," ",repeat)
 var result:={"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"avatar":"UT99 Malcolm, 595 triangles each, frozen pose, no physics/animation/IK updates","scope":"Isolated avatars on black background at night with two production per-pixel headlight cones. Same geometry, camera, skin, GPU animation fetch and headlight formula; only baked-light atlas sampling frequency differs.","frames":frames}
 FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 world.free();quit()
