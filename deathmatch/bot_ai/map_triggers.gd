extends RefCounted
## Resolve map controls, but operate them only through ordinary movement/fire input.
var ai
var logic
func setup(owner_ai) -> void:
	ai=owner_ai
	var runtime=ai.game.get_node_or_null("Map/MapRuntime")
	if runtime:logic=runtime.triggers
func available(node: Node) -> bool:
	if not is_instance_valid(node) or not logic.rows.has(node):return false
	var row: Dictionary=logic.rows[node]
	return node.visible and ai.game.clock>=row.until and (row.gate<0 or not ai.game.gates[row.gate].open)
func controls(node: Node,seen: Array=[]) -> Array:
	if node in seen or seen.size()>=32:return []
	seen=seen.duplicate();seen.append(node)
	var row: Dictionary=logic.rows[node]
	if row.hp>0 or row.kind in ["func_button","trigger_once","trigger_multiple","trigger_secret"]:return [node]
	var result: Array=[]
	# Linked panels can carry the targetname on any member.
	for member in row.get("group",[node]):
		var name: String=logic.rows[member].data.get("targetname","")
		if name.is_empty():continue
		for source in logic.rows:
			if logic.rows[source].data.get("target","")==name:
				for control in controls(source,seen):
					if not control in result:result.append(control)
	return result
func friendly_trap(node: Node,id: int,seen: Array=[]) -> bool:
	if node in seen or seen.size()>=32:return false
	seen=seen.duplicate();seen.append(node)
	var row: Dictionary=logic.rows[node]
	if row.gate>=0 and float(row.data.get("dmg",0))>0:
		var gate: Dictionary=ai.game.gates[row.gate]
		var danger: AABB=row.bounds.merge(AABB(row.bounds.position+gate.travel,row.bounds.size)).grow(.4)
		for peer in ai.game.players:
			if ai.alive(peer) and (peer==id or ai.game.match_mode.same_team(id,peer)) and danger.has_point(ai.target_position(peer)):return true
	for next in logic.targets.get(row.data.get("target",""),[]):
		if friendly_trap(next,id,seen):return true
	return false
func approach(node: Node,id: int) -> Dictionary:
	var row: Dictionary=logic.rows[node];var origin: Vector3=ai.game.fighters[id].position
	var best: Dictionary={};var cost:=INF
	var center: Vector3=row.bounds.get_center()
	if row.hp>0 and ai.game._trace(ai.eye(id),center,id).get("map_node")==node:
		return {"goal":origin,"path":PackedVector3Array(),"point":center}
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var point: Vector3=center+direction*(logic.extent(row.bounds.size,direction)*.5+.28)
		point.y=clampf(origin.y,row.bounds.position.y,row.bounds.end.y)
		var floor_hit: Dictionary=ai.navigation.ray(point+Vector3.UP*.4,point-Vector3.UP*2)
		if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
		point=floor_hit.position+Vector3.UP*.03
		if ai.navigation.hazardous(point):continue
		var hit: Dictionary=ai.navigation.ray(point+Vector3.UP*.8,center)
		if not hit.is_empty() and hit.collider!=node:continue
		var path: PackedVector3Array=ai.navigation.path(origin,point)
		var distance: float=ai.navigation.cost(origin,point,path)
		if distance<cost:cost=distance;best={"goal":point,"path":path,"point":center}
	return best
func find_control(id: int,brain: Dictionary) -> Node:
	var actor=ai.game.fighters[id];var blockers: Array=[]
	var from: Vector3=ai.eye(id)
	for step in range(brain.step,mini(brain.step+5,brain.path.size())):
		var to: Vector3=brain.path[step]+Vector3.UP*.8
		var hit: Dictionary=ai.navigation.ray(from,to)
		if not hit.is_empty():
			if logic.rows.has(hit.collider):blockers.append(hit.collider)
			break
		from=to
	# A nearby visible secret is worth opening even when it is not on the current route.
	if blockers.is_empty():
		for node in logic.rows:
			var row: Dictionary=logic.rows[node]
			if row.kind=="func_door_secret" and actor.position.distance_to(row.bounds.get_center())<10:
				if ai.game._trace(ai.eye(id),row.bounds.get_center(),id).get("map_node")==node:blockers.append(node)
	for blocker in blockers:
		if not available(blocker):continue
		for node in controls(blocker):
			if available(node) and ai.game.clock>=brain.get("map_avoid",{}).get(node,0.0) and not friendly_trap(node,id):return node
	return null
func tick(id: int,brain: Dictionary,delta: float) -> bool:
	if logic==null or logic.rows.is_empty() or ai.game.clock<brain.boost_until:return false
	var action: Dictionary=brain.get("map_action",{})
	if brain.enemy!=0 and ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<6:
		if not action.is_empty():brain.map_action={};brain.plan_at=0
		return false
	if not action.is_empty() and (not available(action.node) or ai.game.clock>action.until or friendly_trap(action.node,id)):
		brain.map_avoid[action.node]=ai.game.clock+12;brain.map_action={};brain.plan_at=0;return false
	if action.is_empty():
		if ai.game.clock<brain.get("map_scan_at",0.0):return false
		brain.map_scan_at=ai.game.clock+.4
		var node:=find_control(id,brain)
		if node==null:return false
		action=approach(node,id)
		if action.is_empty():return false
		action.node=node;action.until=ai.game.clock+8
		brain.map_action=action;brain.map_avoid=brain.get("map_avoid",{})
		brain.goal=action.goal;brain.path=action.path;brain.step=0;brain.goal_key="map_control";brain.goal_kind="map_control";brain.hold=true
		ai.teamplay.count("map_control_plans")
	brain.plan_at=ai.game.clock+.8;brain.progress_at=ai.game.clock
	var state: Dictionary=ai.game.players[id];state.fire=false;state.alt_fire=false
	ai.steer(id,brain,delta)
	var row: Dictionary=logic.rows[action.node]
	if row.hp>0:
		var hit: Dictionary=ai.game._trace(ai.eye(id),action.point,id)
		if hit.get("map_node")==action.node:
			# Prefer direct, nonexplosive shots; no ability or remote activation shortcut.
			for weapon in state.owned:
				var data: Dictionary=ai.game.match_mode.fortress.weapon_data(id,weapon)
				if not ai.game.match_mode.fortress.can_fire(id,weapon) or ai.melee_weapon(id,weapon) or ai.explosive_weapon(id,weapon) or float(data.get("speed",0))>0:continue
				if ai.eye(id).distance_to(action.point)>float(data.get("range",100)):continue
				state.weapon=weapon
				state.fire=ai.aim(id,action.point,1-exp(-10*delta)) and ai.safe_shot(id,action.point)
				break
	return true
