extends RefCounted
## Shared index-only LODs: every retained corner still samples its original
## animated vertex, UV and IK region. No frame texture or vertex is resampled.
const MAX_CORNERS:=30000
static func build(source:ArrayMesh) -> Array[ArrayMesh]:
	var meshes:Array[ArrayMesh]=[source,source,source]
	if source.surface_get_array_len(0)>MAX_CORNERS:return meshes
	var surface:=SurfaceTool.new();surface.create_from(source,0);surface.index()
	var indexed:=surface.commit()
	var arrays:=indexed.surface_get_arrays(0)
	var flags:=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var importer:=ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_material(0),"",flags)
	importer.generate_lods(60,25,[])
	var generated:=importer.get_surface_arrays(0)
	for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0]:
		if arrays[attribute]!=generated[attribute]:return meshes
	for tier in 3:
		var selected:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if tier>0:
			var budget:=maxi(48,int(selected.size()*(.5 if tier==1 else .25)))
			for level in importer.get_surface_lod_count(0):
				var indices:=importer.get_surface_lod_indices(0,level)
				# Stop at the first available level within the requested budget.
				selected=indices
				if indices.size()<=budget:break
		var retained:=arrays.duplicate();retained[Mesh.ARRAY_INDEX]=selected
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,retained,[],{},flags)
		mesh.surface_set_material(0,source.surface_get_material(0));mesh.custom_aabb=source.custom_aabb
		meshes[tier]=mesh
	return meshes

static func effective_distance(position:Vector3,camera:Camera3D) -> float:
	if camera==null:return 0.0
	var distance:=position.distance_to(camera.global_position)
	if camera is XRCamera3D:return distance
	if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:return camera.size/(2*tan(deg_to_rad(85*.5)))
	return distance*tan(deg_to_rad(camera.fov*.5))/tan(deg_to_rad(85*.5))

static func choose_tier(tier:int,distance:float) -> int:
	var thresholds:=[18.0,45.0]
	while tier<2 and distance>thresholds[tier]*1.15:tier+=1
	while tier>0 and distance<thresholds[tier-1]*.85:tier-=1
	return tier
