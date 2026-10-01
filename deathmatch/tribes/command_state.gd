extends RefCounted
## Voluntary command hierarchy and bounded team orders. No movement or combat cheats.
const VERBS:=["move","attack","defend"]
const STATES:=["pending","accepted","complete","declined"]
var rules
var commanders: Dictionary={}
var orders: Dictionary={}
var requests: Dictionary={}
var game:
	get:return rules.game
func setup(value):rules=value
func reset():commanders.clear();orders.clear();requests.clear()
func member(id: int) -> bool:
	return rules.enabled() and rules.mode.kind=="st" and game.active and not game.map_loading and game.intermission<=0 and game.players.has(id) and game.fighters.has(id) and not game.players[id].spectator and game.players[id].team in [0,1]
func allied(a: int,b: int) -> bool:return member(a) and member(b) and game.players[a].team==game.players[b].team
func controls(leader: int,unit: int) -> bool:
	if leader==unit:return true
	var current:=unit
	for i in 128:
		current=commanders.get(current,0)
		if current==0:return false
		if current==leader:return true
	return false
func follow(id: int,leader: int) -> bool:
	if leader==0:commanders.erase(id);orders.erase(id);return true
	if not allied(id,leader) or id==leader or controls(id,leader):return false
	commanders[id]=leader;orders.erase(id);return true
func point_valid(point: Vector3) -> bool:
	var pads=rules.stations()
	return point.is_finite() and pads and pads.playable_bounds.grow(1).has_point(point)
func request(id: int,epoch: int,life: int,sequence: int,action: String,units: Array,point: Vector3) -> bool:
	if not game.multiplayer.is_server() or not member(id) or epoch!=game.map_epoch or life!=game.players[id].serial or sequence<=int(requests.get(id,0)) or units.size()>16:return false
	if action not in VERBS+["follow","unfollow","accept","complete","decline"]:return false
	for unit in units:if not unit is int:return false
	if game.clock<float(game.players[id].get("st_order_at",0)):return false
	requests[id]=sequence;game.players[id].st_order_at=game.clock+.15
	if action=="follow":return units.size()==1 and follow(id,units[0])
	if action=="unfollow":return follow(id,0)
	if action in ["accept","complete","decline"]:
		if not orders.has(id) or orders[id].life!=life:return false
		if action=="complete" and orders[id].status!="accepted":return false
		if action=="accept" and orders[id].status!="pending":return false
		orders[id].status={"accept":"accepted","complete":"complete","decline":"declined"}[action];return true
	if units.is_empty() or not point_valid(point):return false
	var accepted:=false
	for unit in units:
		if not allied(id,unit) or game.players[unit].dead:continue
		# Unassigned bots accept a human commander; human allegiance stays voluntary.
		if unit<0 and commanders.get(unit,0)==0 and id>0:commanders[unit]=id
		if not controls(id,unit):continue
		orders[unit]={"from":id,"verb":action,"point":point,"status":"accepted" if unit<0 or unit==id else "pending","life":game.players[unit].serial,"until":game.clock+180}
		if unit<0 and is_instance_valid(game.bots) and game.bots.brains.has(unit):game.bots.brains[unit].plan_at=0
		accepted=true
	return accepted
func tick():
	if not game.multiplayer.is_server():return
	for unit in commanders.keys():
		if not allied(unit,commanders[unit]):commanders.erase(unit)
	for unit in orders.keys():
		var row: Dictionary=orders[unit]
		if not allied(unit,row.from) or game.players[unit].dead or game.players[unit].serial!=row.life or game.clock>row.until or not controls(row.from,unit):orders.erase(unit)
func bot_goal(id: int,ai,rows: Array) -> bool:
	var row: Dictionary=orders.get(id,{})
	if row.is_empty() or row.status!="accepted" or row.life!=game.players[id].serial:return false
	if game.fighters[id].position.distance_to(row.point)<6 and row.verb!="defend":ai.action("st_order_complete",[id]);return false
	ai.candidate(rows,"st:order","objective",row.point,450);return true
func snapshot() -> Dictionary:return {"commanders":commanders.duplicate(),"orders":orders.duplicate(true)}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2 or not data.get("commanders") is Dictionary or not data.get("orders") is Dictionary or data.commanders.size()>128 or data.orders.size()>128:return false
	for unit in data.commanders:
		if not unit is int or unit==0 or not data.commanders[unit] is int or data.commanders[unit]==0 or unit==data.commanders[unit]:return false
	for unit in data.commanders:
		var seen: Array=[unit];var current: int=data.commanders[unit]
		while data.commanders.has(current):
			if current in seen:return false
			seen.append(current);current=data.commanders[current]
	for unit in data.orders:
		var row=data.orders[unit]
		if not unit is int or unit==0 or not row is Dictionary or row.size()!=6 or not row.get("from") is int or not row.get("life") is int:return false
		if row.get("verb") not in VERBS or row.get("status") not in STATES or not row.get("point") is Vector3 or not row.point.is_finite() or row.point.length()>20000:return false
		if not (row.get("until") is float or row.get("until") is int) or not is_finite(float(row.until)):return false
	return true
func receive(data: Dictionary):
	if valid(data):commanders=data.commanders.duplicate();orders=data.orders.duplicate(true)
