extends RefCounted
## Observer-local billboard pies; the replicated downed state is the sole clock.
const Rules=preload("res://deathmatch/conquest/classes/rules.gd")
const PieShader=preload("res://deathmatch/conquest/classes/revival_timer.gdshader")
var nodes:Dictionary={}
var mesh:QuadMesh
static func eligible(game,observer:int,target:int) -> bool:
	if observer==target or not game.classes.alive(observer) or game.classes.role(observer)!="medic" or not game.classes.downed.has(target):return false
	if not game.players.has(target) or not game.fighters.has(target) or not game.match_mode.same_team(observer,target) or game.players[target].dead:return false
	return game.fighters[observer].position.distance_squared_to(game.fighters[target].position)<=10000.0
func draw(game) -> void:
	if game.headless:return
	var mine:int=game.multiplayer.get_unique_id()
	for id in nodes.keys():
		if not game.classes.downed.has(id) or not game.fighters.has(id):
			if is_instance_valid(nodes[id]):nodes[id].queue_free()
			nodes.erase(id)
	for id in game.classes.downed:
		if not eligible(game,mine,id):
			if nodes.has(id):nodes[id].hide()
			continue
		if not nodes.has(id):
			if not mesh:mesh=QuadMesh.new();mesh.size=Vector2(.38,.38)
			var node:=MeshInstance3D.new();node.name="MedicRevivalPie_%d"%id;node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material:=ShaderMaterial.new();material.shader=PieShader;node.material_override=material;game.add_child(node);nodes[id]=node
		var node:MeshInstance3D=nodes[id];node.position=game.fighters[id].position+Vector3.UP*.85
		node.material_override.set_shader_parameter("remaining",clampf(game.classes.downed[id].remaining/Rules.BLEED_SECONDS,0,1));node.show()
