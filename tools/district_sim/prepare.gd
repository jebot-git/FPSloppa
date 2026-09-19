extends SceneTree
## Clip map triangles at district boundaries; retain original UV/lightmap samples.
const BASE="res://maps/Benchmark1km/"
func _initialize():run.call_deferred()
func clip(poly: Array,axis: int,edge: float,sign_: float) -> Array:
	var result: Array=[]
	for i in poly.size():
		var a: Dictionary=poly[i];var b: Dictionary=poly[(i+1)%poly.size()]
		var da: float=(a.p[axis]-edge)*sign_;var db: float=(b.p[axis]-edge)*sign_
		if da>=-.00001:result.append(a)
		if (da>0 and db<0) or (da<0 and db>0):
			var t:=da/(da-db);result.append({"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t),"uv2":a.uv2.lerp(b.uv2,t),"color":a.color.lerp(b.color,t)})
	return result
func run() -> void:
	var original: Node3D=load(BASE+"baseline-lightmap1.scn").instantiate();root.add_child(original)
	var output:=Node3D.new();output.name="DistrictGeometry";root.add_child(output)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"layout.json"))
	var counts: Array=[]
	for zone in 16:
		var parent:=Node3D.new();parent.name="District_%02d"%zone;output.add_child(parent);parent.owner=output
		var x: float=-500+(zone%4)*250;var z: float=-500+(zone/4)*250;var count:=0
		for source in original.find_children("*","MeshInstance3D",true,false):
			for surface in source.mesh.get_surface_count():
				var a: Array=source.mesh.surface_get_arrays(surface);var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(a[Mesh.ARRAY_VERTEX].size()))
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(source.get_active_material(surface));var added:=0
				for i in range(0,indices.size(),3):
					var poly: Array=[]
					for j in 3:
						var k:=indices[i+j];poly.append({"p":source.global_transform*a[Mesh.ARRAY_VERTEX][k],"n":a[Mesh.ARRAY_NORMAL][k],"uv":a[Mesh.ARRAY_TEX_UV][k],"uv2":a[Mesh.ARRAY_TEX_UV2][k],"color":a[Mesh.ARRAY_COLOR][k] if a[Mesh.ARRAY_COLOR]!=null else Color.WHITE})
					for plane in [[0,x,1],[0,x+250,-1],[2,z,1],[2,z+250,-1]]:
						if poly.is_empty():break
						poly=clip(poly,plane[0],plane[1],plane[2])
					for corner in range(1,poly.size()-1):
						var triangle: Array=[poly[0],poly[corner],poly[corner+1]]
						if (triangle[1].p-triangle[0].p).cross(triangle[2].p-triangle[0].p).length_squared()<.000001:continue
						for vertex in triangle:st.set_normal(vertex.n);st.set_uv(vertex.uv);st.set_uv2(vertex.uv2);st.set_color(vertex.color);st.add_vertex(vertex.p)
						count+=1;added+=1
				if added:
					var node:=MeshInstance3D.new();node.mesh=st.commit();parent.add_child(node);node.owner=output
		preload("res://tools/km_benchmark/city_art.gd").district(parent,output,layout,zone)
		counts.append(count)
	var packed:=PackedScene.new();assert(packed.pack(output)==OK);assert(ResourceSaver.save(packed,BASE+"districts.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	DirAccess.make_dir_recursive_absolute("res://test-results/district-sim")
	FileAccess.open("res://test-results/district-sim/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles_per_district":counts,"source_sha256":FileAccess.get_sha256(BASE+"prototype_km1.bsp")},"  "))
	print("DISTRICT_GEOMETRY ",counts);original.free();output.free();quit()
