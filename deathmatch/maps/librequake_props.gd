extends RefCounted
static var meshes: Dictionary={}
static func fixture(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/librequake-props/"+kind+".json"))
	var texture:=ImageTexture.create_from_image(Image.create_from_data(int(data["size"][0]),int(data["size"][1]),false,Image.FORMAT_RGBA8,Marshalls.base64_to_raw(data.rgba)))
	var glow:=ImageTexture.create_from_image(Image.create_from_data(int(data["size"][0]),int(data["size"][1]),false,Image.FORMAT_RGBA8,Marshalls.base64_to_raw(data.glow)))
	var material:=StandardMaterial3D.new();material.albedo_texture=texture;material.emission_enabled=true;material.emission_texture=glow;material.emission=Color.WHITE;material.roughness=1;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
	for i in data.positions.size():
		var p: Array=data.positions[i];var uv: Array=data.uv[i];tool.set_uv(Vector2(uv[0],uv[1]));tool.add_vertex(Vector3(p[0],p[1],p[2]))
	tool.generate_normals();meshes[kind]=tool.commit();return meshes[kind]
static func add(root: Node3D,rows: Array) -> void:
	for kind in ["flame","flame2"]:
		var selected: Array=rows.filter(func(e):return e.get("fixture","flame")==kind)
		if selected.is_empty():continue
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=fixture(kind);multi.instance_count=mini(selected.size(),192)
		for i in multi.instance_count:
			var e: Dictionary=selected[i];var pos:=preload("res://deathmatch/maps/loader.gd").point(e.origin)
			multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,deg_to_rad(float(e.get("angle",0)))),pos))
		var node:=MultiMeshInstance3D.new();node.name="LibreQuakeFixtures";node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
