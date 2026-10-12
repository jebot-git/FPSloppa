@tool
extends RefCounted
## Static import helpers: OpenSCAD uses Z up; Godot uses Y up.
static func palette(path: String) -> Array:
	if not FileAccess.file_exists(path):return []
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Array else []
static func shade(point: Vector3,normal: Vector3,boxes: Array) -> Color:
	var color:=Color(.56,.37,.25)
	var best:=INF
	for item in boxes:
		var center:=Vector3(item[0][0],item[0][1],item[0][2])
		var half:=Vector3(item[1][0],item[1][1],item[1][2])*.5
		var local: Vector3=(point-center).abs()
		if local.x>half.x+.002 or local.y>half.y+.002 or local.z>half.z+.002:continue
		var axis:=normal.abs().max_axis_index()
		var distance: float=absf(local[axis]-half[axis])
		if distance<best:
			best=distance;color=Color(item[2][0],item[2][1],item[2][2])
	color*=.68+maxf(0,normal.dot(Vector3(-.4,.8,.3).normalized()))*.32
	color.a=1;return color
static func from_triangles(points: PackedVector3Array,triangles: PackedInt32Array,boxes: Array=[]) -> ArrayMesh:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	for i in range(0,triangles.size(),3):
		var a:=points[triangles[i]];var b:=points[triangles[i+1]];var c:=points[triangles[i+2]]
		var normal:=(b-a).cross(c-a).normalized()
		var color:=shade((a+b+c)/3,normal,boxes)
		vertices.append_array(PackedVector3Array([a,b,c]));normals.append_array(PackedVector3Array([normal,normal,normal]));colors.append_array(PackedColorArray([color,color,color]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,material)
	var tool:=SurfaceTool.new();tool.create_from(mesh,0);tool.index();tool.optimize_indices_for_cache();return tool.commit()
static func read_off(path: String,boxes: Array=[]) -> ArrayMesh:
	var tokens:=FileAccess.get_file_as_string(path).replace("\n"," ").replace("\t"," ").split(" ",false)
	if tokens.size()<4 or tokens[0]!="OFF":push_error("Expected OpenSCAD OFF mesh");return null
	var count:=int(tokens[1]);var faces:=int(tokens[2]);var cursor:=4
	var vertices:=PackedVector3Array();var triangles:=PackedInt32Array()
	for i in count:
		vertices.append(Vector3(float(tokens[cursor]),float(tokens[cursor+2]),-float(tokens[cursor+1])));cursor+=3
	for i in faces:
		var size:=int(tokens[cursor]);cursor+=1
		# OpenSCAD's OFF export is triangulated. Fail rather than silently fan-fill concave faces.
		if size!=3:push_error("Expected triangular OpenSCAD OFF face");return null
		triangles.append_array(PackedInt32Array([int(tokens[cursor]),int(tokens[cursor+1]),int(tokens[cursor+2])]));cursor+=3
	return from_triangles(vertices,triangles,boxes)
static func read_json(path: String,boxes: Array=[]) -> ArrayMesh:
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	var points:=PackedVector3Array()
	for p in data.vertices:points.append(Vector3(p[0],p[1],p[2]))
	return from_triangles(points,PackedInt32Array(data.indices),boxes)
