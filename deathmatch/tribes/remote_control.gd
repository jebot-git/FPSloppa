extends RefCounted
## Leased, exclusive control of deployed cameras and turrets; rows keep old demo shape.
var rules
var claims: Dictionary={}
var operators: Dictionary={}
var game:
	get:return rules.game
func setup(value):rules=value
func reset():claims.clear();operators.clear()
func operated(id: int) -> int:
	for key in operators:if id!=0 and operators[key]==id:return key
	return -1
func release(id: int):
	for key in operators.keys():
		if operators[key]==id:operators.erase(key);claims.erase(key)
func eligible(id: int) -> bool:
	return rules.deployables.accessible(id) and not rules.vehicles.mounted(id) and rules.mode.st.carried(id)<0
func active(key: int) -> bool:
	var row: Dictionary=rules.deployables.rows.get(key,{})
	return not row.is_empty() and row.kind in ["camera","turret"] and game.clock>=row.ready and rules.deployables.operational(row)
func control(id: int,key: int,epoch: int,life: int) -> bool:
	if not game.multiplayer.is_server() or epoch!=game.map_epoch or game.players.get(id,{}).get("serial",-1)!=life:return false
	if key<0:release(id);return true
	if not eligible(id) or not active(key) or rules.deployables.rows[key].team!=game.players[id].team or operators.get(key,0) not in [0,id]:return false
	release(id)
	var pads=rules.stations()
	if pads:pads.defences.release(id)
	operators[key]=id;claims[key]={"life":life,"lease":game.clock+1,"aim":rules.deployables.rows[key].aim,"fire":false}
	rules.combat.cancel(id);return true
func command(id: int,key: int,epoch: int,life: int,aim: Vector3,fire: bool) -> bool:
	if not game.multiplayer.is_server() or epoch!=game.map_epoch or not eligible(id) or not active(key) or operators.get(key,0)!=id or not claims.has(key):return false
	if life!=claims[key].life or life!=game.players[id].serial or rules.deployables.rows[key].team!=game.players[id].team:return false
	if game.players[id].get("input_blocked",false):claims[key].fire=false;return false
	if not aim.is_finite() or absf(aim.length()-1)>.01:return false
	claims[key].merge({"aim":aim,"fire":fire,"lease":game.clock+.6},true);return true
func tick():
	if not game.multiplayer.is_server():return
	for key in operators.keys():
		var id: int=operators[key];var row: Dictionary=claims.get(key,{})
		if not eligible(id) or not active(key) or rules.deployables.rows[key].team!=game.players[id].team or row.get("life",-1)!=game.players[id].serial or game.clock>row.get("lease",0):release(id)
func advance(key: int,delta: float) -> bool:
	if not operators.has(key) or not claims.has(key):return false
	var row: Dictionary=rules.deployables.rows[key];var command: Dictionary=claims[key]
	row.aim=row.aim.slerp(command.aim,minf(1,delta*6)).normalized()
	if row.kind=="turret" and not game.players[operators[key]].get("input_blocked",false) and command.fire and row.aim.dot(command.aim)>.97:rules.deployables.fire(key,operators[key])
	return true
func snapshot() -> Dictionary:return operators.duplicate()
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()>50:return false
	var people: Array=[]
	for key in data:
		if not key is int or key<=0 or not data[key] is int or data[key]==0 or data[key] in people:return false
		people.append(data[key])
	return true
func receive(data: Dictionary):
	if valid(data):operators=data.duplicate();claims.clear()
