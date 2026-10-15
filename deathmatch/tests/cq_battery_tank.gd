extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
class TestArena extends Base:
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(10,.05,0)];spawn_yaws=[0];current_map="voxel_jungle";map_sha=map_identity()
		var ground:=StaticBody3D.new();ground.collision_layer=1;ground.position.y=-.5;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2000,1,2000);shape.shape=box;ground.add_child(shape);get_node("Map").add_child(ground);return true
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func step(game,count:int,fire:bool=false,move:=Vector2.ZERO) -> void:
	for i in count:
		game.clock+=.05;game.players[1].last_input=game.clock;game.players[1].fire=fire;game.players[1].move=move;game.battery_tanks.tick(.05);await physics_frame
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Battery",28803,100,10,false)
	var tanks=game.battery_tanks;tanks.configure()
	check(tanks.rows.size()==12 and tanks.rows[0].poi=="west ridge relay" and tanks.rows[1].poi=="canyon crossing","Two batteries, six hover tanks and four transports available")
	for key in tanks.rows:tanks.rows[key].position=Vector3(key*50,.03,0);tanks.rows[key].yaw=0;tanks.rows[key].visual_y=.03+(0 if key<2 else .25);tanks.pose_body(key)
	game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].invulnerable=0;game.fighters[1].position=Vector3(3.5,.03,0)
	await physics_frame;await physics_frame
	check(tanks.use(1) and tanks.mounted(1) and game.fighters[1].collision_layer==0,"Use boards nearby empty hull and disables player collider")
	game._add_player(2,"Enemy");game.players[2].team=1;game.players[2].invulnerable=0;game.players[2].input_blocked=false;game.fighters[2].position=Vector3(3.5,.03,0)
	check(not tanks.use(2),"Occupied tank cannot be boarded by another player")
	var hp:int=game.players[1].hp;game._damage(1,2,1000,"INFANTRY",false);check(game.players[1].hp==hp,"Seated crew cannot be damaged as exposed infantry")
	check(tanks.damage(0,1,100,"infantry")==0 and tanks.rows[0].hp==100,"Infantry weapons cannot damage hull")
	check(tanks.damage(0,1,80,"grenade")==40 and tanks.rows[0].hp==60,"Grenade damage is halved")
	check(tanks.damage(0,0,10,"ordnance")==10,"Allied ordnance damages hull");tanks.rows[0].hp=60
	check(tanks.bodies[0].repair(0,20)==20 and tanks.rows[0].hp==80,"Existing technician repair service restores living allied hull")
	var contact:Dictionary=game._trace(Vector3(10,1,0),Vector3(-10,1,0),2)
	game._damage_map_hit(contact,2,1000);check(contact.get("cq_vehicle")==tanks.bodies[0] and tanks.rows[0].hp==80,"Actual infantry collision trace hits hull without damaging it")
	var energy:int=game.variant_combat.launch(2,1,Vector3(10,1,0),Vector3.LEFT)
	game.variant_combat.active_projectile=energy;game._damage_map_hit(contact,2,1000);game.variant_combat.active_projectile=-1
	check(tanks.rows[0].hp==80,"Projectile energy infantry weapon cannot damage hull")
	game._projectile_end(energy,Vector3(10,1,0),1)
	game.battery_tanks.blast(tanks.bodies[0].global_position,1,40,10,"grenade");check(tanks.rows[0].hp==60,"Actual grenade blast applies half damage at hull center")
	tanks.bodies[0].repair(0,20)

	game.players[1].pitch=.45;game.players[1].yaw=.3
	await step(game,25,true)
	check(game.projectiles.size()==8 and tanks.rows[0].left==0 and tanks.rows[0].reload_at-game.clock>29,"Held trigger launches eight shots and starts thirty-second reload after final shot")
	var p:Dictionary=game.projectiles.values()[0]
	check(p.definition.gravity==20 and is_equal_approx(p.definition.speed,sqrt(5000.0*20)) and p.definition.arm==0 and p.definition.bounce==0 and p.definition.blast_radius==30 and not p.definition.guided,"Barrage uses impact detonation, 30m blast and unguided ballistic flight")
	var impacts:Array=[]
	for projectile in game.projectiles.values():
		var extra:Dictionary=projectile.extra;var landing:Vector3=projectile.position+projectile.velocity*extra.barrage_time-Vector3.UP*10*extra.barrage_time*extra.barrage_time
		check(landing.distance_to(extra.barrage_target)<.02 and extra.barrage_target.distance_to(extra.barrage_center)<=Tanks.BARRAGE_RADIUS+.01,"Actual rocket velocity lands inside bounded barrage footprint")
		impacts.append(extra.barrage_target)
	check(impacts[0].distance_to(impacts[4])>5,"Barrage distributes rockets across the area instead of a single aim line")
	var ready:float=tanks.rows[0].reload_at
	await step(game,5,true);check(game.projectiles.size()==8,"Reload blocks repeated salvos")
	game.clock=ready;game.players[1].last_input=game.clock;tanks.tick(.05);check(game.projectiles.size()==9,"Unlimited ammunition allows another salvo at reload deadline")
	tanks.rows[0].left=0;tanks.rows[0].reload_at=game.clock+100;game.players[1].fire=false
	var before:Vector3=tanks.rows[0].position;await step(game,150,false,Vector2(0,-1));check(tanks.rows[0].position.z<before.z-10 and tanks.rows[0].speed<=10,"Motion joystick accelerates medium-speed hull forward")
	var yaw:float=tanks.rows[0].yaw;await step(game,5,false,Vector2(1,0));check(tanks.rows[0].yaw<yaw,"Horizontal motion joystick turns hull")
	var pose:Dictionary={"weapon":Transform3D(Basis(Vector3.UP,.8)*Basis(Vector3.RIGHT,.4),Vector3(.2,1.2,-.3)),"head":Transform3D(Basis.IDENTITY,Vector3(0,1.7,0)),"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"left_handed":false}
	game.players[1].xr=pose;game.players[1].yaw=0;game.players[1].vr_device=true;await step(game,1)
	check(tanks.rows[0].direction.distance_to(-pose.weapon.basis.z)<.001,"Tracked weapon hand steers turret separately from motion joystick")
	game.players[1].last_input=game.clock-1;game.players[1].fire=true;game.players[1].move=Vector2(0,-1);tanks.rows[0].speed=0;tanks.tick(.05);check(tanks.rows[0].speed==0 and tanks.rows[0].left==0,"Stale input cannot drive or start a salvo")
	game.players[1].xr={};game.players[1].vr_device=false;game.players[1].fire=false;game.players[1].last_input=game.clock
	game.classes.choose(1,"technician");game.classes.states[1]["class"]="technician";game.classes.states[2]["class"]="scout"
	game.designations[2]={"team":0,"position":tanks.rows[0].position+Vector3(0,0,-100),"until":game.clock+1}
	game.players[1].move=Vector2.ZERO;tanks.rows[0].speed=0;tanks.rows[0].velocity=Vector3.ZERO
	var help:Dictionary=tanks.helper(1);check(not help.is_empty() and (help.origin+help.velocity*help.time-Vector3.UP*10*help.time*help.time).distance_to(game.designations[2].position)<.01,"Technician sees physically accurate scout-designated mortar solution")
	# Align with the laser aid, then fire: designation never removes the spread.
	game.players[1].yaw=atan2(-help.direction.x,-help.direction.z);game.players[1].pitch=asin(help.direction.y)
	tanks.rows[0].direction=help.direction;tanks.rows[0].reload_at=0;tanks.rows[0].next=0;tanks.rows[0].velocity=Vector3.ZERO
	game.projectiles.clear();await step(game,1,true)
	var locked_center:Vector3=game.projectiles.values()[0].extra.barrage_center
	game.players[1].yaw+=.7 # Hand motion cannot drag an active salvo off its footprint.
	await step(game,31,true)
	var marker:Vector3=game.designations[2].position
	check(game.projectiles.size()==8 and game.projectiles.values().all(func(projectile):return projectile.extra.barrage_center.distance_to(locked_center)<.001 and projectile.extra.barrage_target.distance_to(locked_center)<Tanks.BARRAGE_RADIUS+.01),"Laser-assisted barrage stays within locked footprint even while turning aim")
	check(game.projectiles.values().any(func(projectile):return projectile.extra.barrage_target.distance_to(marker)>3),"Laser designation cannot produce eight pinpoint impacts")
	game.players[1].fire=false
	game.classes.states[1]["class"]="medic";check(tanks.helper(1).is_empty(),"Other classes do not receive technician targeting aid")
	game.classes.states[1]["class"]="technician";game.designations[2].team=1;check(tanks.helper(1).is_empty(),"Enemy scout designations do not provide targeting aid")
	var snapshot:Dictionary=game.match_mode.snapshot();check(snapshot.has("ctk:0") and snapshot.has("ctk:1"),"Both tank hulls and occupants have independent snapshot records")
	var replica:=Tanks.new();game.add_child(replica);replica.setup(game);replica.receive(tanks.rows,500);check(replica.rows[0].reload_at==tanks.rows[0].reload_at+500 and replica.rows[0].pilot==1,"Client clock offset preserves reload and occupant state");replica.reset();replica.free();tanks.seat(1,0)
	game.players[1].last_input=game.clock;check(tanks.use(1) and not tanks.mounted(1) and game.fighters[1].collision_layer==2 and game.fighters[1].position.distance_to(tanks.rows[0].position)>3,"Use safely dismounts outside hull and restores collider")
	game.players[2].hp=100;game.players[2].armor=0;game.fighters[2].position=tanks.rows[0].position+Vector3(0,0,-1);tanks.rows[0].pilot=1;tanks.rows[0].life=game.players[1].serial;tanks.rows[0].speed=4;tanks.rows[0].yaw=0;tanks.rows[0].velocity=Vector3(0,0,-4)
	tanks.crush(0,tanks.rows[0].position,tanks.rows[0].position+Vector3(0,0,-1));check(game.classes.downed.has(2) and not game.players[2].dead,"Running over ground troops incapacitates without gibbing")
	var roof_hit:Dictionary=game._trace(tanks.rows[0].position+Vector3(10,2.7,0),tanks.rows[0].position+Vector3(-10,2.7,0),2)
	check(roof_hit.get("cq_vehicle")==tanks.bodies[0],"Upper battery is part of the vehicle damage collider")
	var rocket:int=game.variant_combat.launch(2,11,tanks.rows[0].position+Vector3(10,2.7,0),Vector3.LEFT)
	game.variant_combat.active_projectile=rocket;game._damage_map_hit(roof_hit,2,80);game.variant_combat.active_projectile=-1
	check(tanks.rows[0].hp==0 and not tanks.mounted(1) and tanks.bodies[0].collision_layer==0,"Actual ordnance contact does full damage and releases crew")
	check(not tanks.use(1),"Destroyed battery cannot be boarded")
	var model:Node3D=load("res://deathmatch/models/battery_tank/battery_tank.glb").instantiate();check(model.find_child("Aim",true,false)!=null and model.find_child("Hull",true,false)!=null,"Combined optimized model has independent battery pivot");model.free()
	var layout=preload("res://tools/voxel_battle/architecture.gd").new();layout.generate()
	for placement in Tanks.placements():
		var bounds:=AABB(placement.position-Vector3(Tanks.PROFILES[placement.kind].size.x*.5,0,Tanks.PROFILES[placement.kind].size.z*.5),Tanks.PROFILES[placement.kind].size)
		var clear:=true
		for box in layout.boxes:
			var point:Vector3=Tanks.Landscape.CENTERS[box.kind]+box.center
			if bounds.intersects(AABB(point-box.size*.5,box.size)):clear=false
		check(clear,placement.poi+" spawn clears buildings, fixtures and primary road")
		var level:=true
		for x in [-2.3,2.3]:
			for z in [-2.4,2.4]:
				var point:Vector3=placement.position+Vector3(x,0,z)
				if absf(Tanks.Landscape.surface(point.x,point.z).x-placement.position.y)>.2:level=false
		check(level,placement.poi+" footprint lies on level authored terrain")
	game.match_mode.reset();check(tanks.rows.size()==12 and tanks.rows.values().all(func(row):return row.hp==tanks.profile(row).hp and row.pilot==0 and row.left==0),"Round reset restores all twelve empty vehicles")
	print("CQ_BATTERY_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
