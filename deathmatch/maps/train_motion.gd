extends Node
## Cosmetic movement in the stationary train frame. Never moves solid collision.
var game
var speed:=640.0
var distance:=0.0
var moving: Array=[]
var materials: Array=[]
func configure(arena: Node,root: Node3D,entities: Array) -> void:
	game=arena
	for node in entities:
		var e: Dictionary=node.attributes
		if e.get("classname","")=="info_train_motion":speed=clampf(float(e.get("speed",640)),0,1024)
		if e.get("classname","")=="func_illusionary" and e.has("train_loop"):
			moving.append({"node":node,"base":node.position,"period":clampf(float(e.train_loop),32,4096)})
	var visited: Dictionary={}
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh:continue
		for surface in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(surface)
			if not material is ShaderMaterial or not material.get_meta("bsp_texture_name","") in ["hs_track","hs_cutting","hs_rail"]:continue
			if visited.has(material):continue
			visited[material]=true
			var texture: Texture2D=material.get_shader_parameter("base_texture")
			if texture:materials.append({"material":material,"width":texture.get_width()})
	set_process(not moving.is_empty() or not materials.is_empty())
func _process(delta: float) -> void:
	if not game.presentation.get("train_motion",true):return
	distance=fposmod(distance+delta*speed,1048576.0)
	for row in moving:row.node.position=row.base+Vector3.BACK*fposmod(distance,row.period)/32.0
	for row in materials:row.material.set_shader_parameter("map_uv_offset",Vector2(fposmod(distance/row.width,1.0),0))
