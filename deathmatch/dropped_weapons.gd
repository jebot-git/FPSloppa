extends RefCounted
## Separate IDs keep map pickup indices stable for snapshots and late joiners.
const LIMIT:=64
const LIFETIME:=30.0
var game
var entries: Dictionary={}
var next_id:=0
func clear() -> void:
	for id in entries.keys():remove(id)
func remove(id: int) -> void:
	var node=entries[id].get("node")
	if is_instance_valid(node):node.queue_free()
	entries.erase(id)
func drop(id: int) -> void:
	if not game.multiplayer.is_server() or game.lobby.active():return
	var state: Dictionary=game.players[id]
	var weapon: int=state.weapon
	if state.spectator or not game.armory.valid(weapon) or weapon in state.get("starting_weapons",state.owned) or not weapon in state.owned:return
	var amount: int=game.variant_combat.cs.loaded_ammo(id,weapon) if game.match_mode.defusal.enabled() else game.armory.pickup_ammo(weapon)
	var position: Vector3=game.fighters[id].position
	var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.5,position-Vector3.UP*2,1)
	var floor_hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():position=floor_hit.position
	if entries.size()>=LIMIT:remove(entries.keys()[0])
	next_id+=1
	add(next_id,position,weapon,amount)
func add(id: int,position: Vector3,weapon: int,amount: int) -> void:
	if entries.has(id):remove(id)
	elif entries.size()>=LIMIT:remove(entries.keys()[0])
	var pickup: Dictionary={"kind":"weapon","item":weapon,"position":position,"amount":amount,"available":true,"respawn":INF,"expires":game.clock+LIFETIME,"dropped":true,"node":null,"title":game.armory.data(weapon).name}
	if not game.headless:
		pickup.node=game._pickup_art(pickup)
	entries[id]=pickup
func tick() -> void:
	for id in entries.keys():
		if not entries[id].available or game.clock>=entries[id].expires:remove(id)
func snapshot() -> Array:
	var result: Array=[]
	for id in entries:
		var p: Dictionary=entries[id]
		if p.available:result.append([id,p.position,p.item,p.amount])
	return result
func receive(rows: Array) -> void:
	var seen: Dictionary={}
	for row in rows.slice(0,LIMIT):
		if not row is Array or row.size()!=4 or not row[0] is int or not row[1] is Vector3 or not row[1].is_finite() or not row[2] is int or not game.armory.valid(row[2]) or not row[3] is int:continue
		var id: int=row[0];seen[id]=true
		if not entries.has(id):add(id,row[1],row[2],maxi(0,row[3]))
	for id in entries.keys():
		if not seen.has(id):remove(id)
