extends SceneTree
const Hits=preload("res://deathmatch/hit_detection.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(is_finite(Hits.capsule_fraction(Vector3(.39,.9,2),Vector3(.39,.9,-2))),"Wider player capsule accepts edge hits")
	check(not is_finite(Hits.capsule_fraction(Vector3(.42,.9,2),Vector3(.42,.9,-2))),"Shots outside damage capsule still miss")
	check(Hits.capsule_fraction(Vector3(0,.9,0),Vector3(0,.9,-1))==0,"Starting inside target produces immediate impact")
	check(Hits.capsule_fraction(Vector3(0,.9,0),Vector3(0,.9,0))==0,"Stationary overlap is detected")
	check(not is_finite(Hits.capsule_fraction(Vector3(0,1.9,2),Vector3(0,1.9,-2))),"Shots over the head miss")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	Fixture.setup(g)
	g.start_host("Collision",0,100,60,true)
	g.bots.free();g.bots=null;g.set_physics_process(false)
	for id in g.players:
		g.players[id].invulnerable=0
		g.fighters[id].position=Fixture.point(0 if id==1 else 5,-3 if id==-1 else 8)
	g.fighters[-1].position=Fixture.point(.52,-3)
	var start:=Fixture.point()+Vector3.UP*.9
	var end:=start+Vector3(0,0,-6)
	check(g._trace(start,end,1).id==0,"Point trace misses outside capsule")
	check(g._trace(start,end,1,0,.16).id==-1,"Plasma edge clips target using its radius")
	g.fighters[-1].position=Fixture.point(1,-3)
	var previous={-1:{"position":Fixture.point(-1,-3),"serial":g.players[-1].serial}}
	check(g._trace(start,end,1,0,.16,previous).id==-1,"Swept relative motion catches target crossing within a tick")
	previous[-1].serial-=1
	check(g._trace(start,end,1,0,.16,previous).id==0,"Respawn does not sweep old life across projectile")
	g.fighters[-1].position=Fixture.point(1,-1)
	previous[-1]={"position":Fixture.point(-1,-1),"serial":g.players[-1].serial}
	check(g._trace(start,end,1,0,.16,previous).id==0,"Paths crossing at different times do not count as a hit")
	var wall=Fixture.box(g,Fixture.point(0,-2)+Vector3.UP,Vector3(2,2,.08))
	await physics_frame
	await physics_frame
	g.fighters[-1].position=Fixture.point(0,-3)
	var blocked: Dictionary=g._trace(start,end,1,0,.16)
	check(blocked.hit and blocked.id==0 and blocked.position.z>Fixture.point(0,-2).z+.16,"Swept projectile stops before thin wall")
	var overlap: Dictionary=g._trace(Fixture.point(0,-1.9)+Vector3.UP,end,1,0,.16)
	check(overlap.hit and overlap.id==0,"Projectile initially touching wall cannot tunnel out")
	wall.free()
	wall=Fixture.box(g,Fixture.point(.25,-3)+Vector3.UP,Vector3(.04,2,2))
	await physics_frame
	await physics_frame
	g.fighters[-1].position=Fixture.point(.5,-3)
	check(g._trace(start,end,1,0,.16).id==0,"Expanded capsule cannot reach through side cover")
	g.fighters[-1].position=Fixture.point(.35,-3)
	g.fighters[1].position=Fixture.point();g.players[1].weapon=9;g.players[1].yaw=0.0;g.players[1].pitch=0.0;g.players[1].cooldown=0.0
	var covered_hp: int=g.players[-1].hp
	g._fire(1)
	check(g.players[-1].hp==covered_hp,"Railgun cannot hit the part of a damage capsule extending through side cover")
	wall.free()
	await physics_frame
	g.fighters[-1].position=Fixture.point(1,-3)
	previous[-1]={"position":Fixture.point(-1,-3),"serial":g.players[-1].serial}
	g._projectile_spawn(999,1,7,start,Vector3.FORWARD,0,0)
	g.projectiles[999].fresh=false
	var hp: int=g.players[-1].hp
	g._update_projectiles(6.0/39.4,previous)
	check(g.players[-1].hp<hp and not g.projectiles.has(999),"Crossing target takes authoritative damage exactly once")
	for weapon in [6,7,8]:
		g.players[-1].hp=10000;g.players[-1].dead=false;g.players[-1].invulnerable=0
		g.fighters[-1].position=Fixture.point(1,-3)
		previous[-1]={"position":Fixture.point(-1,-3),"serial":g.players[-1].serial}
		g._projectile_spawn(1000+weapon,1,weapon,start,Vector3.FORWARD,0.0,0.0)
		g.projectiles[1000+weapon].fresh=false
		g._update_projectiles(6.0/g.W.DATA[weapon].speed,previous)
		var after: int=g.players[-1].hp
		g._update_projectiles(.1,previous)
		check(after<10000 and g.players[-1].hp==after and not g.projectiles.has(1000+weapon),"Weapon %d sweeps a crossing target and cannot deal duplicate damage"%weapon)
	g.free()
	print("HIT_DETECTION_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
