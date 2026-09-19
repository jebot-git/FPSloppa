extends Node
## Hash-keyed, disposable map photographs. A dedicated server only stores PNGs.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Hash=preload("res://deathmatch/avatars/library.gd")
const SIZE=Vector2i(320,180)
const MAX_BYTES=256000
const CHUNK=32768
const VERSION="4"
var game
var textures: Dictionary={}
var queue: Array=[]
var busy:=false
var waiting: Dictionary={}
var requests: Dictionary={}
var incoming: Dictionary={}
var outgoing: Dictionary={}
var failed: Dictionary={}
func setup(arena: Node) -> void:game=arena
static func path(hash: String) -> String:
	return Maps.Paths.folder("maps")+"previews/"+VERSION+"-"+hash+".png"
static func decode(bytes: PackedByteArray) -> Image:
	if bytes.size()<33 or bytes.size()>MAX_BYTES:return null
	if bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(12,16).get_string_from_ascii()!="IHDR":return null
	var width: int=(bytes[16]<<24)|(bytes[17]<<16)|(bytes[18]<<8)|bytes[19]
	var height: int=(bytes[20]<<24)|(bytes[21]<<16)|(bytes[22]<<8)|bytes[23]
	if Vector2i(width,height)!=SIZE:return null
	var picture:=Image.new()
	return picture if picture.load_png_from_buffer(bytes)==OK and picture.get_size()==SIZE else null
static func store_png(hash: String,bytes: PackedByteArray) -> bool:
	if not Hash.valid_hash(hash) or decode(bytes)==null:return false
	var target:=path(hash);DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var temporary:=target+".%d.tmp"%Time.get_ticks_usec()
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return false
	file.store_buffer(bytes);file.close()
	var error:=DirAccess.rename_absolute(temporary,target)
	if error!=OK:DirAccess.remove_absolute(temporary)
	return error==OK
static func bytes_for(hash: String) -> PackedByteArray:
	if not Hash.valid_hash(hash) or not FileAccess.file_exists(path(hash)):return PackedByteArray()
	var file:=FileAccess.open(path(hash),FileAccess.READ)
	return file.get_buffer(file.get_length()) if file and file.get_length()<=MAX_BYTES else PackedByteArray()
func texture(map_id: String,hash: String="") -> Texture2D:
	var row: Dictionary={}
	for entry in game.map_catalog:
		if (hash.is_empty() and entry.id==map_id) or (not hash.is_empty() and entry.sha256==hash):row=entry;hash=entry.sha256;break
	if not Hash.valid_hash(hash):return null
	if textures.has(hash):return textures[hash]
	var image:=decode(bytes_for(hash))
	if image!=null and DisplayServer.get_name()!="headless":
		if textures.size()>=32:textures.erase(textures.keys()[0])
		textures[hash]=ImageTexture.create_from_image(image);return textures[hash]
	if not row.is_empty():enqueue(row)
	elif game.active and not multiplayer.is_server() and Time.get_ticks_msec()>=waiting.get(hash,0):
		waiting[hash]=Time.get_ticks_msec()+5000;request.rpc_id(1,hash)
	return null
func enqueue(row: Dictionary) -> void:
	if DisplayServer.get_name()=="headless" or not bytes_for(row.sha256).is_empty() or queue.any(func(entry):return entry.sha256==row.sha256):return
	if queue.size()<24 and Time.get_ticks_msec()>=failed.get(row.sha256,0):queue.append(row.duplicate())
func ensure(row: Dictionary) -> void:
	enqueue(row)
	while queue.any(func(entry):return entry.sha256==row.sha256):await get_tree().process_frame
func _process(_delta: float) -> void:
	if not busy and not queue.is_empty():generate(queue[0])
	for key in outgoing.keys():
		var item: Dictionary=outgoing[key]
		if not game.players.has(item.peer):outgoing.erase(key);continue
		var count: int=game.asset_allowance(item.peer,mini(CHUNK,item.bytes.size()-item.offset))
		if count<=0:continue
		receive.rpc_id(item.peer,item.hash,item.offset,item.bytes.size(),item.bytes.slice(item.offset,item.offset+count))
		item.offset+=count
		if item.offset==item.bytes.size():outgoing.erase(key)
	var now:=Time.get_ticks_msec()
	for key in requests.keys():
		if requests[key]<now:requests.erase(key)
	for hash in incoming.keys():
		if now-incoming[hash].time>30000:incoming.erase(hash)
func generate(row: Dictionary) -> void:
	busy=true
	await get_tree().process_frame
	var packed:=Maps.scene(row)
	if packed:
		var viewport:=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.transparent_bg=false
		add_child(viewport)
		var level:=packed.instantiate();viewport.add_child(level)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("364b60")
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.tonemap_exposure=1.4
		environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
		viewport.add_child(environment)
		var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-25,0);light.light_energy=.65;viewport.add_child(light)
		var camera:=Camera3D.new();camera.fov=85;camera.far=300;viewport.add_child(camera)
		await get_tree().physics_frame;await get_tree().physics_frame
		var pose:=camera_pose(level,viewport.find_world_3d().direct_space_state)
		camera.position=pose.origin;camera.basis=pose.basis;camera.make_current()
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		for frame in 3:await get_tree().process_frame
		RenderingServer.force_draw(false)
		var picture:=viewport.get_texture().get_image()
		if picture and not picture.is_empty():store_png(row.sha256,picture.save_png_to_buffer())
		viewport.queue_free()
	if bytes_for(row.sha256).is_empty():failed[row.sha256]=Time.get_ticks_msec()+60000
	queue.pop_front();busy=false
static func camera_pose(level: Node3D,space: PhysicsDirectSpaceState3D) -> Transform3D:
	var candidates: Array=[]
	for node in level.get_children():
		if "attributes" in node and node.attributes.get("classname","") in ["info_player_deathmatch","info_player_start","info_player_team1","info_player_team2","info_player_teamspawn","info_tb_spawn"]:
			candidates.append(node.global_position+Vector3.UP*.9)
	if candidates.is_empty():candidates.append(Vector3(0,2,0))
	var best:=-1.;var position: Vector3=candidates[0];var direction:=Vector3.FORWARD
	# Prefer a spawn with an open, broad view instead of the outside of a sealed BSP.
	for index in mini(candidates.size(),16):
		var eye: Vector3=candidates[index]
		var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye-Vector3.UP*5,1))
		if floor_hit.is_empty() or floor_hit.normal.y<.5:continue
		eye=floor_hit.position+Vector3.UP*1.6
		for heading in 8:
			var forward:=Vector3.FORWARD.rotated(Vector3.UP,heading*TAU/8.)
			var score:=0.
			for angle in [-.55,0.,.55]:
				var target: Vector3=eye+forward.rotated(Vector3.UP,angle)*80
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,1))
				var distance: float=80. if hit.is_empty() else eye.distance_to(hit.position)
				# A far miss often looks into sky/void. Favor visible architecture.
				if angle==0 and distance<2.5:score=-1000.;break
				score+=(3. if hit.is_empty() else minf(distance,24.)+6.)*(2. if angle==0 else 1.)
			if score>best:best=score;position=eye;direction=forward
	return Transform3D(Basis.looking_at((direction+Vector3.DOWN*.08).normalized()),position)
@rpc("any_peer","call_remote","reliable",5)
func request(hash: String) -> void:
	if not multiplayer.is_server() or not Hash.valid_hash(hash):return
	var peer:=multiplayer.get_remote_sender_id()
	if not game.players.has(peer) or not game.map_catalog.any(func(row):return row.sha256==hash):return
	var now:=Time.get_ticks_msec();var key: String=str(peer)+":"+hash
	if now<requests.get(key,0) or outgoing.has(key):return
	requests[key]=now+5000
	# One ballot's small images per peer per window; no BSP downloads for browsing.
	var recent:=0
	for entry in requests:
		if str(entry).begins_with(str(peer)+":") and requests[entry]>now:recent+=1
	if recent>9:return
	var bytes:=bytes_for(hash)
	if bytes.is_empty():receive.rpc_id(peer,hash,0,0,bytes)
	else:outgoing[key]={"peer":peer,"hash":hash,"offset":0,"bytes":bytes}
@rpc("authority","call_remote","reliable",5)
func receive(hash: String,offset: int,total: int,bytes: PackedByteArray) -> void:
	if not waiting.has(hash) or total<0 or total>MAX_BYTES or bytes.size()>CHUNK:return
	if total==0:incoming.erase(hash);return
	if not incoming.has(hash):
		if offset!=0 or incoming.size()>=9:return
		incoming[hash]={"total":total,"bytes":PackedByteArray(),"time":Time.get_ticks_msec()}
	var item: Dictionary=incoming[hash]
	if item.total!=total or item.bytes.size()!=offset or bytes.is_empty() or offset+bytes.size()>total:incoming.erase(hash);return
	item.bytes.append_array(bytes);item.time=Time.get_ticks_msec();waiting[hash]=item.time+10000
	if item.bytes.size()==total:
		if store_png(hash,item.bytes):waiting.erase(hash);textures.erase(hash)
		incoming.erase(hash)
