extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Enhancer=preload("res://deathmatch/tribes/image_enhancer.gd")
const Visor=preload("res://deathmatch/vr/tribes_visor.gd")
class Rig extends Node3D:
	var head: Camera3D
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames():
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
func red_bounds(im: Image) -> Rect2i:
	var lo:=Vector2i(im.get_width(),im.get_height());var hi:=Vector2i(-1,-1)
	for y in im.get_height():
		for x in im.get_width():
			var c:=im.get_pixel(x,y)
			if c.r>.3 and c.r>c.g*2 and c.r>c.b*2:
				lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
	return Rect2i(lo,hi-lo+Vector2i.ONE)
func run():
	root.size=Vector2i(1000,800);root.content_scale_size=Vector2i.ZERO
	var stage:=Node3D.new();root.add_child(stage)
	var rig:=Rig.new();stage.add_child(rig);rig.head=Camera3D.new();rig.add_child(rig.head)
	rig.head.fov=85;rig.head.make_current()
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("182533");stage.add_child(env)
	var red:=Art.material(Color("e84424"));red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	Art.box(stage,Vector3(.3,.3,-60),Vector3(1,1,.1),red)
	var white:=Art.material(Color("8b9cac"));white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	Art.box(stage,Vector3(-2,-.8,-60),Vector3(.5,2,.1),white)
	await frames()
	var normal:=red_bounds(root.get_texture().get_image())
	var overlay=preload("res://deathmatch/tribes/zoom_overlay.gd").new();var canvas:=CanvasLayer.new();root.add_child(canvas);canvas.add_child(overlay)
	for amount in Enhancer.LEVELS:
		rig.head.fov=Enhancer.zoom_fov(85,amount);overlay.display(amount)
		await frames();var im:=root.get_texture().get_image();im.save_png("res://test-results/tribes-image-enhancer/desktop-%dx.png"%amount)
		var bounds:=red_bounds(im)
		check(absf(float(bounds.size.x)/normal.size.x-amount)<amount*.2,"Desktop rendered target grows %dx"%amount)
	canvas.free();rig.head.fov=85
	var visor:=Visor.new();stage.add_child(visor);visor.setup(rig);visor.prepare()
	check(visor.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Visor starts suspended")
	check(not visor.viewport.use_xr and not visor.viewport.audio_listener_enable_3d,"Single independent view with no duplicate listener")
	check(visor.camera.cull_mask&visor.screen.layers==0,"Visor cannot render itself")
	for amount in Enhancer.LEVELS:
		visor.camera.global_transform=rig.head.global_transform
		visor.camera.fov=Enhancer.zoom_fov(Visor.BASE_FOV,amount)
		visor.material.set_shader_parameter("head_view",visor.camera.global_transform.affine_inverse())
		visor.overlay.display(amount)
		visor.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;visor.screen.show()
		await frames();var im:=root.get_texture().get_image();im.save_png("res://test-results/tribes-image-enhancer/visor-%dx.png"%amount)
		var bounds:=red_bounds(im)
		check(absf(float(bounds.size.x)/normal.size.x-amount)<amount*.2,"Visor rendered target grows %dx"%amount)
		check(bounds.get_center().y<400 and bounds.get_center().x>500,"Visor preserves image orientation")
		check(rig.head.fov==85,"Headset camera projection remains unchanged")
	visor.disable();await frames()
	check(not visor.screen.visible and visor.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Release suspends viewport and overlay")
	check(red_bounds(root.get_texture().get_image())==normal,"Normal view restored exactly")
	visor.free();stage.free()
	var report:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/tribes-image-enhancer/render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIBES_VISOR_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
