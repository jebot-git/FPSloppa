extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Capture extends Node:
	var heard: Array=[]
	func play(kind: String,where: Vector3,volume: float=-8):heard.append([kind,where,volume])
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false);Fixture.setup(g)
	g.players[1]=g._new_state("Jumper",1);g._create_fighter(1);g.active=true
	var original=g.effects;var capture:=Capture.new();g.add_child(capture);g.effects=capture;g.headless=false
	var actor=g.fighters[1];actor.position=Fixture.point()+Vector3.UP*.03
	for i in 12:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	capture.heard.clear();g.demos.recording=true
	for i in 100:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(capture.heard.filter(func(e):return e[0]=="jump").size()==1,"Holding jump produces one accepted takeoff cue")
	check(capture.heard.filter(func(e):return e[0]=="land").size()==1,"Landing has one separate impact cue")
	check(g.demos.events.filter(func(e):return e[0]=="_movement_sound").size()==2,"Movement audio is recorded for demo playback")
	check(capture.heard[0][1].distance_to(Fixture.point()+Vector3.UP*.65)<.25,"Jump source is anchored to the jumper, not the listener")
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(capture.heard.filter(func(e):return e[0]=="jump").size()==2,"A fresh grounded press creates a new cue")
	var before:=capture.heard.size()
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(capture.heard.size()==before,"Airborne jump attempts are silent")
	g._movement_sound(g.map_epoch+1,1,0,"jump",Vector3.ZERO);g._movement_sound(g.map_epoch,1,-1,"jump",Vector3.ZERO)
	check(capture.heard.size()==before,"Old map and respawn events are discarded")
	g.players[1].spectator=true;g._fighter_movement_sound("jump",Vector3.ZERO,1)
	check(capture.heard.size()==before,"Spectators cannot emit jump cues")
	g.players[1].spectator=false;actor.in_water=true
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(capture.heard.size()==before,"Swimming does not trigger a grounded jump sound")
	g.players[1].dead=true
	g._movement_sound(g.map_epoch,1,int(g.players[1].serial)+1,"jump",Fixture.point())
	check(capture.heard.size()==before+1,"New spawn audio survives arrival before its state snapshot")
	g.players[1].dead=false
	for kind in ["jump","land","weapon_1","weapon_2","weapon_3","weapon_4","weapon_5","weapon_6","weapon_7","weapon_8","pickup_ammo","pickup_health","pickup_armor","pickup_weapon","pickup_mega"]:
		var sound=g.spatial.choose(kind)
		check(sound!=null and sound.get_length()>.1 and not sound.stereo,"Mono decoded SFX: "+kind)
	g.spatial.play("jump",Fixture.point(),-10)
	check(g.spatial.active.size()==1 and g.spatial.active[0].max_distance==28 and g.spatial.active[0].unit_size==3.5,"Jump uses bounded 3D distance attenuation")
	g.demos.recording=false;g.headless=true;g.effects=original;g.free();await process_frame
	print("MOVEMENT_AUDIO_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
