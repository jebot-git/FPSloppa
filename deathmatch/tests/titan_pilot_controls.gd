extends SceneTree
const Controls=preload("res://deathmatch/vehicles/ba2/pilot_controls.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 var c:=Controls.new();c.begin(1);var centre:=Vector3(-.42,1.29,-.43)
 check(not c.sample(0,centre,centre,true,true,true)[0],"Boarding with grip held cannot acquire accidentally")
 c.sample(0,centre,centre,false,false,true)
 check(c.sample(0,centre,centre,true,true,true)==[true,Vector2.ZERO,true],"Fresh nearby grip acquires manual control and trigger")
 check(c.sample(0,centre+Vector3(.014,0,0),centre,true,false,true)[1]==Vector2.ZERO,"Relaxed 1.4 cm hand movement stays in neutral deadzone")
 var row:=c.sample(0,centre+Vector3(.08,0,0),centre,true,false,true)
 check(row[0] and row[1].is_equal_approx(Vector2.RIGHT) and not row[2],"Stick displacement aims without firing")
 check(c.sample(0,centre+Vector3(0,0,-.08),centre,true,false,true)[1]==Vector2.ZERO,"Left stick ignores fore/aft movement")
 c.sample(1,centre,centre,false,false,true);c.sample(1,centre,centre,true,false,true)
 check(c.sample(1,centre+Vector3(.08,0,0),centre,true,false,true)[1]==Vector2.ZERO,"Right stick ignores lateral movement")
 check(c.sample(1,centre+Vector3(0,0,-.08),centre,true,false,true)[1].is_equal_approx(Vector2.DOWN),"Right fore/aft movement supplies only elevation")
 check(not c.sample(0,centre,centre,true,true,false)[0],"Tracking loss drops manual control")
 check(not c.sample(0,centre,centre,true,true,true)[0],"Tracking recovery needs a new grip")
 c.sample(0,centre,centre,false,false,true);c.sample(0,centre,centre,true,true,true)
 check(not c.sample(0,centre+Vector3.ONE,centre,true,true,true)[0],"Pulling away releases the stick")
 check(Controls.validated([[true,Vector2(INF,0),true],[false,Vector2.ZERO,false]]).is_empty(),"Nonfinite network axes rejected")
 check(Controls.validated([[true,Vector2(10,10),true],[false,Vector2.ONE,true]])[1]==[false,Vector2.ZERO,false],"Released pair cannot retain fire or aim")
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Manual pilot test",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var w=g.match_mode.fortress.walkers
 w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}])
 var r: Dictionary=w.robots.test;var s: Dictionary=g.players[1]
 s.team=0;s.dead=false;s.input_blocked=false;s.spectator=false;s.invulnerable=0
 g.fighters[1].position=r.position;await physics_frame;await physics_frame
 check(w.try_board(1,"test"),"Authority grants the cockpit")
 s.last_input=g.clock;s.xr=preload("res://deathmatch/vr/poses.gd").neutral()
 s.xr.left.origin=centre;s.xr.right.origin=Vector3(.42,1.29,-.43);s.xr.weapon.origin=s.xr.right.origin
 var manual: Array=[[true,Vector2.ZERO,true],[true,Vector2.ZERO,false]]
 w.accept_controls(1,manual);check(w.manual_controls(r)==manual,"Mounted nearby hands accepted by authority")
 r.ready=0;r.next=[0.,0.];r.heat=[0.,0.];r.overheated=[false,false];r.pitches=[0.,0.];r.body_yaw=0.
 var before: float=g.clock;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(r.heat==[12.5,0.] and r.next[0]>before,"Manual left volley uses one linked heat meter and ordinary cooldown")
 w._tick_cannons(r,1./60.,w.bodies.test.get_rid());check(r.heat[0]==12.5,"Held trigger cannot bypass cooldown")
 r.next[0]=0.;r.heat[0]=87.5;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(r.heat[0]==100 and r.overheated[0],"Last manual volley fires before pair overheat locks")
 r.next[0]=0.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid());check(r.next[0]==0.,"Overheated pair cannot fire manually")
 w.accept_controls(1,[[true,Vector2.ONE,false],[true,Vector2.ZERO,false]])
 for i in 100:
  g.clock+=1./60.;s.last_input=g.clock;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(is_equal_approx(r.body_yaw,-w.CANNON_CONE) and r.pitches==[0.,0.],"Left stick steers lateral aim without changing elevation")
 var yaw:float=r.body_yaw
 w.accept_controls(1,[[false,Vector2.ZERO,false],[true,Vector2.ONE,false]])
 for i in 500:
  g.clock+=1./60.;s.last_input=g.clock;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(is_equal_approx(r.body_yaw,yaw) and is_equal_approx(r.pitches[0],w.PITCH_LIMIT) and is_equal_approx(r.pitches[1],w.PITCH_LIMIT),"Right stick forward lowers all cannons without changing lateral aim")
 check(r.manual==[true,true],"Either gripped stick overrides automatic aim for all cannons")
 var held_yaw:float=r.body_yaw;var held_pitch:Array=r.pitches.duplicate()
 w.accept_controls(1,[[true,Vector2.ZERO,false],[true,Vector2.ZERO,false]])
 for i in 120:
  g.clock+=1./60.;s.last_input=g.clock;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(is_equal_approx(r.body_yaw,held_yaw) and r.pitches==held_pitch,"Centered held sticks preserve the current aim without recentering")
 w.accept_controls(1,[[true,Vector2(-.25,0),false],[true,Vector2(0,-.25),false]])
 for i in 60:
  g.clock+=1./60.;s.last_input=g.clock;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(absf(r.body_yaw-held_yaw-deg_to_rad(1.5))<.001 and absf(r.pitches[0]-held_pitch[0]+deg_to_rad(1.5))<.001,"Small deflection makes a gradual correction instead of snapping to a new absolute angle")
 check(r.heat[0]==0. and not r.overheated[0],"Manual no-fire input cools and unlocks pair")
 g.clock+=.36;check(w.manual_controls(r).is_empty(),"Stale input relinquishes manual control")
 s.last_input=g.clock;s.xr.left.origin=Vector3(5,5,5);w.accept_controls(1,manual)
 check(not w.manual_controls(r)[0][0],"Hand far from console cannot claim manual control")
 w.accept_controls(1,[]);w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
 check(r.manual==[false,false],"Release restores automatic control for both pairs")
 s.input_blocked=true;w.accept_controls(1,manual);check(w.manual_controls(r).is_empty(),"Menu/focus block prevents manual firing")
 w.leave(1,true);s.input_blocked=false;w.accept_controls(1,manual)
 check(not s.has("pilot_controls"),"Dismounted player cannot control the cannons")
 g.disconnect_game();g.free();await process_frame
 print("TITAN_PILOT_CONTROLS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
