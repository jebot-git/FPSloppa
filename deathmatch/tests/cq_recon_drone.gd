extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Recon=preload("res://deathmatch/conquest/classes/recon_drone.gd")
class TestArena extends Base:
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";return true
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func triangles(node:Node) -> int:
	var count:=0
	if node is MeshInstance3D:count+=node.mesh.get_faces().size()/3
	for child in node.get_children():count+=triangles(child)
	return count
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var path:=Recon.route(Vector3(10,70,20),Vector3(0,.5,-1),100)
	check(path.start==Vector3(10,0,100) and path.end==Vector3(10,0,-100),"Cardinal route spans opposite map edges on horizontal look bearing")
	var diagonal:=Recon.route(Vector3(90,0,-50),Vector3(1,0,1),100)
	check(diagonal.start.is_equal_approx(Vector3(40,0,-100)) and diagonal.end.is_equal_approx(Vector3(100,0,-40)),"Diagonal route enters and leaves the square map through the scout's line")
	check(Recon.route(Vector3.ZERO,Vector3.UP).is_empty() and Recon.route(Vector3(INF,0,0),Vector3.FORWARD).is_empty(),"Degenerate/nonfinite flight routes rejected")
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Recon",0,100,10,false);game._add_player(2,"Enemy");game._add_player(3,"Outside");game._add_player(4,"Friendly")
	game.classes.choose(1,"scout");game._spawn(1);game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].fire=false;game.players[1].alt_fire=false;game.players[1].xr={};game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[1].position=Vector3.ZERO
	var recon=game.recon_drone
	check(not recon.activate(1),"T1 utility cannot launch a drone")
	game.classes.award(1,7499)
	check(not game.classes.choose_utility(1,"scout","recon_drone"),"Drone remains locked below level 15")
	game.classes.award(1,1)
	check(game.classes.choose_utility(1,"scout","recon_drone") and game.classes.ensure(1).equipped_utility=="recon","Unlocked utility selection applies only at next spawn")
	game._spawn(1);game.players[1].input_blocked=false;game.fighters[1].position=Vector3.ZERO;game.players[1].yaw=0
	check(not game.classes.cloak(1) and not game.classes.cloaked(1),"Equipped drone replaces the scout cloak ability")
	check(recon.activate(1) and recon.flights.size()==1,"Authority launches one edge-to-edge flight")
	var flight:Dictionary=recon.flights.values()[0]
	check(is_equal_approx(flight.length,game.BattleMap.Landscape.EXTENT) and flight.direction.is_equal_approx(Vector3.FORWARD),"Flight follows the scout's horizontal view, not a random or player-controlled path")
	var ready:float=game.classes.states[1].drone_ready
	check(is_equal_approx(ready-game.clock,120) and not recon.activate(1),"Drone activation starts a two-minute cooldown and cannot be spammed")
	game._spawn(1);game.players[1].input_blocked=false
	check(not recon.activate(1) and game.classes.states[1].drone_ready==ready,"Respawn does not reset drone cooldown")
	game.players[2].team=1;game.players[3].team=1;game.players[4].team=0
	game.fighters[2].position=Vector3(100,0,0);game.fighters[3].position=Vector3(100.1,0,0);game.fighters[4].position=Vector3(0,0,0)
	# One large simulation step exercises continuous swept coverage between scans.
	game.clock=flight.at+flight.length/(2*Recon.SPEED);recon.tick()
	check(game.spotting.visible(game,1,2) and not game.spotting.visible(game,1,3),"Swept recon scan includes the 100 m boundary and excludes 100.1 m")
	check(recon.alerts.has(2) and not recon.alerts.has(3) and not recon.alerts.has(4),"Detection warning applies only to acquired enemies")
	var seq:int=recon.alerts[2].seq;game.clock+=.11;recon.tick()
	check(recon.alerts[2].seq==seq,"Continuous detection does not repeat the warning each scan")
	game.players[1].team=1;recon.alerts[1]={"seq":500,"life":game.players[1].serial,"until":game.clock+10}
	recon.notify_local();recon.notify_local()
	check(recon.warning_count==1,"Local detection warning is deduplicated across repeated snapshots")
	game.players[1].team=0
	game.classes.choose(2,"scout");game._spawn(2);game.fighters[2].position=Vector3(30,0,-10);game.classes.cloak(2);game.clock+=.11;recon.tick()
	check(game.classes.cloaked(2) and game.spotting.visible(game,1,2),"Drone detects cloaked enemies without changing their camouflage state")
	var snapshot:Dictionary=game.match_mode.snapshot()
	check(snapshot.has("crd:1") and snapshot.has("crw:2") and snapshot.has("crs:2"),"Flights, warnings and radar spotting have independent snapshot records")
	var replica:=Recon.new();game.add_child(replica);replica.setup(game)
	replica.receive({1:flight},{2:recon.alerts[2]},{2:recon.marks[2]},500)
	check(replica.flights[1].at==flight.at+500 and replica.alerts[2].until==recon.alerts[2].until+500 and replica.marks[2][0]==recon.marks[2][0]+500,"Client flight and detection deadlines preserve clock offsets")
	check(Recon.position(replica.flights[1],game.clock+500).is_equal_approx(Recon.position(flight,game.clock)),"Client animates the same flight position despite its clock offset")
	game.clock=flight.until+.11;recon.tick()
	check(recon.flights.is_empty() and recon.seen.is_empty(),"Completed pass removes its flight and scan tracking")
	game.clock+=10.1;recon.tick()
	check(not game.spotting.visible(game,1,2) and not recon.detected(2,0),"Recon spotting expires ten seconds after final detection")
	game.clock=ready-.001
	check(not recon.activate(1),"Cooldown remains active immediately before two minutes")
	game.clock=ready
	check(recon.activate(1),"Drone is ready at exactly two minutes")
	game.match_mode.reset()
	check(recon.flights.is_empty() and recon.alerts.is_empty() and recon.marks.is_empty(),"Round reset clears aircraft and old detection warnings")
	check(load("res://deathmatch/audio/recon/spotted.wav").get_length()>.5 and load("res://deathmatch/models/recon/fighter.glb")!=null,"Authored warning and procured model import successfully")
	var model:Node3D=load("res://deathmatch/models/recon/fighter.glb").instantiate()
	check(triangles(model)==116,"Converted recon fighter retains the source's 116-triangle budget")
	model.free()
	print("CQ_RECON_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
