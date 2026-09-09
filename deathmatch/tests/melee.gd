extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Melee=preload("res://deathmatch/melee.gd")
var g
var failures: Array=[]
var sequence:=0
var offhand:=false
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func reset():
	g.intermission=0;g.clock+=2;offhand=false
	for id in g.players:
		var s: Dictionary=g.players[id]
		s.hp=100;s.armor=0;s.dead=false;s.invulnerable=0;s.charge=0;s.cooldown=0;s.fire=false
		s.melee=false;s.melee_state={};s.melee_seq=-1;s.offhand_melee_state={};s.offhand_melee_seq=-1;s.xr={};s.vr_device=false;s.weapon=2;s.owned=range(9);s.ammo=[0,0,0,0]
		s.yaw=0;s.pitch=0;s.last_input=g.clock
	g.fighters[1].position=Fixture.point()
	g.fighters[-1].position=Fixture.point(0,-1)
	g.fighters[-2].position=Fixture.point(5,0)
func swing(x: float,dt: float=.05,enabled: bool=true,head_shift: Vector3=Vector3.ZERO,rotation: float=0.0):
	g.clock+=dt;sequence+=1
	var pose:=Poses.neutral()
	pose.head.origin+=head_shift
	pose.right=Transform3D(Basis(Vector3.UP,rotation),Vector3(x,1.1,-.6)+head_shift)
	pose.weapon=pose.right
	if offhand:
		pose.left=pose.right;pose.offhand_weapon=pose.left
		pose.right=Poses.neutral().right;pose.weapon=pose.right
	g._accept_input(1,{"seq":sequence,"move":Vector2.ZERO,"yaw":g.players[1].yaw,"pitch":0.0,"fire":false,"melee":enabled,"weapon":g.players[1].weapon,"slow":false,"respawn":false,"xr":pose})
	g._update_melee(1)
func strike():
	swing(-.8);swing(-.65);swing(-.45)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Melee test",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	await physics_frame
	await physics_frame
	reset();swing(-.8);swing(-.65)
	check(g.players[-1].hp==100,"Swing can start before the weapon reaches its target")
	swing(-.45)
	check(g.players[-1].hp==90 and g.players[1].ammo==[0,0,0,0],"Swept VR weapon hits later in the swing for 10 damage without ammo")
	for x in [-.3,-.15,0.0,.15]:swing(x)
	check(g.players[-1].hp==90,"One swing registers only one hit")
	swing(.15);swing(0.0);swing(-.15)
	check(g.players[-1].hp==90,"A second swing inside the cooldown cannot hit")
	swing(-.8,.9);swing(-.8);swing(-.65);swing(-.45)
	check(g.players[-1].hp==80,"A fresh deliberate swing can hit after cooldown")
	reset();offhand=true;strike()
	check(g.players[-1].hp==90,"Offhand pistol can whip without ammunition")
	offhand=false;strike()
	check(g.players[-1].hp==90,"Alternating pistols cannot bypass the shared melee cooldown")
	reset();swing(0.0)
	for i in range(25):swing(0.0)
	check(g.players[-1].hp==100,"Holding the weapon inside a target does no contact damage")
	reset();swing(0.0)
	for i in range(10):swing(0.0,.05,true,Vector3(.02*i,0,0))
	g.players[1].yaw=PI/2;swing(0.0)
	check(g.players[-1].hp==100 and not g.players[1].melee_state.has("ready_at"),"Shared head/hand motion and snap turn do not initiate a whip")
	reset();swing(-.8);swing(-.45,.3)
	check(g.players[-1].hp==100,"Stale tracking cannot create a sweep across a packet gap")
	reset();swing(-.8);swing(.2)
	check(g.players[-1].hp==100,"Discontinuous tracking jump is rejected")
	reset();swing(-.8);g.players[1].weapon=3;swing(-.45)
	check(g.players[-1].hp==100,"Changing weapons resets the tracked motion baseline")
	reset();swing(-.8);swing(-.45,.05,false)
	check(g.players[-1].hp==100,"Menu/focus-disabled melee cannot hit")
	reset();g.players[-1].invulnerable=g.clock+5;strike()
	check(g.players[-1].hp==100,"Weapon whip respects spawn protection")
	reset();g.players[-1].armor=20;strike()
	check(g.players[-1].hp==93 and g.players[-1].armor==17,"Weapon whip uses normal armor absorption")
	reset();g.players[1].dead=true;strike()
	check(g.players[-1].hp==100,"Dead attackers cannot whip")
	reset();g.intermission=5;strike()
	check(g.players[-1].hp==100,"Intermission blocks weapon whip")
	reset();g.players[1].charge=.5;strike()
	check(g.players[-1].hp==100,"Charging a BFG blocks simultaneous melee")
	reset();g.players[1].melee=true
	g._update_melee(1);g._update_melee(1)
	check(g.players[-1].hp==90 and g.players[1].ammo==[0,0,0,0],"Desktop bash hits with empty ammo and rejects immediate repeats")
	g.clock+=.81;g.players[1].last_input=g.clock;g._update_melee(1)
	check(g.players[-1].hp==80,"Desktop bash becomes available after 0.8 seconds")
	reset();g.players[1].melee=true;g.fighters[-1].position=Fixture.point(0,-2)
	g._update_melee(1)
	check(g.players[-1].hp==100,"Desktop bash has short reach")
	reset();g.players[1].melee=true;g.players[-1].hp=10
	var kills: int=g.players[1].kills
	g._update_melee(1)
	check(g.players[-1].dead and g.players[1].kills==kills+1,"Weapon whip kill uses normal frag/death accounting")
	reset();g.fighters[-2].position=g.fighters[-1].position;strike()
	check(g.players[-1].hp+g.players[-2].hp==190,"A swing cannot damage two overlapping targets")
	reset()
	Fixture.box(g,Fixture.point(0,-.5)+Vector3.UP,Vector3(3,3,.1))
	await physics_frame
	await physics_frame
	strike()
	check(g.players[-1].hp==100,"VR weapon clipped through a wall cannot damage the opponent")
	g.players[1].xr={};g.players[1].vr_device=false;g.players[1].melee_state={};g.players[1].melee=true
	g._update_melee(1)
	check(g.players[-1].hp==100,"Walls block desktop bash")
	print("MELEE_RESULT ",JSON.stringify({"failures":failures}))
	g.disconnect_game("Melee checks complete");g.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
