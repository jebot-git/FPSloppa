extends SceneTree
## Geometry checks for floors, window openings and connected stairs, independent of renderer.
const FactoryMap=preload("res://tools/voxelspace/factory_map.gd")
var failures: Array=[]
var checks:=0
var vertices: PackedVector3Array
var indices: PackedInt32Array
func _initialize() -> void:run.call_deferred()
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures.append(message);push_error(message)
func hit(from: Vector3,to: Vector3):
	var nearest=null;var distance:=INF
	for i in range(0,indices.size(),3):
		var point=Geometry3D.segment_intersects_triangle(from,to,vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]])
		if point!=null and from.distance_squared_to(point)<distance:distance=from.distance_squared_to(point);nearest=point
	return nearest
func digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func run() -> void:
	var map:=FactoryMap.new();map.generate("res://test-results/voxelspace/geometry")
	var arrays:=map.factory_mesh.surface_get_arrays(0);vertices=arrays[Mesh.ARRAY_VERTEX];indices=arrays[Mesh.ARRAY_INDEX]
	for level in 4:
		var floor_y:=map.BASE+level*4
		var point=hit(Vector3(-5,floor_y+1,0),Vector3(-5,floor_y-1,0))
		check(point!=null and absf(point.y-floor_y-.13)<.001,"Storey %d floor must be a separate real surface"%level)
		var wall=hit(Vector3(-29.5,floor_y+.5,20),Vector3(-29.5,floor_y+.5,17))
		var window=hit(Vector3(-29.5,floor_y+1.8,20),Vector3(-29.5,floor_y+1.8,17))
		check(wall!=null,"Storey %d has a facade wall"%level)
		check(window==null,"Storey %d window opening must stay open"%level)
	for level in 3:
		for step in 16:
			var y:=map.BASE+level*4+(step+1)*.25
			var point=hit(Vector3(24,y+.5,-29+step*.65),Vector3(24,y-.5,-29+step*.65))
			check(point!=null and absf(point.y-y-.125)<.001,"Stair %d step %d has a surface joining storeys"%[level,step])
	for level in 4:
		var y:=map.BASE+level*4
		check(hit(Vector3(26,y+.5,-28),Vector3(26,y-.5,-28))==null,"Stairwell must remain open through slab %d"%level)
	check(digest(map.heights.to_byte_array())!=digest(map.solid_heights.to_byte_array()),"Solid-column factory mass differs from hollow hybrid terrain")
	var result:={"checks":checks,"failures":failures,"height_sha256":digest(map.heights.to_byte_array()),"factory_geometry_sha256":digest(vertices.to_byte_array()),"scope":"Segment intersection with generated triangle geometry; no gameplay collision implementation."}
	FileAccess.open("res://test-results/voxelspace/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("VOXEL_FACTORY_GEOMETRY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
