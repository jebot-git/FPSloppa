extends "res://tools/voxelspace/validate.gd"
## Check imported geometry, interior preservation, stationary-camera LOD and sealed voxel chunks.
const FactoryLOD=preload("res://tools/voxelspace/factory_lod.gd")
const VoxelTerrain=preload("res://tools/voxelspace/voxel_terrain.gd")
var variants: Array=[]
func set_geometry(mesh: ArrayMesh,offset: Vector3=Vector3.ZERO) -> void:
	var arrays:=mesh.surface_get_arrays(0);vertices=arrays[Mesh.ARRAY_VERTEX];indices=arrays[Mesh.ARRAY_INDEX]
	for i in vertices.size():vertices[i]+=offset
func interior(label: String) -> void:
	for level in 4:
		var y:=FactoryMap.BASE+level*4
		var floor_hit=hit(Vector3(-5,y+1,0),Vector3(-5,y-1,0))
		check(floor_hit!=null and absf(floor_hit.y-y-.13)<.001,label+" floor "+str(level))
		check(hit(Vector3(-29.5,y+.5,20),Vector3(-29.5,y+.5,17))!=null,label+" facade "+str(level))
		check(hit(Vector3(-29.5,y+1.8,20),Vector3(-29.5,y+1.8,17))==null,label+" open window "+str(level))
		check(hit(Vector3(26,y+.5,-28),Vector3(26,y-.5,-28))==null,label+" open stairwell "+str(level))
	# Offset from x=24: step 11 overlaps a structural column there.
	# Boolean unions correctly remove that hidden interior stair face.
	for level in 3:
		for step in 16:
			var y:=FactoryMap.BASE+level*4+(step+1)*.25
			var point=hit(Vector3(24.6,y+.5,-29+step*.65),Vector3(24.6,y-.5,-29+step*.65))
			check(point!=null and absf(point.y-y-.125)<.001,label+" stair %d step %d"%[level,step])
func run() -> void:
	var map:=FactoryMap.new();map.generate("res://test-results/factory-optimization/geometry")
	for label in ["baseline","native_csg","openscad","blender_planar","greedy","culled"]:
		var mesh: ArrayMesh=map.factory_mesh if label=="baseline" else load("res://tools/voxelspace/assets/factory.csg") if label=="openscad" else load("res://tools/voxelspace/assets/factory_"+label+".res")
		check(mesh.get_surface_count()==1,label+" must remain one draw surface")
		set_geometry(mesh);interior(label)
		variants.append({"variant":label,"triangles":indices.size()/3,"vertices":vertices.size(),"vertex_sha256":digest(vertices.to_byte_array()),"index_sha256":digest(indices.to_byte_array())})
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.far=300;camera.fov=70
	var factory:=FactoryLOD.new();root.add_child(factory);factory.setup()
	for item in [[Vector3(0,8,5),0],[Vector3(0,20,205),2],[Vector3(0,10,125),1],[Vector3(0,10,68),0]]:
		camera.position=item[0];factory.update(camera);check(factory.lod==item[1],"Factory distance LOD "+str(item[0]))
	set_geometry(factory.mesh);interior("factory_lod_near")
	var terrain:=VoxelTerrain.new();root.add_child(terrain);terrain.setup(map)
	camera.position=Vector3(0,10,68);camera.rotation=Vector3.ZERO;terrain.update(camera)
	check(terrain.counts[0]>0 and terrain.counts[1]>0 and terrain.counts[2]>0,"Initial stationary view must resolve all three voxel LODs")
	check(terrain.counts.reduce(func(total,value):return total+value,0)<64,"Frustum must cull some chunks")
	var initial_counts:=terrain.counts.duplicate();terrain.update(camera)
	check(terrain.counts==initial_counts,"Stationary camera must retain resolved LOD counts")
	var chunk=terrain.chunks.filter(func(item):return item.node.position==Vector3(0,0,0))[0]
	for lod in 3:
		set_geometry(chunk.meshes[lod],chunk.node.position)
		var top=hit(Vector3(10,4,10),Vector3(10,1,10))
		check(top!=null and absf(top.y-FactoryMap.BASE)<.0001,"Flat factory yard stays at 2.4 metres at LOD "+str(lod))
		# This edge is retained even if its neighbour uses a different LOD.
		check(hit(Vector3(-1,0,10),Vector3(1,0,10))!=null,"Chunk side wall closes mixed-LOD boundary "+str(lod))
		var normals: PackedVector3Array=chunk.meshes[lod].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		check(normals.size()==vertices.size(),"Voxel surface normals exist "+str(lod))
	camera.position=Vector3(0,20,205);terrain.update(camera)
	check(terrain.counts[2]>0 and terrain.counts[0]==0,"Teleport must directly resolve far chunks to LOD2")
	factory.free();terrain.free();camera.free()
	var result:={"checks":checks,"failures":failures,"variants":variants,"stationary_voxel_counts":initial_counts,"scope":"Triangle segment intersections and runtime visual LOD; no gameplay collision certification."}
	FileAccess.open("res://test-results/factory-optimization/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FACTORY_OPTIMIZATION_GEOMETRY ",JSON.stringify(result));await process_frame;quit(0 if failures.is_empty() else 1)
