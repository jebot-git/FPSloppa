extends RefCounted
## The gameplay fixture now loads the same compiled BSP used by normal hosting.
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
const Timing=preload("res://deathmatch/modes/titanball.gd")
static func points() -> Array:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Ashfall/route.json"));var result: Array=[]
	for p in data.points:result.append(Vector3(p[0],p[1],p[2]))
	return result
static func build(game: Node3D) -> void:
	var path: String="res://maps/tb_ashfall.bsp";var hash:=FileAccess.get_sha256(path)
	game.map_catalog=game.map_catalog.filter(func(row):return row.id!="tb_ashfall")
	game.map_catalog.append({"id":"tb_ashfall","title":"Ashfall Boulevard | TITANBALL","path":path,"scene":"res://maps/cache/tb_ashfall.scn","sha256":hash,"modes":["tb"]})
	game.current_map="";assert(game._load_map("tb_ashfall"))
