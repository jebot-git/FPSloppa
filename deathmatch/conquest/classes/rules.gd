extends RefCounted
## CQ class abilities. Only the authority mutates gameplay; snapshots drive visuals.
const CLASSES=["shocktroop","scout","medic","technician"]
const CLOAK_SECONDS:=10.0
const CLOAK_COOLDOWN:=30.0 # Measured from activation; cancelling never resets it.
const BLEED_SECONDS:=10.0
const INJECTION_SECONDS:=3.0
const DISPENSER_CAPACITY:=1000
var host: WeakRef
var game:
	get:return host.get_ref() if host else null
var progression=preload("res://deathmatch/conquest/classes/progression.gd").new()
var states: Dictionary={}
var downed: Dictionary={}
var injecting: Dictionary={}
var dispensers: Dictionary={}
var next_dispenser:=0
func setup(arena) -> void:host=weakref(arena)
func authority() -> bool:return game!=null and game.multiplayer.is_server()
func alive(id:int) -> bool:
	return game.players.has(id) and not game.players[id].dead and not game.players[id].spectator and not downed.has(id)
func ensure(id:int) -> Dictionary:
	if not states.has(id):states[id]={"class":"shocktroop","next":"shocktroop","xp":{"shocktroop":0,"scout":0,"medic":0,"technician":0},"cloak_until":0.0,"cloak_ready":0.0,"dispenser_ready":0.0}
	return states[id]
func role(id:int) -> String:return states.get(id,{}).get("class","shocktroop")
func choose(id:int,value:String) -> bool:
	if not authority() or not game.players.has(id) or value not in CLASSES:return false
	ensure(id).next=value;return true # Applied on spawn; changing class cannot refill gear.
func choose_equipment(id:int,role_name:String,weapon:int,secondary:bool) -> bool:
	if not authority() or not game.players.has(id) or role_name not in CLASSES:return false
	var state:=ensure(id)
	if weapon not in progression.unlocked(role_name,state.xp[role_name],secondary):return false
	var key:="secondary_choices" if secondary else "primary_choices"
	if not state.has(key):state[key]={}
	state[key][role_name]=weapon;return true
func equipment(id:int,secondary:bool=false) -> int:
	var state:=ensure(id);var role_name:String=state["class"]
	var unlocked:Array=progression.unlocked(role_name,state.xp[role_name],secondary)
	var choice:int=state.get("secondary_choices" if secondary else "primary_choices",{}).get(role_name,unlocked[0])
	return choice if choice in unlocked else unlocked[0]
func spawn(id:int) -> void:
	if not authority():return
	var s:=ensure(id);s["class"]=s.next;s.cloak_until=0.0
	downed.erase(id);injecting.erase(id)
	# Ability cooldowns persist through death and class changes.
func cloak(id:int) -> bool:
	if not authority() or not alive(id) or role(id)!="scout":return false
	var s:=ensure(id)
	if s.cloak_ready>game.clock or game.players[id].get("fire",false) or game.players[id].get("alt_fire",false):return false
	s.cloak_until=game.clock+CLOAK_SECONDS;s.cloak_ready=game.clock+CLOAK_COOLDOWN
	return true
func cloaked(id:int) -> bool:
	return alive(id) and role(id)=="scout" and states[id].cloak_until>game.clock
func weapon_used(id:int) -> void:
	if authority() and states.has(id):states[id].cloak_until=0.0
func incapacitate(id:int,attacker:int,weapon:String,gibbed:bool,headshot:bool,bypass:bool) -> bool:
	if not authority() or not alive(id) or gibbed or headshot or bypass:return false
	downed[id]={"remaining":BLEED_SECONDS,"attacker":attacker,"weapon":weapon}
	game.players[id].hp=1;game.players[id].fire=false;game.players[id].alt_fire=false
	weapon_used(id);return true
func injection(medic:int,victim:int,delta:float) -> bool:
	# Caller establishes chest contact, trigger state, LOS and validated pose.
	if not authority() or not alive(medic) or role(medic)!="medic" or not downed.has(victim) or not game.match_mode.same_team(medic,victim):return false
	var old:Dictionary=injecting.get(victim,{})
	if not old.is_empty() and old.medic!=medic:return false
	var progress:float=old.get("progress",0.0)+maxf(0,delta)
	injecting[victim]={"medic":medic,"progress":progress,"touched":game.clock}
	if progress+0.00001<INJECTION_SECONDS:return false
	downed.erase(victim);injecting.erase(victim);game.players[victim].hp=35
	award(medic,75);return true
func tick(delta:float) -> Array:
	if not authority():return []
	var expired:Array=[]
	for id in downed.keys():
		if not game.players.has(id) or game.players[id].dead:downed.erase(id);injecting.erase(id);continue
		# Contact is renewed each authority tick, never by a client timer.
		var contact:Dictionary=injecting.get(id,{})
		if not contact.is_empty() and contact.touched==game.clock and alive(contact.medic):continue
		injecting.erase(id) # Lost contact resets the continuous three-second injection.
		downed[id].remaining=maxf(0,downed[id].remaining-delta)
		if downed[id].remaining<=0:
			expired.append({"id":id,"attacker":downed[id].attacker,"weapon":downed[id].weapon});downed.erase(id)
	return expired
func award(id:int,amount:int) -> void:
	if not authority() or amount<=0 or not game.players.has(id) or game.players[id].spectator:return
	var s:=ensure(id);s.xp[s["class"]]+=amount
func round_awards(winner:int) -> void:
	if not authority():return
	for id in game.players:
		if not game.players[id].spectator:award(id,50+(100 if game.players[id].team==winner else 0))
func snapshot() -> Dictionary:
	return {"states":states.duplicate(true),"downed":downed.duplicate(true),"injecting":injecting.duplicate(true),"dispensers":dispensers.duplicate(true)}
func receive(data:Dictionary) -> void:
	if authority():return
	states=data.get("states",{}).duplicate(true);downed=data.get("downed",{}).duplicate(true);injecting=data.get("injecting",{}).duplicate(true);dispensers=data.get("dispensers",{}).duplicate(true)
func status(id:int) -> String:
	if not states.has(id):return ""
	if downed.has(id):return " · INCAPACITATED %.1fs%s"%[downed[id].remaining," · REVIVING %.1f / 3s"%injecting[id].progress if injecting.has(id) else ""]
	var s:Dictionary=states[id];var text:=" · %s · %d XP"%[s["class"].to_upper(),s.xp[s["class"]]]
	if s["class"]=="scout":text+=" · CLOAK %.1fs"%maxf(0,s.cloak_until-game.clock) if cloaked(id) else " · CLOAK "+("READY" if s.cloak_ready<=game.clock else "%.1fs"%(s.cloak_ready-game.clock))
	return text
func deploy(id:int,position:Vector3) -> bool:
	if not authority() or not alive(id) or role(id) not in ["medic","technician"] or not position.is_finite():return false
	var s:=ensure(id)
	if s.dispenser_ready>game.clock:return false
	for key in dispensers:
		if dispensers[key].owner==id and dispensers[key].remaining>0:return false
	next_dispenser+=1;dispensers[next_dispenser]={"owner":id,"team":game.players[id].team,"kind":"health" if role(id)=="medic" else "ammo","position":position,"remaining":DISPENSER_CAPACITY,"credit":0.0,"xp_credit":0.0}
	s.dispenser_ready=game.clock+60.0;return true
func transfer(key:int,target:int,requested:int) -> int:
	if not authority() or not dispensers.has(key) or not alive(target) or requested<=0:return 0
	var box:Dictionary=dispensers[key];var s:Dictionary=game.players[target]
	if s.team!=box.team:return 0
	var amount:int=mini(requested,box.remaining)
	if box.kind=="health":amount=mini(amount,maxi(0,100-s.hp));s.hp+=amount
	else:
		var limits:Array=game.armory.loadout_capacity(s)
		var restored:=0
		for i in limits.size():
			var n:int=mini(amount-restored,maxi(0,limits[i]-s.ammo[i]));s.ammo[i]+=n;restored+=n
		amount=restored
	box.remaining-=amount
	if amount>0 and target!=box.owner:
		box.xp_credit+=amount
		var xp:int=int(box.xp_credit/10.0);box.xp_credit-=xp*10;award(box.owner,xp)
	return amount
