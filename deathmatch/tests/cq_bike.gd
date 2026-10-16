extends SceneTree
const Fixtures=preload("res://deathmatch/tests/cq_transport_wheel.gd")
const Wheel=preload("res://deathmatch/vr/transport_wheel.gd")
const Geometry=preload("res://deathmatch/conquest/classes/bike_geometry.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var placements:Array=Tanks.placements().filter(func(p):return p.kind=="bike")
 check(placements.size()==Landscape.TYPES.size(),"one bike at every POI")
 for name in Landscape.TYPES:check(placements.filter(func(p):return p.poi==name).size()==1,"single bike for "+name)
 for p in placements:check(not Landscape.in_water(p.position),"bike spawns on land: "+p.poi)
 check(Tanks.PROFILES.bike.hp==50 and Tanks.PROFILES.bike.reverse==0. and Tanks.PROFILES.bike.forward>Tanks.PROFILES.transport.forward,"fast unarmed 50HP bike with no reverse")
 var game:=Fixtures.Game.new();root.add_child(game);game.bindings.physical_transport_steering=false
 game.battery_tanks.rows[0]={"kind":"bike","hp":50,"pilot":1,"yaw":0.}
 var rig:=Fixtures.Rig.new();game.add_child(rig);rig.game=game
 for n in [rig.left,rig.right,rig.head]+rig.hand_models:rig.add_child(n)
 var model:Node3D=load(Tanks.PROFILES.bike.model).instantiate();game.add_child(model);game.battery_tanks.models[0]=model
 check(model.find_child("Handlebars",true,false)!=null,"separate authored handlebars")
 check(model.find_child("Handlebars",true,false).position.distance_to(Geometry.point("steering_pivot"))<.001,"handlebar export pivots at physical steering socket")
 var wheel:=Wheel.new();wheel.setup(rig);wheel.update(.016)
 var frame:Transform3D=wheel.frame()
 check(wheel.grab_contact(Geometry.grip(0)+Vector3.BACK*.20),"bike rear grab extension is reachable from seat")
 check(not wheel.grab_contact(Geometry.grip(0)+Vector3.BACK*.50),"bike grab extension remains bounded")
 rig.left.global_position=frame*Geometry.grip(0);rig.right.global_position=frame*Geometry.grip(1);wheel.update(.016)
 rig.left.grip=1.;rig.right.grip=1.;wheel.update(.016)
 check(not wheel.hands[0].is_empty() and not wheel.hands[1].is_empty(),"both hands physically grip handlebars with transport setting off")
 var turn:=deg_to_rad(20.)
 rig.left.global_position=frame*(Basis(Vector3.UP,turn)*Geometry.grip(0));rig.right.global_position=frame*(Basis(Vector3.UP,turn)*Geometry.grip(1));wheel.update(.016)
 check(absf(wheel.angle-turn)<.001 and wheel.command().x<0.,"physical handlebar yaw produces steering")
 check(absf(model.find_child("Handlebars",true,false).rotation.y-turn)<.001,"rendered handlebars match physical angle")
 check(rig.hand_models[0].global_position.distance_to(rig.left.global_position)<.001 and rig.hand_models[1].global_position.distance_to(rig.right.global_position)<.001,"hands remain attached to handlebars")
 rig.right.trigger=1.;check(wheel.command().y==-1.,"main trigger accelerates bike")
 rig.left.trigger=1.;check(wheel.command().y==1.,"support trigger takes braking priority")
 rig.left_handed=true;rig.right.trigger=0.;check(wheel.command().y==-1.,"left-handed main trigger accelerates")
 rig.left.trigger=0.;rig.right.trigger=1.;check(wheel.command().y==1.,"left-handed support trigger brakes")
 game.menu_open=true;wheel.update(.016);check(wheel.command()==Vector2.ZERO and wheel.hands[0].is_empty(),"menu releases bike controls")
 game.menu_open=false;wheel.update(.016);check(wheel.hands[0].is_empty(),"held grips cannot auto-acquire after menu")
 game.free()
 await native_bridge()
 # Exercise the exact client movement path that formerly discarded jump in stroke-only mode.
 var actor=load("res://deathmatch/fighter.gd").new();root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.in_water=true;actor.stroke_only_water=true;actor.quake_movement=true
 actor.simulate(Vector2(0,-1),0.,false,1./60.,true,Vector3.ZERO)
 check(actor.velocity.y>0. and actor.velocity.z<0.,"client stroke-only swimmer can rise and move using jump without hand strokes")
 actor.free()
 if OS.get_cmdline_user_args().has("--integration"):await integration()
 if OS.get_cmdline_user_args().has("--render"):await render_bike()
 print("CQ_BIKE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func render_bike()->void:
 root.size=Vector2i(1400,1000)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("25323d");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;world.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=2.;world.add_child(light)
 var bike:Node3D=load(Tanks.PROFILES.bike.model).instantiate();world.add_child(bike)
 var body:=Node3D.new();world.add_child(body);body.position=Geometry.point("seat")
 var library=load("res://deathmatch/avatars/library.gd").new();world.add_child(library)
 var hash:String=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
 var avatar=library.create_avatar(hash);body.add_child(avatar);avatar.set_process(false);avatar.seated_bike=true;avatar.unarmed=true;avatar.speed=0.;avatar.grounded=true;avatar.distance_ik_enabled=false
 avatar.target_xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Geometry.point("steering_pivot")+Geometry.grip(0)-Geometry.point("seat")),"right":Transform3D(Basis.IDENTITY,Geometry.point("steering_pivot")+Geometry.grip(1)-Geometry.point("seat"))}
 for i in 20:avatar.advance_animation(.02)
 check(avatar.visual.get_instance_shader_parameter("animation_frames").z<0.,"native avatar uses static seated deformation")
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(4,2.8,-5);camera.look_at(Vector3(0,.9,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.2;camera.make_current()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/cq-bike-rider.png")
 world.free()

func integration()->void:
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.start_host("Bike QA",0,200,10,true,"tdm","ut99");game.set_process(false);game.set_physics_process(false)
 var tanks=game.battery_tanks;var key:int=tanks.rows.keys().filter(func(k):return tanks.rows[k].kind=="bike")[0];var row:Dictionary=tanks.rows[key]
 row.yaw=0.;row.position=Vector3(0,800,0);row.visual_y=800.;tanks.pose_body(key)
 var floor:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,1,30);shape.shape=box;floor.add_child(shape);floor.position=row.position-Vector3.UP*.5;game.add_child(floor)
 var id:=2;game.players[id]=game._new_state("Bike QA Rider",id);game._create_fighter(id)
 var state:Dictionary=game.players[id];state.team=0;state.spectator=false;state.dead=false;state.input_blocked=false;state.use_at=0.;state.last_input=game.clock;state.vr_device=false;game.classes.ensure(id)
 var actor=game.fighters[id];actor.set_process(false);actor.set_physics_process(false);actor.position=row.position+Vector3(1.5,0,0)
 await physics_frame;await physics_frame
 check(tanks.use(id),"live script player boards bike")
 check(tanks.mounted(id) and not tanks.protected_rider(id),"script rider is mounted and exposed")
 check(not tanks.bodies[key].has_node("TurretCollision") and not tanks.start_salvo(key),"bike has no phantom turret or weapon")
 tanks.draw();actor._process(.016)
 check(actor.vehicle_bike and actor.vehicle_avatar_visible and actor.avatar.visible,"live bike rider remains visibly seated")
 check(actor.avatar.get_node("LeftBoot").position.y>.25 if actor.avatar_hash.is_empty() else actor.avatar.seated_bike,"fallback and downloaded avatars receive seated pose")
 state.move=Vector2(1,-1);tanks.tick(.1)
 check(row.speed>0 and row.yaw<0.,"live script bike drives and steers")
 for i in 40:state.move=Vector2(0,1);tanks.tick(1./30.)
 check(row.speed==0.,"live script brake cannot reverse")
 state.jump=true;tanks.tick(1./30.)
 check(not tanks.mounted(id),"live script jump dismounts bike")
 check(tanks.damage(key,1,20,"grenade")==10 and row.hp==40,"live bike follows ordinary grenade damage")
 tanks.damage(key,1,100,"ordnance")
 check(row.hp==0 and absf(row.respawn_at-game.clock-120.)<.001,"live bike destruction schedules transport-length respawn")
 game.queue_free();await process_frame

func native_bridge()->void:
 var world:=Node3D.new();root.add_child(world)
 var body:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Tanks.PROFILES.bike.size;shape.shape=box;shape.position.y=box.size.y*.5;body.add_child(shape);world.add_child(body);body.position.y=10.
 var authority=ClassDB.instantiate("FPSAuthority");authority.configure_tick_rate(Engine.physics_ticks_per_second)
 check(authority.configure_world(world) and authority.configure_cq({"auto_respawn":false}) and authority.configure_frames(true),"native bike world configures")
 check(authority.attach_vehicle(4,body,0.,-1)==0,"Godot adapter accepts neutral bike kind")
 for i in 4:
  await physics_frame
  check(authority.advance(),"native bike world advances")
 var frame:Dictionary=preload("res://deathmatch/native/authority_protocol.gd").decode_frame(authority.snapshot())
 check(not frame.is_empty() and frame.vehicles.size()==1,"native bike snapshot decodes")
 if not frame.is_empty():
  var key=frame.vehicles.keys()[0];var projected:Array=preload("res://deathmatch/native/cq_presentation.gd").project(frame,0.,1,120.)
  check(projected[10]["ctk:"+str(key)].kind=="bike","native bike kind projects into client vehicle service")
 authority=null;world.free()
