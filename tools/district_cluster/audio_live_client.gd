extends "res://tools/district_cluster/desktop.gd"
## Real worker shot -> received snapshot -> score -> inactivity -> ambient-only.
func smoke() -> void:
	await create_timer(4).timeout
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if not have_eye or soundscape.state().music!="":push_error("Expected live ambient-only district");quit(4);return
	var recorder:=AudioEffectRecord.new();AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
	input_sequence+=1
	await request("input",{"generation":actor.generation,"command":{"seq":input_sequence,"move":[0,0],"yaw":yaw,"pitch":-1.2,"fire":true,"weapon":2}})
	await create_timer(.5).timeout
	input_sequence+=1
	await request("input",{"generation":actor.generation,"command":{"seq":input_sequence,"move":[0,0],"yaw":yaw,"pitch":-1.2,"fire":false,"weapon":2}})
	await create_timer(1.5).timeout
	var active: Dictionary=soundscape.state()
	if not active.combat or active.music!="combat" or active.music_gain<=0:push_error("Authoritative firing did not start CQ music");quit(4);return
	await create_timer(16).timeout
	var quiet: Dictionary=soundscape.state()
	if quiet.combat or quiet.music!="":push_error("CQ music did not return to ambience");quit(4);return
	recorder.set_recording_active(false);recorder.get_recording().save_to_wav(settings.audio_recording)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("CQ_LIVE_AUDIO ",JSON.stringify({"combat":active,"quiet":quiet,"authoritative_shot":true}))
	busy=true;await request("leave");await shutdown()
