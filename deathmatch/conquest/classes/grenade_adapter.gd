extends RefCounted
const Attribution=preload("res://deathmatch/server/attribution.gd")
class Hands extends RefCounted:
	static func primary(pose:Dictionary) -> Transform3D:return pose.left if pose.left_handed else pose.right
const Interaction=Hands
var host:WeakRef
var game:
	get:return host.get_ref()
var phase:="live"
var round_id:=0
var mode:
	get:return game.match_mode
func setup(arena) -> void:host=weakref(arena)
func enabled() -> bool:return game!=null
func alive(id:int) -> bool:return game.players.has(id) and not game.players[id].dead and not game.players[id].spectator
func busy(id:int) -> bool:return game.classes.downed.has(id) or not game.classes.has_grenade(id) or game.lobby.active() or game.intermission>0
func base_pose(id:int) -> Transform3D:return Transform3D(Basis(Vector3.UP,game.players[id].yaw),game.fighters[id].position)
func ray_surface(start:Vector3,end:Vector3) -> Dictionary:return Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(start,end,1),"query.grenade_adapter.ray_surface.ray")
