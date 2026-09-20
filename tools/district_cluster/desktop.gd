class_name CQDesktop
extends SceneTree
## Separate experimental desktop client for the regional protocol. Authoritative
## movement snapshots; deliberately no claim of shipping-client prediction parity.
const Rules=preload("res://deathmatch/conquest/rules.gd")
var edge
var replies: Dictionary={}
var request_id:=0
var input_sequence:=0
var settings: Dictionary
var auth: Dictionary={}
var actor: Dictionary={}
var status: Dictionary={}
var world:=Node3D.new()
var camera:=Camera3D.new()
var label:=Label.new()
var level: Node3D
var address: Array=[]
var district:=""
var busy:=false
var yaw:=0.0
var pitch:=0.0
var target_eye:=Vector3.ZERO
var have_eye:=false
var bodies: Dictionary={}
var last_travel:=0
var health:=100
var weapon:=2
var identity: Dictionary={}
var avatars
var avatar_hashes: Dictionary={}
var soundscape
var main_menu
var moderator
var global_voice
class Controls extends Node:
	var client
	func _input(event: InputEvent) -> void:client.handle_input(event)
func _initialize() -> void:run.call_deferred()
func invoke(body: Dictionary) -> Dictionary:
	request_id+=1;var id:=request_id;edge.request(id,body)
	var deadline:=Time.get_ticks_msec()+6500
	while not replies.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	if not replies.has(id):return {"error":"Regional request timed out"}
	var result: Dictionary=replies[id];replies.erase(id);return result
func request(op: String,extra: Dictionary={}) -> Dictionary:
	var body:=auth.duplicate();body.op=op;body.merge(extra);return await invoke(body)
func connect_region(next: Array) -> bool:
	address=next
	if edge.connect_gateway(address)!=OK:return false
	var deadline:=Time.get_ticks_msec()+5000
	while edge.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:await process_frame
	return edge.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
func follow(result: Dictionary) -> void:
	if result.has("actor") and int(result.actor.get("generation",0))!=int(actor.get("generation",0)):have_eye=false
	if result.has("actor"):actor=result.actor
	var destination: Array=result.get("gateway",result.get("redirect",address))
	if destination!=address:
		if not await connect_region(destination):label.text="Gateway unavailable";return
		var resumed:=await request("resume")
		if resumed.has("result"):
			if resumed.result.has("redirect"):await follow(resumed.result);return
			actor=resumed.result
	await load_district()
func load_district() -> void:
	var next: String=actor.get("district","") if actor.get("district")!=null else ""
	if next==district and is_instance_valid(level):return
	district=next;have_eye=false
	if is_instance_valid(soundscape):soundscape.set_district(district)
	for body in bodies.values():body.free()
	bodies.clear()
	if is_instance_valid(level):level.free()
	if district.is_empty():
		level=Node3D.new();world.add_child(level)
		var builder:=preload("res://deathmatch/server/cluster/campaign_visuals.gd").new();level.add_child(builder)
		builder.box_at("Floor",Vector3(0,-.1,0),Vector3(12,.2,12),Color(.09,.12,.18))
		for p in [Vector3(0,2,-6),Vector3(-6,2,0),Vector3(6,2,0)]:builder.box_at("Wall"+str(p),p,Vector3(12 if p.z!=0 else .2,4,.2 if p.z!=0 else 12),Color(.05,.07,.11))
		builder.label_at("Waiting","REINFORCEMENT RESERVE\nWaiting for an allied or neutral district slot",Vector3(0,2,-4),32)
		camera.position=Vector3(0,1.7,3);camera.rotation=Vector3.ZERO;return
	label.text="Loading "+district
	var path:="res://maps/CampaignDistricts/district_%02d/presentation.scn"%int(district.substr(1))
	if ResourceLoader.load_threaded_request(path)!=OK:label.text="Missing campaign map "+district;return
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await process_frame
	var packed=ResourceLoader.load_threaded_get(path)
	if not packed is PackedScene:label.text="Invalid campaign map";return
	level=packed.instantiate();world.add_child(level)
	preload("res://deathmatch/conquest/presentation.gd").apply(world)
	last_travel=Time.get_ticks_msec()
func run() -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":push_error("Campaign desktop requires Vulkan");quit(2);return
	var args:=OS.get_cmdline_user_args()
	var config_path: String=args[0] if not args.is_empty() else OS.get_executable_path().get_base_dir().path_join("client.json")
	if not FileAccess.file_exists(config_path):
		var dialog:=FileDialog.new();dialog.title="Select the CQ client JSON supplied by your server administrator";dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.json ; CQ client configuration"]);dialog.use_native_dialog=true;root.add_child(dialog);dialog.canceled.connect(func():quit());dialog.popup_centered_ratio(.65)
		config_path=await dialog.file_selected;dialog.queue_free()
	var parsed_settings=JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed_settings is Dictionary:push_error("Invalid CQ client configuration");quit(2);return
	settings=parsed_settings
	if not settings is Dictionary:push_error("Invalid CQ client configuration");quit(2);return
	var identity_path: String=settings.get("identity_file","user://cq_identity_"+str(settings.get("campaign_id",str(settings.get("token","")).sha256_text().substr(0,16)))+".json")
	if FileAccess.file_exists(identity_path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(identity_path))
		if not parsed is Dictionary:push_error("Invalid saved CQ identity");quit(2);return
		identity=parsed
	else:
		identity={"actor":Crypto.new().generate_random_bytes(16).hex_encode(),"resume":Crypto.new().generate_random_bytes(32).hex_encode()}
		var saved:=FileAccess.open(identity_path,FileAccess.WRITE)
		if saved==null:push_error("Cannot save persistent CQ identity");quit(2);return
		saved.store_string(JSON.stringify(identity));saved.close()
		FileAccess.set_unix_permissions(identity_path,FileAccess.UNIX_READ_OWNER|FileAccess.UNIX_WRITE_OWNER)
	if not identity is Dictionary or not identity.has_all(["actor","resume"]):push_error("Invalid saved CQ identity");quit(2);return
	root.add_child(world);world.add_child(camera);camera.current=true;camera.far=400;camera.fov=85
	var controls:=Controls.new();controls.client=self;root.add_child(controls)
	auto_accept_quit=false;root.close_requested.connect(close_client)
	var env:=WorldEnvironment.new();env.environment=Environment.new();world.add_child(env)
	var canvas:=CanvasLayer.new();root.add_child(canvas);canvas.add_child(label);label.position=Vector2(20,16);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
	edge=preload("res://deathmatch/server/cluster/edge.gd").new();edge.name="ClusterEdge";root.add_child(edge);edge.response.connect(func(id,body):replies[id]=body)
	soundscape=preload("res://tools/district_cluster/soundscape.gd").new();root.add_child(soundscape)
	var preferences:=ConfigFile.new();preferences.load("user://cq_audio.cfg")
	soundscape.music_volume=clampf(float(settings.get("music_volume",preferences.get_value("audio","music",.8))),0,1)
	soundscape.ambience_volume=clampf(float(settings.get("ambience_volume",preferences.get_value("audio","ambience",.7))),0,1)
	main_menu=preload("res://tools/district_cluster/cq_menu.gd").new();canvas.add_child(main_menu);main_menu.setup(soundscape)
	label.hide()
	if settings.has("menu_smoke_output"):
		await create_timer(3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(settings.menu_smoke_output)
		print("CQ_MENU_SMOKE ",JSON.stringify(soundscape.state()));await shutdown();return
	var automatic: bool=settings.get("autoconnect",false) or settings.has("smoke_output")
	var joined: Dictionary={}
	while true:
		if not automatic:await main_menu.join_requested
		if not await connect_region(settings.address):
			if automatic:push_error("Cannot connect to campaign gateway");quit(3);return
			main_menu.failed("Gateway unavailable. Try again shortly.");continue
		joined=await invoke({"op":"join","identity":identity.actor,"resume":identity.resume,"token":settings.token,"district":settings.get("district","d40"),"name":settings.get("name","Campaign Explorer"),"team":int(settings.get("team",0))})
		if not joined.has("error"):break
		if automatic:push_error(joined.error);quit(3);return
		main_menu.failed(str(joined.error))
	main_menu.queue_free();label.show()
	auth={"actor":joined.result.identity,"resume":joined.result.resume};await follow(joined.result)
	avatars=preload("res://tools/district_cluster/client_avatar.gd").new();root.add_child(avatars);avatars.setup(str(settings.get("content_url","")))
	if not str(settings.get("vrm","")).is_empty():
		var error: String=await avatars.upload(settings.vrm,auth)
		if not error.is_empty():push_warning(error)
	moderator=preload("res://tools/district_cluster/moderator_menu.gd").new();canvas.add_child(moderator);moderator.setup(self)
	global_voice=preload("res://tools/district_cluster/moderator_voice.gd").new();root.add_child(global_voice);global_voice.setup(self,canvas)
	var mod_button:=Button.new();mod_button.text="Moderator · F8";mod_button.position=Vector2(20,145);canvas.add_child(mod_button);mod_button.pressed.connect(moderator.toggle)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;Engine.max_fps=120
	input_loop();status_loop();snapshot_loop()
	if settings.has("smoke_output"):smoke()
func smoke() -> void:
	await create_timer(4).timeout
	if not have_eye or not status.get("campaign") is Dictionary or not level.has_node("CampaignVisuals"):push_error("Campaign desktop state unavailable");quit(4);return
	busy=true;have_eye=false;camera.position=Vector3(8,4,4);camera.look_at(Vector3(0,4,-20))
	var custom_count:=0
	for body in bodies.values():
		if body.has_meta("avatar"):
			custom_count+=1
			if settings.get("require_avatar",false):camera.position=body.position+Vector3(3,2.2,4);camera.look_at(body.position+Vector3.UP*.9)
	if settings.get("require_avatar",false) and custom_count==0:push_error("Remote custom VRM was not instantiated");quit(4);return
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(settings.smoke_output)
	await request("leave");print("CAMPAIGN_DESKTOP_SMOKE ",JSON.stringify({"district":district,"campaign":status.campaign.epoch,"scoreboard":true,"custom_avatars":custom_count,"audio":soundscape.state()}));await shutdown()
func close_client() -> void:
	busy=true
	if not auth.is_empty():await request("leave")
	await shutdown()
func shutdown() -> void:
	if is_instance_valid(global_voice):global_voice.queue_free()
	if is_instance_valid(soundscape):soundscape.queue_free()
	await create_timer(.25).timeout
	quit()
func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and is_instance_valid(moderator):
		if event.keycode==KEY_F8 and event.pressed:moderator.toggle();return
		if event.keycode==KEY_F9:global_voice.talk(event.pressed);return
		if moderator.visible and event.keycode==KEY_ESCAPE and event.pressed:moderator.toggle();return
		if moderator.visible:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*.0025;pitch=clampf(pitch-event.relative.y*.0025,-1.5,1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if event.keycode==KEY_R and health<=0 and not busy:respawn()
		if event.keycode>=KEY_1 and event.keycode<=KEY_9:weapon=int(event.keycode-KEY_1)+1
func _process(delta: float) -> bool:
	if have_eye:
		camera.position=camera.position.lerp(target_eye,1-exp(-delta*22));camera.rotation=Vector3(pitch,yaw,0)
	return false
func input_loop() -> void:
	while true:
		if not busy and have_eye and actor.get("phase")=="active" and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			input_sequence+=1
			var move:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length()
			await request("input",{"generation":actor.generation,"command":{"seq":input_sequence,"move":[move.x,move.y],"yaw":yaw,"pitch":pitch,"jump":Input.is_physical_key_pressed(KEY_SPACE),"fire":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"weapon":weapon}})
		await create_timer(1.0/30).timeout
func status_loop() -> void:
	while true:
		if not busy:
			if actor.get("phase")=="waiting":
				var resumed:=await request("resume")
				if resumed.has("result"):
					busy=true
					if resumed.result.has("redirect"):await follow(resumed.result)
					else:actor=resumed.result;await load_district()
					busy=false
			var reply:=await request("status")
			if reply.has("result") and int(reply.result.actor.generation)>=int(actor.get("generation",0)):
				if reply.result.has("redirect") or (reply.result.actor.phase=="active" and (reply.result.actor.get("district")!=district or int(reply.result.actor.generation)!=int(actor.get("generation",0)))):
					busy=true;await follow(reply.result);busy=false;continue
				status=reply.result;actor=status.actor
				var overlay:=level.get_node_or_null("CampaignVisuals") if is_instance_valid(level) else null
				if overlay and status.get("campaign") is Dictionary:overlay.apply_campaign(status.campaign,int(actor.get("team",-1)),status.links)
				label.text=(status.get("metadata",{}).get("name","Reinforcement reserve"))+"\n"+("RED" if int(actor.get("team",0))==0 else "BLUE")+" · HP %d\nWASD · mouse · double Space jetpack · R respawn · Esc cursor"%health
		await create_timer(.5).timeout
func snapshot_loop() -> void:
	while true:
		if not busy and actor.get("phase")=="active":
			var reply:=await request("snapshot")
			if reply.has("result") and reply.result.district==district:
				avatar_hashes=reply.result.get("avatars",{})
				var data=bytes_to_var(Marshalls.base64_to_raw(reply.result.payload))
				if data is Dictionary:update_snapshot(data)
		await create_timer(.05).timeout
func update_snapshot(data: Dictionary) -> void:
	if is_instance_valid(soundscape):soundscape.observe(data,int(actor.id))
	var visible: Dictionary={};var origin:=Rules.center(int(data.zone))
	for row in data.actors:
		var id:=int(row.id);var p: Vector3=row.position-origin
		if id==int(actor.id):
			input_sequence=maxi(input_sequence,int(row.state.get("last_seq",-1)))
			health=int(row.state.hp);target_eye=p+Vector3.UP*1.55
			if not have_eye:camera.position=target_eye;yaw=float(row.state.yaw);pitch=float(row.state.pitch);have_eye=true
			if not row.state.dead and Time.get_ticks_msec()-last_travel>1500:
				var metadata: Dictionary=status.get("metadata",{});var links: Dictionary=metadata.get("links",{}).duplicate();links.merge(metadata.get("terminals",{}))
				for target in links:
					var e: Array=links[target].exit
					if status.get("links",{}).get(target,{}).get("open",false) and p.distance_to(Vector3(e[0],e[1],e[2]))<2.5:travel(target);break
			continue
		if row.state.dead:continue
		visible[id]=true
		var hash: String=avatar_hashes.get(str(id),"")
		if is_instance_valid(avatars) and not hash.is_empty() and (not bodies.has(id) or bodies[id].get_meta("avatar","")!=hash):
			var custom: Node3D=avatars.create(hash)
			if custom:
				if bodies.has(id):bodies[id].free()
				var holder:=Node3D.new();world.add_child(holder);holder.add_child(custom);holder.set_meta("avatar",hash);bodies[id]=holder
				var tag:=Label3D.new();tag.text="●";tag.modulate=Color(1,.2,.25) if int(row.state.team)==0 else Color(.15,.5,1);tag.position=Vector3(0,1.95,0);tag.font_size=24;tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;holder.add_child(tag)
		if not bodies.has(id):
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.7,1.65,.6);mesh.mesh=box
			var material:=StandardMaterial3D.new();material.albedo_color=Color(1,.15,.2) if int(row.state.team)==0 else Color(.1,.45,1);mesh.material_override=material;world.add_child(mesh);bodies[id]=mesh
		bodies[id].position=p+(Vector3.UP*.825 if bodies[id] is MeshInstance3D else Vector3.ZERO)
		bodies[id].rotation.y=float(row.state.yaw)
		if bodies[id].has_meta("avatar"):
			var rig=bodies[id].get_child(0)
			rig.set_weapon(int(row.state.weapon),"ut99")
			rig.aim_pitch=float(row.state.pitch)
	for id in bodies.keys():
		if not visible.has(id):bodies[id].free();bodies.erase(id)
func travel(target: String) -> void:
	if busy:return
	busy=true;last_travel=Time.get_ticks_msec();var reply:=await request("transfer",{"target":target})
	if reply.has("result"):await follow(reply.result)
	else:label.text=str(reply.get("error","Gate unavailable"))
	busy=false
func respawn() -> void:
	busy=true;var reply:=await request("respawn")
	if reply.has("result"):await follow(reply.result)
	busy=false
