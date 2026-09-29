extends Node
## Server-authoritative Tribes inventory, respawns and finite team reserves.
const Armour=preload("res://deathmatch/movement/tribes_armour.gd")
const Arsenal=preload("res://deathmatch/tribes/arsenal.gd")
const CLASSES=Armour.CLASSES
var vehicles=preload("res://deathmatch/vehicles/tribes/controller.gd").new()
var deployables=preload("res://deathmatch/tribes/deployables.gd").new()
var recovery=preload("res://deathmatch/tribes/recovery.gd").new()
var targeting=preload("res://deathmatch/tribes/targeting.gd").new()
var remote=preload("res://deathmatch/tribes/remote_control.gd").new()
var commander=preload("res://deathmatch/tribes/command_state.gd").new()
var command_view
var order_sequence:=0
var field_view
var field_sequence:=0
var field_requests: Dictionary={}
var turret_view
var deployable_view
var combat=preload("res://deathmatch/tribes/combat.gd").new()
const INITIAL_ENERGY:=5000
const MAX_TEAM_ENERGY:=700000
const REPLENISH:=700
const REPLENISH_SECONDS:=30.0
var mode
var game
var energy: Array=[INITIAL_ENERGY,INITIAL_ENERGY,INITIAL_ENERGY] # red, blue, FFA
var infinite_energy:=false
var credit:=0.0
var requests: Dictionary={}
var panel: CanvasLayer
var local_station:=-1
var funded_slots: Array=[1,1,1]
func setup(rules) -> void:mode=rules;game=rules.game;remote.setup(self);commander.setup(self);combat.setup(self);deployables.setup(self);recovery.setup(self);targeting.setup(self);vehicles.name="TribesVehicles";add_child(vehicles);vehicles.setup(self)
func enabled() -> bool:return preload("res://deathmatch/release_features.gd").TRIBES and game.armory.effective()=="tribes" and not game.lobby.active()
func reset() -> void:
	if is_instance_valid(panel):panel.close()
	vehicles.reset();remote.reset();commander.reset()
	if is_instance_valid(command_view):command_view.close()
	energy=[INITIAL_ENERGY,INITIAL_ENERGY,INITIAL_ENERGY];credit=0.0;requests.clear();combat.reset();deployables.reset();recovery.reset();targeting.reset();field_requests.clear();local_station=-1;funded_slots=[1,1,1]
	var pads=stations()
	if pads:pads.reset();recovery.spawn_patches(pads.patch_markers)
func bank(id: int) -> int:
	var team: int=game.players.get(id,{}).get("team",-1)
	return team if mode.team_game() and team in [0,1] else 2
func balance(id: int) -> int:return MAX_TEAM_ENERGY if infinite_energy else energy[bank(id)]
func spend(id: int,amount: int) -> void:
	if not infinite_energy:energy[bank(id)]=clampi(energy[bank(id)]-amount,0,MAX_TEAM_ENERGY)
func energy_text(id: int) -> String:return str(deployables.available(id))+" REMOTE" if deployables.station(id)>=0 else "UNLIMITED" if infinite_energy else str(balance(id))
func definition(id: int) -> Dictionary:return Armour.definition(game.players.get(id,{}).get("tribes_class","light"))
func choose(key: String) -> void:
	if multiplayer.is_server():select_class(multiplayer.get_unique_id(),key)
	else:class_request.rpc_id(1,key)
@rpc("any_peer","call_remote","reliable",0)
func class_request(key: String) -> void:
	if multiplayer.is_server():select_class(multiplayer.get_remote_sender_id(),key)
func select_class(id: int,key: String) -> bool:
	if not multiplayer.is_server() or not enabled() or not game.active or not game.players.has(id) or game.players[id].spectator or not CLASSES.has(key):return false
	if game.clock<requests.get(id,0.0):return false
	requests[id]=game.clock+.25
	var s: Dictionary=game.players[id]
	s.tribes_next=key
	var pack: String=s.get("tribes_next_pack","energy")
	if not deployables.Data.allowed(key,pack):pack="none";s.tribes_next_pack=pack
	var guns: Array=s.get("tribes_next_guns",Arsenal.defaults(key)).filter(func(w):return Arsenal.allowed(key,w,pack))
	guns.resize(mini(guns.size(),int(CLASSES[key].guns)))
	s.tribes_next_guns=Arsenal.defaults(key) if guns.is_empty() else guns
	return true
func stations():
	var runtime=game.get_node_or_null("Map/MapRuntime")
	return runtime.tribes_stations if runtime else null
func base_ctf() -> bool:
	var pads=stations()
	return enabled() and mode.kind in ["ctf","st"] and pads!=null and pads.rows.any(func(row):return row.kind=="inventory")
func carried_value(id: int) -> int:
	if not game.players.has(id) or game.players[id].get("tribes_ammo",[]).size()!=12:return 0
	var s: Dictionary=game.players[id]
	var value: int=int(s.get("tribes_beacons",0))*5+Armour.definition(s.get("tribes_class","light")).cost+Arsenal.PACKS[s.get("tribes_pack","none")].cost+(35 if s.get("tribes_kit",false) else 0)
	for w in s.owned:
		if w<8:value+=Arsenal.PRICES[w]
		value+=int(s.tribes_ammo[w])*Arsenal.AMMO_PRICE[w]
	# A free emergency spawn must never be sold for newly minted energy.
	return mini(value,int(s.get("tribes_paid",0)))
func refit_cost(id: int,armour: String,weapons: Array,pack: String) -> int:
	return Arsenal.cost(armour,weapons,pack)-(carried_value(id) if base_ctf() else 0)
func spawn(id: int) -> void:
	if not enabled():return
	var state: Dictionary=game.players[id]
	if state.spectator:return
	var key: String=state.get("tribes_next",["light","medium","heavy"][posmod(-id,3)] if id<0 else "light")
	if not CLASSES.has(key):key="light"
	var weapons: Array=state.get("tribes_next_guns",Arsenal.defaults(key)).duplicate()
	var pack: String=state.get("tribes_next_pack","energy")
	if not Arsenal.valid_loadout(key,weapons,pack):weapons=Arsenal.defaults(key);pack="energy"
	state.tribes_next=key;state.tribes_next_guns=weapons.duplicate();state.tribes_next_pack=pack
	if base_ctf():
		# Base Tribes CTF starts in Light with blaster, chaingun, disc and kit.
		# Saved favourites are purchased at a station, never on respawn.
		var account:=bank(id)
		var count: int=game.players.values().filter(func(player):return not player.spectator and player.team==state.team).size()
		if count>funded_slots[account]:
			energy[account]=mini(MAX_TEAM_ENERGY,energy[account]+(count-funded_slots[account])*INITIAL_ENERGY);funded_slots[account]=count
		var stock_cost: int=Armour.definition("light").cost+Arsenal.PRICES[0]+Arsenal.PRICES[2]+Arsenal.PRICES[3]+100+30+35
		var paid: int=mini(balance(id),stock_cost);spend(id,paid)
		apply_equipment(id,"light",[0,2,3],"none")
		state.weapon=3;state.tribes_ammo[9]=0;state.tribes_ammo[10]=0
		state.tribes_paid=paid;state.tribes_fallback=paid<stock_cost
		return
	var cost: int=Arsenal.cost(key,weapons,pack);var account:=bank(id)
	state.tribes_next=key;state.tribes_next_guns=weapons.duplicate();state.tribes_next_pack=pack
	state.tribes_fallback=balance(id)<cost
	if state.tribes_fallback:key="light";weapons=[0];pack="energy"
	else:spend(id,cost)
	apply_equipment(id,key,weapons,pack)
	state.tribes_paid=0 if state.tribes_fallback else cost
func apply_equipment(id: int,key: String,weapons: Array,pack: String) -> void:
	var state: Dictionary=game.players[id]
	state.tribes_class=key;state.tribes_pack=pack;state.tribes_kit=true;state.tribes_beacons=0
	var profile:=definition(id)
	state.hp=profile.hp;state.armor=0;state.tier=1
	state.owned=weapons.duplicate();state.owned.append_array([9,10,11])
	if pack=="repair":state.owned.append(8)
	state.weapon=weapons[0];state.ammo=[0,0,0,0];state.tribes_ammo=[];state.tribes_grenade=9
	for w in 12:state.tribes_ammo.append(Arsenal.capacity(key,pack,w) if w in state.owned else 0)
	game.fighters[id].tribes_state=game.fighters[id].Tribes.fresh(key,pack)
	combat.cancel(id)
func tick(delta: float) -> void:
	if not multiplayer.is_server():return
	if not enabled() or mode.kind!="st":
		if not deployables.rows.is_empty():deployables.reset()
	vehicles.tick(delta)
	if not enabled():return
	remote.tick();commander.tick()
	deployables.tick(delta)
	combat.tick(delta);recovery.tick(delta);targeting.tick()
	var pads=stations()
	if pads:pads.tick(self,delta)
	credit+=delta
	while credit>=REPLENISH_SECONDS:
		credit-=REPLENISH_SECONDS
		for i in energy.size():energy[i]=mini(MAX_TEAM_ENERGY,energy[i]+REPLENISH)
func can_carry(id: int,weapon: int) -> bool:
	if not enabled():return true
	var s: Dictionary=game.players[id]
	return Arsenal.allowed(s.get("tribes_class","light"),weapon,s.get("tribes_pack","energy")) and (weapon in s.owned or s.owned.filter(func(w):return w<8).size()<definition(id).guns)
func damage(id: int,amount: int,weapon: String,bypass: bool) -> int:
	if not enabled() or amount<=0:return amount
	var w: int=Arsenal.NAMES.find(weapon)
	if weapon in ["REMOTE TURRET","FUSION TURRET","MINI-FUSION TURRET"]:w=0
	elif weapon in ["MISSILE TURRET","SCOUT ROCKET"]:w=3
	elif weapon=="MORTAR TURRET":w=7
	elif weapon=="ELF TURRET":w=6
	if w<0:return amount
	var movement: Dictionary=game.fighters[id].tribes_state
	var points: float=amount
	if movement.pack=="shield" and movement.pack_on:
		var strength: float=.012*Arsenal.UNIT*(.75 if w in [4,7,9] else 1.0)
		var absorbed: float=minf(points,movement.energy*strength)
		movement.energy=maxf(0,movement.energy-absorbed/strength);points-=absorbed
	return maxi(0,roundi(points*Arsenal.RESISTS[movement.armour][w]))
func amount(id: int,w: int) -> int:
	var s: Dictionary=game.players.get(id,{})
	return int(s.get("tribes_ammo",[])[w]) if w in [1,2,3,4,7,9,10] and s.get("tribes_ammo",[]).size()==12 else -1
func ammo_label(id: int,w: int) -> String:
	return str(amount(id,w)) if amount(id,w)>=0 else "%d ENERGY"%roundi(game.fighters[id].tribes_state.energy) if w in [0,5,6,8,11] and game.fighters.has(id) else "DESIGNATE"
func usable(id: int,w: int) -> bool:
	if amount(id,w)==0:return false
	return w not in [0,5,6,8,11] or game.fighters[id].tribes_state.energy>=float(game.armory.data(w).get("minimum",0))
func collect(id: int,p: Dictionary) -> bool:
	var s: Dictionary=game.players[id];var took:=false
	if p.kind=="weapon":
		if not can_carry(id,p.item):return false
		if p.item not in s.owned:s.owned.append(p.item);took=true
		var cap: int=Arsenal.capacity(s.tribes_class,s.tribes_pack,p.item)
		if s.tribes_ammo[p.item]<cap:s.tribes_ammo[p.item]=mini(cap,s.tribes_ammo[p.item]+(int(p.get("amount",0)) if p.get("dropped",false) else maxi(1,cap/3)));took=true
	elif p.kind=="ammo":
		for w in s.owned:
			var cap: int=Arsenal.capacity(s.tribes_class,s.tribes_pack,w)
			if s.tribes_ammo[w]<cap:s.tribes_ammo[w]=mini(cap,s.tribes_ammo[w]+maxi(1,cap/3));took=true
	return took
func choose_equipment(armour: String,weapons: Array,pack: String,refit: bool=false) -> void:
	if multiplayer.is_server():
		var ok:=select_equipment(multiplayer.get_unique_id(),armour,weapons,pack,refit)
		if refit:equipment_notice(ok)
	else:equipment_request.rpc_id(1,armour,weapons,pack,refit)
@rpc("any_peer","call_remote","reliable",0)
func equipment_request(armour: String,weapons: Array,pack: String,refit: bool=false) -> void:
	if multiplayer.is_server():
		var id:=multiplayer.get_remote_sender_id();var ok:=select_equipment(id,armour,weapons,pack,refit)
		if refit:equipment_notice.rpc_id(id,ok)
@rpc("authority","call_remote","reliable",0)
func equipment_notice(ok: bool) -> void:
	game.status("Inventory refitted." if ok else "Cannot refit: use a friendly inventory station with sufficient team energy.")
func select_equipment(id: int,armour: String,weapons: Array,pack: String,refit: bool=false) -> bool:
	if not Arsenal.valid_loadout(armour,weapons,pack) or not select_class(id,armour):return false
	game.players[id].tribes_next_guns=weapons.duplicate();game.players[id].tribes_next_pack=pack
	if not refit:return true
	if not can_refit(id):return false
	var cost:=refit_cost(id,armour,weapons,pack)
	if not deployables.can_shop(id,armour,pack) or deployables.available(id)<cost:return false
	var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var condition: float=float(s.hp)/definition(id).hp;var personal_energy: float=actor.tribes_state.energy
	deployables.pay(id,cost)
	apply_equipment(id,armour,weapons,pack)
	s.tribes_paid=Arsenal.cost(armour,weapons,pack);s.tribes_fallback=false
	# Refits preserve damage and jet charge; standing at the station repairs it.
	s.hp=maxi(1,roundi(definition(id).hp*condition));actor.tribes_state.energy=minf(personal_energy,definition(id).energy)
	s.cooldown=.5;s.fire=false;s.held=false;s.serial+=1
	if id==multiplayer.get_unique_id():game.desired_weapon=s.weapon
	return true
func action(id: int) -> void:
	if remote.operated(id)>=0:remote.release(id);return
	if vehicles.use(id):return
	if not enabled() or not multiplayer.is_server() or not game.players.has(id):return
	var pads=stations()
	if pads and pads.defences.operated(id)>=0:pads.defences.release(id);return
	if pads and pads.at(id,["command"])>=0:
		if id==multiplayer.get_unique_id():command_station_notice()
		elif id>0:command_station_notice.rpc_id(id)
		return
	pack_action(id)
func pack_action(id: int):
	if not enabled() or not multiplayer.is_server() or not game.players.has(id) or vehicles.piloting(id):return
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or s.get("input_blocked",false) or game.intermission>0 or game.clock<s.get("tribes_use_at",0.0):return
	s.tribes_use_at=game.clock+.25
	var m: Dictionary=game.fighters[id].tribes_state
	if deployables.Data.is_pack(m.pack):
		var frame: Transform3D=game._weapon_transform(id)
		deployment_notice(id,deployables.deploy(id,frame.origin,-frame.basis.z));return
	if m.pack in ["shield","jammer"]:
		m.pack_on=not m.pack_on and m.energy>=4
	elif m.pack=="repair":
		s.weapon=8
		if id==multiplayer.get_unique_id():repair_selected(game.map_epoch,s.serial)
		elif id>0:repair_selected.rpc_id(id,game.map_epoch,s.serial)
	elif s.get("tribes_kit",false) and s.hp<definition(id).hp:
		s.hp=mini(definition(id).hp,s.hp+roundi(.2*Arsenal.UNIT));s.tribes_kit=false
@rpc("authority","call_remote","reliable",0)
func repair_selected(epoch: int,life: int) -> void:
	if enabled() and game.map_epoch==epoch and game.local_state().get("serial",-1)==life:game.desired_weapon=8
func use_kit() -> void:
	if multiplayer.is_server():kit(multiplayer.get_unique_id())
	else:kit_request.rpc_id(1)
@rpc("any_peer","call_remote","reliable",0)
func kit_request() -> void:
	if multiplayer.is_server():kit(multiplayer.get_remote_sender_id())
func kit(id: int) -> bool:
	if not recovery.eligible(id):return false
	var s: Dictionary=game.players[id]
	# This is an explicit inventory/H-button action, not held weapon input.
	if not s.get("tribes_kit",false) or s.hp>=definition(id).hp:return false
	s.hp=mini(definition(id).hp,s.hp+roundi(.2*Arsenal.UNIT));s.tribes_kit=false;return true
func toss_flag() -> void:
	if multiplayer.is_server():flag_request()
	else:flag_request.rpc_id(1)
@rpc("any_peer","call_remote","reliable",0)
func flag_request() -> void:
	if not multiplayer.is_server() or not enabled() or not game.active or game.map_loading or game.intermission>0:return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	if not game.players.has(id) or game.players[id].dead or game.players[id].spectator or game.players[id].get("input_blocked",false):return
	mode.st.drop(id,Vector3.INF,-game._weapon_transform(id).basis.z*10+Vector3.UP*3)
func snapshot() -> Dictionary:
	if not enabled():return {}
	var people: Dictionary={}
	for id in game.players:
		var s: Dictionary=game.players[id]
		people[id]={"class":s.get("tribes_class","light"),"next":s.get("tribes_next","light"),"fallback":s.get("tribes_fallback",false),"pack":s.get("tribes_pack","energy"),"next_pack":s.get("tribes_next_pack","energy"),"guns":s.get("tribes_next_guns",Arsenal.defaults(s.get("tribes_next","light"))).duplicate(),"ammo":s.get("tribes_ammo",[0,0,0,0,0,0,0,0,0,0,0,0]).duplicate(),"kit":s.get("tribes_kit",false),"grenade":s.get("tribes_grenade",9),"paid":s.get("tribes_paid",0),"beacons":s.get("tribes_beacons",0)}
	var pads=stations()
	return {"remote":remote.snapshot(),"command":commander.snapshot(),"vehicles":vehicles.snapshot(),"energy":energy.duplicate(),"credit":credit,"players":people,"infinite_energy":infinite_energy,"generators":pads.health.duplicate() if pads else [300.0,300.0],"base_assets":pads.assets.snapshot() if pads else [],"fixed_defences":pads.defences.snapshot() if pads else [],"deployables":deployables.snapshot(),"power":pads.power_snapshot() if pads else {"sources":[],"shields":[]},"targeting":targeting.snapshot(),"recovery":recovery.snapshot()}
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary:return false
	if data.is_empty():return true
	if data.size() not in [6,7,8,11,12,14] or data.size()>=7 and not data.has("base_assets") or data.size()>=8 and not data.has("fixed_defences") or not preload("res://deathmatch/tribes/base_assets.gd").valid(data.get("base_assets",[])):return false
	if data.size()>=11 and (not preload("res://deathmatch/tribes/stations.gd").valid_power(data.get("power")) or not preload("res://deathmatch/tribes/targeting.gd").valid(data.get("targeting")) or not preload("res://deathmatch/tribes/recovery.gd").valid(data.get("recovery"))):return false
	if data.has("vehicles") and not preload("res://deathmatch/vehicles/tribes/controller.gd").valid(data.vehicles):return false
	if data.size()>=12 and not data.has("vehicles"):return false
	if data.size()==14 and (not preload("res://deathmatch/tribes/remote_control.gd").valid(data.get("remote")) or not preload("res://deathmatch/tribes/command_state.gd").valid(data.get("command"))):return false
	if not preload("res://deathmatch/tribes/fixed_defences.gd").valid(data.get("fixed_defences",[])):return false
	if not preload("res://deathmatch/tribes/deployables.gd").valid(data.get("deployables")) or not data.get("infinite_energy") is bool or not data.get("energy") is Array or data.energy.size()!=3 or not data.get("players") is Dictionary or data.players.size()>128:return false
	for key in data.get("remote",{}):
		if not data.deployables.rows.has(key) or data.deployables.rows[key].kind not in ["camera","turret"] or not data.players.has(data.remote[key]):return false
	if not (data.get("credit") is float or data.get("credit") is int) or not is_finite(float(data.credit)) or data.credit<0 or data.credit>=REPLENISH_SECONDS:return false
	if not data.get("generators") is Array or data.generators.size()!=2:return false
	for hp in data.generators:
		if not (hp is float or hp is int) or not is_finite(float(hp)) or hp<0 or hp>300:return false
	for value in data.energy:
		if not value is int or value<0 or value>MAX_TEAM_ENERGY:return false
	for id in data.players:
		var row=data.players[id]
		if not id is int or not row is Dictionary or row.size() not in [10,11] or not CLASSES.has(row.get("class")) or not CLASSES.has(row.get("next")) or not row.get("fallback") is bool:return false
		if row.size()==11 and (not row.get("beacons") is int or row.beacons<0 or row.beacons>(13 if row.get("pack")=="ammo" else 3)):return false
		if row.get("grenade") not in [9,10] or not row.get("paid") is int or row.paid<0 or row.paid>MAX_TEAM_ENERGY:return false
		if not Arsenal.PACKS.has(row.get("pack")) or not row.get("kit") is bool or not Arsenal.valid_loadout(row.next,row.get("guns"),row.get("next_pack","")):return false
		if not row.get("ammo") is Array or row.ammo.size()!=12:return false
		for w in 12:
			if not row.ammo[w] is int or row.ammo[w]<0 or row.ammo[w]>Arsenal.capacity(row["class"],row.pack,w):return false
	return true
func receive(data: Dictionary) -> void:
	if data.is_empty():vehicles.reset();deployables.reset();recovery.reset();targeting.reset();remote.reset();commander.reset();return
	if not valid_snapshot(data):return
	vehicles.receive(data.get("vehicles",{"rows":{},"rockets":{}}))
	deployables.receive(data.deployables)
	remote.receive(data.get("remote",{}));commander.receive(data.get("command",{"commanders":{},"orders":{}}))
	recovery.receive(data.get("recovery",{}));targeting.receive(data.get("targeting",{"beacons":{},"lasers":{}}))
	energy=data.energy.duplicate();credit=data.credit;infinite_energy=data.infinite_energy
	var pads=stations()
	if pads:
		pads.health=data.generators.duplicate()
		if data.has("fixed_defences"):pads.defences.receive(data.fixed_defences)
		else:
			for row in pads.defences.rows:row.hp=0;row.operator=0 # Older recordings had decorative sockets.
		if data.has("base_assets"):pads.assets.receive(data.base_assets)
		else:pads.assets.reset() # Legacy demos predate independent fixture damage.
		if data.has("power"):pads.receive_power(data.power)
		else:
			for row in pads.assets.rows:row.energy=0.0
	for id in data.players:
		if not game.players.has(id):continue
		var row: Dictionary=data.players[id];var state: Dictionary=game.players[id]
		state.tribes_class=row["class"];state.tribes_next=row.next;state.tribes_fallback=row.fallback

		state.tribes_pack=row.pack;state.tribes_next_pack=row.next_pack;state.tribes_next_guns=row.guns.duplicate();state.tribes_ammo=row.ammo.duplicate();state.tribes_kit=row.kit;state.tribes_grenade=row.grenade;state.tribes_paid=row.paid;state.tribes_beacons=row.get("beacons",0)

func can_refit(id: int) -> bool:
	if vehicles.mounted(id) or not enabled() or not game.active or game.map_loading or not game.players.has(id) or not game.fighters.has(id):return false
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator or game.intermission>0 or mode.special.blocked(id):return false
	var pads=stations()
	if deployables.station(id)>=0:return true
	if pads and not pads.rows.is_empty():return pads.at(id)>=0
	for point in mode.spawns(s.team):
		if game.fighters[id].position.distance_to(point)<5:return true
	return false
func inventory_station(id: int) -> int:
	if vehicles.mounted(id) or not deployables.accessible(id):return -1
	var pads=stations()
	var index: int=pads.at(id,["inventory","command"]) if pads else -1
	if index>=0:return index
	index=vehicles.station(id)
	if index>=0:return 2000+index
	index=deployables.station(id)
	return 1000+index if index>=0 else -1
func can_open_inventory(id: int) -> bool:
	return can_refit(id) or inventory_station(id)>=0
func cycle_grenade(direction: int):
	if multiplayer.is_server():cycle_for(multiplayer.get_unique_id(),direction)
	else:cycle_request.rpc_id(1,direction)
@rpc("any_peer","call_remote","reliable",0)
func cycle_request(direction: int):
	if multiplayer.is_server():cycle_for(multiplayer.get_remote_sender_id(),direction)
func cycle_for(id: int,direction: int):
	if enabled() and game.players.has(id) and direction in [-1,1] and not game.players[id].dead:
		game.players[id].tribes_grenade=10 if game.players[id].get("tribes_grenade",9)==9 else 9

func jammed(id: int) -> bool:
	if not enabled() or not game.players.has(id):return false
	for other in game.players:
		if game.players[other].dead or game.players[other].spectator or not (other==id or mode.same_team(other,id)):continue
		var m: Dictionary=game.fighters[other].tribes_state
		if m.pack=="jammer" and m.pack_on and game.fighters[other].position.distance_to(game.fighters[id].position)<=20:return true
	return false

func open_inventory() -> void:
	if not enabled() or game.headless:return
	if not is_instance_valid(panel):panel=load("res://deathmatch/ui/defusal_panel.gd").new();game.add_child(panel);panel.setup(self)
	if not panel.opened:panel.toggle()
func _process(_delta: float):
	vehicles.update(_delta)
	if not game.headless and enabled() and game.active and not is_instance_valid(command_view):
		command_view=load("res://deathmatch/tribes/command_view.gd").new();game.add_child(command_view);command_view.setup(self)
	if is_instance_valid(command_view):command_view.update(_delta)
	if is_instance_valid(panel) and panel.opened:panel.refresh()
	if not game.headless and enabled() and game.active:
		if not is_instance_valid(deployable_view):deployable_view=preload("res://deathmatch/tribes/deployable_view.gd").new();game.add_child(deployable_view);deployable_view.setup(self)
	if is_instance_valid(deployable_view):deployable_view.update()
	if not game.headless and enabled() and game.active and not is_instance_valid(turret_view):
		turret_view=preload("res://deathmatch/tribes/turret_view.gd").new();game.add_child(turret_view);turret_view.setup(self)
	if is_instance_valid(turret_view):turret_view.update()
	if not game.headless and enabled() and game.active and not is_instance_valid(field_view):
		field_view=preload("res://deathmatch/tribes/field_view.gd").new();game.add_child(field_view);field_view.setup(self)
	if is_instance_valid(field_view):field_view.update()
	if game.headless or not enabled() or not game.active or game.map_loading or game.demos.playing:return
	var id: int=multiplayer.get_unique_id();var pads=stations()
	var current: int=inventory_station(id)
	if current<0:
		if local_station>=0:
			if is_instance_valid(panel):panel.close()
			if game.is_vr() and game.xr_rig.weapon_wheel.tribes_shop:game.xr_rig.weapon_wheel.close()
		local_station=-1;return
	if current==local_station or game.menu_open or pda_open() or operating(id):return
	if game.is_vr():
		var wheel=game.xr_rig.weapon_wheel
		if not game.xr_rig.can_open_weapon_wheel():return
		wheel.close();wheel.toggle(game.xr_rig.right.get_vector2("primary"))
	else:open_inventory()
	local_station=current
func menu_open() -> bool:return enabled() and (pda_open() or is_instance_valid(panel) and panel.opened)
func desktop_input(event: InputEvent) -> bool:
	if not enabled() or game.menu_open or game.demos.playing:return false
	if pda_open():return command_view.input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_C:
		open_pda();return true
	if menu_open():
		panel.refresh()
		if event is InputEventKey and event.pressed and not event.echo:panel.handle_key(event.physical_keycode)
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_B:
			open_inventory();return true
		if event.physical_keycode==KEY_G:cycle_grenade(1);return true
		if event.physical_keycode==KEY_H:use_kit();return true
		if event.physical_keycode==KEY_T and mode.kind=="st":toss_flag();return true
	return false

func deployment_notice(id: int,success: bool):
	if id==multiplayer.get_unique_id():deployment_result(success)
	elif id>0:deployment_result.rpc_id(id,success)
@rpc("authority","call_remote","reliable",0)
func deployment_result(success: bool):
	game.status("Equipment deployed." if success else "Cannot deploy here: check clearance, surface, range and team limit.")
@rpc("authority","call_local","unreliable",3)
func deployable_sound(epoch: int,where: Vector3):
	if epoch==game.map_epoch and not game.headless:game.spatial.play("tribes_weapon_0",where,-8)
func view_camera(key: int):
	if key>=0:control_turret(-1);control_remote(-1)
	if is_instance_valid(deployable_view):deployable_view.watch(key)

func close_remote_view() -> bool:
	# Consume the Use edge locally before it can also activate a chest pack.
	var pads=stations();var closed:=false
	if pda_open():command_view.close();closed=true
	if remote.operated(multiplayer.get_unique_id())>=0 or is_instance_valid(turret_view) and turret_view.remote_mode and turret_view.key>=0:
		control_remote(-1);closed=true
	if (is_instance_valid(turret_view) and turret_view.key>=0) or (pads and pads.defences.operated(multiplayer.get_unique_id())>=0):
		control_turret(-1);closed=true
		if is_instance_valid(turret_view):turret_view.key=-1
	if is_instance_valid(deployable_view) and deployable_view.camera_key>=0:
		deployable_view.watch(-1);closed=true
	return closed

func control_turret(key: int):
	if is_instance_valid(turret_view):turret_view.releasing=key<0
	if key>=0 and is_instance_valid(deployable_view):deployable_view.watch(-1)
	var id: int=multiplayer.get_unique_id();var s: Dictionary=game.local_state()
	if multiplayer.is_server():turret_control(key,game.map_epoch,s.get("serial",-1))
	else:turret_control.rpc_id(1,key,game.map_epoch,s.get("serial",-1))
@rpc("any_peer","call_remote","reliable",0)
func turret_control(key: int,epoch: int,life: int):
	if not multiplayer.is_server():return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var pads=stations()
	if pads and pads.defences.control(id,key,epoch,life) and key>=0:remote.release(id)
@rpc("any_peer","call_remote","unreliable_ordered",3)
func turret_command(key: int,epoch: int,life: int,direction: Vector3,fire: bool):
	if not multiplayer.is_server():return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var pads=stations()
	if pads:pads.defences.command(id,key,epoch,life,direction,fire)

func field_action(kind: String):
	field_sequence+=1
	var life: int=game.local_state().get("serial",-1)
	if multiplayer.is_server():field_request(kind,game.map_epoch,life,field_sequence)
	else:field_request.rpc_id(1,kind,game.map_epoch,life,field_sequence)
@rpc("any_peer","call_remote","reliable",0)
func field_request(kind: String,epoch: int,life: int,sequence: int):
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var ok:=perform_field(id,kind,epoch,life,sequence)
	if id==multiplayer.get_unique_id():field_result(ok,kind)
	elif id>0:field_result.rpc_id(id,ok,kind)
func perform_field(id: int,kind: String,epoch: int,life: int,sequence: int) -> bool:
	if not recovery.eligible(id) or epoch!=game.map_epoch or game.players[id].serial!=life or sequence<=int(field_requests.get(id,0)) or kind not in ["pack","ammo","weapon","beacon","buy_beacons"]:return false
	field_requests[id]=sequence
	var s: Dictionary=game.players[id]
	if game.clock<float(s.get("tribes_field_at",0)):return false
	s.tribes_field_at=game.clock+.25
	if kind=="buy_beacons":return targeting.buy(id)
	if kind=="beacon":
		var frame: Transform3D=game._weapon_transform(id)
		return targeting.place(id,frame.origin,-frame.basis.z)
	return recovery.drop(id,kind)
@rpc("authority","call_remote","reliable",0)
func command_station_notice():open_pda()

@rpc("authority","call_remote","reliable",0)
func field_result(ok: bool,kind: String):
	var labels:={"pack":"Backpack dropped.","ammo":"Ammunition dropped.","weapon":"Weapon dropped.","beacon":"Target beacon deployed.","buy_beacons":"Target beacons purchased."}
	game.status(labels.get(kind,"Equipment ready.") if ok else "Equipment unavailable, obstructed or out of reach.")

func buy_scout():buy_vehicle("scout")
func buy_vehicle(kind: String):
	var s: Dictionary=game.local_state()
	if multiplayer.is_server():vehicle_purchase(game.map_epoch,s.get("serial",-1),kind)
	else:vehicle_purchase.rpc_id(1,game.map_epoch,s.get("serial",-1),kind)
@rpc("any_peer","call_remote","reliable",0)
func vehicle_purchase(epoch: int,life: int,kind: String):
	if not multiplayer.is_server() or kind not in vehicles.Data.KINDS:return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var ok: bool=vehicles.purchase(id,epoch,life,kind)
	if id==multiplayer.get_unique_id():vehicle_notice(ok,kind)
	elif id>0:vehicle_notice.rpc_id(id,ok,kind)
@rpc("authority","call_remote","reliable",0)
func vehicle_notice(ok: bool,kind: String):
	game.status(vehicles.Data.definition(kind).name+" ready in 3 seconds. Use beside a seat to board; jump to eject." if ok else "Vehicle purchase failed: check station power, team energy, type limit and clear launch pad.")

func operating(id: int) -> bool:
	var pads=stations()
	return remote.operated(id)>=0 or pads and pads.defences.operated(id)>=0
func pda_open() -> bool:return is_instance_valid(command_view) and command_view.opened
func open_pda():
	if game.headless or not enabled():return
	if not is_instance_valid(command_view):command_view=load("res://deathmatch/tribes/command_view.gd").new();game.add_child(command_view);command_view.setup(self)
	command_view.toggle()
func control_remote(key: int):
	if is_instance_valid(turret_view):turret_view.releasing=key<0
	if key>=0:
		if is_instance_valid(deployable_view):deployable_view.watch(-1)
		if pda_open():command_view.close()
	var s: Dictionary=game.local_state()
	if multiplayer.is_server():remote_control(key,game.map_epoch,s.get("serial",-1))
	else:remote_control.rpc_id(1,key,game.map_epoch,s.get("serial",-1))
@rpc("any_peer","call_remote","reliable",0)
func remote_control(key: int,epoch: int,life: int):
	if not multiplayer.is_server():return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var ok: bool=remote.control(id,key,epoch,life)
	if not ok:
		if id==multiplayer.get_unique_id():remote_notice()
		elif id>0:remote_notice.rpc_id(id)
@rpc("authority","call_remote","reliable",0)
func remote_notice():game.status("Remote control unavailable: check team, active equipment and current operator.")
@rpc("any_peer","call_remote","unreliable_ordered",3)
func remote_command(key: int,epoch: int,life: int,direction: Vector3,fire: bool):
	if not multiplayer.is_server():return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	remote.command(id,key,epoch,life,direction,fire)
func command_action(action: String,units: Array,point:=Vector3.ZERO):
	order_sequence+=1
	var life: int=game.local_state().get("serial",-1)
	if multiplayer.is_server():command_request(game.map_epoch,life,order_sequence,action,units,point)
	else:command_request.rpc_id(1,game.map_epoch,life,order_sequence,action,units,point)
@rpc("any_peer","call_remote","reliable",0)
func command_request(epoch: int,life: int,sequence: int,action: String,units: Array,point: Vector3):
	if not multiplayer.is_server():return
	var id: int=multiplayer.get_remote_sender_id()
	if id==0:id=multiplayer.get_unique_id()
	var ok: bool=commander.request(id,epoch,life,sequence,action,units,point)
	if id==multiplayer.get_unique_id():command_result(ok)
	elif id>0:command_result.rpc_id(id,ok)
@rpc("authority","call_remote","reliable",0)
func command_result(ok: bool):game.status("Command updated." if ok else "Command unavailable: select a unit under your command or an unassigned bot.")
