extends SceneTree
const Test=preload("res://deathmatch/tests/cq_healing_field.gd")
const Turrets=preload("res://deathmatch/conquest/classes/turrets.gd")
class Vehicle extends StaticBody3D:
	var hp:=500
	var team:=1
	func _ready() -> void:
		collision_layer=1;add_to_group("cq_repairable_vehicles");var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,2,3);shape.shape=box;add_child(shape)
	func owns_collider(node) -> bool:return node==self
	func damage(_team:int,amount:int,_kind:String="infantry") -> void:hp-=amount
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func ready(game) -> void:
	game.players[1].team=0;game.players[1].weapon=6;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[1].position=Vector3.ZERO
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Turret",28798,100,10,false)
	game.classes.choose(1,"technician");game._spawn(1);ready(game)
	check(game.classes.deploy(1,Vector3.ZERO),"T1 technician retains ammo box")
	game.classes.award(1,7499);check(not game.classes.choose_utility(1,"technician","turret"),"Turret remains locked below level 15")
	game.classes.award(1,1);check(game.classes.choose_utility(1,"technician","turret"),"T2 turret unlocks at 7500 technician XP")
	game._spawn(1);ready(game)
	check(game.classes.dispensers.is_empty() and not game.classes.deploy(1,Vector3.ZERO) and 6 in game.players[1].owned and 7 in game.players[1].owned,"T2 replaces dispenser ability, retains placement slot and repair tool")
	check(game.match_mode.fortress.weapon_data(1,6).name=="TURRET DEPLOYER" and game.match_mode.fortress.art_rules(1,6)=="cq_turret","Placement slot uses turret deployer name and handheld tool instead of ammo box")
	await physics_frame;await physics_frame
	check(game.deploy_class_box(1),"Existing placement action deploys turret on flat ground")
	var service=game.turrets;var key:int=service.rows.keys()[0];var row:Dictionary=service.rows[key];var origin:Vector3=row.position
	check(row.hp==200 and row.ammo==12 and service.bodies.has(key) and game.classes.states[1].turret_ready-game.clock==120,"Turret starts with 200 HP, twelve shots, stationary collision and two-minute cooldown")
	check(not service.deploy(1),"Cooldown prevents another deployment")
	game._spawn(1);ready(game);check(service.rows.has(key) and not service.deploy(1),"Respawn retains turret and its cooldown")
	game._add_player(2,"Enemy");game.players[2].team=1;game.fighters[2].position=origin+Vector3(12,0,0)
	game._add_player(3,"Friendly");game.players[3].team=0;game.fighters[3].position=origin+Vector3(5,0,0)
	var vehicle:=Vehicle.new();game.get_node("Map").add_child(vehicle);vehicle.position=origin+Vector3(-40,1,0)
	await physics_frame;await physics_frame
	check(service.target(key,game.variant_combat.vehicle_lock.targets(game)).name.begins_with("v:"),"Visible vehicle is prioritized over nearer enemy infantry")
	service.tick();check(row.ammo==11 and game.projectiles.size()==1,"Autonomous turret fires one ordnance projectile and consumes one reserved shot")
	var shot:Dictionary=game.projectiles.values()[0]
	check(shot.definition.guided==false and shot.definition.gravity==0 and shot.extra.get("vehicle_target","").is_empty() and shot.definition.damage==100 and shot.definition.splash==120,"Turret shot is unguided single ordnance using existing 100 direct / 120 splash rules")
	var velocity:Vector3=shot.velocity;vehicle.position+=Vector3(0,0,20);game.variant_combat.vehicle_lock.guide(game,.5);check(shot.velocity==velocity,"Moving vehicle cannot turn an already fired turret projectile")
	game.clock+=1.49;service.tick();check(row.ammo==11,"Moderate fire interval blocks early repeat")
	game.clock+=.12;service.tick();check(row.ammo==10,"Turret fires again after 1.5-second interval")
	vehicle.team=0;game.clock+=.11;service.tick();check(row.target=="p:2","Friendly vehicle is ignored and enemy infantry acquired")
	game.fighters[2].position=origin+Vector3(Turrets.RANGE+.1,0,0);check(service.target(key,game.variant_combat.vehicle_lock.targets(game)).is_empty(),"Targets beyond turret range are ignored")
	game.fighters[2].position=origin+Vector3(Turrets.RANGE,0,0);check(service.target(key,game.variant_combat.vehicle_lock.targets(game)).get("name","")=="p:2","Enemy at turret range boundary can be targeted")
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.3,5,5);shape.shape=box;wall.add_child(shape);game.get_node("Map").add_child(wall);wall.position=origin+Vector3(5,2,0)
	await physics_frame;await physics_frame
	check(service.target(key,game.variant_combat.vehicle_lock.targets(game)).is_empty(),"Solid world geometry blocks autonomous target acquisition")
	wall.queue_free();await process_frame;await physics_frame
	game.fighters[2].position=origin+Vector3(15,0,0)
	for i in 10:game.clock+=1.6;service.tick()
	check(service.rows.is_empty() and game.projectiles.size()==12,"Turret removes itself immediately after its twelfth shot")
	game.clock=game.classes.states[1].turret_ready;ready(game);check(service.deploy(1),"New turret is available at two minutes")
	key=service.rows.keys()[0];var previous:int=key;game.clock+=120
	game.players[1].pitch=-PI/2;game.fighters[1].position=Vector3(600,0,600)
	check(not service.deploy(1) and service.rows.has(previous),"Invalid or obstructed placement preserves old turret and cooldown readiness")
	ready(game);check(service.deploy(1) and service.rows.size()==1 and not service.rows.has(previous),"New placement replaces old turret, keeping one per owner")
	key=service.rows.keys()[0];row=service.rows[key]
	service.damage(key,3,100);check(row.hp==200,"Small arms retain allied turret protection")
	service.damage(key,3,10,-1,"ordnance");check(row.hp==190,"Allied ordnance damages deployable turret");row.hp=200
	await physics_frame;await physics_frame
	var ray:Dictionary=game._trace(row.position+Vector3(0,1,-4),row.position+Vector3(0,1,4),2)
	check(ray.has("cq_turret"),"Turret participates in real weapon collision traces")
	game._damage_map_hit(ray,2,100);check(row.hp==100,"Real weapon map-hit path damages turret")
	game._damage_map_hit(ray,2,100);check(service.rows.is_empty(),"Two hundred damage destroys turret")
	game.clock+=120;ready(game);check(service.deploy(1),"Destroyed turret may be redeployed when cooldown permits")
	key=service.rows.keys()[0];row=service.rows[key];service.damage(key,2,100,999);game.variant_combat.active_projectile=999;service.blast(row.position+Vector3.UP,2,120,5,true);game.variant_combat.active_projectile=-1
	check(row.hp==100,"Direct ordnance hit is not charged twice as splash")
	service.blast(row.position+Vector3.UP*.7,2,100,5,true);check(service.rows.is_empty(),"Independent rocket splash can destroy turret")
	game.clock+=120;ready(game);var floor:=StaticBody3D.new();floor.collision_layer=1;floor.position=Vector3(0,3.75,-1.6);var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(5,.5,5);floor_shape.shape=floor_box;floor.add_child(floor_shape);game.get_node("Map").add_child(floor);game.fighters[1].position.y=4
	await physics_frame;await physics_frame
	floor.rotation.z=.25;await physics_frame;await physics_frame
	check(not service.deploy(1),"Sloped floor fails flat-ground placement validation")
	floor.rotation.z=0;floor_box.size.x=1.5;await physics_frame;await physics_frame
	check(not service.deploy(1),"Narrow ledge fails full-footprint support validation")
	floor_box.size.x=5;await physics_frame;await physics_frame
	check(service.deploy(1) and service.rows.values()[0].position.y>4,"Turret can be placed on an elevated structure floor")
	key=service.rows.keys()[0];game.players[1].dead=true
	check(service.rows.has(key),"Deployed turret persists after owner death")
	var snapshot:Dictionary=game.match_mode.snapshot();check(snapshot.has("ctu:"+str(key)),"Turret state is independently replicated")
	var replica:=Turrets.new();game.add_child(replica);replica.setup(game);replica.receive(service.rows,500);check(replica.rows[key].fire_at==service.rows[key].fire_at+500 and replica.bodies[key].position==service.rows[key].position,"Client clock offsets and stationary collision placement match authority")
	var model:Node3D=load("res://deathmatch/models/turret/turret.glb").instantiate();check(triangles(model)>0 and triangles(model)<=1500,"Optimized requested turret imports within 1500-triangle budget");model.free()
	game.match_mode.reset();check(service.rows.is_empty() and service.bodies.is_empty(),"Round reset clears turret and collision state")
	print("CQ_TURRET_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func triangles(node:Node) -> int:
	var count:=0
	if node is MeshInstance3D:count+=node.mesh.get_faces().size()/3
	for child in node.get_children():count+=triangles(child)
	return count
