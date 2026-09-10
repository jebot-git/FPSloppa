extends SceneTree
const Grid=preload("res://deathmatch/projectile_targets.gd")
const Hits=preload("res://deathmatch/hit_detection.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var players: Dictionary={};var fighters: Dictionary={};var previous: Dictionary={}
	var rng:=RandomNumberGenerator.new();rng.seed=813991
	for i in range(32):
		var id:=32-i # Deliberately different insertion order from numeric IDs.
		players[id]={"dead":i%11==0,"spectator":i%13==0,"serial":2}
		var p:=Vector3(rng.randf_range(-30,30),rng.randf_range(-3,3),rng.randf_range(-30,30))
		fighters[id]={"position":p}
		previous[id]={"serial":1 if i%5==0 else 2,"position":p+Vector3(rng.randf_range(-10,10),0,rng.randf_range(-10,10))}
	var grid:=Grid.new();grid.build(players,fighters,previous)
	var missed:=0;var order_errors:=0;var culled:=0;var hits:=0
	for trial in range(12000):
		var start:=Vector3(rng.randf_range(-45,45),rng.randf_range(-5,5),rng.randf_range(-45,45))
		var end:=start+Vector3(rng.randf_range(-15,15),rng.randf_range(-2,2),rng.randf_range(-15,15))
		var radius:float=[0,.14,.16,.30][trial%4]
		# Include deliberate capsule crossings as well as mostly empty space.
		if trial%3==0:
			var aim:Vector3=fighters[grid.all_ids[trial%grid.all_ids.size()]].position+Vector3.UP
			start=aim+Vector3(0,0,3);end=aim-Vector3(0,0,3)
		var candidates:=grid.candidates(start,end,radius)
		culled+=grid.all_ids.size()-candidates.size()
		var rank:=-1
		for id in candidates:
			if grid.order[id]<=rank:order_errors+=1
			rank=grid.order[id]
		for id in players:
			if players[id].dead or players[id].spectator:continue
			var current:Vector3=fighters[id].position
			var old:Vector3=previous[id].position if previous[id].serial==players[id].serial and trial%2==0 else current
			if is_finite(Hits.capsule_fraction(start-old,end-current,Hits.PLAYER_RADIUS+radius)):
				hits+=1
				if not id in candidates:missed+=1
	check(hits>100 and missed==0,"12,000 swept queries retain every exact hit, including fresh shots and spawn changes")
	check(culled>12000*10,"Broad phase removes distant player candidates")
	check(order_errors==0,"Candidate lists preserve original hit tie order without duplicates")
	var edge_grid:=Grid.new();var boundary_misses:=0;var boundary_hits:=0
	for cell in [-250,-1,0,1,250]:
		var center:=Vector3(float(cell)*Grid.CELL_SIZE+Hits.PLAYER_RADIUS,0,0)
		edge_grid.build({1:{"dead":false,"spectator":false,"serial":1}},{1:{"position":center}},{})
		for radius in [0.0,.14,.16,.30]:
			for offset in [-.00001,0.0,.00001]:
				var start:=Vector3(float(cell)*Grid.CELL_SIZE-radius+offset,1,-2)
				var end:=start+Vector3(0,0,4)
				if is_finite(Hits.capsule_fraction(start-center,end-center,Hits.PLAYER_RADIUS+radius)):
					boundary_hits+=1
					if not 1 in edge_grid.candidates(start,end,radius):boundary_misses+=1
	check(boundary_hits>10 and boundary_misses==0,"Tangent hits survive positive and negative grid boundaries")
	previous[1]={"serial":players[1].serial,"position":Vector3(-10000,0,-10000)};grid.build(players,fighters,previous)
	check(grid.cells.size()<2048 and 1 in grid.overflow,"Huge player movement takes a bounded conservative fallback")
	check(grid.candidates(Vector3(-10000,0,0),Vector3(10000,0,0),.3)==grid.all_ids,"Huge projectile sweep falls back to all targets")
	previous[1].position=Vector3(1e30,0,0);grid.build(players,fighters,previous)
	check(1 in grid.overflow and grid.candidates(Vector3(-1e30,0,0),Vector3.ZERO,.3)==grid.all_ids,"Extreme finite coordinates cannot overflow grid cell conversion")
	check(grid.candidates(Vector3.INF,Vector3.ZERO,.3)==grid.all_ids,"Non-finite sweep uses conservative fallback")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	g.start_host("Broad-phase test",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	for id in g.players:g.players[id].invulnerable=0;g.fighters[id].position=Fixture.point(0,-3)
	var motion:={}
	for id in g.players:motion[id]={"position":g.fighters[id].position+Vector3.LEFT,"serial":g.players[id].serial}
	grid.build(g.players,g.fighters,motion)
	var mismatches:=0
	for i in range(300):
		var start:=Fixture.point()+Vector3(rng.randf_range(-2,2),rng.randf_range(.1,2),0)
		var end:=start+Vector3(0,0,-6)
		var full:Dictionary=g._trace(start,end,1,0,.16,motion)
		var fast:Dictionary=g._trace(start,end,1,0,.16,motion,grid.candidates(start,end,.16))
		if full!=fast:mismatches+=1
	check(mismatches==0,"Broad and full authoritative traces produce identical impacts and target IDs")
	g.disconnect_game();g.free();await process_frame
	print("PROJECTILE_TARGETS_RESULT ",JSON.stringify({"failures":failures,"exact_hits":hits,"missed_hits":missed,"culled_pairs":culled}));quit(0 if failures.is_empty() else 1)
