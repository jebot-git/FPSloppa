extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var results: Array=[]
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST ski chains",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Runner")
	# Two physically connected 20-degree hills; ordinary gravity supplies
	# the downhill speed before the bot must launch across the valley.
	var angle:=deg_to_rad(20);var span:=80.0
	for side in [-1,1]:
		var ramp=Fixture.box(g,Fixture.ORIGIN+Vector3(side*cos(angle)*span*.5,sin(angle)*span*.5,0),Vector3(span+1,1,45))
		ramp.rotation.z=side*angle
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame;await physics_frame
	var ai=g.bots;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	for armour in ["light","medium","heavy"]:
		s.team=0;s.dead=false;s.serial+=1;s.yaw=-PI/2;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.tribes.apply_equipment(-1,armour,[3,2,0],"energy")
		actor.position=Fixture.ORIGIN+Vector3(-65,65*tan(angle)+1,0);actor.velocity=Vector3.ZERO;actor.jump_held=false
		for frame in 20:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,s.yaw,false,1.0/60,false)
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=Fixture.ORIGIN+Vector3(65,65*tan(angle)+.6,0);b.goal_key="ski-chain";b.goal_kind="objective"
		b.path=PackedVector3Array([actor.position,Fixture.ORIGIN+Vector3(-40,40*tan(angle)+.6,0),Fixture.ORIGIN+Vector3(-16,16*tan(angle)+.6,0),Fixture.ORIGIN+Vector3(16,16*tan(angle)+.6,0),Fixture.ORIGIN+Vector3(40,40*tan(angle)+.6,0),b.goal]);b.step=0
		var peak:=0.0;var launches: Array=[];var elapsed:=0.0;var arrived:=false;var samples: Array=[]
		for frame in 1200:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			var grounded: bool=actor.is_supported();var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
			ai.tribes.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			peak=maxf(peak,Vector2(actor.velocity.x,actor.velocity.z).length())
			if grounded and not actor.is_supported() and (s.jump or s.jet_held):launches.append({"speed":speed,"x":actor.position.x-Fixture.ORIGIN.x,"energy":actor.tribes_state.energy})
			if frame%12==0:samples.append({"seconds":elapsed,"position":actor.position,"velocity":actor.velocity,"jet":s.jet_held,"ski":s.ski,"phase":b.get("travel_phase",""),"energy":actor.tribes_state.energy})
			if actor.position.distance_to(b.goal)<3:arrived=true;break
		var row:={"armour":armour,"arrived":arrived,"seconds":elapsed,"peak":peak,"launches":launches,"samples":samples};results.append(row)
		print("ST_SKI_CHAIN ",armour," arrived=",arrived," seconds=",elapsed," peak=",peak," launches=",launches)
	FileAccess.open("res://test-results/st-routing/ski-chain.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	g.disconnect_game();g.free();quit(0 if results.all(func(r):return r.arrived and r.launches.any(func(l):return l.speed>12)) else 1)
