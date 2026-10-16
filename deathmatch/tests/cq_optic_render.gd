extends SceneTree
const Scope=preload("res://deathmatch/vr/sniper_scope.gd")
const Models=preload("res://deathmatch/conquest/classes/models.gd")
class RigMock extends Node3D:
 var gun:=Node3D.new()
 var head:=Camera3D.new()
 var gun_id:=9
class GameMock extends Node3D:
 var active:=true
 var menu_open:=false
 var viewmodel
 var offhand_viewmodel
 var xr_rig:RigMock
 var players:Dictionary={1:{"serial":3}}
 var impacts:Array=[]
 func is_vr()->bool:return true
 func _impacts(start:Vector3,ends:PackedVector3Array,_weapon:int)->void:impacts.append([start,ends])
class TankMock extends RefCounted:
 var models:Dictionary={}
 var bodies:Dictionary={}
 func key_for(_id:int)->int:return 1
 func view_row(_key:int)->Dictionary:return {"kind":"light","direction":Vector3.FORWARD}
 func muzzle(_row:Dictionary)->Vector3:return Vector3(0,1,-1)
var checks:=0
var failures:Array=[]
var out:="res://test-results/cq-optics"
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func draw_frames()->void:
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
func red_pixels(image:Image)->Dictionary:
 var count:=0;var sum_x:=0.
 for y in image.get_height():
  for x in image.get_width():
   var c:=image.get_pixel(x,y)
   if c.r>.65 and c.g<.25 and c.b<.25:count+=1;sum_x+=x
 return {"count":count,"x":sum_x/maxi(1,count)}
func run()->void:
 var args:=OS.get_cmdline_user_args();var index:=args.find("--output")
 if index>=0 and index+1<args.size():out=args[index+1]
 DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1024,768)
 for radius in [.01365,.01479]:
  for distance in [.06,.12,.25]:
   for zoom in [1.5,3.,6.]:
    var fov:=Scope.aperture_fov(radius,distance,zoom)
    check(is_equal_approx(radius/distance/tan(deg_to_rad(fov)*.5),zoom),"physical aperture magnification %.1fx"%zoom)
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.04,.08,.16);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1;scene.add_child(env)
 var camera:=Camera3D.new();camera.fov=20;camera.near=.01;camera.position=Vector3(0,0,.18);scene.add_child(camera);camera.make_current()
 var glass:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.028,.028);glass.mesh=quad
 var mat:=ShaderMaterial.new();mat.shader=preload("res://deathmatch/conquest/classes/red_dot.gdshader");glass.material_override=mat;scene.add_child(glass)
 for x in [0.,.008,-.008,.018]:
  camera.position.x=x;await draw_frames()
  var image:=root.get_texture().get_image();var red:=red_pixels(image)
  image.save_png(out+"/dot-%d.png"%roundi(x*1000))
  check(red.count>0 and absf(red.x-511.5)<3 if absf(x)<.014 else red.count==0,"collimated dot stays at aim direction and clips outside aperture %.3f"%x)
 glass.free()
 for slot in [1,4]:
  var rifle:=Models.weapon(slot,"cq_shocktroop");scene.add_child(rifle);rifle.scale=Vector3.ONE*.65
  var dot:Node3D=rifle.find_child("AlignedRedDot",true,false)
  for shift in [0.,.005]:
   camera.global_transform=Transform3D(dot.global_basis.orthonormalized(),dot.global_position+Vector3(shift,0,.12));camera.fov=20
   await draw_frames();var rendered:=root.get_texture().get_image();var red:=red_pixels(rendered)
   check(red.count>0 and absf(red.x-511.5)<4,"reticle is visible through authored housing and remains collimated %d %.3f"%[slot,shift])
   rendered.save_png(out+"/housing-%d-%d.png"%[slot,roundi(shift*1000)])
  rifle.free()
 var model:=Models.weapon(9,"cq_scout");scene.add_child(model);model.scale=Vector3.ONE*.65
 var optic=Scope.new();scene.add_child(optic);optic.attach(model)
 camera.fov=65;camera.global_position=optic.lens.global_position+Vector3(0,0,.12)
 for i in 7:
  var target:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.5,3,.1);target.mesh=mesh;target.position=Vector3((i-3)*1.5,optic.lens.global_position.y,-30)
  var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_color=Color(1,.1,.05) if i%2==0 else Color(.1,.3,1);target.material_override=finish;scene.add_child(target)
 for zoom in [1.5,3.,6.]:
  optic.zoom=zoom;optic.update_view(model,[camera.global_transform],Transform3D(Basis.IDENTITY,model.to_global(model.get_meta("muzzle"))),true)
  await draw_frames();check(optic.active,"aligned scope activates")
  root.get_texture().get_image().save_png(out+"/scope-%.1f.png"%zoom)
 var before:Image=optic.viewport.get_texture().get_image()
 var nvg=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new();nvg.configure(6.,false,0.,0.,1.);nvg.enabled=true
 env.compositor=Compositor.new();env.compositor.compositor_effects=[nvg]
 await draw_frames();var after:Image=optic.viewport.get_texture().get_image()
 var difference:=0.
 for point in [Vector2i(256,256),Vector2i(220,220),Vector2i(300,300)]:difference+=before.get_pixelv(point).r-after.get_pixelv(point).r
 check(absf(difference)<.01,"scope camera does not inherit headset NVG compositor")
 root.get_texture().get_image().save_png(out+"/scope-nvg.png")
 env.compositor=null;nvg.enabled=false;RenderingServer.call_on_render_thread(nvg.release)
 await process_frame
 var game:=GameMock.new();scene.add_child(game);game.xr_rig=RigMock.new();game.add_child(game.xr_rig);game.xr_rig.add_child(game.xr_rig.head);game.xr_rig.add_child(game.xr_rig.gun)
 game.xr_rig.gun.position=Vector3(.25,.1,0);game.xr_rig.gun.set_meta("muzzle",Vector3(0,0,-.2))
 var authority=preload("res://deathmatch/native/cq_authority.gd").new();authority.game=game
 var trace:={"kind":7,"actor":1,"life":3,"position":Vector3(0,.1,-.2),"direction":Vector3.FORWARD,"value":20.,"detail":9,"entity":0}
 authority.effects({"events":{1:trace}})
 check(game.impacts[0][0].distance_to(game.xr_rig.gun.to_global(Vector3(0,0,-.2)))<.001,"confirmed local tracer starts at current rendered muzzle")
 check(game.impacts[0][1][0]==trace.position+trace.direction*trace.value,"cosmetic tracer correction preserves authoritative impact")
 trace=trace.duplicate();trace.actor=2;authority.effects({"events":{2:trace}})
 check(game.impacts[1][0]==trace.position,"remote tracer retains authoritative origin")
 var tanks:=TankMock.new();var hull:=Node3D.new();game.add_child(hull);tanks.models[1]=hull
 var body:=StaticBody3D.new();game.add_child(body);tanks.bodies[1]=body
 var view=preload("res://deathmatch/conquest/classes/battery_view.gd").new();game.add_child(view);view.setup(game,tanks);view.set_process(false);view.update()
 check(hull.visible,"VR vehicle view leaves own hull visible for heading reference")
 view.deactivate();authority.free();game.free()
 var report:={"checks":checks,"failures":failures};FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("CQ_OPTICS ",JSON.stringify(report));scene.free();quit(1 if failures.size() else 0)
