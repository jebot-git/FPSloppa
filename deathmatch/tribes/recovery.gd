extends RefCounted
## Server-owned, partially recoverable inventories. Every accepted transfer removes
## the same count from its source; salvaged items never create trade-in credit.
const A=preload("res://deathmatch/tribes/arsenal.gd")
const LIMIT:=128
const AMMO_CHUNK=[0,5,20,1,1,0,0,1,0,1,1,0]
var rules
var game
var rows: Dictionary={}
var next_id:=1
var scan_at:=0.0
var stats: Dictionary={}
var patches: Array=[]
func setup(value):rules=value;game=rules.game
func reset():rows.clear();next_id=1;scan_at=0;stats.clear();patches.clear()
func eligible(id: int) -> bool:
	if not game.multiplayer.is_server() or not rules.enabled() or not game.active or game.map_loading or game.intermission>0 or not game.players.has(id) or not game.fighters.has(id):return false
	var s: Dictionary=game.players[id];var pads=rules.stations()
	return not s.dead and not s.spectator and not rules.mode.special.blocked(id) and (not pads or pads.defences.operated(id)<0)
func empty_payload() -> Dictionary:return {"pack":"none","guns":[],"ammo":[0,0,0,0,0,0,0,0,0,0,0,0],"kit":false,"beacons":0,"patch":false}
func create(id: int,payload: Dictionary,point: Vector3,velocity: Vector3,kind: String,life: float=30) -> int:
	if rows.size()>=LIMIT or not point.is_finite() or not velocity.is_finite():return -1
	var key:=next_id;next_id+=1
	rows[key]={"position":point,"velocity":velocity.limit_length(35),"owner":id,"ready":game.clock+1,"expires":game.clock+life,"kind":kind,"payload":payload,"rest":false}
	return key
func drop(id: int,kind: String,point: Vector3=Vector3.INF,velocity: Vector3=Vector3.ZERO) -> bool:
	if not eligible(id) or rows.size()>=LIMIT or kind not in ["pack","ammo","weapon"]:return false
	var s: Dictionary=game.players[id];var payload:=empty_payload();var w: int=s.weapon
	if kind=="pack":
		if s.tribes_pack=="none":return false
		payload.pack=s.tribes_pack
		if payload.pack=="ammo":
			for index in 12:payload.ammo[index]=maxi(0,s.tribes_ammo[index]-A.capacity(s.tribes_class,"none",index))
			payload.beacons=maxi(0,int(s.get("tribes_beacons",0))-3)
	elif kind=="ammo":
		if w<0 or w>=12 or AMMO_CHUNK[w]==0:return false
		payload.ammo[w]=mini(AMMO_CHUNK[w],maxi(0,s.tribes_ammo[w]-(0 if w==2 else 1)))
		if payload.ammo[w]<=0:return false
	else:
		if w<0 or w>=8 or w not in s.owned or s.owned.filter(func(gun):return gun<8).size()<=1:return false
		payload.guns=[w]
	if not point.is_finite():
		var frame: Transform3D=game._weapon_transform(id);point=frame.origin;velocity=-frame.basis.z*8+game.fighters[id].velocity
	var chest: Vector3=game.fighters[id].position+Vector3.UP*game.fighters[id].torso_height()
	if point.distance_to(chest)>2 or not rules.deployables.ray(chest,point).is_empty():return false
	if create(id,payload,point,velocity,kind)<0:return false
	var value: int=A.PACKS[payload.pack].cost+payload.beacons*5
	for index in 12:s.tribes_ammo[index]-=payload.ammo[index];value+=payload.ammo[index]*A.AMMO_PRICE[index]
	for gun in payload.guns:s.owned.erase(gun);value+=A.PRICES[gun]
	s.tribes_beacons=int(s.get("tribes_beacons",0))-payload.beacons
	if kind=="pack":set_pack(id,"none")
	s.tribes_paid=maxi(0,s.tribes_paid-value);select_valid(id)
	stats[kind+"_drops"]=int(stats.get(kind+"_drops",0))+1;return true
func set_pack(id: int,pack: String):
	var s: Dictionary=game.players[id];s.tribes_pack=pack
	game.fighters[id].tribes_state.pack=pack;game.fighters[id].tribes_state.pack_on=false
	if pack=="repair":
		if 8 not in s.owned:s.owned.append(8)
	else:s.owned.erase(8)
	select_valid(id)
func select_valid(id: int):
	var s: Dictionary=game.players[id]
	if s.weapon not in s.owned or s.weapon==5 and s.tribes_pack!="energy":
		var choices: Array=s.owned.filter(func(w):return w<8 and A.allowed(s.tribes_class,w,s.tribes_pack))
		s.weapon=choices[0] if not choices.is_empty() else 11
		if id==game.multiplayer.get_unique_id():game.desired_weapon=s.weapon
func death(id: int):
	if not game.multiplayer.is_server() or not rules.enabled() or not game.players.has(id):return
	var s: Dictionary=game.players[id];var payload:=empty_payload()
	payload.pack=s.tribes_pack;payload.guns=s.owned.filter(func(w):return w<8);payload.ammo=s.tribes_ammo.duplicate();payload.kit=s.tribes_kit;payload.beacons=int(s.get("tribes_beacons",0))
	if rows.size()>=LIMIT:rows.erase(rows.keys()[0])
	create(id,payload,game.fighters[id].position+Vector3.UP*.6,game.fighters[id].velocity*.25,"corpse",24.5)
	# Consume corpse contents once. The next spawn provides its own inventory.
	s.tribes_ammo.fill(0);s.tribes_kit=false;s.tribes_beacons=0;s.tribes_paid=0;s.tribes_pack="none"
func useful(id: int,p: Dictionary) -> bool:
	var s: Dictionary=game.players[id]
	if p.patch and s.hp<rules.definition(id).hp or p.kit and not s.tribes_kit:return true
	if p.pack!="none" and s.tribes_pack=="none" and rules.deployables.Data.allowed(s.tribes_class,p.pack):return true
	if p.beacons>0 and s.get("tribes_beacons",0)<rules.targeting.capacity(id):return true
	for w in p.guns:
		if w not in s.owned and rules.can_carry(id,w):return true
	for w in 12:
		if p.ammo[w]>0 and w in s.owned and s.tribes_ammo[w]<A.capacity(s.tribes_class,s.tribes_pack,w):return true
	return false
func pickup(id: int,key: int) -> bool:
	if not eligible(id) or not rows.has(key):return false
	var row: Dictionary=rows[key];var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if game.clock<row.ready and row.owner==id or game.clock>=row.expires or (actor.position+Vector3.UP*.65).distance_to(row.position)>1.5:return false
	if not rules.deployables.ray(actor.position+Vector3.UP*.65,row.position).is_empty():return false
	var p: Dictionary=row.payload
	if not useful(id,p):return false
	var refundable: int=rules.carried_value(id)
	if p.patch and s.hp<rules.definition(id).hp:s.hp=mini(rules.definition(id).hp,s.hp+roundi(.125*A.UNIT));p.patch=false
	if p.pack!="none" and s.tribes_pack=="none" and rules.deployables.Data.allowed(s.tribes_class,p.pack):set_pack(id,p.pack);p.pack="none"
	for w in p.guns.duplicate():
		if w not in s.owned and rules.can_carry(id,w):s.owned.append(w);p.guns.erase(w)
	for w in 12:
		if w not in s.owned:continue
		var count: int=mini(p.ammo[w],maxi(0,A.capacity(s.tribes_class,s.tribes_pack,w)-s.tribes_ammo[w]))
		s.tribes_ammo[w]+=count;p.ammo[w]-=count
	var beacons: int=mini(p.beacons,maxi(0,rules.targeting.capacity(id)-int(s.get("tribes_beacons",0))))
	s.tribes_beacons=int(s.get("tribes_beacons",0))+beacons;p.beacons-=beacons
	if p.kit and not s.tribes_kit:s.tribes_kit=true;p.kit=false
	if p.pack=="none" and p.guns.is_empty() and p.ammo.all(func(v):return v==0) and not p.kit and p.beacons==0 and not p.patch:rows.erase(key)
	s.tribes_paid=mini(s.tribes_paid,refundable)
	stats["pickups"]=int(stats.get("pickups",0))+1;return true
func tick(delta: float):
	if not rules.enabled() or not game.multiplayer.is_server():return
	for key in rows.keys():
		var row: Dictionary=rows[key]
		if game.clock>=row.expires:rows.erase(key);continue
		if row.kind=="patch":continue
		if row.rest:continue
		var end: Vector3=row.position+row.velocity*delta-Vector3.UP*10*delta*delta
		var hit: Dictionary=rules.deployables.ray(row.position,end)
		row.velocity.y-=20*delta
		if hit.is_empty():row.position=end
		else:
			row.position=hit.position+hit.normal*.08;row.velocity=row.velocity.bounce(hit.normal)*.25
			if row.velocity.length()<1.5:row.rest=true;row.velocity=Vector3.ZERO
	for patch in patches:
		if not rows.has(patch.key):
			if patch.ready==0:patch.ready=game.clock+30
			elif game.clock>=patch.ready:
				var payload:=empty_payload();payload.patch=true
				patch.key=create(0,payload,patch.point,Vector3.ZERO,"patch",86400);patch.ready=0.0
	if game.clock<scan_at:return
	scan_at=game.clock+.1
	for id in game.players:
		if not eligible(id):continue
		for key in rows.keys():pickup(id,key)
func snapshot() -> Dictionary:return rows.duplicate(true)
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()>LIMIT:return false
	for key in data:
		var row=data[key]
		if not key is int or key<=0 or not row is Dictionary or row.size()!=8:return false
		if not row.get("position") is Vector3 or not row.position.is_finite() or row.position.length()>20000 or not row.get("velocity") is Vector3 or not row.velocity.is_finite() or row.velocity.length()>200:return false
		if not row.get("owner") is int or row.get("kind") not in ["pack","ammo","weapon","corpse","patch"] or not row.get("rest") is bool:return false
		for field in ["ready","expires"]:
			if not (row.get(field) is float or row.get(field) is int) or not is_finite(float(row[field])) or row[field]<0:return false
		var p=row.get("payload")
		if not p is Dictionary or p.size()!=6 or not A.PACKS.has(p.get("pack")) or not p.get("kit") is bool or not p.get("patch") is bool or not p.get("beacons") is int or p.beacons<0 or p.beacons>13:return false
		if not p.get("guns") is Array or p.guns.size()>5 or not p.get("ammo") is Array or p.ammo.size()!=12:return false
		var seen: Array=[]
		for w in p.guns:
			if not w is int or w<0 or w>=8 or w in seen:return false
			seen.append(w)
		for w in 12:
			if not p.ammo[w] is int or p.ammo[w]<0 or p.ammo[w]>A.capacity("heavy","ammo",w):return false
	return true
func receive(data: Dictionary):
	if valid(data):rows=data.duplicate(true)

func spawn_patches(points: Array):
	for point in points:
		var payload:=empty_payload();payload.patch=true
		patches.append({"point":point,"ready":0.0,"key":create(0,payload,point,Vector3.ZERO,"patch",86400)})
