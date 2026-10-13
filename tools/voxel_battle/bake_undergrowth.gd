extends SceneTree
const Assets=preload("res://tools/voxel_battle/undergrowth_assets.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var atlas:=Image.create(1536,256,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
	for kind in 4:
		var viewport:=SubViewport.new();viewport.size=Vector2i(384,256);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4;camera.position=Vector3(0,1.2,-4);viewport.add_child(camera);camera.look_at(Vector3(0,1.2,0));camera.current=true
		var mesh:=MeshInstance3D.new();mesh.mesh=Assets.asset(kind,0);viewport.add_child(mesh)
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		atlas.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,384,256),Vector2i(kind*384,0));viewport.queue_free()
	atlas.save_png("res://experimental-assets/jungle/undergrowth.png");print("UNDERGROWTH_ATLAS_BAKED");quit()
