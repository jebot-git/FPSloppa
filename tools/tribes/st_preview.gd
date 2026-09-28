extends SceneTree
var g
func _initialize():run.call_deferred()
func shot(label: String):
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/st-tribes/"+label+".png")
func run():
	root.size=Vector2i(1280,800)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST preview",0,5,30,true,"st");g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g.hud.hide();g.menu_open=false;g.fighters[1].hide()
	var camera:=Camera3D.new();camera.far=1800;camera.fov=72;g.add_child(camera);camera.make_current()
	var pads=g.match_mode.tribes.stations()
	for row in pads.generators:
		camera.global_position=row.frame*Vector3(6,.7,6);camera.look_at(row.frame.origin)
		await shot("generator-"+str(row.team))
		pads.health[row.team]=0.0;await shot("generator-offline-"+str(row.team));pads.health[row.team]=300.0
	var row: Dictionary=pads.rows[0]
	g.players[1].team=row.team;g.fighters[1].position=row.position
	camera.global_position=row.position+Vector3(4,3,5);camera.look_at(row.position+Vector3.UP)
	g.match_mode.tribes.open_inventory();await shot("inventory");g.match_mode.tribes.panel.close()
	var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
	var attachments:=Node3D.new();g.add_child(attachments);attachments.position=row.position
	for key in ["kit","pack","flag"]:
		var model:=preload("res://deathmatch/tribes/equipment.gd").model(key,1);attachments.add_child(model)
		model.transform=preload("res://deathmatch/tribes/equipment.gd").mount(pose,key)
	camera.position=row.position+Vector3(-1.0,1.8,-1.2);camera.look_at(row.position+Vector3(0,1.1,-.1));camera.fov=50
	await shot("hip-chest-equipment")
	print("ST_PREVIEW_OK");g.disconnect_game();g.free()
	for i in 3:await process_frame
	quit()
