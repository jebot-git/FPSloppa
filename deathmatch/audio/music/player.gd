extends Node
const TRACKS={"title":"dead_air","lobby":"please_hold"}
const Catalog=preload("res://deathmatch/audio/music/catalog.gd")
const Paths=preload("res://deathmatch/assets/paths.gd")
var game
var players: Array[AudioStreamPlayer]=[]
var selected:=""
var playing_path:=""
var current:=0
var fade:=1.0
var outgoing_gain:=1.0
var owned_bus:=false
var folder:=""
var catalog:=Catalog.new()
var context:=""
var tracks: Array=[]
var index:=-1
var generation:=0
var failed: Array=[]
var need_next:=false
var exhausted:=false
var worker: Thread
var loading:=""
var loading_index:=-1
var loading_generation:=-1
var prepared: AudioStreamOggVorbis
var prepared_index:=-1
func setup(arena: Node,custom_folder: String="") -> void:
	game=arena
	if game.headless:set_process(false);return
	folder=Paths.folder("bgm") if custom_folder.is_empty() else custom_folder
	DirAccess.make_dir_recursive_absolute(folder)
	if AudioServer.get_bus_index("ArenaMusic")<0:
		owned_bus=true;AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaMusic")
		AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	for i in 2:
		var player:=AudioStreamPlayer.new();player.bus="ArenaMusic";add_child(player);players.append(player)
		player.finished.connect(finished.bind(i))
func desired_context() -> String:
	if not game.active:return "title"
	if game.lobby.active():return "lobby"
	return game.match_mode.kind+"|"+game.current_map
func refresh() -> void:
	context=desired_context()
	var choice: Dictionary
	if TRACKS.has(context):choice={"key":context,"tracks":["res://deathmatch/audio/music/"+TRACKS[context]+".ogg"]}
	else:
		var names: Array=[game.current_map]
		for row in game.map_catalog:names.append(row.id)
		catalog.scan(folder,names);choice=catalog.choose(game.match_mode.kind,game.current_map)
	if selected==choice.key and tracks==choice.tracks:
		failed.clear();exhausted=false
		if not players[current].playing:need_next=not tracks.is_empty()
		return
	selected=choice.key;tracks=choice.tracks;index=-1;generation+=1;failed.clear()
	prepared=null;prepared_index=-1;need_next=not tracks.is_empty();exhausted=false
	if tracks.is_empty():transition(null,"")
static func load_track(path: String) -> AudioStreamOggVorbis:
	var stream: AudioStreamOggVorbis
	if path.begins_with("res://"):
		var original:=ResourceLoader.load(path,"AudioStreamOggVorbis") as AudioStreamOggVorbis
		if original:stream=original.duplicate();stream.loop=true
	elif FileAccess.file_exists(path):
		stream=AudioStreamOggVorbis.load_from_file(path)
		if stream:stream.loop=false # Ignore file tags: playlists must advance.
	return stream if stream and stream.get_length()>0 else null
func request_next() -> void:
	if worker or prepared or tracks.is_empty() or exhausted:return
	if not need_next and TRACKS.has(selected):return
	for offset in tracks.size():
		var next: int=(index+1+offset)%tracks.size()
		if tracks[next] in failed:continue
		loading=tracks[next];loading_index=next;loading_generation=generation;worker=Thread.new()
		if worker.start(load_track.bind(loading))!=OK:
			worker=null;failed.append(loading);loading="";continue
		return
	# Every entry failed: remain silent until the next rescan, without retry spam.
	need_next=false;exhausted=true
	if not playing_path.is_empty():transition(null,"")
func finished(which: int) -> void:
	if which==current and not tracks.is_empty():need_next=true
func transition(stream: AudioStreamOggVorbis,path: String) -> void:
	var outgoing:=current if fade>=.5 else 1-current
	outgoing_gain=db_to_linear(players[outgoing].volume_db) if players[outgoing].playing else 0.0
	current=1-outgoing;players[current].stop();players[current].stream=stream;playing_path=path
	fade=0.0 if outgoing_gain>0 else 1.0
	players[current].volume_db=-80 if fade==0 else 0
	if stream:players[current].play()
func _process(delta: float) -> void:
	if players.is_empty():return
	if context!=desired_context():refresh()
	if worker and not worker.is_alive():
		var stream=worker.wait_to_finish();worker=null
		if loading_generation==generation:
			if stream:prepared=stream;prepared_index=loading_index
			else:failed.append(loading);push_warning("Skipping unreadable custom music: "+loading)
		loading=""
	if need_next and prepared:
		index=prepared_index;transition(prepared,tracks[index]);prepared=null;prepared_index=-1;need_next=false
	request_next() # Prefetch one track only; never cache a user's entire library.
	fade=minf(1,fade+delta/2.5)
	players[current].volume_db=linear_to_db(maxf(.0001,sin(fade*PI*.5)))
	players[1-current].volume_db=linear_to_db(maxf(.0001,outgoing_gain*cos(fade*PI*.5)))
	if fade>=1 and players[1-current].stream:players[1-current].stop();players[1-current].stream=null
func stop() -> void:
	set_process(false)
	if worker:worker.wait_to_finish();worker=null
	loading="";prepared=null;tracks.clear();need_next=false
	for player in players:player.stop();player.stream=null
	players.clear()
func _exit_tree() -> void:
	stop()
	if owned_bus:
		var bus:=AudioServer.get_bus_index("ArenaMusic")
		if bus>=0:AudioServer.remove_bus(bus)
