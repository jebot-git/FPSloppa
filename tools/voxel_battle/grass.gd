extends Node3D
## Hybrid waist-high canopy and large bushes sharing terrain generation/residency.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Stream=preload("res://tools/streamed_heightfield/stream.gd")
const Assets=preload("res://tools/voxel_battle/undergrowth_assets.gd")
const CAPACITY:=2048 # Total across species and LODs, not per tile/eye.
const GROUP_CAPS:=[600,400,600,84,56,84,42,28,42,42,28,42]
const LOD_CAPS:=[768,512,768] # Reserve far cards, even in dense near vegetation.
const VIEW_DISTANCE:=96.0
var view_distance:=VIEW_DISTANCE
const NEAR_DISTANCE:=16.0
const CARD_DISTANCE:=36.0
const REFRESH_SECONDS:=1.0/30
var enabled:=true
var tiles: Dictionary={}
var groups: Array=[]
var buffers: Array=[]
var counts: Array=[0,0,0,0,0,0,0,0,0,0,0,0]
var visible_tufts:=0
var max_submitted_distance:=0.0
var resident_tufts:=0
var peak_resident_tufts:=0
var candidates:=0
var draw_calls:=0
var triangles:=0
var update_ms:=0.0
var refreshes:=0
var dirty:=true
var last_position:=Vector3.INF
var last_rotation:=Vector3.INF
var next_refresh_usec:=0
func set_enabled(value: bool) -> void:
	if enabled==value:return
	enabled=value;dirty=true
	if not value:
		for group in groups:group.visible=false;group.multimesh.visible_instance_count=0
		counts=[0,0,0,0,0,0,0,0,0,0,0,0];visible_tufts=0;draw_calls=0;triangles=0;update_ms=0;max_submitted_distance=0
static func species(row:Vector4) -> int:
	# Tall grass dominates. Broad leaves and bushes share occasional irregular
	# 18 m patches instead of being sprinkled uniformly across every tile.
	var cell:=Vector2(floor(row.x/18),floor(row.z/18))
	var patch:=fposmod(sin(cell.x*19.19+cell.y*73.73)*43758.5453,1)
	if patch>.18:return 0
	var center:=(cell+Vector2(.5+.18*sin(cell.y*3.1),.5+.18*cos(cell.x*4.7)))*18
	var radius:float=5.5+patch*10
	if Vector2(row.x,row.z).distance_to(center)>radius:return 0
	var value:=fposmod(sin(row.x*12.9898+row.z*78.233)*43758.5453,1)
	return 1 if value<.45 else 2 if value<.73 else 3
static func asset(lod:int,kind:int=0) -> ArrayMesh:
	return Assets.card(kind) if lod==2 else Assets.asset(kind,lod)
func set_distance(value:float) -> void:
	view_distance=clampf(value,24,160);dirty=true
func setup(stream) -> void:
	stream.tile_loaded.connect(load_tile);stream.tile_evicted.connect(evict_tile)
	for kind in 4:
		for lod in 3:
			var group:=MultiMeshInstance3D.new();group.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
			group.multimesh=MultiMesh.new();group.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			group.multimesh.mesh=asset(lod,kind);group.multimesh.instance_count=GROUP_CAPS[kind*3+lod];group.multimesh.visible_instance_count=0
			group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.visible=false;add_child(group);groups.append(group)
			var buffer:=PackedFloat32Array();buffer.resize(GROUP_CAPS[kind*3+lod]*12);buffers.append(buffer)
func load_tile(coord: Vector2i,data: Dictionary) -> void:
	var rows: PackedVector4Array=data.get("grass",PackedVector4Array())
	var heights: Vector2=data.height_bounds
	var bounds:=AABB(Vector3(coord.x*Landscape.TILE-Landscape.EXTENT*.5,heights.x-1,coord.y*Landscape.TILE-Landscape.EXTENT*.5),Vector3(Landscape.TILE,heights.y-heights.x+4,Landscape.TILE))
	var kinds:=PackedByteArray();kinds.resize(rows.size())
	for index in rows.size():kinds[index]=species(rows[index])
	tiles[coord]={"rows":rows,"kinds":kinds,"bounds":bounds}
	resident_tufts+=rows.size();peak_resident_tufts=maxi(peak_resident_tufts,resident_tufts);dirty=true
func evict_tile(coord: Vector2i) -> void:
	if tiles.has(coord):resident_tufts-=tiles[coord].rows.size();tiles.erase(coord);dirty=true
func update(camera: Camera3D) -> void:
	update_ms=0
	if not enabled:return
	var now:=Time.get_ticks_usec()
	if not dirty:
		if camera.global_position==last_position and camera.global_rotation==last_rotation:return
		if now<next_refresh_usec:return
	var begin:=now
	refreshes+=1
	dirty=false;last_position=camera.global_position;last_rotation=camera.global_rotation;next_refresh_usec=now+int(REFRESH_SECONDS*1000000)
	counts=[0,0,0,0,0,0,0,0,0,0,0,0];candidates=0;max_submitted_distance=0;visible_tufts=0;draw_calls=0;triangles=0
	var buckets: Array=[]
	for i in ceili(view_distance)*4:buckets.append(PackedVector4Array())
	camera.force_update_transform()
	var planes:=camera.get_frustum()
	# Tight local bounds precede individual checks. No raycasts or physics shapes.
	var nearby: Array=[]
	var center:=Landscape.bin_key(Vector2(camera.global_position.x,camera.global_position.z))
	var tile_radius:=ceili((view_distance+2)/Landscape.TILE)
	for z in range(center.y-tile_radius,center.y+tile_radius+1):
		for x in range(center.x-tile_radius,center.x+tile_radius+1):
			var key:=Vector2i(x,z)
			if tiles.has(key):nearby.append(tiles[key])
	for tile in nearby:
		var bounds: AABB=tile.bounds
		if camera.global_position.clamp(bounds.position,bounds.end).distance_squared_to(camera.global_position)>view_distance*view_distance:continue
		if Stream.outside_frustum(bounds.grow(2.1),planes):continue
		for row_index in tile.rows.size():
			var row:Vector4=tile.rows[row_index]
			var p:=Vector3(row.x,row.y,row.z)
			if absf(camera.global_position.y-p.y)>8:continue # Flight/high overview suppression.
			var distance_squared:=camera.global_position.distance_squared_to(p)
			if distance_squared>=view_distance*view_distance:continue
			candidates+=1
			if Stream.outside_frustum(AABB(p-Vector3(2.1,.05,2.1),Vector3(4.2,2.8,4.2)),planes):continue
			buckets[int(sqrt(distance_squared))*4+int(tile.kinds[row_index])].append(row)
	var local_bounds:=AABB(camera.global_position-Vector3.ONE*(view_distance+3),Vector3.ONE*(view_distance+3)*2)
	# Near-first within each LOD; separate LOD budgets preserve distant coverage.
	for group_index in groups.size():
		var kind:int=group_index/3;var lod:int=group_index%3
		var buffer:PackedFloat32Array=buffers[group_index]
		var start:=0 if lod==0 else int(NEAR_DISTANCE if lod==1 else CARD_DISTANCE)
		var end:=mini(ceili(view_distance),int(NEAR_DISTANCE if lod==0 else CARD_DISTANCE) if lod<2 else ceili(view_distance))
		for distance in range(start,end):
			for row:Vector4 in buckets[distance*4+kind]:
				if counts[group_index]>=GROUP_CAPS[group_index]:break
				# Stable distance thinning allows cards to reach the full requested
				# range instead of filling the far budget in the closest ring.
				if lod==2 and fposmod(sin(row.x*39.3+row.z*7.1)*12345.67,1)>pow(CARD_DISTANCE/maxf(distance,CARD_DISTANCE),2):continue
				var p:=Vector3(row.x,row.y,row.z)
				var scale:=.90+.20*(.5+.5*sin(row.x*3.1+row.z*2.7))
				var height_scale:=1-smoothstep(view_distance-8,view_distance,camera.global_position.distance_to(p))
				var basis:=Basis(Vector3.UP,row.w).scaled(Vector3(scale,scale*height_scale,scale))
				var index:int=counts[group_index]*12
				buffer[index]=basis.x.x;buffer[index+1]=basis.y.x;buffer[index+2]=basis.z.x;buffer[index+3]=p.x
				buffer[index+4]=basis.x.y;buffer[index+5]=basis.y.y;buffer[index+6]=basis.z.y;buffer[index+7]=p.y
				buffer[index+8]=basis.x.z;buffer[index+9]=basis.y.z;buffer[index+10]=basis.z.z;buffer[index+11]=p.z
				counts[group_index]+=1;visible_tufts+=1;max_submitted_distance=maxf(max_submitted_distance,camera.global_position.distance_to(p))
				triangles+=groups[group_index].multimesh.mesh.surface_get_array_index_len(0)/3
		buffers[group_index]=buffer
	for index in groups.size():
		var group:MultiMeshInstance3D=groups[index]
		group.visible=counts[index]>0;group.multimesh.visible_instance_count=counts[index]
		group.custom_aabb=local_bounds;group.multimesh.custom_aabb=local_bounds
		if counts[index]>0:group.multimesh.buffer=buffers[index];draw_calls+=1
	update_ms=(Time.get_ticks_usec()-begin)/1000.0
