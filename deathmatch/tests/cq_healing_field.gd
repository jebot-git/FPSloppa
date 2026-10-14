extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Field=preload("res://deathmatch/conquest/classes/healing_field.gd")
class TestArena extends Base:
	var damages:Array=[]
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";map_sha=map_identity()
		var ground:=StaticBody3D.new();ground.collision_layer=1;ground.position.y=-.5;var shape:=CollisionShape3D.new();var mesh:=BoxShape3D.new();mesh.size=Vector3(1000,1,1000);shape.shape=mesh;ground.add_child(shape);get_node("Map").add_child(ground);return true
	func _damage(victim:int,_attacker:int,amount:int,_weapon:String,_bypass:bool=false,_impact:Vector3=Vector3.INF,_direction:Vector3=Vector3.ZERO,_blast:bool=false,_hull:bool=false,_heavy:bool=false,_head:bool=false) -> void:damages.append({"id":victim,"amount":amount})
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Medic",28796,100,10,false)
	game.classes.choose(1,"medic");game._spawn(1);check(game.classes.deploy(1,Vector3.ZERO),"T1 medic retains health box")
	game.classes.award(1,7499);check(not game.classes.choose_utility(1,"medic","healing_grenade"),"Healing grenade locked below level 15")
	game.classes.award(1,1);check(game.classes.choose_utility(1,"medic","healing_grenade"),"Healing grenade unlocks at 7500 medic XP")
	game._spawn(1);game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.fighters[1].position=Vector3.ZERO
	check(game.grenades.state(1).counts[3]==3 and 6 not in game.players[1].owned and 7 in game.players[1].owned and game.classes.dispensers.is_empty() and not game.classes.deploy(1,Vector3.ZERO),"T2 carries three grenades and injector, replacing box and clearing previous boxes")
	check(not game.grenades.buy(1,3),"Carry capacity cannot exceed three")
	game.equip_he(1);check(game.grenades.selected(1)==3,"Desktop G selects healing grenade")
	game.players[1].fire=true;game.variant_combat.tick_input(1,.016);game.clock+=.5;game.players[1].last_input=game.clock;game.players[1].fire=false;game.variant_combat.tick_input(1,.016)
	check(game.grenades.state(1).counts[3]==2 and game.grenades.flying.size()==1 and game.grenades.flying.values()[0].kind==3,"Normal trigger press/release throwing path consumes exactly one healing grenade")
	var shot:int=game.grenades.flying.keys()[0];game.grenades.flying[shot].position=Vector3(0,.065,0);game.grenades.detonate(shot)
	var field=game.healing_field;var key:int=field.fields.keys()[0]
	check(field.fields[key].health==500 and field.fields[key].energy==500 and field.fields[key].until-game.clock==10,"Detonation creates independent 500 HP / 500 energy pools for ten seconds")
	game._add_player(2,"Ally");game._add_player(3,"Enemy");game._add_player(4,"Outside")
	for id in game.players:game.players[id].hp=50;game.players[id].invulnerable=0;game.fighters[id].position=Vector3(id-1,0,0);game.players[id].team=0
	game.players[3].team=1;game.fighters[4].position=Vector3(5.1,0,0)
	await physics_frame;await physics_frame
	field.tick(1);check(game.players[1].hp==60 and game.players[2].hp==60 and game.players[3].hp==50 and game.players[4].hp==50 and field.fields[key].health==480,"Regeneration is 10 HP/s per ally, excludes enemies and outside players, and charges actual healing")
	field.fields[key].health=5;game.clock+=1;field.tick(1);check(field.fields.has(key) and field.fields[key].health==0 and field.fields[key].energy==500,"Healing pool depletion leaves force field intact")
	var result:Dictionary=field.intercept(3,Vector3(-10,1,0),Vector3(10,1,0),120,false)
	check(result.damage==120 and field.fields[key].energy==500,"Projectiles, ordnance and non-energy hits do not interact with shield")
	result=field.intercept(1,Vector3(0,1,0),Vector3(10,1,0),55,true)
	check(result.damage==55 and field.fields[key].energy==500,"Allied fire from inside exits freely without shield damage")
	result=field.intercept(3,Vector3(-10,1,0),Vector3(0,1,0),55,true)
	check(result.damage==0 and field.fields[key].energy==445 and is_equal_approx(result.position.distance_to(field.fields[key].position),5),"Incoming energy is stopped at exact five-metre boundary and deducted from shield")
	result=field.intercept(3,Vector3(-10,1,0),Vector3(0,1,0),500,true)
	check(result.damage==55 and field.fields.is_empty(),"Shield absorbs only remaining capacity, breaks immediately and passes excess energy")
	field.activate(1,Vector3.ZERO,0);key=field.fields.keys()[0];field.fields[key].health=0;var until:float=field.fields[key].until;game.clock=until-.001;field.tick(0);check(field.fields.has(key),"Empty healing pool still shields until timeout")
	game.clock=until;field.tick(0);check(field.fields.is_empty(),"Field expires exactly at ten seconds")
	# Validated tracked throwing uses the same shoulder gesture and guided velocity.
	game.clock+=1;game.players[1].last_input=game.clock;game.players[1].input_blocked=false
	var pose:Dictionary={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.7,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.25,1.25,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.25,1.25,-.3)),"left_handed":false,"weapon":Transform3D.IDENTITY}
	game.players[1].xr=pose;game.players[1].vr_device=true;game.players[1].physical=true
	check(game.grenades.physical_request(1,"arm",pose,Vector3.ZERO) and game.grenades.physical_request(1,"throw",pose,Vector3(0,0,-4)) and game.grenades.state(1).counts[3]==1,"VR offhand shoulder arm and guided physical throw consume healing grenade")
	check(game.grenades.valid_snapshot(game.grenades.snapshot()),"Four-kind inventory and healing projectile validate for replication")
	field.activate(1,Vector3.ZERO,0);var snapshot:Dictionary=game.match_mode.snapshot();check(snapshot.keys().any(func(k):return str(k).begins_with("chf:")),"Shield has independent snapshot record")
	var replica:=Field.new();game.add_child(replica);replica.setup(game);replica.receive(field.fields,500);check(replica.fields.values()[0].until==field.fields.values()[0].until+500,"Shield expiry preserves relative client clock deadline")
	game.players[1].xr={};game.players[1].vr_device=false;game.players[1].hp=50;game.fighters[1].position=Vector3.ZERO
	game.classes.choose(3,"scout");game._spawn(3);game.classes.award(3,5000);game.classes.choose_equipment(3,"scout",10,false);game._spawn(3);game.players[3].weapon=10;game.players[3].team=1;game.players[3].input_blocked=false;game.players[3].cooldown=0;game.players[3].last_input=game.clock;game.players[3].yaw=-PI/2;game.players[3].pitch=0;game.fighters[3].position=Vector3(-12,0,0)
	game.fighters[2].position=Vector3(30,0,30);game.fighters[4].position=Vector3(40,0,40)
	await physics_frame;await physics_frame
	game.damages.clear();key=field.fields.keys()[0];var energy:float=field.fields[key].energy
	var fired:bool=game.variant_combat.fire(3)
	check(fired and field.fields[key].energy==energy-55 and game.damages.is_empty(),"Real scout beam firing path stops before target and drains 55 energy")
	game.players[3].weapon=9;game.players[3].owned.append(9);game.players[3].ammo[0]=42;game.players[3].cooldown=0;game.variant_combat.fire(3)
	check(not game.damages.is_empty() and field.fields[key].energy==energy-55,"Real ballistic hitscan path ignores force field")
	game.players[3].weapon=4;game.players[3].owned.append(4);game.players[3].ammo[1]=120;game.players[3].cooldown=0;game.variant_combat.magazines.state(3).clips[4]=30
	var launched:int=game.variant_combat.launch(3,4,Vector3(-10,1,0),Vector3.RIGHT)
	var targets=preload("res://deathmatch/projectile_targets.gd").new();targets.build(game.players,game.fighters,{})
	game.damages.clear();game.variant_combat.tick_projectile(launched,.2,{},targets)
	check(launched>=0 and not game.damages.is_empty() and field.fields[key].energy==energy-55,"Travelling laser-carbine energy projectile crosses field and damages inside target without absorption")
	game.damages.clear();game.variant_combat.blast(Vector3(1,1,0),3,120,5,"TEST ORDNANCE",0,true)
	check(not game.damages.is_empty() and field.fields[key].energy==energy-55,"Ordnance splash damages allies inside without consuming shield")
	field.reset()
	for id in range(5,33):game._add_player(id,"Crowded ally %d"%id)
	for id in game.players:game.players[id].team=0;game.players[id].hp=1;game.fighters[id].position=Vector3(id*.03,0,0)
	await physics_frame;await physics_frame
	field.activate(1,Vector3.ZERO,0);game.clock+=5;field.tick(5)
	var healed:=0
	for player in game.players.values():healed+=player.hp-1
	check(healed==500 and field.fields.values()[0].health==0 and field.fields.values()[0].energy==500,"Thirty-two wounded allies share exactly 500 HP; pool depletion preserves shielding")
	game.match_mode.reset();check(field.fields.is_empty() and field.credits.is_empty(),"Round reset clears fields and healing credits")
	var model=preload("res://deathmatch/conquest/classes/grenade_visuals.gd").model(3);check(triangles(model)>0 and triangles(model)<=1200,"Procured healing grenade imports with optimized handheld mesh");model.free()
	print("CQ_HEALING_FIELD_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func triangles(node:Node) -> int:
	var count:=0
	if node is MeshInstance3D:count+=node.mesh.get_faces().size()/3
	for child in node.get_children():count+=triangles(child)
	return count
