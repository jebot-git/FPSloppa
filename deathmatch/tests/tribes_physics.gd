extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const T=preload("res://deathmatch/movement/tribes.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var actor
var checks:=0
var failures: Array=[]
var measurements: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func reset(at: Vector3=Vector3(0,.02,0)):
	actor.position=at;actor.velocity=Vector3.ZERO;actor.reset_tribes();actor.configure_tribes(true);actor.reset_view();actor.update_height(1.65,true)
	for i in 8:actor.simulate(Vector2.ZERO,0,false,1.0/60)
func step(seconds: float,wish: Vector2=Vector2.ZERO,jump: bool=false,hz: int=60):
	for i in roundi(seconds*hz):actor.simulate(wish,0,false,1.0/hz,jump)
func run():
	var world:=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(800,1,160))
	var ramp=Fixture.box(world,Vector3(0,30,200),Vector3(150,1,60));ramp.rotation.z=deg_to_rad(-20)
	Fixture.box(world,Vector3(40,8,0),Vector3(.02,16,80))
	actor=Fighter.new();actor.setup(1,"Tribes",Color.WHITE);actor.quake_movement=true;world.add_child(actor)
	await physics_frame;await physics_frame
	check(T.valid_state(T.fresh()),"Fresh Tribes state passes validation")
	for key in ["energy","airtime","time"]:
		var bad:=T.fresh();bad[key]=NAN;check(not T.valid_state(bad),"Non-finite "+key+" rejected")
	var bad:=T.fresh();bad.energy=61;check(not T.valid_state(bad),"Overfilled energy rejected")
	for hz in [30,60,120]:
		reset();actor.ski_held=true;actor.velocity=Vector3(0,0,-30);step(1.0,Vector2.ZERO,false,hz)
		check(absf(actor.velocity.z+30)<.1,"Ski preserves flat momentum at %d Hz"%hz)
		actor.ski_held=false;step(1.0,Vector2.ZERO,false,hz)
		check(actor.velocity.length()<.1,"Releasing ski brakes to a stop at %d Hz"%hz)
		reset(Vector3(0,100,0));actor.velocity=Vector3(0,0,-35);step(.5,Vector2.RIGHT,false,hz)
		check(absf(actor.velocity.x)<.001 and absf(actor.velocity.z+35)<.001,"No free air acceleration or forward speed clamp at %d Hz"%hz)
		reset();actor.jet_held=true;step(2,Vector2.ZERO,false,hz)
		check(actor.position.y>10 and actor.velocity.y>10,"Held jets produce sustained lift at %d Hz"%hz)
		check(absf(actor.tribes_state.energy-32)<.05,"Recharge and drain integrate in seconds at %d Hz"%hz)
		actor.jet_held=false;step(1,Vector2.ZERO,false,hz)
		check(absf(actor.tribes_state.energy-43)<.05 and not actor.tribes_state.jetting,"Released jets recharge without cooldown at %d Hz"%hz)
		measurements.append({"hz":hz,"energy_after_two_second_burn":32,"coasting_energy":actor.tribes_state.energy})
	reset(Vector3(0,100,0));actor.tribes_state.energy=.02;actor.jet_held=true;step(.1)
	check(actor.tribes_state.exhausted and not actor.tribes_state.jetting and actor.tribes_state.energy<3,"Empty pack cuts thrust until restart reserve recharges")
	actor.jet_held=false;step(6)
	check(actor.tribes_state.energy==T.MAX_ENERGY,"Recharge saturates at the energy capacity")
	reset();actor.jet_held=true;actor.ski_held=true;actor.configure_tribes(true,true);step(.3)
	check(not actor.tribes_state.jetting and not actor.tribes_state.skiing and actor.tribes_state.energy==60,"Menu block clears held actions without spending energy")
	actor.configure_tribes(true,false)
	reset();step(.5,Vector2.RIGHT)
	check(absf(actor.velocity.x-T.WALK_SPEED)<.1,"Walking reaches light-armour speed")
	reset();actor.ski_held=true;step(.25,Vector2.ZERO,true)
	var first_y: float=actor.position.y;step(1.5,Vector2.ZERO,true)
	check(first_y>1 and actor.position.y<.03,"Holding jump skis after landing without repeated vertical launches")
	var space:=world.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-45,90,200),Vector3(-45,0,200),1))
	reset(hit.position+Vector3.UP*.03);actor.ski_held=true;actor.velocity=Vector3(15,0,0).slide(hit.normal)
	var before: float=actor.velocity.length();step(1)
	check(actor.velocity.length()>before+4 and actor.position.x>-35,"Actual capsule gains downhill speed on a sloped surface")
	check(actor.tribes_state.grounded,"Ski keeps contact on a continuous downhill slope")
	reset(Vector3(0,5,0));actor.ski_held=true;actor.velocity=Vector3(100,0,0);step(.6)
	check(actor.position.x<39.72 and absf(actor.velocity.x)<.1,"100 m/s capsule cannot tunnel through a 2 cm wall")
	reset(Vector3(0,4,0));actor.ski_held=true;actor.velocity=Vector3(0,-20,-40);step(.3)
	check(absf(actor.velocity.z+40)<.1 and actor.position.y>=-.02,"Ski landing retains tangential momentum")
	actor.travel_path=[Vector3(-3,0,0),Vector3(3,0,0)];actor.position=Vector3(3,0,0)
	check(actor.touches(Vector3.ZERO,1.05),"Swept pickup contact catches a skipped endpoint")
	var reference:=T.fresh();reference.energy=40;actor.tribes_state.energy=33
	var authority:=reference.duplicate();authority.energy=38
	T.reconcile(actor,authority,reference)
	check(actor.tribes_state.energy==31,"Energy correction retains newer local consumption")
	actor.velocity=Vector3(80,20,0);actor.configure_tribes(false)
	check(actor.velocity==Vector3.ZERO and actor.tribes_state.energy==60 and not actor.ski_held,"Leaving Tribes clears momentum, energy and held ski state")
	reset();actor.jet_held=true;actor.tribes_state.energy=10;actor.show_alive(false,true)
	check(actor.tribes_state.energy==60 and not actor.jet_held,"Death clears flight and energy state")
	var result:={"checks":checks,"failures":failures,"measurements":measurements}
	DirAccess.make_dir_recursive_absolute("res://test-results/tribes")
	FileAccess.open("res://test-results/tribes/physics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TRIBES_PHYSICS ",JSON.stringify(result));world.free();quit(0 if failures.is_empty() else 1)
