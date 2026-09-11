extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func run() -> void:
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.start_host("Fire test",0,20,10,true,"tf");game._add_player(-77,"Opponent")
 var tf=game.match_mode.fortress;var actor=game.fighters[1]
 game.players[1].team=0;game.players[1].invulnerable=0;game.players[1].dead=false;game.players[1].spectator=false;game.players[-77].team=1
 tf.ignite(1,-77);check(tf.burning(1),"Enemy flame marks player as burning")
 var snapshot: Dictionary=tf.snapshot();check(snapshot.burning.has(1) and snapshot.burning[1]<=3,"Burn duration is replicated without absolute server-clock dependence")
 game.headless=false;tf.draw();game.headless=true
 check(is_instance_valid(actor.fire_particles) and actor.fire_particles.emitting,"Burn creates visible flame particles on the affected avatar")
 for i in 10:actor.set_burning_visual(true)
 check(actor.find_children("BurningFlames","CPUParticles3D",false,false).size()==1,"Repeated snapshots reuse one bounded emitter")
 tf.burns.clear();tf.receive(snapshot);check(tf.burning(1),"Client snapshot restores burn presentation")
 game.clock+=3.1;check(not tf.burning(1),"Burn indicator expires if updates stop")
 game.headless=false;tf.draw();game.headless=true;check(actor.fire_particles==null,"Expired burn releases the emitter")
 tf.ignite(1,-77);tf.resupply(1,.5);check(not tf.burning(1),"Resupply immediately extinguishes the visual state")
 tf.ignite(1,-77);game.players[1].dead=true;check(not tf.burning(1),"Dead players have no burning indicator")
 game.players[1].dead=false;game.match_mode.kind="dm";check(not tf.burning(1),"Leaving TF removes the burning cue")
 game.free();await process_frame;await process_frame
 print("BURNING_FEEDBACK_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
