extends SceneTree
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var scene:=Node3D.new();root.add_child(scene)
 for kind in ["light","heavy"]:
  var mount:=Node3D.new();scene.add_child(mount)
  var model:Node3D=load(Tanks.PROFILES[kind].model).instantiate();mount.add_child(model);Tanks.normalise_model(model)
  var yaw:Node3D=model.find_child("Yaw",true,false);var aim:Node3D=model.find_child("Aim",true,false)
  var turret:Node3D=model.find_child("Turret",true,false);var barrel:MeshInstance3D=aim.find_children("*","MeshInstance3D",true,false)[0]
  check(turret.position.length()<.00001 and barrel.position.length()<.00001,kind+" mesh offsets are baked into geometry, not applied around pivots")
  for slope in [0.,.3]:
   for hull_yaw in [0.,.8]:
    var row:Dictionary={"yaw":hull_yaw,"normal":Basis(Vector3.FORWARD,slope)*Vector3.UP,"direction":Vector3.FORWARD}
    mount.position=Vector3(7,2,-9);mount.basis=Tanks.visual_basis(row)
    var expected:Vector3=mount.global_transform*Tanks.PROFILES[kind].pivot
    for turn in [-PI,-PI/2,0.,PI/2,PI]:
     for pitch in [deg_to_rad(Tanks.PROFILES[kind].pitch_min),0.,deg_to_rad(Tanks.PROFILES[kind].pitch_max)]:
      row.direction=mount.basis*Basis(Vector3.UP,turn)*Basis(Vector3.RIGHT,pitch)*Vector3.FORWARD
      Tanks.pose_turret(mount,row)
      check(yaw.global_position.distance_to(expected)<.0001 and turret.global_position.distance_to(expected)<.0001,kind+" turret rotates in place around the hull pivot")
      check(aim.global_position.distance_to(expected)<.0001 and barrel.global_position.distance_to(expected)<.0001,kind+" barrel pitch keeps its hinge attached")
      check((-aim.global_basis.z).distance_to(row.direction)<.0001,kind+" barrel axis matches authoritative aim")
      var tip:Vector3=barrel.global_transform*Vector3(0,0,-Tanks.PROFILES[kind].length)
      check(tip.distance_to(expected+row.direction*Tanks.PROFILES[kind].length)<.0001,kind+" visible gun endpoint matches firing axis")
  mount.free()
 if DisplayServer.get_name()!="headless":
  root.size=Vector2i(1280,800)
  var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("26343d");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.7;env.environment=environment;scene.add_child(env)
  var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-55,-25,0)
  var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(10,15,20);camera.look_at(Vector3(0,.5,0));camera.fov=52;camera.current=true
  for row_index in 2:
   var kind:String=["light","heavy"][row_index]
   for column in 3:
    var mount:=Node3D.new();scene.add_child(mount);mount.position=Vector3((column-1)*6,0,(row_index-.5)*7)
    var model:Node3D=load(Tanks.PROFILES[kind].model).instantiate();mount.add_child(model);Tanks.normalise_model(model)
    var direction:Vector3=Basis(Vector3.UP,(column-1)*PI/2)*Basis(Vector3.RIGHT,.2)*Vector3.FORWARD
    Tanks.pose_turret(mount,{"normal":Vector3.UP,"direction":direction})
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://docs/validation/voxel-battle/turret-axes-20261015")
  root.get_texture().get_image().save_png("res://docs/validation/voxel-battle/turret-axes-20261015/axes.png")
 scene.free();await process_frame
 print("CQ_TURRET_AXES ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
