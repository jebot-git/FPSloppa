extends "res://deathmatch/experimental/combat.gd"
var salvos:Dictionary={}
var magazines=preload("res://deathmatch/conquest/classes/magazines.gd").new()
func setup(arena) -> void:super.setup(arena);magazines.setup(arena)
func tick_input(id:int,delta:float) -> void:
	var s:Dictionary=game.players[id]
	if not game.classes.alive(id) or game.intermission>0 or game.lobby.active():salvos.erase(id);return
	if salvos.has(id) and salvos[id].at<=game.clock:
		if s.weapon!=5 or s.serial!=salvos[id].life:salvos.erase(id)
		else:
			launch_blast(id);salvos[id].left-=1;salvos[id].at=game.clock+.15
			if salvos[id].left<=0:salvos.erase(id)
	if game.grenades.selected(id)>=0:return
	if s.fire or s.get("alt_fire",false):game.classes.weapon_used(id)
	if s.weapon in [6,7,8]:
		if s.fire and not s.get("input_blocked",false) and game.clock-s.last_input<=.35:
			if s.weapon==6:game.deploy_class_box(id)
			elif s.weapon==8:game.designate(id)
		return
	if not magazines.tick(id):return
	if s.weapon==5:
		if s.fire and s.cooldown<=0 and s.ammo[2]>=3 and magazines.loaded(id)>=3 and not s.get("input_blocked",false) and not game._shot_solution(id).blocked:
			s.ammo[2]-=3;magazines.consume(id,3);s.cooldown=1.0;launch_blast(id)
			salvos[id]={"left":2,"at":game.clock+.15,"life":s.serial}
		return
	var before:int=s.ammo[game.armory.data(s.weapon).ammo]
	super.tick_input(id,delta)
	if s.ammo[game.armory.data(s.weapon).ammo]<before:magazines.consume(id)
func launch_blast(id:int) -> void:
	var solution:Dictionary=game._shot_solution(id)
	if solution.blocked:return
	var direction:Vector3=-game._weapon_transform(id).basis.z
	launch(id,5,solution.origin,direction,{"guided_team":game.players[id].team})
	game._variant_shot_fx.rpc(id,5,false)
func launch(owner_id:int,weapon:int,position:Vector3,direction:Vector3,extra:Dictionary={}) -> int:
	var tagged:=extra.duplicate();tagged["cq_team"]=game.players.get(owner_id,{}).get("team",0)
	return super.launch(owner_id,weapon,position,direction,tagged)
func predict(id:int,command:Dictionary) -> void:
	if command.weapon in [6,7,8] or game.classes.downed.has(id):return
	super.predict(id,command)
func reset() -> void:super.reset();salvos.clear();magazines.states.clear()
func definition(owner_id:int,weapon:int,extra:Dictionary) -> Dictionary:
	var data:Dictionary=super.definition(owner_id,weapon,extra)
	if weapon in [4,5]:
		data.cq_effect="energy" if weapon==4 else "ordnance"
		var team:int=extra.get("cq_team",game.players.get(owner_id,{}).get("team",0))
		data.color=Color("ff3c39") if team==0 else Color("3b8dff")
	return data
