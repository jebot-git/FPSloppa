extends RefCounted
## Import-only batching: retain mesh/node/skin identity and every triangle.
## Morph meshes, transparent/custom shaders and material-animation targets stay intact.
const MAX_VERTICES:=100000
const MAX_INDICES:=600000
const MTOON_OPAQUE=["mtoon.gdshader","mtoon_cull_off.gdshader","mtoon_cutout.gdshader","mtoon_cutout_cull_off.gdshader"]
static func safe_material(material: Material) -> bool:
	if material is StandardMaterial3D:return material.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]
	if material is ShaderMaterial and material.shader:
		return material.shader.resource_path.begins_with("res://addons/Godot-MToon-Shader/") and material.shader.resource_path.get_file() in MTOON_OPAQUE
	return false
static func compile(model: Node,meshes: Dictionary={}) -> Dictionary:
	var blocked: Dictionary={}
	for player in model.find_children("*","AnimationPlayer",true,false):
		var base=player.get_node_or_null(player.root_node)
		if not base:continue
		for key in player.get_animation_list():
			var clip: Animation=player.get_animation(key)
			for track in clip.get_track_count():
				if clip.track_get_type(track)==Animation.TYPE_BLEND_SHAPE:continue
				var path:=clip.track_get_path(track)
				var target=base.get_node_or_null(NodePath(path.get_concatenated_names()))
				if target is MeshInstance3D:blocked[target]=true
	var before:=0;var after:=0
	for instance in model.find_children("*","MeshInstance3D",true,false):
		var mesh=instance.mesh
		if not mesh is ArrayMesh:continue
		before+=mesh.get_surface_count()
		var eligible: bool=not blocked.has(instance) and instance.material_override==null and mesh.get_blend_shape_count()==0
		for surface in mesh.get_surface_count():
			if instance.get_surface_override_material(surface)!=null:eligible=false
		if eligible:
			if not meshes.has(mesh):meshes[mesh]=merge(mesh)
			instance.mesh=meshes[mesh]
		after+=instance.mesh.get_surface_count()
	return {"surfaces_before":before,"surfaces_after":after}
static func merge(source: ArrayMesh) -> ArrayMesh:
	if source.get_blend_shape_count()>0 or source.shadow_mesh!=null:return source
	var vertices:=0;var index_count:=0
	for i in source.get_surface_count():vertices+=source.surface_get_array_len(i);index_count+=source.surface_get_array_index_len(i)
	if vertices>MAX_VERTICES or index_count>MAX_INDICES:return source
	for surface in source.get("_surfaces"):
		if not surface.get("lods",[]).is_empty():return source
	var groups: Array=[];var by_material: Dictionary={}
	for surface in source.get_surface_count():
		var material=source.surface_get_material(surface)
		var format:=source.surface_get_format(surface)
		var eligible: bool=source.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES and safe_material(material)
		# Custom vertex streams may carry shader-specific per-surface semantics.
		for flag in [Mesh.ARRAY_FORMAT_CUSTOM0,Mesh.ARRAY_FORMAT_CUSTOM1,Mesh.ARRAY_FORMAT_CUSTOM2,Mesh.ARRAY_FORMAT_CUSTOM3]:
			if format&flag:return source
		var key:=str(material.get_instance_id())+":"+str(format) if material else ""
		if eligible and by_material.has(key):groups[by_material[key]].append(surface)
		else:
			if eligible:by_material[key]=groups.size()
			groups.append([surface])
	if groups.size()==source.get_surface_count():return source
	var result:=ArrayMesh.new();result.resource_name=source.resource_name;result.custom_aabb=source.custom_aabb
	for key in source.get_meta_list():result.set_meta(key,source.get_meta(key))
	for group in groups:
		var first: int=group[0]
		var arrays:=source.surface_get_arrays(first)
		if group.size()>1:
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(range(arrays[Mesh.ARRAY_VERTEX].size()))
			for item in range(1,group.size()):
				var next:=source.surface_get_arrays(group[item]);var offset: int=arrays[Mesh.ARRAY_VERTEX].size()
				var indices: PackedInt32Array=next[Mesh.ARRAY_INDEX] if next[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if indices.is_empty():indices=PackedInt32Array(range(next[Mesh.ARRAY_VERTEX].size()))
				for index in indices:arrays[Mesh.ARRAY_INDEX].append(index+offset)
				for channel in Mesh.ARRAY_MAX:
					if channel!=Mesh.ARRAY_INDEX and arrays[channel]!=null:arrays[channel].append_array(next[channel])
		result.add_surface_from_arrays(source.surface_get_primitive_type(first),arrays,[],{},source.surface_get_format(first)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		var index:=result.get_surface_count()-1
		result.surface_set_material(index,source.surface_get_material(first));result.surface_set_name(index,source.surface_get_name(first))
	return result
