extends SceneTree
const Capacity=preload("res://deathmatch/conquest/capacity.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
const State=preload("res://deathmatch/server/districts/state.gd")
class Gateway extends "res://deathmatch/server/districts/gateway.gd":
	var sent: Array=[]
	var failures: Array=[]
	func send(zone: int,message: Dictionary):sent.append({"zone":zone,"message":message.duplicate(true)})
	func need(_zone: int) -> bool:return true
	func fail(reason: String):failures.append(reason)
	func apply(row: Dictionary):game.players[row.id]=row.state.duplicate(true);game.fighters[row.id].position=row.position
var checks:=0
var failures: Array=[]
var g
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func actor(id: int,zone: int,dead: bool=false) -> Dictionary:
	return {"schema":State.SCHEMA,"id":id,"position":Rules.center(zone),"velocity":Vector3.ZERO,"body":{},"state":{"dead":dead,"team":0}}
func member(id: int,zone: int):
	g.owners[id]={"zone":zone,"generation":1,"phase":"active","ack":true,"last_seq":-1,"baseline":false}
	g.game.players[id]={"dead":false,"team":0};g.game.fighters[id]={"position":Rules.center(zone)}
func offer(id: int,target: int,respawn: bool=false):
	var zone: int=g.owners[id].zone
	g.handle(g.workers[zone].wire,{"kind":"offer","zone":zone,"epoch":1,"actor":actor(id,target),"target":target,"tx":str(id),"generation":g.owners[id].generation,"respawn":respawn})
func _initialize():run.call_deferred()
func run():
	g=Gateway.new();g.game={"map_epoch":1,"players":{},"fighters":{},"match_mode":{"conquest":{"rules":Rules.new()}}}
	for zone in 3:g.workers[zone]={"ready":true,"wire":RefCounted.new(),"last":0,"external":true,"pid":0}
	for i in 15:member(-i-1,1)
	member(-100,0);member(-101,0)
	check(Capacity.available(g.owners,1),"Fifteenth resident leaves one slot")
	offer(-100,1)
	check(Capacity.counts(g.owners)[1]==16 and g.owners[-100].phase=="preparing","First arrival reserves the sixteenth slot before commit")
	check(Capacity.counts(g.owners)[0]==2,"Source reservation remains until transfer commits")
	offer(-101,1)
	check(g.owners[-101].phase=="rolling_back" and g.sent[-1].message.kind=="rollback","Concurrent seventeenth arrival rolls back without stopping the match")
	g.progress(-100)
	g.handle(g.workers[1].wire,{"kind":"prepared","zone":1,"epoch":1,"tx":"-100"})
	g.handle(g.workers[1].wire,{"kind":"committed","zone":1,"epoch":1,"tx":"-100","actor":actor(-100,1)})
	check(Capacity.counts(g.owners)[0]==1 and Capacity.counts(g.owners)[1]==16,"Commit releases source while keeping destination at sixteen")
	g.handle(g.workers[0].wire,{"kind":"rolled_back","zone":0,"epoch":1,"tx":"-101","actor":actor(-101,0)})
	check(g.owners[-101].phase=="active" and g.owners[-101].zone==0,"Denied transfer resumes at source")
	g.game.players[-1].dead=true
	check(not Capacity.available(g.owners,1),"Death does not free a connected player's district slot")
	check(Capacity.available(g.owners,1,-1),"Resident may reuse its own slot for respawn in a full district")
	g.remove(-100)
	check(Capacity.available(g.owners,1),"Disconnect immediately releases reservation")
	member(-100,1)
	g.game.match_mode.conquest.rules.owners.fill(1);g.game.match_mode.conquest.rules.owners[1]=0
	g.handle(g.workers[0].wire,{"kind":"respawn_request","zone":0,"epoch":1,"id":-101,"generation":1,"actor":actor(-101,0,true)})
	check(g.owners[-101].phase=="spawn_wait" and g.owners[-101].zone==-1,"All friendly districts full: actor enters private waiting state")
	check(Capacity.counts(g.owners)[0]==0 and g.sent[-1].message.kind=="retire","Waiting player retires from source and releases its slot")
	var sent_before: int=g.sent.size()
	g.input(-101,{"seq":100,"cq_generation":g.owners[-101].generation});g.action(-101,"suicide")
	check(g.sent.size()==sent_before,"Waiting player cannot submit battle input or actions")
	g.remove(-100);member(-102,0);g.owners[-102].respawn_pending=true;g.respawn(-102)
	check(g.owners[-102].respawn_zone==1 and Capacity.counts(g.owners)[1]==16,"Respawn reserves newly freed friendly slot")
	check(g.sent[-1].message.kind=="respawn_grant" and g.sent[-1].message.target==1,"Master grants nearest friendly district with room")
	offer(-102,1,true)
	check(g.owners[-102].phase=="preparing" and Capacity.counts(g.owners)[1]==16,"Respawn transfer reuses its reservation without counting twice")
	member(-103,0);g.game.match_mode.conquest.rules.owners.fill(1);g.owners[-103].respawn_pending=true;g.respawn(-103)
	check(g.owners[-103].zone==-1 and g.owners[-103].phase=="spawn_wait","No controlled territory also puts reinforcements into waiting state")
	var owners: Dictionary={}
	for i in 16:owners[i+1]={"zone":1}
	var territories: Array=[];territories.resize(16);territories.fill(1);territories[1]=0;territories[4]=0
	check(Capacity.nearest(owners,territories,0,Rules.center(0))==4,"Respawn skips full nearest friendly district")
	owners[17]={"zone":0,"source":1,"respawn_zone":1}
	check(Capacity.claims(owners[17])==[0,1],"Duplicate source/respawn claims consume one slot per district")
	check(g.failures.is_empty(),"Capacity contention never fails the whole match")
	g.stop();g.free()
	await collision()
	print("CQ_CAPACITY_RULES ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func collision():
	var world:=Node3D.new();root.add_child(world)
	var client=preload("res://deathmatch/conquest/client.gd").new(world);client.enabled=true;client.zone=0
	var counts: Array=[];counts.resize(16);counts.fill(0);counts[1]=16
	client.capacity(counts,5)
	check(client.transit.get_child_count()==1,"Full neighbor creates authority/prediction collision barrier")
	var body:=CharacterBody3D.new();body.collision_layer=2;body.collision_mask=1;world.add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.5,1.65,.5);shape.shape=box;body.add_child(shape)
	body.position=Vector3(-251,1,-375)
	await physics_frame;await physics_frame
	body.move_and_collide(Vector3(2,0,0))
	check(body.position.x < -250.3,"Player cannot cross a disabled transit gate")
	counts[1]=15;client.capacity(counts,4)
	check(client.occupancy[1]==16,"Stale capacity update cannot reopen a full district")
	client.capacity(counts,6)
	await physics_frame;await physics_frame
	body.position=Vector3(-251,1,-375);body.move_and_collide(Vector3(2,0,0))
	check(body.position.x > -250,"Gate reopens when a slot clears")
	counts[1]=16;client.zone=1;client.capacity(counts,7)
	check(client.transit.get_child_count()==0,"Players can leave their full district toward a nonfull neighbor")
	client.reset();world.queue_free();await process_frame
