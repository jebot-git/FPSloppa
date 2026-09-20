extends "res://tools/district_cluster/desktop.gd"
func smoke() -> void:
	await create_timer(3).timeout
	moderator.toggle()
	if not moderator.password.secret:push_error("Unmasked password");quit(4);return
	moderator.password.text=settings.moderator_test_password
	await moderator.login()
	await create_timer(.6).timeout
	if moderator.token.is_empty() or moderator.districts.item_count!=81 or not moderator.password.text.is_empty():push_error("Moderator UI login failed: "+moderator.message.text);quit(4);return
	var samples:=PackedByteArray();samples.resize(3200)
	for i in 1600:samples.encode_s16(i*2,int(sin(i*TAU*440/16000)*8000))
	var recorder:=AudioEffectRecord.new();AudioServer.add_bus_effect(0,recorder)
	soundscape.music_volume=0;soundscape.ambience_volume=0;await create_timer(.3).timeout
	recorder.set_recording_active(true)
	global_voice.receive({"id":1001,"name":"Network test", "stream":"test", "sequence":1,"pcm":Marshalls.raw_to_base64(samples)})
	await create_timer(.1).timeout
	if not global_voice.label.visible or soundscape.voice_duck!=.45:push_error("Global voice indication failed");quit(4);return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(settings.smoke_output)
	await create_timer(.25).timeout
	recorder.set_recording_active(false);recorder.get_recording().save_to_wav(settings.smoke_output.get_basename()+"-voice.wav");AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	await moderator.lock_menu()
	if not moderator.token.is_empty():quit(4);return
	var snapshot_reply:=await request("snapshot")
	var snapshot: Dictionary=bytes_to_var(Marshalls.base64_to_raw(snapshot_reply.result.payload))
	var a: Dictionary={};var b: Dictionary={}
	for row in snapshot.actors:
		if int(row.id)==1000:a=row
		if int(row.id)==1001:b=row
	if a.is_empty() or b.is_empty() or a.position.distance_to(b.position)>5.1 or a.state.hp!=100:push_error("Teleport landing invariant failed");quit(4);return
	print("CQ_MODERATOR_SMOKE ",JSON.stringify({"district":district,"distance":a.position.distance_to(b.position),"hp":a.state.hp,"masked_password":true,"lock":true,"global_voice_indicator":true}))
	busy=true;await request("leave")
	var rejoined:=await invoke({"op":"join","identity":identity.actor,"resume":identity.resume,"token":settings.token,"district":"d41","team":1})
	if rejoined.has("error"):push_error(str(rejoined.error));quit(4);return
	await follow(rejoined.result)
	var deployed:=await request("deploy")
	await follow(deployed.result);await create_timer(1).timeout
	var restored_reply:=await request("snapshot")
	var restored: Dictionary=bytes_to_var(Marshalls.base64_to_raw(restored_reply.result.payload))
	var distance:=999.0
	for row in restored.actors:
		if int(row.id)==1000:distance=row.position.distance_to(a.position)
	if distance>.15 or district!="d41":push_error("Saved location not restored: "+str(distance));quit(4);return
	print("CQ_LOCATION_RESTORED ",distance)
	await request("leave");await shutdown()
