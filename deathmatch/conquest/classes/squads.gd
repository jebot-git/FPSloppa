extends Node
## Client presentation and voice routing over native, life-bound squad state.
const NAMES=["ALPHA","BRAVO","CHARLIE","DELTA"]
var game
var roster:Dictionary={}
var screen
var death_life:=-1
var previous:Dictionary={}
var map_epoch:=-1
func setup(arena)->void:game=arena
func setup_ui(hud)->void:
	screen=preload("res://deathmatch/ui/cq/deployment.gd").new();screen.setup(game,hud,self)
func membership(id:int)->int:
	if game.resident.serving():return roster.get(id,-1)
	var state:Dictionary=game.classes.states.get(id,{})
	var squad:int=state.get("squad",-1)
	var team:int=game.resident.client_frame.get("players",{}).get(id,{}).get("team",game.players.get(id,{}).get("team",-1))
	return team*4+squad if squad in range(4) and team in [0,1] else -1
func same_squad(a:int,b:int)->bool:
	var first:=membership(a);return first>=0 and first==membership(b)
func local()->Dictionary:return game.resident.client_frame.get("players",{}).get(game.multiplayer.get_unique_id(),{})
func frame()->Dictionary:return game.resident.client_frame
func count(team:int,squad:int)->int:
	var total:=0
	for id in game.players:total+=int(membership(id)==team*4+squad)
	return total
func join(squad:int)->void:game.resident.request(11,squad)
func open_map()->void:
	if not screen:return
	game.menu_open=true;game.hud.show_menu(true);game.hud.menu_pages.navigate("cq_deployment");screen.refresh()
func reason(kind:int,target:int=0,life:int=0)->String:
	var mine:=local();var f:=frame()
	if mine.is_empty():return "Join a native CQ match to deploy."
	if mine.get("squad",-1)<0:return "Join a squad first."
	if not mine.dead and not mine.get("staging",false):return "Deployment is available after death."
	if mine.dead and mine.respawn_at>f.mode.time:return "Reinforcements in %.1fs"%(mine.respawn_at-f.mode.time)
	if f.mode.winner!=-2:return "Round complete."
	if game.loadout_menu.pending and not game.loadout_menu.calibration_confirmed:return "Confirm avatar alignment before deploying."
	if kind==1:
		if target<0 or target>=f.mode.zones.size():return "Select a capture point."
		var zone:Dictionary=f.mode.zones[target]
		if zone.owner!=mine.team:return "This POI is not controlled by your team."
		if zone.contested:return "This POI is contested."
	elif kind==2:
		var buddy:Dictionary=f.players.get(target,{})
		if buddy.is_empty() or buddy.life!=life:return "Squad member unavailable."
		if target==game.multiplayer.get_unique_id() or buddy.team!=mine.team or buddy.get("squad",-1)!=mine.squad:return "Select a squad member."
		if buddy.dead or buddy.incapacitated or buddy.staging:return "Squad member is not active."
		if buddy.get("combat_until",0.)>f.mode.time:return "Squad member in combat · %.0fs"%ceilf(buddy.combat_until-f.mode.time)
		if buddy.vehicle>=0:
			var vehicle:Dictionary={}
			for row in f.get("vehicles",{}).values():
				if row.index==buddy.vehicle:vehicle=row;break
			if vehicle.is_empty() or vehicle.kind!=3:return "Cannot spawn on tank drivers."
			if vehicle.hp<=0 or vehicle.team!=mine.team:return "Transport unavailable."
			var occupied:=0
			for row in f.players.values():occupied+=int(row.vehicle==buddy.vehicle and row.get("vehicle_seat",-1)!=6)
			if occupied>=7:return "Transport is full."
	elif kind!=0:return "Select a deployment point."
	return ""
func spawn(kind:int,target:int=0,life:int=0)->bool:
	if not reason(kind,target,life).is_empty():return false
	game.resident.request(12,kind,target,life);return true
func _process(_delta:float)->void:
	if not game or not game.active:previous.clear();death_life=-1;roster.clear();return
	if map_epoch!=game.map_epoch:previous.clear();death_life=-1;map_epoch=game.map_epoch
	if game.headless:return
	var current:=local()
	if current.is_empty():return
	if not previous.is_empty() and current.staging and (not previous.get("staging",false) or current.life!=previous.life):open_map()
	if current.dead and current.life!=death_life:
		death_life=current.life;open_map()
	if not previous.is_empty() and (previous.get("staging",false) or previous.dead) and not current.dead and not current.staging:
		game.loadout_menu.pending=false;game.menu_open=false;game.hud.show_menu(false)
	previous=current
