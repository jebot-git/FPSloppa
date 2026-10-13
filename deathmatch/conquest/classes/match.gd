extends "res://deathmatch/modes/match.gd"
## CQ frontier prototype uses team scoring while its new objectives are authored.
func configure(settings:Dictionary) -> void:
	var config:=settings.duplicate();config.sv_gametype="tdm";super.configure(config)
func killed(victim:int,attacker:int) -> void:
	if attacker!=victim and game.players.has(attacker) and not same_team(victim,attacker):game.classes.award(attacker,100)
	super.killed(victim,attacker)
func status(id:int=0) -> String:
	var text:String=super.status(id).replace("TDM","CQ")+game.classes.status(id)
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
	return text
func snapshot() -> Dictionary:
	var data:=super.snapshot()
	var common:Dictionary=game.classes.snapshot();common.erase("states")
	for pair in [["downed","cd:"],["injecting","ci:"],["dispensers","cb:"]]:
		for id in common[pair[0]]:data[pair[1]+str(id)]=common[pair[0]][id]
	for id in game.designations:data["cl:"+str(id)]=game.designations[id].duplicate(true)
	var grenades:Dictionary=game.grenades.snapshot()
	for id in grenades.inventory:data["cg:"+str(id)]=grenades.inventory[id]
	for shot in grenades.shots:data["ch:"+str(shot[0])]=shot
	data["class_mode"]={"clock":game.clock}
	var magazines:Dictionary=game.variant_combat.magazines.snapshot()
	# Individual records stay within the UDP budget at the 32-player district target.
	for id in game.classes.states:data["cp:"+str(id)]={"state":game.classes.states[id].duplicate(true),"mag":magazines.get(id,{}),"spot":game.spotting.spotted.get(id,[0.0,0.0]).duplicate(),"lock":game.variant_combat.vehicle_lock.locks.get(id,{}).duplicate(true),"charge":game.variant_combat.charges.get(id,{}).duplicate(true)}
	return data
func receive(data:Dictionary) -> void:
	super.receive(data)
	if game.multiplayer.is_server():return
	var common:Dictionary=data.get("class_mode",{}).duplicate(true)
	var stamp:float=game.snapshot_view_time if game.snapshot_view_time>=0 else common.get("clock",game.clock)
	var offset:float=game.clock-stamp
	common["states"]={};common["downed"]={};common["injecting"]={};common["dispensers"]={};common["designations"]={}
	var grenades:Dictionary={"inventory":{},"shots":[],"smoke":[],"blind":{}}
	var magazines:Dictionary={}
	game.spotting.spotted.clear()
	game.variant_combat.vehicle_lock.locks.clear();game.variant_combat.charges.clear()
	for key in data:
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
		state.cloak_until+=offset;state.cloak_ready+=offset;state.dispenser_ready+=offset;common.states[id]=state
		if not row.mag.is_empty():
			var mag:Dictionary=row.mag.duplicate(true);mag.reload_at+=offset;mag["cycle_at"]=mag.get("cycle_at",0.0)+offset;magazines[id]=mag
	game.classes.receive(common)
	game.grenades.receive(grenades)
	game.designations=common.get("designations",{}).duplicate(true)
	game.variant_combat.magazines.states=magazines
	for row in game.designations.values():row.until+=offset
func reset() -> void:
	super.reset();game.spotting.spotted.clear();game.spotting.next_scan=0.0;game.classes.downed.clear();game.classes.injecting.clear();game.classes.dispensers.clear();game.designations.clear();game.grenades.new_round()
