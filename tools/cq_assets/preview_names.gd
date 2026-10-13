extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(960,540)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("111c28");world.add_child(env)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;world.add_child(camera);camera.current=true
	var spotting=preload("res://deathmatch/conquest/classes/spotting.gd").new()
	var i:=0
	for role in spotting.ICONS:
		var label:=Label3D.new();label.text=spotting.ICONS[role]+"  "+role.capitalize()+" Player";label.font=spotting.font();label.font_size=36;label.pixel_size=.006;label.position.y=1.1-i*.7;label.modulate=Color("66b6ff") if i%2 else Color("ff7777");world.add_child(label);i+=1
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/cq-classes/name-icons.png")
	world.free();quit()
