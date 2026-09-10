extends RefCounted
## Conservative X/Z broad phase, rebuilt from this tick's authoritative poses.
## World collision, exact capsule sweeps, cover and damage stay in Arena._trace.
const Hits=preload("res://deathmatch/hit_detection.gd")
const CELL_SIZE:=4.0
const MAX_CELLS:=64
const MAX_COORD:=1000000.0 # Keep cell conversion safely inside Vector2i's range.
var cells: Dictionary={}
var overflow: Array=[]
var all_ids: Array=[]
var order: Dictionary={}
func build(players: Dictionary,fighters: Dictionary,movement_start: Dictionary) -> void:
	cells.clear();overflow.clear();all_ids.clear();order.clear()
	for id in players:
		var state: Dictionary=players[id]
		if state.dead or state.spectator:continue
		order[id]=all_ids.size();all_ids.append(id)
		var current: Vector3=fighters[id].position
		var previous: Vector3=current
		if movement_start.has(id) and movement_start[id].serial==state.serial:previous=movement_start[id].position
		if not grid_safe(current) or not grid_safe(previous):overflow.append(id);continue
		var low:=Vector2i(floori((minf(current.x,previous.x)-Hits.PLAYER_RADIUS-.000001)/CELL_SIZE),floori((minf(current.z,previous.z)-Hits.PLAYER_RADIUS-.000001)/CELL_SIZE))
		var high:=Vector2i(floori((maxf(current.x,previous.x)+Hits.PLAYER_RADIUS+.000001)/CELL_SIZE),floori((maxf(current.z,previous.z)+Hits.PLAYER_RADIUS+.000001)/CELL_SIZE))
		if large_range(low,high):overflow.append(id);continue
		for x in range(low.x,high.x+1):
			for z in range(low.y,high.y+1):
				var key:=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(id)
static func large_range(low: Vector2i,high: Vector2i) -> bool:
	# Bound both axes before multiplying, including malformed / huge travel.
	var width:=int(high.x)-int(low.x)+1;var depth:=int(high.y)-int(low.y)+1
	return width<1 or depth<1 or width>MAX_CELLS or depth>MAX_CELLS or width*depth>MAX_CELLS
static func grid_safe(position: Vector3) -> bool:
	return position.is_finite() and absf(position.x)<=MAX_COORD and absf(position.z)<=MAX_COORD
func candidates(start: Vector3,end: Vector3,radius: float) -> Array:
	if not grid_safe(start) or not grid_safe(end) or not is_finite(radius) or radius>MAX_COORD:return all_ids
	var pad:=maxf(0,radius)+.000001
	var low:=Vector2i(floori((minf(start.x,end.x)-pad)/CELL_SIZE),floori((minf(start.z,end.z)-pad)/CELL_SIZE))
	var high:=Vector2i(floori((maxf(start.x,end.x)+pad)/CELL_SIZE),floori((maxf(start.z,end.z)+pad)/CELL_SIZE))
	if large_range(low,high):return all_ids
	if low==high and overflow.is_empty():return cells.get(low,[])
	var unique: Dictionary={}
	for id in overflow:unique[id]=true
	for x in range(low.x,high.x+1):
		for z in range(low.y,high.y+1):
			for id in cells.get(Vector2i(x,z),[]):unique[id]=true
	var result: Array=unique.keys()
	# Preserve the old full scan's tie-breaking for overlapping damage capsules.
	if result.size()>1:result.sort_custom(func(a,b):return order[a]<order[b])
	return result
