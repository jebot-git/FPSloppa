extends "res://deathmatch/modes/match.gd"
## Unified jungle CQ; TDM is only the legacy team-mode carrier, not its scoring.
var objectives=preload("res://deathmatch/conquest/frontier/objectives.gd").new()
func setup(arena:Node) -> void:
	super.setup(arena);objectives.setup(arena)
func limit() -> int:return objectives.Points.LIMIT
func tick(delta:float) -> void:
	if not game.multiplayer.is_server() or game.intermission>0:return
	objectives.tick(delta)
func check_limit() -> void:
	if objectives.rules.winner!=-2 and game.intermission<=0:game._end_round()
func result() -> String:
	var winner:int=objectives.rules.winner
	return ("DRAW" if winner<0 else TEAMS[winner]+" WINS")+" · %d : %d"%scores
func draw_objectives() -> void:objectives.draw()
func configure(settings:Dictionary) -> void:
	var config:=settings.duplicate();config.sv_gametype="tdm";super.configure(config)
	if game.dedicated:Engine.physics_ticks_per_second=settings.get("sv_cq_tick_rate",60)
func killed(victim:int,attacker:int) -> void:
	if not game.multiplayer.is_server() or game.intermission>0:return
	fortress.walkers.departed(victim);drop(victim)
	if not game.players.has(attacker):return
	var enemy:bool=attacker!=victim and game.players.has(victim) and not same_team(victim,attacker) and game.players[victim].team in [0,1] and game.players[attacker].team in [0,1]
	game.players[attacker].kills+=1 if enemy else -1
	if enemy:
		game.classes.award(attacker,100);objectives.rules.kill(game.players[attacker].team)
		scores=objectives.rules.scores.duplicate();check_limit()
func status(id:int=0) -> String:
	if game.battery_tanks.mounted(id):
		var row:Dictionary=game.battery_tanks.rows[game.battery_tanks.key_for(id)]
		return "%s · %d HP · USE TO DISMOUNT"%[game.battery_tanks.profile(row).name,row.hp]
	var text:String="CQ · RED %d BLUE %d / 200"%scores+objectives.status(id)+game.classes.status(id)
	if game.players.has(id):
		var s:Dictionary=game.players[id];var ammo:int=game.armory.data(s.weapon).ammo
		if ammo>=0:
			var c:Dictionary=game.variant_combat.magazines.states.get(id,{})
			var loaded:int=c.get("clips",{}).get(s.weapon,game.armory.data(s.weapon).magazine)
			text+=" · %d LOADED / %d POUCH"%[loaded,maxi(0,s.ammo[ammo]-loaded)]
			var charge:Dictionary=game.variant_combat.charges.get(id,{})
			if not charge.is_empty():text+=" · CHARGING %.2fs"%maxf(0,charge.at-game.clock)
			if c.get("cycling",-1)>=0:text+=" · CHARGE RELOAD %.1fs"%maxf(0,c.cycle_at-game.clock)
			if c.get("reloading",-1)>=0:text+=" · RELOADING %.1fs"%maxf(0,c.reload_at-game.clock)
	if game.classes.states.get(id,{}).get("nv",false):text+=" · NVG "+("GLARE" if game.classes.states[id].get("nb",0)>game.clock else "ON")
	if game.recon_drone.alerts.get(id,{}).get("until",0.0)>game.clock and game.players.has(id) and game.recon_drone.alerts[id].life==game.players[id].serial:text+=" · RECON DETECTED"
	return text
func snapshot() -> Dictionary:
	var data:=super.snapshot()
	for zone in objectives.sites.size():data["cqo:"+str(zone)]={"owner":objectives.rules.owners[zone],"progress":objectives.rules.progress[zone].duplicate(),"contested":objectives.rules.contested[zone],"credit":objectives.rules.credit[zone]}
	data["cq_points"]={"scores":objectives.rules.scores.duplicate(),"winner":objectives.rules.winner}
	var common:Dictionary=game.classes.snapshot();common.erase("states")
	for pair in [["downed","cd:"],["injecting","ci:"],["dispensers","cb:"]]:
		for id in common[pair[0]]:data[pair[1]+str(id)]=common[pair[0]][id]
	for id in game.designations:data["cl:"+str(id)]=game.designations[id].duplicate(true)
	for key in game.recon_drone.flights:data["crd:"+str(key)]=game.recon_drone.flights[key].duplicate(true)
	for id in game.recon_drone.alerts:data["crw:"+str(id)]=game.recon_drone.alerts[id].duplicate(true)
	for id in game.recon_drone.marks:data["crs:"+str(id)]=game.recon_drone.marks[id].duplicate()
	for key in game.airstrike.flights:data["cas:"+str(key)]=game.airstrike.flights[key].duplicate(true)
	for id in game.airstrike.pending:data["cap:"+str(id)]=game.airstrike.pending[id].duplicate(true)
	for key in game.battery_tanks.rows:data["ctk:"+str(key)]=game.battery_tanks.rows[key].duplicate(true)
	for key in game.turrets.rows:data["ctu:"+str(key)]=game.turrets.rows[key].duplicate(true)
	for key in game.healing_field.fields:data["chf:"+str(key)]=game.healing_field.fields[key].duplicate(true)
	var grenades:Dictionary=game.grenades.snapshot()
	for id in grenades.inventory:data["cg:"+str(id)]=grenades.inventory[id]
	for shot in grenades.shots:data["ch:"+str(shot[0])]=shot
	data["class_mode"]={"clock":game.clock,"lighting_time":game.battle_map.lighting.cycle_time() if game.battle_map and game.battle_map.lighting else 0.0}
	var magazines:Dictionary=game.variant_combat.magazines.snapshot()
	# Individual records stay within the UDP budget at the 32-player district target.
	for id in game.classes.states:data["cp:"+str(id)]={"state":game.classes.states[id].duplicate(true),"mag":magazines.get(id,{}),"spot":game.spotting.spotted.get(id,[0.0,0.0]).duplicate(),"lock":game.variant_combat.vehicle_lock.locks.get(id,{}).duplicate(true),"charge":game.variant_combat.charges.get(id,{}).duplicate(true)}
	return data
func receive(data:Dictionary) -> void:
	super.receive(data)
	if game.multiplayer.is_server():return
	for zone in objectives.sites.size():
		var point:Dictionary=data.get("cqo:"+str(zone),{})
		if point.is_empty():continue
		objectives.rules.owners[zone]=point.owner;objectives.rules.progress[zone]=point.progress.duplicate();objectives.rules.contested[zone]=point.contested;objectives.rules.credit[zone]=point.credit
	var score:Dictionary=data.get("cq_points",{})
	if not score.is_empty():objectives.rules.scores=score.scores.duplicate();objectives.rules.winner=score.winner;scores=score.scores.duplicate()
	var common:Dictionary=data.get("class_mode",{}).duplicate(true)
	if game.battle_map and game.battle_map.lighting:game.battle_map.lighting.synchronize(common.get("lighting_time",0.0))
	var stamp:float=game.snapshot_view_time if game.snapshot_view_time>=0 else common.get("clock",game.clock)
	var offset:float=game.clock-stamp
	common["states"]={};common["downed"]={};common["injecting"]={};common["dispensers"]={};common["designations"]={}
	var grenades:Dictionary={"inventory":{},"shots":[],"smoke":[],"blind":{}}
	var magazines:Dictionary={}
	var tank_rows:Dictionary={}
	var turret_rows:Dictionary={}
	var healing:Dictionary={}
	var strikes:Dictionary={};var targeting:Dictionary={}
	var flights:Dictionary={};var alerts:Dictionary={};var marks:Dictionary={}
	game.spotting.spotted.clear()
	game.variant_combat.vehicle_lock.locks.clear();game.variant_combat.charges.clear()
	for key in data:
		if str(key).begins_with("ctk:"):tank_rows[str(key).trim_prefix("ctk:").to_int()]=data[key]
		if str(key).begins_with("ctu:"):turret_rows[str(key).trim_prefix("ctu:").to_int()]=data[key]
		if str(key).begins_with("chf:"):healing[str(key).trim_prefix("chf:").to_int()]=data[key]
		if str(key).begins_with("cas:"):strikes[str(key).trim_prefix("cas:").to_int()]=data[key]
		if str(key).begins_with("cap:"):targeting[str(key).trim_prefix("cap:").to_int()]=data[key]
		if str(key).begins_with("crd:"):flights[str(key).trim_prefix("crd:").to_int()]=data[key]
		if str(key).begins_with("crw:"):alerts[str(key).trim_prefix("crw:").to_int()]=data[key]
		if str(key).begins_with("crs:"):marks[str(key).trim_prefix("crs:").to_int()]=data[key]
		for pair in [["cd:","downed"],["ci:","injecting"],["cb:","dispensers"],["cl:","designations"]]:
			if str(key).begins_with(pair[0]):common[pair[1]][str(key).trim_prefix(pair[0]).to_int()]=data[key].duplicate(true)
		if str(key).begins_with("cg:"):grenades.inventory[str(key).trim_prefix("cg:").to_int()]=data[key]
		if str(key).begins_with("ch:"):grenades.shots.append(data[key])
		if not str(key).begins_with("cp:"):continue
		var id:int=str(key).trim_prefix("cp:").to_int();var row:Dictionary=data[key]
		var spot:Array=row.get("spot",[0.0,0.0]).duplicate()
		for team in 2:spot[team]+=offset
		game.spotting.spotted[id]=spot
		if not row.get("lock",{}).is_empty():game.variant_combat.vehicle_lock.locks[id]=row.lock.duplicate(true)
		if not row.get("charge",{}).is_empty():
			var charge:Dictionary=row.charge.duplicate(true);charge.at+=offset;game.variant_combat.charges[id]=charge
		var state:Dictionary=row.state.duplicate(true)
		if state.has("nb"):state.nb+=offset
		if state.has("turret_ready"):state.turret_ready+=offset
		if state.has("airstrike_ready"):state.airstrike_ready+=offset
		if state.has("drone_ready"):state.drone_ready+=offset
		state.cloak_until+=offset;state.cloak_ready+=offset;state.dispenser_ready+=offset;common.states[id]=state
		if not row.mag.is_empty():
			var mag:Dictionary=row.mag.duplicate(true);mag.reload_at+=offset;mag["cycle_at"]=mag.get("cycle_at",0.0)+offset;magazines[id]=mag
	game.battery_tanks.receive(tank_rows,offset)
	game.turrets.receive(turret_rows,offset)
	game.healing_field.receive(healing,offset)
	game.airstrike.receive(strikes,targeting,offset)
	game.recon_drone.receive(flights,alerts,marks,offset)
	game.classes.receive(common)
	game.grenades.receive(grenades)
	game.designations=common.get("designations",{}).duplicate(true)
	game.variant_combat.magazines.states=magazines
	for row in game.designations.values():row.until+=offset
func reset() -> void:
	super.reset();objectives.reset();scores=[0,0];game.recon_drone.reset();game.airstrike.reset();game.healing_field.reset();game.turrets.reset();game.battery_tanks.configure();game.spotting.spotted.clear();game.spotting.next_scan=0.0;game.classes.downed.clear();game.classes.injecting.clear();game.classes.dispensers.clear();game.supply_budgets.clear();game.designations.clear();game.grenades.new_round()
