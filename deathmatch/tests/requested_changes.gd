extends SceneTree
const Body=preload("res://deathmatch/vr/body_basis.gd")
var game
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 for yaw in [PI/2,PI,-PI/2,-PI+.01]:
  var pose:={"head":Transform3D(Basis(Vector3.UP,yaw),Vector3(0,1.65,0))}
  check(absf(angle_difference(Body.head_yaw(pose),yaw))<.001,"Physical head turn follows body: "+str(yaw))
  pose.body={"hips":Transform3D.IDENTITY}
  check(Body.head_yaw(pose)==0,"Tracked hips retain their own orientation")
 check(Body.head_yaw({"head":Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO)},.7)==.7,"Vertical gaze preserves last heading")
 var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
 var actor:=Node3D.new();root.add_child(actor);actor.rotation.y=.6
 var avatar=library.create_avatar("9adf1b44e959d2688d62c2dd558e74315d6aa40e3bf8d281390b7a85dc0df9b7")
 actor.add_child(avatar);avatar.process_mode=Node.PROCESS_MODE_DISABLED
 var pose:=preload("res://deathmatch/vr/poses.gd").neutral();pose.head.basis=Basis(Vector3.UP,PI)
 avatar.target_xr_pose=pose
 for first_person in [false,true]:
  avatar.first_person=first_person
  avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
  check(avatar.global_basis.z.dot((actor.global_basis*pose.head.basis).z)>.999,"Loaded avatar body follows physical 180-degree turn, first_person="+str(first_person))
  check((avatar.tracking_transform()*avatar.xr_pose.left).is_equal_approx(actor.global_transform*pose.left),"Hand targets retain the tracking frame")
 avatar.target_xr_pose=pose.duplicate(true);avatar.target_xr_pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.9,0))}
 avatar._process(.016)
 check(avatar.global_basis.z.dot(actor.global_basis.z)>.999,"Tracked hips supersede head-derived avatar yaw")
 actor.free();library.free()
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Changes",0,100,10,true,"tb","quake");game.set_physics_process(false);game.set_process(false)
 var w=game.match_mode.fortress.walkers
 w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}])
 game.players[1].team=0;game.fighters[1].position=Vector3(1000,0,0)
 await physics_frame;await physics_frame
 check(w.try_board(1,"test"),"Human test pilot boards Titan")
 var s: Dictionary=game.players[-1];s.team=1;s.owned=[0,2,7];s.ammo=[100,100,100,100];s.tf_class="scout"
 check(not game.bots.can_engage(-1,1),"Scout ignores immune Titan even with ordinary super nailgun")
 s.tf_class="heavy"
 check(game.bots.can_engage(-1,1) and game.bots.choose_weapon(-1,20,1)==7,"Heavy selects its hull-damaging assault cannon")
 s.tf_class="pyro"
 check(not game.bots.can_engage(-1,1),"Pyro flamethrower cannot engage Titan")
 s.tf_class="soldier";s.owned=[0,2,6];s.weapon=2
 check(game.bots.can_engage(-1,1) and game.bots.choose_weapon(-1,20,1)==6,"Soldier switches from shotgun to rockets against Titan")
 s.ammo=[0,100,0,100]
 check(not game.bots.can_engage(-1,1),"Empty heavy weapon cannot sustain Titan engagement")
 var brain: Dictionary=game.bots.new_brain(-1);brain.enemy=1;brain.remembered_enemy=1;s.fire=true
 game.bots.combat(-1,brain,.016)
 check(brain.enemy==0 and not s.fire,"Combat drops remembered immune target immediately")
 w.leave(1,true)
 check(game.bots.can_engage(-1,1),"Bot resumes engaging dismounted pilot with light weapons")
 game.dedicated=true;game.max_clients=8
 var rcon=preload("res://deathmatch/server/rcon.gd").new();rcon.game=game
 for invalid in ["bots -1","bots 9","bots 2.5","bots","bots 1 extra"]:check(rcon.execute(invalid).has("error"),"RCON rejects "+invalid)
 check(rcon.execute("bots 5").get("ok",false) and game.players.size()==6,"RCON creates five bots alongside the human")
 check(rcon.execute("bots 2").get("ok",false) and game.players.size()==3,"RCON decreases live bot count")
 check(game._rotate_map(game.current_map) and game.players.size()==2 and game.bot_population.count_target==2,"RCON bot count survives dedicated map reload")
 game._add_player(1,"Human fixture");game.bot_population.maintain()
 game._add_player(42,"Second human");game.bot_population.maintain()
 check(game.players.size()==4 and game.players.keys().filter(func(id):return id<0).size()==2,"New human does not reduce explicit bot count when capacity permits")
 game._peer_left(42)
 check(rcon.execute("bots 8").get("ok",false) and game.players.size()==8,"Explicit bot count respects capacity and preserves human")
 check(rcon.execute("bots 0").get("ok",false) and game.players.keys()==[1],"RCON removes bots and preserves human")
 rcon.free();game.disconnect_game();game.free();await process_frame
 print("REQUESTED_CHANGES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
