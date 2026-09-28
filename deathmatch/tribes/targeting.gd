extends RefCounted
const A=preload("res://deathmatch/tribes/arsenal.gd")
const Ballistics=preload("res://deathmatch/tribes/ballistics.gd")
var rules
var game
var beacons: Dictionary={}
var lasers: Dictionary={}
var next_id:=1
var stats: Dictionary={}
func setup(value):rules=value;game=rules.game
func reset():beacons.clear();lasers.clear();next_id=1;stats.clear()
func capacity(id: int) -> int:return 13 if game.players.get(id,{}).get("tribes_pack","")=="ammo" else 3
func buy(id: int) -> bool:
	if not rules.recovery.eligible(id) or not rules.can_refit(id):return false
	var s: Dictionary=game.players[id];var count: int=mini(capacity(id)-int(s.get("tribes_beacons",0)),rules.deployables.available(id)/5)
	if count<=0:return false
	rules.deployables.pay(id,count*5);s.tribes_beacons=int(s.get("tribes_beacons",0))+count;s.tribes_paid+=count*5;return true
func place(id: int,origin: Vector3,direction: Vector3) -> bool:
	if not rules.recovery.eligible(id) or rules.mode.kind!="st" or game.players[id].get("tribes_beacons",0)<=0 or not origin.is_finite() or not direction.is_finite() or absf(direction.length()-1)>.01:return false
	var s: Dictionary=game.players[id];var eye: Vector3=game.fighters[id].position+Vector3.UP*game.fighters[id].eye_height()
	if beacons.values().filter(func(row):return row.team==s.team).size()>=40 or eye.distance_to(origin)>1.8 or not rules.deployables.ray(eye,origin).is_empty():return false
	var hit: Dictionary=rules.deployables.ray(origin,origin+direction*3)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.collider is AnimatableBody3D or hit.collider.has_meta("st_deployable"):return false
	var point: Vector3=hit.position+hit.normal*.17;var pads=rules.stations()
	if not pads or not pads.playable_bounds.has_point(point):return false
	if beacons.values().any(func(row):return row.position.distance_to(point)<.5):return false
	for peer in game.players:
		if not game.players[peer].dead and not game.players[peer].spectator and (game.fighters[peer].position+Vector3.UP*.6).distance_to(point)<.75:return false
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=SphereShape3D.new();shape.radius=.14;query.shape=shape;query.transform.origin=point;query.collision_mask=1
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	beacons[next_id]={"team":s.team,"position":point,"normal":hit.normal,"hp":.1*A.UNIT};next_id+=1
	s.tribes_beacons-=1;s.tribes_paid=maxi(0,s.tribes_paid-5)
	stats["placed"]=int(stats.get("placed",0))+1;return true
func designate(id: int,hit: Dictionary):
	if not rules.recovery.eligible(id) or rules.mode.kind!="st" or game.players[id].weapon!=11 or not game.players[id].fire or not hit.hit:return
	lasers[id]={"team":game.players[id].team,"position":hit.position,"until":game.clock+.45,"life":game.players[id].serial}
	stats["designations"]=int(stats.get("designations",0))+1
func tick():
	for id in lasers.keys():
		if not rules.recovery.eligible(id) or lasers[id].until<game.clock or game.players[id].serial!=lasers[id].life or game.players[id].weapon!=11 or not game.players[id].fire or game.players[id].get("input_blocked",false):lasers.erase(id)
func targets(team: int) -> Array:
	var result: Array=[]
	for key in beacons:
		var row: Dictionary=beacons[key]
		if row.team==team and row.hp>.05*A.UNIT:result.append({"position":row.position,"name":"BEACON %d"%key,"key":"b%d"%key})
	for id in lasers:
		var row: Dictionary=lasers[id]
		if row.team==team and row.until>=game.clock:result.append({"position":row.position,"name":"LASER","key":"l%d"%id})
	return result
func solution(id: int,target: Vector3,w: int=-1) -> Dictionary:
	if not game.players.has(id) or not game.fighters.has(id):return {}
	if w<0:w=game.players[id].weapon
	if w not in [4,7]:return {}
	var shot: Dictionary=game._shot_solution(id)
	if shot.blocked:return {}
	var d: Dictionary=A.table()[w];var inherited: Vector3=game.fighters[id].velocity*d.inherit
	for high in [false,true]:
		var result:=Ballistics.solve(shot.origin,target,d.speed,d.gravity,inherited,high)
		if not result.is_empty() and result.time>=d.arm and Ballistics.clear(game.get_world_3d().direct_space_state,shot.origin,result,d.gravity,d.radius):return result
	return {}
func trace(start: Vector3,end: Vector3,hit: Dictionary,radius: float) -> Dictionary:
	var nearest: float=start.distance_to(hit.position)
	for key in beacons:
		var fraction: float=preload("res://deathmatch/hit_detection.gd").sphere_fraction(start,end-start,beacons[key].position,.16+radius)
		if not is_finite(fraction):continue
		var point: Vector3=start.lerp(end,fraction)
		if start.distance_to(point)<nearest:
			nearest=start.distance_to(point);hit={"id":0,"hit":true,"position":point,"beacon":key}
	return hit
func damage(key: int,id: int,amount: float):
	if not game.multiplayer.is_server() or not beacons.has(key) or not is_finite(amount) or amount<=0:return
	var row: Dictionary=beacons[key]
	if game.players.get(id,{}).get("team",-1)==row.team and not rules.mode.friendly_fire:return
	row.hp=maxf(0,row.hp-amount)
	if row.hp<=.025*A.UNIT:beacons.erase(key)
func blast(point: Vector3,id: int,amount: float,radius: float,team: int=-1):
	for key in beacons.keys():
		var row: Dictionary=beacons[key];var distance: float=point.distance_to(row.position)
		if distance>=radius or row.team==team and not rules.mode.friendly_fire:continue
		if rules.deployables.ray(point,row.position).is_empty():damage(key,id,amount*(1-distance/radius))
func snapshot() -> Dictionary:return {"beacons":beacons.duplicate(true),"lasers":lasers.duplicate(true)}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2 or not data.get("beacons") is Dictionary or data.beacons.size()>80 or not data.get("lasers") is Dictionary or data.lasers.size()>128:return false
	for kind in ["beacons","lasers"]:
		var counts: Array=[0,0]
		for key in data[kind]:
			var row=data[kind][key]
			if not key is int or kind=="beacons" and key<=0 or not row is Dictionary or row.size()!=4 or not row.get("team") is int or row.get("team") not in [0,1] or not row.get("position") is Vector3 or not row.position.is_finite() or row.position.length()>20000:return false
			counts[row.team]+=1
			if kind=="beacons":
				if counts[row.team]>40 or not row.get("normal") is Vector3 or not row.normal.is_finite() or absf(row.normal.length()-1)>.01 or not (row.get("hp") is float or row.get("hp") is int) or not is_finite(float(row.hp)) or row.hp<0 or row.hp>.1*A.UNIT:return false
			elif not (row.get("until") is float or row.get("until") is int) or not is_finite(float(row.until)) or row.until<0 or not row.get("life") is int:return false
	return true
func receive(data: Dictionary):
	if valid(data):beacons=data.beacons.duplicate(true);lasers=data.lasers.duplicate(true)

func repair(key: int,id: int,amount: float) -> bool:
	if not game.multiplayer.is_server() or not beacons.has(key) or game.players.get(id,{}).get("team",-1)!=beacons[key].team or not is_finite(amount) or amount<=0:return false
	var before: float=beacons[key].hp;beacons[key].hp=minf(.1*A.UNIT,before+amount);return beacons[key].hp>before
