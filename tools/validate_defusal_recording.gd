extends SceneTree
## Validate every recorded roster/state and seek through a completed 6v6 match.
const Demo=preload("res://deathmatch/demos/session.gd")
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:push_error("Pass match.fpsdemo after --");quit(2);return
	var path: String=args[0];var input:=FileAccess.open(path,FileAccess.READ)
	if not input or input.get_buffer(8).get_string_from_ascii()!=Demo.MAGIC:quit(1);return
	var frames:=0;var failures: Array=[];var last: Dictionary={};var planted:=0;var rounds: Dictionary={};var teams: Dictionary={};var dead_frames:=0;var map_id:="";var roles: Dictionary={};var grenades: Dictionary={}
	var thrown: Dictionary={};var smoke_frames:=0;var flash_frames:=0;var sites: Dictionary={};var defuse_frames:=0
	while input.get_position()<input.get_length():
		var length:=input.get_32()
		if length<1 or length>Demo.MAX_FRAME or input.get_position()+length>input.get_length():failures.append("Incomplete frame");break
		var frame=bytes_to_var(input.get_buffer(length))
		if not Demo.valid_frame(frame):failures.append("Invalid frame "+str(frames));break
		if map_id.is_empty():map_id=frame.map
		if frame.map!=map_id or not frame.map in preload("res://deathmatch/modes/defusal_maps.gd").IDS or frame.snapshot[10].kind!="de":failures.append("Wrong map/mode");break
		var counts: Array=[0,0]
		for row in frame.roster:
			if row[5]:continue
			if row[0]>=0:failures.append("Non-bot player");break
			counts[row[6]]+=1
			if teams.has(row[0]) and teams[row[0]]!=row[6]:failures.append("Bot changed team identity");break
			teams[row[0]]=row[6]
		if counts!=[6,6]:failures.append("Roster is not 6v6 at frame "+str(frames));break
		var de: Dictionary=frame.snapshot[10].defusal
		roles[de.round]=de.attacking
		var utility: Dictionary=de.get("utility",{})
		for shot in utility.get("shots",[]):thrown[str(de.round)+":"+str(shot[0])]=shot[1]
		if not utility.get("smoke",[]).is_empty():smoke_frames+=1
		if not utility.get("blind",{}).is_empty():flash_frames+=1
		if de.planted:sites[str(de.site)]=true
		if de.defuser!=0:defuse_frames+=1
		for event in frame.events:
			if event[0]=="_de_grenade_fx":grenades[str(event[1][1])]=int(grenades.get(str(event[1][1]),0))+1
		rounds[de.round]=true
		if de.planted:planted+=1
		if frame.snapshot[0].any(func(row):return row[7] and not row[20]):dead_frames+=1
		last=frame;frames+=1
	input.close()
	if last.is_empty() or last.snapshot[10].defusal.phase!="finished":failures.append("Match did not finish")
	var receipt_path:=path.get_base_dir()+"/match.json"
	if FileAccess.file_exists(receipt_path):
		var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
		if receipt.get("format","")=="six rounds, sides swapped after three":
			if rounds.keys().filter(func(id):return id>0).size()!=6 or roles.get(3)!=0 or roles.get(4)!=1:failures.append("Six-round format or halftime mismatch")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var playback: bool=g.demos.open_demo(path)
	if playback:
		for fraction in [0.0,.25,.5,.75,1.0]:g.demos.seek(g.demos.duration*fraction)
	else:failures.append("Playback: "+g.demos.message)
	var result:={"passed":failures.is_empty(),"failures":failures,"map":map_id,"frames":frames,"seconds":last.get("time",0),"rounds":rounds.keys().filter(func(id):return id>0).size(),"roles_by_round":roles,"grenade_events":grenades,"players":teams.size(),"planted_frames":planted,"dead_player_frames":dead_frames,"playback_and_seeking":playback,"scores":last.get("snapshot",[[],[],0,0,"",0,0,[],[],0,{},{}])[10].get("scores",[])}
	result.utility={"HE":thrown.values().count(0),"flash":thrown.values().count(1),"smoke":thrown.values().count(2),"smoke_frames":smoke_frames,"flash_frames":flash_frames};result.planted_sites=sites.keys();result.defuse_frames=defuse_frames
	FileAccess.open(path.get_base_dir()+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_RECORD_VALIDATION ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
