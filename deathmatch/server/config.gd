extends RefCounted
const MODES := ["dm","tdm","ctf","koth","ig","if","ft","cc","tf","tb","as"]
const MAX_CLIENTS := 32
const CAPACITY_WARNING := "UNSUPPORTED PLAYER COUNT: more than 16 players is unsupported. Performance, gameplay and maps are not balanced for player limits higher than 16."
const DEFAULTS={"sv_weapon_rules":"doom","sv_lobby":0,"sv_lobby_seconds":45,"sv_hostname":"FPSloppa","net_ip":"*","net_port":7777,"sv_maxclients":8,"fraglimit":20,"timelimit":10,"sv_log_level":"normal","sv_log_file":"","sv_log_max_mb":8,"sv_log_backups":3,"sv_voice":1,"sv_tf_spy_invisibility":0,"sv_announcer":1,"sv_voice_backend":"builtin","sv_mumble_url":"","sv_votes":1,"sv_map_uploads":1,"map":"qsrc_dm1","sv_maplist":"","sv_gametype":"dm","sv_gametypes":"","sv_friendlyfire":0,"capturelimit":5,"hilllimit":120,"rcon_password":"","rcon_port":7778,"rcon_bind":"127.0.0.1","dm_maplist":"","tdm_maplist":"","ctf_maplist":"","koth_maplist":"","ig_maplist":"","ft_maplist":"","cc_maplist":"","tf_maplist":"","tb_maplist":"","as_maplist":""}
const RANGES={"rcon_port":Vector2i(1024,65535),"sv_lobby":Vector2i(0,1),"sv_lobby_seconds":Vector2i(15,180),"sv_map_uploads":Vector2i(0,1),"sv_log_max_mb":Vector2i(1,512),"sv_log_backups":Vector2i(1,9),"sv_friendlyfire":Vector2i(0,1),"capturelimit":Vector2i(1,100),"hilllimit":Vector2i(1,3600),"net_port":Vector2i(1024,65535),"sv_maxclients":Vector2i(1,MAX_CLIENTS),"fraglimit":Vector2i(1,100),"timelimit":Vector2i(1,60),"sv_votes":Vector2i(0,1),"sv_tf_spy_invisibility":Vector2i(0,1),"sv_announcer":Vector2i(0,1),"sv_voice":Vector2i(0,1)}

static func parse(source: String) -> Dictionary:
	var values:=DEFAULTS.duplicate()
	var line_number:=0
	for raw in source.split("\n"):
		line_number+=1
		var lex:=tokens(raw)
		if lex.has("error"): return {"error":"Line %d: %s"%[line_number,lex.error]}
		var words: Array=lex.words
		if words.is_empty(): continue
		var key: String
		var value: String
		if words[0] in ["set","seta","sets"] and words.size()==3:
			key=words[1]; value=words[2]
		elif words[0]=="map" and words.size()==2:
			key="map"; value=words[1]
		else: return {"error":"Line %d: expected set/seta/sets <name> <value>, or map <id>."%line_number}
		# Retired option: keep old server.cfg files loadable, with a fixed hill.
		if key=="koth_move_points":continue
		if not DEFAULTS.has(key): return {"error":"Line %d: unsupported setting %s."%[line_number,key]}
		if RANGES.has(key):
			if not value.is_valid_int(): return {"error":"Line %d: %s requires an integer."%[line_number,key]}
			var number:=value.to_int()
			if number<RANGES[key].x or number>RANGES[key].y: return {"error":"Line %d: %s is out of range."%[line_number,key]}
			values[key]=number
		else:
			if (value.is_empty() and not key.ends_with("_maplist") and not key in ["sv_maplist","sv_mumble_url","sv_gametypes","sv_log_file","rcon_password"]) or value.length()>(2048 if key.ends_with("_maplist") else 512 if key in ["sv_mumble_url","sv_log_file"] else 80): return {"error":"Line %d: empty or excessive value."%line_number}
			values[key]=value
	if not values.sv_weapon_rules in ["doom","quake","ut99"]:return {"error":"sv_weapon_rules must be doom, quake or ut99."}
	values.sv_gametype=str(values.sv_gametype).to_lower()
	if values.sv_gametype=="tb":values.timelimit=10
	if not values.sv_gametype in MODES:return {"error":"sv_gametype must be dm, tdm, ctf, koth, ig, if, ft, cc, tf, tb or as."}
	if not values.sv_voice_backend in ["builtin","mumble"]:return {"error":"sv_voice_backend must be builtin or mumble."}
	if values.sv_voice_backend=="mumble" and not preload("res://deathmatch/voice/external.gd").valid_url(values.sv_mumble_url):return {"error":"Mumble requires a valid mumble://host:port/channel URL without credentials."}
	var modes:=str(values.sv_gametypes).to_lower().split(" ",false)
	if modes.is_empty():modes=PackedStringArray([values.sv_gametype])
	if modes.size()>MODES.size() or not Array(modes).all(func(mode):return mode in MODES) or not modes.has(values.sv_gametype):return {"error":"sv_gametypes must list valid modes and include sv_gametype."}
	values["gametypes"]=[]
	for mode in modes:
		if not values.gametypes.has(mode):values.gametypes.append(mode)
	if not values.sv_log_level in ["off","normal","verbose"]:return {"error":"sv_log_level must be off, normal or verbose."}
	var maps:=str(values.sv_maplist).split(" ",false)
	if maps.size()>32: return {"error":"sv_maplist supports at most 32 maps."}
	values["maps"]=Array(maps) if not maps.is_empty() else [values.map]
	values["mode_maps"]={}
	for mode in ["dm","tdm","ctf","koth","ig","ft","cc","tf","tb","as"]:
		var specific:=str(values[mode+"_maplist"]).split(" ",false)
		if specific.size()>32:return {"error":mode+"_maplist supports at most 32 maps."}
		values.mode_maps[mode]=Array(specific)
	# IF shares IG configuration; no second maplist can drift out of sync.
	values.mode_maps["if"]=values.mode_maps.ig
	return {"values":values}

static func tokens(line: String) -> Dictionary:
	var words: Array=[]
	var word:=""
	var quoted:=false
	var started:=false
	var i:=0
	while i<line.length():
		var c:=line[i]
		if not quoted and (c=="#" or (c=="/" and i+1<line.length() and line[i+1]=="/")): break
		if c=='"': quoted=not quoted; started=true
		elif c=="\\" and quoted and i+1<line.length() and line[i+1] in ['"',"\\"]:
			i+=1; word+=line[i]
		elif not quoted and c in [" ","\t","\r"]:
			if started: words.append(word); word=""; started=false
		elif not quoted and c==";": return {"error":"Semicolon commands are not supported."}
		else: word+=c; started=true
		i+=1
	if quoted: return {"error":"Unclosed quote."}
	if started: words.append(word)
	return {"words":words}

static func read_config(path: String) -> Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if not f: return {"error":"Cannot read server config: "+path}
	if f.get_length()>65536: return {"error":"Server config exceeds 64 KiB."}
	return parse(f.get_as_text())
