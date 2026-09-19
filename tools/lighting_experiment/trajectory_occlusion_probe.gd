extends "res://tools/lighting_experiment/trajectory_probe.gd"
const TreeData=preload("res://tools/lighting_experiment/occlusion_tree.gd")
const OCC_OUT="res://test-results/trajectory-occlusion/"
const OCC_SOURCE="res://tools/lighting_experiment/trajectory_occlusion.gdshaderinc"
const CELL_SOURCE="res://tools/lighting_experiment/trajectory_occlusion_cells.gdshaderinc"
var tree_data=TreeData.new()
var use_occlusion:=true
var brush_heads:=PackedInt32Array()
var brush_transforms: Array[Transform3D]=[]
var local_tree=TreeData.new()
var local_mode:=false
var cell_mode:=false
var experimental_cells: bool="--cells" in OS.get_cmdline_user_args()
var active_count:=0
var local_heads:=PackedInt32Array()

func shader_variant(source: Shader) -> Shader:
	var key: Array=[source,cell_mode]
	if not variants.has(key):
		var addition:=FileAccess.get_file_as_string("res://tools/lighting_experiment/trajectory.gdshaderinc")
		addition=addition.replace("illumination +=", "if (falloff <= 0.0 || facing <= 0.0) continue;\n        if (!occlusion_clear_emitter(trajectory_world + normalize(trajectory_normal) * 0.002, a + t * segment, i)) continue;\n        illumination +=")
		var code:=source.code.replace("void fragment()",FileAccess.get_file_as_string(CELL_SOURCE if cell_mode else OCC_SOURCE)+"\n"+addition+"\nvoid fragment()")
		code=code.replace("ROUGHNESS = 1.0;","EMISSION += base * trajectory_illumination();\n    ROUGHNESS = 1.0;")
		var shader:=Shader.new();shader.code=code;variants[key]=shader
	return variants[key]
func activate(count: int,stock: bool=false) -> void:
	active_count=count
	super.activate(count,stock)
	if not stock:
		for material in receivers:
			tree_data.apply(material,use_occlusion,brush_heads,brush_transforms)
			material.set_shader_parameter("occlusion_local",false)
func update_segments(count: int,phase: float=0.0) -> void:
	super.update_segments(count,phase)
	if not local_mode or not use_occlusion or active_count==0:return
	local_tree.planes.clear();local_tree.children.clear();local_heads.resize(8)
	var combined:=AABB()
	for i in active_count:
		var a:=Vector3(starts[i].x,starts[i].y,starts[i].z)
		var b:=Vector3(ends[i].x,ends[i].y,ends[i].z)
		# Both ray endpoints and their segment lie inside this convex domain.
		var bounds:=AABB(a,Vector3.ZERO).expand(b).grow(starts[i].w+.004)
		combined=bounds if i==0 else combined.merge(bounds)
		local_heads[i]=tree_data.prune_into(local_tree,tree_data.head,bounds)
	var local_brush_heads:=PackedInt32Array()
	for i in brush_heads.size():
		var local_bounds: AABB=brush_transforms[i].affine_inverse()*combined
		local_brush_heads.append(tree_data.prune_into(local_tree,brush_heads[i],local_bounds))
	if cell_mode:local_tree.pack_cells(local_heads,active_count)
	else:local_tree.pack()
	for material in receivers:
		local_tree.apply(material,true,local_brush_heads,brush_transforms)
		material.set_shader_parameter("occlusion_local",true)
		material.set_shader_parameter("occlusion_local_heads",local_tree.cell_heads if cell_mode else local_heads)
func capture(name: String) -> Image:
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();image.save_png(OCC_OUT+name+".png");return image
func physical_box(parent: Node3D,position: Vector3,size: Vector3,material: Material) -> StaticBody3D:
	var body:=StaticBody3D.new();parent.add_child(body);body.position=position
	var mesh:=BoxMesh.new();mesh.size=size
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;body.add_child(node)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
	return body
func pixel_gain(a: Image,b: Image,point: Vector3) -> float:
	var pixel:=Vector2i(camera.unproject_position(point))
	return b.get_pixelv(pixel).r-a.get_pixelv(pixel).r
func fixture() -> void:
	var scene:=Node3D.new();stage.add_child(scene)
	var material:=fixture_material()
	physical_box(scene,Vector3(0,-.1,0),Vector3(12,.2,12),material)
	var wall:=physical_box(scene,Vector3(0,1,0),Vector3(.2,2,6),material)
	receivers=[material];originals={material:material.shader}
	camera.position=Vector3(7,8,9);camera.look_at(Vector3.ZERO)
	origin=Vector3(-.6,.6,-1.5);direction=Vector3.BACK;side=Vector3.ZERO
	for scenario in ["wall","thin-wall","door-closed","door-open","door-rotated"]:
		wall.transform=Transform3D.IDENTITY;wall.position=Vector3(0,1,0)
		var size:=Vector3(.02 if scenario=="thin-wall" else .2,2,6)
		wall.get_child(0).mesh.size=size;wall.get_child(1).shape.size=size
		tree_data=TreeData.new();brush_heads.clear();brush_transforms.clear()
		var floor_head: int=tree_data.box(AABB(Vector3(-6,-.2,-6),Vector3(12,.2,12)))
		var head: int=tree_data.box(AABB(-size*.5,size))
		if scenario.begins_with("door"):
			if scenario=="door-open":wall.position.y+=4
			if scenario=="door-rotated":wall.rotate_y(.25)
			tree_data.head=floor_head;brush_heads.append(head);brush_transforms.append(wall.transform)
		else:
			tree_data.head=tree_data.box(AABB(wall.position-size*.5,size),floor_head)
		tree_data.pack()
		await physics_frame;await physics_frame
		use_occlusion=false;activate(0);update_segments(1)
		var baseline:=await capture(scenario+"-baseline")
		activate(1)
		var leaked:=await capture(scenario+"-unoccluded")
		use_occlusion=true;activate(1)
		var corrected:=await capture(scenario+"-occluded")
		local_mode=true;activate(1);update_segments(1)
		var local_image:=await capture(scenario+"-local")
		check(corrected.get_data()==local_image.get_data(),scenario+": optimized static/moving brush result matches full tree")
		local_mode=false
		var blocked:=Vector3(.7,.01,1)
		var clear:=Vector3(-.85,.01,3.3)
		var raw_gain:=pixel_gain(baseline,leaked,blocked)
		var corrected_gain:=pixel_gain(baseline,corrected,blocked)
		var clear_gain:=pixel_gain(baseline,corrected,clear)
		check(raw_gain>.05,scenario+": unoccluded control illuminates test point")
		check(corrected_gain>.05 if scenario=="door-open" else absf(corrected_gain)<.008,scenario+": expected visibility across wall")
		check(clear_gain>.03,scenario+": unblocked floor remains illuminated")
		records.append({"fixture":scenario,"raw_gain":raw_gain,"corrected_gain":corrected_gain,"clear_gain":clear_gain})
		await ray_validation(scenario,Vector3(0,1,0),null)
	# A ceiling/floor slab blocks vertical rays independently of camera visibility.
	tree_data=TreeData.new();var floor_head: int=tree_data.box(AABB(Vector3(-6,-.2,-6),Vector3(12,.2,12)));tree_data.head=tree_data.box(AABB(Vector3(-4,1,-4),Vector3(8,.02,8)),floor_head);tree_data.pack()
	brush_heads.clear();brush_transforms.clear()
	wall.position=Vector3(0,1.01,0);wall.rotation=Vector3.ZERO
	wall.get_child(0).mesh.size=Vector3(8,.02,8);wall.get_child(1).shape.size=Vector3(8,.02,8)
	await physics_frame;await physics_frame
	await ray_validation("thin-ceiling",Vector3(0,1.2,0),null)
	receivers.clear();originals.clear();scene.free()
func ray_validation(name: String,center: Vector3,contents) -> void:
	var queries: Array=[];var expected: Array=[];var rng:=RandomNumberGenerator.new();rng.seed=70919
	var space:=stage.get_world_3d().direct_space_state
	for attempt in 4096:
		if queries.size()>=256:break
		var a:=center+Vector3(rng.randf_range(-2,2),rng.randf_range(-.7,.7),rng.randf_range(-2,2))
		var b:=a+Vector3(rng.randf_range(-3,3),rng.randf_range(-.8,.8),rng.randf_range(-3,3))
		if contents and contents.at(a) in [-2,-6]:continue
		# Explicit point-overlap rejection makes physics rays an independent oracle.
		var point:=PhysicsPointQueryParameters3D.new();point.position=a;point.collision_mask=1
		if not space.intersect_point(point,1).is_empty():continue
		var query:=PhysicsRayQueryParameters3D.create(a,b,1)
		queries.append([a,b]);expected.append(space.intersect_ray(query).is_empty())
	var input:=Image.create(128,4,false,Image.FORMAT_RGBAF)
	for i in queries.size():
		for j in 2:
			var p: Vector3=queries[i][j];input.set_pixel((i*2+j)%128,(i*2+j)/128,Color(p.x,p.y,p.z,1))
	var view:=SubViewport.new();view.size=Vector2i(128,2);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var rect:=ColorRect.new();rect.size=Vector2(128,2);view.add_child(rect)
	var shader:=Shader.new();shader.code="shader_type canvas_item;\n"+FileAccess.get_file_as_string(CELL_SOURCE if cell_mode else OCC_SOURCE)+"\nuniform sampler2D query_data : filter_nearest;\nvoid fragment() { ivec2 xy = ivec2(UV * vec2(128.0, 2.0)); int i = xy.y * 128 + xy.x; vec3 a = texelFetch(query_data, ivec2((i*2)%128,(i*2)/128),0).xyz; vec3 b = texelFetch(query_data, ivec2((i*2+1)%128,(i*2+1)/128),0).xyz; float v = occlusion_clear(a,b) ? 1.0 : 0.0; COLOR = vec4(v,v,v,1.0); }"
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("query_data",ImageTexture.create_from_image(input));tree_data.apply(material,true,brush_heads,brush_transforms);rect.material=material
	if cell_mode:material.set_shader_parameter("occlusion_local_heads",tree_data.cell_heads)
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var result:=view.get_texture().get_image();var leaks:=0;var dark:=0;var blocked:=0
	for i in queries.size():
		var clear:=result.get_pixel(i%128,i/128).r>.5
		if not expected[i]:blocked+=1
		if clear and not expected[i]:leaks+=1
		if not clear and expected[i]:dark+=1
	check(queries.size()==256,name+": 256 independent GPU/physics visibility queries")
	check(leaks==0 and dark==0,name+": GPU visibility agrees with physics (%d leaks, %d dark)"%[leaks,dark])
	records.append({"ray_case":name,"queries":queries.size(),"blocked":blocked,"leaks":leaks,"false_dark":dark})
	view.free()
func map_test(name: String) -> void:
	var level:=Loader.read("res://maps/"+name+".bsp");stage.add_child(level)
	for node in level.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	collect(level);tree_data=TreeData.new();check(tree_data.open("res://maps/"+name+".bsp"),name+": BSP tree uploaded")
	brush_heads.clear();brush_transforms.clear()
	var contents=preload("res://deathmatch/maps/contents.gd").new();contents.open("res://maps/"+name+".bsp")
	await physics_frame;await physics_frame
	for node in level.find_children("*","Node3D",true,false):
		if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch":camera.position=node.global_position+Vector3.UP*.78;break
	var space:=stage.get_world_3d().direct_space_state;var best:=-INF
	for i in 32:
		var dir:=Vector3(sin(i*TAU/32),-.09,cos(i*TAU/32)).normalized()
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,camera.position+dir*18,1))
		var length:=18.0 if hit.is_empty() else camera.position.distance_to(hit.position)
		if length>best:best=length;direction=dir
	camera.look_at(camera.position+direction*10);side=camera.global_basis.x
	origin=camera.position+direction*minf(best*.25,3.0)-Vector3.UP*.8
	use_occlusion=false;activate(1);update_segments(1)
	var raw:=await capture(name+"-unoccluded")
	use_occlusion=true;activate(1)
	var corrected:=await capture(name+"-occluded")
	local_mode=true;cell_mode=experimental_cells;activate(1);update_segments(1)
	var optimized:=await capture(name+"-local")
	check(corrected.get_data()==optimized.get_data(),name+": local tree produces pixel-identical occlusion")
	local_mode=false;cell_mode=false
	activate(0)
	var baseline:=await capture(name+"-baseline")
	check(difference(baseline,corrected).changed_pixels>100,name+": visible illumination survives occlusion")
	check(stage.find_children("*","Light3D",true,false).is_empty(),name+": no realtime light nodes")
	records.append({"map":name,"nodes":tree_data.planes.size(),"tree_bytes":tree_data.bytes,"changed_by_occlusion":difference(corrected,raw,false)})
	await ray_validation(name,camera.position,contents)
	# Independently compare a pruned domain against physics using identical rays.
	var full=tree_data;local_tree=TreeData.new()
	local_tree.head=tree_data.prune_into(local_tree,tree_data.head,AABB(camera.position-Vector3(5.01,1.51,5.01),Vector3(10.02,3.02,10.02)))
	local_tree.pack();tree_data=local_tree
	await ray_validation(name+"-pruned",camera.position,contents)
	local_tree.pack_cells(PackedInt32Array([local_tree.head]),1);cell_mode=true
	await ray_validation(name+"-cells",camera.position,contents)
	cell_mode=false
	tree_data=full
	await benchmark(name)
	receivers.clear();originals.clear();level.free()
func benchmark(name: String) -> void:
	use_occlusion=true;activate(8);update_segments(8)
	var until:=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<until:await process_frame
	for index in 10:
		var spec: Array=[[false,1,false],[true,1,true],[false,4,false],[true,4,true],[false,8,false],[true,8,true],[true,8,false],[true,8,true],[false,8,false],[true,1,true]][index]
		use_occlusion=spec[0];local_mode=spec[2];cell_mode=local_mode and experimental_cells;activate(spec[1]);update_segments(8)
		for i in 90:await process_frame
		var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var update: Array=[]
		for frame in 400:
			var start:=Time.get_ticks_usec();update_segments(8,float(frame)/60.0);update.append((Time.get_ticks_usec()-start)/1000.0);await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var row:={"map":name,"occlusion":use_occlusion,"local":local_mode,"cells":cell_mode,"segments":spec[1],"gpu_ms":stats(gpu),"cpu_ms":stats(cpu),"update_ms":stats(update),"local_nodes":local_tree.planes.size(),"cell_counts":local_tree.cell_counts.duplicate(),"draws":stats(draws)};records.append(row);print("OCCLUSION_BLOCK ",JSON.stringify(row))
	local_mode=false;cell_mode=false
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OCC_OUT)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	viewport=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.007,.008,.012);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=0;environment.environment.reflected_light_source=2;stage.add_child(environment)
	camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=80;camera.far=300;create_streaks()
	await fixture()
	await map_test("qsrc_dm6")
	await map_test("tf_vesper")
	var result:={"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"frames_per_block":400,"records":records,"checks":checks,"failures":failures}
	FileAccess.open(OCC_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	stage.free();print("OCCLUSION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
