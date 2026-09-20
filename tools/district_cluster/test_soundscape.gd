extends SceneTree
const Soundscape=preload("res://tools/district_cluster/soundscape.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frame(id: int,events: Array=[],enemy_position: Vector3=Vector3(20,0,0),hp: int=100,dead: bool=false) -> Dictionary:
	return {"sequence":id,"actors":[{"id":1,"position":Vector3.ZERO,"state":{"team":0,"hp":hp,"armor":0,"serial":1,"dead":dead}}, {"id":2,"position":enemy_position,"state":{"team":1,"hp":100,"dead":false}}],"events":events,"projectiles":[]}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var audio=Soundscape.new();root.add_child(audio);audio.set_process(false)
	var panel=preload("res://tools/district_cluster/cq_menu.gd").new();root.add_child(panel);panel.setup(audio)
	panel.find_child("MusicVolume",true,false).value=.25
	panel.find_child("AmbienceVolume",true,false).value=.4
	check(is_equal_approx(audio.music_volume,.25) and is_equal_approx(audio.ambience_volume,.4),"Independent volume controls")
	panel.join_button.pressed.emit();check(panel.join_button.disabled,"Join action did not disable duplicate clicks")
	panel.failed("Test");check(not panel.join_button.disabled,"Retry action remained disabled")
	panel.queue_free()
	audio.advance(.1);audio.advance(2)
	check(audio.state().music=="menu" and audio.state().music_gain>0,"Menu music did not start")
	audio.set_district("d00");audio.advance(4)
	check(audio.state().music=="" and not audio.state().combat,"Ambient-only entry")
	audio.observe(frame(1,[["_shot_fx",[2,2,false]]],Vector3(100,0,0)),1)
	check(not audio.state().combat,"Distant fighting started music")
	var friendly:=frame(2,[["_shot_fx",[2,2,false]]]);friendly.actors[1].state.team=0
	audio.observe(friendly,1);check(not audio.state().combat,"Unopposed allied target practice started music")
	audio.last_sequence=1
	audio.observe(frame(2,[["_shot_fx",[2,2,false]]]),1);audio.advance(.1);audio.advance(1)
	check(audio.state().combat and audio.state().music=="combat" and audio.state().music_gain>0,"Nearby combat did not start score")
	audio.advance(3);var before: float=audio.remaining;audio.observe(frame(2,[["_shot_fx",[2,2,false]]]),1)
	check(audio.remaining==before,"Repeated snapshot extended combat")
	audio.advance(20);audio.advance(4)
	check(not audio.state().combat and not audio.music.playing,"Combat music did not stop")
	audio.observe(frame(3,[["_shot_fx",[1,2,false]]]),1)
	check(audio.state().combat,"Own confirmed shot did not start combat")
	audio.observe(frame(4,[],Vector3(20,0,0),0,true),1);audio.advance(4)
	check(not audio.state().combat and audio.state().music=="","Death retained combat")
	audio.set_district("d40");audio.observe(frame(5,[["_shot_fx",[1,2,false]]]),1);audio.advance(2)
	check(audio.state().safe and not audio.state().combat,"Hub combat music")
	audio.set_district("");audio.combat();check(not audio.state().combat,"Waiting room combat music")
	for i in 81:
		audio.set_district("d%02d"%i);audio.advance(.08)
		check(audio.state().voices<=3,"Unbounded simultaneous streams")
		check(audio.cache.size()<=4,"Unbounded stream cache")
	audio.set_district("d01");audio.observe(frame(1),1);audio.observe(frame(2,[],Vector3(20,0,0),80),1)
	check(audio.state().combat,"Damage near enemy ignored")
	audio.set_district("d02");var incoming:=frame(1)
	incoming.projectiles=[{"owner":2,"position":Vector3(5,0,0)}];audio.observe(incoming,1)
	check(audio.state().combat,"Incoming enemy projectile ignored")
	audio.set_menu(true);audio.advance(4);audio.advance(2)
	check(audio.state().music=="menu" and not audio.state().combat,"Menu reset")
	print("CQ_AUDIO_TEST ",JSON.stringify({"failures":failures,"themes":audio.manifest.district_themes.size(),"tracks":audio.manifest.tracks.size(),"voices":audio.state().voices}))
	audio.queue_free();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
