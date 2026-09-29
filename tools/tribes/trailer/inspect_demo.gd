extends SceneTree
func _initialize():
	var args:=OS.get_cmdline_user_args()
	var file:=FileAccess.open(args[0],FileAccess.READ)
	assert(file.get_buffer(8).get_string_from_ascii()=="FPSDEMO1")
	var frames: Array=[];var events: Array=[];var next:=0.0
	while file.get_position()+4<=file.get_length():
		var size:=file.get_32()
		if size<1 or size>2097152 or file.get_position()+size>file.get_length():break
		var f: Dictionary=bytes_to_var(file.get_buffer(size))
		for e in f.events:events.append([f.time,e[0],e[1]])
		if f.time<next:continue
		next=f.time+.1
		var players: Array=[]
		for p in f.snapshot[0]:players.append({"id":p[0],"p":[p[1].x,p[1].y,p[1].z],"v":[p[2].x,p[2].y,p[2].z],"hp":p[5],"dead":p[7],"weapon":p[8],"team":f.roster.filter(func(r):return r[0]==p[0])[0][6]})
		frames.append({"t":f.time,"players":players,"mode":f.snapshot[10]})
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify({"frames":frames,"events":events}))
	print("INSPECTED ",frames.size()," frames; ",events.size()," events; end ",frames.back().t)
	quit()
