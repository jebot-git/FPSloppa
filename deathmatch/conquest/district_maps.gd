extends RefCounted
## Opt-in atlas: one independent local BSP per authority, one active scene per client.
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Paths=preload("res://deathmatch/assets/paths.gd")
const BASE="res://maps/CQDistricts/"
const PROFILE="cq-district-bsp-1"
var game
var enabled:=false
var manifest: Dictionary={}
var identity:=""
var zone:=-1
var loading:=-1
var pending:=-1
var prepared: Dictionary={}
var transitions: Array=[]
var prefetch_at:=0.0
var cluster_asset:=-1
var cluster_slot:=-1
func _init(arena):
	game=arena;enabled=OS.get_cmdline_user_args().has("--cq-district-maps")
func file(district: int,name: String) -> String:
	if cluster_asset>=0 and district==cluster_slot:return Paths.resolve("res://maps/CampaignDistricts/district_%02d/"%cluster_asset+name)
	return Paths.resolve(BASE+"district_%02d/"%district+name)
func origin(district: int) -> Vector3:
	var row: Array=manifest.districts[district].origin;return Vector3(row[0],row[1],row[2])
func install() -> String:
	var path:=Paths.resolve(BASE+"manifest.json")
	if not FileAccess.file_exists(path):return "Build and prepare the CQ district-map pack first."
	var value=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("profile","")!=PROFILE or value.get("districts",[]).size()!=16:return "Invalid CQ district atlas."
	manifest=value;identity=FileAccess.get_sha256(path)
	var args:=OS.get_cmdline_user_args();var worker: int=game._arg_int(args,"--cq-worker",-1)
	if args.has("--cluster-worker"):
		var config=JSON.parse_string(FileAccess.get_file_as_string(game._arg_value(args,"--cluster-worker","")))
		if config is Dictionary and config.has("asset_id"):
			cluster_asset=int(config.asset_id);cluster_slot=worker
			var campaign=JSON.parse_string(FileAccess.get_file_as_string(Paths.resolve("res://maps/CampaignDistricts/manifest.json")))
			if not campaign is Dictionary or campaign.get("profile")!="vesper-campaign-81" or cluster_asset not in range(81) or worker not in range(16):return "Invalid campaign atlas."
			var row: Dictionary=campaign.districts[cluster_asset].duplicate(true);row.id=worker
			var center:=Rules.center(worker);row.origin=[center.x,center.y,center.z]
			manifest.districts[worker]=row
	var master: bool=(OS.has_feature("dedicated_server") or args.has("--server")) and worker<0
	for i in 16:
		var row: Dictionary=manifest.districts[i]
		if int(row.id)!=i or row.get("spawns",[]).size()!=4 or row.get("pickup_positions",[]).size()!=8:return "Invalid CQ district inventory."
		if master or worker>=0 and worker!=i:continue
		for name in (["district.bsp","collision.scn","navigation.res"] if worker>=0 else ["district.bsp","presentation.scn"]):
			if not FileAccess.file_exists(file(i,name)) or FileAccess.get_sha256(file(i,name))!=row.files.get(name,""):return "Missing or mismatched CQ district %02d: %s"%[i+1,name]
	game.map_catalog.append({"id":game.match_mode.conquest.MAP_ID,"title":"Vesper · Independent Districts","path":path,"sha256":identity,"size":FileAccess.get_file_as_bytes(path).size(),"modes":["cq"]})
	game.selected_map=game.match_mode.conquest.MAP_ID
	return ""
func reset() -> void:
	zone=-1;loading=-1;prepared.clear();prefetch_at=0
	# In-flight ResourceLoader work is drained by pump; never block disconnect.
func spawn_points() -> void:
	game.spawn_points.clear();game.spawn_yaws.clear()
	var selected: Array=range(16) # Spawn metadata is global; geometry and navigation remain local.
	for i in selected:
		for row in manifest.districts[i].spawns:
			game.spawn_points.append(origin(i)+Vector3(row[0],row[1],row[2]));game.spawn_yaws.append(0.0)
func clear_map() -> void:
	game.match_mode.clear_visuals()
	for child in game.get_node("Map").get_children():game.get_node("Map").remove_child(child);child.queue_free()
	for pickup in game.pickups:
		if is_instance_valid(pickup.node):pickup.node.queue_free()
	game.pickups.clear();game.gates.clear();game.lifts.clear();game.map_objectives.clear();game.ctf_spawns=[[],[]];game.tf_resupply=[[],[]];game.tf_capture.clear();game.map_assault.clear()
func load_world() -> bool:
	if game.current_map==game.match_mode.conquest.MAP_ID and game.get_node("Map").get_child_count()>0:return true
	clear_map();zone=-1
	var worker: int=game._arg_int(OS.get_cmdline_user_args(),"--cq-worker",-1)
	if worker>=0:
		var packed: PackedScene=load(file(worker,"collision.scn"))
		if packed==null:return false
		activate(worker,packed)
	else:
		var atlas:=Node3D.new();atlas.name="DistrictAtlas";game.get_node("Map").add_child(atlas)
		spawn_points();game.match_mode.conquest.configure_pickups();game.fall_limit=-14
	game.current_map=game.match_mode.conquest.MAP_ID;game.map_title="Vesper · Independent Districts";game.map_sha=identity
	game.loaded_pickup_rules=game.match_mode.kind+":"+game.armory.effective()
	print("CQ_ATLAS_READY district=",zone," geometry_instances=",1 if zone>=0 else 0)
	return true
func activate(district: int,packed: PackedScene) -> void:
	clear_map();zone=district
	var level:=packed.instantiate();level.name="District_%02d"%zone;level.position=origin(zone);game.get_node("Map").add_child(level)
	add_sky_bounds(level)
	for entity in level.find_children("*","Node3D",true,false):
		if "attributes" in entity and str(entity.attributes.get("classname","")).begins_with("light"):entity.free()
	var runtime:=preload("res://deathmatch/maps/runtime.gd").new();runtime.name="MapRuntime";game.get_node("Map").add_child(runtime)
	runtime.configure(game,level,file(zone,"district.bsp"));spawn_points();game.match_mode.conquest.configure_pickups()
	if not game.headless:preload("res://deathmatch/conquest/presentation.gd").apply(game)
static func add_sky_bounds(level: Node3D) -> void:
	# The importer omits sky triangles. Close the space above the 36 m walls
	# identically in authority and prediction so high jumps cannot bypass gates.
	var body:=StaticBody3D.new();body.name="DistrictSkyBounds";body.collision_layer=1;body.collision_mask=0;level.add_child(body)
	for row in [[Vector3(-125,73,0),Vector3(1,74,250)],[Vector3(125,73,0),Vector3(1,74,250)],[Vector3(0,73,-125),Vector3(250,74,1)],[Vector3(0,73,125),Vector3(250,74,1)],[Vector3(0,110,0),Vector3(250,1,250)]]:
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=row[1];shape.shape=box;shape.position=row[0];body.add_child(shape)
func request(district: int) -> void:
	if district<0 or district==zone or prepared.has(district) or pending>=0:return
	# At most the current scene and one prefetched scene are retained.
	prepared.clear();var error:=ResourceLoader.load_threaded_request(file(district,"presentation.scn"),"PackedScene")
	if error==OK:pending=district
func pump() -> void:
	if not enabled:return
	if pending>=0:
		var status:=ResourceLoader.load_threaded_get_status(file(pending,"presentation.scn"))
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var scene=ResourceLoader.load_threaded_get(file(pending,"presentation.scn"));prepared.clear();prepared[pending]=scene;pending=-1
		elif status==ResourceLoader.THREAD_LOAD_FAILED:pending=-1
	if zone<0 or loading>=0 or not game.active or game.multiplayer.is_server() or game.clock<prefetch_at:return
	prefetch_at=game.clock+.25
	var id: int=game.multiplayer.get_unique_id()
	if not game.fighters.has(id):return
	var p: Vector3=game.fighters[id].position;var best:=-1;var distance:=1600.0
	for next in Rules.neighbors(zone):
		var gate: Vector3=(Rules.center(zone)+Rules.center(next))*.5
		var d:=Vector2(p.x-gate.x,p.z-gate.z).length_squared()
		if d<distance:best=next;distance=d
	if best>=0:request(best)
func enter(district: int,expected_generation: int) -> bool:
	if district==zone:return true
	var began:=Time.get_ticks_msec();loading=district
	while not prepared.has(district):
		pump();request(district)
		if Time.get_ticks_msec()-began>45000 or not game.active or game.cq_client.generation!=expected_generation:loading=-1;return false
		await game.get_tree().process_frame
	var packed: PackedScene=prepared[district];prepared.clear()
	activate(district,packed)
	await game.get_tree().physics_frame
	loading=-1
	transitions.append({"zone":zone,"load_ms":Time.get_ticks_msec()-began})
	print("CQ_DISTRICT_LOADED ",zone," ms=",Time.get_ticks_msec()-began)
	return true
func pickup(zone_id: int,index: int) -> Vector3:
	var row: Array=manifest.districts[zone_id].pickup_positions[index];return origin(zone_id)+Vector3(row[0],row[1],row[2])
static func portal_allowed(source: int,target: int,point: Vector3) -> bool:
	if target not in Rules.neighbors(source) or point.y<-.5 or point.y>14.2:return false
	var center: Vector3=(Rules.center(source)+Rules.center(target))*.5
	return absf(point.z-center.z)<11.5 if absi(source-target)==1 else absf(point.x-center.x)<11.5
func route_target(source: int,target: int) -> Vector3:
	if target==source:return Rules.center(target)
	var next:=source;var best:=100
	for neighbor in Rules.neighbors(source):
		if is_instance_valid(game.district_worker) and game.district_worker.occupancy.size()==16 and game.district_worker.occupancy[neighbor]>=16:continue
		var cost: int=absi(neighbor%4-target%4)+absi(neighbor/4-target/4)
		if cost<best:next=neighbor;best=cost
	if next==source:return Rules.center(source)
	var direction: Vector3=(Rules.center(next)-Rules.center(source)).normalized()
	return (Rules.center(next)+Rules.center(source))*.5+direction*2
