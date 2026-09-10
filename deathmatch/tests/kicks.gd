extends "res://deathmatch/tests/melee.gd"
func foot(z: float,side: String="left",height: float=.35,dt: float=.05,enabled: bool=true,shift: Vector3=Vector3.ZERO):
	g.clock+=dt;sequence+=1
	var pose:=Poses.neutral()
	for key in ["head","left","right","weapon"]:pose[key].origin+=shift
	pose.body={side+"_foot":Transform3D(Basis.IDENTITY,Vector3(0,height,z)+shift)}
	g._accept_input(1,{"seq":sequence,"move":Vector2.ZERO,"yaw":g.players[1].yaw,"pitch":0.0,"fire":false,"melee":enabled,"weapon":2,"slow":false,"respawn":false,"xr":pose})
	g._update_melee(1)
func kick(side: String="left"):
	foot(0,side);foot(-.15,side);foot(-.35,side);foot(-.55,side)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Kick test",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	await physics_frame;await physics_frame
	reset();kick()
	check(g.players[-1].hp==90 and g.players[1].ammo==[0,0,0,0],"Tracked foot sweep deals 10 melee damage without ammunition")
	for i in 25:foot(-.55)
	check(g.players[-1].hp==90,"Holding a foot against a player cannot repeatedly damage them")
	reset();kick();kick("right");strike()
	check(g.players[-1].hp==90,"Alternating feet and weapon whips share the same cooldown")
	reset();strike();kick()
	check(g.players[-1].hp==90,"A weapon whip prevents an immediate kick")
	reset();kick();g.clock+=.9;foot(0);kick("right")
	check(g.players[-1].hp==80,"A fresh kick can hit after the shared cooldown")
	reset();foot(0)
	for i in 10:foot(0,"left",.35,.05,true,Vector3(.03*i,0,0))
	g.players[1].yaw=PI/2;foot(0)
	check(g.players[-1].hp==100 and g.players[1].melee_ready_at==0,"Shared head/foot motion and snap turning cannot create kicks")
	reset();foot(0,"left",.05);foot(-.2,"left",.05);foot(-.5,"left",.05)
	check(g.players[-1].hp==100,"A foot sliding along the ground does not count as a kick")
	reset();foot(0);foot(-.6,"left",.35,.3)
	check(g.players[-1].hp==100,"Tracking gaps cannot produce a long foot sweep")
	reset();foot(0);foot(-.9)
	check(g.players[-1].hp==100,"Discontinuous tracking jumps cannot create kicks")
	reset();foot(0);foot(-.5,"left",.35,.05,false)
	check(g.players[-1].hp==100,"Menu or focus-disabled melee blocks kicks")
	reset();g.players[-1].invulnerable=g.clock+5;kick()
	check(g.players[-1].hp==100,"Kicks respect target spawn protection")
	reset();g.players[-1].armor=20;kick()
	check(g.players[-1].hp==93 and g.players[-1].armor==17,"Kicks use normal armor absorption")
	reset();g.players[1].dead=true;kick()
	check(g.players[-1].hp==100,"Dead players cannot kick")
	reset();g.match_mode.kind="cc";kick()
	check(g.players[-1].hp==100,"Chainsaw-only mode keeps physical melee disabled")
	g.match_mode.kind="dm";reset();g.players[-1].hp=10
	var kills: int=g.players[1].kills;kick()
	check(g.players[-1].dead and g.players[1].kills==kills+1,"Kick kills use normal frag accounting")
	reset();Fixture.box(g,Fixture.point(0,-.5)+Vector3.UP,Vector3(3,3,.1))
	await physics_frame;await physics_frame;kick()
	check(g.players[-1].hp==100,"Walls block tracked feet from damaging players through cover")
	print("KICKS_RESULT ",JSON.stringify(failures));g.disconnect_game("Kick checks complete");g.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
