extends SceneTree
## A real ENet spectator. Capture only its viewport and its own Master bus.
class LateDirector extends Node:
	var session
	func _process(_delta):session.direct()
var g
var options: Dictionary
var overlay: Label
var encoder: Dictionary
var audio_record:=AudioEffectRecord.new()
var recording:=false
var started:=0
var frames:=0
var duplicates:=0
var max_frame_gap:=0.0
var last_capture:=0
var focus:=0
var focus_at:=-10.0
var shots: Array=[]
func _initialize():run.call_deferred()
func write_json(name: String,data):FileAccess.open(options.output+"/"+name,FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
func run():
	options=JSON.parse_string(OS.get_cmdline_user_args()[0])
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.title="DE LIVE · "+str(options.map).trim_prefix("de_").trim_suffix("_rebuilt").to_upper()
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_join("DE Live View","127.0.0.1",int(options.port),true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var timeout:=Time.get_ticks_msec()+90000
	while not g.active or g.players.size()<13 or g.match_mode.kind!="de":
		if Time.get_ticks_msec()>timeout:push_error("Spectator connection timeout");quit(1);return
		await process_frame
	g.menu_open=false;g.hud.hide();g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.unresizable=true
	var layer:=CanvasLayer.new();root.add_child(layer);layer.layer=100
	var background:=ColorRect.new();background.color=Color(0.025,0.035,0.05,.88);background.size=Vector2(1280,94);layer.add_child(background)
	overlay=Label.new();overlay.position=Vector2(20,10);overlay.add_theme_font_size_override("font_size",20);layer.add_child(overlay)
	var director:=LateDirector.new();director.session=self;director.process_priority=100;root.add_child(director)
	AudioServer.add_bus_effect(0,audio_record);audio_record.format=AudioStreamWAV.FORMAT_16_BITS
	encoder=OS.execute_with_pipe("/usr/bin/ffmpeg",["-loglevel","error","-y","-f","rawvideo","-pixel_format","rgb24","-video_size","1280x720","-framerate","30","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p","-movflags","+faststart",options.output+"/video-silent.mp4"],true)
	assert(encoder.has("stdio"));started=Time.get_ticks_usec();last_capture=started;audio_record.set_recording_active(true);recording=true
	RenderingServer.frame_post_draw.connect(capture)
	write_json("view-ready.json",{"map":g.current_map,"peer":g.multiplayer.get_unique_id(),"spectator":g.local_state().spectator,"encoder_pid":encoder.pid})
	print("DE_LIVE_VIEW_READY ",options.map)
	var finished_at:=0
	while g.active and Time.get_ticks_usec()-started<1800000000:
		if g.match_mode.defusal.phase=="finished" and finished_at==0:finished_at=Time.get_ticks_msec()
		if finished_at>0 and Time.get_ticks_msec()-finished_at>3500:break
		if options.get("smoke_seconds",0)>0 and Time.get_ticks_usec()-started>float(options.smoke_seconds)*1000000:break
		await process_frame
	recording=false;audio_record.set_recording_active(false);RenderingServer.frame_post_draw.disconnect(capture)
	var wav:=audio_record.get_recording();assert(wav and wav.save_to_wav(options.output+"/audio.wav")==OK)
	encoder.stdio.close()
	var encoding_deadline:=Time.get_ticks_msec()+30000
	while OS.is_process_running(encoder.pid) and Time.get_ticks_msec()<encoding_deadline:await create_timer(.1).timeout
	var complete: bool=g.match_mode.defusal.phase=="finished"
	write_json("view.json",{"completed":complete,"map":g.current_map,"spectator":g.local_state().spectator,"frames":frames,"seconds":frames/30.0,"duplicate_frames":duplicates,"max_frame_gap_seconds":max_frame_gap,"audio_seconds":wav.get_length(),"shots":shots,"real_time":true,"capture":"client viewport RGB stream and client-only Master audio"})
	print("DE_LIVE_VIEW_DONE ",options.map," frames=",frames)
	g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if complete or options.get("smoke_seconds",0)>0 else 1)
func capture():
	if not recording:return
	var now:=Time.get_ticks_usec();var wanted:=int((now-started)*30/1000000)+1
	if wanted<=frames:return
	var img:=root.get_texture().get_image()
	if img.get_size()!=Vector2i(1280,720):img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8);var data:=img.get_data()
	if frames==0:img.save_png(options.output+"/opening.png")
	if frames/900<wanted/900:img.save_png(options.output+"/live.png")
	max_frame_gap=maxf(max_frame_gap,(now-last_capture)/1000000.0);last_capture=now
	duplicates+=maxi(0,wanted-frames-1)
	while frames<wanted:
		if not encoder.stdio.store_buffer(data):recording=false;push_error("Video encoder write failed");quit(1);return
		frames+=1
func direct():
	if not is_instance_valid(g) or not g.active or not is_instance_valid(overlay):return
	var de=g.match_mode.defusal
	var alive: Array=g.players.keys().filter(func(id):return id<0 and not g.players[id].dead and not g.players[id].spectator and g.fighters.has(id));alive.sort()
	if not alive.is_empty() and (focus not in alive or g.clock-focus_at>8):
		focus=alive[int(g.clock/8)%alive.size()]
		if de.defuser in alive:focus=de.defuser
		elif de.carrier in alive and int(g.clock/8)%2==0:focus=de.carrier
		elif de.planted:
			var defenders: Array=alive.filter(func(id):return g.players[id].team!=de.attacking)
			defenders.sort_custom(func(a,b):return g.fighters[a].position.distance_squared_to(de.bomb_position)<g.fighters[b].position.distance_squared_to(de.bomb_position))
			if not defenders.is_empty():focus=defenders[0]
		focus_at=g.clock;shots.append({"time":g.clock,"player":focus,"round":de.round_id})
	if g.fighters.has(focus):
		var s: Dictionary=g.players[focus];var actor=g.fighters[focus];var eye: Vector3=actor.render_position()+Vector3.UP*actor.eye_height()
		var basis:=Basis(Vector3.UP,s.yaw);var target: Vector3=eye+basis*Vector3(1.8,1.3,3.4)
		var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,1))
		g.camera.global_position=hit.position+hit.normal*.25 if not hit.is_empty() else target;g.camera.look_at(eye-basis.z*5);g.camera.fov=85
	if is_instance_valid(g.viewmodel):g.viewmodel.hide()
	var counts: Array=[0,0]
	for id in alive:counts[g.players[id].team]+=1
	var watched: String=g.players[focus].name if g.players.has(focus) else "Overview"
	var name: String=str(options.map).trim_prefix("de_").trim_suffix("_rebuilt").to_upper()
	overlay.text="LIVE 6v6 · %s · ROUND %d / 6 · %s\nRED %d  :  %d BLUE     ALIVE %d : %d     RED: %s     %s\n%s"%[name,de.round_id,de.phase.to_upper(),g.match_mode.scores[0],g.match_mode.scores[1],counts[0],counts[1],"T" if de.attacking==0 else "CT",watched,"BOMB PLANTED · %.0fs"%maxf(0,de.fuse_end-g.clock) if de.planted and de.phase=="live" else de.message]
