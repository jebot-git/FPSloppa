extends SceneTree
## Offline static visibility bake. No lights or visibility rays run in gameplay.
const Map=preload("res://tools/voxel_battle/map.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const Landscape=Map.Landscape
const SIDE:=1024
const SkySource=Lighting.SkySource
var map
var space:PhysicsDirectSpaceState3D
var lamps:Array=[]
var lamp_cells:Dictionary={}
var heights:PackedFloat32Array
var spacing:float
func _initialize() -> void:call_deferred("run")
func lamp(row:Dictionary) -> void:
	var point:Vector3=Landscape.CENTERS[row.kind]+row.local+Vector3(0,Map.Architecture.Fixtures.ground(row),0)
	var index:=lamps.size();lamps.append({"position":[point.x,point.y,point.z],"radius":row.radius,"power":row.power,"kind":row.kind,"type":row.type})
	var cell:=Vector2i(floori(point.x/24),floori(point.z/24))
	if not lamp_cells.has(cell):lamp_cells[cell]=[]
	lamp_cells[cell].append(index)
func height_at(x:float,z:float) -> float:
	var u:=clampf((x+Map.LIMIT)/spacing,0,Map.COLLISION_SIDE-1.001);var v:=clampf((z+Map.LIMIT)/spacing,0,Map.COLLISION_SIDE-1.001)
	var ix:=int(u);var iz:=int(v);var a:=iz*Map.COLLISION_SIDE+ix
	return lerpf(lerpf(heights[a],heights[a+1],u-ix),lerpf(heights[a+Map.COLLISION_SIDE],heights[a+Map.COLLISION_SIDE+1],u-ix),v-iz)*spacing
func clear_ray(a:Vector3,b:Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
func irradiance(point:Vector3,normal:Vector3) -> Array:
	var direct:=Vector3.ZERO
	var suns:Array[Vector3]=[SkySource.SUN_NOON.normalized(),SkySource.SUN_DUSK.normalized(),SkySource.SUN_DAWN.normalized()]
	for i in 3:
		if normal.dot(suns[i])>0 and clear_ray(point,point+suns[i]*1500):direct[i]=.76*normal.dot(suns[i])
	var sky_visibility:=0.0;var total:=0.0
	for direction in SkySource.directions():
		var weight:=maxf(0,normal.dot(direction));total+=weight
		if weight>0 and clear_ray(point,point+direction*1200):sky_visibility+=weight
	sky_visibility/=maxf(.001,total)
	var night:=0.0;var cell:=Vector2i(floori(point.x/24),floori(point.z/24))
	for z in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			for index in lamp_cells.get(Vector2i(x,z),[]):
				var row:Dictionary=lamps[index];var p:=Vector3(row.position[0],row.position[1],row.position[2]);var dist:=point.distance_to(p)
				if dist>=row.radius:continue
				var amount:float=row.power*pow(1.0-dist/row.radius,2)*(.35+.65*maxf(0,normal.dot((p-point).normalized())))
				if amount>.002 and clear_ray(point,p):night+=amount
	return [minf(1,direct.x+night*.18),minf(1,night),sky_visibility,minf(1,direct.y+night*.18),minf(1,direct.z+night*.18)]
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Lighting.ROOT))
	SkySource.bake()
	map=Map.new();root.add_child(map);map.build(false,true,true)
	# The gameplay boundary must not cast a kilometre-wide baked shadow.
	for child in map.get_children():
		if child is StaticBody3D and (absf(child.position.x)>Map.LIMIT or absf(child.position.z)>Map.LIMIT):child.free()
	for row in Map.Architecture.Fixtures.rows(map.layout.buildings):lamp(row)
	await physics_frame;await physics_frame
	space=map.get_world_3d().direct_space_state
	heights=Map.terrain_collision().map_data;spacing=Landscape.EXTENT/(Map.COLLISION_SIDE-1)
	if "--meshes-only" not in OS.get_cmdline_user_args():
		var image:=Image.create(SIDE,SIDE,false,Image.FORMAT_RGBA8)
		var dawn:=Image.create(SIDE,SIDE,false,Image.FORMAT_RGBA8)
		for z in SIDE:
			for x in SIDE:
				var px:float=(x+.5)/SIDE*Landscape.EXTENT-Map.LIMIT;var pz:float=(z+.5)/SIDE*Landscape.EXTENT-Map.LIMIT
				var normal:=Vector3(height_at(px-1,pz)-height_at(px+1,pz),2,height_at(px,pz-1)-height_at(px,pz+1)).normalized()
				var pair:=irradiance(Vector3(px,height_at(px,pz)+.24,pz),normal)
				image.set_pixel(x,z,Color(pair[0],pair[1],pair[2],pair[3]))
				dawn.set_pixel(x,z,Color(pair[4],0,0,1))
			if z%128==0:print("LIGHT BAKE atlas ",z,"/",SIDE);await process_frame
		assert(image.save_png(Lighting.ROOT+"irradiance.png")==OK)
		assert(dawn.save_png(Lighting.ROOT+"dawn.png")==OK)
	var paths:Array=[];var vertices:=0
	var meshes:Array=map.layout.generate()
	for kind in meshes.size():
		paths.append([])
		for lod in 3:
			var mesh:ArrayMesh=meshes[kind][lod];var arrays:Array=mesh.surface_get_arrays(0)
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var normals:=PackedVector3Array();normals.resize(points.size());var centers:=PackedVector3Array();centers.resize(points.size());var counts:=PackedInt32Array();counts.resize(points.size())
			for i in range(0,indices.size(),3):
				var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
				var n:Vector3=(points[b]-points[a]).cross(points[c]-points[a]).normalized();var center:Vector3=(points[a]+points[b]+points[c])/3
				for j in [a,b,c]:normals[j]+=n;centers[j]+=center;counts[j]+=1
			var data:=PackedFloat32Array();data.resize(points.size()*4)
			var dawn_data:=PackedFloat32Array();dawn_data.resize(points.size()*4)
			for i in points.size():
				var normal:Vector3=normals[i].normalized();var p:Vector3=points[i].lerp(centers[i]/maxi(1,counts[i]),.04)+normal*.045+Landscape.CENTERS[kind]
				var pair:=irradiance(p,normal)
				for j in 4:data[i*4+j]=pair[j]
				dawn_data[i*4]=pair[4]
			arrays[Mesh.ARRAY_CUSTOM0]=data;arrays[Mesh.ARRAY_CUSTOM1]=dawn_data
			var baked:=ArrayMesh.new();baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
			baked.surface_set_material(0,Lighting.surface(mesh.surface_get_material(0),true))
			var path:String=Lighting.ROOT+"site_%d_lod_%d.res"%[kind,lod];assert(ResourceSaver.save(baked,path,ResourceSaver.FLAG_COMPRESS)==OK)
			paths[kind].append(path);vertices+=points.size()
		print("LIGHT BAKE site ",kind);await process_frame
	var file:=FileAccess.open(Lighting.ROOT+"bake.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source_sha256":Lighting.source_fingerprint(),"atlas_side":SIDE,"meshes":paths,"lamps":lamps,"baked_vertices":vertices,"cycle_seconds":Lighting.CYCLE_SECONDS,"sky_average":SkySource.averages(),"sky_stages":SkySource.STAGES,"method":"Offline terrain/structure physics visibility, warm static fixtures, numeric linear irradiance; runtime blend only"},"\t"))
	print("LIGHT BAKE COMPLETE ",vertices," vertices, ",lamps.size()," fixtures");quit()
