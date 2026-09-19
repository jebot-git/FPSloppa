extends RefCounted
## Pure CQ territory rules. One point per second, independent of squad size.
const HOMEBASES=[0,3,12,15]
const PERIMETERS={0:[1,4,5],3:[2,6,7],12:[8,9,13],15:[10,11,14]}
const INITIAL=[0,0,1,1,0,0,1,1,1,1,0,0,1,1,0,0]
const RADIUS:=3.0
var owners: Array=INITIAL.duplicate()
var progress: Array=[]
var contested: Array=[]
var revision:=0
func _init() -> void:reset()
func reset() -> void:
	owners=INITIAL.duplicate();progress=[];contested=[];revision+=1
	for zone in 16:progress.append([0.0,0.0]);contested.append(false)
static func district(point: Vector3) -> int:
	return clampi(floori((point.x+500.0)/250.0),0,3)+4*clampi(floori((point.z+500.0)/250.0),0,3)
static func center(zone: int) -> Vector3:return Vector3(-375+(zone%4)*250,.05,-375+floori(zone/4.0)*250)
static func neighbors(zone: int) -> Array:
	var result: Array=[]
	for other in 16:
		if absi(other%4-zone%4)+absi(floori(other/4.0)-floori(zone/4.0))==1:result.append(other)
	return result
static func radio_connected(a: int,b: int) -> bool:return a==b or b in neighbors(a)
static func threshold(zone: int) -> float:return 30.0 if zone in HOMEBASES else 10.0
func unlocked(zone: int,team: int) -> bool:
	if not zone in HOMEBASES:return true
	for perimeter in PERIMETERS[zone]:
		if owners[perimeter]!=team:return false
	return true
func advance(delta: float,presence: Array) -> Array:
	var captured: Array=[]
	# All eligibility decisions use ownership at the beginning of the step.
	var ready: Array=[]
	for zone in 16:ready.append([unlocked(zone,0),unlocked(zone,1)])
	var order: Array=range(16).filter(func(zone):return not zone in HOMEBASES)+HOMEBASES
	for zone in order:
		var here: Array=presence[zone]
		contested[zone]=bool(here[0]) and bool(here[1])
		for team in 2:
			if not here[team] or (not ready[zone][team] or not unlocked(zone,team)):progress[zone][team]=0.0
		if contested[zone]:continue
		var team:=0 if here[0] else 1 if here[1] else -1
		if team<0 or owners[zone]==team or not ready[zone][team] or not unlocked(zone,team):continue
		progress[zone][team]=minf(threshold(zone),progress[zone][team]+maxf(0,delta))
		if progress[zone][team]+.000001>=threshold(zone):
			owners[zone]=team;progress[zone]=[0.0,0.0];revision+=1;captured.append(zone)
	return captured
func scores() -> Array:
	var result: Array=[0,0]
	for zone in HOMEBASES:result[owners[zone]]+=1
	return result
func winner(timeout: bool=false) -> int:
	var counts:=scores()
	if counts[0]==4:return 0
	if counts[1]==4:return 1
	if not timeout:return -2
	return -1 if counts[0]==counts[1] else 0 if counts[0]>counts[1] else 1
func nearest(team: int,position: Vector3) -> int:
	var best:=-1;var distance:=INF
	for zone in 16:
		if owners[zone]!=team:continue
		var offset:=Vector2(center(zone).x-position.x,center(zone).z-position.z)
		if offset.length_squared()<distance:best=zone;distance=offset.length_squared()
	return best
func snapshot() -> Dictionary:return {"owners":owners.duplicate(),"progress":progress.duplicate(true),"contested":contested.duplicate(),"revision":revision}
func receive(data: Dictionary) -> void:
	if data.get("owners",[]).size()!=16 or data.get("progress",[]).size()!=16:return
	owners=data.owners.duplicate();progress=data.progress.duplicate(true);contested=data.get("contested",[]).duplicate();revision=int(data.get("revision",0))
