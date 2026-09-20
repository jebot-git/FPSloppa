extends RefCounted
## The master reserves both sides of an unfinished transfer, including dead actors.
const LIMIT:=16
const Rules=preload("res://deathmatch/conquest/rules.gd")
static func claims(owner: Dictionary) -> Array:
	var result: Array=[]
	for key in ["zone","source","respawn_zone"]:
		var zone: int=owner.get(key,-1)
		if zone in range(16) and zone not in result:result.append(zone)
	return result
static func counts(owners: Dictionary,exclude: int=0) -> Array:
	var result: Array=[];result.resize(16);result.fill(0)
	for id in owners:
		if id==exclude:continue
		for zone in claims(owners[id]):result[zone]+=1
	return result
static func available(owners: Dictionary,zone: int,id: int=0) -> bool:
	return zone in range(16) and counts(owners,id)[zone]<LIMIT
static func nearest(owners: Dictionary,territories: Array,team: int,point: Vector3,id: int=0) -> int:
	var occupied:=counts(owners,id);var best:=-1;var distance:=INF
	for zone in 16:
		if territories[zone]!=team or occupied[zone]>=LIMIT:continue
		var delta:=Vector2(Rules.center(zone).x-point.x,Rules.center(zone).z-point.z)
		if delta.length_squared()<distance:best=zone;distance=delta.length_squared()
	return best
