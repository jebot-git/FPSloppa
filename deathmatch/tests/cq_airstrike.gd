extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Strike=preload("res://deathmatch/conquest/classes/airstrike.gd")
class TestArena extends Base:
	var impacts:Array=[]
	var ray_hit:Dictionary={"hit":true,"id":0,"position":Vector3(0,0,-80)}
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";return true
	func _trace(_a:Vector3,_b:Vector3,_id:int,_r:float=0,_radius:float=0,_m:Dictionary={},_c:Variant=null) -> Dictionary:return ray_hit.duplicate()
	func _cq_airstrike_fx(where:Vector3) -> void:impacts.append(where)
class DamageArena extends Base:
	var damage_log:Array=[]
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle"
		var ground:=StaticBody3D.new();ground.collision_layer=1;ground.position.y=Strike.Landscape.surface(0,0).x-.5
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(500,1,500);shape.shape=box;ground.add_child(shape);get_node("Map").add_child(ground);return true
	func _damage(victim:int,attacker:int,amount:int,weapon_name:String,_bypass:bool=false,_impact:Vector3=Vector3.INF,_direction:Vector3=Vector3.ZERO,_blast:bool=false,_hull:bool=false,_heavy:bool=false,_head:bool=false) -> void:damage_log.append({"id":victim,"attacker":attacker,"amount":amount,"weapon":weapon_name})
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func aim(game) -> void:
	game.players[1].weapon=8;game.players[1].fire=true;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].cooldown=0;game.players[1].move=Vector2.ZERO;game.players[1].jump=false;game.players[1].swim=Vector3.ZERO;game.fighters[1].velocity=Vector3(0,-.2,0)
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Airstrike",0,100,10,false);var strike=game.airstrike
	check(game.classes.has_grenade(1) and 8 not in game.players[1].owned,"T1 shocktroop retains HE grenade")
	game.classes.award(1,7499);check(not game.classes.choose_utility(1,"shocktroop","airstrike"),"T2 airstrike locked below level 15")
	game.classes.award(1,1);check(game.classes.choose_utility(1,"shocktroop","airstrike"),"Airstrike unlocks at 7500 class XP")
	game._spawn(1);aim(game)
	check(8 in game.players[1].owned and not game.classes.has_grenade(1) and game.grenades.state(1).counts[0]==0 and game.grenade_adapter.busy(1),"T2 designator replaces grenade inventory and physical throwing")
	game._add_player(2,"Ammo technician");game.classes.choose(2,"technician");game._spawn(2);game.players[2].team=game.players[1].team;game.classes.deploy(2,Vector3.ZERO)
	var supply_box:int=game.classes.dispensers.keys()[0]
	check(not game.classes.needs_supply(supply_box,1) and game.classes.transfer(supply_box,1,100)==0 and game.grenades.state(1).counts[0]==0,"Ammo dispenser cannot restore a grenade to the airstrike kit")
	game.fighters[2].position=Vector3(500,0,500)
	game.designate(1);check(strike.pending.has(1),"Stationary valid laser begins authority targeting")
	game.clock+=4.99;aim(game);game.designate(1);check(strike.flights.is_empty(),"No bomber before five seconds")
	game.players[1].move=Vector2(.1,0);strike.tick();check(strike.pending.is_empty() and game.designations.is_empty(),"Locomotion cancels lock and immediately hides laser")
	aim(game);game.fighters[1].velocity.x=.3;game.designate(1);check(strike.pending.is_empty(),"Coasting/physics motion blocks the designator with released movement input")
	aim(game);game.fighters[1].velocity.y=-1;game.designate(1);check(strike.pending.is_empty(),"Falling or jetpack ascent blocks designator")
	aim(game);game.players[1].room=Vector3(.04,0,0);game.fighters[1].position+=Vector3(.04,0,0);game.designate(1);check(strike.pending.has(1),"Validated playspace capsule shift permits targeting without physics locomotion")
	game.players[1].fire=false;strike.tick();check(strike.pending.is_empty(),"Trigger release cancels continuous sequence")
	aim(game);game.designate(1);game.clock+=.36;strike.tick();check(strike.pending.is_empty(),"Stale controller input cancels lock")
	aim(game);game.designate(1);var initial:Dictionary=strike.pending[1].duplicate();game.clock+=5;aim(game);game.ray_hit.position+=Vector3(2,0,0);game.designate(1)
	check(strike.flights.size()==1 and strike.pending.is_empty(),"Five-second uninterrupted targeting calls one bomber")
	var flight:Dictionary=strike.flights.values()[0];var ready:float=game.classes.ensure(1).airstrike_ready
	check(is_equal_approx(ready-game.clock,300) and flight.direction==initial.direction,"Five-minute cooldown and initial targeting bearing captured")
	var before:int=strike.flights.size();game.clock+=.1;aim(game);game.designate(1);check(strike.flights.size()==before,"Held trigger cannot repeat a call during cooldown")
	for i in Strike.COUNT:
		var p:=Strike.point(flight,i);game.ray_hit.position=p;game.clock=Strike.impact_time(flight,i);strike.tick()
		check(game.impacts.size()==i+1,"Barrage impact %d delivered once in order"%(i+1))
		if i>0:check((p-Strike.point(flight,i-1)).dot(initial.direction)>0,"Barrage advances along original laser bearing")
	strike.tick();check(game.impacts.size()==12,"Tick repetition never duplicates payload impacts")
	game._spawn(1);check(game.classes.ensure(1).airstrike_ready==ready,"Cooldown survives respawn")
	var snap:Dictionary=game.match_mode.snapshot();check(snap.has("cas:1") and snap["cp:1"].state.airstrike_ready==ready,"Bomber and cooldown replicated independently")
	var replica:=Strike.new();game.add_child(replica);replica.setup(game);replica.receive({1:flight},{1:initial},500)
	check(replica.flights[1].impact_at==flight.impact_at+500 and replica.pending[1].at==initial.at+500 and Strike.position(replica.flights[1],game.clock+500).is_equal_approx(Strike.position(flight,game.clock)),"Flight, payload and targeting deadlines preserve client clock offset")
	game.clock=ready-.001;aim(game)
	check(not strike.launch(1,Vector3(1413,0,1413),Vector3(1,0,1)),"Airstrike unavailable immediately before five-minute cooldown")
	game.clock=ready;aim(game)
	check(strike.launch(1,Vector3(1413,0,1413),Vector3(1,0,1)),"Airstrike ready at exactly five minutes")
	var edge:Dictionary=strike.flights.values()[-1];var bounded:=true
	for i in Strike.COUNT:
		var p:=Strike.point(edge,i)
		if absf(p.x)>Strike.Landscape.EXTENT/2+.01 or absf(p.z)>Strike.Landscape.EXTENT/2+.01:bounded=false
	check(bounded,"All twelve barrage points stay within map edges")
	game.classes.choose(1,"scout");game._spawn(1);aim(game);game.players[1].move=Vector2(.2,0);game.designate(1);check(not game.designations.has(1),"Scout designator also requires stationary locomotion")
	game.match_mode.reset();check(strike.flights.is_empty() and strike.pending.is_empty(),"Round reset clears targeting, bomber and payloads")
	var model:Node3D=load("res://deathmatch/models/airstrike/bomber.glb").instantiate();var tris:=count_triangles(model);check(tris<=1500,"Optimized X-001 bomber has at most 1500 triangles (%d)"%tris)
	Strike.prepare_model(model);Strike.Lighting.convert_node(model);check(painted(model),"Bomber baked material uses authored coloured vertices instead of default white");model.free()
	game.disconnect_game();game.free()
	var damage=load("res://tools/voxel_battle/class_arena.tscn").instantiate();damage.set_script(DamageArena);root.add_child(damage);damage.set_process(false);damage.set_physics_process(false);damage.start_host("Damage",0,100,10,false)
	for id in [2,3,4,5]:damage._add_player(id,"Target"+str(id));damage.players[id].team=1;damage.players[id].invulnerable=0
	damage.players[1].team=0;damage.players[4].team=0
	damage.fighters[1].position=Vector3(50,0,0);damage.fighters[2].position=Vector3.ZERO;damage.fighters[3].position=Vector3(3,0,0);damage.fighters[4].position=Vector3(2,0,0);damage.fighters[5].position=Vector3(25,0,0)
	var height:float=Strike.Landscape.surface(0,0).x
	for fighter in damage.fighters.values():fighter.position.y=height
	await physics_frame;await physics_frame
	var row:Dictionary={"owner":1,"team":0,"start":Vector3(0,height+100,100),"target":Vector3(0,height,0),"direction":Vector3.FORWARD,"step":18}
	damage.airstrike.impact(row,0)
	var direct:Array=damage.damage_log.filter(func(r):return r.id==2);var splash:Array=damage.damage_log.filter(func(r):return r.id==3)
	check(direct.size()==1 and direct[0].amount==300,"Real downward collision delivers exactly 300 direct damage without double splash")
	check(splash.size()==1 and splash[0].amount>200 and splash[0].amount<300,"Nearby enemy receives the existing 300-point rocket splash falloff")
	check(damage.damage_log.any(func(r):return r.id==4) and damage.damage_log.any(func(r):return r.id==5),"Airstrike hits allies and targets beyond the old radius")
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(1.5,height+1,0);var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,12);shape.shape=box;wall.add_child(shape);damage.get_node("Map").add_child(wall)
	await physics_frame;await physics_frame;damage.damage_log.clear();damage.airstrike.impact(row,0)
	check(damage.damage_log.filter(func(r):return r.id==3).is_empty(),"Solid cover blocks rocket splash line of sight")
	damage.disconnect_game();damage.free()
	print("CQ_AIRSTRIKE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func count_triangles(node:Node) -> int:
	var count:=0
	if node is MeshInstance3D:count+=node.mesh.get_faces().size()/3
	for child in node.get_children():count+=count_triangles(child)
	return count

func painted(node:Node) -> bool:
	if node is MeshInstance3D:
		var colours:PackedColorArray=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		if not material.get_shader_parameter("vertex_tint") or colours.is_empty() or colours[0].r>.8:return false
	for child in node.get_children():
		if not painted(child):return false
	return true
