extends SceneTree
const Demo=preload("res://deathmatch/demos/session.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var file:=FileAccess.open(args[0],FileAccess.READ)
	var result: Dictionary={"valid":true,"frames":0,"duration":0.0,"peak_players":0,"segments":[],"events":{},"gaps_over_100ms":0}
	if file.get_buffer(8).get_string_from_ascii()!=Demo.MAGIC:quit(2);return
	var previous:=-1.0
	while file.get_position()<file.get_length():
		if file.get_position()+4>file.get_length():result.valid=false;break
		var size:=file.get_32()
		if size<1 or size>Demo.MAX_FRAME or size>file.get_length()-file.get_position():result.valid=false;break
		var frame=bytes_to_var(file.get_buffer(size))
		if not Demo.valid_frame(frame) or frame.time<previous:result.valid=false;break
		if previous>=0 and frame.time-previous>.1:result.gaps_over_100ms+=1
		previous=frame.time;result.duration=frame.time;result.frames+=1;result.peak_players=maxi(result.peak_players,frame.roster.size())
		var mode: String=frame.snapshot[10].get("kind","")
		if result.segments.is_empty() or result.segments[-1].mode!=mode:
			result.segments.append({"mode":mode,"map":frame.map,"rules":frame.snapshot[10].get("weapon_rules","doom"),"start":frame.time,"end":frame.time,"frames":0,"peak_players":0,"shots":0,"teleports":0,"maximum_as_leg":0,"maximum_as_stage":0,"players":{},"avatars":frame.avatars.size()})
		var segment: Dictionary=result.segments[-1];segment.end=frame.time;segment.frames+=1;segment.peak_players=maxi(segment.peak_players,frame.roster.size())
		var assault: Dictionary=frame.snapshot[10].get("assault",{})
		segment.maximum_as_leg=maxi(segment.maximum_as_leg,assault.get("leg",0));segment.maximum_as_stage=maxi(segment.maximum_as_stage,assault.get("stage",0))
		for p in frame.snapshot[0]:
			if p[20]:continue
			if not segment.players.has(p[0]):segment.players[p[0]]={"distance":0.0,"last":p[1],"serial":p[14],"kills":0,"deaths":0,"weapons":{},"ping_max":0}
			var row: Dictionary=segment.players[p[0]]
			if row.serial==p[14] and row.last.distance_to(p[1])<3:row.distance+=row.last.distance_to(p[1])
			row.last=p[1];row.serial=p[14];row.kills=p[11];row.deaths=p[12];row.weapons[str(p[8])]=true;row.ping_max=maxi(row.ping_max,p[13])
		for event in frame.events:
			result.events[event[0]]=int(result.events.get(event[0],0))+1
			if event[0] in ["_shot_fx","_variant_shot_fx"]:segment.shots+=1
			if event[0]=="_teleport_fx":segment.teleports+=1
	file.close()
	for segment in result.segments:
		for row in segment.players.values():row.erase("last");row.erase("serial");row.weapons=row.weapons.keys()
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEMO_AUDIT valid=",result.valid," frames=",result.frames," duration=",result.duration," modes=",result.segments.size()," peak=",result.peak_players)
	quit(0 if result.valid else 2)
