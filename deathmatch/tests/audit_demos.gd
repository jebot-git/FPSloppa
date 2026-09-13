extends SceneTree
const Demo=preload("res://deathmatch/demos/session.gd")
func stats(values: Array) -> Dictionary:
	if values.is_empty():return {"count":0}
	values.sort()
	return {"count":values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"p99":values[mini(values.size()-1,int(values.size()*.99))],"max":values[-1]}
func _initialize():call_deferred("run")
func run() -> void:
	var reports: Array=[]
	var samples:=FileAccess.open("res://test-results/assault-movement.csv",FileAccess.WRITE);samples.store_csv_line(PackedStringArray(["demo","time","team","x","y","z","speed","weapon","stage","leg","attacking","dead"]))
	for name in DirAccess.get_files_at("/home/blux/Downloads/FPSloppa-Linux/demos"):
		if not name.ends_with(".fpsdemo"):continue
		var file:=FileAccess.open("/home/blux/Downloads/FPSloppa-Linux/demos/"+name,FileAccess.READ)
		var row:Dictionary={"file":name,"frames":0,"valid":true,"events":{},"shots_by_weapon":{},"offhand_shots":0,"map_modes":{},"peak_players":0,"movement_outliers":0,"teleport_events":0}
		if file.get_buffer(8).get_string_from_ascii()!=Demo.MAGIC:row.valid=false;reports.append(row);continue
		var previous:Dictionary={};var last_time:=-1.0;var first_time:=-1.0;var steps:Array=[];var speeds:Array=[];var pings:Array=[];var errors:Array=[];var yaw_deltas:Array=[];var gaps:=0
		while file.get_position()<file.get_length():
			if file.get_length()-file.get_position()<4:row.valid=false;row.failure="Truncated length header";break
			var size:=file.get_32()
			if size<=0 or size>Demo.MAX_FRAME or size>file.get_length()-file.get_position():row.valid=false;row.failure="Truncated or invalid payload";row.expected_bytes=size;row.remaining_bytes=file.get_length()-file.get_position();break
			var f=bytes_to_var(file.get_buffer(size))
			if not Demo.valid_frame(f) or float(f.time)<last_time:
				row.valid=false;row.failure="Invalid schema" if not Demo.valid_frame(f) else "Time moves backwards";row.failure_offset=file.get_position()-size;row.failure_time=f.get("time");row.remaining_bytes=file.get_length()-file.get_position()
				row.failure_events=f.get("events",[]).map(func(e):return [e[0],e[1].map(func(v):return type_string(typeof(v)))])
				row.failure_shape={"snapshot":f.get("snapshot",[]).size(),"roster":f.get("roster",[]).size()}
				break
			if first_time<0:first_time=f.time
			var dt:float=f.time-last_time if last_time>=0 else 0
			if dt>0:steps.append(dt*1000);gaps+=1 if dt>.1 else 0
			last_time=f.time;row.frames+=1;row.peak_players=maxi(row.peak_players,f.roster.size())
			var key:String=f.map+" / "+str(f.snapshot[10].get("kind","unknown"));row.map_modes[key]=int(row.map_modes.get(key,0))+1
			var teleported:=false
			for event in f.events:
				row.events[event[0]]=int(row.events.get(event[0],0))+1
				if event[0]=="_teleport_fx":teleported=true;row.teleport_events+=1
				if event[0]=="_shot_fx":
					var weapon:String=preload("res://deathmatch/weapons.gd").DATA[event[1][1]].name
					row.shots_by_weapon[weapon]=int(row.shots_by_weapon.get(weapon,0))+1
					if event[1][2]:row.offhand_shots+=1
			var current:Dictionary={}
			for p in f.snapshot[0]:
				current[p[0]]={"position":p[1],"velocity":p[2],"serial":p[14],"map":f.map,"dead":p[7],"yaw":p[3]}
				if f.map=="as_hislop":
					var objective:Dictionary=f.snapshot[10].get("assault",{});var roster: Array=f.roster.filter(func(r):return r[0]==p[0])
					samples.store_csv_line(PackedStringArray([name,str(f.time),str(roster[0][6] if not roster.is_empty() else -1),str(p[1].x),str(p[1].y),str(p[1].z),str(Vector2(p[2].x,p[2].z).length()),str(p[8]),str(objective.get("stage",0)),str(objective.get("leg",0)),str(objective.get("attacking",0)),str(p[7])]))
				if p[7] or p[20] or f.map=="__waiting_lobby__":continue
				pings.append(p[13]);speeds.append(Vector2(p[2].x,p[2].z).length())
				if not previous.has(p[0]) or dt<=0 or dt>.2 or teleported:continue
				var old:Dictionary=previous[p[0]]
				if old.serial!=p[14] or old.map!=f.map or old.dead:continue
				var displacement:Vector3=p[1]-old.position
				var expected:Vector3=(old.velocity+p[2])*.5*dt
				var error:float=(displacement-expected).length()
				errors.append(error);yaw_deltas.append(absf(angle_difference(old.yaw,p[3])))
				if error>.5:row.movement_outliers+=1
			previous=current
		row.duration_seconds=last_time-first_time;row.frame_interval_ms=stats(steps);row.snapshot_gaps_over_100ms=gaps;row.horizontal_speed_mps=stats(speeds);row.ping_ms=stats(pings);row.position_velocity_residual_m=stats(errors);row.yaw_step_rad=stats(yaw_deltas)
		file.close();reports.append(row);print("DEMO_AUDIT ",JSON.stringify(row))
	samples.close()
	var output:=FileAccess.open("res://test-results/live-demo-analysis.json",FileAccess.WRITE);output.store_string(JSON.stringify(reports,"  "));output.close();quit()
