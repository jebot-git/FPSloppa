extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const AI=preload("res://deathmatch/bot_ai/tribes.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
var g
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func point(x: float=0,y: float=0,z: float=0) -> Vector3:return Fixture.ORIGIN+Vector3(x,y,z)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST infrastructure",0,100,30,true,"st");g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Equipment opponent");g.players[1].team=0;g.players[-1].team=1
	var rules=g.match_mode.tribes;var pads=rules.stations();var assets=pads.assets;var deploy=rules.deployables
	var actor=g.fighters[1];var enemy=g.fighters[-1]
	Fixture.setup(g);Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	actor.position=point(50,0);enemy.position=point(-50,0)
	await physics_frame;await physics_frame
	check(assets.rows.size()==6 and assets.rows.filter(func(r):return r.kind=="pulse").size()==2,"Stonehenge has four independent stations and two fixed pulse sensors")
	for index in pads.rows.size():
		var row: Dictionary=pads.rows[index];var key: int=row.asset;var asset: Dictionary=assets.rows[key]
		g.players[1].team=row.team;g.players[-1].team=1-row.team
		actor.position=row.position;actor.velocity=Vector3.ZERO
		var eye: Vector3=actor.position+Vector3.UP*actor.eye_height()
		var direction: Vector3=(row.frame*Vector3(0,2.4,1.9)-eye).normalized()
		var hit: Dictionary=g._trace(eye,eye+direction*5,1)
		check(hit.get("base_asset",-1)==key,"Weapon trace hits inventory frame %d"%index)
		g._damage_map_hit(hit,1,10000);check(asset.hp==assets.HP,"Friendly-fire policy protects station %d"%index)
		g._damage_map_hit(hit,-1,10000)
		check(asset.hp==0 and pads.at(1)<0 and not rules.can_refit(1),"Destroyed station denies purchases independently %d"%index)
		check(pads.powered(row.team) and pads.rows.any(func(other):return other.team==row.team and other.asset!=key and assets.active(other.asset)),"Sibling station and generator remain online %d"%index)
		check(not assets.repair(key,-1,20),"Enemy repair rejected %d"%index)
		rules.apply_equipment(1,"light",[3,2,0],"repair")
		rules.combat.beam(1,8,eye,direction,1)
		check(asset.hp>0 and pads.at(1)<0,"Initial repair beam repairs but leaves damaged station offline %d"%index)
		assets.repair(key,1,10000)
		check(pads.at(1)==index,"Repair above threshold restores inventory service %d"%index)
		actor.position=point(50,0)
		assets.blast(eye,-1,40,5);check(asset.hp<assets.HP,"Visible explosion damages station %d"%index)
		assets.reset()
		g.variant_combat.launch(0,0,eye,direction,{"tribes_turret":true,"turret_team":row.team})
		for frame in 30:g._update_projectiles(1.0/120)
		check(asset.hp==assets.HP,"Orphaned friendly turret projectile respects fixture ownership %d"%index)
		g.variant_combat.launch(0,0,eye,direction,{"tribes_turret":true,"turret_team":1-row.team})
		for frame in 30:g._update_projectiles(1.0/120)
		check(asset.hp<assets.HP,"Enemy turret projectile still damages fixture %d"%index)
		assets.reset()
	actor.position=point(50,0);enemy.position=point(-50,0)
	for key in assets.rows.size():
		var row: Dictionary=assets.rows[key]
		if row.kind!="pulse":continue
		var start: Vector3=row.frame*Vector3(0,5,4)
		var hit: Dictionary=g._trace(start,row.frame*Vector3(0,5,-4),1)
		check(hit.get("base_asset",-1)==key,"BSP sensor antenna is damageable %d"%row.team)
		g.players[1].team=row.team;g.players[-1].team=1-row.team
		g._damage_map_hit(hit,-1,10000);check(not assets.active(key),"Destroyed fixed sensor stops working %d"%row.team)
		rules.combat.beam(1,8,start,(row.point-start).normalized(),1)
		check(row.hp>0 and not assets.active(key),"Initial repair beam leaves disabled sensor below threshold %d"%row.team)
		assets.reset()
	await sensor_cases()
	await bot_cases()
	var snapshot: Dictionary=rules.snapshot()
	check(rules.valid_snapshot(snapshot) and rules.valid_snapshot(Codec.unpack(Codec.pack(snapshot))),"Base health and detection survive the production codec")
	var malformed: Dictionary=snapshot.duplicate(true);malformed.base_assets[0]=NAN
	check(not rules.valid_snapshot(malformed),"Non-finite asset health rejected")
	malformed=snapshot.duplicate(true);malformed.base_assets.resize(129)
	check(not rules.valid_snapshot(malformed),"Unbounded base asset state rejected")
	malformed=snapshot.duplicate(true);malformed.deployables.suppressed=["bad"]
	check(not rules.valid_snapshot(malformed),"Malformed sensor suppression rejected")
	var legacy: Dictionary=snapshot.duplicate(true);legacy.erase("base_assets");legacy.erase("fixed_defences");legacy.deployables.erase("suppressed")
	for key in ["power","targeting","recovery"]:legacy.erase(key)
	for row in legacy.players.values():row.erase("beacons")
	check(rules.valid_snapshot(legacy),"Legacy Tribes demo state remains readable")
	assets.rows[0].hp=0;rules.receive(snapshot);check(assets.rows[0].hp==snapshot.base_assets[0],"Client/replay restores independent fixture damage")
	await uphill_cases()
	print("ST_BASE_ASSETS ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
func sensor_cases():
	var rules=g.match_mode.tribes;var pads=rules.stations();var assets=pads.assets;var deploy=rules.deployables
	var key: int=range(assets.rows.size()).filter(func(i):return assets.rows[i].kind=="pulse" and assets.rows[i].team==0)[0]
	var sensor: Dictionary=assets.rows[key];var original: Transform3D=sensor.frame
	sensor.frame=Transform3D(Basis.IDENTITY,point(0,0))
	g.players[1].team=0;g.players[-1].team=1;g.fighters[1].position=point(-100,0);g.fighters[-1].position=point(0,0,-30)
	deploy.scan();check(-1 in deploy.contacts[0] and deploy.sensor_status(-1)=="DETECTED","Powered fixed pulse detects visible stationary enemy")
	var wall=Fixture.box(g,point(0,5,-15),Vector3(12,12,1));await physics_frame;await physics_frame
	deploy.scan();check(-1 not in deploy.contacts[0],"Fixed pulse respects world occlusion")
	wall.free();await physics_frame
	rules.apply_equipment(-1,"light",[3,2,0],"jammer");g.fighters[-1].tribes_state.pack_on=true
	deploy.scan();check(-1 not in deploy.contacts[0] and deploy.sensor_status(-1)=="JAMMED","Active jammer suppresses pulse and reports scan suppression")
	g.fighters[-1].tribes_state.pack_on=false;pads.health[0]=0
	deploy.scan();check(-1 not in deploy.contacts[0] and deploy.sensor_status(-1)=="CLEAR","Generator outage disables linked sensor")
	pads.health[0]=pads.GENERATOR_HP;sensor.hp=0;deploy.scan();check(-1 not in deploy.contacts[0],"Destroyed sensor cannot contribute contacts")
	sensor.hp=assets.HP;sensor.frame=original;deploy.scan()
func bot_cases():
	var ai=g.bots;var rules=g.match_mode.tribes;var deploy=rules.deployables;var pads=rules.stations()
	var actor=g.fighters[-1];g.players[-1].team=0;g.players[1].team=1
	rules.apply_equipment(-1,"light",[3,2,0],"none");actor.position=point(0,0);actor.velocity=Vector3.ZERO
	g.fighters[1].position=point(100,0)
	var row:={"kind":"turret","team":1,"owner":1,"position":point(0,0,-20),"normal":Vector3.UP,"yaw":0.0,"hp":deploy.Data.hp("turret"),"energy":60.0,"ready":0.0,"aim":Vector3.BACK}
	deploy.rows[500]=row;deploy.sync();await physics_frame;await physics_frame
	var brain: Dictionary=ai.new_brain(-1);brain.role="capper";brain.goal_kind="objective";brain.goal_key="st:flag";brain.goal=point(0,0,-50)
	var point: Vector3=row.position+Vector3.UP*.55;ai.aim(-1,point,1)
	check(ai.tribes.equipment.combat(-1,brain,1.0/60) and g.players[-1].fire,"Runner deliberately fires at exposed enemy turret")
	var yaw: float=g.players[-1].yaw;ai.tribes.steer(-1,brain)
	check(brain.goal_key=="st:flag" and is_equal_approx(yaw,g.players[-1].yaw),"Equipment fire preserves flag objective and aim through steering")
	g._add_player(-2,"Disconnecting threat");brain.enemy=-2;g._peer_left(-2)
	check(ai.tribes.equipment.combat(-1,brain,1.0/60),"Disconnect between perception ticks does not interrupt equipment targeting")
	brain.enemy=0
	g.players[-1].cooldown=0;g.players[-1].input_blocked=false
	var before: int=rules.amount(-1,g.players[-1].weapon)
	var fired: bool=rules.combat.fire(-1)
	for frame in 90:g._update_projectiles(1.0/120)
	check(fired and rules.amount(-1,g.players[-1].weapon)==before-1 and (not deploy.rows.has(500) or deploy.rows[500].hp<deploy.Data.hp("turret")),"Bot-selected shot consumes ammo and actually damages the turret")
	row.hp=deploy.Data.hp("turret");deploy.rows[500]=row;deploy.sync();await physics_frame
	var wall=Fixture.box(g,point(0,3,-10),Vector3(10,6,1));await physics_frame;await physics_frame
	check(not ai.tribes.equipment.combat(-1,brain,1.0/60),"Bot cannot keep firing at a turret through new cover")
	wall.free();row.team=0;await physics_frame
	check(not ai.tribes.equipment.combat(-1,brain,1.0/60),"Bot rejects a friendly turret")
	row.team=1;row.position=point(0,24,-15);deploy.sync();g.clock+=1;brain.equipment_scan_at=0;g.players[-1].yaw=0
	await physics_frame;await physics_frame
	check(ai.tribes.equipment.combat(-1,brain,1.0/60) and brain.equipment_target==500,"Visible turret above a tower approach can be acquired without first reaching the deck")
	row.position=point(0,0,20);deploy.sync();g.clock+=1;brain.equipment_scan_at=0;g.players[-1].yaw=0
	await physics_frame;await physics_frame
	check(not ai.tribes.equipment.combat(-1,brain,1.0/60),"Equipment acquisition still rejects a distant turret behind the bot")
	row.team=0;row.position=point(0,0,-20);deploy.sync();await physics_frame
	row.hp-=20;rules.apply_equipment(-1,"light",[3,2,0],"repair")
	actor.position=row.position+Vector3(0,0,2.5)
	var rows: Array=[]
	check(ai.tribes.equipment.repair_goal(-1,rows) and rows[0].kind=="st_deploy_repair","Repair specialist selects damaged friendly turret")
	brain.goal_kind="st_deploy_repair";brain.support=500;ai.aim(-1,point,1)
	check(ai.tribes.equipment.combat(-1,brain,1.0/60) and g.players[-1].weapon==8 and g.players[-1].fire,"Bot repair action reaches real deployable hitbox")
	deploy.reset();await physics_frame
	var station: Dictionary=pads.rows[0];pads.assets.rows[station.asset].hp=0;rows=[]
	check(ai.tribes.equipment.repair_goal(-1,rows) and rows[0].kind=="st_asset_repair","Damaged inventory station gets a repair objective")
	actor.position=station.position;brain.goal_kind="st_asset_repair";brain.support=station.asset
	ai.aim(-1,pads.assets.rows[station.asset].point,1)
	check(ai.tribes.equipment.combat(-1,brain,1.0/60) and g.players[-1].fire,"Bot can repair the fixed station with normal repair gun")
	pads.assets.reset()
func uphill_cases():
	var actor=g.fighters[-1];var rules=g.match_mode.tribes
	var ramp=Fixture.box(g,point(0,30,120),Vector3(140,1,50));ramp.rotation.z=deg_to_rad(20)
	await physics_frame;await physics_frame
	for armour in ["light","medium","heavy"]:
		rules.apply_equipment(-1,armour,[3,2,0],"none");actor.position=point(-30,30-tan(deg_to_rad(20))*30+1,120);actor.velocity=Vector3.ZERO
		actor.configure_tribes(true);actor.jet_held=false
		for i in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60)
		var start: Vector3=actor.position;var skiing:=0
		for i in 240:
			var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
			actor.ski_held=AI.ground_ski(actor.tribes_state.normal,Vector3.RIGHT,velocity,rules.definition(-1).walk,3)
			skiing+=int(actor.ski_held);actor.simulate(Vector2.RIGHT,0,false,1.0/60)
		check(actor.position.x-start.x>rules.definition(-1).walk*2.5 and actor.position.y>start.y+3 and skiing==0,"Walk traction climbs a real 20-degree hill without jets: "+armour)
	check(AI.ground_ski(Vector3(-.34,.94,0),Vector3.RIGHT,Vector3.RIGHT*35,11,5),"Fast uphill coast keeps useful momentum")
	check(not AI.ground_ski(Vector3(-.34,.94,0),Vector3.RIGHT,Vector3.RIGHT*12,11,5),"Fading uphill momentum releases ski before stalling")
	check(AI.ground_ski(Vector3(.34,.94,0),Vector3.RIGHT,Vector3.ZERO,11),"Downhill skiing can accelerate from rest")
