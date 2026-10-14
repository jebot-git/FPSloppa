extends CharacterBody3D
## Simple stationary/drive collider exposed to existing vehicle lock and repair services.
var service
var key:int
var hp:int:
	get:return service.rows.get(key,{}).get("hp",0)
var team:int:
	get:return service.rows.get(key,{}).get("team",-1)
func owns_collider(collider:Node) -> bool:return collider==self or is_ancestor_of(collider)
func damage(attacker_team:int,amount:int) -> int:return service.damage(key,attacker_team,amount,"ordnance")
func repair(request_team:int,amount:int) -> int:
	if not multiplayer.is_server() or request_team!=team or hp<=0 or amount<=0:return 0
	var restored:int=mini(amount,service.profile(service.rows[key]).hp-hp);service.rows[key].hp+=restored;return restored
