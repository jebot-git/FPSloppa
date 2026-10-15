extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const NVG=preload("res://deathmatch/conquest/classes/night_vision.gd")
const SkySource=preload("res://tools/voxel_battle/jungle_sky.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
var failures:Array=[]
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,title:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",title)
	if not ok:failures.append(title)
func skytime(seconds:float)->float:
	var p:=seconds/1200.
	return (p*.275/.31 if p<.31 else .275+(p-.31)*.45/.375 if p<.685 else .725+(p-.685)*.275/.315)*1200.
func run()->void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var map=game.BattleMap.new();game.add_child(map);game.battle_map=map;map.lighting=Lighting.new();map.add_child(map.lighting)
	game.spawn_points=[Vector3(0,1,0)];game.spawn_yaws=[0];game.start_host("NVG",0,100,10,false)
	game._add_player(2,"Scout");game.classes.choose(2,"scout");game._spawn(2)
	var lighting=map.lighting;var service=game.night_vision
	for p in [.0,.24,.29,.33,.50,.67,.71,.76,.9]:
		var pair:=SkySource.stage_pair(p*1200,1200);print("STAGE ",p," ",SkySource.STAGES[int(pair.x)]," -> ",SkySource.STAGES[int(pair.y)]," ",pair.z)
	check(SkySource.stage_pair(skytime(330),1200).y==2 and SkySource.stage_pair(skytime(375),1200).y==3 and SkySource.stage_pair(skytime(795),1200).y==5 and SkySource.stage_pair(skytime(830),1200).y==6,"Dusk and dawn pass through their distinct stages")
	var previous:=1.0;var dusk_ok:=true
	for seconds in range(324,421):
		var fraction:=Lighting.day_weight(skytime(seconds));dusk_ok=dusk_ok and fraction<=previous;previous=fraction
	var dawn_ok:=true;previous=0
	for seconds in range(780,865):
		var fraction:=Lighting.day_weight(skytime(seconds));dawn_ok=dawn_ok and fraction>=previous;previous=fraction
	check(dusk_ok and dawn_ok and is_equal_approx(Lighting.day_weight(330),.5) and is_equal_approx(Lighting.day_weight(870),.5),"Spotting light fraction falls through dusk and rises through dawn smoothly")
	lighting.phase_override=1;check(game.spotting.range_for(game,1)==75 and game.spotting.range_for(game,2)==150,"Day limits 75/150m")
	lighting.phase_override=0;check(game.spotting.range_for(game,1)==15 and game.spotting.range_for(game,2)==25,"Night limits 15/25m")
	check(service.toggle(1,game.players[1].serial,game.map_epoch,1,{}),"Desktop wearer activates visor")
	game.classes.states[2]["nv"]=true
	check(game.spotting.range_for(game,1)==50 and game.spotting.range_for(game,2)==100,"NVG night limits 50/100m")
	lighting.phase_override=.5;check(game.spotting.range_for(game,1)==62.5 and game.spotting.range_for(game,2)==125,"NVG ranges interpolate through dusk and dawn")
	check(not service.toggle(1,game.players[1].serial,game.map_epoch,2,{}),"Switch debounce")
	game.clock+=.4;check(not service.toggle(1,game.players[1].serial,game.map_epoch,1,{}),"Replay rejected")
	check(not service.toggle(1,game.players[1].serial-1,game.map_epoch,3,{}) and not service.toggle(1,game.players[1].serial,game.map_epoch-1,3,{}),"Stale life and map rejected")
	var pose:=Base.VRPoses.neutral();pose.left.origin=pose.head.origin+Vector3(0,.20,-.1)
	game.players[1].xr=pose;game.players[1].vr_device=true;game.players[1].last_input=game.clock
	check(NVG.above_forehead(pose) and service.toggle(1,game.players[1].serial,game.map_epoch,4,pose),"Offhand trigger gesture above forehead toggles VR visor")
	game.clock+=.4;game.players[1].last_input=game.clock
	var invalid:=pose.duplicate();invalid.left=Transform3D(Basis.IDENTITY,pose.head.origin+Vector3(0,-.4,-.1))
	check(not NVG.above_forehead(invalid) and not service.toggle(1,game.players[1].serial,game.map_epoch,5,invalid),"Hand below forehead rejected")
	pose.left_handed=true;pose.right.origin=pose.head.origin+Vector3(0,.2,-.1);pose.weapon=pose.left;game.players[1].xr=pose
	check(service.toggle(1,game.players[1].serial,game.map_epoch,6,pose),"Left handed offhand gesture accepted")
	var rotated:=pose.duplicate(true);var rotation:=Basis(Vector3.FORWARD,.5)*Basis(Vector3.UP,1.2)
	rotated.head.basis=rotation;rotated.right.origin=rotated.head.origin+rotation*Vector3(0,.2,-.1)
	check(NVG.above_forehead(rotated),"Forehead region follows head rotation")
	game.clock+=.4;game.players[1].last_input=game.clock-.36
	check(not service.toggle(1,game.players[1].serial,game.map_epoch,7,pose),"Stale XR pose rejected")
	game.players[1].xr={};game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[1].position=Vector3.ZERO
	var eye:Vector3=service.eye(1).origin;var source:=eye+Vector3(0,0,-8)
	game.headless=false
	if game.camera:game.camera.global_transform=service.eye(1)
	service.flash(eye+Vector3(0,0,8),18,1);check(service.blind_for(1)==0 and service.flash_samples(service.eye(1)).is_empty(),"Flash behind observer does not blind or paint the view")
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=eye+Vector3(0,0,-4)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10,10,1);shape.shape=box;wall.add_child(shape);game.add_child(wall)
	await physics_frame;await physics_frame;service.flash(source,18,1);check(service.blind_for(1)==0 and service.flash_samples(service.eye(1)).is_empty(),"Solid cover blocks NVG flash spots")
	wall.free();await physics_frame;await physics_frame
	service.flash(source,18,.65);check(service.blind_for(1)==0 and game.spotting.range_for(game,1)>0 and service.flash_samples(service.eye(1)).size()==1,"Visible muzzle flash creates a local spot without global blindness")
	game.clock+=1;check(service.flash_samples(service.eye(1),Time.get_ticks_msec()/1000.+1).is_empty(),"Transient spots expire without a spotting penalty")
	map.lighting.metadata={"lamps":[{"position":[source.x,source.y,source.z]}]};lighting.synchronize(600);lighting.phase_override=-1;service.indexed_map=null;service.tick()
	check(service.blind_for(1)>.1,"Looking at baked fixture blinds without dynamic lights")
	var direct:Transform3D=service.eye(1)
	check(service.static_glare(direct)>.99,"Direct visible lamp gives full local whiteout")
	var turned:=Transform3D(Basis(Vector3.UP,.12),direct.origin)
	check(service.static_glare(turned)==0,"Turning away clears local whiteout immediately, without waiting for a timer")
	game.players[1].yaw=.12;game.clock+=.15;service.tick();check(service.blind_for(1)==0,"Peripheral fixture does not blind authoritative spotting")
	game.players[1].yaw=PI;game.clock+=1;service.tick();check(service.blind_for(1)==0,"Looking away clears authoritative fixture glare")
	game.headless=true
	game._spawn(1);check(not service.enabled_for(1) and service.blind_for(1)==0,"Respawn resets visor and glare")
	game.battle_map=null;map.queue_free();game.disconnect_game();game.queue_free();await process_frame;await process_frame;print("CQ_NVG_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
