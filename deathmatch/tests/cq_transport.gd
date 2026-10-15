extends SceneTree
const Geometry=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var placements:=Tanks.placements().filter(func(p):return p.kind=="transport")
 check(placements.size()==4,"four transports on map")
 check(placements.filter(func(p):return p.team==0).size()==2 and placements.filter(func(p):return p.team==1).size()==2,"two transports per allied team")
 var rocket:Dictionary=Tanks.PROFILES.rocket;var transport:Dictionary=Tanks.PROFILES.transport
 check([transport.forward,transport.reverse,transport.turn,transport.acceleration]==[rocket.forward,rocket.reverse,rocket.turn,rocket.acceleration],"script transport has rocket mobility")
 check(transport.capacity==0 and transport.pair==0,"script transport is unarmed")
 check(transport.hp==100 and transport.hp==rocket.hp,"script transport shares battery tank 100 HP")
 var model:Node3D=load(transport.model).instantiate();root.add_child(model)
 for i in 6:
  var entry:Node3D=model.find_child("Entry"+str(i),true,false);var seat:Node3D=model.find_child("Seat"+str(i),true,false)
  check(entry!=null and entry.position.distance_to(Geometry.point(i,"entry"))<.0001,"exported pod entry matches manifest")
  check(seat!=null and seat.position.distance_to(Geometry.point(i,"seat"))<.0001,"exported pod seat matches manifest")
 check(model.find_child("Yaw",true,false)==null and model.find_children("*turret*","",true,false).is_empty(),"export contains no turret")
 Geometry.prepare_windows(model)
 var windows=model.find_child("PodWindows",true,false)
 check(windows!=null and windows.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"pod window remains transparent")
 model.queue_free()
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.start_host("Transport QA",0,200,10,true,"tdm","ut99");game.set_process(false);game.set_physics_process(false)
 var tanks=game.battery_tanks;var key:int=tanks.rows.keys().filter(func(k):return tanks.rows[k].kind=="transport")[0];var row:Dictionary=tanks.rows[key]
 var floor:=StaticBody3D.new();var fc:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(50,1,50);fc.shape=box;floor.position=row.position-Vector3.UP*.5;floor.add_child(fc);game.add_child(floor)
 # Isolate this candidate transport from the authored world for deterministic boarding.
 row.yaw=0.;row.position=Vector3(0,800,0);row.visual_y=800.;floor.position=row.position-Vector3.UP*.5;tanks.pose_body(key)
 for i in 8:
  var id:int=i+1
  if not game.players.has(id):game.players[id]=game._new_state("Ally "+str(id),id);game._create_fighter(id)
  game.players[id].team=row.team;game.players[id].spectator=false;game.players[id].dead=false;game.players[id].input_blocked=false;game.players[id].use_at=0.;game.classes.ensure(id)
  game.fighters[id].set_physics_process(false);game.fighters[id].set_process(false);game.fighters[id].position=row.position+Geometry.point(i,"entry")
 await physics_frame;await physics_frame
 for i in 8:
  check(tanks.use(i+1),"script pod use boards ally")
  check(tanks.seat_index(i+1,key)==i and game.fighters[i+1].vehicle_seated,"script occupant occupies authored pod")
 check(not tanks.bodies[key].has_node("TurretCollision"),"transport has no phantom turret collider")
 check(not tanks.start_salvo(key),"script driver cannot start weapon salvo")
 game.players[7].last_input=game.clock;game.players[7].vr_device=false;game.players[7].offhand_fire=false;tanks.tick(1./30)
 game.players[1].offhand_fire=true;tanks.tick(1./30);check(not row.headlights,"script passenger cannot toggle lights")
 game.players[7].offhand_fire=true;tanks.tick(1./30);check(row.headlights,"script driver toggles headlights")
 tanks.tick(1./30);check(row.headlights,"script held trigger toggles only once")
 tanks.draw();check(tanks.models[key].get_node("HeadlightLenses").visible,"gameplay draw enables real vehicle lamp faces")
 game.players[7].offhand_fire=false;tanks.tick(1./30);game.players[7].offhand_fire=true;tanks.tick(1./30);check(not row.headlights,"script fresh press switches headlights off")
 game.players[7].offhand_fire=false;game.players[1].offhand_fire=false

 var view=load("res://deathmatch/conquest/classes/battery_view.gd").new();game.add_child(view);view.setup(game,tanks)
 var mask:int=game.camera.cull_mask;var env=game.camera.environment;view.update()
 check(view.viewport==null and game.camera.cull_mask==mask and game.camera.environment==env,"transport keeps direct world view without tank scope isolation")
 check(game.match_mode.status(1).contains("JUMP TO DISMOUNT"),"transport HUD explains jump exit")
 check(tanks.leave(7) and row.pilot==0,"script driver exit leaves cockpit vacant")
 game.players[4].jump=true;game.players[4].last_input=game.clock;tanks.tick(1./30)
 check(not tanks.mounted(4),"script jump dismounts passenger")
 var incoming:Dictionary=tanks.rows.duplicate(true);incoming[key].kind="light";incoming[key].pilot=0
 tanks.receive(incoming,0.)
 check(tanks.bodies[key].has_node("TurretCollision") and tanks.bodies[key].get_child(0).shape.size==Tanks.PROFILES.light.size,"incoming native ID rebuilds transport placeholder as tank")
 incoming[key].kind="transport";incoming[key].seats=[0,0,0,0,0,0,0,0];tanks.receive(incoming,0.)
 check(not tanks.bodies[key].has_node("TurretCollision") and tanks.bodies[key].get_child(0).shape.size==Tanks.PROFILES.transport.size,"incoming native ID rebuilds tank placeholder as transport")
 view.queue_free();game.disconnect_game();game.queue_free();await process_frame;await process_frame
 # A real render from every pod must show the outside through its window.
 var viewport:=SubViewport.new();viewport.size=Vector2i(640,400);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage);var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.07,.32,.68);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;stage.add_child(environment)
 model=load(transport.model).instantiate();stage.add_child(model);Geometry.prepare_windows(model)
 var camera:=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.near=.02;camera.fov=75;stage.add_child(camera);camera.make_current()
 camera.position=Vector3(5,3.6,-6);camera.fov=55;camera.look_at(Vector3(0,1.2,0));await process_frame;await process_frame;await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png("/tmp/cq-lpmac/transport-exterior.png")
 for i in 6:
  camera.fov=75
  camera.position=Geometry.point(i,"seat")+Vector3.UP*1.48;camera.look_at(camera.position+Vector3(signf(camera.position.x),0,0))
  var first:="";var nearest:=INF
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var faces:PackedVector3Array=mesh.mesh.get_faces()
   for t in range(0,faces.size(),3):
    var hit:Variant=Geometry3D.segment_intersects_triangle(camera.position,camera.position+Vector3(signf(camera.position.x)*3,0,0),faces[t],faces[t+1],faces[t+2])
    if hit is Vector3 and camera.position.distance_to(hit)<nearest:nearest=camera.position.distance_to(hit);first=mesh.name
  check(first=="PodWindows" and nearest<.6,"pod camera sits inside its authored window "+str(i))
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image();var pixel:=image.get_pixel(320,200)
  check(pixel.b>pixel.r+.18 and pixel.g>pixel.r+.1,"outside is visible through pod window "+str(i))
  if i in [0,3]:image.save_png("/tmp/cq-lpmac/transport-pod-"+str(i)+".png")
 viewport.queue_free();await process_frame;await process_frame
 print("CQ_TRANSPORT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
