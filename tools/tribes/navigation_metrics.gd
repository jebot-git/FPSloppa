extends RefCounted
## Passive measurements of normal server motion. Never changes bot inputs.
var game
var output: String
var previous: Dictionary={}
var history: Dictionary={}
var totals: Dictionary={"travel_seconds":0.0,"slow_seconds":0.0,"ground_down_seconds":0.0,"down_ski_seconds":0.0,"ground_up_seconds":0.0,"up_walk_or_jet_seconds":0.0,"liftoffs":0,"ski_liftoffs":0,"fast_ski_liftoffs":0,"collision_losses":0,"reversals":0}
var events: FileAccess
var traces: FileAccess
var sample_at:=0.0
func setup(value,folder: String):
	game=value;output=folder
	events=FileAccess.open(folder+"/navigation-events.jsonl",FileAccess.WRITE)
	traces=FileAccess.open(folder+"/navigation.jsonl",FileAccess.WRITE)
func tick():
	for id in game.bots.brains:
		if not game.bots.alive(id):previous.erase(id);continue
		var b: Dictionary=game.bots.brains[id];var s: Dictionary=game.players[id];var a=game.fighters[id]
		var travelling: bool=b.goal_key in ["st:flag","st:capture","st:intercept","st:return","st:hold"] and a.position.distance_to(b.goal)>8
		var velocity:=Vector3(a.velocity.x,0,a.velocity.z);var speed:=velocity.length();var grounded: bool=a.is_supported()
		var wish:=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
		var slope: float=a.tribes_state.normal.dot(velocity.normalized() if speed>1 else wish.normalized())
		var row:={"seconds":game.clock,"id":id,"serial":s.serial,"team":s.team,"class":s.tribes_class,"goal":b.goal_key,"position":a.position,"velocity":a.velocity,"speed_kmh":speed*3.6,"energy":a.tribes_state.energy,"grounded":grounded,"ski":s.ski,"jet":s.jet_held,"jump":s.jump,"slope":slope,"phase":b.get("travel_phase",""),"target":b.goal,"waypoint":b.path[b.step] if b.step<b.path.size() else b.goal,"tower_phase":b.get("tower",{}).get("phase",""),"tower_stage":b.get("tower",{}).get("stage",Vector3.ZERO)}
		var old: Dictionary=previous.get(id,{})
		if not old.is_empty() and old.serial==s.serial and travelling:
			var dt: float=game.clock-old.seconds
			totals.travel_seconds+=dt
			if speed<2:totals.slow_seconds+=dt
			if grounded and slope>.035:
				totals.ground_down_seconds+=dt
				if s.ski:totals.down_ski_seconds+=dt
			if grounded and slope<-.035:
				totals.ground_up_seconds+=dt
				if not s.ski or s.jet_held:totals.up_walk_or_jet_seconds+=dt
			if old.grounded and not grounded and (s.jet_held or s.jump):
				totals.liftoffs+=1;var launch: Dictionary=row.duplicate();launch.kind="liftoff";launch.entry_kmh=old.speed_kmh
				launch.ski_approach=game.clock-float(history.get(id,{}).get("ski_at",-100))<.4
				if launch.ski_approach:totals.ski_liftoffs+=1
				if launch.ski_approach and old.speed_kmh>game.match_mode.tribes.definition(id).walk*3.6*1.3:totals.fast_ski_liftoffs+=1
				events.store_line(JSON.stringify(launch))
			if old.speed_kmh>36 and speed*3.6<old.speed_kmh*.65:
				totals.collision_losses+=1;var loss: Dictionary=row.duplicate();loss.kind="abrupt_speed_loss";loss.entry_kmh=old.speed_kmh;events.store_line(JSON.stringify(loss))
			if Vector2(old.velocity.x,old.velocity.z).length()>4 and speed>4 and velocity.normalized().dot(Vector3(old.velocity.x,0,old.velocity.z).normalized())<-.5:totals.reversals+=1
		if not history.has(id) or history[id].serial!=s.serial:history[id]={"serial":s.serial}
		if grounded and s.ski:history[id].ski_at=game.clock
		if game.clock>=sample_at:traces.store_line(JSON.stringify(row))
		previous[id]=row
	if game.clock>=sample_at:sample_at=game.clock+1
func finish():
	events.flush();traces.flush()
	FileAccess.open(output+"/navigation-summary.json",FileAccess.WRITE).store_string(JSON.stringify(totals,"  "))
