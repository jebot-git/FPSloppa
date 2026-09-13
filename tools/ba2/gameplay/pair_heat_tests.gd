extends SceneTree
var g
var w
var r: Dictionary
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:checks.append({"pass":ok,"name":label});print("PASS " if ok else "FAIL ",label)
func fire_step(seconds: float) -> void:
 for i in ceili(seconds*60):g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
func reset_guns() -> void:
 r.heat=[0.,0.];r.overheated=[false,false];r.next=[0.,0.];r.last_fire=[-100.,-100.];r.scan_at=0.;r.ready=0.
 for pair in 2:
  var point: Vector3=g.match_mode.fortress.sentry_target_point(-1 if pair==0 else -3)-w.cannon_origin(r,pair*2)
  r.pitches[pair]=-atan2(point.y,Vector2(point.x,point.z).length())
func run() -> void:
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Linked heat tests",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 w=g.match_mode.fortress.walkers;w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}]);r=w.robots.test
 for id in g.players:
  var s: Dictionary=g.players[id];s.dead=false;s.spectator=id==-2;s.team=0 if id==1 else 1;s.hp=10000;s.armor=0;s.invulnerable=0.;s.input_blocked=false
  g.fighters[id].position=Vector3(1002.3362 if id==-1 else 997.6638,0,30)
 g.fighters[1].position=Vector3(1000,0,0);await physics_frame;await physics_frame
 check(w.try_board(1,"test"),"Fixture uses normal cockpit reservation")
 reset_guns();r.next[1]=g.clock+1000
 var hp: int=g.players[-1].hp;fire_step(.1)
 check(hp-g.players[-1].hp==24 and r.heat==[12.5,0.],"Two left barrel hits add exactly one shared volley heat charge")
 r.heat=[87.5,25.];r.overheated=[false,false];r.next[0]=0.;hp=g.players[-1].hp;fire_step(1./60.)
 check(hp-g.players[-1].hp==24 and r.heat[0]==100 and r.overheated[0],"Final volley fires both linked barrels before locking the pair")
 hp=g.players[-1].hp;fire_step(1)
 check(g.players[-1].hp==hp and absf(r.heat[0]-75.)<.01 and r.overheated[0],"A locked pair blocks both barrels and cools only once per tick")
 check(not r.overheated[1],"Left lock does not lock the right pair")
 r.targets=[0,0];g.players[-1].invulnerable=g.clock+10;g.players[-3].invulnerable=g.clock+10;fire_step(2.1)
 check(not r.overheated[0] and r.heat[0]<25.,"Shared lock clears at the restart threshold when fire is withheld")
 g.players[-1].invulnerable=0.;g.players[-3].invulnerable=0.;reset_guns();r.next[1]=g.clock+1000
 var origin: Vector3=w.cannon_origin(r,1);var target: Vector3=g.match_mode.fortress.sentry_target_point(-1)
 var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3.ONE*.25;shape.shape=box;wall.add_child(shape);g.add_child(wall);wall.position=origin+(target-origin).normalized()*.8
 await physics_frame;await physics_frame
 hp=g.players[-1].hp;fire_step(.1)
 check(hp-g.players[-1].hp==12 and r.heat[0]==12.5,"One covered barrel leaves the other firing against the same shared heat budget")
 r.heat[0]=100.;r.overheated[0]=true;r.next[0]=0.;hp=g.players[-1].hp;fire_step(.1)
 check(g.players[-1].hp==hp,"Covered and uncovered barrels both obey the shared overheat lock")
 wall.free();await physics_frame;reset_guns();r.heat=[100.,0.];r.overheated=[true,false]
 hp=g.players[-3].hp;fire_step(.1)
 check(hp-g.players[-3].hp==24 and r.heat[1]==12.5,"Right pair keeps firing while left vents")
 w.leave(1,true);r.heat=[50.,75.];fire_step(1)
 check(absf(r.heat[0]-25.)<.01 and absf(r.heat[1]-50.)<.01,"Unmanned robot cools each pair at 25 heat per second")
 var wire: Array=w.snapshot();check(wire[0].heat.size()==2 and wire[0].overheated.size()==2 and wire[0].next.size()==2,"Snapshot carries two heat reservoirs, locks and firing cycles")
 FileAccess.open("res://test-results/ba2/gameplay/pair-heat.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
 var ok: bool=checks.all(func(c):return c.pass)
 g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if ok else 1)
