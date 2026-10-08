extends Node
## Two persistent beds, no world queries or per-frame allocations. Shared room probes
## soften outdoor sound indoors; close combat ducks only this environmental bus.
const ROOT:="res://deathmatch/audio/modes/ambient_"
const PROFILES=["tech","gothic","arena","desert","industrial","coast","alpine","rain","void","inferno"]
const MAP_PROFILES={
 "ctf_t2_acidrain":"rain",
 "ctf_t2_blastside":"coast",
 "ctf_t2_broadside":"coast",
 "ctf_t2_confusco":"desert",
 "ctf_t2_dangerouscrossing":"coast",
 "ctf_t2_desertofdeath":"desert",
 "ctf_t2_gorgon":"desert",
 "ctf_t2_hillside":"coast",
 "ctf_t2_iceridge":"alpine",
 "ctf_t2_lakefront":"coast",
 "ctf_t2_magmatic":"inferno",
 "ctf_t2_ramparts":"alpine",
 "ctf_t2_rollercoaster":"desert",
 "ctf_t2_sandstorm":"desert",
 "ctf_t2_scarabrae":"coast",
 "ctf_t2_shockridge":"alpine",
 "ctf_t2_snowblind":"alpine",
 "ctf_t2_starfallen":"coast",
 "ctf_t2_subzero":"alpine",
 "ctf_t2_surreal":"inferno",
 "ctf_t2_titan":"coast",
 "ctf_t2_whitedwarf":"coast",
"de_dust2_rebuilt":"desert","de_inferno_rebuilt":"desert","de_nuke_rebuilt":"industrial","de_train_rebuilt":"industrial","de_aztec_rebuilt":"rain","ctf_raindance":"rain","ctf_katabatic":"alpine","ctf_stonehenge":"alpine","as_frigate":"coast","as_hislop":"industrial","tf_pressureworks":"industrial"}
var game
var spatial
var streams: Dictionary={}
var players: Array[AudioStreamPlayer]=[]
var gains: Array[float]=[0.0,0.0]
var selected:=-1
var profile:=""
var context:=""
var check_tick:=0.0
var duck_until:=0.0
var elapsed:=0.0
var lowpass: AudioEffectLowPassFilter
var owns_bus:=false
static func profile_for(map: String,rules: String) -> String:
	map=preload("res://deathmatch/maps/skies/catalog.gd").canonical(map)
	if MAP_PROFILES.has(map):return MAP_PROFILES[map]
	var sky: String=preload("res://deathmatch/maps/atmosphere.gd").MAPS.get(map,"")
	if not sky.is_empty():return {"abbey":"gothic","works":"industrial"}.get(sky,sky)
	return {"doom":"tech","quake":"gothic","ut99":"arena","cs16":"desert","tribes":"alpine"}.get(rules,"tech")
func setup(arena,mixer) -> void:
	game=arena;spatial=mixer
	if AudioServer.get_bus_index("ArenaAmbience")<0:
		owns_bus=true;AudioServer.add_bus()
		var idx:=AudioServer.bus_count-1
		AudioServer.set_bus_name(idx,"ArenaAmbience");AudioServer.set_bus_send(idx,"ArenaEffects")
		lowpass=AudioEffectLowPassFilter.new();lowpass.cutoff_hz=12000;AudioServer.add_bus_effect(idx,lowpass)
	for name_here in PROFILES:
		var stream:=load(ROOT+name_here+".ogg") as AudioStreamOggVorbis
		stream.loop=true;streams[name_here]=stream
	for i in 2:
		var player:=AudioStreamPlayer.new();player.bus="ArenaAmbience";player.volume_db=-80
		add_child(player);players.append(player)
func combat_pulse() -> void:duck_until=elapsed+.6
func clear() -> void:
	for player in players:player.stop();player.stream=null
	gains=[0.0,0.0];profile="";context="";selected=-1;duck_until=0
func _process(delta: float) -> void:
	if not game or game.headless:return
	elapsed+=delta;check_tick-=delta
	var enabled: bool=game.active and not game.map_loading and not game.quitting and not game.menu_open and not game.lobby.active() and game.intermission<=0
	if enabled and is_instance_valid(game.music) and game.music.has_custom_bgm(false):
		if selected>=0:clear()
		return
	if check_tick<=0:
		check_tick=.25
		if enabled:
			var next_context: String=game.current_map+":"+game.armory.effective()
			if next_context!=context:
				context=next_context
				var next_profile:=profile_for(game.current_map,game.armory.effective())
				if next_profile!=profile:
					profile=next_profile;selected=0 if selected<0 else 1-selected
					gains[selected]=0.0;players[selected].volume_db=-80
					players[selected].stream=streams[profile];players[selected].play()
	if lowpass:lowpass.cutoff_hz=lerpf(lowpass.cutoff_hz,lerpf(12000.0,2400.0,spatial.enclosure),minf(1,delta*2))
	var music_gain: float=game.music.ambience_gain() if is_instance_valid(game.music) else 1.0
	for i in players.size():
		var target:=music_gain if enabled and i==selected else 0.0
		gains[i]=move_toward(gains[i],target,delta*.65)
		var room_db: float=-4.0*spatial.enclosure if profile in ["desert","coast","alpine","rain"] else 0.0
		var target_db: float=-12.0+room_db+(-7.0 if elapsed<duck_until else 0.0)+linear_to_db(maxf(gains[i],.0001))
		players[i].volume_db=lerpf(players[i].volume_db,target_db,minf(1,delta*(18 if elapsed<duck_until else 3)))
		if gains[i]<=0 and players[i].playing:players[i].stop()
		elif gains[i]>0 and i==selected and not players[i].playing:players[i].play()
func _exit_tree() -> void:
	if owns_bus:
		var idx:=AudioServer.get_bus_index("ArenaAmbience")
		if idx>=0:AudioServer.remove_bus(idx)
