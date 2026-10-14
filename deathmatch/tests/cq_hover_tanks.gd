extends SceneTree
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
const Timers=preload("res://deathmatch/conquest/classes/revival_timers.gd")
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pulse(game,time:float,fire:bool=true,move:=Vector2.ZERO) -> void:
	game.clock=time;game.players[1].last_input=time;game.players[1].fire=fire;game.players[1].move=move;game.battery_tanks.tick(.05)
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Hover",28807,100,10,false)
	var tanks=game.battery_tanks;tanks.configure();game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].invulnerable=0
	check(tanks.rows.values().filter(func(r):return r.kind=="light").size()==4 and tanks.rows.values().filter(func(r):return r.kind=="heavy").size()==2,"Four light and two heavy tanks plus two existing rocket batteries")
	for key in tanks.rows:tanks.rows[key].position=Vector3(key*25,.03,0);tanks.rows[key].yaw=0;tanks.rows[key].visual_y=.28;tanks.pose_body(key)
	game._add_player(2,"Enemy");game.players[2].team=1;game.players[2].invulnerable=0
	await physics_frame;await physics_frame
	for key in [2,6]:
		var row:Dictionary=tanks.rows[key];var config:Dictionary=tanks.profile(row)
		game.fighters[1].position=row.position+Vector3(3.5,0,0);game.players[1].use_at=0;check(tanks.use(1) and tanks.key_for(1)==key,"Board "+row.kind+" using shared Use controls")
		check(row.hp==config.hp and tanks.damage(key,1,100,"infantry")==0,"Infantry immunity and full initial HP "+row.kind)
		check(tanks.damage(key,1,100,"grenade")==50 and tanks.damage(key,1,100,"ordnance")==100,"Half grenade and full ordnance damage "+row.kind)
		check(tanks.bodies[key].repair(0,999)==150 and row.hp==config.hp and tanks.bodies[key].repair(1,30)==0,"Repair respects type HP cap and allied team "+row.kind)
		game.players[1].pitch=1.4;game.players[1].yaw=.7;pulse(game,game.clock+.1,false)
		check(is_equal_approx(rad_to_deg(asin(row.direction.y)),config.pitch_max),"Barrel elevation constrained "+row.kind)
		game.players[1].pitch=-1.4;pulse(game,game.clock+.1,false)
		check(is_equal_approx(rad_to_deg(asin(row.direction.y)),config.pitch_min),"Barrel depression constrained "+row.kind)
		game.players[1].xr={"weapon":Transform3D(Basis(Vector3.UP,.4)*Basis(Vector3.RIGHT,.2),Vector3(0,1,0))};pulse(game,game.clock+.1,false)
		check(row.direction.distance_to(-(Basis(Vector3.UP,game.players[1].yaw)*game.players[1].xr.weapon.basis).z)<.001,"Tracked hand follows aim inside pitch limits "+row.kind);game.players[1].xr={};game.players[1].pitch=.1;game.players[1].yaw=0
		var first:int=game.projectiles.size();var start:float=game.clock+1
		for volley in config.capacity:pulse(game,start+volley*1.5)
		check(game.projectiles.size()-first==config.capacity*config.pair and row.rounds==0,"Exact magazine/paired volley count "+row.kind)
		check(is_equal_approx(row.reload_at-game.clock,config.reload),"Reload starts after final volley "+row.kind)
		var ready:float=row.reload_at;pulse(game,ready-.01);check(game.projectiles.size()-first==config.capacity*config.pair,"No shot before reload deadline "+row.kind)
		pulse(game,ready);check(game.projectiles.size()-first==(config.capacity+1)*config.pair and row.rounds==config.capacity-1,"Unlimited ammo refills at deadline "+row.kind)
		var shot:Dictionary=game.projectiles.values().back();check(shot.definition.cq_effect=="ordnance" and not shot.definition.guided and shot.definition.gravity==0 and shot.definition.speed==40,"Direct unguided ordnance definition "+row.kind)
		if config.pair==2:
			var shots:Array=game.projectiles.values();var a:Dictionary=shots[-2];var b:Dictionary=shots[-1]
			check(a.direction==b.direction and a.position.distance_to(b.position)>.3,"Heavy pair fires simultaneously from distinct barrels")
		check(tanks.visual_origin(row).y<=.5 and absf(tanks.pivot(row).y-(tanks.visual_origin(row).y+config.pivot.y))<.001,"Hover clearance stays below half a metre and barrel follows hull "+row.kind)
		var before:float=row.yaw;pulse(game,game.clock+.1,false,Vector2(1,-1));check(row.yaw<before and row.speed>0,"Shared drive and hull turn "+row.kind)
		check(config.forward==10 if row.kind=="light" else config.forward<10 and config.turn<.65,"Mobility profile "+row.kind)
		tanks.leave(1,true);game.players[1].fire=false
	# Heavy crush kills and gibs an already incapacitated infantry target.
	var heavy:Dictionary=tanks.rows[6];heavy.pilot=1;heavy.life=game.players[1].serial;heavy.team=0;heavy.speed=4;heavy.velocity=Vector3(0,0,-4);heavy.yaw=0
	game.players[2].hp=100;game.players[2].armor=0;game.fighters[2].position=heavy.position+Vector3(0,0,-1);game.classes.incapacitate(2,1,"TEST",false,false,false)
	tanks.crush(6,heavy.position,heavy.position+Vector3(0,0,-1));check(game.players[2].dead and game.fighters[2].gibbed,"Heavy run-over immediately gibs incapacitated troops")
	tanks.leave(1,true);game._spawn(2);game.players[2].team=0;game.players[2].invulnerable=0;game.classes.states[1]["class"]="medic";game.fighters[1].position=Vector3(0,.03,0);game.fighters[2].position=Vector3(3,.03,0)
	game.classes.incapacitate(2,1,"TEST",false,false,false);check(Timers.eligible(game,1,2),"Medic sees allied revival pie within 100m")
	game.classes.states[1]["class"]="scout";check(not Timers.eligible(game,1,2),"Non-medics cannot see revival pie");game.classes.states[1]["class"]="medic";game.players[2].team=1;check(not Timers.eligible(game,1,2),"Enemy revival clock remains private");game.players[2].team=0
	game.classes.tick(2.0);check(is_equal_approx(game.classes.downed[2].remaining,8.0),"Revival pie follows authoritative remaining time")
	game.classes.downed.erase(2);check(not Timers.eligible(game,1,2),"Revived player loses timer")
	# Actual repair tool loop: near-hull contact at crouching hand height.
	game.classes.states[1]["class"]="technician";game.players[1].weapon=7;game.players[1].fire=true;game.players[1].last_input=game.clock;game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[1].update_height(1.05);game.fighters[1].position=heavy.position+Vector3(2.2,0,0);heavy.hp=400;heavy.team=0
	await physics_frame;game.tick_class_tools(1.0);check(heavy.hp==430,"Repair tool restores heavy vehicle at 30 HP/s through actual contact loop")
	# A ramp makes the flat drive collider bridge over the supporting centre.
	# The visible hull must follow the floor normal and retain its 25 cm clearance.
	var ramp:=StaticBody3D.new();ramp.collision_layer=1;ramp.position=Vector3(180,5,40);ramp.rotation.z=deg_to_rad(20);var ramp_shape:=CollisionShape3D.new();var ramp_box:=BoxShape3D.new();ramp_box.size=Vector3(30,.2,20);ramp_shape.shape=ramp_box;ramp.add_child(ramp_shape);game.get_node("Map").add_child(ramp)
	heavy.position=Vector3(180,8,40);heavy.pilot=0;heavy.speed=0;tanks.pose_body(6)
	for i in 90:
		game.clock+=.05;tanks.tick(.05);await physics_frame
	var floor_hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(heavy.position+Vector3.UP,heavy.position-Vector3.UP*6,1,[tanks.bodies[6].get_rid()]))
	check(tanks.bodies[6].is_on_floor() and not floor_hit.is_empty() and absf(tanks.visual_origin(heavy).y-floor_hit.position.y-.25)<.01 and heavy.normal.dot(floor_hit.normal)>.999,"Sloping support keeps hover hull at 25 cm and fits its floor normal")
	var snapshot:Dictionary=game.match_mode.snapshot();check(snapshot.has("ctk:7") and snapshot["ctk:6"].kind=="heavy","All vehicle profiles replicate in independent snapshot records")
	var replica:=Tanks.new();game.add_child(replica);replica.setup(game);replica.receive(tanks.rows,500);check(replica.rows[6].rounds==heavy.rounds and replica.rows[6].kind=="heavy" and replica.rows[6].reload_at==heavy.reload_at+500,"Client copies magazine and relative reload without aliasing");replica.reset();replica.free()
	for kind in ["light","heavy"]:
		var model:Node3D=load(Tanks.PROFILES[kind].model).instantiate();check(model.find_child("Yaw",true,false)!=null and model.find_child("Aim",true,false)!=null and model.find_child("Hull",true,false)!=null,"Model has separate yaw and barrel pitch pivots "+kind);model.free()
	print("CQ_HOVER_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
