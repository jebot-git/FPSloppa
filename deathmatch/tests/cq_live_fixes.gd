extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Transport=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
const Effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd")
const SkySource=preload("res://tools/voxel_battle/jungle_sky.gd")
const Points=preload("res://deathmatch/conquest/frontier/points.gd")
const Foveation=preload("res://deathmatch/vr/foveation.gd")
var checks:=0
var failures:Array=[]
var results:Dictionary={}
class Runtime extends RefCounted:
 var foveation_dynamic:=false
 var foveation_level:=1
 var vrs_min_radius:=0.
 var vrs_strength:=0.
 func is_initialized():return true
 func is_foveation_supported():return true
 func is_eye_gaze_interaction_supported():return false
 func get_view_count():return 2
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func settle():
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run():
 DirAccess.make_dir_recursive_absolute("/home/blux/.cache/cq-rec1-review/render")
 var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.05,.32,.7);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1.;stage.add_child(env)
 var camera:=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.near=.01;camera.fov=55;stage.add_child(camera);camera.make_current()
 for w in [0,1,2,3,4,9,10]:
  var gun:=Models.weapon(w,"cq_shocktroop");stage.add_child(gun)
  check(gun.get_meta("muzzle")==Models.muzzle(w,"cq_shocktroop"),"flash metadata matches modeled barrel "+str(w))
  var handle:Node3D=gun.find_child("ChargingHandle",true,false)
  check(handle==null if w in [0,2,9,10] else handle!=null and handle.position.distance_to(Models.anchor(w,"rack_anchor"))<.00001,"pistols use slides; rifle handles match physical anchors "+str(w))
  Models.animate_reload(gun,{"stroke":1.,"mag":false,"locked":false})
  if handle:check(handle.position.z>Models.anchor(w,"rack_anchor").z+.06,"charging handle physically retracts "+str(w))
  check(not gun.find_child("InsertedAmmo",true,false).visible,"extracted magazine disappears from gun "+str(w))
  if w in [0,2,9,10]:
   var slide:=gun.find_child("SlidingBolt",true,false)
   check(slide!=null and slide.mesh.get_surface_count()>0,"pistol has a separate moving slide "+str(w))
   Models.animate_reload(gun,{"stroke":0.,"mag":true,"locked":true,"ready":false});check(slide.position.z>.04,"empty pistol slide remains visibly locked open "+str(w))
  if w==2:
   var vertices:PackedVector3Array=gun.find_child("SlidingBolt",true,false).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var front:float=-INF;var rear:float=-INF
   for v in vertices:
    if absf(v.x)<.004 and absf(v.z+.245)<.008 and v.y>.17:front=maxf(front,v.y)
    if absf(v.x)>.009 and absf(v.x)<.019 and absf(v.z-.021)<.009 and v.y>.17:rear=maxf(rear,v.y)
   check(is_finite(front) and is_finite(rear) and absf(front-rear)<.0001,"pistol front blade and rear iron tops share the same sight plane")
  var data:Dictionary=Models.metadata(w,"cq_shocktroop")
  if data.has("scope_front") and data.has("scope_rear"):
   var a:Array=data.scope_front;var b:Array=data.scope_rear
   check(absf(a[0]-b[0])<.00001 and absf(a[1]-b[1])<.00001,"scope axis is parallel to authored bore "+str(w))
  if w in [0,3,4]:
   var dot:Node3D=gun.find_child("AlignedRedDot",true,false);camera.position=dot.position+Vector3(0,0,.25);camera.look_at(dot.position)
   await settle();var image:=viewport.get_texture().get_image();image.save_png("/home/blux/.cache/cq-rec1-review/render/dot-"+str(w)+".png")
   var count:=0
   for y in range(200,280):
    for x in range(280,360):
     var color:=image.get_pixel(x,y)
     if color.r>.5 and color.r>color.g*2 and color.r>color.b*2:count+=1
   var center:=image.get_pixel(320,240);check(center.r>.5 and center.r>center.g*2.,"red dot sits at optical centre "+str(w))
   results["dot_"+str(w)]=count;check(count>6,"red dot actually renders through optic "+str(w))
  gun.free()
 var mag:=Models.ammunition_pose(Transform3D(Basis(Vector3.RIGHT,1.),Vector3.ONE),Transform3D.IDENTITY)
 check(mag.basis.orthonormalized().is_equal_approx(Basis.IDENTITY),"hand magazine uses aim axes rather than tilted grip")
 var truck:Node3D=load("res://deathmatch/models/ground_transport/transport.glb").instantiate();stage.add_child(truck);Transport.prepare_windows(truck);Transport.prepare_seats(truck)
 check(Transport.data().seats.size()==8 and Transport.data().driver_seat==6,"transport holds a full eight-player squad")
 check(truck.has_node("OccupantSeats") and truck.get_node("OccupantSeats").get_child_count()>=16,"all occupants have visible seating and entry labels")
 for seat in [0,3,6,7]:
  camera.position=Transport.point(seat,"seat")+Vector3.UP*1.48;camera.fov=75;camera.look_at(camera.position+(Vector3(signf(camera.position.x),0,0) if seat<6 else Vector3.FORWARD))
  await settle();var image:=viewport.get_texture().get_image();image.save_png("/home/blux/.cache/cq-rec1-review/render/seat-"+str(seat)+".png");var color:=image.get_pixel(320,240)
  results["seat_"+str(seat)]=[color.r,color.g,color.b];check(color.b>color.r+.15,"outside visible from passenger/driver seat "+str(seat))
 truck.free()
 camera.position=Vector3.ZERO;camera.rotation=Vector3.ZERO
 var effect:=Effect.new();effect.enabled=true;effect.configure(1.,false,0.,12.,0.)
 var compositor:=Compositor.new();compositor.compositor_effects=[effect];env.compositor=compositor
 var ui:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.4,.25);ui.mesh=quad;ui.position=Vector3(0,0,-.8)
 var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;finish.albedo_color=Color(.04,.22,.9,1.);finish.no_depth_test=true;finish.render_priority=105;ui.material_override=finish;stage.add_child(ui)
 await settle();var ui_image:=viewport.get_texture().get_image();ui_image.save_png("/home/blux/.cache/cq-rec1-review/render/nvg-ui.png");var ui_pixel:=ui_image.get_pixel(320,240)
 check(ui_pixel.b>ui_pixel.g*2,"transparent UI retains blue colour under NVG shading")
 effect.enabled=false;env.compositor=null;RenderingServer.call_on_render_thread(effect.release)
 var points:=Points.new();points.reset(1);points.advance(2.49,[[4,0]]);check(points.owners[0]==-1,"four-player capture not early");points.advance(.01,[[4,0]]);check(points.owners[0]==0 and points.scores[0]==0,"four-player capture takes 2.5 seconds")
 points.reset(1);points.advance(20.,[[8,1]]);check(points.owners[0]==-1,"any opposing presence stops capture")
 var day_count:=0
 for i in 12000:
  if SkySource.sun_weights(i*.1,1200).dot(Vector3.ONE)>.5:day_count+=1
 check(absf(day_count/12000.-.55)<.001,"day is fifty-five percent of cycle")
 var runtime:=Runtime.new();var applied:=Foveation.apply(viewport,runtime,2,2,true);check(runtime.foveation_dynamic and applied.mode=="dynamic","dynamic foveation reaches runtime")
 applied=Foveation.apply(viewport,runtime,2,2,false);check(not runtime.foveation_dynamic and applied.mode=="static","static foveation remains explicitly selectable")
 viewport.queue_free();await process_frame;await process_frame
 print("CQ_LIVE_FIXES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":results}));quit(0 if failures.is_empty() else 1)
