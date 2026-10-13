extends SceneTree
const Arena=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Arena:
	func _load_map(_map_id:String) -> bool:
		spawn_points=[Vector3(0,3,0)];spawn_yaws=[0.0];current_map="voxel_jungle";return true
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var scene=load("res://tools/voxel_battle/class_arena.tscn").instantiate();scene.set_script(TestArena);root.add_child(scene);scene.set_process(false);scene.set_physics_process(false)
	scene.start_host("CQ progression",28781,100,10,false,"tdm","ut99")
	if not scene.active:scene.free();quit(1);return
	var ids={"shocktroop":1,"scout":2,"medic":3,"technician":4}
	for role in ids:
		var id:int=ids[role]
		if id!=1:scene._add_player(id,role)
		scene.classes.choose(id,role);scene._spawn(id)
		var primary:int=scene.classes.progression.SECOND_PRIMARY[role]
		check(not scene.classes.choose_equipment(id,role,primary,false),role+" primary locked below 1000 XP")
		scene.classes.award(id,999);check(not scene.classes.choose_equipment(id,role,primary,false),role+" rejects 999 XP")
		scene.classes.award(id,1);check(scene.classes.choose_equipment(id,role,primary,false),role+" unlocks at 1000 XP")
		check(scene.players[id].weapon!=primary,role+" choice waits for respawn")
		scene._spawn(id);check(scene.players[id].weapon==primary,role+" selected primary equipped on respawn")
		check(not scene.classes.choose_equipment(id,role,0,true),role+" burst pistol locked at 1000 XP")
		scene.classes.award(id,500);check(scene.classes.choose_equipment(id,role,0,true),role+" burst pistol unlocks at 1500 XP")
		scene._spawn(id);check(scene.players[id].owned[1]==0 and scene.players[id].ammo[3]==36,role+" burst pistol has loaded cell plus one spare")
	check(scene.players[1].ammo[1]==144 and scene.players[2].ammo[1]==40 and scene.players[3].ammo[1]==160 and scene.players[4].ammo[2]==9,"Selected primary capacities: 3 spare magazines/cells, 2 ordnance packs")
	check(not scene.classes.choose_equipment(3,"medic",11,false) and not scene.classes.choose_equipment(99,"scout",10,false),"Authority rejects another class's weapon and unknown player")
	var s:Dictionary=scene.players[3];s.weapon=0;s.fire=true;s.last_input=scene.clock;s.cooldown=0;s.input_blocked=false
	var before:int=scene.projectiles.size();scene.variant_combat.tick_input(3,.016)
	for i in 2:scene.clock+=.066;s.last_input=scene.clock;scene.variant_combat.tick_input(3,.066)
	check(scene.projectiles.size()==before+3 and s.ammo[3]==33 and scene.variant_combat.magazines.loaded(3)==15,"One burst emits exactly 3 energy bolts and spends 3 charges")
	scene.clock+=1;s.last_input=scene.clock;s.cooldown=0;scene.variant_combat.tick_input(3,.016)
	check(scene.projectiles.size()==before+3,"Held trigger cannot repeat a burst")
	s.fire=false;scene.variant_combat.tick_input(3,.016);s.fire=true;s.last_input=scene.clock;scene.variant_combat.tick_input(3,.016);s.weapon=3
	scene.clock+=.1;s.last_input=scene.clock;s.fire=false;scene.variant_combat.tick_input(3,.016)
	check(not scene.variant_combat.bursts.has(3),"Holstering cancels unfinished burst")
	var scout:Dictionary=scene.players[2];scout.last_input=scene.clock;scout.cooldown=0;scout.input_blocked=false
	before=scene.projectiles.size();check(scene.variant_combat.fire(2) and scene.projectiles.size()==before,"Beam pistol fires hitscan without spawning a projectile")
	s.last_input=scene.clock;s.cooldown=0;before=scene.projectiles.size();check(scene.variant_combat.fire(3) and scene.projectiles.size()==before+1 and scene.projectiles.values()[-1].definition.kind=="nail","SMG fires a travelling projectile")
	var bullet_id:int=scene.projectile_id;var bullet:Dictionary=scene.projectiles[bullet_id]
	bullet.position=Vector3(20,4,-20);bullet.velocity=Vector3(0,0,-150);bullet.fresh=true
	var targets=preload("res://deathmatch/projectile_targets.gd").new();targets.build(scene.players,scene.fighters,{})
	scene.variant_combat.tick_projectile(bullet_id,.02,{},targets)
	check(scene.projectiles.has(bullet_id) and bullet.position.is_equal_approx(Vector3(20,4,-23)),"SMG projectile advances through the actual arena sweep interface")
	scene.variant_combat.tick_projectile(bullet_id,.5,{},targets)
	check(not scene.projectiles.has(bullet_id) and scene.armory.data(3).fuse*scene.armory.data(3).speed==60.0,"Medic SMG limits projectile travel to short range")
	var soldier:Dictionary=scene.players[1];soldier.last_input=scene.clock;soldier.cooldown=0;soldier.input_blocked=false
	before=scene.projectiles.size();check(scene.variant_combat.fire(1) and scene.projectiles.size()==before+1 and scene.projectiles.values()[-1].definition.kind=="pulse","Service rifle fires travelling energy bolts")
	check(scene.armory.data(1).fuse*scene.armory.data(1).speed==180.0 and scene.armory.data(3).cycle<scene.armory.data(1).cycle,"Service rifle reaches medium range while medic favors shorter range and higher ROF")
	var tech:Dictionary=scene.players[4];tech.last_input=scene.clock;tech.cooldown=0;tech.input_blocked=false;tech.team=0
	check(not scene.variant_combat.fire(4),"Guided launcher cannot fire before acquiring a vehicle lock")
	var hull:=StaticBody3D.new();hull.collision_layer=1;scene.add_child(hull);hull.position=Vector3(0,4.3,-20)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,2,2);shape.shape=box;hull.add_child(shape)
	var vehicle=preload("res://deathmatch/conquest/classes/vehicle_health.gd").new();vehicle.team=1;vehicle.aircraft=true;hull.add_child(vehicle)
	await physics_frame
	var locking=scene.variant_combat.vehicle_lock
	for i in 14:scene.clock+=.1;tech.last_input=scene.clock;locking.tick(scene,.1)
	check(locking.locks.has(4) and not locking.locks[4].ready,"Enemy aircraft requires continuous acquisition dwell")
	scene.clock+=.2;tech.last_input=scene.clock;locking.tick(scene,.2)
	check(locking.locks.get(4,{}).get("ready",false),"Enemy aircraft locks after 1.5 seconds of clear aim")
	before=scene.projectiles.size();tech.fire=true;scene.variant_combat.tick_input(4,.016);tech.fire=false
	check(scene.projectiles.size()==before+1 and tech.ammo[2]==8 and scene.variant_combat.magazines.loaded(4)==2,"Guided shot spends one charge; two remain in pack plus two spare three-charge packs")
	check(not scene.variant_combat.magazines.tick(4) and scene.variant_combat.magazines.states[4].cycling==11,"Guided launcher internally reloads after a shot without changing packs")
	tech.cooldown=0;check(not scene.variant_combat.fire(4),"Charge reload blocks another shot even if firing cooldown has elapsed")
	scene.clock+=2.71;tech.last_input=scene.clock
	check(scene.variant_combat.magazines.tick(4) and scene.variant_combat.magazines.loaded(4)==2 and tech.ammo[2]==8,"Internal reload readies the next charge without creating ammo or needing a rack")
	for remaining in [1,0]:
		tech.cooldown=0;tech.fire=true;tech.last_input=scene.clock;scene.variant_combat.tick_input(4,.016);tech.fire=false
		check(scene.variant_combat.magazines.loaded(4)==remaining and tech.ammo[2]==6+remaining,"Each guided shot consumes exactly one pack charge")
		check(not scene.variant_combat.magazines.tick(4),"Guided launcher blocks firing during charge or empty-pack reload")
		if remaining==0:check(scene.variant_combat.magazines.states[4].reloading==11 and scene.variant_combat.magazines.states[4].cycling==-1,"Third shot empties the pack and starts replacement instead of internal cycling")
		scene.clock+=2.71;tech.last_input=scene.clock
		check(scene.variant_combat.magazines.tick(4) and scene.variant_combat.magazines.loaded(4)==(remaining if remaining>0 else 3) and tech.ammo[2]==6+remaining,"Reload retains remaining charges or seats a fresh three-charge pack")
	var guided:Dictionary=scene.projectiles.values()[-1];guided.velocity=Vector3(10,0,-30)
	var desired:Vector3=(vehicle.global_position-guided.position).normalized();var angle:float=guided.velocity.angle_to(desired);locking.guide(scene,.1)
	check(guided.velocity.angle_to(desired)<angle,"Guided ordnance turns toward its acquired hull")
	vehicle.team=0;locking.tick(scene,.1);check(not locking.locks.has(4),"Allied vehicle cannot retain an enemy lock")
	vehicle.team=1;scene.clock+=1;locking.tick(scene,.1);check(not locking.locks.has(4),"Stale aim cannot acquire a lock")
	check(vehicle.damage(1,100)==0 and vehicle.damage(0,100)==100,"Vehicle damage rejects friendly fire and accepts enemy ordnance")
	var model:=Node3D.new();scene.add_child(model);model.set_meta("zoom_steps",[2.0,4.0,8.0]);var optic=preload("res://deathmatch/vr/sniper_scope.gd").new();scene.add_child(optic);optic.attach(model);optic.step_zoom(.8);optic.step_zoom(0);optic.step_zoom(.8)
	check(optic.zoom_steps==[2.0,4.0,8.0] and optic.zoom_index==2,"Beam scope selects 2x / 4x / 8x")
	var dot:=Node3D.new();scene.add_child(dot);dot.set_meta("zoom_steps",[1.5]);optic.attach(dot);optic.step_zoom(.8)
	check(optic.zoom_steps==[1.5] and optic.zoom_index==0,"Switching to assault rifle resets to fixed 1.5x")
	print("CQ_PROGRESSION_RESULT ",JSON.stringify(failures));scene.disconnect_game();scene.free();quit(0 if failures.is_empty() else 1)
