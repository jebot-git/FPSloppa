extends Node
## Separate headless process: all network RPCs remain owned by the real Arena.
const Paths=preload("res://deathmatch/assets/paths.gd")
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
const Lists=preload("res://deathmatch/launcher/playlists.gd")
var job: Dictionary={}
var job_path:=""
var game
var state:={"state":"working","message":"Starting…","done":0,"total":0}
var finished:=false
var elapsed:=0.0
func _ready() -> void:run.call_deferred()
func publish(message: String,done: int=0,total: int=0) -> void:
	state.message=message;state.done=done;state.total=total
	Lists.write_text(job_path+".status",JSON.stringify(state))
func finish(ok: bool,message: String) -> void:
	if finished:return
	finished=true;state.state="complete" if ok else "error";publish(message,1,1)
	if is_instance_valid(game):
		# Closing this process needs no return-to-menu map/mode reset.
		if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
		game.request_quit()
	else:get_tree().quit(0 if ok else 1)
func cancelled() -> bool:
	# Godot can query its children, not its parent. The window renews a heartbeat
	# instead, which also makes orphaned workers stop after an abrupt launcher exit.
	var lease:=job_path+".heartbeat"
	var expired: bool=job.get("heartbeat",false) and (not FileAccess.file_exists(lease) or Time.get_unix_time_from_system()-FileAccess.get_modified_time(lease)>30)
	return FileAccess.file_exists(job_path+".cancel") or expired
func _process(delta: float) -> void:
	if finished or job_path.is_empty():return
	elapsed+=delta
	if elapsed<.2:return
	elapsed=0
	if cancelled():
		finish(false,"Cancelled.");return
	if not is_instance_valid(game):return
	var download: Dictionary=game.loading.snapshot()
	if game.loading.blocking or game.loading.downloading():
		publish(str(download.phase) if not str(download.phase).is_empty() else "Downloading assets…",int(download.done),int(download.total))
	elif not game.uploads.outgoing.is_empty():
		publish("Submitting BSP…",int(game.uploads.outgoing.ack),int(game.uploads.outgoing.size))
	elif game.avatars.outgoing.has(1):
		var row: Dictionary=game.avatars.outgoing[1];publish("Submitting VRM…",int(row.ack),int(row.size))
func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not finished and Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await get_tree().create_timer(.05).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var pos:=args.find("--job")
	if pos<0 or pos+1>=args.size():get_tree().quit(2);return
	job_path=args[pos+1]
	var data=JSON.parse_string(FileAccess.get_file_as_string(job_path))
	if not data is Dictionary:finish(false,"Invalid launcher job.");return
	job=data
	if job.get("action")=="playlist":
		publish("Validating Ogg Vorbis tracks…")
		var result:=Lists.save(Paths.root().path_join("bgm"),job.scope,job.target,job.climax,job.tracks,func(done,total,title):publish("Copying "+title,done,total),cancelled,job.get("titles",[]))
		finish(not result.has("error"),result.get("error",result.get("message","Saved.")));return
	var imported: Array=[]
	for path in job.get("files",[]):
		if cancelled():finish(false,"Cancelled.");return
		publish("Validating "+str(path).get_file(),imported.size(),job.files.size())
		var hash:=FileAccess.get_sha256(path);var result: Dictionary
		match str(path).get_extension().to_lower():
			"bsp":result=Jobs.map_file(path,hash,str(path).get_file().get_basename(),Paths.folder("maps"),str(path).get_file())
			"vrm":result=Jobs.model_file(path,hash,Paths.folder("vrm"))
			_:result={"error":"Choose BSP or VRM files."}
		if result.has("error"):finish(false,str(path).get_file()+": "+result.error);return
		result.kind=str(path).get_extension().to_lower();imported.append(result)
		await get_tree().process_frame
	if job.get("action")=="import":finish(true,"Imported and verified %d file(s)."%imported.size());return
	if job.get("action") not in ["preload","submit"]:finish(false,"Unknown launcher action.");return
	publish("Connecting as a temporary spectator…")
	game=load("res://deathmatch/arena.tscn").instantiate();get_tree().root.add_child(game)
	# Do not offer the user's usual avatar during a preload session.
	game.avatars.library.selected=""
	game.start_join("Asset preload",str(job.address),int(job.game_port),true)
	var admitted:=await wait_for(func():return game.players.has(multiplayer.get_unique_id()) or (not game.loading.blocking and not game.active),240)
	if finished:return
	if not admitted or not game.players.has(multiplayer.get_unique_id()):finish(false,game.last_event if not game.last_event.is_empty() else "Server connection timed out.");return
	if job.action=="preload":
		if not await wait_for(func():return not game.loading.blocking and not game.loading.downloading() and game.avatars.checking.is_empty(),120):finish(false,"Asset download timed out.");return
		finish(true,"Current map and announced player VRMs are cached and verified.");return
	for i in imported.size():
		if finished:return
		var row: Dictionary=imported[i]
		publish("Submitting %s (%d/%d)…"%[row.title,i+1,imported.size()])
		if row.kind=="bsp":
			game.last_event="";game.uploads.upload(row)
			if not await wait_for(func():return game.uploads.offered.is_empty(),125):finish(false,"Map submission timed out.");return
			if finished:return
			if not game.last_event.begins_with("Map stored on server"):finish(false,game.last_event if not game.last_event.is_empty() else "Server did not accept the map.");return
			if i+1<imported.size():
				publish("Server accepted the map · waiting for upload cooldown…")
				await wait_for(func():return false,30.2)
		else:
			game.avatars.library.entries[row.hash]=row;game.avatars.library.selected=row.hash
			if not await wait_for(func():return game.avatars.choices.get(multiplayer.get_unique_id(),{}).get("hash","")==row.hash,125):finish(false,"Server did not acknowledge the VRM: "+game.avatars.message);return
	finish(true,"Server acknowledged all %d submitted file(s)."%imported.size())
