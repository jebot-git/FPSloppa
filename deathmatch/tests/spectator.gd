extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Player",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	g._add_player(-4,"Observer",true)
	var s: Dictionary=g.players[-4]
	var actor=g.fighters[-4]
	check(s.spectator and s.dead and actor.collision_layer==0 and actor.collision_mask==0,"Spectator has no damage capsule or movement collision")
	g._accept_input(-4,{"seq":1,"move":Vector2(1,0),"fly":1.0,"yaw":0.0,"pitch":0.0,"fire":true,"offhand_fire":true,"melee":true,"weapon":2,"slow":false,"respawn":true,"spectator":false})
	check(s.spectator and not s.fire and not s.offhand_fire and not s.melee and not s.want_respawn,"Spectator cannot enable combat or become a player through input")
	actor.position=Fixture.point(9,0)
	g._server_tick(.5)
	check(actor.position.x>Fixture.ORIGIN.x+10.5 and actor.position.y>Fixture.ORIGIN.y+1.5,"Spectator flies vertically and through map collision")
	var before:Vector3=actor.position;g.clock+=1;g._server_tick(.1)
	check(actor.position==before,"Lost spectator input stops camera movement")
	g._damage(-4,1,1000,"test",true);g._fire(-4);g._fire(-4,true)
	check(s.hp==0 and s.shots==0 and s.deaths==0,"Spectator cannot receive damage or shoot")
	var pickup:Dictionary=g.pickups[0];pickup.available=true;actor.position=pickup.position
	g._collect(-4)
	check(pickup.available and s.ammo==[0,0,0,0],"Spectator cannot collect pickups")
	s.kills=1000;g._end_round()
	check(not g.round_message.contains("Observer"),"Spectators are excluded from winner selection")
	g._restart_round()
	check(s.spectator and s.dead and s.hp==0,"Round restart preserves spectator role")
	print("SPECTATOR_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
