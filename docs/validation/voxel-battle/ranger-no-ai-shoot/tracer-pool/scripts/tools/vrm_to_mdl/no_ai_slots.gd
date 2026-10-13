extends Node
## Lifecycle protocol only. No perception, navigation, planning or steering.
class ReadyNavigation extends RefCounted:
	func ready() -> bool:return true
var navigation:=ReadyNavigation.new()
var region:=NavigationRegion3D.new()
var brains: Dictionary={}
var teamplay=null
var boosts:=0
var tick_ms: Array=[]
var ai_work_calls:=0
func setup(_game: Node) -> void:
	region.navigation_mesh=NavigationMesh.new();add_child(region)
func tick(_delta: float) -> void:pass
