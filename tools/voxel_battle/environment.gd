extends Node3D
## Original opaque, vertex-colored assets. Features share the terrain worker jobs,
## residency and eviction, with nine shared species/LOD draws rather than nodes.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Stream=preload("res://tools/streamed_heightfield/stream.gd")
const Builder=preload("res://tools/streamed_heightfield/structures.gd").Builder
const Under=preload("res://tools/voxel_battle/undergrowth_assets.gd")
const SVO=preload("res://tools/voxel_battle/tree_svo.gd")
var render_mode:="hybrid"
var variants: Dictionary={}
var svo_stats: Array=[]
var svo_sources: Dictionary={}
var svo_resident: Dictionary={}
var svo_uploads:=0
var peak_svo_uploads_per_frame:=0
var svo_evictions:=0
var svo_resident_bytes:=0
const CAPACITY:=Stream.CAPACITY*16
const VIEW_DISTANCE:=240.0
var tiles: Dictionary={}
var meshes: Array=[]
var groups: Array=[]
var counts: Array=[]
var visible_features:=0
var resident_features:=0
var peak_features:=0
var draw_calls:=0
var triangles:=0
var dirty:=true
var last_position:=Vector3.INF
var last_rotation:=Vector3.INF
var culling_enabled:=true
var force_near:=false
var update_ms:=0.0
static func triangle(b, a: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	var start: int=b.vertices.size()
	var normal: Vector3=(c-a).cross(d-a).normalized()
	var shade:=color*(.70+.30*absf(normal.dot(Vector3(-.4,.8,.3).normalized())))
	shade.a=1
	for p in [a,c,d]:b.vertices.append(p);b.colors.append(shade)
	b.indices.append_array(PackedInt32Array([start,start+1,start+2]))
static func cone(b,p: Vector3,radius: float,height: float,segments: int,color: Color,top_radius: float=0) -> void:
	for i in segments:
		var a:=TAU*i/segments;var c:=TAU*(i+1)/segments
		var left:=p+Vector3(cos(a)*radius,0,sin(a)*radius)
		var right:=p+Vector3(cos(c)*radius,0,sin(c)*radius)
		var tip:=p+Vector3(cos(a)*top_radius,height,sin(a)*top_radius)
		var next:=p+Vector3(cos(c)*top_radius,height,sin(c)*top_radius)
		triangle(b,left,right,tip,color)
		if top_radius>0:triangle(b,right,next,tip,color)
		triangle(b,p,right,left,color.darkened(.2))
static func ellipsoid(b,p: Vector3,radius: Vector3,segments: int,color: Color) -> void:
	for ring in 4:
		var y0: float=-PI*.5+PI*ring/4
		var y1: float=-PI*.5+PI*(ring+1)/4
		for i in segments:
			var a:=TAU*i/segments;var c:=TAU*(i+1)/segments
			var v0:=p+Vector3(cos(y0)*cos(a),sin(y0),cos(y0)*sin(a))*radius
			var v1:=p+Vector3(cos(y0)*cos(c),sin(y0),cos(y0)*sin(c))*radius
			var v2:=p+Vector3(cos(y1)*cos(a),sin(y1),cos(y1)*sin(a))*radius
			var v3:=p+Vector3(cos(y1)*cos(c),sin(y1),cos(y1)*sin(c))*radius
			triangle(b,v0,v2,v1,color);triangle(b,v1,v2,v3,color)
static func asset(kind: int,lod: int) -> ArrayMesh:
	var b:=Builder.new()
	var segments: int=[8,6,4][lod]
	if kind<2:
		cone(b,Vector3.ZERO,.43 if kind==0 else .32,17,segments,Color(.32,.23,.13),.2)
		for crown in SVO.crowns(kind):
			ellipsoid(b,Vector3(crown.x,crown.y,crown.z),Vector3(crown.w,crown.w*(.65 if kind==0 else .16),crown.w),segments,Color(.19,.34,.17) if crown.x<=0 else Color(.27,.43,.20))
	else:return Under.asset(2,lod)
	return b.finish()
static func card(kind: int) -> ArrayMesh:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-7,0,0),Vector3(7,0,0),Vector3(7,20,0),Vector3(-7,20,0)])
	var u: float=kind*.5
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(u,1),Vector2(u+.5,1),Vector2(u+.5,0),Vector2(u,0)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load("res://experimental-assets/jungle/trees.png")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold=.45
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale=true
	mesh.surface_set_material(0,material)
	return mesh
func make_variants() -> void:
	for mode in ["mesh","billboard","svo","hybrid"]:variants[mode]=[[],[],[]]
	for kind in 3:
		for lod in 3:
			var mesh:=asset(kind,lod)
			variants.mesh[kind].append(mesh)
			var billboard:=card(kind) if kind<2 else Under.card(2)
			variants.billboard[kind].append(billboard)
			variants.hybrid[kind].append(billboard if lod==2 else mesh)
			var voxel_mesh=mesh
			if kind<2:
				var box:=BoxMesh.new();box.size=Vector3(14,20,14)
				var b:=Builder.new()
				var raw:=box.get_mesh_arrays()
				b.vertices=raw[Mesh.ARRAY_VERTEX];b.indices=raw[Mesh.ARRAY_INDEX]
				for i in b.vertices.size():b.vertices[i].y+=10;b.colors.append(Color.WHITE)
				voxel_mesh=b.finish()
				var material:=ShaderMaterial.new();material.shader=preload("res://tools/voxel_battle/tree_svo.gdshader")
				voxel_mesh.surface_set_material(0,material)
			variants.svo[kind].append(voxel_mesh)
func set_mode(mode: String) -> void:
	assert(variants.has(mode));render_mode=mode;meshes=variants[mode]
	for kind in 3:
		for lod in 3:groups[kind][lod].multimesh.mesh=meshes[kind][lod]
	dirty=true
func stream_svo_resources() -> void:
	# Demand-load only shared canonical trees/LODs used by streamed instances.
	# This is asset streaming, not an enormous unique voxel volume per tree.
	var wanted: Dictionary={}
	var uploaded:=0
	if render_mode=="svo":
		for kind in 2:
			for lod in 3:
				if counts[kind][lod]==0:continue
				var key:=Vector2i(kind,lod);wanted[key]=true
				if not svo_resident.has(key):
					if uploaded>=Stream.UPLOADS_PER_FRAME:dirty=true;continue
					if not svo_sources.has(key):
						var data:=SVO.new().build(kind,lod);svo_sources[key]=data
						svo_stats.append({"kind":kind,"lod":lod,"nodes":data.nodes,"bytes":data.bytes,"resolution":data.resolution,"occupied":data.occupied})
					var texture:=ImageTexture.create_from_image(svo_sources[key].image)
					variants.svo[kind][lod].surface_get_material(0).set_shader_parameter("nodes",texture)
					svo_resident[key]=texture;svo_uploads+=1;uploaded+=1
	peak_svo_uploads_per_frame=maxi(peak_svo_uploads_per_frame,uploaded)
	for key in svo_resident.keys():
		if not wanted.has(key):
			variants.svo[key.x][key.y].surface_get_material(0).set_shader_parameter("nodes",null)
			svo_resident.erase(key);svo_evictions+=1
	svo_resident_bytes=0
	for key in svo_resident:svo_resident_bytes+=svo_sources[key].bytes
func setup(stream) -> void:
	make_variants()
	stream.tile_loaded.connect(load_tile)
	stream.tile_evicted.connect(evict_tile)
	for kind in 3:
		meshes.append([]);groups.append([])
		for lod in 3:
			meshes[kind].append(variants[render_mode][kind][lod])
			var group:=MultiMeshInstance3D.new();group.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
			group.multimesh=MultiMesh.new();group.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			group.multimesh.mesh=meshes[kind][lod];group.multimesh.instance_count=CAPACITY
			group.multimesh.visible_instance_count=0
			group.custom_aabb=AABB(Vector3(-Landscape.EXTENT/2,Landscape.MIN_HEIGHT,-Landscape.EXTENT/2),Vector3(Landscape.EXTENT,Landscape.MAX_HEIGHT-Landscape.MIN_HEIGHT+30,Landscape.EXTENT))
			group.multimesh.custom_aabb=group.custom_aabb
			group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(group);groups[kind].append(group)
func load_tile(coord: Vector2i,data: Dictionary) -> void:
	var rows: Array=data.get("features",[])
	var height_range: Vector2=data.height_bounds
	var bounds:=AABB(Vector3(coord.x*Landscape.TILE-Landscape.EXTENT/2,height_range.x,coord.y*Landscape.TILE-Landscape.EXTENT/2),Vector3(Landscape.TILE,height_range.y-height_range.x+30,Landscape.TILE)).grow(9)
	tiles[coord]={"rows":rows,"bounds":bounds}
	resident_features+=rows.size();peak_features=maxi(peak_features,resident_features);dirty=true
func evict_tile(coord: Vector2i) -> void:
	if tiles.has(coord):resident_features-=tiles[coord].rows.size();tiles.erase(coord);dirty=true
func update(camera: Camera3D) -> void:
	if not dirty and camera.global_position==last_position and camera.global_rotation==last_rotation:return
	var begin:=Time.get_ticks_usec()
	dirty=false;last_position=camera.global_position;last_rotation=camera.global_rotation
	counts=[[0,0,0],[0,0,0],[0,0,0]];visible_features=0;triangles=0;draw_calls=0
	var planes:=camera.get_frustum()
	for tile in tiles.values():
		if culling_enabled and Stream.outside_frustum(tile.bounds,planes):continue
		for row in tile.rows:
			var distance: float=camera.global_position.distance_to(row.position)
			if Vector2(camera.global_position.x-row.position.x,camera.global_position.z-row.position.z).length()>VIEW_DISTANCE:continue
			var basis:=Basis(Vector3.UP,row.angle).scaled(Vector3.ONE*row.scale)
			var transform:=Transform3D(basis,row.position)
			var bounds: AABB=transform*variants.mesh[row.kind][0].get_aabb()
			if culling_enabled and Stream.outside_frustum(bounds,planes):continue
			var lod: int=row.get("lod",2)
			if force_near or distance<42:lod=0
			elif distance>130:lod=2
			elif lod==0 and distance>55:lod=1
			elif lod==2 and distance<110:lod=1
			row.lod=lod
			var index: int=counts[row.kind][lod]
			groups[row.kind][lod].multimesh.set_instance_transform(index,transform)
			counts[row.kind][lod]+=1;visible_features+=1
			triangles+=meshes[row.kind][lod].surface_get_array_index_len(0)/3
	stream_svo_resources()
	for kind in 3:
		for lod in 3:
			groups[kind][lod].multimesh.visible_instance_count=counts[kind][lod]
			groups[kind][lod].visible=counts[kind][lod]>0 and (render_mode!="svo" or kind==2 or svo_resident.has(Vector2i(kind,lod)))
			if counts[kind][lod]>0:draw_calls+=1
	update_ms=(Time.get_ticks_usec()-begin)/1000.0
static func collision_shapes() -> Array:
	var broadleaf:=CylinderShape3D.new();broadleaf.radius=.43;broadleaf.height=17
	var palm:=CylinderShape3D.new();palm.radius=.32;palm.height=17
	return [broadleaf,palm]
