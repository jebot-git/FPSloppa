extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Penetration=preload("res://deathmatch/counterstrike/penetration.gd")
var game
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func reset(weapon: int,lane: float,rules: String="cs16"):
	game.clock+=5;game.armory.select(rules);game.variant_combat.reset();game.intermission=0
	for id in game.players:
		game.players[id].merge({"weapon":weapon,"owned":range(12),"ammo":[300,300,300,300],"hp":5000,"armor":0,"dead":false,"spectator":false,"invulnerable":0,"cooldown":0.0,"fire":false,"held":false,"alt_fire":false,"reload":false,"input_blocked":false,"weapon_zoom":weapon==9,"last_input":game.clock,"yaw":-PI/2,"pitch":0.0,"vr_device":false,"xr":{},"team":0 if id==1 else 1},true)
		game.fighters[id].position=Fixture.point(-10,-10);game.fighters[id].velocity=Vector3.ZERO
	game.fighters[1].position=Fixture.point(-4,lane);game.fighters[-1].position=Fixture.point(1.6,lane)
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game);await physics_frame
	game.start_host("CS penetration",0,100,60,true,"dm","cs16");game.bots.free();game.bots=null;game.set_physics_process(false);game.set_process(false)
	var fixture:=Node3D.new();game.add_child(fixture)
	Fixture.box(game,Fixture.ORIGIN+Vector3(0,-.5,25),Vector3(40,1,100))
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/de-restoration/penetration-fixture.json"))
	var data: Dictionary=raw.data;var shift:=Fixture.ORIGIN
	for brush in data.static:
		for index in [0,1]:
			var value:=Penetration.v3(brush[index])+shift;brush[index]=[value.x,value.y,value.z]
		for plane in brush[2]:plane[3]+=Vector3(plane[0],plane[1],plane[2]).dot(shift)
	for branch in data.tree:
		for index in [0,1]:
			var value:=Penetration.v3(branch[index])+shift;branch[index]=[value.x,value.y,value.z]
	var faces:=PackedVector3Array()
	for box in raw.boxes:
		var mesh:=BoxMesh.new();mesh.size=Penetration.v3(box.size);var arrays:=mesh.get_mesh_arrays()
		for index in arrays[Mesh.ARRAY_INDEX]:faces.append(arrays[Mesh.ARRAY_VERTEX][index]+Penetration.v3(box.position)+shift)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var triangles:=ConcavePolygonShape3D.new();triangles.set_faces(faces);shape.shape=triangles;body.add_child(shape);fixture.add_child(body)
	var runtime=game.get_node("Map/MapRuntime")
	check(runtime.ballistics.configure(data,fixture),"Server binds exact authored fixture volumes")
	if OS.get_cmdline_user_args().has("--bsp-cover"):
		var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/de-restoration/bsp-cover.json"))
		var anchor:=Node3D.new();fixture.add_child(anchor);anchor.position=shift
		var backend=preload("res://deathmatch/counterstrike/bsp_penetration.gd").new()
		check(backend.configure(profile,anchor),"Compiled BSP point hull binds to independent collision fixture")
		runtime.ballistics.bsp_cover=backend
	await physics_frame;await physics_frame
	for row in [[6,0.0,true],[7,0.0,true],[8,0.0,true],[10,0.0,true],[9,0.0,true],
				[1,0.0,false],[2,0.0,false],[3,0.0,false],[4,0.0,false],[5,0.0,false],[11,0.0,false],
				[6,5.0,false],[6,10.0,true],[6,15.0,false],[6,20.0,true],[6,25.0,false],
				[6,30.0,true],[6,35.0,false],[9,35.0,true],[9,40.0,false]]:
		reset(row[0],row[1]);await physics_frame
		for settle in 8:
			game.fighters[1].simulate(Vector2.ZERO,-PI/2,true,1.0/60);await physics_frame
		var cs=game.variant_combat.cs;var before:int=game.players[1].ammo[game.armory.data(row[0]).ammo]
		check(cs.shoot(1),"Authoritative shot accepted: weapon "+str(row[0])+" lane "+str(row[1]))
		if (game.players[-1].hp<5000)!=row[2]:
			print("DEBUG ",row," hp=",game.players[-1].hp," solution=",game._shot_solution(1)," transform=",game._weapon_transform(1)," target=",game.fighters[-1].position)
		check((game.players[-1].hp<5000)==row[2],"Expected cover result: weapon "+str(row[0])+" lane "+str(row[1]))
		check(game.players[1].ammo[game.armory.data(row[0]).ammo]==before-1,"Penetration spends only one cartridge")
	reset(6,0);await physics_frame
	var start:=Fixture.point(-3.5,0)+Vector3.UP*1.0;var end:=Fixture.point(4,0)+Vector3.UP*1.0
	var hits: Array=runtime.ballistics.trace(game,start,end,1,0,6)
	check(hits.size()==2 and hits[0].id==0 and hits[1].id==-1 and is_equal_approx(float(hits[1].damage_scale),.6),"Wood retains 60 percent damage at the authoritative target")
	var head_start:=start+Vector3.UP*.55;var head_end:=end+Vector3.UP*.55
	hits=runtime.ballistics.trace(game,head_start,head_end,1,0,6)
	check(hits.size()==2 and hits[1].get("headshot",false),"Penetrated shot retains shared headshot classification")
	reset(2,0,"doom");await physics_frame
	var before:int=game.players[-1].hp;game._fire(1)
	check(game.players[-1].hp==before,"Non-CS hitscan still stops at the wall")
	reset(6,0);await physics_frame
	var space=game.get_world_3d().direct_space_state
	var entry: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
	var predicted: Dictionary=runtime.ballistics.exit_surface(entry.position,Vector3.RIGHT,39.0/32)
	check(not predicted.is_empty(),"Fixture provides an authored wood exit")
	if not predicted.is_empty():
		var obstruction=Fixture.box(fixture,predicted.position,Vector3(.2,.4,.4))
		await physics_frame;await physics_frame
		check(runtime.ballistics.exit_surface(entry.position,Vector3.RIGHT,39.0/32,space).is_empty(),"Collision extending beyond authored metadata blocks the exit")
		obstruction.free();await physics_frame
	reset(6,0);runtime.ballistics.ready=false;await physics_frame;game.variant_combat.cs.shoot(1)
	check(game.players[-1].hp==5000,"Maps without valid metadata retain wall blocking")
	var report:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var suffix:="-bsp" if OS.get_cmdline_user_args().has("--bsp-cover") else ""
	FileAccess.open("res://test-results/de-restoration/penetration-combat"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CS16_PENETRATION_RESULT ",JSON.stringify(report));game.free();quit(0 if failures.is_empty() else 1)
