extends Node
## Injected only into the audit PCK, using the actual console engine and server graph.
var game
var failures: Array=[]
var maps: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _ready() -> void:run.call_deferred()
func presentation_nodes() -> int:
	var count:=0
	var stack: Array=[game]
	while not stack.is_empty():
		var node: Node=stack.pop_back();stack.append_array(node.get_children())
		if node is VisualInstance3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is Control:count+=1
	return count
func run() -> void:
	check(OS.has_feature("dedicated_server") and DisplayServer.get_name()=="headless","Dedicated feature and headless-only display")
	check(not ClassDB.class_exists("GLTFDocument") and not ClassDB.class_exists("OpenXRInterface"),"No avatar renderer or OpenXR runtime")
	game=load("res://deathmatch/arena.tscn").instantiate();get_tree().root.add_child(game)
	check(game.dedicated and game.active,"Direct executable starts dedicated hosting")
	check(game.voice.get_script().resource_path.ends_with("/relay.gd") and game.voice.mic==null,"Voice uses packet relay without microphone")
	check(game.spatial==null and game.music==null and game.permissions==null,"No client audio or permission services")
	for row in game.map_catalog:
		game.match_mode.kind="dm"
		check(game._load_map(row.id),"Load server map "+row.id)
		await get_tree().physics_frame
		var runtime=game.get_node("Map/MapRuntime")
		var shapes: int=game.get_node("Map").find_children("*","CollisionShape3D",true,false).size()
		check(shapes>0 and not game.spawn_points.is_empty(),row.id+" keeps collision and spawns")
		check(runtime.bounds.size.length()>1 and is_finite(game.fall_limit),row.id+" keeps map bounds")
		check(presentation_nodes()==0,row.id+" has no rendering, UI or audio nodes")
		var liquid_count:=0
		for region in runtime.regions:
			if region.kind in ["water","slime","lava"]:liquid_count+=1
		if row.id=="lqdm1":check(liquid_count>0,row.id+" keeps liquid volumes")
		if row.id=="as_hislop":check(runtime.has_contents and runtime.contents.at(Vector3(-3,3.05,0))==-4,"HiSlop sludge remains detectable from BSP contents")
		for gate in game.gates:
			if gate.get("train",false):
				var train: Dictionary=game.get_node("Map/MapRuntime").triggers.rows[gate.node]
				check(train.route.size()>1 and train.route_time>0,row.id+" keeps train route")
			else:check(gate.travel.length()>0 and gate.travel.length()<100,row.id+" keeps door travel")
		maps.append({"map":row.id,"shapes":shapes,"liquids":liquid_count,"doors":game.gates.size(),"lifts":game.lifts.size()})
		game.match_mode.kind="as" if row.id.begins_with("as_") else "tf"
		game.match_mode.reset()
		check(presentation_nodes()==0,row.id+" team mode creates no presentation nodes")
	game._end_round()
	check(not game.lobby.last_results.is_empty(),"Round results captured without menu dependency")
	check(game._load_map(game.lobby.ID),"Lobby transition succeeds")
	check(presentation_nodes()==0 and game.get_node("Map").find_children("*","CollisionShape3D",true,false).size()==6,"Lobby has six collision walls and no graphics")
	print("CONSOLE_RUNTIME_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"maps":maps}))
	game.disconnect_game();game.queue_free();await get_tree().process_frame;await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
