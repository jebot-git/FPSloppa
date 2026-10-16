extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
var failures:Array=[]
var rows:Array=[]
var output:="/tmp/cq-avatar-parity-render"
func _initialize()->void:run.call_deferred()
func shot()->Image:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run()->void:
 if DisplayServer.get_name()=="headless":push_error("Vulkan required");quit(1);return
 var args:=OS.get_cmdline_user_args()
 if args.has("--output"):output=args[args.find("--output")+1]
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(512,512)
 var library:=Library.new();root.add_child(library)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.1,.13,.18);world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2,1.5,3);camera.look_at(Vector3(0,.9,0));camera.fov=40;camera.make_current()
 var hash:=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
 var reference=library.create_avatar(hash);world.add_child(reference);reference.set_process(false)
 reference.native_animation.detach(reference);reference.native_animation=null
 var actual=library.create_avatar(hash);world.add_child(actual);actual.set_process(false)
 for rig in [reference,actual]:rig.set_weapon(1,"cq_shocktroop");rig.set_equipment("jetpack");rig.distance_ik_enabled=false
 for state in ["tracked","crouch","prone","death"]:
  for rig in [reference,actual]:
   rig.stance=state if state in ["crouch","prone"] else "stand";rig.dead=state=="death";rig.speed=4;rig.time=0;rig.clip_name="";rig.ik_weight=0
   rig.target_xr_pose={"head":Transform3D(Basis.from_euler(Vector3(.12,-.25,.05)),Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.25,1.1,-.45)),"right":Transform3D(Basis.IDENTITY,Vector3(.35,1.25,-.5)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.35,1.25,-.5))}
  reference.advance_animation(.4);actual.advance_animation(.4)
  reference.show();actual.hide();var a:=await shot();a.save_png(output+"/"+state+"-reference.png")
  reference.hide();actual.show();var b:=await shot();b.save_png(output+"/"+state+"-native.png")
  var diff:=0;var peak:=0.;var non_background:=0
  for y in a.get_height():
   for x in a.get_width():
    var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
    var d:float=maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
    if d>1./255:diff+=1
    peak=maxf(peak,d)
    if absf(p.r-a.get_pixel(0,0).r)>.02:non_background+=1
  if diff>0 or non_background<100:failures.append(state)
  rows.append({"state":state,"different_pixels":diff,"peak_channel_error":peak,"non_background_pixels":non_background})
 var report:Dictionary={"failures":failures,"rows":rows,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method()}
 FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 world.free();library.free();print("CQ_NATIVE_ANIMATION_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
