extends SceneTree
var g
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,title: String) -> void:checks.append({"pass":ok,"name":title});print("PASS " if ok else "FAIL ",title)
func step(seconds: float) -> void:
 for i in ceili(seconds*60):await physics_frame;g._physics_process(1./60.)
func run() -> void:
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="tb_ashfall";g.start_host("TB objective regression",0,100,10,true,"tb")
 g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true;g._spawn(1)
 for id in [-1,-3]:g.players[id].team=0;g._spawn(id)
 g.players[-2].team=1;g._spawn(-2)
 for i in 120:await physics_frame
 var w=g.match_mode.fortress.walkers;var r: Dictionary=w.robots.values()[0];var ai=g.bots
 g.fighters[-1].position=Vector3(.7,0,0);g.fighters[-3].position=Vector3(3,0,-1);g.fighters[-2].position=Vector3(0,0,250)
 ai.brains.clear();await step(3)
 var pilot: int=r.pilot
 check(pilot in [-1,-3],"An attacker reaches the ladder and boards through normal bot input")
 check(r.distance==0 and g.match_mode.titanball.preparing(),"Piloted bot waits behind the preparation gate")
 check(w.mounted(pilot) and not g.players[pilot].jump and not g.players[pilot].fire and g.players[pilot].weapon==0,"Pilot holds the objective without jumping out or firing a personal weapon")
 check(ai.brains[-2].goal_key.begins_with("tb:"),"Defender chooses a payload interception objective")
 var replacement: int=-3 if pilot==-1 else -1
 g.players[replacement].dead=false;g.players[replacement].hp=150;g.fighters[replacement].position=Vector3(1,0,0)
 g._damage(pilot,-2,100000,"TEST",true)
 await step(4)
 check(r.pilot==replacement,"Surviving attacker replaces a killed pilot without scripted boarding")
 g.match_mode.titanball.advance_time(60.);await step(3)
 check(r.distance>0.5,"Replacement pilot advances the robot after preparation")
 var centre: Vector3=w.transform(r)*w.CRUSH_OFFSET
 g.fighters[-2].position=centre+Vector3(4,0,0)
 var brain: Dictionary=ai.brains[-2];brain.goal=centre-Vector3(10,0,0)
 var escape: Vector3=ai.titanball.steering(-2,brain,Vector3.LEFT)
 check(escape.x>0,"Ground defender steers out of the moving foot envelope")
 g.fighters[-2].position=centre+Vector3(4,4,0)
 check(ai.titanball.steering(-2,brain,Vector3.LEFT)==Vector3.LEFT,"Elevated defender can hold a safe overpass position")
 g.match_mode.kind="dm"
 check(ai.titanball.steering(-2,brain,Vector3.LEFT)==Vector3.LEFT,"Other modes retain ordinary steering")
 check(not ai.titanball.pilot_input(replacement,brain),"Other modes do not inherit payload bot controls")
 FileAccess.open("res://test-results/titanball/simulation/objective-tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
 var success: bool=checks.all(func(c):return c.pass)
 g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if success else 1)
