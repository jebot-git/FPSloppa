extends Node3D
## OpenNova-inspired: heightfield patches, reusable LOD families, separate structures.
const TILES:=8
var groups: Array=[]
var counts: Array=[]
var meshes: Array=[]
var last_position:=Vector3.INF
var last_rotation:=Vector3.INF
var triangles:=0
var visible_patches:=0
func setup(map) -> void:
	var material:=ShaderMaterial.new();material.shader=preload("res://tools/voxelspace/patch.gdshader")
	material.set_shader_parameter("heights",map.height_texture);material.set_shader_parameter("colors",map.color_texture)
	for step in [1,2,4,8]:
		var segments: int=64/step;var side: float=map.EXTENT/TILES
		var vertices:=PackedVector3Array();var shades:=PackedColorArray();var indices:=PackedInt32Array()
		for z in segments+1:
			for x in segments+1:vertices.append(Vector3(x*side/segments,0,z*side/segments));shades.append(Color(1,1,1,0))
		for z in segments:
			for x in segments:
				var i:=z*(segments+1)+x;indices.append_array(PackedInt32Array([i,i+segments+1,i+1,i+1,i+segments+1,i+segments+2]))
		# Shared edge skirts conceal cracks between different LOD families.
		for edge in 4:
			for i in segments:
				var a:=Vector3.ZERO;var b:=Vector3.ZERO
				match edge:
					0:a=Vector3(i*side/segments,0,0);b=Vector3((i+1)*side/segments,0,0)
					1:a=Vector3(i*side/segments,0,side);b=Vector3((i+1)*side/segments,0,side)
					2:a=Vector3(0,0,i*side/segments);b=Vector3(0,0,(i+1)*side/segments)
					3:a=Vector3(side,0,i*side/segments);b=Vector3(side,0,(i+1)*side/segments)
				var start:=vertices.size();vertices.append_array(PackedVector3Array([a,b,a,b]));shades.append_array(PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,1),Color(1,1,1,1)]));indices.append_array(PackedInt32Array([start,start+2,start+1,start+1,start+2,start+3]))
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=shades;arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.custom_aabb=AABB(Vector3(0,-5,0),Vector3(side,30,side));mesh.surface_set_material(0,material);meshes.append(mesh)
		var group:=MultiMeshInstance3D.new();group.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;group.multimesh=MultiMesh.new();group.multimesh.transform_format=MultiMesh.TRANSFORM_3D;group.multimesh.mesh=mesh;group.multimesh.custom_aabb=AABB(Vector3(-125,-5,-125),Vector3(250,50,250));group.multimesh.instance_count=TILES*TILES;group.multimesh.visible_instance_count=0;group.custom_aabb=AABB(Vector3(-125,-5,-125),Vector3(250,50,250));group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(group);groups.append(group)
func update(camera: Camera3D,force_full: bool=false) -> void:
	if camera.global_position==last_position and camera.rotation==last_rotation:return
	last_position=camera.global_position;last_rotation=camera.rotation;counts=[0,0,0,0];triangles=0;visible_patches=0
	var planes:=camera.get_frustum()
	for z in TILES:
		for x in TILES:
			var origin:=Vector3(x*31.25-125,0,z*31.25-125);var center:=origin+Vector3(15.625,8,15.625)
			var visible:=true
			for plane in planes:
				if plane.distance_to(center)>28:visible=false;break
			if not visible:continue
			var distance:=Vector2(center.x-camera.global_position.x,center.z-camera.global_position.z).length()
			var family:=0 if force_full or distance<38 else 1 if distance<75 else 2 if distance<140 else 3
			groups[family].multimesh.set_instance_transform(counts[family],Transform3D(Basis.IDENTITY,origin));counts[family]+=1;visible_patches+=1
			triangles+=meshes[family].surface_get_array_index_len(0)/3
	for i in 4:groups[i].multimesh.visible_instance_count=counts[i]
