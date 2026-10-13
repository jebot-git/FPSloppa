extends SceneTree
const Arena=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Arena:
	func _load_map(_map_id:String) -> bool:
		spawn_points=[Vector3(0,1,0),Vector3(8,1,0)];spawn_yaws=[0,PI];current_map="voxel_jungle"
		var ground:=StaticBody3D.new();ground.collision_layer=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,1,40);shape.shape=box;ground.add_child(shape);$Map.add_child(ground);return true
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var scene=load("res://tools/voxel_battle/class_arena.tscn").instantiate();scene.set_script(TestArena)
	root.add_child(scene);scene.set_process(false);scene.set_physics_process(false)
	scene.start_host("CQ integration",0,100,10,false,"tdm","ut99")
	check(scene.players.has(1),"CQ prototype can host")
	if not scene.players.has(1):quit(1);return
	scene._add_player(2,"Medic");scene._add_player(3,"Technician");scene._add_player(4,"Scout")
	for id in scene.players:scene.players[id].team=0;scene.players[id].invulnerable=0
	scene.classes.choose(2,"medic");scene._spawn(2);scene.classes.choose(3,"technician");scene._spawn(3);scene.classes.choose(4,"scout");scene._spawn(4)
	check(scene.players[3].weapon==5 and scene.players[3].ammo[2]==9,"Technician carries launcher plus two spare three-charge packs")
	check(scene.players[4].ammo[0]==42 and scene.players[4].owned==[9,8],"Scout has five spare pistol magazines and designator")
	check(scene.players[1].ammo[1]==120 and scene.players[1].ammo[0]==14,"Energy primary has three spare cells; secondary has one spare magazine")
	check(scene.jetpack_allowed_for(1) and not scene.jetpack_allowed_for(2) and not scene.jetpack_allowed_for(3) and not scene.jetpack_allowed_for(4),"Jetpack restricted to shocktroop")
	scene.players[1].hp=100;scene._damage(1,1,100,"LASER CARBINE")
	check(scene.classes.downed.has(1) and not scene.players[1].dead and scene.players[1].deaths==0,"Real lethal damage incapacitates without awarding a death")
	var remaining:float=scene.classes.downed[1].remaining;scene._damage(1,1,25,"DOBRYL P-1")
	check(not scene.players[1].dead and scene.classes.downed[1].remaining==remaining,"Ordinary follow-up damage preserves the bleed timer")
	scene._damage(1,1,1,"DOBRYL P-1",false,Vector3.INF,Vector3.ZERO,false,false,false,true)
	check(scene.players[1].dead and scene.players[1].deaths==1,"Headshot finisher causes immediate death")
	scene._spawn(1);scene.players[1].invulnerable=0;scene.players[1].hp=100
	scene._damage(1,1,100,"DOBRYL P-1",false,Vector3.INF,Vector3.ZERO,false,false,false,true)
	check(scene.players[1].dead and not scene.classes.downed.has(1),"Lethal headshot never enters revive state")
	scene._spawn(1);scene.players[1].invulnerable=0;scene.players[1].hp=100;scene._damage(1,1,130,"MASSACRE GUN")
	check(scene.players[1].dead and scene.fighters[1].gibbed,"Overkill retains gibbing and immediate death")
	check(scene.classes.deploy(2,Vector3.ZERO),"Medic deploys health box")
	scene.players[4].hp=1
	var box:int=scene.classes.dispensers.keys()[0]
	check(scene.classes.transfer(box,4,1000)==99 and scene.classes.dispensers[box].remaining==901,"Health box budget counts actual restored health")
	check(scene.classes.transfer(box,4,1000)==0 and scene.classes.dispensers[box].remaining==901,"Full-health ally cannot drain box or farm XP")
	check(scene.classes.deploy(3,Vector3.ZERO),"Technician deploys ammo box")
	var ammo_box:int=scene.classes.dispensers.keys()[1];scene.players[4].ammo=[0,0,0,0]
	check(scene.classes.transfer(ammo_box,4,1000)==42 and scene.classes.dispensers[ammo_box].remaining==958,"Ammo box refills class pouch capacity and counts rounds")
	var mags=scene.variant_combat.magazines
	var s:Dictionary=scene.players[3];s.last_input=scene.clock;s.input_blocked=false;s.cooldown=0
	check(mags.tick(3) and mags.loaded(3)==3,"Launcher starts with three loaded charges")
	s.ammo[2]-=3;mags.consume(3,3)
	check(mags.loaded(3)==0 and not mags.tick(3),"Launcher spends full pack and blocks fire during reload")
	scene.clock+=2.71;s.last_input=scene.clock
	check(mags.tick(3) and mags.loaded(3)==3 and s.ammo[2]==6,"One reload seats all three charges without creating ammunition")
	var Beam=preload("res://deathmatch/conquest/classes/beam.gd")
	var clipped:=Beam.clipped(Vector3(-10,0,0),Vector3(10,0,0),Vector3.ZERO)
	check(clipped.size()==2 and clipped[0].is_equal_approx(Vector3(-3,0,0)) and clipped[1].is_equal_approx(Vector3(3,0,0)),"Enemy designation beam limited to three metres")
	check(Beam.clipped(Vector3(-10,4,0),Vector3(10,4,0),Vector3.ZERO).is_empty(),"Distant enemy beam invisible")
	check(scene.max_clients==32,"CQ host admits the district target of 32 players")
	scene.players[3].team=1;s.fire=true;s.cooldown=0;s.last_input=scene.clock;scene.fighters[3].position=Vector3(8,3,0)
	var before:int=scene.projectiles.size();scene.variant_combat.tick_input(3,.016)
	s.fire=false
	for n in 2:scene.clock+=.151;s.last_input=scene.clock;scene.variant_combat.tick_input(3,.151)
	check(scene.projectiles.size()==before+3 and s.ammo[2]==3 and mags.loaded(3)==0,"One launcher trigger emits three ordered blasts and spends one pack")
	var blue:Dictionary=scene.variant_combat.definition(3,5,{"cq_team":1})
	check(blue.cq_effect=="ordnance" and blue.color.is_equal_approx(Color("3b8dff")),"Launcher blast and energy impact retain blue firing team")
	scene._spawn(1);scene.players[1].team=0;scene.players[1].weapon=4;scene.players[1].fire=true;scene.players[1].last_input=scene.clock;scene.players[1].cooldown=0;scene.fighters[1].position=Vector3(0,3,0)
	before=scene.projectiles.size();scene.variant_combat.tick_input(1,.016)
	check(scene.projectiles.size()==before+1,"Carbine fires a travelling blaster bolt rather than a hitscan beam")
	var red:Dictionary=scene.variant_combat.definition(1,4,{"cq_team":0})
	check(red.cq_effect=="energy" and red.color.is_equal_approx(Color("ff3c39")),"Carbine bolt and impact retain red firing team")
	var vehicle=preload("res://deathmatch/conquest/classes/vehicle_health.gd").new();scene.add_child(vehicle);vehicle.team=0;vehicle.hp=500
	check(vehicle.repair(1,100)==0 and vehicle.repair(0,100)==100 and vehicle.hp==600,"Repair kit vehicle component accepts only actual allied repair")
	var hull:=StaticBody3D.new();hull.collision_layer=1;scene.add_child(hull);hull.position=scene.fighters[3].position+Vector3(0,1,-1)
	var hull_shape:=CollisionShape3D.new();var hull_box:=BoxShape3D.new();hull_box.size=Vector3.ONE*.7;hull_shape.shape=hull_box;hull.add_child(hull_shape)
	vehicle.reparent(hull);vehicle.position=Vector3.ZERO;scene.players[3].team=0;scene.players[3].weapon=7;scene.players[3].fire=true;scene.players[3].last_input=scene.clock
	await physics_frame
	scene.tick_class_tools(.1)
	check(vehicle.hp==603,"Held repair tool repairs the allied hull through its own collision surface")
	for id in range(5,33):
		scene._add_player(id,"CQ snapshot %d"%id);scene.classes.choose(id,scene.classes.CLASSES[id%4]);scene._spawn(id);scene.variant_combat.magazines.state(id);scene.classes.award(id,id*37)
	var rows:Array=[]
	for id in scene.players:
		var player:Dictionary=scene.players[id];var fighter=scene.fighters[id]
		rows.append([id,fighter.position,fighter.velocity,player.yaw,player.pitch,player.hp,player.armor,player.dead,player.weapon,player.ammo,player.owned,player.kills,player.deaths,player.ping,player.serial,0.0,false,player.cooldown,player.xr,player.offhand_cooldown,player.spectator,fighter.blast_velocity])
	var wire:Array=[rows,PackedByteArray(),100.0,0.0,"",100,10,[],[],scene.map_epoch,scene.match_mode.snapshot(),{},scene.clock,scene.projectile_id]
	var replication=preload("res://deathmatch/network/replication.gd").new();var packets:Dictionary=replication.packets(wire)
	print("CQ_32_SNAPSHOT ",JSON.stringify(replication.stats))
	check(packets.large.is_empty() and replication.stats.max_packet<=1100,"32 class players fit independent UDP snapshot packets")
	for id in scene.players:
		scene.classes.dispensers[id]={"owner":id,"team":id%2,"kind":"ammo" if id%2 else "health","position":Vector3(id*1.7,0,id*.9),"remaining":1000-id,"credit":.2,"xp_credit":.3}
		scene.classes.downed[id]={"remaining":8.1+id*.01,"attacker":1,"weapon":"LASER CARBINE"}
		scene.grenades.flying[id]={"kind":0,"owner":id,"position":Vector3(id*1.9,1,id*.8),"velocity":Vector3(id*.3,2,-10),"age":.1,"ground":false}
	wire[10]=scene.match_mode.snapshot();wire[12]+=.05
	packets=replication.packets(wire)
	print("CQ_32_STRESS_SNAPSHOT ",JSON.stringify(replication.stats))
	var only_membership:=true
	var Codec=preload("res://deathmatch/network/snapshot_codec.gd")
	for packet in packets.large:
		var message:Array=Codec.unpack(packet)
		for record in message[3]:
			if Codec.decode(record)[0]!=4:only_membership=false
	for packet in packets.normal:
		if packet.size()>1100:only_membership=false
	check(only_membership and packets.large.size()<=1,"32 ability records remain UDP sized; membership alone uses reliable fallback")
	var Reload=preload("res://deathmatch/conquest/classes/reload_state.gd")
	check(Reload.mag_direction(mags.geometry(5))==Vector3.LEFT and mags.geometry(4)==7,"Launcher reload enters from the side; carbine retains its magazine geometry")
	var pack:Dictionary=Reload.make(3);pack.weapon=12;Reload.eject_mag(pack)
	check(not pack.ready,"Removing an ordnance pack cannot retain a chambered launcher charge")
	var Scope=preload("res://deathmatch/vr/sniper_scope.gd")
	var optic=Scope.new();optic.step_zoom(.8);optic.step_zoom(.8)
	check(optic.zoom_index==1,"Scout zoom steps to 3x once per stick deflection")
	optic.step_zoom(0);optic.step_zoom(.8);optic.step_zoom(0);optic.step_zoom(-.8)
	check(optic.zoom_index==1 and Scope.zoom_fov(85,6)<Scope.zoom_fov(85,3),"Scout zoom selects 1.5x, 3x and 6x with neutral rearming")
	optic.free()
	print("CQ_CLASS_INTEGRATION_RESULT ",JSON.stringify(failures));scene.disconnect_game();scene.free();quit(0 if failures.is_empty() else 1)
