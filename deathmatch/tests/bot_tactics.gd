extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var bots
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func reset_positions() -> void:
	for id in game.players:
		game.players[id].dead=false;game.players[id].spectator=false;game.players[id].invulnerable=0
		game.fighters[id].position=Fixture.point(-10+abs(id)*2,12)
	game.fighters[-1].position=Fixture.point()
	bots.brains[-1]=bots.new_brain(-1)
func run() -> void:
	seed(7129)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("AI tests",0,100,60,true,"dm");game.set_physics_process(false)
	bots=game.bots;Fixture.setup(game);await physics_frame
	reset_positions()
	var s: Dictionary=game.players[-1];var brain: Dictionary=bots.brains[-1]
	game.pickups=[{"kind":"health","item":25,"position":Fixture.point(0,-5),"available":true},{"kind":"ammo","item":2,"position":Fixture.point(0,-1),"available":true},{"kind":"armor","item":2,"position":Fixture.point(0,6),"available":true}]
	s.hp=20;s.armor=0;s.owned=[2];s.ammo=[50,0,0,0]
	bots.plan(-1,brain)
	check(brain.goal_key=="item:0","Critical health wins over nearer unusable ammo and armor")
	s.hp=100
	check(bots.item_value(-1,game.pickups[0])==0 and bots.item_value(-1,game.pickups[1])==0,"Skip full health and ammunition for unowned weapons")
	s.owned=[0,2,4,6,7];s.ammo=[10,10,5,20]
	check(bots.choose_weapon(-1,2)!=6 and bots.choose_weapon(-1,2)!=8,"Avoid explosive weapons at self-damage range")
	s.ammo=[0,0,0,0];check(bots.choose_weapon(-1,2)==0,"Empty weapons fall back to owned melee")
	s.owned=[2];s.ammo=[50,0,0,0]
	game.players[-2].spectator=true;game.players[-3].spectator=true
	game.fighters[1].position=Fixture.point(0,-5)
	await physics_frame
	bots.perceive(-1,brain);check(brain.enemy==1,"Acquire visible enemy")
	var seen: Vector3=brain.seen_position
	game.fighters[1].position=Fixture.point(12,0)
	await physics_frame
	bots.perceive(-1,brain)
	check(brain.enemy!=1 and brain.seen_position==seen,"Occluded enemy does not update last-known position")
	# A visible incoming rocket requests a lateral escape with checked ground.
	game.projectiles[999]={"owner":1,"position":Fixture.point(0,-5)+Vector3.UP,"direction":Vector3.BACK,"weapon":6}
	bots.perceive_projectiles(-1,brain)
	check(brain.dodge_until>game.clock and absf(brain.dodge.x)>.9,"Bot dodges a visible incoming projectile sideways")
	game.projectiles.clear()
	var cover_rows: Array=[];s.hp=20;brain.enemy=1;brain.visible=[1]
	game.fighters[1].position=Fixture.point(12,0)
	game.fighters[-1].position=Fixture.point(8,5)
	await physics_frame;bots.cover_goals(-1,brain,cover_rows)
	check(not cover_rows.is_empty() and cover_rows.all(func(row):return not bots.navigation.ray(bots.target_position(1),row.position+Vector3.UP*.8).is_empty()),"Low-health bot finds positions shielded from enemy fire")
	# A low ceiling requests the same crouch input as a human.
	reset_positions();brain=bots.brains[-1]
	var ceiling=Fixture.box(game,Fixture.point(0,-1)+Vector3.UP*1.55,Vector3(3,.25,1))
	brain.goal=Fixture.point(0,-8);brain.goal_kind="roam";brain.path=PackedVector3Array()
	await physics_frame;bots.steer(-1,brain,1.0/60)
	check(s.crouch and not s.prone,"Crouch under a low passage")
	ceiling.free()
	game.fighters[-1].in_water=true;game.fighters[-1].underwater=true
	brain.goal=Fixture.point(0,-5)+Vector3.UP*3;bots.steer(-1,brain,1.0/60)
	check(s.swim.y>0 and s.jump,"Swim upward and request a surface jump toward a raised exit")
	game.fighters[-1].in_water=false;game.fighters[-1].underwater=false
	game.match_mode.kind="tf"
	game.players[-1].team=0;game.players[-2].team=0;game.players[1].team=1;game.players[-3].team=1
	s.tf_class="medic";s.hp=110;s.armor=50;s.owned=[0,2,7];s.ammo=[80,0,0,100]
	game.players[-2].tf_class="soldier";game.players[-2].hp=30
	game.fighters[-2].position=Fixture.point(0,-3)
	game.fighters[1].position=Fixture.point(12,12);game.fighters[-3].position=Fixture.point(12,12)
	game.match_mode.fortress.cooldowns[-1]=0
	brain.goal_kind="heal";brain.support=-2;brain.enemy=0
	await physics_frame;bots.class_action(-1,brain)
	check(game.players[-2].hp==65,"Medic aims and heals through authoritative ability with normal cooldown")
	check(game.match_mode.fortress.cooldowns[-1]>game.clock,"Medic healing obeys cooldown")
	game.players[1].team=0;game.fighters[1].position=Fixture.point(0,-1.5)
	await physics_frame
	check(not bots.safe_shot(-1,Fixture.point(0,-5)+Vector3.UP),"Teammate in firing lane blocks bot fire")
	game.players[1].team=1
	game.match_mode.flags[1].carrier=-1
	var rows: Array=[];bots.mode_goals(-1,brain,rows)
	check(rows.any(func(row):return row.kind=="capture"),"Flag carrier plans a return to the capture zone")
	game.match_mode.flags[1].carrier=-2;rows=[];bots.mode_goals(-1,brain,rows)
	check(rows.any(func(row):return row.kind=="escort" and row.support==-2),"Teammate carrier gets an escort goal")
	game.match_mode.flags[1].carrier=0
	game.match_mode.kind="as"
	var assault=game.match_mode.assault;assault.finished=false;assault.switching=false;assault.attacking=0;assault.stage=0
	assault.objectives=[{"position":Fixture.point(0,-6),"health":100},{"position":Fixture.point(0,8),"health":0}]
	rows=[];bots.mode_goals(-1,brain,rows)
	check(rows.any(func(row):return row.kind=="destroy" and row.key=="as:0") and not rows.any(func(row):return row.key=="as:1"),"AS attacks only the active destructible objective")
	s.team=1;rows=[];bots.mode_goals(-1,brain,rows)
	check(rows.any(func(row):return row.kind=="defend") and not rows.any(func(row):return row.kind=="destroy"),"AS defenders hold the active objective")
	# Exercise actual AS damage/advancement while a distant defender is visible.
	s.team=0;s.owned=[5];s.weapon=5;s.ammo=[200,0,0,0];s.yaw=0;s.pitch=0
	game.fighters[-2].position=Fixture.point(-12,12)
	game.fighters[1].position=Fixture.point(4,-10)
	brain.goal_kind="destroy";brain.goal=assault.objectives[0].position;brain.enemy=1;brain.seen_at=game.clock-1
	game.match_mode.fortress.buildings[100100]={"owner":0,"team":1,"position":assault.objectives[0].position,"kind":"compressor","hp":100,"objective":0}
	await physics_frame
	for shot in 40:
		bots.combat(-1,brain);s.cooldown=0
		if s.fire:game._fire(-1)
		if assault.stage>0:break
	check(assault.stage==1,"AS bot destroys the active objective through normal weapon damage")
	game.match_mode.kind="tf";s.tf_class="spy";s.ammo=[80,25,5,50];s.tf_disguise={}
	var tf=game.match_mode.fortress;tf.spy_invisibility=true;tf.cooldowns[-1]=0;brain.enemy=0
	bots.class_action(-1,brain);check(tf.cloaked(-1),"Spy cloaks while travelling without a flag")
	tf.cooldowns[-1]=0;bots.class_action(-1,brain);check(tf.cloaked(-1),"Spy does not toggle a useful cloak off each think")
	tf.revealed(-1);tf.spy_invisibility=false;s.tf_class="heavy";brain.goal_kind="capture";brain.enemy=1
	tf.cooldowns[-1]=0;bots.class_action(-1,brain)
	check(not tf.effects.has(-1),"Heavy does not slow a flag return with brace")
	s.tf_class="scout";brain.goal_kind="objective";brain.goal=Fixture.point(0,-16);brain.enemy=0
	bots.class_action(-1,brain);check(tf.effects.get(-1,{}).get("kind","")=="scout","Scout sprints on a long objective route")
	tf.effects.clear();tf.cooldowns[-1]=0;s.tf_class="demoman";brain.enemy=1;brain.visible=[1]
	tf.charges[-1]={"kind":"pipe","position":Fixture.point(0,12),"armed":0,"until":game.clock+20,"owner":-1,"team":0}
	bots.class_action(-1,brain);check(tf.charges.has(-1),"Demoman keeps a pipe until an enemy enters its blast radius")
	tf.charges[-1].position=game.fighters[1].position;bots.class_action(-1,brain)
	check(not tf.charges.has(-1),"Demoman detonates a pipe when an enemy enters a safe blast radius")
	game.match_mode.kind="dm";game.armory.select("ut99");s.owned=[2,10,11];s.ammo=[50,0,0,0]
	check(bots.choose_weapon(-1,12) in [2,10],"Extended weapon slots are safe and a translocator is not chosen as a gun")
	game.armory.select("doom")
	# Blocked and respawned bots must not retain combat/route input.
	game.match_mode.kind="dm";s.dead=true;s.fire=true;s.move=Vector2.ONE
	bots.tick(.016);check(not s.fire and s.move==Vector2.ZERO,"Dead bot input is cleared")
	s.dead=false;s.serial+=1;brain.enemy=1;bots.tick(.016)
	check(bots.brains[-1].serial==s.serial and bots.brains[-1].enemy==0,"Respawn/teleport invalidates old route and enemy memory")
	game.disconnect_game();game.free()
	print("BOT_TACTICS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
