extends SceneTree
## Reproducible capture of a random bundled UT99 model in production prone pose.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
const Grass=preload("res://tools/voxel_battle/grass.gd")
const Format=preload("res://deathmatch/avatars/ut_format.gd")
var map
var camera:Camera3D
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000)
	DisplayServer.window_set_title("Prone player · standing observer · 3 m · Forward+")
	var stage:=Node3D.new();root.add_child(stage)
	var library:=preload("res://deathmatch/avatars/library.gd").new();stage.add_child(library)
	var manifest:Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	var rng:=RandomNumberGenerator.new();rng.randomize()
	var args:=OS.get_cmdline_user_args()
	if args.has("--seed"):rng.seed=str(args[args.find("--seed")+1]).to_int()
	var seed_value:=rng.seed
	var selected:Dictionary=manifest[rng.randi_range(0,manifest.size()-1)]
	var avatar=library.create_avatar(selected.hash)
	if avatar==null:push_error(library.last_error);quit(1);return
	stage.add_child(avatar);avatar.unarmed=true;avatar.selected_sequence="Breath1";avatar.stance="prone";avatar.preview_mode=-1;avatar.tracked_arms_enabled=false;avatar._process(0);avatar.set_process(false)
	# Use the production prone pose without hiding any part beneath the terrain.
	var decoded:=Format.read(selected.path);var positions:PackedFloat32Array=decoded.positions.to_float32_array()
	var clip:Dictionary=avatar.choose_clip();var frame:int=clip.start
	var minimum:=INF;var maximum:=-INF
	for i in int(decoded.manifest.vertices):
		var index:int=(frame*int(decoded.manifest.vertices)+i)*4
		var p:Vector3=avatar.visual.transform*Vector3(positions[index],positions[index+1],positions[index+2])
		minimum=minf(minimum,p.y);maximum=maxf(maximum,p.y)
	var coord:=Landscape.bin_key(Vector2(-1000,-300))
	var point:=Vector3.ZERO;var found:=false
	for offset in [Vector2i.ZERO,Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,1),Vector2i(-2,0),Vector2i(2,0)]:
		var data:=Landscape.new().generate_tile(coord+offset)
		var trees:=Landscape.features(coord+offset)
		for row:Vector4 in data.grass:
			if Grass.species(row)!=0:continue
			var x:float=row.x;var z:float=row.z
			var slope:=Vector2(Landscape.surface(x+1,z).x-Landscape.surface(x-1,z).x,Landscape.surface(x,z+1).x-Landscape.surface(x,z-1).x).length()*.5
			if slope>.12:continue
			var observer_ground:=Landscape.surface(x+3,z).x
			if absf(observer_ground-(row.y+.03))>.40:continue
			var clear:=true
			for tree in trees:
				if tree.kind<2 and (Vector2(tree.position.x,tree.position.z).distance_to(Vector2(x,z))<1.5 or Vector2(tree.position.x,tree.position.z).distance_to(Vector2(x+3,z))<.6):clear=false
			if not clear:continue
			point=Vector3(x,Landscape.surface(x,z).x,z);found=true;break
		if found:break
	if args.has("--reference-receipt"):
		var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--reference-receipt")+1]))
		var values:PackedStringArray=str(previous.point).trim_prefix("(").trim_suffix(")").split(",")
		point=Vector3(values[0].to_float(),values[1].to_float(),values[2].to_float());found=true
		if selected.hash!=previous.hash:push_error("Reference model does not match seed");quit(1);return
	if not found:push_error("No suitable flat tall-grass patch found");quit(1);return
	var lift:float=-minimum+.035
	for i in int(decoded.manifest.vertices):
		var index:int=(frame*int(decoded.manifest.vertices)+i)*4
		var p:Vector3=avatar.visual.transform*Vector3(positions[index],positions[index+1],positions[index+2])
		lift=maxf(lift,Landscape.surface(point.x+p.x,point.z+p.z).x-point.y-p.y+.035)
	avatar.position=point+Vector3(0,lift,0)
	camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(point.x+3,Landscape.surface(point.x+3,point.z).x+1.7,point.z);camera.fov=60;camera.far=2200;camera.current=true;camera.look_at(point+Vector3(0,.3,-.35))
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.38,.55,.63);stage.add_child(env)
	map=Map.new();stage.add_child(map);map.build(true,false)
	map.update_view(camera)
	var deadline:=Time.get_ticks_msec()+120000
	while not map.terrain.settled():
		map.update_view(camera);await process_frame
		if Time.get_ticks_msec()>deadline:push_error("Terrain streaming timeout");quit(1);return
	map.grass.dirty=true;map.update_view(camera)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var output:="res://test-results/jungle-prone-observer"
	if args.has("--output"):output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var covered:=root.get_texture().get_image();covered.save_png(output+"/prone-in-grass.png")
	avatar.visible=false
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var covered_background:=root.get_texture().get_image();covered_background.save_png(output+"/grass-background.png")
	avatar.visible=true
	# Internal visibility reference confirms the same model/pose was present.
	map.grass.set_enabled(false)
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var reference:=root.get_texture().get_image();reference.save_png(output+"/prone-reference.png")
	avatar.visible=false
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var reference_background:=root.get_texture().get_image();reference_background.save_png(output+"/reference-background.png")
	var reference_pixels:=0;var visible_pixels:=0
	for y in reference.get_height():
		for x in reference.get_width():
			var a:=reference.get_pixel(x,y);var b:=reference_background.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))<=3.0/255:continue
			reference_pixels+=1
			var c:=covered.get_pixel(x,y);var d:=covered_background.get_pixel(x,y)
			if maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))>3.0/255:visible_pixels+=1
	var receipt:={"reference_avatar_pixels":reference_pixels,"visible_avatar_pixels":visible_pixels,"visible_fraction":float(visible_pixels)/maxi(reference_pixels,1),"model":selected.title,"hash":selected.hash,"seed":str(seed_value),"source":"random draw from bundled UT99 roster","stance":avatar.stance,"clip":clip.name,"frame":frame,"standing_eye_height_m":1.7,"horizontal_observer_distance_m":3.0,"prone_height_m":maximum-minimum,"ground_clearance_m":.035,"point":str(point),"observer":str(camera.position),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"undergrowth_distance_m":map.grass.view_distance,"note":"Still preview: original straight-body Breath1 frame with the production prone transform, grounded using native frame bounds; no AI or fabricated tracking."}
	FileAccess.open(output+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "));print("PRONE_OBSERVER ",JSON.stringify(receipt))
	avatar.visible=true;map.grass.set_enabled(true);map.grass.update(camera)
	map.terrain.shutdown()
	if not args.has("--keep-open"):quit()
