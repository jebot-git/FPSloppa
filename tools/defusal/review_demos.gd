extends SceneTree
## Read the original match states without substituting current map assets.
func _initialize():
	var results: Array=[]
	for map in preload("res://deathmatch/modes/defusal_maps.gd").IDS:
		var f:=FileAccess.open("res://recordings/de-map-series-2026-09-26/"+map+"/match.fpsdemo",FileAccess.READ)
		assert(f.get_buffer(8).get_string_from_ascii()=="FPSDEMO1")
		var stranded: Dictionary={};var episodes: Array=[];var previous:=0.0
		while f.get_position()<f.get_length():
			var frame: Dictionary=bytes_to_var(f.get_buffer(f.get_32()))
			var de: Dictionary=frame.snapshot[10].defusal
			var dt: float=frame.time-previous;previous=frame.time
			for row in frame.snapshot[0]:
				var id: int=row[0];var point: Vector3=row[1]
				var held_away: bool=de.phase=="live" and not row[7] and de.carrier==id and de.held and de.sites.all(func(p):return point.distance_to(p)>2)
				var cutters_away: bool=de.phase=="live" and not row[7] and de.accounts.get(id,[0,false,false,false])[3] and point.distance_to(de.position)>2
				if held_away or cutters_away:
					if not stranded.has(id):stranded[id]={"id":id,"round":de.round,"start":frame.time,"duration":0.0,"cause":"held bomb away from site" if held_away else "cutters away from bomb"}
					stranded[id].duration+=dt
				elif stranded.has(id):
					if stranded[id].duration>.5:episodes.append(stranded[id])
					stranded.erase(id)
		f.close()
		results.append({"map":map,"holstered_away_from_objective":episodes})
		print("DE_DEMO_REVIEW ",map," ",JSON.stringify(episodes))
	FileAccess.open("res://test-results/de-bot-review/demo-audit.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "));quit()
