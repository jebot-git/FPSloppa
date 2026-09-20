extends Node
## Local presentation only: no server audio, downloaded tracks or audio replication.
const BASE="res://deathmatch/audio/cq/"
const HOLD=12.0
const RANGE=75.0
var manifest: Dictionary={}
var ambience: Array[AudioStreamPlayer]=[]
var music: AudioStreamPlayer
var selected_ambience:=""
var ambient_slot:=0
var ambient_mix:=1.0
var menu:=true
var safe:=true
var alive:=true
var remaining:=0.0
var music_gain:=0.0
var music_key:=""
var voice_duck:=1.0
var music_volume:=.80
var ambience_volume:=.70
var last_sequence:=-1
var previous_health:=-1.0
var previous_life:=-1
var cache: Dictionary={}
var current_district:=""
func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
	for i in 2:
		var player:=AudioStreamPlayer.new();add_child(player);ambience.append(player)
	music=AudioStreamPlayer.new();add_child(music)
func stream(key: String) -> AudioStreamOggVorbis:
	if not cache.has(key):
		var source:=AudioStreamOggVorbis.load_from_file(BASE+key+".ogg")
		if source==null:return null
		source.loop=true;cache[key]=source
	return cache[key]
func set_menu(value: bool) -> void:
	menu=value
	if value:
		remaining=0;current_district="";safe=true;selected_ambience=""
		for player in ambience:player.stop();player.stream=null
func set_district(value: String) -> void:
	if value==current_district and not menu:return
	current_district=value;menu=false;remaining=0;last_sequence=-1;previous_health=-1;previous_life=-1;alive=true
	safe=value.is_empty() or value=="d40"
	var key: String=manifest.get("district_themes",{}).get(str(int(value.substr(1))),"arcology") if not value.is_empty() else "bastion"
	if key==selected_ambience:return
	# A rapid gate sequence keeps the louder outgoing bed; maximum three voices.
	var outgoing:=ambient_slot if ambient_mix>=.5 else 1-ambient_slot
	ambient_slot=1-outgoing;ambient_mix=0;selected_ambience=key
	ambience[ambient_slot].stop();ambience[ambient_slot].stream=stream(key)
	ambience[ambient_slot].volume_db=-80
	if ambience[ambient_slot].stream:ambience[ambient_slot].play()
	for cached in cache.keys():
		if cached not in ["menu","combat",key] and cache[cached]!=ambience[outgoing].stream:cache.erase(cached)
func combat() -> void:
	if not menu and not safe and alive:remaining=HOLD
func observe(data: Dictionary,local_id: int) -> void:
	if menu or safe:return
	var sequence:=int(data.get("sequence",0))
	if sequence<=last_sequence:return
	last_sequence=sequence
	var actors: Dictionary={};var me: Dictionary={}
	for row in data.get("actors",[]):
		actors[int(row.id)]=row
		if int(row.id)==local_id:me=row
	if me.is_empty():remaining=0;return
	alive=not me.state.get("dead",false)
	if not alive:remaining=0;previous_health=-1;return
	var life:=int(me.state.get("serial",0));var health_value:=float(me.state.get("hp",100))+float(me.state.get("armor",0))
	var hostile_near:=false
	for row in actors.values():
		if int(row.state.team)!=int(me.state.team) and not row.state.get("dead",false) and me.position.distance_to(row.position)<=RANGE:hostile_near=true
	if previous_life==life and previous_health>=0 and health_value<previous_health and hostile_near:combat()
	previous_health=health_value;previous_life=life
	for event in data.get("events",[]):
		if not event is Array or event.size()!=2 or not event[1] is Array:continue
		var kind: String=event[0];var args: Array=event[1]
		if kind in ["_shot_fx","_variant_shot_fx","_melee_fx"] and args.size()>0:
			var shooter: int=int(args[0])
			if shooter==local_id:combat()
			elif actors.has(shooter) and me.position.distance_to(actors[shooter].position)<=RANGE:
				if int(actors[shooter].state.team)!=int(me.state.team) or hostile_near:combat()
		if kind=="_hurt_fx" and args.size()>8 and int(args[0])==local_id and float(args[3])>0:
			if str(args[8]).to_lower() not in ["fall","falling","lava","slime","world","void",""]:combat()
	for projectile in data.get("projectiles",[]):
		var owner:=int(projectile.get("owner",0))
		if actors.has(owner) and int(actors[owner].state.team)!=int(me.state.team) and me.position.distance_to(projectile.position)<18:combat()
func advance(delta: float) -> void:
	remaining=maxf(0,remaining-delta)
	var wanted:="menu" if menu else "combat" if remaining>0 and not safe and alive else ""
	# Fade the old cue completely before changing it; interrupted transitions cannot stack.
	var target:=music_volume*voice_duck if wanted==music_key and not wanted.is_empty() else 0.0
	music_gain=move_toward(music_gain,target,delta/(1.0 if target>music_gain else 3.0))
	if music_gain<=.0001 and music_key!=wanted:
		music.stop();music_key=wanted
		if not wanted.is_empty():music.stream=stream(wanted);music.play()
	if wanted.is_empty() and music_gain<=.0001:music.stop();music.stream=null
	music.volume_db=linear_to_db(maxf(.0001,music_gain))
	ambient_mix=minf(1,ambient_mix+delta/2.5)
	var bed:=0.0 if menu else ambience_volume*voice_duck*(.55 if remaining>0 else 1.0)
	ambience[ambient_slot].volume_db=linear_to_db(maxf(.0001,bed*sin(ambient_mix*PI*.5)))
	ambience[1-ambient_slot].volume_db=linear_to_db(maxf(.0001,bed*cos(ambient_mix*PI*.5)))
	if ambient_mix>=1:ambience[1-ambient_slot].stop();ambience[1-ambient_slot].stream=null
func _process(delta: float) -> void:advance(delta)
func _exit_tree() -> void:
	for player in ambience:player.stop();player.stream=null
	if is_instance_valid(music):music.stop();music.stream=null
	cache.clear()
func state() -> Dictionary:
	return {"menu":menu,"safe":safe,"combat":remaining>0,"remaining":remaining,"music":music_key,"music_gain":music_gain,"ambience":selected_ambience,"voices":int(music.playing)+int(ambience[0].playing)+int(ambience[1].playing)}
