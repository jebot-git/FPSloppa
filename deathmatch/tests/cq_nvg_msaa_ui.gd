extends SceneTree
const Effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd")
const Exposure=preload("res://deathmatch/conquest/classes/nvg_exposure.gd")
var checks:=0
var failures:Array=[]
var effect
var viewport:SubViewport
var camera:Camera3D
var results:Dictionary={}
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func capture(name:String,day:float=0.,blind:float=0.,spots:Array=[])->Image:
 effect.configure(lerpf(6000,1.3,day),false,blind,12.,day,spots)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image:=viewport.get_texture().get_image();image.save_png("/home/blux/.cache/cq-rec1-review/nvg/"+name+".png");return image
func stats(image:Image)->Dictionary:
 var hf:=0.;var white:=0;var soft:=0
 for y in range(90,390,2):
  for x in range(110,530,2):
   var c:=image.get_pixel(x,y);hf+=absf(c.g-image.get_pixel(x+1,y).g)
   var whiteness:float=minf(c.r,c.b)/maxf(.001,c.g)
   if whiteness>.9 and c.r>.6:white+=1
   if whiteness>.35 and whiteness<.85 and c.r>.15:soft+=1
 return {"hf":hf/(150*210),"white":white,"soft":soft}
func run():
 DirAccess.make_dir_recursive_absolute("/home/blux/.cache/cq-rec1-review/nvg")
 viewport=SubViewport.new();viewport.size=Vector2i(640,480);viewport.msaa_3d=Viewport.MSAA_4X;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.12,.12);stage.add_child(environment)
 effect=Effect.new();effect.enabled=true;var compositor:=Compositor.new();compositor.compositor_effects=[effect];environment.compositor=compositor
 camera=Camera3D.new();camera.near=.02;camera.fov=65;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;stage.add_child(camera);camera.make_current()
 var aa=load("res://deathmatch/conquest/classes/night_vision_view.gd").new();aa.configure_aa(viewport,true)
 check(viewport.msaa_3d==Viewport.MSAA_DISABLED and viewport.screen_space_aa==Viewport.SCREEN_SPACE_AA_FXAA,"NVG uses FXAA when requested MSAA would overwrite its resolve")
 var night:Image=await capture("night");var day:Image=await capture("day",1.)
 results.night=stats(night);results.day=stats(day)
 check(Exposure.noise(1,false)>Exposure.noise(0,false)*12 and Exposure.noise(1,true)>Exposure.noise(0,true)*12,"day grain exceeds night grain by more than twelve times for both classes")
 check(results.day.hf>results.night.hf*4,"rendered daytime grain is substantially stronger than night")
 check(results.day.white==0 and results.night.white==0,"ordinary daylight and night do not produce whiteout")
 var spot:Dictionary={"position":Vector3(1.5,0,-8),"radius":.65,"strength":1.}
 var small:Image=await capture("muzzle",0.,0.,[spot]);results.muzzle=stats(small)
 check(results.muzzle.white>10 and results.muzzle.white<1500,"muzzle flash creates a localized white spot")
 check(results.muzzle.soft>20,"flash spot has soft, partially white borders")
 spot.radius=1.3
 var large:Image=await capture("explosion",0.,0.,[spot]);results.explosion=stats(large)
 check(results.explosion.white>results.muzzle.white*2,"larger explosion produces proportionally larger white area")
 spot.position=Vector3(3,0,-16);spot.radius=.65
 var far:Image=await capture("distant-flash",0.,0.,[spot]);results.distant=stats(far)
 check(results.distant.white<results.muzzle.white*.6,"distant flash has proportionally smaller white area")
 spot.position=Vector3(0,0,-.1);spot.radius=10
 var close:Image=await capture("close-flash",0.,0.,[spot]);results.close=stats(close)
 check(results.close.white<150*210*.7,"even a near explosion cannot request full-field whiteout")
 var white:Image=await capture("direct-light",0.,1.);results.direct=stats(white)
 check(results.direct.white>150*210*.9,"direct source can produce whiteout")
 var clear:Image=await capture("look-away");results.away=stats(clear)
 check(results.away.white==0,"looking away immediately removes full-screen whiteout")
 spot.position=Vector3(0,0,8);spot.radius=.65
 var behind:Image=await capture("flash-behind",0.,0.,[spot]);check(stats(behind).white==0,"flash behind camera paints no pixels")
 var left:=Exposure.spot(Vector3(0,0,-.6),.1,1.,Transform3D(Basis.IDENTITY,Vector3(-.032,0,0)))
 var right:=Exposure.spot(Vector3(0,0,-.6),.1,1.,Transform3D(Basis.IDENTITY,Vector3(.032,0,0)))
 check(left[0]>0 and right[0]<0,"near flash directions respect separate eye origins")
 var ui:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.035,.035);ui.mesh=quad
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.no_depth_test=true;mat.albedo_color=Color(.02,.15,.8,1);ui.material_override=mat;stage.add_child(ui)
 for distance in [.08,.3,1.5]:
  ui.position=Vector3(0,0,-distance);ui.scale=Vector3.ONE*distance/.08
  var panel:Image=await capture("ui-"+str(distance));var pixel:=panel.get_pixel(320,240);var world:=panel.get_pixel(200,240)
  check(pixel.b>pixel.g*2.,"UI remains blue at close distance "+str(distance))
  check(world.g>world.b*2.,"UI plane does not overwrite world NVG at distance "+str(distance))
 ui.free();aa.configure_aa(viewport,false);check(viewport.msaa_3d==Viewport.MSAA_4X,"NVG restores requested MSAA when removed");aa.free()
 effect.enabled=false;environment.compositor=null;await process_frame;RenderingServer.call_on_render_thread(effect.release);await process_frame;await process_frame
 viewport.queue_free();await process_frame
 print("CQ_NVG_RENDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":results}));quit(0 if failures.is_empty() else 1)
