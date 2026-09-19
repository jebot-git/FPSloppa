extends "res://deathmatch/tests/fortress.gd"
func prepare(role_name: String,weapon: int) -> void:
	for id in g.projectiles.keys():g._projectile_end(id,g.projectiles[id].position,g.projectiles[id].weapon)
	role(1,role_name);g.players[1].weapon=weapon;g.players[1].yaw=0;g.players[1].pitch=0
	for id in g.players:
		g.players[id].hp=2000;g.players[id].armor=0;g.players[id].dead=false;g.players[id].spectator=false;g.players[id].invulnerable=0
		g.players[id].team=0 if id==1 else 1
		g.fighters[id].position=Fixture.point(15,15)
	g.fighters[1].position=Fixture.point(0,4);g.fighters[-1].position=Fixture.point()
func advance(seconds: float) -> void:
	for i in int(ceil(seconds*120)):g._update_projectiles(1.0/120)
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("TF arsenal",0,100,60,true,"tf");g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false);tf=g.match_mode.fortress
	var expected={"scout":[0,2,5],"sniper":[0,5,9],"soldier":[0,2,3,6],"demoman":[0,2,4],"medic":[0,2,3,7],"heavy":[0,2,3,7],"pyro":[0,2,6,7],"spy":[0,2,3,5],"engineer":[0,2,3]}
	for role_name in expected:
		role(1,role_name)
		check(g.players[1].owned==expected[role_name],role_name+": expected Quake TF weapon slots")
		for weapon in g.players[1].owned:
			var data: Dictionary=tf.weapon_data(1,weapon)
			check(data.ammo<0 or g.players[1].ammo[data.ammo]>=data.cost,role_name+": spawn has usable ammo for "+data.name)
	for row in [["scout",5,18,1],["medic",7,26,2]]:
		prepare(row[0],row[1]);var d: Dictionary=tf.weapon_data(1,row[1]);var ammo: int=g.players[1].ammo[0]
		check(d.spread==0 and d.vertical==0 and is_equal_approx(d.cycle,.1),d.name+": zero spread and ten shots per second")
		check(g.variant_combat.fire(1),d.name+": fires")
		check(g.players[-1].hp==2000 and g.projectiles.size()==1,d.name+": real travelling projectile")
		advance(.2)
		check(g.players[-1].hp==2000-row[2] and g.players[1].ammo[0]==ammo-row[3],d.name+": correct TF damage and ammo cost, one hit per projectile")
		prepare(row[0],row[1]);d=tf.weapon_data(1,row[1])
		for offset in [.49+d.radius-.005,.49+d.radius+.005]:
			g.players[-1].hp=2000
			var nail: int=g.variant_combat.launch(1,row[1],Fixture.point(offset,2)+Vector3.UP,Vector3.FORWARD)
			advance(.15)
			check((g.players[-1].hp<2000)==(offset<.49+d.radius),d.name+": collision edge at "+str(offset))
			if g.projectiles.has(nail):g._projectile_end(nail,g.projectiles[nail].position,row[1])
		g.players[-1].hp=2000;g.fighters[-1].position=Fixture.point(9,0)
		var old: Dictionary={-1:{"position":Fixture.point(-9,0),"serial":g.players[-1].serial,"height":1.65}}
		var nail: int=g.variant_combat.launch(1,row[1],Fixture.point(0,2)+Vector3.UP,Vector3.FORWARD)
		g.projectiles[nail].fresh=false;g._update_projectiles(.128,old)
		check(g.players[-1].hp==2000-row[2],d.name+": continuous sweep catches a target crossing between ticks")
		prepare(row[0],row[1]);g.fighters[-1].position=Fixture.point(12,0)
		g.variant_combat.launch(1,row[1],Fixture.point()+Vector3.UP,Vector3.RIGHT);advance(.5)
		check(g.players[-1].hp==2000,d.name+": solid wall blocks projectile damage")
	prepare("medic",7);g.players[1].ammo[0]=1
	g.variant_combat.fire(1);advance(.2)
	check(g.players[1].ammo[0]==0 and g.players[-1].hp==1982,"Super nailgun fires its final nail at normal TF nail damage")
	prepare("pyro",6);var cannon: Dictionary=tf.weapon_data(1,6)
	check(cannon.name=="INCENDIARY CANNON" and cannon.cost==3 and cannon.speed<g.armory.data(6).speed,"Pyro uses slower incendiary rockets at three rockets per shot")
	g.variant_combat.fire(1);advance(.3)
	check(g.players[-1].hp<=1970 and g.players[-1].hp>=1950 and tf.burning(-1),"Incendiary direct hit damages and ignites enemy")
	prepare("heavy",7);g.fighters[-1].position=Fixture.point(0,3)
	var shells: int=g.players[1].ammo[1];g.variant_combat.fire(1)
	check(g.projectiles.is_empty() and g.players[-1].hp<2000 and g.players[1].ammo[1]==shells-1,"Heavy assault cannon uses shell-fed hitscan pellets, not nails")
	prepare("engineer",2);g.fighters[-2].position=Fixture.point(0,-2)
	g.variant_combat.fire(1);advance(.3)
	check(g.players[-1].hp==1975 and g.players[-2].hp==1975,"Engineer rail projectile pierces two enemies once each")
	prepare("spy",2);g.variant_combat.fire(1);advance(.2)
	check(g.players[-1].hp==1980 and is_equal_approx(tf.speed(-1),tf.definition(-1).speed*.5),"Spy tranquilizer deals dart damage and slows target")
	var slow_state: Dictionary=tf.snapshot();tf.tranquilized.clear();tf.receive(slow_state)
	check(is_equal_approx(tf.speed(-1),tf.definition(-1).speed*.5),"Tranquilizer duration survives snapshot replication")
	g.clock+=5.01;check(is_equal_approx(tf.speed(-1),tf.definition(-1).speed),"Tranquilizer expires without permanently changing movement")
	prepare("sniper",9);g.players[1].alt_fire=true;g.players[1].fire=false;g.variant_combat.tick_input(1,.1)
	check(g.players[1].weapon_zoom and g.players[-1].hp==2000,"TF sniper alternate input zooms without firing")
	g.match_mode.kind="dm";g.armory.select("quake")
	check(g.armory.data(5).damage==9 and g.armory.data(7).damage==18,"Ordinary Quake retains original 9/18 nail damage")
	print("TF_ARSENAL_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
