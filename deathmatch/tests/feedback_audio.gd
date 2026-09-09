extends SceneTree
var failures: Array=[]
class Capture extends Node:
	var events: Array=[]
	func play(kind: String,where: Vector3,volume: float=-8):events.append([kind,where,volume])
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var original=g.effects;var capture:=Capture.new();g.add_child(capture);g.effects=capture;g.headless=false
	g.pickups=[{"kind":"health","item":100,"available":false,"respawn":0,"position":Vector3.ONE},
		{"kind":"armor","item":2,"available":false,"respawn":0,"position":Vector3.LEFT},
		{"kind":"weapon","item":8,"available":false,"respawn":0,"position":Vector3.RIGHT},
		{"kind":"ammo","item":1,"available":false,"respawn":0,"position":Vector3.ZERO}]
	g._respawn_pickups();g._respawn_pickups()
	check(capture.events.size()==3 and capture.events.all(func(e):return e[0]=="power_spawn"),"Only powerful respawns play a cue, exactly once per availability transition")
	var heard: Array=[]
	for pair in [["ammo",0],["health",25],["armor",1],["weapon",6],["health",100]]:
		var kind:String=g.pickup_sound(pair[0],pair[1]);heard.append(kind)
		var sound=g.spatial.choose(kind)
		check(sound!=null and sound.get_length()>.1 and sound.get_length()<1.1,kind+" decodes as a short feedback cue")
	check(heard.size()==5 and heard.all(func(k):return heard.count(k)==1),"Pickup classes have distinct sound identities")
	for i in range(3):
		var sound=load("res://deathmatch/audio/recorded/pain_%d.wav"%i)
		check(sound.get_length()>.2 and sound.get_length()<.7,"Recorded pain variation %d is a short grunt"%i)
	check(g.spatial.choose("spawn").get_length()>.5 and g.spatial.choose("power_spawn").get_length()>1,"Player and powerful-item spawns use distinct full cues")
	for pickup in g.pickups:
		var art=g._pickup_art(pickup)
		check((art.get_node_or_null("PowerHalo")!=null)==g.powerful_pickup(pickup.kind,pickup.item),"Only powerful pickups have the floating halo")
	g.effects=original;g.headless=true;g.free()
	print("FEEDBACK_AUDIO_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
