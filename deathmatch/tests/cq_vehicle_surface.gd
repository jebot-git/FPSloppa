extends SceneTree
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Vehicle surfaces",28810,100,10,false)
	var tanks=game.battery_tanks;tanks.configure();game._add_player(2,"Attacker");game.players[1].team=0;game.players[2].team=1
	var road:Vector3=Landscape.CENTERS[3];road.y=Landscape.surface(road.x,road.z).x+.03
	var dirt:Vector3=Landscape.CENTERS[3]+Vector3(62,0,-45);dirt.y=Landscape.surface(dirt.x,dirt.z).x+.03
	check(Landscape.is_road(road.x,road.z) and not Landscape.is_road(dirt.x,dirt.z),"Terrain road classification agrees with painted main roads and excludes offroad pad")
	check(Tanks.mobility_at(road)==1.25 and Tanks.mobility_at(dirt)==1.0 and Tanks.mobility_at(road+Vector3.UP*5)==1.0,"Road gets 25 percent mobility; offroad and elevated floor retain defaults")
	var access:Dictionary=Landscape.access_roads[0];var access_point:Vector3=access.a.lerp(access.b,.5);access_point.y=Landscape.surface(access_point.x,access_point.z).x+.03
	check(Landscape.is_road(access_point.x,access_point.z) and Tanks.mobility_at(access_point)==1.25,"Painted building access lane also receives road bonus")
	# Place collidable support at the real terrain road height.
	var floor:=StaticBody3D.new();floor.collision_layer=1;floor.position=road-Vector3.UP*.53;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,1,100);shape.shape=box;floor.add_child(shape);game.get_node("Map").add_child(floor)
	await physics_frame
	for key in [0,2,6]:
		var row:Dictionary=tanks.rows[key];var config:Dictionary=tanks.profile(row)
		row.position=road;row.yaw=0;row.visual_y=road.y;row.pilot=1;row.life=game.players[1].serial;row.team=0;row.speed=0;tanks.pose_body(key)
		game.players[1].dead=false;game.players[1].hp=100;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].move=Vector2(1,-1);game.players[1].fire=false
		var yaw:float=row.yaw;tanks.tick(.1)
		check(is_equal_approx(row.speed,config.acceleration*.1*1.25) and is_equal_approx(yaw-row.yaw,config.turn*.1*1.25),"Road accelerates and turns "+row.kind+" 25 percent faster")
		row.position=road;row.yaw=0;row.speed=config.forward*1.25;tanks.pose_body(key);game.players[1].move=Vector2(0,-1);tanks.tick(.1)
		check(is_equal_approx(row.speed,config.forward*1.25),"Road forward top speed "+row.kind)
		row.position=road;row.speed=-config.reverse*1.25;tanks.pose_body(key);game.players[1].move=Vector2(0,1);tanks.tick(.1);check(is_equal_approx(row.speed,-config.reverse*1.25),"Road reverse top speed "+row.kind)
		row.position=dirt;row.speed=0;row.yaw=0;tanks.pose_body(key);game.players[1].move=Vector2(1,-1);tanks.tick(.1)
		check(is_equal_approx(row.speed,config.acceleration*.1) and is_equal_approx(-row.yaw,config.turn*.1),"Offroad preserves original mobility "+row.kind)
		tanks.leave(1,true)
		# Combat hull destruction kills a fully armored, spawn-protected crew member.
		row.position=dirt;row.pilot=1;row.life=game.players[1].serial;row.team=0;row.hp=config.hp;tanks.pose_body(key);tanks.seat(1,key);game.players[1].hp=100;game.players[1].armor=200;game.players[1].invulnerable=game.clock+100
		var frags:int=game.players[2].kills
		tanks.damage(key,1,config.hp,"ordnance",2)
		check(row.hp==0 and row.pilot==0 and game.players[1].dead and game.fighters[1].gibbed and not game.classes.downed.has(1),"Destroyed "+row.kind+" instantly gibs crew despite armor/protection")
		check(game.players[2].kills==frags+1 and not game.fighters[1].vehicle_seated and game.fighters[1].collision_layer==2,"Destruction credits attacker and restores crew state "+row.kind)
		game._spawn(1)
	# Real authored river water: grounded collision bed permits physical driving.
	tanks.configure();var wet:=Vector3(-553,0,-650);wet.y=Landscape.surface(wet.x,wet.z).x+.03
	check(Landscape.in_water(wet),"Chosen test point is actual river killzone")
	var bed:=StaticBody3D.new();bed.collision_layer=1;bed.position=wet-Vector3.UP*.53;var bed_shape:=CollisionShape3D.new();var bed_box:=BoxShape3D.new();bed_box.size=Vector3(40,1,40);bed_shape.shape=bed_box;bed.add_child(bed_shape);game.get_node("Map").add_child(bed)
	await physics_frame
	for key in [0,2,6]:
		var row:Dictionary=tanks.rows[key];row.position=wet;row.pilot=1;row.life=game.players[1].serial;row.team=0;row.speed=4;row.yaw=0;tanks.pose_body(key);tanks.seat(1,key)
		game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].move=Vector2(0,-1);game.players[1].fire=true;game.players[1].invulnerable=game.clock+100
		var shots:int=game.projectiles.size();tanks.tick(.05)
		check(row.hp==0 and game.players[1].dead and game.fighters[1].gibbed and row.pilot==0 and row.speed==0 and row.left==0 and game.projectiles.size()==shots,"Water destroys "+row.kind+", gibs crew and cancels firing/movement")
		game._spawn(1)
	var empty:Dictionary=tanks.rows[3];empty.position=wet;tanks.pose_body(3);tanks.tick(.05);check(empty.hp==0 and tanks.bodies[3].collision_layer==0,"Unoccupied vehicle in water also becomes disabled wreck")
	# Drive across a real river-bank boundary on a collidable bed, not a teleport kill.
	tanks.configure();var crossing:Dictionary=tanks.rows[2];crossing.position=wet+Vector3(20,0,0);crossing.yaw=PI*.5;crossing.speed=10;crossing.pilot=1;crossing.life=game.players[1].serial;crossing.team=0;tanks.pose_body(2);tanks.seat(1,2)
	game.players[1].input_blocked=false;game.players[1].fire=false;game.players[1].move=Vector2(0,-1);var start:Vector3=crossing.position
	for i in 80:
		if crossing.hp==0:break
		game.clock+=.05;game.players[1].last_input=game.clock;tanks.tick(.05);await physics_frame
	check(crossing.position.x<start.x-3 and crossing.hp==0 and game.players[1].dead and game.fighters[1].gibbed,"Physical shoreline crossing moves into water and destroys occupied hull")
	var above:Dictionary=tanks.rows[4];above.position=wet+Vector3.UP*12;tanks.pose_body(4);check(not Tanks.water_contact(above),"Bridge or floor above water doesn't count as submerged")
	print("CQ_VEHICLE_SURFACE_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
