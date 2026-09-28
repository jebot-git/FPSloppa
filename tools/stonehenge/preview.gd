extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
var world: Node3D
var camera: Camera3D
var views: Array=[]
func _initialize():run.call_deferred()
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func shot(name: String):
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/stonehenge/"+name+".png")
	views.append({"view":name,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	world=Node3D.new();root.add_child(world)
	var row: Dictionary
	for item in Loader.catalog():
		if item.id=="ctf_stonehenge":row=item;break
	assert(not row.is_empty())
	var packed:=Loader.scene(row);assert(packed!=null)
	var level:=packed.instantiate();world.add_child(level)
	preload("res://deathmatch/maps/filtering.gd").new().apply(level,2,true)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.name="Environment"
	env.environment.background_mode=Environment.BG_SKY
	env.environment.sky=preload("res://deathmatch/maps/skies/catalog.gd").create("ctf_stonehenge")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.72,.79,.84);env.environment.ambient_light_energy=.35
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	camera=Camera3D.new();camera.far=1800;camera.near=.1;camera.fov=76;world.add_child(camera);camera.make_current()
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Stonehenge/probes.json"))
	for view in probes.views:
		camera.position=v(view.eye);camera.look_at(v(view.look));await shot(view.name)
	camera.position=Vector3(0,950,0);camera.look_at(Vector3(0,0,0),Vector3.FORWARD);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=770
	await shot("top-down")
	FileAccess.open("res://test-results/stonehenge/views.json",FileAccess.WRITE).store_string(JSON.stringify({"bsp_sha256":row.sha256,"views":views},"  "))
	print("STONEHENGE_VIEWS_OK");world.queue_free();await process_frame;quit()
