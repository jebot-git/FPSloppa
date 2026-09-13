extends SceneTree
const Steps=preload("res://deathmatch/vehicles/ba2/footsteps.gd")
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func sequence(hz: int) -> Array:
	var state=Steps.new();var hits: Array=[];state.advance(0,.8)
	for i in range(1,hz*12+1):
		var at:=float(i)/hz*.8;var foot: int=state.advance(at,.8)
		if foot>=0:hits.append(foot)
	return hits
func run() -> void:
	var state=Steps.new()
	check(state.advance(150,.8)==-1,"Joining a moving robot does not replay old stomps")
	check(state.advance(200,.8)==-1 and state.advance(0,0)==-1,"Large snapshot corrections and round resets stay silent")
	check(state.advance(0,0)==-1 and state.advance(.6,0)==-1,"Parked robot and stationary corrections emit no footsteps")
	state=Steps.new();state.advance(0,.8)
	check(state.advance(.503,.8)==-1 and state.advance(.505,.8)==0,"First stomp coincides with authored 20-percent swing touchdown")
	check(state.advance(.505,.8)==-1,"Repeated render frames cannot duplicate a contact")
	var normal:=sequence(60)
	check(normal.size()==15 and normal.slice(0,8)==[0,1,2,3,0,1,2,3],"Cruise cadence follows all four feet in authored order")
	check(sequence(20)==normal and sequence(144)==normal,"Snapshot and render rates do not change contact count/order")
	state=Steps.new();state.advance(0,.1)
	check(state.advance(.503,.1)==-1 and state.advance(.505,.1)==0,"Braking still emits contacts from actual travel")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
	if g.headless:g.headless=false;g.spatial.setup(g)
	g.presentation.spatial_audio="stereo";g.camera=g.get_node("Overview");g.camera.position=Vector3(0,30,0)
	for i in 3:
		var stream: AudioStreamWAV=load("res://deathmatch/audio/ba2/stomp_%d.res"%i)
		check(stream and not stream.stereo and stream.mix_rate==44100 and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and absf(stream.get_length()-1.45)<.001,"Stomp variant %d is a bounded mono one-shot"%i)
	g.spatial.play("ba2_stomp",Vector3(3,30,0),-3)
	var source: AudioStreamPlayer3D=g.spatial.active.back()
	check(source.playing and source.bus=="ArenaEffects" and source.unit_size==8 and source.max_distance==100,"Stomp uses the existing positional effects bus and 100 m distance limit")
	check(source.global_position==Vector3(3,30,0) and source.volume_db<=-3,"Sound is placed at the contact with conservative source gain")
	g.presentation.spatial_audio="steam_audio"
	g.spatial.play("ba2_stomp",Vector3(-3,30,0),-3)
	var binaural: AudioStreamPlayer3D=g.spatial.active.back()
	check(binaural.playing and (not g.spatial.steam.available or (binaural.has_method("play_stream") and binaural.get("min_attenuation_distance")==8)),"Stomp also uses the active Steam Audio backend with matching attenuation")
	g.spatial.clear();await process_frame
	check(g.spatial.active.is_empty(),"Map/audio reset clears in-flight stomps")
	g.free();await process_frame
	FileAccess.open("res://test-results/titanball/stomps.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cruise_contact_interval_seconds":.7875},"  "))
	print("BA2_STOMP_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
