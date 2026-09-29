extends SceneTree
const Routes=preload("res://deathmatch/bot_ai/tribes_routes.gd")
class UncachedGraph extends Routes.TerrainGraph:
	func _compute_cost(from_id: int,to_id: int) -> float:
		edge_costs.clear()
		return super._compute_cost(from_id,to_id)
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("ST query equivalence",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	while not g.bots.navigation.ready():await physics_frame
	var cached=g.bots.tribes.routes;var plain=Routes.new();plain.ai=g.bots;plain.graph=UncachedGraph.new()
	cached.build();plain.build()
	for context in [{"walk":11.0,"speed":14.3,"reserve":1.0},{"walk":11.0,"speed":28.0,"reserve":.2},{"walk":8.0,"speed":10.4,"reserve":.6},{"walk":5.0,"speed":17.0,"reserve":.4}]:
		for team in [0,1]:
			var start: Vector3=g.match_mode.bases[team];var goal: Vector3=g.match_mode.bases[1-team]
			for lane in [-1,0,1]:
				for avoided in [false,true]:
					var avoid: Array=[{"point":start.lerp(goal,.5),"until":g.clock+100}] if avoided else []
					var reference: PackedVector3Array=plain.path(start,goal,lane,avoid,context)
					var actual: PackedVector3Array=cached.path(start,goal,lane,avoid,context)
					checks+=1
					if actual!=reference:failures.append({"team":team,"lane":lane,"context":context,"avoid":avoided})
	print("ST_ROUTE_CACHE ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
