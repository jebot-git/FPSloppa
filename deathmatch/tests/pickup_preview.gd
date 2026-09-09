extends SceneTree
func _initialize():call_deferred("run")
func run():
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("151d22");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;world.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-40,0);light.light_energy=1.2;world.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.3;camera.position=Vector3(2.4,3,-7);world.add_child(camera);camera.look_at(Vector3(0,0,0));camera.make_current()
	root.msaa_3d=Viewport.MSAA_4X
	var entries:=[["ammo",0,"BULLETS"],["ammo",1,"SHELLS"],["ammo",2,"ROCKETS"],["ammo",3,"CELLS"],["health",0,"MEDKIT"],["armor",1,"GREEN ARMOUR"],["armor",2,"MEGA ARMOUR"],["health",100,"MEGA HEALTH"]]
	for i in range(entries.size()):
		var entry:Array=entries[i];var model=preload("res://deathmatch/pickups/models.gd").create(entry[0],entry[1]);world.add_child(model);model.position=Vector3((i%4-1.5)*1.0,0,(i/4-.5)*1.3)
		var label:=Label3D.new();label.text=entry[2];label.font_size=28;label.pixel_size=.0018;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world.add_child(label);label.position=model.position+Vector3(0,-.36,-.2)
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/pickup-models-preview.png")
	quit()
