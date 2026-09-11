extends SceneTree
const Fixture=preload('res://deathmatch/tests/fixture.gd')
const Saw=preload('res://deathmatch/chainsaw.gd')
var g
var failures: Array=[]
func check(ok: bool,label: String):
	print('PASS ' if ok else 'FAIL ',label)
	if not ok:failures.append(label)
func _initialize():call_deferred('run')
func prepare(mode: String='cc') -> void:
	g.intermission=0;g.match_mode.kind=mode;g.match_mode.friendly_fire=false;g.chainsaw.reset()
	for id in g.players:
		g._spawn(id);g.players[id].invulnerable=0;g.players[id].weapon=1;g.players[id].owned=[1];g.players[id].cooldown=0;g.players[id].yaw=0;g.players[id].pitch=0;g.players[id].xr={};g.players[id].team=-1
		g.fighters[id].position=Fixture.point(-15,15)
	g.fighters[1].position=Fixture.point()
func run() -> void:
	g=load('res://deathmatch/arena.tscn').instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host('Combat test',0,100,10,true,'cc');g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false)
	prepare();g.fighters[-1].position=Fixture.point(0,-.8);g.players[-1].weapon=2
	check(absf(Saw.blade(g,1)[0].distance_to(Saw.blade(g,1)[1])-.95)<.001,'CC blade reach is 0.95 metres from weapon pivot')
	g._fire(1)
	check(g.players[-1].hp<100,'An unguarded opponent within blade reach takes damage')
	prepare();g.fighters[-1].position=Fixture.point(0,-1.5);g.players[-1].weapon=2;g._fire(1)
	check(g.players[-1].hp==100,'CC chainsaw cannot damage targets beyond shortened reach')
	prepare();g.fighters[-1].position=Fixture.point(0,-.8);g.players[-1].yaw=PI;g._fire(1)
	check(g.players[-1].hp==100 and g.players[1].hp==100,'Facing chainsaws parry without dealing damage')
	check(g.players[1].cooldown>=.3 and g.players[-1].cooldown>=.3,'Parry applies the same recovery window to both players')
	check(g.chainsaw.contact_at.has(1) and g.chainsaw.contact_at.has(-1),'Parry produces one rate-limited contact cue for both blades')
	g._fire(-1);check(g.players[1].hp==100,'Parried opponent cannot damage on the same tick')
	prepare();g.fighters[-1].position=Fixture.point(0,-.8);g._fire(1)
	check(g.players[-1].hp<100,'A saw pointing away cannot automatically block a rear attack')
	prepare();g.fighters[-1].position=Fixture.point(0,-.8);g.players[-1].yaw=PI;g.players[-1].dead=true;g._fire(1)
	check(not g.chainsaw.contact_at.has(1),'Dead players do not leave parry colliders')
	prepare();var wall=Fixture.box(g,Fixture.point(0,-.4)+Vector3.UP*1.4,Vector3(2,2,.05));await physics_frame
	g.fighters[-1].position=Fixture.point(0,-.9);g.players[-1].yaw=PI;g._fire(1)
	check(g.players[-1].hp==100 and g.chainsaw.contact_at.has(1),'Wall contact blocks damage and requests grinding sparks')
	check(g.players[-1].cooldown==0,'Blades cannot parry through a thin wall')
	var first: float=g.chainsaw.contact_at[1];g.players[1].cooldown=0;g._fire(1)
	check(g.chainsaw.contact_at[1]==first,'Repeated contact in one instant does not spam effects')
	g.players[1].xr={"weapon":Transform3D(Basis.IDENTITY,Vector3(0,1.45,-.65))};g.players[1].cooldown=0;g._fire(1)
	check(g.players[-1].hp==100,'A tracked hand beyond a wall cannot bypass blade obstruction')
	var tracked_length: float=Saw.blade(g,1)[0].distance_to(Saw.blade(g,1)[1])
	check(tracked_length>.5 and tracked_length<.6,'Tracked saw contact follows the visible blade with only a small margin')
	var model:=Node3D.new();g.add_child(model);model.global_transform=g.Art.held_transform(Transform3D(Basis.IDENTITY,Fixture.point()+Vector3.UP*1.45),1)
	g.Art.clip_saw(model)
	check(model.to_global(g.Art.muzzle(1)).z>=Fixture.point(0,-.375).z,'Rendered saw retracts to the near side of a wall')
	model.free();wall.free();await physics_frame
	prepare('dm');check(absf(Saw.blade(g,1)[0].distance_to(Saw.blade(g,1)[1])-1.2)<.001,'Other modes retain 1.2 metre reach')
	# BFG gets broad radial coverage in addition to its existing forward spray.
	prepare('dm');g.fighters[1].position=Fixture.point(0,4);g.fighters[-1].position=Fixture.point(0,-6.5);g.fighters[-2].position=Fixture.point(-9.8,0);g.fighters[-3].position=Fixture.point(0,2)
	var center:=Fixture.point()+Vector3.UP*.85
	g._blast(center,1,g.W.BFG_SPLASH_DAMAGE,g.W.BFG_SPLASH_RADIUS,'BFG 9000')
	check(g.players[-1].hp<100,'BFG splash reaches targets beyond rocket blast radius')
	check(g.players[-2].hp==100,'BFG splash has a finite nine-metre radius')
	check(g.players[-3].dead,'BFG splash is lethal close to the explosion')
	check(g.players[1].hp==100,'BFG splash does not damage its owner')
	prepare('dm');g.fighters[-1].position=Fixture.point(12,0)
	g._blast(Fixture.point(8,0)+Vector3.UP*.85,1,200,9,'BFG 9000')
	check(g.players[-1].hp==100,'Solid walls block BFG splash')
	prepare('tdm');g.players[1].team=0;g.players[-1].team=0;g.fighters[-1].position=Fixture.point(0,-1)
	g._blast(center,1,200,9,'BFG 9000')
	check(g.players[-1].hp==100,'BFG splash respects friendly-fire policy')
	prepare('dm');g.fighters[1].position=Fixture.point(0,2);g._blast(center,1,128,5.76)
	check(g.players[1].hp<100 and g.fighters[1].blast_velocity.length()>0,'Rocket self-damage and rocket-jump impulse are preserved')
	prepare('dm');g.fighters[1].position=Fixture.point(0,4);g.fighters[-1].position=Fixture.point(0,6.5)
	g._projectile_spawn(9001,1,8,center,Vector3.RIGHT,0,0);g.projectiles[9001].life=0;g._update_projectiles(.001)
	check(g.players[-1].hp<100 and not g.projectiles.has(9001),'Actual BFG detonation invokes splash behind the shooter, outside the forward spray')
	g.disconnect_game();check(g.chainsaw.contact_at.is_empty(),'Disconnect releases contact throttle state')
	g.free();print('ULTIMATE_SAW_RESULT ',JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
