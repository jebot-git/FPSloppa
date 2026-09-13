extends SceneTree
const Loader = preload("res://deathmatch/maps/loader.gd")
var failures: Array = []
func _initialize(): call_deferred("run")
func require(ok: bool, label: String):
	if not ok: failures.append(label)
func run():
	var args := OS.get_cmdline_user_args()
	var key: String = args[0]
	var report_path: String = args[1]
	var rows := Loader.catalog()
	var selected := rows.filter(func(row): return row.id == key)
	require(selected.size() == 1, "Discovered exactly once")
	if selected.is_empty(): quit(1); return
	var row: Dictionary = selected[0]
	require(row.get("distribution", "") == "optional", "Optional catalog metadata")
	require(not row.get("custom", false), "Known BSP checksum matches")
	for mode in ["dm", "tdm", "ctf", "koth", "ig", "ft", "cc", "tf", "as"]:
		require(Loader.available_for_mode(row, mode) == (mode in row.modes), "Mode filtering " + mode)
	require(Loader.available_for_mode(row, "if") == ("ig" in row.modes), "Legacy IG alias")
	require(Loader.validate(row.path).is_empty(), "Production BSP geometry validation")
	var game = load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.map_catalog = selected
	game.match_mode.kind = row.modes[0]
	require(game._load_map(key), "Production runtime import")
	await physics_frame
	await physics_frame
	require(game.spawn_points.size() >= 2, "Multiplayer spawns")
	var meshes: Array = game.get_node("Map").find_children("*", "MeshInstance3D", true, false)
	var collisions: Array = game.get_node("Map").find_children("*", "CollisionShape3D", true, false)
	require(not meshes.is_empty(), "Visible geometry")
	require(not collisions.is_empty(), "Collision geometry")
	if row.modes == ["ctf"] or row.modes == ["tf"]:
		require(game.map_objectives.has("red") and game.map_objectives.has("blue"), "Native flags")
		require(game.ctf_spawns[0].size() > 0 and game.ctf_spawns[1].size() > 0, "Native team spawns")
	if row.modes == ["tf"]:
		require(not game.tf_resupply[0].is_empty() and not game.tf_resupply[1].is_empty(), "Native TF resupply")
	if row.modes == ["as"]:
		require(Loader.supports_assault(row.path), "Two native Assault objectives")
	var result := {"id": key, "sha256": row.sha256, "modes": row.modes, "spawns": game.spawn_points.size(), "meshes": meshes.size(), "collisions": collisions.size(), "failures": failures}
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	game.free()
	print("OPTIONAL_MAP_SMOKE ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
