extends Node3D
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Stream=preload("res://tools/streamed_heightfield/stream.gd")
const Structures=preload("res://tools/streamed_heightfield/structures.gd")
const Scenery=preload("res://tools/voxel_battle/environment.gd")
const Grass=preload("res://tools/voxel_battle/grass.gd")
const LIMIT:=Landscape.EXTENT/2
const COLLISION_SIDE:=1425
var physics_enabled:=true
var environment
var grass
var environment_colliders:=0
var layout:=Architecture.new()
var terrain
var structures
var collision_rows: Dictionary={}
var geometry: Array=[]
var spawn_positions: Array[Vector3]=[]
var routes: Array[Vector3]=[]
var waterways
func build(graphics: bool, physics: bool=true) -> void:
	physics_enabled=physics
	Landscape.Hydrology.prepare()
	var meshes:=layout.generate()
	if physics:
		var body:=StaticBody3D.new();body.name="TerrainCollision";add_child(body)
		var collider:=CollisionShape3D.new();collider.shape=terrain_collision()
		# Uniform scale avoids GodotPhysics' nonuniform HeightMap scaling issue.
		collider.scale=Vector3.ONE*Landscape.EXTENT/(COLLISION_SIDE-1)
		body.add_child(collider)
		for row in layout.boxes:
			var p: Vector3=Landscape.CENTERS[row.kind]+row.center
			add_box(p,row.size)
		seed_collision()
		# Boundary lies outside the terrain, clear of all authored road endpoints.
		for side in [-1,1]:
			add_box(Vector3(side*(LIMIT+2),310,0),Vector3(4,680,Landscape.EXTENT+8))
			add_box(Vector3(0,310,side*(LIMIT+2)),Vector3(Landscape.EXTENT+8,680,4))
	for i in 4:
		var center: Vector3=Landscape.CENTERS[i]
		for x in [-9.0,9.0]:
			for z in [-62.0,-54.0,46.0,54.0]:
				var p:=center+Vector3(x,.15,z)
				spawn_positions.append(p);routes.append(p)
	for offset in [Vector3(0,.15,-42),Vector3(0,.15,42),Vector3(-42,.15,0),Vector3(42,.15,0)]:routes.append(Landscape.CENTERS[4]+offset)
	for building in layout.buildings:
		for entry in building.entries:routes.append(Landscape.CENTERS[building.kind]+entry)
		for floor_index in building.floors:
			routes.append(Landscape.CENTERS[building.kind]+building.center+Vector3(0,floor_index*Architecture.STOREY+.13,0))
	if graphics:
		terrain=Stream.new();terrain.source=Landscape.new();terrain.coarse_segments=128;terrain.min_height=Landscape.MIN_HEIGHT;terrain.max_height=Landscape.MAX_HEIGHT;add_child(terrain);terrain.setup()
		structures=Structures.new();structures.placements=Landscape.sites();structures.factory_base_offset=0
		structures.world_aabb=AABB(Vector3(-LIMIT,Landscape.MIN_HEIGHT,-LIMIT),Vector3(Landscape.EXTENT,Landscape.MAX_HEIGHT-Landscape.MIN_HEIGHT+40,Landscape.EXTENT))
		structures.meshes=meshes;add_child(structures);structures.setup()
		for site in Landscape.sites():
			var label:=Label3D.new();label.text=site.name.to_upper();label.position=site.position+Vector3(0,14,0)
			label.visible=false;label.font_size=64;label.pixel_size=.035;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
		environment=Scenery.new();add_child(environment);environment.setup(terrain)
		grass=Grass.new();add_child(grass);grass.setup(terrain)
	waterways=preload("res://tools/voxel_battle/waterways.gd").new();add_child(waterways);waterways.build(self,graphics,physics)
func add_box(p: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.position=p;add_child(body)
	var shape:=BoxShape3D.new();shape.size=size
	var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	geometry.append(AABB(p-size*.5,size))
func seed_collision() -> void:
	# Spatially grouped authoritative colliders; rendering residency has no effect.
	var shapes:=Scenery.collision_shapes()
	for z in Landscape.GRID:
		for x in Landscape.GRID:
			var coord:=Vector2i(x,z)
			var rows:=Landscape.features(coord);collision_rows[coord]=rows
			var body: StaticBody3D
			for row in rows:
				if row.kind==2:continue
				if body==null:body=StaticBody3D.new();body.name="Trees_%d_%d"%[x,z];add_child(body)
				var collider:=CollisionShape3D.new();collider.shape=shapes[row.kind]
				collider.transform=Transform3D(Basis(Vector3.UP,row.angle).scaled(Vector3.ONE*row.scale),row.position)
				collider.position.y+=8.5*row.scale
				body.add_child(collider);environment_colliders+=1
func update_view(camera: Camera3D) -> void:
	if terrain!=null:terrain.tick(camera);structures.update(camera);environment.update(camera);grass.update(camera)

static func collision_cache_path() -> String:
	var fingerprint:=FileAccess.get_sha256("res://tools/voxel_battle/landscape.gd")+FileAccess.get_sha256("res://tools/voxel_battle/architecture.gd")+FileAccess.get_sha256("res://tools/voxel_battle/outer_architecture.gd")+FileAccess.get_sha256("res://tools/voxel_battle/hydrology.gd")+FileAccess.get_sha256("res://tools/voxel_battle/waterways.gd")
	return "user://jungle-heightmap-%s.res"%fingerprint.sha256_text().left(16)
static func terrain_collision() -> HeightMapShape3D:
	var path:=collision_cache_path()
	if FileAccess.file_exists(path):return load(path)
	Landscape.prepare_roads()
	var spacing:=Landscape.EXTENT/(COLLISION_SIDE-1)
	var heights:=PackedFloat32Array();heights.resize(COLLISION_SIDE*COLLISION_SIDE)
	for z in COLLISION_SIDE:
		for x in COLLISION_SIDE:
			var px:=x*spacing-LIMIT;var pz:=z*spacing-LIMIT
			heights[z*COLLISION_SIDE+x]=Landscape.surface(px,pz).x/spacing
	var shape:=HeightMapShape3D.new();shape.map_width=COLLISION_SIDE;shape.map_depth=COLLISION_SIDE;shape.map_data=heights
	assert(ResourceSaver.save(shape,path,ResourceSaver.FLAG_COMPRESS)==OK)
	return shape

func navigation_source_chunk(bounds: AABB,heights: PackedFloat32Array) -> NavigationMeshSourceGeometryData3D:
	# River beds collide but are excluded from walking navigation.
	var data:=NavigationMeshSourceGeometryData3D.new()
	var step:=Landscape.EXTENT/(COLLISION_SIDE-1)
	var faces:=PackedVector3Array()
	var lo:=Vector2i(maxi(0,floori((bounds.position.x+LIMIT)/step)),maxi(0,floori((bounds.position.z+LIMIT)/step)))
	var hi:=Vector2i(mini(COLLISION_SIDE-1,ceili((bounds.end.x+LIMIT)/step)),mini(COLLISION_SIDE-1,ceili((bounds.end.z+LIMIT)/step)))
	for z in range(lo.y,hi.y):
		for x in range(lo.x,hi.x):
			var a:=Vector3(x*step-LIMIT,heights[z*COLLISION_SIDE+x]*step,z*step-LIMIT)
			var b:=Vector3((x+1)*step-LIMIT,heights[z*COLLISION_SIDE+x+1]*step,z*step-LIMIT)
			var c:=Vector3(x*step-LIMIT,heights[(z+1)*COLLISION_SIDE+x]*step,(z+1)*step-LIMIT)
			var d:=Vector3((x+1)*step-LIMIT,heights[(z+1)*COLLISION_SIDE+x+1]*step,(z+1)*step-LIMIT)
			if a.is_finite() and b.is_finite() and c.is_finite() and Landscape.water_mask((a.x+b.x+c.x)/3,(a.z+b.z+c.z)/3)<.5:faces.append_array(PackedVector3Array([a,b,c]))
			if b.is_finite() and d.is_finite() and c.is_finite() and Landscape.water_mask((b.x+d.x+c.x)/3,(b.z+d.z+c.z)/3)<.5:faces.append_array(PackedVector3Array([b,d,c]))
	if not faces.is_empty():data.add_faces(faces,Transform3D.IDENTITY)
	for row in layout.boxes:
		var center: Vector3=Landscape.CENTERS[row.kind]+row.center
		if bounds.intersects(AABB(center-row.size*.5,row.size)):
			var box:=BoxMesh.new();box.size=row.size
			data.add_mesh_array(box.get_mesh_arrays(),Transform3D(Basis.IDENTITY,center))
	var trunks: Array=[]
	for kind in 2:
		var trunk:=CylinderMesh.new();trunk.radial_segments=6;trunk.rings=1;trunk.height=17;trunk.top_radius=.43 if kind==0 else .32;trunk.bottom_radius=trunk.top_radius
		trunks.append(trunk.get_mesh_arrays())
	lo=Vector2i(maxi(0,floori((bounds.position.x+LIMIT-2)/Landscape.TILE)),maxi(0,floori((bounds.position.z+LIMIT-2)/Landscape.TILE)))
	hi=Vector2i(mini(Landscape.GRID,ceili((bounds.end.x+LIMIT+2)/Landscape.TILE)),mini(Landscape.GRID,ceili((bounds.end.z+LIMIT+2)/Landscape.TILE)))
	for z in range(lo.y,hi.y):
		for x in range(lo.x,hi.x):
			for row in collision_rows.get(Vector2i(x,z),[]):
				if row.kind==2:continue
				data.add_mesh_array(trunks[row.kind],Transform3D(Basis(Vector3.UP,row.angle).scaled(Vector3.ONE*row.scale),row.position+Vector3.UP*8.5*row.scale))
	if waterways!=null:waterways.navigation_source(data,bounds)
	return data
